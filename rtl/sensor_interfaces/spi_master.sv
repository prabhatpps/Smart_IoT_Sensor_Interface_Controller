//=============================================================================
// SPI Master Interface Module  
// Author: Prabhat Pandey
// Date: August 24, 2025
// Description: SPI master for motion sensor communication
//=============================================================================

import iot_sensor_pkg::*;

module spi_master #(
    parameter int SYSTEM_CLK_FREQ = 100_000_000,
    parameter int SPI_CLK_FREQ = 1_000_000,
    parameter int DATA_WIDTH = 16
)(
    // System interface
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    enable,

    // Control interface  
    input  logic                    start_transaction,
    input  logic [DATA_WIDTH-1:0]   tx_data,
    output logic [DATA_WIDTH-1:0]   rx_data,
    output logic                    transaction_done,

    // SPI physical interface
    output logic                    sclk,
    output logic                    mosi,
    input  logic                    miso,
    output logic                    cs_n
);

    // Clock divider for SPI clock generation
    localparam int CLK_DIVIDER = SYSTEM_CLK_FREQ / (2 * SPI_CLK_FREQ);

    // Internal signals
    spi_state_e current_state, next_state;
    logic [15:0] clk_counter;
    logic [4:0]  bit_counter; // Up to 32 bits
    logic [DATA_WIDTH-1:0] tx_shift_reg, rx_shift_reg;
    logic sclk_reg;

    // SPI clock generation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_counter <= '0;
            sclk_reg <= 1'b0;
        end else if (!enable || current_state == SPI_IDLE) begin
            clk_counter <= '0;
            sclk_reg <= 1'b0;
        end else if (clk_counter >= CLK_DIVIDER - 1) begin
            clk_counter <= '0;
            sclk_reg <= ~sclk_reg;
        end else begin
            clk_counter <= clk_counter + 1'b1;
        end
    end

    logic sclk_posedge, sclk_negedge;
    logic sclk_prev;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_prev <= 1'b0;
        end else begin
            sclk_prev <= sclk_reg;
        end
    end

    assign sclk_posedge = sclk_reg && !sclk_prev;
    assign sclk_negedge = !sclk_reg && sclk_prev;
    assign sclk = (current_state == SPI_TRANSFER) ? sclk_reg : 1'b0;

    // Main SPI state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= SPI_IDLE;
        end else if (!enable) begin
            current_state <= SPI_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // State machine logic
    always_comb begin
        next_state = current_state;

        case (current_state)
            SPI_IDLE: begin
                if (start_transaction && enable) begin
                    next_state = SPI_CS_LOW;
                end
            end

            SPI_CS_LOW: begin
                next_state = SPI_TRANSFER;
            end

            SPI_TRANSFER: begin
                if (bit_counter == DATA_WIDTH && sclk_negedge) begin
                    next_state = SPI_CS_HIGH;
                end
            end

            SPI_CS_HIGH: begin
                next_state = SPI_IDLE;
            end

            default: next_state = SPI_IDLE;
        endcase
    end

    // Control signals and data handling
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_counter <= '0;
            tx_shift_reg <= '0;
            rx_shift_reg <= '0;
            cs_n <= 1'b1;
            transaction_done <= 1'b0;
            rx_data <= '0;
        end else begin
            case (current_state)
                SPI_IDLE: begin
                    bit_counter <= '0;
                    cs_n <= 1'b1;
                    transaction_done <= 1'b0;
                    if (start_transaction) begin
                        tx_shift_reg <= tx_data;
                        rx_shift_reg <= '0;
                    end
                end

                SPI_CS_LOW: begin
                    cs_n <= 1'b0;
                end

                SPI_TRANSFER: begin
                    // Data transmission on negative edge (CPOL=0, CPHA=0)
                    if (sclk_negedge) begin
                        tx_shift_reg <= {tx_shift_reg[DATA_WIDTH-2:0], 1'b0};
                        bit_counter <= bit_counter + 1'b1;
                    end

                    // Data reception on positive edge
                    if (sclk_posedge) begin
                        rx_shift_reg <= {rx_shift_reg[DATA_WIDTH-2:0], miso};
                    end
                end

                SPI_CS_HIGH: begin
                    cs_n <= 1'b1;
                    transaction_done <= 1'b1;
                    rx_data <= rx_shift_reg;
                end
            endcase
        end
    end

    // MOSI output
    assign mosi = (current_state == SPI_TRANSFER) ? tx_shift_reg[DATA_WIDTH-1] : 1'b0;

    // Assertions for verification
    `ifdef SIMULATION
        always @(posedge clk) begin
            if (current_state == SPI_TRANSFER) begin
                assert (bit_counter <= DATA_WIDTH) 
                    else $error("SPI bit counter overflow: %0d", bit_counter);
            end
        end
    `endif

endmodule : spi_master

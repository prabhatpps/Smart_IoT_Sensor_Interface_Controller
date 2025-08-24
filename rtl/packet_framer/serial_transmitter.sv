//=============================================================================
// Serial Transmitter Module
// Author: Prabhat Pandey
// Date: August 24, 2025
// Description: Serializes packet bytes and transmits at configurable baud rate
//=============================================================================

import iot_sensor_pkg::*;

module serial_transmitter #(
    parameter int SYSTEM_CLK_FREQ = 100_000_000,
    parameter int BAUD_RATE = 115200
)(
    // System interface
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,

    // Packet input
    input  logic [7:0]  packet_byte,
    input  logic        packet_valid,
    output logic        packet_ready,

    // Serial output
    output logic        tx_serial,
    output logic        tx_busy,

    // Status
    output logic [7:0]  bytes_transmitted,
    output logic        transmission_complete
);

    // UART timing parameters
    localparam int CLKS_PER_BIT = SYSTEM_CLK_FREQ / BAUD_RATE;

    // Internal signals
    typedef enum logic [2:0] {
        TX_IDLE,
        TX_START_BIT,
        TX_DATA_BITS,
        TX_STOP_BIT,
        TX_CLEANUP
    } tx_state_e;

    tx_state_e current_state, next_state;

    logic [$clog2(CLKS_PER_BIT):0] clk_counter;
    logic [2:0] bit_index;
    logic [7:0] tx_data_reg;
    logic       clk_pulse;

    // Baud rate clock generation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_counter <= '0;
        end else if (!enable || current_state == TX_IDLE) begin
            clk_counter <= '0;
        end else if (clk_counter >= CLKS_PER_BIT - 1) begin
            clk_counter <= '0;
        end else begin
            clk_counter <= clk_counter + 1'b1;
        end
    end

    assign clk_pulse = (clk_counter == CLKS_PER_BIT - 1);

    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= TX_IDLE;
        end else if (!enable) begin
            current_state <= TX_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // State transition logic
    always_comb begin
        next_state = current_state;

        case (current_state)
            TX_IDLE: begin
                if (packet_valid && enable) begin
                    next_state = TX_START_BIT;
                end
            end

            TX_START_BIT: begin
                if (clk_pulse) begin
                    next_state = TX_DATA_BITS;
                end
            end

            TX_DATA_BITS: begin
                if (clk_pulse && bit_index == 3'd7) begin
                    next_state = TX_STOP_BIT;
                end
            end

            TX_STOP_BIT: begin
                if (clk_pulse) begin
                    next_state = TX_CLEANUP;
                end
            end

            TX_CLEANUP: begin
                next_state = TX_IDLE;
            end

            default: next_state = TX_IDLE;
        endcase
    end

    // Control logic and data transmission
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_serial <= 1'b1; // Idle high
            tx_busy <= 1'b0;
            packet_ready <= 1'b1;
            bit_index <= '0;
            tx_data_reg <= '0;
            bytes_transmitted <= '0;
            transmission_complete <= 1'b0;
        end else begin
            case (current_state)
                TX_IDLE: begin
                    tx_serial <= 1'b1; // Idle high
                    tx_busy <= 1'b0;
                    packet_ready <= 1'b1;
                    bit_index <= '0;
                    transmission_complete <= 1'b0;

                    if (packet_valid) begin
                        tx_data_reg <= packet_byte;
                        packet_ready <= 1'b0;
                    end
                end

                TX_START_BIT: begin
                    tx_busy <= 1'b1;
                    tx_serial <= 1'b0; // Start bit (low)
                    packet_ready <= 1'b0;
                end

                TX_DATA_BITS: begin
                    tx_serial <= tx_data_reg[bit_index];

                    if (clk_pulse) begin
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end
                end

                TX_STOP_BIT: begin
                    tx_serial <= 1'b1; // Stop bit (high)

                    if (clk_pulse) begin
                        bytes_transmitted <= bytes_transmitted + 1'b1;
                    end
                end

                TX_CLEANUP: begin
                    tx_busy <= 1'b0;
                    transmission_complete <= 1'b1;
                end
            endcase
        end
    end

    // Enhanced version with FIFO for packet buffering
    // This helps prevent data loss when packets arrive faster than transmission

    logic [7:0] tx_fifo_data;
    logic       tx_fifo_empty, tx_fifo_full;
    logic       tx_fifo_wr, tx_fifo_rd;
    logic [2:0] tx_fifo_count;

    // Internal FIFO for packet bytes
    sync_fifo #(
        .DATA_WIDTH(8),
        .DEPTH(16), // Buffer up to 16 bytes (1-2 packets)
        .ADDR_WIDTH(4)
    ) tx_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(tx_fifo_wr),
        .rd_en(tx_fifo_rd),
        .wr_data(packet_byte),
        .rd_data(tx_fifo_data),
        .full(tx_fifo_full),
        .empty(tx_fifo_empty),
        .count(tx_fifo_count[2:0])
    );

    // FIFO control logic
    assign tx_fifo_wr = packet_valid && !tx_fifo_full;
    assign tx_fifo_rd = (current_state == TX_IDLE) && !tx_fifo_empty;
    assign packet_ready = !tx_fifo_full;

    // Use FIFO data when available
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_data_reg <= '0;
        end else if (tx_fifo_rd) begin
            tx_data_reg <= tx_fifo_data;
        end
    end

    // Update state transition for FIFO mode
    always_comb begin
        next_state = current_state;

        case (current_state)
            TX_IDLE: begin
                if (!tx_fifo_empty && enable) begin
                    next_state = TX_START_BIT;
                end
            end

            TX_START_BIT: begin
                if (clk_pulse) begin
                    next_state = TX_DATA_BITS;
                end
            end

            TX_DATA_BITS: begin
                if (clk_pulse && bit_index == 3'd7) begin
                    next_state = TX_STOP_BIT;
                end
            end

            TX_STOP_BIT: begin
                if (clk_pulse) begin
                    next_state = TX_CLEANUP;
                end
            end

            TX_CLEANUP: begin
                next_state = TX_IDLE;
            end

            default: next_state = TX_IDLE;
        endcase
    end

    // Assertions for verification
    `ifdef SIMULATION
        always @(posedge clk) begin
            if (enable) begin
                // Check baud rate timing
                if (current_state != TX_IDLE) begin
                    assert (clk_counter < CLKS_PER_BIT) 
                        else $error("Baud rate counter overflow: %0d", clk_counter);
                end

                // Verify data bit transmission
                if (current_state == TX_DATA_BITS) begin
                    assert (bit_index <= 7) 
                        else $error("Data bit index overflow: %0d", bit_index);
                end

                // Check FIFO overflow
                assert (!(packet_valid && tx_fifo_full)) 
                    else $warning("TX FIFO overflow - packet data lost");
            end
        end
    `endif

endmodule : serial_transmitter

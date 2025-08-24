//=============================================================================
// SPI Master Controller
// Supports configurable SPI mode and data transfer
//=============================================================================

`timescale 1ns/1ps

import iot_sensor_pkg::*;

module spi_master (
    input  logic       clk,
    input  logic       rst_n,

    // Control interface
    input  logic       start_transaction,
    input  logic [7:0] tx_data,
    output logic [7:0] rx_data,
    output logic       transaction_done,

    // SPI interface
    output logic       spi_clk,
    output logic       spi_mosi,
    input  logic       spi_miso,
    output logic       spi_cs
);

    // State machine
    spi_state_e current_state, next_state;

    // Internal signals
    logic [7:0] tx_shift_reg;
    logic [7:0] rx_shift_reg;
    logic [2:0] bit_count;
    logic [7:0] clk_count;

    // Clock divider for SPI timing
    localparam CLK_DIV = SYSTEM_CLK_FREQ / (2 * SPI_CLK_FREQ);

    // State machine - sequential
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= SPI_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // State machine - combinational
    always_comb begin
        next_state = current_state;

        case (current_state)
            SPI_IDLE: begin
                if (start_transaction)
                    next_state = SPI_START;
            end

            SPI_START: begin
                if (clk_count >= CLK_DIV)
                    next_state = SPI_TRANSFER;
            end

            SPI_TRANSFER: begin
                if (bit_count == 7 && clk_count >= CLK_DIV)
                    next_state = SPI_FINISH;
            end

            SPI_FINISH: begin
                if (clk_count >= CLK_DIV)
                    next_state = SPI_IDLE;
            end

            default: next_state = SPI_IDLE;
        endcase
    end

    // Control logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_cs <= 1'b1;
            spi_clk <= 1'b0;
            spi_mosi <= 1'b0;
            bit_count <= '0;
            clk_count <= '0;
            tx_shift_reg <= '0;
            rx_shift_reg <= '0;
            rx_data <= '0;
            transaction_done <= 1'b0;
        end else begin
            transaction_done <= 1'b0;

            case (current_state)
                SPI_IDLE: begin
                    spi_cs <= 1'b1;
                    spi_clk <= 1'b0;
                    clk_count <= '0;
                    bit_count <= '0;
                    if (start_transaction) begin
                        tx_shift_reg <= tx_data;
                    end
                end

                SPI_START: begin
                    spi_cs <= 1'b0;  // Assert chip select
                    clk_count <= clk_count + 1;
                end

                SPI_TRANSFER: begin
                    if (clk_count < CLK_DIV/2) begin
                        spi_clk <= 1'b0;
                        spi_mosi <= tx_shift_reg[7-bit_count];
                        clk_count <= clk_count + 1;
                    end else if (clk_count < CLK_DIV) begin
                        spi_clk <= 1'b1;
                        rx_shift_reg[7-bit_count] <= spi_miso;
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= '0;
                        bit_count <= bit_count + 1;
                        if (bit_count == 7) begin
                            rx_data <= rx_shift_reg;
                        end
                    end
                end

                SPI_FINISH: begin
                    spi_clk <= 1'b0;
                    if (clk_count >= CLK_DIV) begin
                        spi_cs <= 1'b1;  // Deassert chip select
                        transaction_done <= 1'b1;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end
            endcase
        end
    end

endmodule : spi_master

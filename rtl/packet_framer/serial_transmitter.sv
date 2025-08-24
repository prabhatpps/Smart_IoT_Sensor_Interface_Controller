//=============================================================================
// Serial Transmitter (UART)
// Transmits data packets over serial interface
//=============================================================================

`timescale 1ns/1ps

import iot_sensor_pkg::*;

module serial_transmitter (
    input  logic        clk,
    input  logic        rst_n,

    // Data interface
    input  logic        tx_start,
    input  logic [7:0]  tx_data,
    output logic        tx_busy,
    output logic        tx_done,

    // Serial output
    output logic        serial_tx
);

    // UART timing
    localparam BAUD_DIV = SYSTEM_CLK_FREQ / BAUD_RATE;

    // State machine states
    typedef enum logic [2:0] {
        TX_IDLE     = 3'b000,
        TX_START    = 3'b001,
        TX_DATA     = 3'b010,
        TX_STOP     = 3'b011,
        TX_COMPLETE = 3'b100
    } tx_state_e;

    tx_state_e current_state, next_state;

    // Internal signals
    logic [7:0] shift_reg;
    logic [2:0] bit_count;
    logic [15:0] baud_count;

    // State machine - sequential
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= TX_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // State machine - combinational
    always_comb begin
        next_state = current_state;

        case (current_state)
            TX_IDLE: begin
                if (tx_start)
                    next_state = TX_START;
            end

            TX_START: begin
                if (baud_count >= BAUD_DIV-1)
                    next_state = TX_DATA;
            end

            TX_DATA: begin
                if (bit_count == 7 && baud_count >= BAUD_DIV-1)
                    next_state = TX_STOP;
            end

            TX_STOP: begin
                if (baud_count >= BAUD_DIV-1)
                    next_state = TX_COMPLETE;
            end

            TX_COMPLETE: begin
                next_state = TX_IDLE;
            end

            default: next_state = TX_IDLE;
        endcase
    end

    // Output assignments
    assign tx_busy = (current_state != TX_IDLE && current_state != TX_COMPLETE);
    assign tx_done = (current_state == TX_COMPLETE);

    // Control logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            serial_tx <= 1'b1;  // Idle high
            shift_reg <= '0;
            bit_count <= '0;
            baud_count <= '0;
        end else begin
            case (current_state)
                TX_IDLE: begin
                    serial_tx <= 1'b1;  // Idle high
                    bit_count <= '0;
                    baud_count <= '0;
                    if (tx_start) begin
                        shift_reg <= tx_data;
                    end
                end

                TX_START: begin
                    serial_tx <= 1'b0;  // Start bit
                    if (baud_count >= BAUD_DIV-1) begin
                        baud_count <= '0;
                    end else begin
                        baud_count <= baud_count + 1;
                    end
                end

                TX_DATA: begin
                    serial_tx <= shift_reg[bit_count];
                    if (baud_count >= BAUD_DIV-1) begin
                        baud_count <= '0;
                        bit_count <= bit_count + 1;
                    end else begin
                        baud_count <= baud_count + 1;
                    end
                end

                TX_STOP: begin
                    serial_tx <= 1'b1;  // Stop bit
                    if (baud_count >= BAUD_DIV-1) begin
                        baud_count <= '0;
                    end else begin
                        baud_count <= baud_count + 1;
                    end
                end

                TX_COMPLETE: begin
                    serial_tx <= 1'b1;  // Idle high
                end
            endcase
        end
    end

endmodule : serial_transmitter

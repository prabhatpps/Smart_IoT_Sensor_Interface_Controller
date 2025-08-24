//=============================================================================
// Motion Sensor Interface (SPI)
// Interfaces with SPI motion sensor with interrupt capability
//=============================================================================

`timescale 1ns/1ps

import iot_sensor_pkg::*;

module motion_sensor_interface (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic [1:0]  power_mode,

    // Interrupt input
    input  logic        motion_int,

    // Data output
    output logic [15:0] sensor_data,
    output logic        data_valid,
    output logic        data_ready,
    output logic        sensor_error,

    // SPI interface
    output logic        start_spi,
    output logic [7:0]  spi_tx_data,
    input  logic [7:0]  spi_rx_data,
    input  logic        spi_done
);

    // State machine
    motion_state_e current_state, next_state;

    // Internal signals
    logic motion_int_sync;
    logic motion_int_prev;
    logic motion_detected;
    logic [15:0] motion_count;
    logic [15:0] debounce_counter;

    // Synchronize interrupt signal
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            motion_int_sync <= 1'b0;
            motion_int_prev <= 1'b0;
        end else begin
            motion_int_sync <= motion_int;
            motion_int_prev <= motion_int_sync;
        end
    end

    // Detect motion interrupt edge
    assign motion_detected = motion_int_sync && !motion_int_prev;
    assign data_ready = (current_state == MOTION_DONE);

    // State machine - sequential
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= MOTION_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // State machine - combinational
    always_comb begin
        next_state = current_state;

        case (current_state)
            MOTION_IDLE: begin
                if (enable && (motion_detected || debounce_counter == 0))
                    next_state = MOTION_START;
            end

            MOTION_START: begin
                if (start_spi)
                    next_state = MOTION_READ;
            end

            MOTION_READ: begin
                if (spi_done)
                    next_state = MOTION_DONE;
            end

            MOTION_DONE: begin
                if (data_ready)
                    next_state = MOTION_IDLE;
            end

            default: next_state = MOTION_IDLE;
        endcase
    end

    // Control logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_spi <= 1'b0;
            spi_tx_data <= 8'h00;
            sensor_data <= '0;
            data_valid <= 1'b0;
            sensor_error <= 1'b0;
            motion_count <= '0;
            debounce_counter <= 16'd50000; // ~500us @ 100MHz for periodic check
        end else begin
            case (current_state)
                MOTION_IDLE: begin
                    start_spi <= 1'b0;
                    data_valid <= 1'b0;
                    sensor_error <= 1'b0;

                    // Increment motion count on interrupt
                    if (motion_detected) begin
                        motion_count <= motion_count + 1;
                    end

                    // Debounce counter for periodic checks
                    if (debounce_counter > 0) begin
                        debounce_counter <= debounce_counter - 1;
                    end else begin
                        // Reset counter based on power mode
                        case (power_mode)
                            PWR_NORMAL: debounce_counter <= 16'd50000;   // 500us
                            PWR_LOW:    debounce_counter <= 16'd100000;  // 1ms  
                            PWR_SLEEP:  debounce_counter <= 16'd200000;  // 2ms
                            default:    debounce_counter <= 16'd50000;
                        endcase
                    end
                end

                MOTION_START: begin
                    start_spi <= 1'b1;
                    spi_tx_data <= 8'hA0; // Read command for motion sensor
                end

                MOTION_READ: begin
                    start_spi <= 1'b0;
                    if (spi_done) begin
                        // Store received data in lower byte, motion count in upper byte
                        sensor_data <= {motion_count[7:0], spi_rx_data};
                    end
                end

                MOTION_DONE: begin
                    data_valid <= 1'b1;
                    debounce_counter <= 16'd50000; // Reset counter for next read
                end
            endcase
        end
    end

endmodule : motion_sensor_interface

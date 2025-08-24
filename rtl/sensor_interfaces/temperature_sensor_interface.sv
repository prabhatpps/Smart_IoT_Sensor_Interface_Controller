//=============================================================================
// Temperature Sensor Interface
// Author: Prabhat Pandey
// Date: August 24, 2025
// Description: Wrapper for temperature sensor with I2C interface
//=============================================================================

import iot_sensor_pkg::*;

module temperature_sensor_interface #(
    parameter logic [6:0] SENSOR_I2C_ADDR = 7'h48  // TMP102 default address
)(
    // System interface
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,

    // Data interface
    output logic [15:0] sensor_data,
    output logic        data_valid,
    input  logic        data_ready,

    // I2C physical interface  
    output logic        scl,
    inout  logic        sda,

    // Status
    output logic        sensor_error
);

    // Internal signals
    logic start_read;
    logic transaction_done;
    logic ack_error;
    logic [7:0] read_data_msb, read_data_lsb;

    // State machine for sensor reading
    typedef enum logic [2:0] {
        TEMP_IDLE,
        TEMP_READ_MSB,
        TEMP_WAIT_MSB,
        TEMP_READ_LSB, 
        TEMP_WAIT_LSB,
        TEMP_PROCESS,
        TEMP_DONE
    } temp_state_e;

    temp_state_e current_state, next_state;
    logic [15:0] read_counter;

    // I2C Master instance
    i2c_master #(
        .SYSTEM_CLK_FREQ(SYSTEM_CLK_FREQ),
        .I2C_CLK_FREQ(I2C_CLK_FREQ)
    ) i2c_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .start_transaction(start_read),
        .slave_addr(SENSOR_I2C_ADDR),
        .read_write_n(1'b1), // Always reading
        .write_data(8'h00),
        .read_data(current_state == TEMP_READ_MSB ? read_data_msb : read_data_lsb),
        .transaction_done(transaction_done),
        .ack_error(ack_error),
        .scl(scl),
        .sda(sda)
    );

    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= TEMP_IDLE;
        end else if (!enable) begin
            current_state <= TEMP_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // State transition logic
    always_comb begin
        next_state = current_state;

        case (current_state)
            TEMP_IDLE: begin
                if (read_counter == 0) begin
                    next_state = TEMP_READ_MSB;
                end
            end

            TEMP_READ_MSB: begin
                next_state = TEMP_WAIT_MSB;
            end

            TEMP_WAIT_MSB: begin
                if (transaction_done || ack_error) begin
                    next_state = TEMP_READ_LSB;
                end
            end

            TEMP_READ_LSB: begin
                next_state = TEMP_WAIT_LSB;
            end

            TEMP_WAIT_LSB: begin
                if (transaction_done || ack_error) begin
                    next_state = TEMP_PROCESS;
                end
            end

            TEMP_PROCESS: begin
                next_state = TEMP_DONE;
            end

            TEMP_DONE: begin
                if (data_ready) begin
                    next_state = TEMP_IDLE;
                end
            end

            default: next_state = TEMP_IDLE;
        endcase
    end

    // Control logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_read <= 1'b0;
            sensor_data <= '0;
            data_valid <= 1'b0;
            sensor_error <= 1'b0;
            read_counter <= 16'd50000; // ~500us @ 100MHz
        end else begin
            case (current_state)
                TEMP_IDLE: begin
                    start_read <= 1'b0;
                    data_valid <= 1'b0;
                    if (read_counter > 0) begin
                        read_counter <= read_counter - 1'b1;
                    end else begin
                        read_counter <= 16'd50000; // Reset for next read
                    end
                end

                TEMP_READ_MSB: begin
                    start_read <= 1'b1;
                end

                TEMP_WAIT_MSB: begin
                    start_read <= 1'b0;
                    if (ack_error) begin
                        sensor_error <= 1'b1;
                    end
                end

                TEMP_READ_LSB: begin
                    start_read <= 1'b1;
                    sensor_error <= 1'b0;
                end

                TEMP_WAIT_LSB: begin
                    start_read <= 1'b0;
                    if (ack_error) begin
                        sensor_error <= 1'b1;
                    end
                end

                TEMP_PROCESS: begin
                    if (!sensor_error) begin
                        // Combine MSB and LSB (TMP102 format)
                        sensor_data <= {read_data_msb, read_data_lsb};
                        data_valid <= 1'b1;
                    end
                end

                TEMP_DONE: begin
                    if (data_ready) begin
                        data_valid <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule : temperature_sensor_interface

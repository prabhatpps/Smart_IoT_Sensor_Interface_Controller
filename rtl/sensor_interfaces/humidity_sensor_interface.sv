//=============================================================================
// Humidity Sensor Interface
// Author: Prabhat Pandey
// Date: August 24, 2025
// Description: Wrapper for humidity sensor with I2C interface
//=============================================================================

import iot_sensor_pkg::*;

module humidity_sensor_interface #(
    parameter logic [6:0] SENSOR_I2C_ADDR = 7'h40  // SHT30 default address
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

    // Internal signals - similar to temperature sensor but different timing
    logic start_read;
    logic transaction_done;
    logic ack_error;
    logic [7:0] read_data_msb, read_data_lsb;

    typedef enum logic [2:0] {
        HUM_IDLE,
        HUM_READ_MSB,
        HUM_WAIT_MSB,
        HUM_READ_LSB,
        HUM_WAIT_LSB,
        HUM_PROCESS,
        HUM_DONE
    } hum_state_e;

    hum_state_e current_state, next_state;
    logic [17:0] read_counter; // Longer delay for humidity sensor

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
        .read_write_n(1'b1),
        .write_data(8'h00),
        .read_data(current_state == HUM_READ_MSB ? read_data_msb : read_data_lsb),
        .transaction_done(transaction_done),
        .ack_error(ack_error),
        .scl(scl),
        .sda(sda)
    );

    // State machine (similar structure to temperature sensor)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= HUM_IDLE;
        end else if (!enable) begin
            current_state <= HUM_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;

        case (current_state)
            HUM_IDLE: begin
                if (read_counter == 0) begin
                    next_state = HUM_READ_MSB;
                end
            end
            HUM_READ_MSB: next_state = HUM_WAIT_MSB;
            HUM_WAIT_MSB: begin
                if (transaction_done || ack_error) next_state = HUM_READ_LSB;
            end
            HUM_READ_LSB: next_state = HUM_WAIT_LSB;
            HUM_WAIT_LSB: begin
                if (transaction_done || ack_error) next_state = HUM_PROCESS;
            end
            HUM_PROCESS: next_state = HUM_DONE;
            HUM_DONE: begin
                if (data_ready) next_state = HUM_IDLE;
            end
            default: next_state = HUM_IDLE;
        endcase
    end

    // Control logic - humidity sensors typically slower
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_read <= 1'b0;
            sensor_data <= '0;
            data_valid <= 1'b0;
            sensor_error <= 1'b0;
            read_counter <= 18'd200000; // ~2ms @ 100MHz (humidity sensors slower)
        end else begin
            case (current_state)
                HUM_IDLE: begin
                    start_read <= 1'b0;
                    data_valid <= 1'b0;
                    if (read_counter > 0) begin
                        read_counter <= read_counter - 1'b1;
                    end else begin
                        read_counter <= 18'd200000;
                    end
                end
                HUM_READ_MSB: start_read <= 1'b1;
                HUM_WAIT_MSB: begin
                    start_read <= 1'b0;
                    if (ack_error) sensor_error <= 1'b1;
                end
                HUM_READ_LSB: begin
                    start_read <= 1'b1;
                    sensor_error <= 1'b0;
                end
                HUM_WAIT_LSB: begin
                    start_read <= 1'b0;
                    if (ack_error) sensor_error <= 1'b1;
                end
                HUM_PROCESS: begin
                    if (!sensor_error) begin
                        sensor_data <= {read_data_msb, read_data_lsb};
                        data_valid <= 1'b1;
                    end
                end
                HUM_DONE: begin
                    if (data_ready) data_valid <= 1'b0;
                end
            endcase
        end
    end

endmodule : humidity_sensor_interface

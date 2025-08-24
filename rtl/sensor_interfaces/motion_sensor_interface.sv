//=============================================================================
// Motion Sensor Interface  
// Author: Prabhat Pandey
// Date: August 24, 2025
// Description: Wrapper for motion sensor with SPI interface (e.g., ADXL345)
//=============================================================================

import iot_sensor_pkg::*;

module motion_sensor_interface (
    // System interface
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,

    // Data interface
    output logic [15:0] sensor_data,
    output logic        data_valid,
    input  logic        data_ready,

    // SPI physical interface
    output logic        sclk,
    output logic        mosi,
    input  logic        miso,
    output logic        cs_n,

    // Motion interrupt (optional)
    input  logic        motion_int,

    // Status
    output logic        sensor_error
);

    // Internal signals
    logic start_read;
    logic transaction_done;
    logic [15:0] tx_data, rx_data;

    // State machine for motion sensor reading
    typedef enum logic [2:0] {
        MOT_IDLE,
        MOT_READ_X,
        MOT_WAIT_X,
        MOT_READ_Y,
        MOT_WAIT_Y,
        MOT_PROCESS,
        MOT_DONE
    } motion_state_e;

    motion_state_e current_state, next_state;
    logic [15:0] read_counter;
    logic [15:0] x_axis_data, y_axis_data;

    // SPI Master instance
    spi_master #(
        .SYSTEM_CLK_FREQ(SYSTEM_CLK_FREQ),
        .SPI_CLK_FREQ(SPI_CLK_FREQ),
        .DATA_WIDTH(16)
    ) spi_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .start_transaction(start_read),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .transaction_done(transaction_done),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n)
    );

    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= MOT_IDLE;
        end else if (!enable) begin
            current_state <= MOT_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // State transition logic
    always_comb begin
        next_state = current_state;

        case (current_state)
            MOT_IDLE: begin
                // Read every 1ms or on motion interrupt
                if (read_counter == 0 || motion_int) begin
                    next_state = MOT_READ_X;
                end
            end

            MOT_READ_X: begin
                next_state = MOT_WAIT_X;
            end

            MOT_WAIT_X: begin
                if (transaction_done) begin
                    next_state = MOT_READ_Y;
                end
            end

            MOT_READ_Y: begin
                next_state = MOT_WAIT_Y;
            end

            MOT_WAIT_Y: begin
                if (transaction_done) begin
                    next_state = MOT_PROCESS;
                end
            end

            MOT_PROCESS: begin
                next_state = MOT_DONE;
            end

            MOT_DONE: begin
                if (data_ready) begin
                    next_state = MOT_IDLE;
                end
            end

            default: next_state = MOT_IDLE;
        endcase
    end

    // Control logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_read <= 1'b0;
            tx_data <= '0;
            sensor_data <= '0;
            data_valid <= 1'b0;
            sensor_error <= 1'b0;
            read_counter <= 16'd100000; // ~1ms @ 100MHz
            x_axis_data <= '0;
            y_axis_data <= '0;
        end else begin
            case (current_state)
                MOT_IDLE: begin
                    start_read <= 1'b0;
                    data_valid <= 1'b0;
                    sensor_error <= 1'b0;
                    if (read_counter > 0 && !motion_int) begin
                        read_counter <= read_counter - 1'b1;
                    end else begin
                        read_counter <= 16'd100000; // Reset for next read
                    end
                end

                MOT_READ_X: begin
                    start_read <= 1'b1;
                    tx_data <= 16'h8032; // Read X-axis register (ADXL345)
                end

                MOT_WAIT_X: begin
                    start_read <= 1'b0;
                    if (transaction_done) begin
                        x_axis_data <= rx_data;
                    end
                end

                MOT_READ_Y: begin
                    start_read <= 1'b1;
                    tx_data <= 16'h8034; // Read Y-axis register
                end

                MOT_WAIT_Y: begin
                    start_read <= 1'b0;
                    if (transaction_done) begin
                        y_axis_data <= rx_data;
                    end
                end

                MOT_PROCESS: begin
                    // Calculate magnitude or use simple threshold
                    // For simplicity, use X-axis data with motion detection
                    if (x_axis_data > 16'h0100 || y_axis_data > 16'h0100) begin
                        sensor_data <= x_axis_data; // Motion detected
                        data_valid <= 1'b1;
                    end else begin
                        sensor_data <= 16'h0000; // No significant motion
                        data_valid <= 1'b1;
                    end
                end

                MOT_DONE: begin
                    if (data_ready) begin
                        data_valid <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule : motion_sensor_interface

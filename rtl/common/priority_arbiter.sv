//=============================================================================
// Priority Arbiter Module
// Author: Prabhat Pandey  
// Date: August 24, 2025
// Description: Priority-based arbiter for multi-sensor data aggregation
//=============================================================================

import iot_sensor_pkg::*;

module priority_arbiter (
    // System interface
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,

    // Sensor data inputs
    input  logic [15:0] temp_data,
    input  logic        temp_valid,
    output logic        temp_ready,

    input  logic [15:0] hum_data,
    input  logic        hum_valid,
    output logic        hum_ready,

    input  logic [15:0] motion_data,
    input  logic        motion_valid,
    output logic        motion_ready,

    // Aggregated output
    output logic [15:0] sensor_data,
    output logic [1:0]  sensor_id,
    output logic        data_valid,
    input  logic        data_ready,

    // Status
    output logic [2:0]  pending_sensors,
    output logic        overflow_error
);

    // Priority encoding: Motion > Temperature > Humidity
    // Motion    = 2'b10 (highest priority)
    // Temperature = 2'b00 (medium priority)  
    // Humidity  = 2'b01 (lowest priority)

    // Internal FIFOs for each sensor
    logic [15:0] temp_fifo_data, hum_fifo_data, motion_fifo_data;
    logic        temp_fifo_empty, hum_fifo_empty, motion_fifo_empty;
    logic        temp_fifo_full, hum_fifo_full, motion_fifo_full;
    logic        temp_fifo_rd, hum_fifo_rd, motion_fifo_rd;
    logic [2:0]  temp_fifo_count, hum_fifo_count, motion_fifo_count;

    // Temperature sensor FIFO
    sync_fifo #(
        .DATA_WIDTH(16),
        .DEPTH(FIFO_DEPTH),
        .ADDR_WIDTH(FIFO_ADDR_WIDTH)
    ) temp_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(temp_valid && !temp_fifo_full),
        .rd_en(temp_fifo_rd),
        .wr_data(temp_data),
        .rd_data(temp_fifo_data),
        .full(temp_fifo_full),
        .empty(temp_fifo_empty),
        .count(temp_fifo_count)
    );

    // Humidity sensor FIFO
    sync_fifo #(
        .DATA_WIDTH(16),
        .DEPTH(FIFO_DEPTH),
        .ADDR_WIDTH(FIFO_ADDR_WIDTH)
    ) hum_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(hum_valid && !hum_fifo_full),
        .rd_en(hum_fifo_rd),
        .wr_data(hum_data),
        .rd_data(hum_fifo_data),
        .full(hum_fifo_full),
        .empty(hum_fifo_empty),
        .count(hum_fifo_count)
    );

    // Motion sensor FIFO  
    sync_fifo #(
        .DATA_WIDTH(16),
        .DEPTH(FIFO_DEPTH),
        .ADDR_WIDTH(FIFO_ADDR_WIDTH)
    ) motion_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(motion_valid && !motion_fifo_full),
        .rd_en(motion_fifo_rd),
        .wr_data(motion_data),
        .rd_data(motion_fifo_data),
        .full(motion_fifo_full),
        .empty(motion_fifo_empty),
        .count(motion_fifo_count)
    );

    // Priority arbitration logic
    typedef enum logic [1:0] {
        ARB_IDLE,
        ARB_SELECT,
        ARB_OUTPUT,
        ARB_WAIT
    } arbiter_state_e;

    arbiter_state_e current_state, next_state;
    logic [1:0] selected_sensor;
    logic [15:0] selected_data;

    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= ARB_IDLE;
        end else if (!enable) begin
            current_state <= ARB_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // State transition and priority selection
    always_comb begin
        next_state = current_state;

        case (current_state)
            ARB_IDLE: begin
                if (!motion_fifo_empty || !temp_fifo_empty || !hum_fifo_empty) begin
                    next_state = ARB_SELECT;
                end
            end

            ARB_SELECT: begin
                next_state = ARB_OUTPUT;
            end

            ARB_OUTPUT: begin
                next_state = ARB_WAIT;
            end

            ARB_WAIT: begin
                if (data_ready) begin
                    next_state = ARB_IDLE;
                end
            end

            default: next_state = ARB_IDLE;
        endcase
    end

    // Priority selection logic
    always_comb begin
        // Default values
        temp_fifo_rd = 1'b0;
        hum_fifo_rd = 1'b0;
        motion_fifo_rd = 1'b0;
        selected_sensor = 2'b00;
        selected_data = 16'h0000;

        if (current_state == ARB_SELECT) begin
            // Priority: Motion > Temperature > Humidity
            if (!motion_fifo_empty) begin
                motion_fifo_rd = 1'b1;
                selected_sensor = SENSOR_MOTION;
                selected_data = motion_fifo_data;
            end else if (!temp_fifo_empty) begin
                temp_fifo_rd = 1'b1;
                selected_sensor = SENSOR_TEMPERATURE;
                selected_data = temp_fifo_data;
            end else if (!hum_fifo_empty) begin
                hum_fifo_rd = 1'b1;
                selected_sensor = SENSOR_HUMIDITY;
                selected_data = hum_fifo_data;
            end
        end
    end

    // Output control
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sensor_data <= '0;
            sensor_id <= '0;
            data_valid <= 1'b0;
            overflow_error <= 1'b0;
        end else begin
            case (current_state)
                ARB_IDLE: begin
                    data_valid <= 1'b0;
                    overflow_error <= 1'b0;
                end

                ARB_SELECT: begin
                    // Check for overflow conditions
                    overflow_error <= temp_fifo_full || hum_fifo_full || motion_fifo_full;
                end

                ARB_OUTPUT: begin
                    sensor_data <= selected_data;
                    sensor_id <= selected_sensor;
                    data_valid <= 1'b1;
                end

                ARB_WAIT: begin
                    if (data_ready) begin
                        data_valid <= 1'b0;
                    end
                end
            endcase
        end
    end

    // Ready signals - simple back-pressure
    assign temp_ready = !temp_fifo_full;
    assign hum_ready = !hum_fifo_full;
    assign motion_ready = !motion_fifo_full;

    // Status outputs
    assign pending_sensors = {!motion_fifo_empty, !temp_fifo_empty, !hum_fifo_empty};

    // Assertions for verification
    `ifdef SIMULATION
        always @(posedge clk) begin
            if (enable) begin
                // Check for data loss
                assert (!(temp_valid && temp_fifo_full)) 
                    else $warning("Temperature data lost due to FIFO overflow");
                assert (!(hum_valid && hum_fifo_full)) 
                    else $warning("Humidity data lost due to FIFO overflow");
                assert (!(motion_valid && motion_fifo_full)) 
                    else $warning("Motion data lost due to FIFO overflow");

                // Verify priority order
                if (data_valid) begin
                    if (!motion_fifo_empty) begin
                        assert (sensor_id == SENSOR_MOTION) 
                            else $error("Priority violation: Motion should have highest priority");
                    end else if (!temp_fifo_empty && motion_fifo_empty) begin
                        assert (sensor_id == SENSOR_TEMPERATURE) 
                            else $error("Priority violation: Temperature should be next priority");
                    end
                end
            end
        end
    `endif

endmodule : priority_arbiter

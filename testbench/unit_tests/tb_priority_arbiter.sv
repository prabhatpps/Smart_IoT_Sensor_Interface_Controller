//=============================================================================
// Priority Arbiter Unit Test  
// Author: Prabhat Pandey
// Date: August 24, 2025
//=============================================================================

`timescale 1ns/1ps

import iot_sensor_pkg::*;

module tb_priority_arbiter;

    logic        clk;
    logic        rst_n;
    logic        enable;
    logic [15:0] temp_data;
    logic        temp_valid;
    logic        temp_ready;
    logic [15:0] hum_data;
    logic        hum_valid;
    logic        hum_ready;
    logic [15:0] motion_data;
    logic        motion_valid;
    logic        motion_ready;
    logic [15:0] sensor_data;
    logic [1:0]  sensor_id;
    logic        data_valid;
    logic        data_ready;
    logic [2:0]  pending_sensors;
    logic        overflow_error;

    // Clock generation
    initial begin
        clk = 0;
        forever #5ns clk = ~clk;
    end

    // DUT
    priority_arbiter dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .temp_data(temp_data),
        .temp_valid(temp_valid),
        .temp_ready(temp_ready),
        .hum_data(hum_data),
        .hum_valid(hum_valid),
        .hum_ready(hum_ready),
        .motion_data(motion_data),
        .motion_valid(motion_valid),
        .motion_ready(motion_ready),
        .sensor_data(sensor_data),
        .sensor_id(sensor_id),
        .data_valid(data_valid),
        .data_ready(data_ready),
        .pending_sensors(pending_sensors),
        .overflow_error(overflow_error)
    );

    initial begin
        $display("=== Priority Arbiter Unit Test ===");

        rst_n = 0;
        enable = 0;
        temp_data = 0;
        temp_valid = 0;
        hum_data = 0;
        hum_valid = 0;
        motion_data = 0;
        motion_valid = 0;
        data_ready = 0;

        #20ns rst_n = 1;
        #10ns enable = 1;

        // Test priority: Motion > Temperature > Humidity
        $display("\nTest 1: Priority verification");

        @(posedge clk);
        temp_data = 16'h1234;
        temp_valid = 1;
        hum_data = 16'h5678;
        hum_valid = 1;
        motion_data = 16'h9ABC;
        motion_valid = 1;

        @(posedge clk);
        temp_valid = 0;
        hum_valid = 0;
        motion_valid = 0;

        // Wait for output
        wait(data_valid);
        $display("First output - Sensor ID: %0d, Data: 0x%04h", sensor_id, sensor_data);
        assert(sensor_id == SENSOR_MOTION) else $error("Priority violation: expected motion");

        @(posedge clk);
        data_ready = 1;
        @(posedge clk);
        data_ready = 0;

        wait(data_valid);
        $display("Second output - Sensor ID: %0d, Data: 0x%04h", sensor_id, sensor_data);
        assert(sensor_id == SENSOR_TEMPERATURE) else $error("Priority violation: expected temperature");

        @(posedge clk);
        data_ready = 1;
        @(posedge clk);
        data_ready = 0;

        wait(data_valid);
        $display("Third output - Sensor ID: %0d, Data: 0x%04h", sensor_id, sensor_data);
        assert(sensor_id == SENSOR_HUMIDITY) else $error("Priority violation: expected humidity");

        $display("\nPriority arbiter test completed successfully");
        $finish;
    end

    initial begin
        $dumpfile("arbiter_test.vcd");
        $dumpvars(0, tb_priority_arbiter);
    end

endmodule

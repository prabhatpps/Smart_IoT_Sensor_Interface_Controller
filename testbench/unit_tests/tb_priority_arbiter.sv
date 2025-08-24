//=============================================================================
// Priority Arbiter Testbench
//=============================================================================

`timescale 1ns/1ps

module tb_priority_arbiter();

    import iot_sensor_pkg::*;

    logic clk = 0;
    logic rst_n = 0;
    
    // Sensor requests
    logic temp_req = 0;
    logic hum_req = 0;
    logic motion_req = 0;
    
    // Grants
    logic temp_grant;
    logic hum_grant;
    logic motion_grant;
    
    // FIFO interfaces
    logic temp_fifo_empty = 1;
    logic hum_fifo_empty = 1;
    logic motion_fifo_empty = 1;
    
    logic [3:0] temp_count = 0;
    logic [3:0] hum_count = 0;
    logic [3:0] motion_count = 0;

    always #5 clk = ~clk;

    priority_arbiter dut (
        .clk(clk),
        .rst_n(rst_n),
        .temp_req(temp_req),
        .hum_req(hum_req),
        .motion_req(motion_req),
        .temp_grant(temp_grant),
        .hum_grant(hum_grant),
        .motion_grant(motion_grant),
        .temp_fifo_empty(temp_fifo_empty),
        .hum_fifo_empty(hum_fifo_empty),
        .motion_fifo_empty(motion_fifo_empty),
        .temp_count(temp_count),
        .hum_count(hum_count),
        .motion_count(motion_count)
    );

    initial begin
        $display("Priority Arbiter Unit Test Starting...");
        
        rst_n = 0;
        #100;
        rst_n = 1;
        #50;

        // Test priority: motion > temperature > humidity
        temp_req = 1;
        hum_req = 1;
        motion_req = 1;
        
        repeat(10) @(posedge clk);
        
        if (!motion_grant) $error("Motion should have highest priority");
        
        $display("✅ Priority Arbiter Unit Test Completed");
        #100;
        $finish;
    end

endmodule

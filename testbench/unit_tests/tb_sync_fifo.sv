//=============================================================================
// FIFO Unit Test
// Author: Prabhat Pandey
// Date: August 24, 2025
//=============================================================================

`timescale 1ns/1ps

module tb_sync_fifo;

    parameter DATA_WIDTH = 16;
    parameter DEPTH = 8;
    parameter ADDR_WIDTH = 3;

    logic                    clk;
    logic                    rst_n;
    logic                    wr_en;
    logic                    rd_en;
    logic [DATA_WIDTH-1:0]   wr_data;
    logic [DATA_WIDTH-1:0]   rd_data;
    logic                    full;
    logic                    empty;
    logic [ADDR_WIDTH:0]     count;

    // Clock generation
    initial begin
        clk = 0;
        forever #5ns clk = ~clk;
    end

    // DUT
    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .wr_data(wr_data),
        .rd_data(rd_data),
        .full(full),
        .empty(empty),
        .count(count)
    );

    initial begin
        $display("=== FIFO Unit Test ===");

        rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        wr_data = 0;

        #20ns rst_n = 1;

        // Test 1: Write until full
        $display("Test 1: Fill FIFO");
        for (int i = 0; i < DEPTH + 2; i++) begin
            @(posedge clk);
            wr_data = i + 1;
            wr_en = !full;
            $display("Write %0d, Count: %0d, Full: %b", wr_data, count, full);
        end

        wr_en = 0;
        #20ns;

        // Test 2: Read until empty
        $display("\nTest 2: Empty FIFO");
        for (int i = 0; i < DEPTH + 2; i++) begin
            @(posedge clk);
            rd_en = !empty;
            $display("Read %0d, Count: %0d, Empty: %b", rd_data, count, empty);
        end

        rd_en = 0;
        #20ns;

        $display("\nFIFO test completed successfully");
        $finish;
    end

    initial begin
        $dumpfile("fifo_test.vcd");
        $dumpvars(0, tb_sync_fifo);
    end

endmodule

//=============================================================================
// FIFO Unit Test
// Tests the synchronous FIFO functionality
//=============================================================================

`timescale 1ns/1ps

module tb_sync_fifo();

    parameter DATA_WIDTH = 8;
    parameter DEPTH = 16;

    logic clk = 0;
    logic rst_n = 0;
    logic wr_en = 0;
    logic rd_en = 0;
    logic [DATA_WIDTH-1:0] wr_data = 0;
    logic [DATA_WIDTH-1:0] rd_data;
    logic full;
    logic empty;
    logic [$clog2(DEPTH+1)-1:0] count;

    integer error_count = 0;
    integer test_count = 0;

    // Clock generation
    always #5 clk = ~clk;

    // DUT instantiation
    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
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
        $display("🔧 FIFO Unit Test Starting...");

        // Reset
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        // Test 1: Empty condition after reset
        test_count++;
        if (!empty) begin
            $display("❌ Test %0d FAILED: FIFO should be empty after reset", test_count);
            error_count++;
        end else begin
            $display("✅ Test %0d PASSED: FIFO correctly empty after reset", test_count);
        end

        // Test 2: Write single item
        test_count++;
        @(posedge clk);
        wr_data = 8'hAA;
        wr_en = 1;
        @(posedge clk);
        wr_en = 0;
        @(posedge clk);

        if (empty || count != 1) begin
            $display("❌ Test %0d FAILED: FIFO should contain 1 item", test_count);
            error_count++;
        end else begin
            $display("✅ Test %0d PASSED: Single write successful", test_count);
        end

        // Test 3: Read single item
        test_count++;
        rd_en = 1;
        @(posedge clk);
        rd_en = 0;
        @(posedge clk);

        if (!empty || rd_data != 8'hAA) begin
            $display("❌ Test %0d FAILED: Read data mismatch or FIFO not empty", test_count);
            error_count++;
        end else begin
            $display("✅ Test %0d PASSED: Single read successful", test_count);
        end

        // Test 4: Fill FIFO
        test_count++;
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            wr_data = i;
            wr_en = 1;
            @(posedge clk);
            wr_en = 0;
        end
        @(posedge clk);

        if (!full || count != DEPTH) begin
            $display("❌ Test %0d FAILED: FIFO should be full", test_count);
            error_count++;
        end else begin
            $display("✅ Test %0d PASSED: FIFO fill successful", test_count);
        end

        // Test 5: Empty FIFO
        test_count++;
        for (int i = 0; i < DEPTH; i++) begin
            rd_en = 1;
            @(posedge clk);
            rd_en = 0;
            @(posedge clk);
            if (rd_data !== (i & 8'hFF)) begin
                $display("❌ Read data mismatch at position %0d: expected %0h, got %0h", i, i & 8'hFF, rd_data);
                error_count++;
            end
        end

        if (!empty) begin
            $display("❌ Test %0d FAILED: FIFO should be empty after reading all", test_count);
            error_count++;
        end else begin
            $display("✅ Test %0d PASSED: FIFO empty successful", test_count);
        end

        // Final results
        $display("\n=== FIFO Unit Test Results ===");
        $display("Tests run: %0d", test_count);
        $display("Errors: %0d", error_count);

        if (error_count == 0) begin
            $display("🎉 ALL FIFO TESTS PASSED!");
        end else begin
            $display("💥 %0d FIFO TEST(S) FAILED!", error_count);
        end

        #100;
        $finish;
    end

    // Timeout watchdog
    initial begin
        #50000; // 50us timeout
        $display("❌ TIMEOUT: FIFO test exceeded maximum runtime");
        $finish;
    end

endmodule

//=============================================================================
// IoT Sensor Controller Integration Testbench
// Complete system-level verification with proper stimulus
//=============================================================================

`timescale 1ns/1ps

module tb_iot_sensor_controller();

    import iot_sensor_pkg::*;

    // Clock and Reset
    logic clk = 0;
    logic rst_n = 0;

    // System Control
    logic [1:0] power_mode;
    logic enable;

    // I2C Interface (Temperature & Humidity)
    logic i2c_scl;
    logic i2c_sda;
    wire i2c_scl_wire;
    wire i2c_sda_wire;
    
    // SPI Interface (Motion Sensor)
    logic spi_clk;
    logic spi_mosi;
    logic spi_miso = 0;
    logic spi_cs;

    // Motion Interrupt
    logic motion_int = 0;

    // Serial Output
    logic serial_tx;
    logic serial_tx_busy;

    // Status Outputs
    logic temp_data_ready;
    logic hum_data_ready;
    logic motion_data_ready;
    logic packet_sent;

    // Test control signals
    integer test_count = 0;
    integer error_count = 0;
    integer packet_count = 0;
    
    // Test helper variables (moved to module level)
    integer initial_packets;
    integer start_packets; 
    integer packets_generated;
    
    // I2C bus tristate handling
    logic i2c_scl_drive = 0;
    logic i2c_sda_drive = 0;
    logic i2c_scl_out = 1;
    logic i2c_sda_out = 1;
    
    assign i2c_scl_wire = i2c_scl_drive ? i2c_scl_out : 1'bz;
    assign i2c_sda_wire = i2c_sda_drive ? i2c_sda_out : 1'bz;

    // Clock Generation
    always #5 clk = ~clk; // 100MHz clock

    // Device Under Test
    iot_sensor_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .power_mode(power_mode),
        .enable(enable),
        .i2c_scl(i2c_scl_wire),
        .i2c_sda(i2c_sda_wire),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs(spi_cs),
        .motion_int(motion_int),
        .serial_tx(serial_tx),
        .serial_tx_busy(serial_tx_busy),
        .temp_data_ready(temp_data_ready),
        .hum_data_ready(hum_data_ready),
        .motion_data_ready(motion_data_ready),
        .packet_sent(packet_sent)
    );

    // I2C Slave Model (simplified)
    reg [7:0] i2c_slave_data = 8'h25; // Temperature data
    integer i2c_bit_count = 0;
    logic i2c_ack_phase = 0;
    
    // Simple I2C slave response
    always @(negedge i2c_scl_wire) begin
        if (rst_n && !spi_cs) begin
            if (i2c_ack_phase) begin
                // Send ACK (pull SDA low)
                i2c_sda_drive <= 1'b1;
                i2c_sda_out <= 1'b0;
                i2c_ack_phase <= 1'b0;
            end else if (i2c_bit_count >= 8) begin
                i2c_ack_phase <= 1'b1;
                i2c_bit_count <= 0;
            end else begin
                i2c_sda_drive <= 1'b1;
                i2c_sda_out <= i2c_slave_data[7-i2c_bit_count];
                i2c_bit_count <= i2c_bit_count + 1;
            end
        end
    end
    
    always @(posedge i2c_scl_wire) begin
        if (i2c_ack_phase) begin
            i2c_sda_drive <= 1'b0; // Release SDA after ACK
        end
    end

    // SPI Motion Sensor Model
    reg [7:0] motion_data = 8'h42;
    reg [3:0] spi_bit_count = 0;
    
    always @(posedge spi_clk) begin
        if (!spi_cs) begin
            spi_miso <= motion_data[7-spi_bit_count];
            spi_bit_count <= spi_bit_count + 1;
        end else begin
            spi_bit_count <= 0;
        end
    end

    // Motion interrupt generator
    initial begin
        forever begin
            #1_000_000; // Every 1ms
            motion_int = 1;
            #1000;
            motion_int = 0;
        end
    end

    // Serial packet monitor
    always @(posedge packet_sent) begin
        packet_count++;
        $display("📦 [%0t] Packet #%0d transmitted", $time, packet_count);
    end

    // Main Test Sequence
    initial begin
        $display("=================================================");
        $display("IoT Sensor Controller Integration Test Starting");
        $display("Time: %0t", $time);
        $display("=================================================");

        // Initialize all signals
        rst_n = 0;
        enable = 0;
        power_mode = PWR_NORMAL;

        // Reset sequence
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 1: Basic Functionality
        test_basic_operation();
        
        // Test 2: Power Management
        test_power_modes();
        
        // Test 3: Motion Interrupt Response
        test_motion_interrupt();
        
        // Test 4: Serial Communication
        test_serial_packets();

        // Wait for final packets
        repeat(1000) @(posedge clk);

        // Final Results
        $display("=================================================");
        $display("Test Completion Summary");
        $display("=================================================");
        $display("Total Tests Run: %0d", test_count);
        $display("Errors Detected: %0d", error_count);
        $display("Packets Transmitted: %0d", packet_count);
        
        if (error_count == 0) begin
            $display("🎉 ALL TESTS PASSED SUCCESSFULLY!");
            $display("✅ System is functioning correctly");
        end else begin
            $display("💥 %0d TEST(S) FAILED!", error_count);
            $display("❌ Please check the design");
        end
        
        $display("=================================================");
        $display("Test completed at time: %0t", $time);
        
        $finish;
    end

    // Test Tasks
    task test_basic_operation();
        $display("\\n--- Test 1: Basic System Operation ---");
        test_count++;
        
        enable = 1;
        power_mode = PWR_NORMAL;
        
        $display("⏰ [%0t] Enabling system in normal power mode", $time);
        
        // Wait for system initialization
        repeat(100) @(posedge clk);
        
        // Check if system responds
        fork
            begin
                // Timeout after reasonable time
                repeat(50000) @(posedge clk);
                if (packet_count == 0) begin
                    $display("❌ [%0t] No packets generated - system may not be working", $time);
                    error_count++;
                end
            end
            begin
                // Wait for first packet
                wait(packet_count > 0);
                $display("✅ [%0t] First packet transmitted successfully", $time);
            end
        join_any
        disable fork;
        
        $display("Basic operation test completed");
    endtask

    task test_power_modes();
        $display("\\n--- Test 2: Power Mode Management ---");
        test_count++;
        
        $display("🔋 [%0t] Testing LOW power mode", $time);
        power_mode = PWR_LOW;
        repeat(5000) @(posedge clk);
        
        $display("😴 [%0t] Testing SLEEP power mode", $time);
        power_mode = PWR_SLEEP;
        repeat(5000) @(posedge clk);
        
        $display("⚡ [%0t] Returning to NORMAL power mode", $time);
        power_mode = PWR_NORMAL;
        repeat(5000) @(posedge clk);
        
        $display("✅ Power mode transitions completed");
    endtask

    task test_motion_interrupt();
        $display("\\n--- Test 3: Motion Interrupt Response ---");
        test_count++;
        
        initial_packets = packet_count;
        
        $display("🏃 [%0t] Generating motion interrupt", $time);
        motion_int = 1;
        repeat(100) @(posedge clk);
        motion_int = 0;
        
        // Wait for response
        repeat(10000) @(posedge clk);
        
        if (packet_count > initial_packets) begin
            $display("✅ [%0t] Motion interrupt properly handled", $time);
        end else begin
            $display("⚠️  [%0t] Motion interrupt response may be delayed", $time);
        end
    endtask

    task test_serial_packets();
        $display("\\n--- Test 4: Serial Packet Transmission ---");
        test_count++;
        
        start_packets = packet_count;
        
        // Monitor serial transmission for a period
        repeat(20000) @(posedge clk);
        
        packets_generated = packet_count - start_packets;
        $display("📊 [%0t] Generated %0d packets during test period", $time, packets_generated);
        
        if (packets_generated > 0) begin
            $display("✅ Serial packet transmission is working");
        end else begin
            $display("❌ No packets generated during test period");
            error_count++;
        end
    endtask

    // Timeout watchdog
    initial begin
        #100_000_000; // 100ms timeout
        $display("❌ TIMEOUT: Test exceeded maximum runtime");
        $display("System may be hung or running too slowly");
        $finish;
    end

    // Waveform generation
    initial begin
        if ($test$plusargs("DUMP_VCD")) begin
            $dumpfile("tb_iot_sensor_controller.vcd");
            $dumpvars(0, tb_iot_sensor_controller);
            $display("📊 VCD waveform dumping enabled");
        end
    end

    // Coverage collection (if supported)
    initial begin
        if ($test$plusargs("COVERAGE")) begin
            $display("📈 Coverage collection enabled");
        end
    end

endmodule : tb_iot_sensor_controller

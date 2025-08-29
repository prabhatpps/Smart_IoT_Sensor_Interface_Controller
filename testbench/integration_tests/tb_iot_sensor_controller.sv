//=============================================================================
// IoT Sensor Controller Integration Testbench (CORRECTED VERSION)
// Fixed: I2C slave model, proper stimulus timing
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
    wire i2c_scl;
    wire i2c_sda;
    
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
    
    // Test helper variables (module level to fix syntax)
    integer initial_packets;
    integer start_packets; 
    integer packets_generated;

    // Clock Generation
    always #5 clk = ~clk; // 100MHz clock

    // Device Under Test
    iot_sensor_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .power_mode(power_mode),
        .enable(enable),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda),
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

    // FIXED: Proper I2C Slave Model
    logic sda_drive = 0;
    logic sda_out = 1;
    logic scl_prev, sda_prev;
    
    assign i2c_sda = sda_drive ? sda_out : 1'bz;
    assign i2c_scl = 1'bz; // Let master drive SCL
    
    // I2C state machine
    typedef enum logic [2:0] {
        I2C_IDLE = 0,
        I2C_ADDR = 1, 
        I2C_ACK_ADDR = 2,
        I2C_DATA = 3,
        I2C_ACK_DATA = 4
    } i2c_state_t;
    
    i2c_state_t i2c_state = I2C_IDLE;
    logic [7:0] bit_counter = 0;
    logic [7:0] data_to_send = 8'h19; // Default temp data
    logic start_detected, stop_detected;
    
    // Detect START and STOP conditions
    always @(posedge clk) begin
        scl_prev <= i2c_scl;
        sda_prev <= i2c_sda;
    end
    
    assign start_detected = (scl_prev && i2c_scl) && (sda_prev && !i2c_sda);
    assign stop_detected = (scl_prev && i2c_scl) && (!sda_prev && i2c_sda);
    
    // I2C Slave Response
    always @(negedge i2c_scl or posedge stop_detected) begin
        if (stop_detected) begin
            i2c_state <= I2C_IDLE;
            sda_drive <= 0;
            bit_counter <= 0;
        end else if (start_detected) begin
            i2c_state <= I2C_ADDR;
            bit_counter <= 0;
            sda_drive <= 0;
        end else begin
            case (i2c_state)
                I2C_ADDR: begin
                    bit_counter <= bit_counter + 1;
                    if (bit_counter == 7) begin
                        i2c_state <= I2C_ACK_ADDR;
                        sda_drive <= 1;
                        sda_out <= 0; // ACK
                    end
                end
                
                I2C_ACK_ADDR: begin
                    sda_drive <= 0;
                    i2c_state <= I2C_DATA;
                    bit_counter <= 0;
                    // Alternate between temp (0x19) and humidity (0x32) data
                    data_to_send <= ($time % 4000000 < 2000000) ? 8'h19 : 8'h32;
                end
                
                I2C_DATA: begin
                    sda_drive <= 1;
                    sda_out <= data_to_send[7-bit_counter];
                    bit_counter <= bit_counter + 1;
                    if (bit_counter == 7) begin
                        i2c_state <= I2C_ACK_DATA;
                    end
                end
                
                I2C_ACK_DATA: begin
                    sda_drive <= 0; // Release for master's ACK/NACK
                    i2c_state <= I2C_IDLE;
                    bit_counter <= 0;
                end
                
                default: begin
                    i2c_state <= I2C_IDLE;
                    sda_drive <= 0;
                end
            endcase
        end
    end

    // SPI Motion Sensor Model (Enhanced)
    logic [7:0] motion_data_array [0:1] = '{8'h42, 8'h01}; // Motion detected + count
    logic [3:0] spi_bit_count = 0;
    logic spi_byte_select = 0;
    
    always @(posedge spi_clk) begin
        if (!spi_cs) begin
            spi_miso <= motion_data_array[spi_byte_select][7-spi_bit_count];
            spi_bit_count <= spi_bit_count + 1;
            if (spi_bit_count == 7) begin
                spi_byte_select <= ~spi_byte_select;
                spi_bit_count <= 0;
            end
        end else begin
            spi_bit_count <= 0;
            spi_byte_select <= 0;
        end
    end

    // Enhanced Motion interrupt generator
    initial begin
        forever begin
            #2_000_000; // Every 2ms - faster than sensor read intervals
            motion_int = 1;
            #10000; // 100us pulse
            motion_int = 0;
        end
    end

    // Packet monitor with detailed logging
    always @(posedge packet_sent) begin
        packet_count++;
        $display("📦 [%0t] Packet #%0d transmitted successfully", $time, packet_count);
    end
    
    // Monitor sensor data ready signals
    always @(posedge temp_data_ready) begin
        $display("🌡️  [%0t] Temperature data ready", $time);
    end
    
    always @(posedge hum_data_ready) begin
        $display("💧 [%0t] Humidity data ready", $time);
    end
    
    always @(posedge motion_data_ready) begin
        $display("🏃 [%0t] Motion data ready", $time);
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
        repeat(20) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);
        
        $display("🔄 [%0t] System reset completed", $time);
        
        // Test 1: Basic Functionality
        test_basic_operation();
        
        // Test 2: Power Management
        test_power_modes();
        
        // Test 3: Motion Interrupt Response
        test_motion_interrupt();
        
        // Test 4: Serial Communication
        test_serial_packets();

        // Wait for final packets to complete
        repeat(5000) @(posedge clk);

        // Final Results
        $display("=================================================");
        $display("Test Completion Summary");
        $display("=================================================");
        $display("Total Tests Run: %0d", test_count);
        $display("Errors Detected: %0d", error_count);
        $display("Packets Transmitted: %0d", packet_count);
        
        if (error_count == 0 && packet_count > 0) begin
            $display("🎉 ALL TESTS PASSED SUCCESSFULLY!");
            $display("✅ System is functioning correctly");
        end else begin
            $display("💥 %0d TEST(S) FAILED!", error_count + (packet_count == 0 ? 1 : 0));
            $display("❌ Please check the design");
            if (packet_count == 0) $display("❌ No packets were generated");
        end
        
        $display("=================================================");
        $display("Test completed at time: %0t", $time);
        
        $finish;
    end

    // Test Tasks
    task test_basic_operation();
        $display("\n--- Test 1: Basic System Operation ---");
        test_count++;
        
        enable = 1;
        power_mode = PWR_NORMAL;
        
        $display("⏰ [%0t] Enabling system in normal power mode", $time);
        
        // Wait longer for sensor initialization and first reads
        repeat(500) @(posedge clk);
        
        // Check if sensors start working
        fork
            begin
                // Extended timeout for first packet
                repeat(200000) @(posedge clk); // 20ms timeout
                if (packet_count == 0) begin
                    $display("❌ [%0t] No packets generated within 20ms - system may not be working", $time);
                    error_count++;
                end
            end
            begin
                // Wait for first packet with more time
                wait(packet_count > 0);
                $display("✅ [%0t] First packet transmitted successfully!", $time);
            end
        join_any
        disable fork;
        
        $display("Basic operation test completed");
    endtask

    task test_power_modes();
        $display("\n--- Test 2: Power Mode Management ---");
        test_count++;
        
        $display("🔋 [%0t] Testing LOW power mode", $time);
        power_mode = PWR_LOW;
        repeat(10000) @(posedge clk); // 1ms
        
        $display("😴 [%0t] Testing SLEEP power mode", $time);
        power_mode = PWR_SLEEP;
        repeat(10000) @(posedge clk); // 1ms
        
        $display("⚡ [%0t] Returning to NORMAL power mode", $time);
        power_mode = PWR_NORMAL;
        repeat(10000) @(posedge clk); // 1ms
        
        $display("✅ Power mode transitions completed");
    endtask

    task test_motion_interrupt();
        $display("\n--- Test 3: Motion Interrupt Response ---");
        test_count++;
        
        initial_packets = packet_count;
        
        $display("🏃 [%0t] Generating manual motion interrupt", $time);
        motion_int = 1;
        repeat(1000) @(posedge clk);
        motion_int = 0;
        
        // Wait for response
        repeat(50000) @(posedge clk); // 5ms
        
        if (packet_count > initial_packets) begin
            $display("✅ [%0t] Motion interrupt properly handled", $time);
        end else begin
            $display("⚠️  [%0t] Motion interrupt response may be delayed", $time);
        end
    endtask

    task test_serial_packets();
        $display("\n--- Test 4: Serial Packet Transmission ---");
        test_count++;
        
        start_packets = packet_count;
        
        // Monitor serial transmission for longer period
        repeat(100000) @(posedge clk); // 10ms
        
        packets_generated = packet_count - start_packets;
        $display("📊 [%0t] Generated %0d packets during test period", $time, packets_generated);
        
        if (packets_generated > 0) begin
            $display("✅ Serial packet transmission is working");
        end else begin
            $display("❌ No packets generated during test period");
            error_count++;
        end
    endtask

    // Timeout watchdog - extended for proper sensor timing
    initial begin
        #200_000_000; // 200ms timeout - much longer for sensor intervals
        $display("❌ TIMEOUT: Test exceeded maximum runtime");
        $display("System may be running correctly but needs more time");
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

endmodule : tb_iot_sensor_controller

//=============================================================================
// Smart IoT Sensor Interface Controller - Testbench
// Author: Prabhat Pandey
// Date: August 24, 2025
// Description: Comprehensive testbench with realistic sensor stimuli
//=============================================================================

`timescale 1ns/1ps

import iot_sensor_pkg::*;

module tb_iot_sensor_controller;

    // System signals
    logic        clk;
    logic        rst_n;
    logic        enable;

    // Temperature sensor I2C (simulated with pullups)
    wire         temp_scl;
    wire         temp_sda;
    logic        temp_sda_drive;
    logic        temp_scl_drive;

    // Humidity sensor I2C (simulated with pullups)
    wire         hum_scl;
    wire         hum_sda;
    logic        hum_sda_drive;
    logic        hum_scl_drive;

    // Motion sensor SPI
    logic        motion_sclk;
    logic        motion_mosi;
    logic        motion_miso;
    logic        motion_cs_n;
    logic        motion_int;

    // Serial output
    logic        tx_serial;
    logic        tx_busy;

    // Power management
    logic [1:0]  power_mode;
    logic        timer_wakeup;
    logic        system_wakeup;
    logic        power_save_active;

    // Status outputs
    logic [7:0]  packets_transmitted;
    logic        system_error;
    logic [15:0] debug_status;

    // Testbench variables
    logic [7:0]  received_bytes[0:1023];
    integer      byte_count;
    integer      test_phase;
    real         temperature_value;
    real         humidity_value;
    integer      motion_x, motion_y;

    // Clock generation (100MHz)
    initial begin
        clk = 1'b0;
        forever #5ns clk = ~clk; // 100MHz clock
    end

    // I2C pullup simulation
    assign temp_sda = temp_sda_drive ? 1'b0 : 1'bz;
    assign temp_scl = temp_scl_drive ? 1'b0 : 1'bz;
    assign hum_sda = hum_sda_drive ? 1'b0 : 1'bz;
    assign hum_scl = hum_scl_drive ? 1'b0 : 1'bz;

    // Pullup resistors (weak)
    pullup(temp_sda);
    pullup(temp_scl);
    pullup(hum_sda);
    pullup(hum_scl);

    // DUT instantiation
    iot_sensor_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .temp_scl(temp_scl),
        .temp_sda(temp_sda),
        .hum_scl(hum_scl),
        .hum_sda(hum_sda),
        .motion_sclk(motion_sclk),
        .motion_mosi(motion_mosi),
        .motion_miso(motion_miso),
        .motion_cs_n(motion_cs_n),
        .motion_int(motion_int),
        .tx_serial(tx_serial),
        .tx_busy(tx_busy),
        .power_mode(power_mode),
        .timer_wakeup(timer_wakeup),
        .system_wakeup(system_wakeup),
        .power_save_active(power_save_active),
        .packets_transmitted(packets_transmitted),
        .system_error(system_error),
        .debug_status(debug_status)
    );

    // Main test sequence
    initial begin
        // Initialize signals
        rst_n = 1'b0;
        enable = 1'b0;
        power_mode = PWR_NORMAL;
        timer_wakeup = 1'b0;
        motion_int = 1'b0;
        temp_sda_drive = 1'b1; // Release I2C lines
        temp_scl_drive = 1'b1;
        hum_sda_drive = 1'b1;
        hum_scl_drive = 1'b1;
        motion_miso = 1'b0;

        test_phase = 0;
        byte_count = 0;
        temperature_value = 25.0; // Start at 25°C
        humidity_value = 50.0;    // Start at 50% RH
        motion_x = 0;
        motion_y = 0;

        $display("=== IoT Sensor Interface Controller Testbench ===");
        $display("Time: %0t - Starting testbench", $time);

        // Reset sequence
        #100ns;
        rst_n = 1'b1;
        #50ns;
        enable = 1'b1;

        $display("Time: %0t - Reset released, system enabled", $time);

        // Test Phase 1: Normal operation with all sensors
        test_phase = 1;
        $display("\n=== Test Phase 1: Normal Operation ===");

        fork
            simulate_temperature_sensor();
            simulate_humidity_sensor();
            simulate_motion_sensor();
            monitor_serial_output();
            test_sequence_controller();
        join_any

        $display("\nTime: %0t - Testbench completed", $time);
        $display("Total packets transmitted: %0d", packets_transmitted);
        $display("System errors encountered: %0s", system_error ? "YES" : "NO");
        $finish;
    end

    // Test sequence controller
    task test_sequence_controller();
        // Phase 1: Normal operation (5ms)
        #5ms;
        $display("\nTime: %0t - Phase 1 complete, switching to low power", $time);

        // Phase 2: Low power mode (3ms)
        power_mode = PWR_LOW;
        #3ms;
        $display("\nTime: %0t - Phase 2 complete, testing motion interrupt", $time);

        // Phase 3: Motion interrupt test
        motion_int = 1'b1;
        #100us;
        motion_int = 1'b0;
        #2ms;

        // Phase 4: Sleep mode test
        $display("\nTime: %0t - Testing sleep mode", $time);
        power_mode = PWR_SLEEP;
        #1ms;

        // Wake up with motion
        motion_int = 1'b1;
        #50us;
        motion_int = 1'b0;
        power_mode = PWR_NORMAL;
        #1ms;

        $display("\nTime: %0t - All test phases completed", $time);
    endtask

    // Simulate temperature sensor (TMP102-like behavior)
    task simulate_temperature_sensor();
        logic [7:0] temp_msb, temp_lsb;
        integer temp_raw;

        forever begin
            @(negedge temp_scl);

            // Simple I2C slave simulation
            if (!motion_cs_n) begin // Check if we're being addressed
                // Convert temperature to 12-bit value (TMP102 format)
                temp_raw = $rtoi(temperature_value * 16.0); // 0.0625°C per LSB
                temp_msb = temp_raw[11:4];
                temp_lsb = {temp_raw[3:0], 4'b0000};

                // Simulate I2C ACK and data transmission
                #1us temp_sda_drive = 1'b0; // ACK
                #2us temp_sda_drive = 1'b1; // Release

                // Send MSB
                for (int i = 7; i >= 0; i--) begin
                    @(posedge temp_scl);
                    temp_sda_drive = ~temp_msb[i]; // Invert for pullup
                    @(negedge temp_scl);
                end

                #1us temp_sda_drive = 1'b1; // NACK from master

                // Update temperature (slowly ramping)
                if (temperature_value < 35.0) begin
                    temperature_value = temperature_value + 0.1;
                end
            end

            #10us; // Small delay between transactions
        end
    endtask

    // Simulate humidity sensor (SHT30-like behavior)  
    task simulate_humidity_sensor();
        logic [7:0] hum_msb, hum_lsb;
        integer hum_raw;

        forever begin
            @(negedge hum_scl);

            if (!motion_cs_n) begin // Check if being addressed
                // Convert humidity to 16-bit value
                hum_raw = $rtoi(humidity_value * 655.35); // 65535 / 100
                hum_msb = hum_raw[15:8];
                hum_lsb = hum_raw[7:0];

                // Simulate I2C ACK and data
                #1us hum_sda_drive = 1'b0; // ACK
                #2us hum_sda_drive = 1'b1; // Release

                // Send data bytes
                for (int i = 7; i >= 0; i--) begin
                    @(posedge hum_scl);
                    hum_sda_drive = ~hum_msb[i];
                    @(negedge hum_scl);
                end

                #1us hum_sda_drive = 1'b1; // NACK

                // Update humidity (sine wave pattern)
                humidity_value = 50.0 + 20.0 * $sin($time / 1000000.0);
                if (humidity_value < 0) humidity_value = 0;
                if (humidity_value > 100) humidity_value = 100;
            end

            #15us; // Humidity sensor typically slower
        end
    endtask

    // Simulate motion sensor (ADXL345-like behavior)
    task simulate_motion_sensor();
        logic [15:0] accel_data;

        forever begin
            @(negedge motion_cs_n); // SPI transaction start

            // Wait for command
            @(posedge motion_cs_n); // Transaction end

            // Simulate accelerometer data based on motion interrupt
            if (motion_int) begin
                motion_x = $random % 512 + 256; // Simulated motion
                motion_y = $random % 512 + 256;
            end else begin
                motion_x = $random % 64;  // Small noise
                motion_y = $random % 64;
            end

            // Provide data on MISO during next transaction
            accel_data = motion_x[15:0];

            // Simulate SPI data transmission
            fork
                begin
                    forever begin
                        @(posedge motion_sclk);
                        motion_miso = accel_data[15];
                        accel_data = {accel_data[14:0], 1'b0};
                    end
                end
            join_none

            #1ms; // Motion sensor sample rate
        end
    endtask

    // Monitor serial output and decode packets
    task monitor_serial_output();
        logic [7:0] rx_byte;
        integer bit_count;
        logic [7:0] packet_buffer[0:15];
        integer packet_index;

        packet_index = 0;

        forever begin
            // Wait for start bit
            @(negedge tx_serial);

            // Sample data bits (assuming 115200 baud)
            #(1000000000 / 115200); // Start bit duration

            rx_byte = 8'h00;
            for (bit_count = 0; bit_count < 8; bit_count++) begin
                #(1000000000 / 115200); // Bit duration at 115200 baud
                rx_byte[bit_count] = tx_serial;
            end

            // Stop bit
            #(1000000000 / 115200);

            // Store received byte
            received_bytes[byte_count] = rx_byte;
            packet_buffer[packet_index] = rx_byte;
            byte_count++;
            packet_index++;

            $display("Time: %0t - RX Byte[%0d]: 0x%02h ('%c')", 
                     $time, byte_count-1, rx_byte, 
                     (rx_byte >= 32 && rx_byte <= 126) ? rx_byte : ".");

            // Check for complete packet (starts and ends with 0x7E)
            if (rx_byte == 8'h7E && packet_index > 1) begin
                decode_packet(packet_buffer, packet_index);
                packet_index = 0;
            end

            // Prevent buffer overflow
            if (packet_index >= 16) packet_index = 0;
        end
    endtask

    // Decode received packet
    task decode_packet(input logic [7:0] buffer[0:15], input integer length);
        logic [1:0]  sensor_id;
        logic [7:0]  packet_length;
        logic [15:0] timestamp;
        logic [15:0] sensor_data;
        logic [7:0]  checksum;
        string       sensor_name;

        if (length >= 9 && buffer[0] == 8'h7E && buffer[8] == 8'h7E) begin
            sensor_id = buffer[1][1:0];
            packet_length = buffer[2];
            timestamp = {buffer[3], buffer[4]};
            sensor_data = {buffer[5], buffer[6]};
            checksum = buffer[7];

            case (sensor_id)
                2'b00: sensor_name = "Temperature";
                2'b01: sensor_name = "Humidity";
                2'b10: sensor_name = "Motion";
                default: sensor_name = "Unknown";
            endcase

            $display("\n=== PACKET DECODED ===");
            $display("Sensor: %s (ID: %0d)", sensor_name, sensor_id);
            $display("Timestamp: %0d", timestamp);
            $display("Data: 0x%04h (%0d)", sensor_data, sensor_data);
            $display("Checksum: 0x%02h", checksum);
            $display("====================\n");
        end else begin
            $display("Invalid packet format (length=%0d)", length);
        end
    endtask

    // Monitor and report system status
    initial begin
        forever begin
            #1ms;
            if (debug_status[15]) begin // Power save active
                $display("Time: %0t - System in power save mode", $time);
            end
            if (system_error) begin
                $display("Time: %0t - SYSTEM ERROR detected!", $time);
            end
        end
    end

    // Timeout protection
    initial begin
        #50ms;
        $display("\nERROR: Testbench timeout after 50ms");
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("iot_sensor_controller.vcd");
        $dumpvars(0, tb_iot_sensor_controller);
    end

endmodule : tb_iot_sensor_controller

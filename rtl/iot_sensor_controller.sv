//=============================================================================
// Smart IoT Sensor Interface Controller - Top Level
// Author: Prabhat Pandey
// Date: August 24, 2025
// Description: Top-level integration of all sensor interface modules
//=============================================================================

import iot_sensor_pkg::*;

module iot_sensor_controller (
    // System clock and reset
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,

    // Temperature sensor I2C interface
    output logic        temp_scl,
    inout  logic        temp_sda,

    // Humidity sensor I2C interface  
    output logic        hum_scl,
    inout  logic        hum_sda,

    // Motion sensor SPI interface
    output logic        motion_sclk,
    output logic        motion_mosi,
    input  logic        motion_miso,
    output logic        motion_cs_n,
    input  logic        motion_int,

    // Serial output for wireless module
    output logic        tx_serial,
    output logic        tx_busy,

    // Power management
    input  logic [1:0]  power_mode,
    input  logic        timer_wakeup,
    output logic        system_wakeup,
    output logic        power_save_active,

    // Status and debug
    output logic [7:0]  packets_transmitted,
    output logic        system_error,
    output logic [15:0] debug_status
);

    // Internal clock enables from power controller
    logic temp_clk_en, hum_clk_en, motion_clk_en;
    logic arbiter_clk_en, framer_clk_en, tx_clk_en;

    // Timestamp counter
    logic [15:0] timestamp_counter;

    // Sensor data interfaces
    logic [15:0] temp_data, hum_data, motion_data;
    logic        temp_valid, hum_valid, motion_valid;
    logic        temp_ready, hum_ready, motion_ready;
    logic        temp_error, hum_error, motion_error;

    // Arbiter to framer interface
    logic [15:0] arbiter_data;
    logic [1:0]  arbiter_sensor_id;
    logic        arbiter_valid, arbiter_ready;
    logic [2:0]  pending_sensors;
    logic        arbiter_overflow;

    // Framer to transmitter interface
    logic [7:0]  packet_byte;
    logic        packet_valid, packet_ready;
    logic        frame_error;
    logic [3:0]  frame_state;

    // Activity monitoring for power controller
    logic temp_activity, hum_activity, motion_activity;
    logic arbiter_activity, framer_activity, tx_activity;

    // Status signals
    logic [15:0] power_idle_counter;
    logic [5:0]  modules_active;
    logic        transmission_complete;

    // Timestamp counter (free-running)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timestamp_counter <= '0;
        end else if (enable) begin
            timestamp_counter <= timestamp_counter + 1'b1;
        end
    end

    // Temperature Sensor Interface
    temperature_sensor_interface #(
        .SENSOR_I2C_ADDR(7'h48)
    ) temp_sensor (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable && temp_clk_en),
        .sensor_data(temp_data),
        .data_valid(temp_valid),
        .data_ready(temp_ready),
        .scl(temp_scl),
        .sda(temp_sda),
        .sensor_error(temp_error)
    );

    // Humidity Sensor Interface
    humidity_sensor_interface #(
        .SENSOR_I2C_ADDR(7'h40)
    ) hum_sensor (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable && hum_clk_en),
        .sensor_data(hum_data),
        .data_valid(hum_valid),
        .data_ready(hum_ready),
        .scl(hum_scl),
        .sda(hum_sda),
        .sensor_error(hum_error)
    );

    // Motion Sensor Interface
    motion_sensor_interface motion_sensor (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable && motion_clk_en),
        .sensor_data(motion_data),
        .data_valid(motion_valid),
        .data_ready(motion_ready),
        .sclk(motion_sclk),
        .mosi(motion_mosi),
        .miso(motion_miso),
        .cs_n(motion_cs_n),
        .motion_int(motion_int),
        .sensor_error(motion_error)
    );

    // Priority Arbiter
    priority_arbiter arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable && arbiter_clk_en),
        .temp_data(temp_data),
        .temp_valid(temp_valid),
        .temp_ready(temp_ready),
        .hum_data(hum_data),
        .hum_valid(hum_valid),
        .hum_ready(hum_ready),
        .motion_data(motion_data),
        .motion_valid(motion_valid),
        .motion_ready(motion_ready),
        .sensor_data(arbiter_data),
        .sensor_id(arbiter_sensor_id),
        .data_valid(arbiter_valid),
        .data_ready(arbiter_ready),
        .pending_sensors(pending_sensors),
        .overflow_error(arbiter_overflow)
    );

    // Packet Framer
    packet_framer framer (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable && framer_clk_en),
        .sensor_data(arbiter_data),
        .sensor_id(arbiter_sensor_id),
        .data_valid(arbiter_valid),
        .data_ready(arbiter_ready),
        .timestamp(timestamp_counter),
        .packet_byte(packet_byte),
        .packet_valid(packet_valid),
        .packet_ready(packet_ready),
        .frame_error(frame_error),
        .frame_state_debug(frame_state)
    );

    // Serial Transmitter
    serial_transmitter #(
        .SYSTEM_CLK_FREQ(SYSTEM_CLK_FREQ),
        .BAUD_RATE(UART_BAUD_RATE)
    ) transmitter (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable && tx_clk_en),
        .packet_byte(packet_byte),
        .packet_valid(packet_valid),
        .packet_ready(packet_ready),
        .tx_serial(tx_serial),
        .tx_busy(tx_busy),
        .bytes_transmitted(packets_transmitted),
        .transmission_complete(transmission_complete)
    );

    // Power Controller
    power_controller power_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .global_enable(enable),
        .temp_activity(temp_activity),
        .hum_activity(hum_activity),
        .motion_activity(motion_activity),
        .arbiter_activity(arbiter_activity),
        .framer_activity(framer_activity),
        .tx_activity(tx_activity),
        .temp_clk_en(temp_clk_en),
        .hum_clk_en(hum_clk_en),
        .motion_clk_en(motion_clk_en),
        .arbiter_clk_en(arbiter_clk_en),
        .framer_clk_en(framer_clk_en),
        .tx_clk_en(tx_clk_en),
        .power_mode(power_mode),
        .power_state(),
        .motion_wakeup(motion_int),
        .timer_wakeup(timer_wakeup),
        .system_wakeup(system_wakeup),
        .idle_counter(power_idle_counter),
        .modules_active(modules_active),
        .power_save_active(power_save_active)
    );

    // Activity monitoring
    assign temp_activity = temp_valid || temp_ready;
    assign hum_activity = hum_valid || hum_ready;
    assign motion_activity = motion_valid || motion_ready || motion_int;
    assign arbiter_activity = arbiter_valid || arbiter_ready || (|pending_sensors);
    assign framer_activity = packet_valid || packet_ready;
    assign tx_activity = tx_busy || transmission_complete;

    // System error aggregation
    assign system_error = temp_error || hum_error || motion_error || 
                         arbiter_overflow || frame_error;

    // Debug status register
    assign debug_status = {
        power_save_active,      // [15]
        system_error,           // [14]
        modules_active[5:0],    // [13:8]
        frame_state[3:0],       // [7:4]
        pending_sensors[2:0],   // [3:1]
        |{temp_valid, hum_valid, motion_valid}  // [0] - any sensor active
    };

    // Performance counters and statistics
    logic [31:0] total_packets;
    logic [31:0] error_count;
    logic [31:0] power_save_cycles;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_packets <= '0;
            error_count <= '0;
            power_save_cycles <= '0;
        end else if (enable) begin
            // Count completed packets
            if (transmission_complete) begin
                total_packets <= total_packets + 1'b1;
            end

            // Count errors
            if (system_error) begin
                error_count <= error_count + 1'b1;
            end

            // Count power save cycles
            if (power_save_active) begin
                power_save_cycles <= power_save_cycles + 1'b1;
            end
        end
    end

    // Assertions for system-level verification
    `ifdef SIMULATION
        // Check system coherency
        always @(posedge clk) begin
            if (enable && rst_n) begin
                // Verify data flow consistency
                if (arbiter_valid && !arbiter_ready) begin
                    assert (packet_valid || framer_activity) 
                        else $warning("Arbiter blocked but framer not active");
                end

                // Check power management
                if (power_mode != PWR_NORMAL) begin
                    assert (power_save_active) 
                        else $error("Power save mode not reflected in status");
                end

                // Verify error handling
                if (system_error) begin
                    assert (!arbiter_valid || frame_error) 
                        else $info("System error detected: investigating source");
                end
            end
        end

        // Monitor packet transmission rate
        logic [31:0] packet_rate_counter;
        logic [15:0] packets_per_second;

        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                packet_rate_counter <= '0;
                packets_per_second <= '0;
            end else begin
                packet_rate_counter <= packet_rate_counter + 1'b1;

                // Calculate packets per second (assuming 100MHz clock)
                if (packet_rate_counter >= SYSTEM_CLK_FREQ) begin
                    packets_per_second <= packets_transmitted;
                    packet_rate_counter <= '0;
                end
            end
        end
    `endif

endmodule : iot_sensor_controller

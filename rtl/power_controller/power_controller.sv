//=============================================================================
// Power Controller Module
// Author: Prabhat Pandey
// Date: August 24, 2025
// Description: Clock gating and power management for IoT sensor controller
//=============================================================================

import iot_sensor_pkg::*;

module power_controller (
    // System interface
    input  logic        clk,
    input  logic        rst_n,
    input  logic        global_enable,

    // Activity monitoring inputs
    input  logic        temp_activity,
    input  logic        hum_activity,
    input  logic        motion_activity,
    input  logic        arbiter_activity,
    input  logic        framer_activity,
    input  logic        tx_activity,

    // Clock enable outputs (gated clocks)
    output logic        temp_clk_en,
    output logic        hum_clk_en,
    output logic        motion_clk_en,
    output logic        arbiter_clk_en,
    output logic        framer_clk_en,
    output logic        tx_clk_en,

    // Power mode controls
    input  logic [1:0]  power_mode,  // 00=Normal, 01=Low, 10=Sleep, 11=Deep
    output logic [2:0]  power_state,

    // Wakeup controls
    input  logic        motion_wakeup,
    input  logic        timer_wakeup,
    output logic        system_wakeup,

    // Status and debug
    output logic [15:0] idle_counter,
    output logic [5:0]  modules_active,
    output logic        power_save_active
);

    // Power modes
    typedef enum logic [1:0] {
        PWR_NORMAL = 2'b00,  // All modules active
        PWR_LOW    = 2'b01,  // Reduced sensor polling
        PWR_SLEEP  = 2'b10,  // Only motion sensor active
        PWR_DEEP   = 2'b11   // All modules off except wakeup
    } power_mode_e;

    // Activity timeout counters
    logic [15:0] temp_idle_count, hum_idle_count, motion_idle_count;
    logic [15:0] arbiter_idle_count, framer_idle_count, tx_idle_count;

    // Clock gating control
    logic temp_clk_gate, hum_clk_gate, motion_clk_gate;
    logic arbiter_clk_gate, framer_clk_gate, tx_clk_gate;

    // Global idle detection
    logic [15:0] global_idle_count;
    logic        all_modules_idle;

    // Activity detection and timeout counters
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            temp_idle_count <= '0;
            hum_idle_count <= '0;
            motion_idle_count <= '0;
            arbiter_idle_count <= '0;
            framer_idle_count <= '0;
            tx_idle_count <= '0;
            global_idle_count <= '0;
        end else if (!global_enable) begin
            temp_idle_count <= '0;
            hum_idle_count <= '0;
            motion_idle_count <= '0;
            arbiter_idle_count <= '0;
            framer_idle_count <= '0;
            tx_idle_count <= '0;
            global_idle_count <= '0;
        end else begin
            // Temperature sensor timeout
            if (temp_activity) begin
                temp_idle_count <= '0;
            end else if (temp_idle_count < IDLE_TIMEOUT_CYCLES) begin
                temp_idle_count <= temp_idle_count + 1'b1;
            end

            // Humidity sensor timeout
            if (hum_activity) begin
                hum_idle_count <= '0;
            end else if (hum_idle_count < IDLE_TIMEOUT_CYCLES) begin
                hum_idle_count <= hum_idle_count + 1'b1;
            end

            // Motion sensor timeout  
            if (motion_activity) begin
                motion_idle_count <= '0;
            end else if (motion_idle_count < IDLE_TIMEOUT_CYCLES) begin
                motion_idle_count <= motion_idle_count + 1'b1;
            end

            // Arbiter timeout
            if (arbiter_activity) begin
                arbiter_idle_count <= '0;
            end else if (arbiter_idle_count < IDLE_TIMEOUT_CYCLES) begin
                arbiter_idle_count <= arbiter_idle_count + 1'b1;
            end

            // Framer timeout
            if (framer_activity) begin
                framer_idle_count <= '0;
            end else if (framer_idle_count < IDLE_TIMEOUT_CYCLES) begin
                framer_idle_count <= framer_idle_count + 1'b1;
            end

            // Transmitter timeout
            if (tx_activity) begin
                tx_idle_count <= '0;
            end else if (tx_idle_count < IDLE_TIMEOUT_CYCLES) begin
                tx_idle_count <= tx_idle_count + 1'b1;
            end

            // Global idle counter
            all_modules_idle = (temp_idle_count >= IDLE_TIMEOUT_CYCLES) &&
                              (hum_idle_count >= IDLE_TIMEOUT_CYCLES) &&
                              (motion_idle_count >= IDLE_TIMEOUT_CYCLES) &&
                              (arbiter_idle_count >= IDLE_TIMEOUT_CYCLES) &&
                              (framer_idle_count >= IDLE_TIMEOUT_CYCLES) &&
                              (tx_idle_count >= IDLE_TIMEOUT_CYCLES);

            if (all_modules_idle && global_idle_count < 16'hFFFF) begin
                global_idle_count <= global_idle_count + 1'b1;
            end else if (!all_modules_idle) begin
                global_idle_count <= '0;
            end
        end
    end

    // Power mode control logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            power_state <= 3'b001; // Normal power state
            system_wakeup <= 1'b0;
        end else begin
            system_wakeup <= 1'b0; // Default

            case (power_mode)
                PWR_NORMAL: begin
                    power_state <= 3'b001;
                end

                PWR_LOW: begin
                    power_state <= 3'b010;
                end

                PWR_SLEEP: begin
                    power_state <= 3'b100;
                    // Wakeup conditions
                    if (motion_wakeup || timer_wakeup) begin
                        system_wakeup <= 1'b1;
                    end
                end

                PWR_DEEP: begin
                    power_state <= 3'b000;
                    // Only external wakeup in deep sleep
                    if (motion_wakeup) begin
                        system_wakeup <= 1'b1;
                    end
                end
            endcase
        end
    end

    // Clock gating logic based on power mode and activity
    always_comb begin
        case (power_mode)
            PWR_NORMAL: begin
                // Normal mode - clock gating based on individual timeouts
                temp_clk_gate = (temp_idle_count < IDLE_TIMEOUT_CYCLES) || temp_activity;
                hum_clk_gate = (hum_idle_count < IDLE_TIMEOUT_CYCLES) || hum_activity;
                motion_clk_gate = (motion_idle_count < IDLE_TIMEOUT_CYCLES) || motion_activity;
                arbiter_clk_gate = (arbiter_idle_count < IDLE_TIMEOUT_CYCLES) || arbiter_activity;
                framer_clk_gate = (framer_idle_count < IDLE_TIMEOUT_CYCLES) || framer_activity;
                tx_clk_gate = (tx_idle_count < IDLE_TIMEOUT_CYCLES) || tx_activity;
            end

            PWR_LOW: begin
                // Low power mode - reduce sensor polling rates
                temp_clk_gate = temp_activity && (temp_idle_count[7:0] == 8'h00); // 1/256 rate
                hum_clk_gate = hum_activity && (hum_idle_count[8:0] == 9'h000);  // 1/512 rate
                motion_clk_gate = (motion_idle_count < IDLE_TIMEOUT_CYCLES) || motion_activity; // Normal
                arbiter_clk_gate = (arbiter_idle_count < IDLE_TIMEOUT_CYCLES) || arbiter_activity;
                framer_clk_gate = (framer_idle_count < IDLE_TIMEOUT_CYCLES) || framer_activity;
                tx_clk_gate = (tx_idle_count < IDLE_TIMEOUT_CYCLES) || tx_activity;
            end

            PWR_SLEEP: begin
                // Sleep mode - only motion sensor and critical paths
                temp_clk_gate = 1'b0;
                hum_clk_gate = 1'b0;
                motion_clk_gate = 1'b1; // Motion always active for wakeup
                arbiter_clk_gate = motion_activity;
                framer_clk_gate = motion_activity;
                tx_clk_gate = motion_activity;
            end

            PWR_DEEP: begin
                // Deep sleep - everything off except wakeup detection
                temp_clk_gate = 1'b0;
                hum_clk_gate = 1'b0;
                motion_clk_gate = 1'b0; // Even motion sensor off
                arbiter_clk_gate = 1'b0;
                framer_clk_gate = 1'b0;
                tx_clk_gate = 1'b0;
            end
        endcase
    end

    // Clock enable generation with proper gating
    // Using AND gates for clock enable (safer than actual clock gating)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            temp_clk_en <= 1'b1;
            hum_clk_en <= 1'b1;
            motion_clk_en <= 1'b1;
            arbiter_clk_en <= 1'b1;
            framer_clk_en <= 1'b1;
            tx_clk_en <= 1'b1;
        end else begin
            temp_clk_en <= temp_clk_gate && global_enable;
            hum_clk_en <= hum_clk_gate && global_enable;
            motion_clk_en <= motion_clk_gate && global_enable;
            arbiter_clk_en <= arbiter_clk_gate && global_enable;
            framer_clk_en <= framer_clk_gate && global_enable;
            tx_clk_en <= tx_clk_gate && global_enable;
        end
    end

    // Status outputs
    assign idle_counter = global_idle_count;
    assign modules_active = {tx_clk_en, framer_clk_en, arbiter_clk_en, 
                            motion_clk_en, hum_clk_en, temp_clk_en};
    assign power_save_active = (power_mode != PWR_NORMAL) || all_modules_idle;

    // Assertions for verification
    `ifdef SIMULATION
        always @(posedge clk) begin
            if (global_enable) begin
                // Verify power state transitions
                case (power_mode)
                    PWR_SLEEP: begin
                        assert (motion_clk_en || system_wakeup) 
                            else $warning("Sleep mode without motion detection or wakeup");
                    end

                    PWR_DEEP: begin
                        assert (!temp_clk_en && !hum_clk_en && !motion_clk_en) 
                            else $error("Deep sleep mode with active clocks");
                    end
                endcase

                // Check for clock enable consistency
                if (power_mode == PWR_NORMAL) begin
                    assert (temp_clk_en || (temp_idle_count >= IDLE_TIMEOUT_CYCLES)) 
                        else $error("Temperature clock disabled without timeout");
                end
            end
        end
    `endif

endmodule : power_controller

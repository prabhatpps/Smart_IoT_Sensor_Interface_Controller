//=============================================================================
// Power Controller
// Manages system power modes and clock gating
//=============================================================================

`timescale 1ns/1ps

import iot_sensor_pkg::*;

module power_controller (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [1:0]  power_mode,

    // Activity indicators
    input  logic        temp_active,
    input  logic        hum_active,
    input  logic        motion_active,
    input  logic        tx_active,

    // Gated clocks  
    output logic        temp_clk_en,
    output logic        hum_clk_en,
    output logic        motion_clk_en,
    output logic        tx_clk_en,
    output logic        sys_clk_en
);

    // Internal signals
    logic [15:0] power_timer;
    logic low_power_mode;
    logic sleep_mode;

    // Power mode decoding
    assign low_power_mode = (power_mode == PWR_LOW);
    assign sleep_mode = (power_mode == PWR_SLEEP || power_mode == PWR_DEEP);

    // Power management timer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            power_timer <= '0;
        end else begin
            power_timer <= power_timer + 1;
        end
    end

    // Clock enable generation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            temp_clk_en <= 1'b1;
            hum_clk_en <= 1'b1;
            motion_clk_en <= 1'b1;
            tx_clk_en <= 1'b1;
            sys_clk_en <= 1'b1;
        end else begin
            case (power_mode)
                PWR_NORMAL: begin
                    // All clocks enabled in normal mode
                    temp_clk_en <= 1'b1;
                    hum_clk_en <= 1'b1;
                    motion_clk_en <= 1'b1;
                    tx_clk_en <= 1'b1;
                    sys_clk_en <= 1'b1;
                end

                PWR_LOW: begin
                    // Clock gating based on activity in low power mode
                    temp_clk_en <= temp_active;
                    hum_clk_en <= hum_active;
                    motion_clk_en <= motion_active || (power_timer[7:0] == 8'h00); // Motion always responsive
                    tx_clk_en <= tx_active;
                    sys_clk_en <= 1'b1; // System clock always on
                end

                PWR_SLEEP: begin
                    // Minimal clocking in sleep mode
                    temp_clk_en <= power_timer[11:0] == 12'h000; // Very occasional temp reading
                    hum_clk_en <= power_timer[12:0] == 13'h0000; // Even less frequent humidity
                    motion_clk_en <= 1'b1; // Motion detection always active
                    tx_clk_en <= tx_active;
                    sys_clk_en <= temp_active || hum_active || motion_active || tx_active;
                end

                PWR_DEEP: begin
                    // Only motion detection active in deep sleep
                    temp_clk_en <= 1'b0;
                    hum_clk_en <= 1'b0;
                    motion_clk_en <= 1'b1; // Keep motion detection for wake-up
                    tx_clk_en <= tx_active;
                    sys_clk_en <= motion_active || tx_active;
                end

                default: begin
                    temp_clk_en <= 1'b1;
                    hum_clk_en <= 1'b1;
                    motion_clk_en <= 1'b1;
                    tx_clk_en <= 1'b1;
                    sys_clk_en <= 1'b1;
                end
            endcase
        end
    end

endmodule : power_controller

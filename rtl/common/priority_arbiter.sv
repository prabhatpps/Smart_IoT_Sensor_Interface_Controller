//=============================================================================
// Priority Arbiter for Sensor Data
// Priority: Motion > Temperature > Humidity
//=============================================================================

`timescale 1ns/1ps

import iot_sensor_pkg::*;

module priority_arbiter (
    input  logic clk,
    input  logic rst_n,

    // Sensor requests
    input  logic temp_req,
    input  logic hum_req, 
    input  logic motion_req,

    // Grants (only one active at a time)
    output logic temp_grant,
    output logic hum_grant,
    output logic motion_grant,

    // FIFO status inputs  
    input  logic temp_fifo_empty,
    input  logic hum_fifo_empty,
    input  logic motion_fifo_empty,

    // FIFO count inputs
    input  logic [3:0] temp_count,
    input  logic [3:0] hum_count,
    input  logic [3:0] motion_count
);

    // Internal signals
    logic [2:0] current_grant;

    // Grant encoding
    localparam GRANT_NONE   = 3'b000;
    localparam GRANT_TEMP   = 3'b001;
    localparam GRANT_HUM    = 3'b010;
    localparam GRANT_MOTION = 3'b100;

    // Priority arbitration logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_grant <= GRANT_NONE;
        end else begin
            // Priority: Motion > Temperature > Humidity
            if (motion_req && !motion_fifo_empty) begin
                current_grant <= GRANT_MOTION;
            end else if (temp_req && !temp_fifo_empty) begin
                current_grant <= GRANT_TEMP;
            end else if (hum_req && !hum_fifo_empty) begin
                current_grant <= GRANT_HUM;
            end else begin
                current_grant <= GRANT_NONE;
            end
        end
    end

    // Generate grant signals
    assign motion_grant = (current_grant == GRANT_MOTION);
    assign temp_grant   = (current_grant == GRANT_TEMP);  
    assign hum_grant    = (current_grant == GRANT_HUM);

endmodule : priority_arbiter

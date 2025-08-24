//=============================================================================
// Packet Framer  
// Formats sensor data into packets for transmission
//=============================================================================

`timescale 1ns/1ps

import iot_sensor_pkg::*;

module packet_framer (
    input  logic        clk,
    input  logic        rst_n,

    // Sensor data inputs
    input  logic [15:0] temp_data,
    input  logic        temp_valid,
    input  logic [15:0] hum_data,
    input  logic        hum_valid,
    input  logic [15:0] motion_data,
    input  logic        motion_valid,

    // Packet output interface
    output logic        packet_ready,
    output logic [7:0]  packet_data,
    output logic        packet_valid,
    input  logic        packet_ack,

    // Status
    output logic        packet_sent
);

    // Packet states
    typedef enum logic [3:0] {
        PKT_IDLE        = 4'b0000,
        PKT_HEADER      = 4'b0001,
        PKT_SENSOR_ID   = 4'b0010,
        PKT_LENGTH      = 4'b0011,
        PKT_TIMESTAMP   = 4'b0100,
        PKT_DATA_MSB    = 4'b0101,
        PKT_DATA_LSB    = 4'b0110,
        PKT_CHECKSUM    = 4'b0111,
        PKT_DONE        = 4'b1000
    } pkt_state_e;

    pkt_state_e current_state, next_state;

    // Internal signals
    logic [7:0] current_sensor_id;
    logic [15:0] current_data;
    logic [31:0] timestamp_counter;
    logic [7:0] checksum;
    logic [2:0] byte_count;
    logic [7:0] packet_buffer;

    // Timestamp counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timestamp_counter <= '0;
        end else begin
            timestamp_counter <= timestamp_counter + 1;
        end
    end

    // State machine - sequential
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= PKT_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // State machine - combinational
    always_comb begin
        next_state = current_state;

        case (current_state)
            PKT_IDLE: begin
                if (temp_valid || hum_valid || motion_valid)
                    next_state = PKT_HEADER;
            end

            PKT_HEADER: begin
                if (packet_ack)
                    next_state = PKT_SENSOR_ID;
            end

            PKT_SENSOR_ID: begin
                if (packet_ack)
                    next_state = PKT_LENGTH;
            end

            PKT_LENGTH: begin
                if (packet_ack && byte_count == 1)
                    next_state = PKT_TIMESTAMP;
            end

            PKT_TIMESTAMP: begin
                if (packet_ack && byte_count == 3)
                    next_state = PKT_DATA_MSB;
            end

            PKT_DATA_MSB: begin
                if (packet_ack)
                    next_state = PKT_DATA_LSB;
            end

            PKT_DATA_LSB: begin
                if (packet_ack)
                    next_state = PKT_CHECKSUM;
            end

            PKT_CHECKSUM: begin
                if (packet_ack)
                    next_state = PKT_DONE;
            end

            PKT_DONE: begin
                next_state = PKT_IDLE;
            end

            default: next_state = PKT_IDLE;
        endcase
    end

    // Control logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            packet_data <= '0;
            packet_valid <= 1'b0;
            packet_ready <= 1'b0;
            packet_sent <= 1'b0;
            current_sensor_id <= '0;
            current_data <= '0;
            checksum <= '0;
            byte_count <= '0;
            packet_buffer <= '0;
        end else begin
            packet_sent <= 1'b0;

            case (current_state)
                PKT_IDLE: begin
                    packet_valid <= 1'b0;
                    byte_count <= '0;
                    checksum <= '0;

                    // Priority: Motion > Temperature > Humidity
                    if (motion_valid) begin
                        current_sensor_id <= MOTION_SENSOR_ID;
                        current_data <= motion_data;
                        packet_ready <= 1'b1;
                    end else if (temp_valid) begin
                        current_sensor_id <= TEMP_SENSOR_ID;
                        current_data <= temp_data;
                        packet_ready <= 1'b1;
                    end else if (hum_valid) begin
                        current_sensor_id <= HUM_SENSOR_ID;
                        current_data <= hum_data;
                        packet_ready <= 1'b1;
                    end else begin
                        packet_ready <= 1'b0;
                    end
                end

                PKT_HEADER: begin
                    packet_data <= 8'hAA;  // Header byte
                    packet_valid <= 1'b1;
                    checksum <= checksum ^ 8'hAA;
                end

                PKT_SENSOR_ID: begin
                    packet_data <= current_sensor_id;
                    packet_valid <= 1'b1;
                    checksum <= checksum ^ current_sensor_id;
                end

                PKT_LENGTH: begin
                    case (byte_count)
                        0: begin
                            packet_data <= 8'h00;  // Length MSB
                            packet_valid <= 1'b1;
                            checksum <= checksum ^ 8'h00;
                            byte_count <= byte_count + 1;
                        end
                        1: begin
                            packet_data <= 8'h06;  // Length LSB (6 bytes: 4 timestamp + 2 data)
                            packet_valid <= 1'b1;
                            checksum <= checksum ^ 8'h06;
                            byte_count <= '0;
                        end
                    endcase
                end

                PKT_TIMESTAMP: begin
                    case (byte_count)
                        0: begin
                            packet_data <= timestamp_counter[31:24];
                            packet_valid <= 1'b1;
                            checksum <= checksum ^ timestamp_counter[31:24];
                            byte_count <= byte_count + 1;
                        end
                        1: begin
                            packet_data <= timestamp_counter[23:16];
                            packet_valid <= 1'b1;
                            checksum <= checksum ^ timestamp_counter[23:16];
                            byte_count <= byte_count + 1;
                        end
                        2: begin
                            packet_data <= timestamp_counter[15:8];
                            packet_valid <= 1'b1;
                            checksum <= checksum ^ timestamp_counter[15:8];
                            byte_count <= byte_count + 1;
                        end
                        3: begin
                            packet_data <= timestamp_counter[7:0];
                            packet_valid <= 1'b1;
                            checksum <= checksum ^ timestamp_counter[7:0];
                            byte_count <= '0;
                        end
                    endcase
                end

                PKT_DATA_MSB: begin
                    packet_data <= current_data[15:8];
                    packet_valid <= 1'b1;
                    checksum <= checksum ^ current_data[15:8];
                end

                PKT_DATA_LSB: begin
                    packet_data <= current_data[7:0];
                    packet_valid <= 1'b1;
                    checksum <= checksum ^ current_data[7:0];
                end

                PKT_CHECKSUM: begin
                    packet_data <= checksum;
                    packet_valid <= 1'b1;
                end

                PKT_DONE: begin
                    packet_valid <= 1'b0;
                    packet_ready <= 1'b0;
                    packet_sent <= 1'b1;
                end
            endcase
        end
    end

endmodule : packet_framer

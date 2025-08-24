//=============================================================================
// Packet Framer Module
// Author: Prabhat Pandey
// Date: August 24, 2025  
// Description: Frames sensor data into packets with header, checksum, and delimiters
//=============================================================================

import iot_sensor_pkg::*;

module packet_framer (
    // System interface
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,

    // Data input from arbiter
    input  logic [15:0] sensor_data,
    input  logic [1:0]  sensor_id,
    input  logic        data_valid,
    output logic        data_ready,

    // Timestamp input
    input  logic [15:0] timestamp,

    // Packet output
    output logic [7:0]  packet_byte,
    output logic        packet_valid,
    input  logic        packet_ready,

    // Status
    output logic        frame_error,
    output logic [3:0]  frame_state_debug
);

    // Packet framing state machine
    typedef enum logic [3:0] {
        FRAME_IDLE       = 4'h0,
        FRAME_START_DELIM = 4'h1,
        FRAME_SENSOR_ID   = 4'h2,
        FRAME_LENGTH      = 4'h3,
        FRAME_TIMESTAMP_H = 4'h4,
        FRAME_TIMESTAMP_L = 4'h5,
        FRAME_DATA_H      = 4'h6,
        FRAME_DATA_L      = 4'h7,
        FRAME_CHECKSUM    = 4'h8,
        FRAME_END_DELIM   = 4'h9,
        FRAME_WAIT        = 4'hA
    } frame_state_e;

    frame_state_e current_state, next_state;

    // Internal registers for packet data
    logic [15:0] data_reg, timestamp_reg;
    logic [1:0]  sensor_id_reg;
    logic [7:0]  checksum;
    logic [7:0]  checksum_calc;

    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= FRAME_IDLE;
        end else if (!enable) begin
            current_state <= FRAME_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // State transition logic
    always_comb begin
        next_state = current_state;

        case (current_state)
            FRAME_IDLE: begin
                if (data_valid) begin
                    next_state = FRAME_START_DELIM;
                end
            end

            FRAME_START_DELIM: begin
                if (packet_ready) begin
                    next_state = FRAME_SENSOR_ID;
                end
            end

            FRAME_SENSOR_ID: begin
                if (packet_ready) begin
                    next_state = FRAME_LENGTH;
                end
            end

            FRAME_LENGTH: begin
                if (packet_ready) begin
                    next_state = FRAME_TIMESTAMP_H;
                end
            end

            FRAME_TIMESTAMP_H: begin
                if (packet_ready) begin
                    next_state = FRAME_TIMESTAMP_L;
                end
            end

            FRAME_TIMESTAMP_L: begin
                if (packet_ready) begin
                    next_state = FRAME_DATA_H;
                end
            end

            FRAME_DATA_H: begin
                if (packet_ready) begin
                    next_state = FRAME_DATA_L;
                end
            end

            FRAME_DATA_L: begin
                if (packet_ready) begin
                    next_state = FRAME_CHECKSUM;
                end
            end

            FRAME_CHECKSUM: begin
                if (packet_ready) begin
                    next_state = FRAME_END_DELIM;
                end
            end

            FRAME_END_DELIM: begin
                if (packet_ready) begin
                    next_state = FRAME_WAIT;
                end
            end

            FRAME_WAIT: begin
                next_state = FRAME_IDLE;
            end

            default: next_state = FRAME_IDLE;
        endcase
    end

    // Data capture and output logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_reg <= '0;
            timestamp_reg <= '0;
            sensor_id_reg <= '0;
            packet_byte <= '0;
            packet_valid <= 1'b0;
            data_ready <= 1'b0;
            frame_error <= 1'b0;
            checksum <= '0;
        end else begin
            case (current_state)
                FRAME_IDLE: begin
                    packet_valid <= 1'b0;
                    data_ready <= 1'b1; // Ready to accept new data
                    frame_error <= 1'b0;
                    checksum <= '0;

                    if (data_valid) begin
                        // Capture input data
                        data_reg <= sensor_data;
                        sensor_id_reg <= sensor_id;
                        timestamp_reg <= timestamp;
                        data_ready <= 1'b0;
                    end
                end

                FRAME_START_DELIM: begin
                    packet_byte <= PACKET_START_DELIM;
                    packet_valid <= 1'b1;
                    checksum <= checksum + PACKET_START_DELIM;
                end

                FRAME_SENSOR_ID: begin
                    packet_byte <= {6'b000000, sensor_id_reg};
                    packet_valid <= 1'b1;
                    checksum <= checksum + {6'b000000, sensor_id_reg};
                end

                FRAME_LENGTH: begin
                    packet_byte <= PACKET_LENGTH;
                    packet_valid <= 1'b1;
                    checksum <= checksum + PACKET_LENGTH;
                end

                FRAME_TIMESTAMP_H: begin
                    packet_byte <= timestamp_reg[15:8];
                    packet_valid <= 1'b1;
                    checksum <= checksum + timestamp_reg[15:8];
                end

                FRAME_TIMESTAMP_L: begin
                    packet_byte <= timestamp_reg[7:0];
                    packet_valid <= 1'b1;
                    checksum <= checksum + timestamp_reg[7:0];
                end

                FRAME_DATA_H: begin
                    packet_byte <= data_reg[15:8];
                    packet_valid <= 1'b1;
                    checksum <= checksum + data_reg[15:8];
                end

                FRAME_DATA_L: begin
                    packet_byte <= data_reg[7:0];
                    packet_valid <= 1'b1;
                    checksum <= checksum + data_reg[7:0];
                end

                FRAME_CHECKSUM: begin
                    // Two's complement checksum
                    checksum_calc = ~checksum + 1'b1;
                    packet_byte <= checksum_calc;
                    packet_valid <= 1'b1;
                end

                FRAME_END_DELIM: begin
                    packet_byte <= PACKET_END_DELIM;
                    packet_valid <= 1'b1;
                end

                FRAME_WAIT: begin
                    packet_valid <= 1'b0;
                    // Small delay before accepting next packet
                end

                default: begin
                    packet_valid <= 1'b0;
                    frame_error <= 1'b1;
                end
            endcase
        end
    end

    // Debug output
    assign frame_state_debug = current_state;

    // Packet structure visualization (for debugging):
    // Byte 0: Start Delimiter (0x7E)
    // Byte 1: Sensor ID (2 bits) + Reserved (6 bits)  
    // Byte 2: Packet Length (8 bits)
    // Byte 3: Timestamp High (8 bits)
    // Byte 4: Timestamp Low (8 bits)
    // Byte 5: Sensor Data High (8 bits)
    // Byte 6: Sensor Data Low (8 bits)
    // Byte 7: Checksum (8 bits)
    // Byte 8: End Delimiter (0x7E)
    // Total: 9 bytes per packet

    // Assertions for verification
    `ifdef SIMULATION
        always @(posedge clk) begin
            if (enable && !rst_n) begin
                // Check state transitions
                assert (current_state <= FRAME_WAIT) 
                    else $error("Invalid frame state: %0d", current_state);

                // Verify packet structure
                if (current_state == FRAME_START_DELIM && packet_valid) begin
                    assert (packet_byte == PACKET_START_DELIM) 
                        else $error("Invalid start delimiter: 0x%02h", packet_byte);
                end

                if (current_state == FRAME_END_DELIM && packet_valid) begin
                    assert (packet_byte == PACKET_END_DELIM) 
                        else $error("Invalid end delimiter: 0x%02h", packet_byte);
                end
            end
        end
    `endif

endmodule : packet_framer

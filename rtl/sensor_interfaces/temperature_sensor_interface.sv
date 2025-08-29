//=============================================================================
// Temperature Sensor Interface (FIXED VERSION)
// Fixed: Faster read intervals, proper I2C request generation
//=============================================================================

`timescale 1ns/1ps

import iot_sensor_pkg::*;

module temperature_sensor_interface (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic [1:0]  power_mode,
    
    // Data output
    output logic [15:0] sensor_data,
    output logic        data_valid,
    output logic        data_ready,
    output logic        sensor_error,
    
    // I2C interface
    output logic        start_read,
    output logic [6:0]  slave_addr,
    output logic        read_write_n,
    output logic [7:0]  write_data,
    input  logic [7:0]  i2c_read_data,
    input  logic        transaction_done,
    input  logic        ack_error
);

    // State machine
    temp_state_e current_state, next_state;
    
    // Internal signals
    logic [7:0] read_data_msb;
    logic [7:0] read_data_lsb;
    logic [19:0] read_counter; // Increased width for faster intervals
    logic msb_done, lsb_done;
    
    // Assign outputs
    assign slave_addr = TEMP_SENSOR_ADDR;
    assign read_write_n = 1'b1;  // Always reading
    assign write_data = 8'h00;   // Not used for read
    assign data_ready = (current_state == TEMP_DONE);
    
    // State machine - sequential
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= TEMP_IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // State machine - combinational  
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            TEMP_IDLE: begin
                if (enable && read_counter == 0)
                    next_state = TEMP_START;
            end
            
            TEMP_START: begin
                next_state = TEMP_READ_MSB;
            end
            
            TEMP_READ_MSB: begin
                if (transaction_done && !ack_error)
                    next_state = TEMP_READ_LSB;
                else if (ack_error)
                    next_state = TEMP_IDLE;
            end
            
            TEMP_READ_LSB: begin
                if (transaction_done && !ack_error)
                    next_state = TEMP_DONE;
                else if (ack_error)
                    next_state = TEMP_IDLE;
            end
            
            TEMP_DONE: begin
                next_state = TEMP_IDLE;
            end
            
            default: next_state = TEMP_IDLE;
        endcase
    end
    
    // Control logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_read <= 1'b0;
            sensor_data <= '0;
            data_valid <= 1'b0;
            sensor_error <= 1'b0;
            read_data_msb <= '0;
            read_data_lsb <= '0;
            read_counter <= 20'd50000; // FIXED: Much faster - 500us @ 100MHz for testing
        end else begin
            case (current_state)
                TEMP_IDLE: begin
                    start_read <= 1'b0;
                    data_valid <= 1'b0;
                    sensor_error <= 1'b0;
                    
                    if (enable) begin
                        // FIXED: Faster intervals for testing
                        case (power_mode)
                            PWR_NORMAL: read_counter <= (read_counter > 0) ? read_counter - 1 : 20'd50000;  // 500us
                            PWR_LOW:    read_counter <= (read_counter > 0) ? read_counter - 1 : 20'd100000; // 1ms
                            PWR_SLEEP:  read_counter <= (read_counter > 0) ? read_counter - 1 : 20'd200000; // 2ms
                            default:    read_counter <= (read_counter > 0) ? read_counter - 1 : 20'd50000;
                        endcase
                    end else begin
                        read_counter <= 20'd50000;
                    end
                end
                
                TEMP_START: begin
                    start_read <= 1'b1;
                end
                
                TEMP_READ_MSB: begin
                    start_read <= 1'b0;
                    if (transaction_done && !ack_error) begin
                        read_data_msb <= i2c_read_data;
                    end else if (ack_error) begin
                        sensor_error <= 1'b1;
                    end
                end
                
                TEMP_READ_LSB: begin
                    if (transaction_done && !ack_error) begin
                        read_data_lsb <= i2c_read_data;
                    end else if (ack_error) begin
                        sensor_error <= 1'b1;
                    end
                end
                
                TEMP_DONE: begin
                    sensor_data <= {read_data_msb, read_data_lsb};
                    data_valid <= 1'b1;
                    read_counter <= 20'd50000; // Reset counter for next read
                end
            endcase
        end
    end

endmodule : temperature_sensor_interface

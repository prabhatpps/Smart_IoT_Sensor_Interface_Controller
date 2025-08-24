//=============================================================================
// I2C Master Interface Module
// Author: Prabhat Pandey
// Date: August 24, 2025  
// Description: I2C master for temperature and humidity sensor communication
//=============================================================================

import iot_sensor_pkg::*;

module i2c_master #(
    parameter int SYSTEM_CLK_FREQ = 100_000_000,
    parameter int I2C_CLK_FREQ = 100_000
)(
    // System interface
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,

    // Control interface
    input  logic        start_transaction,
    input  logic [6:0]  slave_addr,
    input  logic        read_write_n,  // 1=read, 0=write
    input  logic [7:0]  write_data,
    output logic [7:0]  read_data,
    output logic        transaction_done,
    output logic        ack_error,

    // I2C physical interface
    output logic        scl,
    inout  logic        sda
);

    // Clock divider for I2C clock generation
    localparam int CLK_DIVIDER = SYSTEM_CLK_FREQ / (4 * I2C_CLK_FREQ);

    // Internal signals
    i2c_state_e current_state, next_state;
    logic [15:0] clk_counter;
    logic [3:0]  bit_counter;
    logic [7:0]  shift_reg;
    logic        sda_out, sda_enable;
    logic        scl_enable;
    logic        ack_bit;

    // I2C clock generation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_counter <= '0;
        end else if (!enable) begin
            clk_counter <= '0;
        end else if (clk_counter >= CLK_DIVIDER - 1) begin
            clk_counter <= '0;
        end else begin
            clk_counter <= clk_counter + 1'b1;
        end
    end

    logic clk_pulse;
    assign clk_pulse = (clk_counter == CLK_DIVIDER - 1);

    // SCL generation
    logic [1:0] scl_state;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_state <= 2'b00;
        end else if (clk_pulse && scl_enable) begin
            scl_state <= scl_state + 1'b1;
        end else if (!scl_enable) begin
            scl_state <= 2'b00;
        end
    end

    assign scl = scl_enable ? (scl_state[1] || scl_state[0]) : 1'b1;

    // SDA tristate control
    assign sda = sda_enable ? sda_out : 1'bz;

    // Main I2C state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= I2C_IDLE;
        end else if (!enable) begin
            current_state <= I2C_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // State machine logic
    always_comb begin
        next_state = current_state;

        case (current_state)
            I2C_IDLE: begin
                if (start_transaction && enable) begin
                    next_state = I2C_START;
                end
            end

            I2C_START: begin
                if (clk_pulse && scl_state == 2'b11) begin
                    next_state = I2C_ADDRESS;
                end
            end

            I2C_ADDRESS: begin
                if (clk_pulse && scl_state == 2'b01 && bit_counter == 4'd8) begin
                    next_state = I2C_ACK;
                end
            end

            I2C_ACK: begin
                if (clk_pulse && scl_state == 2'b01) begin
                    if (read_write_n) begin
                        next_state = I2C_READ;
                    end else begin
                        next_state = I2C_STOP;
                    end
                end
            end

            I2C_READ: begin
                if (clk_pulse && scl_state == 2'b01 && bit_counter == 4'd8) begin
                    next_state = I2C_STOP;
                end
            end

            I2C_STOP: begin
                if (clk_pulse && scl_state == 2'b00) begin
                    next_state = I2C_IDLE;
                end
            end

            default: next_state = I2C_IDLE;
        endcase
    end

    // Control signals and data handling
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_counter <= '0;
            shift_reg <= '0;
            sda_out <= 1'b1;
            sda_enable <= 1'b0;
            scl_enable <= 1'b0;
            transaction_done <= 1'b0;
            ack_error <= 1'b0;
            read_data <= '0;
            ack_bit <= 1'b0;
        end else begin
            case (current_state)
                I2C_IDLE: begin
                    bit_counter <= '0;
                    sda_out <= 1'b1;
                    sda_enable <= 1'b0;
                    scl_enable <= 1'b0;
                    transaction_done <= 1'b0;
                    ack_error <= 1'b0;
                    if (start_transaction) begin
                        shift_reg <= {slave_addr, read_write_n};
                    end
                end

                I2C_START: begin
                    scl_enable <= 1'b1;
                    sda_enable <= 1'b1;
                    if (clk_pulse) begin
                        case (scl_state)
                            2'b00: sda_out <= 1'b1;  // SDA high
                            2'b01: sda_out <= 1'b1;  // SDA high, SCL rising
                            2'b10: sda_out <= 1'b0;  // SDA falling (START)
                            2'b11: sda_out <= 1'b0;  // SDA low
                        endcase
                    end
                end

                I2C_ADDRESS: begin
                    if (clk_pulse && scl_state == 2'b01) begin
                        if (bit_counter < 8) begin
                            sda_out <= shift_reg[7];
                            shift_reg <= {shift_reg[6:0], 1'b0};
                            bit_counter <= bit_counter + 1'b1;
                        end
                    end
                end

                I2C_ACK: begin
                    sda_enable <= 1'b0;  // Release SDA for ACK
                    if (clk_pulse && scl_state == 2'b10) begin
                        ack_bit <= sda;  // Sample ACK
                    end else if (clk_pulse && scl_state == 2'b01) begin
                        ack_error <= ack_bit;
                        bit_counter <= '0;
                        if (read_write_n) begin
                            shift_reg <= '0;
                        end
                    end
                end

                I2C_READ: begin
                    sda_enable <= 1'b0;  // Release SDA for reading
                    if (clk_pulse && scl_state == 2'b10) begin
                        shift_reg <= {shift_reg[6:0], sda};
                        bit_counter <= bit_counter + 1'b1;
                    end else if (bit_counter == 8) begin
                        read_data <= shift_reg;
                        sda_enable <= 1'b1;
                        sda_out <= 1'b1;  // NACK after read
                    end
                end

                I2C_STOP: begin
                    sda_enable <= 1'b1;
                    if (clk_pulse) begin
                        case (scl_state)
                            2'b00: sda_out <= 1'b0;  // SDA low
                            2'b01: sda_out <= 1'b0;  // SDA low, SCL rising  
                            2'b10: sda_out <= 1'b1;  // SDA rising (STOP)
                            2'b11: begin
                                sda_out <= 1'b1;     // SDA high
                                transaction_done <= 1'b1;
                            end
                        endcase
                    end
                end
            endcase
        end
    end

endmodule : i2c_master

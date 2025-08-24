//=============================================================================
// I2C Master Controller
// Supports standard I2C read and write operations
//=============================================================================

`timescale 1ns/1ps

import iot_sensor_pkg::*;

module i2c_master (
    input  logic        clk,
    input  logic        rst_n,

    // Control interface
    input  logic        start_transaction,
    input  logic [6:0]  slave_addr,
    input  logic        read_write_n,  // 1=read, 0=write
    input  logic [7:0]  write_data,
    output logic [7:0]  read_data,
    output logic        transaction_done,
    output logic        ack_error,

    // I2C bus
    inout  wire         scl,
    inout  wire         sda
);

    // State machine
    i2c_state_e current_state, next_state;

    // Internal signals
    logic [7:0] shift_reg;
    logic [3:0] bit_count;
    logic [15:0] clk_count;
    logic scl_out, sda_out;
    logic scl_oe, sda_oe;
    logic sda_in;

    // Clock divider for I2C timing
    localparam CLK_DIV = SYSTEM_CLK_FREQ / (2 * I2C_CLK_FREQ);

    // Tristate control for I2C bus
    assign scl = scl_oe ? scl_out : 1'bz;
    assign sda = sda_oe ? sda_out : 1'bz;
    assign sda_in = sda;

    // State machine - sequential
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= I2C_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // State machine - combinational
    always_comb begin
        next_state = current_state;

        case (current_state)
            I2C_IDLE: begin
                if (start_transaction)
                    next_state = I2C_START;
            end

            I2C_START: begin
                if (clk_count == CLK_DIV)
                    next_state = I2C_ADDRESS;
            end

            I2C_ADDRESS: begin
                if (bit_count == 7 && clk_count == CLK_DIV)
                    next_state = I2C_ACK;
            end

            I2C_ACK: begin
                if (clk_count == CLK_DIV) begin
                    if (read_write_n)
                        next_state = I2C_READ;
                    else
                        next_state = I2C_WRITE;
                end
            end

            I2C_WRITE: begin
                if (bit_count == 7 && clk_count == CLK_DIV)
                    next_state = I2C_STOP;
            end

            I2C_READ: begin
                if (bit_count == 7 && clk_count == CLK_DIV)
                    next_state = I2C_STOP;
            end

            I2C_STOP: begin
                if (clk_count == CLK_DIV)
                    next_state = I2C_IDLE;
            end

            default: next_state = I2C_IDLE;
        endcase
    end

    // Control logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_out <= 1'b1;
            sda_out <= 1'b1;
            scl_oe <= 1'b0;
            sda_oe <= 1'b0;
            bit_count <= '0;
            clk_count <= '0;
            shift_reg <= '0;
            read_data <= '0;
            transaction_done <= 1'b0;
            ack_error <= 1'b0;
        end else begin
            transaction_done <= 1'b0;

            case (current_state)
                I2C_IDLE: begin
                    scl_oe <= 1'b0;
                    sda_oe <= 1'b0;
                    clk_count <= '0;
                    bit_count <= '0;
                    if (start_transaction) begin
                        shift_reg <= {slave_addr, read_write_n};
                    end
                end

                I2C_START: begin
                    scl_oe <= 1'b1;
                    sda_oe <= 1'b1;
                    if (clk_count < CLK_DIV/2) begin
                        scl_out <= 1'b1;
                        sda_out <= 1'b0;  // START condition
                        clk_count <= clk_count + 1;
                    end else if (clk_count < CLK_DIV) begin
                        scl_out <= 1'b0;
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= '0;
                    end
                end

                I2C_ADDRESS: begin
                    if (clk_count < CLK_DIV/2) begin
                        scl_out <= 1'b0;
                        sda_out <= shift_reg[7-bit_count];
                        clk_count <= clk_count + 1;
                    end else if (clk_count < CLK_DIV) begin
                        scl_out <= 1'b1;
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= '0;
                        bit_count <= bit_count + 1;
                    end
                end

                I2C_ACK: begin
                    if (clk_count < CLK_DIV/2) begin
                        scl_out <= 1'b0;
                        sda_oe <= 1'b0;  // Release SDA for ACK
                        clk_count <= clk_count + 1;
                    end else if (clk_count < CLK_DIV) begin
                        scl_out <= 1'b1;
                        if (!sda_in) ack_error <= 1'b0;
                        else ack_error <= 1'b1;
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= '0;
                        bit_count <= '0;
                        sda_oe <= 1'b1;
                        if (read_write_n) shift_reg <= '0;
                        else shift_reg <= write_data;
                    end
                end

                I2C_READ: begin
                    if (clk_count < CLK_DIV/2) begin
                        scl_out <= 1'b0;
                        sda_oe <= 1'b0;  // Release SDA for reading
                        clk_count <= clk_count + 1;
                    end else if (clk_count < CLK_DIV) begin
                        scl_out <= 1'b1;
                        shift_reg <= {shift_reg[6:0], sda_in};
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= '0;
                        bit_count <= bit_count + 1;
                        if (bit_count == 7) begin
                            read_data <= {shift_reg[6:0], sda_in};
                        end
                    end
                end

                I2C_WRITE: begin
                    if (clk_count < CLK_DIV/2) begin
                        scl_out <= 1'b0;
                        sda_out <= shift_reg[7-bit_count];
                        sda_oe <= 1'b1;
                        clk_count <= clk_count + 1;
                    end else if (clk_count < CLK_DIV) begin
                        scl_out <= 1'b1;
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= '0;
                        bit_count <= bit_count + 1;
                    end
                end

                I2C_STOP: begin
                    scl_oe <= 1'b1;
                    sda_oe <= 1'b1;
                    if (clk_count < CLK_DIV/2) begin
                        scl_out <= 1'b0;
                        sda_out <= 1'b0;
                        clk_count <= clk_count + 1;
                    end else if (clk_count < CLK_DIV) begin
                        scl_out <= 1'b1;
                        sda_out <= 1'b1;  // STOP condition
                        clk_count <= clk_count + 1;
                        transaction_done <= 1'b1;
                    end else begin
                        clk_count <= '0;
                    end
                end
            endcase
        end
    end

endmodule : i2c_master

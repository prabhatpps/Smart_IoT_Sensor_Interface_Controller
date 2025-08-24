//=============================================================================
// Synchronous FIFO with configurable data width and depth
//=============================================================================

`timescale 1ns/1ps

module sync_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH = 16
) (
    input  logic                    clk,
    input  logic                    rst_n,

    // Write interface
    input  logic                    wr_en,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    output logic                    full,

    // Read interface  
    input  logic                    rd_en,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic                    empty,

    // Status
    output logic [$clog2(DEPTH+1)-1:0] count
);

    // Internal signals
    logic [$clog2(DEPTH)-1:0] wr_ptr;
    logic [$clog2(DEPTH)-1:0] rd_ptr;
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [$clog2(DEPTH+1)-1:0] fifo_count;

    // Full and empty flags
    assign full = (fifo_count == DEPTH);
    assign empty = (fifo_count == 0);
    assign count = fifo_count;

    // Write operation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
        end else if (wr_en && !full) begin
            mem[wr_ptr] <= wr_data;
            wr_ptr <= (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1;
        end
    end

    // Read operation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= '0;
            rd_data <= '0;
        end else if (rd_en && !empty) begin
            rd_data <= mem[rd_ptr];
            rd_ptr <= (rd_ptr == DEPTH-1) ? '0 : rd_ptr + 1;
        end
    end

    // FIFO count
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_count <= '0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b01: fifo_count <= fifo_count - 1;
                2'b10: fifo_count <= fifo_count + 1;
                default: fifo_count <= fifo_count;
            endcase
        end
    end

endmodule : sync_fifo

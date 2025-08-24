//=============================================================================
// Synchronous FIFO Module
// Author: Prabhat Pandey  
// Date: August 24, 2025
// Description: Parameterizable synchronous FIFO with full/empty flags
//=============================================================================

module sync_fifo #(
    parameter int DATA_WIDTH = 16,
    parameter int DEPTH = 8,
    parameter int ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    wr_en,
    input  logic                    rd_en,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic                    full,
    output logic                    empty,
    output logic [ADDR_WIDTH:0]     count
);

    // Internal signals
    logic [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;
    logic [ADDR_WIDTH:0]   wr_ptr_ext, rd_ptr_ext;

    // Memory array
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Extended pointers for full/empty detection
    assign wr_ptr_ext = {wr_ptr[ADDR_WIDTH-1], wr_ptr};
    assign rd_ptr_ext = {rd_ptr[ADDR_WIDTH-1], rd_ptr};

    // Write pointer logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
        end else if (wr_en && !full) begin
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // Read pointer logic  
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= '0;
        end else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
    end

    // Memory write
    always_ff @(posedge clk) begin
        if (wr_en && !full) begin
            mem[wr_ptr] <= wr_data;
        end
    end

    // Memory read (combinational)
    assign rd_data = mem[rd_ptr];

    // Status flags
    assign full = (wr_ptr_ext == {~rd_ptr_ext[ADDR_WIDTH], rd_ptr_ext[ADDR_WIDTH-1:0]});
    assign empty = (wr_ptr_ext == rd_ptr_ext);

    // Count calculation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= '0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: count <= count + 1'b1;  // Write only
                2'b01: count <= count - 1'b1;  // Read only
                default: count <= count;       // Both or neither
            endcase
        end
    end

    // Assertions for verification
    `ifdef SIMULATION
        always @(posedge clk) begin
            assert (count <= DEPTH) 
                else $error("FIFO count exceeds depth: %0d > %0d", count, DEPTH);

            if (full) begin
                assert (!wr_en) 
                    else $warning("Write attempted when FIFO is full");
            end

            if (empty) begin
                assert (!rd_en) 
                    else $warning("Read attempted when FIFO is empty");
            end
        end
    `endif

endmodule : sync_fifo

`timescale 1ns / 1ps

module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    // Write Domain (Source)
    input  wire                  wr_clk,
    input  wire                  wr_rst_n,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  full,

    // Read Domain (Destination)
    input  wire                  rd_clk,
    input  wire                  rd_rst_n,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  empty
);

    // Pointers (1 extra bit for full/empty detection)
    reg [ADDR_WIDTH:0] wr_ptr_bin, wr_ptr_gray;
    reg [ADDR_WIDTH:0] rd_ptr_bin, rd_ptr_gray;

    wire [ADDR_WIDTH:0] wr_ptr_gray_sync; // Write pointer synced to Read clock
    wire [ADDR_WIDTH:0] rd_ptr_gray_sync; // Read pointer synced to Write clock

    // We only use the lower bits [ADDR_WIDTH-1:0] for addressing memory
    fifo_mem #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) u_mem (
        .wr_clk(wr_clk), 
        .wr_en(wr_en && !full), //cant write if full
        .wr_addr(wr_ptr_bin[ADDR_WIDTH-1:0]), 
        .wr_data(wr_data),
        
        .rd_clk(rd_clk), 
        .rd_en(rd_en && !empty), //cant read if empty
        .rd_addr(rd_ptr_bin[ADDR_WIDTH-1:0]), 
        .rd_data(rd_data)
    );

    
    // Pass Write Pointer -> Read Domain
    synchronizer #(.WIDTH(ADDR_WIDTH+1)) sync_wr2rd (
        .clk(rd_clk), .rst_n(rd_rst_n), .d_in(wr_ptr_gray), .d_out(wr_ptr_gray_sync)
    );

    // Pass Read Pointer -> Write Domain
    synchronizer #(.WIDTH(ADDR_WIDTH+1)) sync_rd2wr (
        .clk(wr_clk), .rst_n(wr_rst_n), .d_in(rd_ptr_gray), .d_out(rd_ptr_gray_sync)
    );

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= 0;
            wr_ptr_gray <= 0;
        end else if (wr_en && !full) begin
            // Increment Binary Pointer
            wr_ptr_bin <= wr_ptr_bin + 1;
            // Convert Binary to Gray
            wr_ptr_gray <= (wr_ptr_bin + 1) ^ ((wr_ptr_bin + 1) >> 1);
        end
    end

    // FULL Condition:
    // In Gray code, Full means MSB and 2nd MSB are different, rest are same.
    assign full = (wr_ptr_gray == {~rd_ptr_gray_sync[ADDR_WIDTH:ADDR_WIDTH-1], rd_ptr_gray_sync[ADDR_WIDTH-2:0]});

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin  <= 0;
            rd_ptr_gray <= 0;
        end else if (rd_en && !empty) begin
            rd_ptr_bin  <= rd_ptr_bin + 1;
            rd_ptr_gray <= (rd_ptr_bin + 1) ^ ((rd_ptr_bin + 1) >> 1);
        end
    end

    // EMPTY Condition:
    // Pointers are identical in Gray code.
    assign empty = (rd_ptr_gray == wr_ptr_gray_sync);

endmodule

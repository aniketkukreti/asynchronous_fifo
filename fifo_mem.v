`timescale 1ns / 1ps

module fifo_mem #(
    parameter DATA_WIDTH = 8,  //can be changed by the user when we instantiate the module
    parameter ADDR_WIDTH = 4   
)(
    input  wire                  wr_clk,
    input  wire                  wr_en,
    input  wire [ADDR_WIDTH-1:0] wr_addr,  //write pointer
    input  wire [DATA_WIDTH-1:0] wr_data,
    
    input  wire                  rd_clk,
    input  wire                  rd_en,
    input  wire [ADDR_WIDTH-1:0] rd_addr,  //read pointer
    output reg  [DATA_WIDTH-1:0] rd_data
);

    localparam DEPTH = 1 << ADDR_WIDTH;  //so the depth is always 2^width(local param since its an internal variable)
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Write Logic (Synchronous to Write Clock)
    always @(posedge wr_clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;  //write teh data to the location write pointer is pointing at
    end

    // Read Logic (Synchronous to Read Clock)
    always @(posedge rd_clk) begin
        if (rd_en)
            rd_data <= mem[rd_addr];  //read the data from the location read pointer is pointing at
    end

endmodule
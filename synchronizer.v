`timescale 1ns / 1ps

module synchronizer #(
    parameter WIDTH = 4
)(
    input  wire             clk,      // Destination Clock
    input  wire             rst_n,    // Active low reset
    input  wire [WIDTH-1:0] d_in,     // Input from source domain
    output reg  [WIDTH-1:0] d_out     // Output to destination domain
);

    reg [WIDTH-1:0] q1; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1    <= 0;
            d_out <= 0;
        end else begin
            q1    <= d_in; // Stage 1
            d_out <= q1;   // Stage 2 
        end
    end

endmodule
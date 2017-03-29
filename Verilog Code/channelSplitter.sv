`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.03.2017 12:28:57
// Design Name: 
// Module Name: channelSplitter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module channelSplitter(clock, data_in, 
                       R_data_out, G_data_out, B_data_out,
                       R_ready_out, G_ready_out, B_ready_out);

parameter int bitwidth = 8;

input                 clock;
input  [bitwidth-1:0] data_in;
output [bitwidth-1:0] R_data_out;
output [bitwidth-1:0] G_data_out;
output [bitwidth-1:0] B_data_out;
output                R_ready_out; 
output                G_ready_out;
output                B_ready_out;
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

logic[1:0] mod3Count = 0;

logic[bitwidth-1:0] R_reg;
logic[bitwidth-1:0] G_reg;
logic[bitwidth-1:0] B_reg;   
logic               R_ready;
logic               G_ready;
logic               B_ready;
                                   

always_ff @ (posedge clock) begin
    
    if (mod3Count == 3) begin
        mod3Count <= 0;
    end
    else begin
        mod3Count <= mod3Count + 1;
    end
    
end
   
   
always_ff @ (posedge clock) begin
    if (mod3Count == 0) begin
        R_reg <= data_in;
        R_ready <= 1;
        G_ready <= 0;
        B_ready <= 0;
    end
    if (mod3Count == 1) begin
        G_reg <= data_in;
        R_ready <= 0;
        G_ready <= 1;
        B_ready <= 0;
    end
    if (mod3Count == 2) begin
        B_reg <= data_in;
        R_ready <= 0;
        G_ready <= 0;
        B_ready <= 1;
    end
end
   
   
assign R_data_out  = R_reg;
assign G_data_out  = G_reg;
assign B_data_out  = B_reg; 

assign R_ready_out = R_ready;
assign G_ready_out = G_ready;
assign B_ready_out = B_ready;
    
endmodule

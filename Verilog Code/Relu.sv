`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date: 15.02.2017 15:34:15
//////////////////////////////////////////////////////////////////////////////////



module Relu(clock, data_in, isValid_in, data_out, isValid_out); 

// These parameters are set during instantiation
parameter  int bitwidth    = 8;
parameter  int filterWidth = 3;
parameter  int imageWidth  = 11;
localparam int filterSize  = filterWidth * filterWidth;
localparam int bufferWidth = imageWidth - filterWidth - 1;

input                clock;
input [bitwidth-1:0] data_in;
input                isValid_in;
output[bitwidth-1:0] data_out;
output               isValid_out;

logic[bitwidth-1:0] data_out_reg;

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

always_ff @ (posedge clock) begin

    if (isValid_in) begin
        if (data_in >= 0) begin
            data_out_reg <= data_in;
        end
        else begin
            data_out_reg <= 0;
        end
    end
end

assign data_out = data_out_reg;

endmodule

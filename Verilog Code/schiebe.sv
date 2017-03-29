`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date: 27.02.2017 20:07:23
//////////////////////////////////////////////////////////////////////////////////


module schiebe(clock, enable, data_in, data_out);

// These parameters are set during instantiation
parameter  int bitwidth    = 8;
parameter  int imageWidth  = 11;
parameter  int filterWidth = 3;
localparam int filterSize  = filterWidth * filterWidth;
localparam int width       = imageWidth - filterWidth - 1;

input                 clock;
input                 enable;
input  [bitwidth-1:0] data_in;
output [bitwidth-1:0] data_out;

logic[bitwidth-1:0] buffer[0:width];
logic[bitwidth-1:0] last_element;

int i;
always @ (posedge clock) begin

    if (enable) begin
        buffer[0] <= data_in; // new first element is input-data
        last_element <= buffer[width];
        for (i = 1; i <= width; i = i+1 ) begin
            buffer[i] <= buffer[i-1]; // other elements are the ones from one to the left
        end
    end
end

assign data_out = last_element; // output last element

endmodule

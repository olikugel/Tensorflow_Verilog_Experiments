`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date: 20.02.2017 16:54:33
// Design Name: 
// Module Name: convModuleWithAdder
//////////////////////////////////////////////////////////////////////////////////


module convModuleWithAdder(clock, data_in, isValid, filter_in, dotproduct, dotproductReady);

// These parameters can be changed during instantiation
parameter  int bitwidth    = 8;
parameter  int filterWidth = 3;
parameter  int imageWidth  = 11;
localparam int filterSize  = filterWidth * filterWidth;

input                clock;
input [bitwidth-1:0] data_in;
input                isValid;
input [bitwidth-1:0] filter_in;
output[31:0]         dotproduct;
output               dotproductReady;

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

logic[bitwidth-1:0] products[filterWidth-1:0][0:filterWidth-1]; // initialise products to zero
logic               productsReady = 0;
logic[31:0]         sum;
logic               sumReady = 0;

convModule_genric #(.bitwidth(bitwidth), .filterWidth(filterWidth), .imageWidth(imageWidth)) myConvModule (
    .clock(clock),
    .data_in(data_in),
    .isValid(isValid),
    .filter_in(filter_in),
    .products_out(products),
    .productsReady_out(productsReady)
);

adderTree #(.bitwidth(bitwidth), .filterWidth(filterWidth)) myAdderTree (
    .clock(clock),
    .addends(products), 
    .canStartAdding(productsReady),
    .sum(sum),
    .sumReady_out(sumReady)
);

assign dotproduct      = sum;
assign dotproductReady = sumReady;

endmodule






























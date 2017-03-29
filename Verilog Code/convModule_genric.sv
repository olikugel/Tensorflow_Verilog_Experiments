`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date: 15.02.2017 15:34:15
// Module Name: convModule
//////////////////////////////////////////////////////////////////////////////////



module convModule_genric(clock, data_in, isValid, filter_in, products_out, productsReady_out); 

// These parameters are set during instantiation
parameter  int bitwidth    = 8;
parameter  int filterWidth = 3;
parameter  int imageWidth  = 11;
localparam int filterSize  = filterWidth * filterWidth;
localparam int bufferWidth = imageWidth - filterWidth - 1;
// this is how long it takes for all data items to be in the right place in the shiftreges
localparam int filterDelay = bufferWidth * (filterWidth - 1) + filterSize + filterWidth;

input                clock;
input [bitwidth-1:0] data_in;
input                isValid;
input [bitwidth-1:0] filter_in;
output[bitwidth-1:0] products_out[filterWidth-1:0][0:filterWidth-1]; // this will be the input to the adder
output               productsReady_out; // high when all products have been calculated

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

logic[bitwidth-1:0] filter  [filterWidth-1:0][0:filterWidth-1]; // 2D array                                      
logic[bitwidth-1:0] products[filterWidth-1:0][0:filterWidth-1]; // 2D array 
logic[bitwidth-1:0] shiftreg[filterWidth:0]  [0:filterWidth-1]; // 2D array 
logic[bitwidth-1:0] buffer_out[0:filterWidth-1]; 
logic[bitwidth-1:0] counter = 0;
logic               valuesInPlace = 0;
logic               productsReady = 0;

assign shiftreg[0] = '{0,0,0}; // this shiftreg is not used

assign filter[0]   = '{1,2,3};
assign filter[1]   = '{4,5,6};
assign filter[2]   = '{7,8,9};

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


always_ff @ (posedge clock) begin
    if (isValid) begin 
        buffer_out[0]   <= data_in;
        
        for (int i = 1; i <= filterWidth; i++) begin
            shiftreg[i] <= { buffer_out[i-1], shiftreg[i][0:filterWidth-2] };
        end 
    end
end


int k;
int l;
always_ff @ (posedge clock) begin

    if (isValid) begin
        if (counter <= filterDelay) begin  // counter could also decrement until 0, consider strides
            valuesInPlace <= 0;
            for (k = 0; k < filterWidth; k++) begin
                for (l = 0; l < filterWidth; l++) begin
                    products[k][l] <= shiftreg[k+1][l] * filter[k][l];
                end
            end
            counter <= counter + 1;
        end
        else begin 
            valuesInPlace <= 1; // all values are in place in their shiftreges
            counter <= 0; // reset counter --> move convolution window
        end
    end  
end 
   
   
always_ff @ (posedge clock) begin

    if (valuesInPlace) begin
        productsReady <= 1;
    end
    else begin
        productsReady <= 0;
    end
        
end   
   
      
genvar j;
generate
    for (j = 0; j < filterWidth; j++) begin : Buffers
        schiebe myBuffer (
            .clock(clock),
            .enable(isValid),
            .data_in(shiftreg[j][filterWidth-1]), 
            .data_out(buffer_out[j])
            );
    end 
endgenerate


assign products_out = products;
assign productsReady_out = productsReady;


endmodule


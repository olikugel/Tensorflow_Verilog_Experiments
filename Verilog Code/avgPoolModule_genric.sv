`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date: 15.02.2017 15:34:15
//////////////////////////////////////////////////////////////////////////////////



module avgPoolModule_genric(clock, data_in, isValid, average_out, averageReady_out); 

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
output[bitwidth-1:0] average_out;
output               averageReady_out; // high when the average has been calculated

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

logic[bitwidth-1:0] shiftreg[filterWidth:0][0:filterWidth-1]; // 2D array 
logic[bitwidth-1:0] window[0:filterSize-1];
logic[bitwidth-1:0] buffer_out[0:filterWidth-1]; 
logic[bitwidth-1:0] average        = 0;
logic               averageReady   = 0;
logic               sumReady       = 0;
logic[bitwidth-1:0] counter        = 0;
logic[bitwidth-1:0] windowCounter  = 0;
logic               valuesInPlace  = 0;
logic               valuesInWindow = 0;


assign shiftreg[0] = '{0,0,0}; // this shiftreg is not used

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


always_ff @ (posedge clock) begin
    if (isValid) begin 
        buffer_out[0]   <= data_in;
        
        for (int i = 1; i <= filterWidth; i++) begin
            shiftreg[i] <= { buffer_out[i-1], shiftreg[i][0:filterWidth-2] };
        end 
    end
end


always_ff @ (posedge clock) begin
    if (isValid) begin 
        if (counter <= filterDelay) begin
            valuesInPlace <= 0;
            counter <= counter + 1;
        end
        else begin 
            valuesInPlace <= 1; // all values are in place in their shiftreges
            counter <= 0; // reset counter --> move convolution window
        end
    end
end 
  
    
int m = 0;
int k;
int l;  
always_ff @ (posedge clock) begin
    if (isValid) begin 
        if (valuesInPlace) begin
            for (k = 0; k < filterWidth; k++) begin
                for (l = 0; l < filterWidth; l++) begin
                    // copy all values from shiftreges to a window, we are looking for the average of this window
                    window[m] <= shiftreg[k+1][l]; 
                    m = m + 1;
                end
            end
            valuesInWindow <= 1; // all values have been copied over to window and are in the right place
        end
    end
end   
   
   
always_ff @ (posedge clock) begin
    if (isValid) begin 
        if (valuesInWindow && windowCounter < filterSize) begin
            average       <= average + window[windowCounter]; // this really is the sum, not yet the average
            windowCounter <= windowCounter + 1;
        end
        
        if (windowCounter == filterSize-1) begin
            sumReady <= 1;
        end
        
        if (windowCounter == filterSize) begin
            average        <= 0;
            windowCounter  <= 0;
            valuesInWindow <= 0;
        end
    end
end   

  
always_ff @ (posedge clock) begin
    
    if (sumReady) begin
        average <= average / filterSize; // this is where we compute the final average by dividing the sum by the filterSize
        sumReady <= 0;
        averageReady <= 1;
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


assign average_out      = average;
assign averageReady_out = averageReady;


endmodule


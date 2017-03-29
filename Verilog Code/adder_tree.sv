`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date: 08.02.2017
//////////////////////////////////////////////////////////////////////////////////


module adderTree (clock, addends, canStartAdding, sum, sumReady_out);

// these parameters are set during instantiation
parameter int bitwidth         = 8;   
parameter int filterWidth      = 3;
localparam int numberOfAddends = filterWidth * filterWidth;  
localparam int arraySize = numberOfAddends + numberOfAddends - 1;
  
input                clock;
input [bitwidth-1:0] addends[filterWidth-1:0][0:filterWidth-1];
input                canStartAdding;
output[31:0]         sum;
output               sumReady_out;

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

logic [bitwidth-1:0] values[filterWidth-1:0][0:filterWidth-1];
logic [31:0]         addReducer[0:arraySize-1];
logic [31:0]         leftHalf  [0:numberOfAddends-1];
logic [bitwidth-1:0] addendIndex = 0;
logic [bitwidth-1:0] sumIndex    = (arraySize + 1) / 2; // be aware: only works pipelined for powers of 2
logic                keepAdding  = 0;
logic                sumReady    = 0;

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

assign values = addends;

int i = 0;
always_ff @ (posedge clock) begin
    if (canStartAdding && sumIndex < arraySize) begin
        for (int k = 0; k < filterWidth; k++) begin
            for (int l = 0; l < filterWidth; l++) begin
                leftHalf[i] <= values[k][l];
                i = i + 1;
            end
        end 
    end
end      


assign addReducer[0:numberOfAddends-1]         = leftHalf[0:numberOfAddends-1]; // first half of addReducer are the input addends
assign addReducer[numberOfAddends:arraySize-1] = '{numberOfAddends-1{0}};       // second half will be the sums, start of as zeros


always_ff @ (posedge clock) begin
    if (canStartAdding) begin
        keepAdding <= 1;
    end
end


always_ff @ (posedge clock) begin
    
    if (keepAdding && sumIndex < arraySize) begin
        addReducer[sumIndex] <= addReducer[addendIndex] + addReducer[addendIndex+1];
        addendIndex          <= addendIndex + 2;
        sumIndex             <= sumIndex    + 1;
    end  

    if (sumIndex == arraySize-1) begin
        sumReady <= 1;
    end
    
    if (sumIndex == arraySize) begin // reset control
        sumIndex   <= (arraySize + 1) / 2;
        keepAdding <= 0;
        sumReady   <= 0;
    end

end

assign sum          = addReducer[arraySize-1]; // assign sum to output
assign sumReady_out = sumReady;

endmodule

 



















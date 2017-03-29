`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date: 16.02.2017 12:37:07
// Module Name: convModule_tb
//////////////////////////////////////////////////////////////////////////////////


module convModule_tb();

logic               clock       = 0;
localparam int      bitwidth    = 8;
localparam int      filterWidth = 3;
localparam int      filterSize  = filterWidth * filterWidth;
localparam int      bufferWidth = 3;

logic[bitwidth-1:0] currentData = 1;
logic               isValid     = 0;
logic               revalidate  = 0;


maxPoolModule_genric #(.bitwidth(bitwidth), .filterWidth(filterWidth)) myConvModule (
    .clock(clock),
    .data_in(currentData), 
    .isValid(isValid)
);

     
always
begin
    #10 clock = !clock;
end


initial
begin
    clock = 0;
    isValid = 1;
    repeat(19)   @ (posedge clock); #1      
    isValid = 0; @ (posedge clock); #1
    isValid = 1; @ (posedge clock); #1
    repeat(20)   @ (posedge clock); #1
    $finish;
end


always_ff @ (posedge clock) begin

    // Simulate data coming in
    if (currentData < 38 && currentData != 19) begin
        currentData <= (currentData + 1);
    end
    if (currentData == 19) begin
        currentData <= 'X;
        revalidate  <= 1;    
    end
    if (revalidate) begin
        currentData <= 20;
        revalidate  <= 0;
    end
end


endmodule



`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date: 16.02.2017 12:37:07
// Module Name: convModule_tb
//////////////////////////////////////////////////////////////////////////////////


module convModuleWithAdder_tb();

logic               clock       = 0;
localparam int      bitwidth    = 8;
localparam int      filterWidth = 3;
localparam int      filterSize  = filterWidth * filterWidth;
localparam int      imageWidth  = 11;
logic[bitwidth-1:0] currentData = 1;
logic[bitwidth-1:0] index       = 0;
logic               isValid     = 0;
logic               revalidate  = 0;


convModuleWithAdder #(.bitwidth(bitwidth), .filterWidth(filterWidth), .imageWidth(imageWidth)) myConvModule (
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
    repeat(19)   @ (posedge clock); #1
    $finish;
end


always_ff @ (posedge clock) begin

    // Simulate data coming in
    if (currentData < 37 && currentData != 19) begin
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



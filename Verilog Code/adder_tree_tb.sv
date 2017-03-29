`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date: 08.02.2017
//////////////////////////////////////////////////////////////////////////////////

module adder_tree_tb();

logic clock;

localparam int           bitwidth                    = 8;
localparam int           numberOfAddends             = 9;
localparam[bitwidth-1:0] values[0:numberOfAddends-1] = {9, 16, 21, 24, 25, 24, 21, 16, 9}; // {1,2,3,4,5,6,7,8,9};


adder_tree #(.bitwidth(bitwidth), .numberOfAddends(numberOfAddends)) myAdderTree (
    .clock(clock),
    .values(values)
);


always
begin
    #10 clock = !clock;
end


initial 
begin
    clock = 0;
    
    repeat(9) @ (posedge clock); #1
    
    $finish;
end


endmodule

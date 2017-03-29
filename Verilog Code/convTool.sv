`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date: 15.03.2017 16:01:54
// Module Name: convTool
//////////////////////////////////////////////////////////////////////////////////

module convTool();

logic               clock       = 0;
localparam int      bitwidth    = 8;
localparam int      filterWidth = 3;
localparam int      imageWidth  = 11;

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

logic[31:0]         R_dotproduct;
logic[31:0]         G_dotproduct;
logic[31:0]         B_dotproduct;   
logic               R_dotprod_ready;
logic               G_dotprod_ready;
logic               B_dotprod_ready;

reg [bitwidth-1:0] DATA [0:299];
reg [bitwidth-1:0] FILTER [0:299];
reg [bitwidth-1:0] R_pos = 0;
reg [bitwidth-1:0] G_pos = 1;
reg [bitwidth-1:0] B_pos = 2;

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

convModuleWithAdder #(.bitwidth(bitwidth), .filterWidth(filterWidth), .imageWidth(imageWidth)) convR (
    .clock(clock),
    .data_in(DATA[R_pos]),
    .isValid('b1),
    .filter_in(FILTER[R_pos]),
    .dotproduct(R_dotproduct),
    .dotproductReady(R_dotprod_ready)
);

convModuleWithAdder #(.bitwidth(bitwidth), .filterWidth(filterWidth), .imageWidth(imageWidth)) convG (
    .clock(clock),
    .data_in(DATA[G_pos]),
    .isValid('b1),
    .filter_in(FILTER[G_pos]),
    .dotproduct(G_dotproduct),
    .dotproductReady(G_dotprod_ready)
);

convModuleWithAdder #(.bitwidth(bitwidth), .filterWidth(filterWidth), .imageWidth(imageWidth)) convB (
    .clock(clock),
    .data_in(DATA[B_pos]),
    .isValid('b1),
    .filter_in(FILTER[B_pos]),
    .dotproduct(B_dotproduct),
    .dotproductReady(B_dotprod_ready)
);

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

initial
begin
    clock = 0;
    $readmemh("tensor1.data", DATA);
    $readmemh("filter.data", FILTER);
    
    repeat(300) @ (posedge clock); #1    
    $finish;
end


always
begin
    #10 clock = !clock;
end


always_ff @ (posedge clock) begin
   R_pos <= R_pos + 3;
   G_pos <= G_pos + 3;
   B_pos <= B_pos + 3;
end


always_ff @ (posedge clock) begin
    if (R_dotprod_ready) begin $display("Red dotproduct: %d", R_dotproduct); end
    if (G_dotprod_ready) begin $display("Green dotproduct: %d", G_dotproduct); end
    if (B_dotprod_ready) begin $display("Blue dotproduct: %d", B_dotproduct); end
end


endmodule

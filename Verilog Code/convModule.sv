`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date: 15.02.2017 15:34:15
// Module Name: convModule
//////////////////////////////////////////////////////////////////////////////////



module convModule(clock, reset, data_in, products, isReady);

// These parameters can be changed during instantiation
parameter  int bitwidth    = 8;
parameter  int filterWidth = 3;
localparam int filterSize  = filterWidth * filterWidth;

input                clock;
input                reset;
input [bitwidth-1:0] data_in;
output[bitwidth-1:0] products[0:filterSize-1]; // this will be the input to adder tree
output               isReady; // high when all products have been calculated

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

logic[bitwidth-1:0] filter  [0:filterSize-1] = {9,8,7,6,5,4,3,2,1};                                            
logic[bitwidth-1:0] products[0:filterSize-1];
logic               isReady = 0;
    
logic[bitwidth-1:0] data_in_0   = 0; // input for buffer0
logic[bitwidth-1:0] data_out_0;      // output from buffer0
logic[bitwidth-1:0] buf0_counter;    // number of items in buffer0
logic               buf0_rd_en  = 0;
logic               buf0_wr_en  = 0;
logic               buf0_empty  = 0;
logic               buf0_full   = 0;

logic[bitwidth-1:0] data_in_1   = 0; // input for buffer1
logic[bitwidth-1:0] data_out_1;      // output from buffer1
logic[bitwidth-1:0] buf1_counter;    // number of items in buffer1
logic               buf1_rd_en  = 0;
logic               buf1_wr_en  = 0;
logic               buf1_empty  = 0;
logic               buf1_full   = 0;

//Convolution window registers
logic[bitwidth-1:0] conv0_reg = 0;
logic[bitwidth-1:0] conv1_reg = 0;
logic[bitwidth-1:0] conv2_reg = 0;
logic[bitwidth-1:0] conv3_reg = 0;
logic[bitwidth-1:0] conv4_reg = 0;
logic[bitwidth-1:0] conv5_reg = 0;
logic[bitwidth-1:0] conv6_reg = 0;
logic[bitwidth-1:0] conv7_reg = 0;
logic[bitwidth-1:0] conv8_reg = 0;

logic[bitwidth-1:0] counter = 0;


// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


always_ff @ (posedge clock) begin

    conv0_reg <= data_in;
    conv1_reg <= conv0_reg;
    conv2_reg <= conv1_reg;
//      data_in_0 <= conv2_reg;  // insert to buffer0
//  conv3_reg <= data_out_0; // retrieve from buffer0 
    conv3_reg <= conv2_reg;
    conv4_reg <= conv3_reg;
    conv5_reg <= conv4_reg;
//      data_in_1 <= conv5_reg;  // insert to buffer1
//  conv6_reg <= data_out_1; // retrieve from buffer1 
    conv6_reg <= conv5_reg;
    conv7_reg <= conv6_reg;
    conv8_reg <= conv7_reg;

end


always_ff @ (posedge clock) begin

   buf0_wr_en <= buf0_full  ? 0 : 1;
   buf0_rd_en <= buf0_empty ? 0 : 1;
   
   buf1_wr_en <= buf1_full  ? 0 : 1;
   buf1_rd_en <= buf1_empty ? 0 : 1;
   
end


always_ff @ (posedge clock) begin

    if (counter < filterSize+2) begin
        products[0] <= conv8_reg * filter[0];
        products[1] <= conv7_reg * filter[1];
        products[2] <= conv6_reg * filter[2];
        products[3] <= conv5_reg * filter[3];
        products[4] <= conv4_reg * filter[4];
        products[5] <= conv3_reg * filter[5];
        products[6] <= conv2_reg * filter[6];
        products[7] <= conv1_reg * filter[7];
        products[8] <= conv0_reg * filter[8];
    
        counter <= counter + 1;
    end
    else begin
        isReady <= 1; // all products have been calculated
    end
end


always_ff @ (posedge clock) begin // this is just for debugging! :)
    $display("Number of items in buffer0: ", buffer0.buffer_counter);
    $display("Number of items in buffer1: ", buffer1.buffer_counter);
end


buffer buffer0( .clk(clock), 
              .rst(reset), 
              .buf_in(conv2_reg), 
              .buf_out(data_out_0), 
              .wr_en(buf0_wr_en), 
              .rd_en(buf0_rd_en), 
              .buf_empty(buf0_empty), 
              .buf_full(buf0_full), 
              .buffer_counter(buf0_counter)
           );
           
buffer buffer1( .clk(clock), 
              .rst(reset), 
              .buf_in(conv5_reg), 
              .buf_out(data_out_1), 
              .wr_en(buf1_wr_en), 
              .rd_en(buf1_rd_en), 
              .buf_empty(buf1_empty), 
              .buf_full(buf1_full), 
              .buffer_counter(buf1_counter)
           );
    
endmodule



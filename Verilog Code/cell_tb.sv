`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date: 28.10.2016
//////////////////////////////////////////////////////////////////////////////////

import cell_package::*;



module cell_tb();

logic clock;

localparam int bitwidth = 8;
localparam int inputVectorSize = 3;

logic[bitwidth-1:0] data_Q0[0:inputVectorSize-1]; 
logic[bitwidth-1:0] data_Q1[0:inputVectorSize-1];

cellstruct streamInH0;
cellstruct streamOutH0;

cellstruct streamInH1;
cellstruct streamOutH1;

cellstruct streamInH2;
cellstruct streamOutH2;

cellstruct streamInP0;
cellstruct streamOutP0;


// ---------- CELL INSTANTIATIONS ----------
ComputationCell #(.bitwidth(bitwidth), .inputVectorSize(inputVectorSize), .weights({0,1,2}), .isLastCellParam(0)) cellH0 (
    .clock(clock),
    .streamIn(streamInH0),
    .streamOut(streamOutH0)
);

assign streamInH1 = streamOutH0;

ComputationCell #(.bitwidth(bitwidth), .inputVectorSize(inputVectorSize), .weights({1,2,3}), .isLastCellParam(0)) cellH1 (
    .clock(clock),
    .streamIn(streamInH1), 
    .streamOut(streamOutH1)
);

assign streamInH2 = streamOutH1;

ComputationCell #(.bitwidth(bitwidth), .inputVectorSize(inputVectorSize), .weights({2,3,4}), .isLastCellParam(1)) cellH2 (
    .clock(clock),
    .streamIn(streamInH2), 
    .streamOut(streamOutH2)
);

assign streamInP0 = streamOutH2;

ComputationCell #(.bitwidth(bitwidth), .inputVectorSize(inputVectorSize), .weights({3,4,5}), .isLastCellParam(0)) cellP0 (
    .clock(clock),
    .streamIn(streamInP0),
    .streamOut(streamOutP0)    
);
// ------------------------------------------



always
begin
    #10 clock = !clock;
end


// initialise data
initial 
begin
    data_Q0[0] = 4;
    data_Q0[1] = 5;
    data_Q0[2] = 6;
    
    data_Q1[0] = 2;
    data_Q1[1] = 3;
    data_Q1[2] = 4;
end


// Simulate data coming in 
initial 
begin
    clock = 0;
    streamInH0.isResult    = 0;
    
    // -- X
    streamInH0.data    = 'X;
    streamInH0.isValid =  0; 
    streamInH0.isFirst =  0;
    streamInH0.isLast  =  0;
    streamInH0.wIndex  = 'X;
    @ (posedge clock);  
    #1
    
    // -- 4
    streamInH0.data    = data_Q0[0];
    streamInH0.isValid = 1;  
    streamInH0.isFirst = 1;
    streamInH0.isLast  = 0; 
    streamInH0.wIndex  = 0;
    @ (posedge clock);
    #1;
    
    // -- 5
    streamInH0.data    = data_Q0[1];
    streamInH0.isValid = 1;    
    streamInH0.isFirst = 0;
    streamInH0.isLast  = 0;  
    streamInH0.wIndex  = 1;
    @ (posedge clock);
    #1;
    
    // -- 6
    streamInH0.data    = data_Q0[2];
    streamInH0.isValid = 1;   
    streamInH0.isFirst = 0;
    streamInH0.isLast  = 1;
    streamInH0.wIndex  = 2;
    @ (posedge clock);  
    #1;
    
    // -- 2x X
    streamInH0.data    = 'X;
    streamInH0.isValid =  0; 
    streamInH0.isFirst =  0;
    streamInH0.isLast  =  0;
    streamInH0.wIndex  = 'X;
    @ (posedge clock);  
    #1;
    @ (posedge clock);  
    #1;
    
    // -- 2
    streamInH0.data    = data_Q1[0];
    streamInH0.isValid = 1; 
    streamInH0.isFirst = 1;
    streamInH0.isLast  = 0;
    streamInH0.wIndex  = 0;
    @ (posedge clock);
    #1;
    
    // -- 3
    streamInH0.data    = data_Q1[1];
    streamInH0.isValid = 1; 
    streamInH0.isFirst = 0;
    streamInH0.isLast  = 0;
    streamInH0.wIndex  = 1;
    @ (posedge clock);
    #1;
    
    // -- 4
    streamInH0.data    = data_Q1[2];
    streamInH0.isValid = 1;
    streamInH0.isFirst = 0;
    streamInH0.isLast  = 1;
    streamInH0.wIndex  = 2;
    @ (posedge clock);  
    #1;
    
    // -- 2x X
    streamInH0.data    = 'X;
    streamInH0.isValid =  0;
    streamInH0.isFirst =  0;
    streamInH0.isLast  =  0; 
    streamInH0.wIndex  = 'X;
    @ (posedge clock);  
    #1;
    @ (posedge clock);  
    #1;
    
    // -- 5x X
    @ (posedge clock);  
    #1;
    @ (posedge clock);  
    #1;
    @ (posedge clock);  
    #1;
    @ (posedge clock);  
    #1;
    @ (posedge clock);  
    #1;
    
    $finish;
end


endmodule 

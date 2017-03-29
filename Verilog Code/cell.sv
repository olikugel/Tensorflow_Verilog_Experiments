

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//       Oli's Cell Model - Yippieh!
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


import cell_package::*;


// Port declarations
module ComputationCell (
input  clock,
input  cellstruct streamIn,
output cellstruct streamOut
);


// These parameters can be changed during instantiation
parameter int           bitwidth                     = 8;
parameter int           inputVectorSize              = 3; 
parameter[bitwidth-1:0] weights[0:inputVectorSize-1] = {0,0,0};
parameter               isLastCellParam              = 0;



// ~~~~~~~~~~~~~~ Cell-internal registers ~~~~~~~~~~~~~
logic[bitwidth-1:0] result_reg; 
logic               rWrittenOut_reg    = 1; 
logic               isLastCell_reg     = isLastCellParam;
logic               forLayerTransf_reg = 0; 
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



// ~~~~~~~~~~~~~ Cell-internal comb wires ~~~~~~~~~~~~~
logic[bitwidth-1:0] result_comb;
logic               rWrittenOut_comb;
logic               forLayerTransf_comb;

logic[bitwidth-1:0] data_comb;
logic               isValid_comb;
logic               isFirst_comb;
logic               isLast_comb;
logic               isResult_comb;
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



// ~~~~~~~~~~~~~~~~ SEQUENTIAL LOGIC ~~~~~~~~~~~~~~~~~~
always_ff @ (posedge clock) begin
    result_reg         <= result_comb;
    rWrittenOut_reg    <= rWrittenOut_comb;
    forLayerTransf_reg <= forLayerTransf_comb;

    streamOut.data     <= data_comb;
    streamOut.isValid  <= isValid_comb; 
    streamOut.isFirst  <= isFirst_comb;
    streamOut.isLast   <= isLast_comb;
    streamOut.isResult <= isResult_comb;
    
    streamOut.wIndex   <= streamIn.wIndex; // for now...
end
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  COMBINATORIAL LOGIC ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
always_comb begin

    //-------- default values ----------
    result_comb         = result_reg;
    rWrittenOut_comb    = rWrittenOut_reg;
    forLayerTransf_comb = forLayerTransf_reg;
    
    data_comb     = 'X;
    isValid_comb  = 0;
    isFirst_comb  = (isLastCell_reg) ? 0 : streamIn.isFirst;
    isLast_comb   = (isLastCell_reg) ? 0 : streamIn.isLast;
    isResult_comb = 0;
    //---------------------------------- 

    unique casez ({streamIn.isValid, streamIn.isResult})
           
        2'b0?: begin  // data is not valid
            if (!rWrittenOut_reg) begin
                isValid_comb     = 1; // for the next cell, this will be valid data
                isResult_comb    = (isLastCell_reg) ? 0 : 1; // it is a result, unless we are the last cell
                data_comb        = result_reg; // write out result from result_reg
                rWrittenOut_comb = 1; // we have now written out the result   
            end
            
            if (isLastCell_reg && !rWrittenOut_reg) begin 
                isLast_comb = 1;  // for the first cell of the next layer, this will be the last data item                        
            end                                           
        end
         
        2'b10: begin  // data is valid, not a result
            if (rWrittenOut_reg && streamIn.isFirst) begin
                result_comb      = 0; // reset result_reg in next cycle
                rWrittenOut_comb = 0; // reset rWrittenOut_reg in next cycle                                           
            end 
             
            if (!isLastCell_reg) begin
                isValid_comb = 1; // for the next cell, this will be valid data
                data_comb    = streamIn.data; // forward data_in which is an input
            end

            if (isLastCell_reg && streamIn.isFirst && !rWrittenOut_reg) begin
                 isValid_comb  = 1;          // for the next cell/layer, this will be valid data
                 isResult_comb = 0;          // for the next layer it's an input, not a result
                 data_comb     = result_reg; // write out result
                 result_comb   = 0;          // reset result_reg in next cycle
                 isLast_comb   = 1;          // for the first cell of the next layer, this will be the last data item
            end
            
            if (isLastCell_reg && streamIn.isLast) begin
                forLayerTransf_comb = 1;
            end
             
            result_comb = result_comb + streamIn.data * weights[streamIn.wIndex];
        end
          
        2'b11: begin  // data is valid, is a result
            isValid_comb  = 1; // for the next cell, this will be valid data
            isResult_comb = (isLastCell_reg) ? 0 : 1; // is a result for next cell, unless we are the last cell
            data_comb     = streamIn.data; // forward data_in which is a result    
            
            if (isLastCell_reg && forLayerTransf_reg) begin
                isFirst_comb        = 1;
                forLayerTransf_comb = 0;
            end                
        end
     
    endcase

end
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


endmodule

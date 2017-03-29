package cell_package;

typedef struct packed
{
logic [7:0] data;
logic       isValid;
logic       isFirst;
logic       isLast;
logic       isResult;
logic [7:0] wIndex;
} cellstruct;

endpackage
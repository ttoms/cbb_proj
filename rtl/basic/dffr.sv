//=============================================================================
// Module      : dffr
// Description : Parameterized control register with async reset and enable.
// Features    : Async active-low reset, explicit enable, constant reset value.
// Parameters  : W - data width; RESET_VALUE - reset value.
// Limitations : Reset release must be synchronized by rst_sync.
//=============================================================================
`default_nettype none

module dffr #(
    parameter   int             W           =   32  ,
    parameter   logic [W-1:0]   RESET_VALUE =   '0
) (
    input   logic           clk     ,
    input   logic           rst_n   ,
    input   logic           en      ,
    input   logic [W -1:0]  d       ,
    output  logic [W -1:0]  q
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= RESET_VALUE;
        end else if (en) begin
            q <= d;
        end
    end

endmodule

`default_nettype wire

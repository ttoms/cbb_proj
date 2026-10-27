//=============================================================================
// Module      : busmux
// Description : One-hot selected data multiplexer with valid flag.
// Features    : Exactly-one-hot select drives data_out; otherwise 0/vld=0.
// Parameters  : N - input count; W - data width.
// Limitations : Multi-hot select is treated as no selection, not OR/priority.
//=============================================================================
`default_nettype none

module busmux #(
    parameter   int N   =   4   ,
    parameter   int W   =   32
) (
    input   logic [N -1:0]          sel         ,
    input   logic [N -1:0] [W -1:0] data        ,
    output  logic [W -1:0]          data_out    ,
    output  logic                   vld
);

    generate
        if (N < 1 || W < 1) begin : g_param_check
            $error("busmux: N and W must be >= 1");
        end
    endgenerate

    always_comb begin
        data_out = '0;
        vld = (sel != '0) && ((sel & (sel - 1'b1)) == '0);
        if (vld) begin
            for (int i = 0; i < N; i++) begin
                if (sel[i]) begin
                    data_out = data[i];
                end
            end
        end
    end

endmodule

`default_nettype wire

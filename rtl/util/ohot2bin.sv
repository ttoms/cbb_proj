//=============================================================================
// Module      : ohot2bin
// Description : One-hot-to-binary encoder with valid flag.
// Features    : Zero input returns bin=0/vld=0; multi-hot selects highest index.
// Parameters  : IN_W - one-hot input width, minimum 1.
// Limitations : Multi-hot is not an error; documented priority behavior applies.
//=============================================================================
`default_nettype none

module ohot2bin #(
    parameter   int IN_W    =   4
) (
    input   logic [IN_W                      -1:0]  ohot    ,
    output  logic [((IN_W>1)?$clog2(IN_W) :1)-1:0]  bin     ,
    output  logic                                   vld
);

    localparam int OUT_W = (IN_W > 1) ? $clog2(IN_W) : 1;

    generate
        if (IN_W < 1) begin : g_param_check
            $error("ohot2bin: IN_W must be >= 1");
        end
    endgenerate

    always_comb begin
        bin = '0;
        vld = |ohot;
        for (int i = 0; i < IN_W; i++) begin
            if (ohot[i]) begin
                bin = OUT_W'(i);
            end
        end
    end

endmodule

`default_nettype wire

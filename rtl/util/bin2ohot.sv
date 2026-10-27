//=============================================================================
// Module      : bin2ohot
// Description : Binary-to-one-hot converter.
// Features    : Output has exactly one asserted bit for every input value.
// Parameters  : W - binary input width, minimum 1.
// Limitations : Output width grows as 2**W; keep W small.
//=============================================================================
`default_nettype none

module bin2ohot #(
    parameter int W = 4
) (
    input  logic [W-1:0]     bin,
    output logic [(1<<W)-1:0] ohot
);

    localparam int OUT_W = 1 << W;

    generate
        if (W < 1) begin : g_param_check
            $error("bin2ohot: W must be >= 1");
        end
    endgenerate

    assign ohot = {{(OUT_W-1){1'b0}}, 1'b1} << bin;

endmodule

`default_nettype wire

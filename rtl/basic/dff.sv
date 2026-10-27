//=============================================================================
// Module      : dff
// Description : Parameterized data-path register with explicit enable.
// Features    : Single clock, enable hold, no reset.
// Parameters  : W - data width.
// Limitations : No reset; output is unknown until first enabled write.
//=============================================================================
`default_nettype none

module dff #(
    parameter int W = 32
) (
    input  logic         clk,
    input  logic         en,
    input  logic [W-1:0] d,
    output logic [W-1:0] q
);

    always_ff @(posedge clk) begin
        if (en) begin
            q <= d;
        end
    end

endmodule

`default_nettype wire

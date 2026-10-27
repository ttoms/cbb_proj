//=============================================================================
// Module      : edge_det
// Description : Single-cycle rising/falling/both edge detector.
// Features    : One input pipeline register, synchronous single-clock operation.
// Parameters  : None.
// Limitations : Input must be synchronous to clk; no CDC synchronizer inside.
//=============================================================================
`default_nettype none

module edge_det (
    input  logic clk,
    input  logic rst_n,
    input  logic sig,
    output logic rise,
    output logic fall,
    output logic both
);

    logic sig_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sig_q <= 1'b0;
        end else begin
            sig_q <= sig;
        end
    end

    assign rise = sig & ~sig_q;
    assign fall = ~sig & sig_q;
    assign both = rise | fall;

endmodule

`default_nettype wire

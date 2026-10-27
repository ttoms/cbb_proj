//=============================================================================
// Module      : icg
// Description : Behavioral model of a latch-based integrated clock gate.
// Features    : Enable captured while clock is low; glitch-free gated clock.
// Parameters  : None.
// Limitations : Latch has no reset; replace with the target library cell.
//=============================================================================
`default_nettype none

module icg (
    input  logic clk,
    input  logic en,
    output logic gclk
);

    logic en_latched;

    always_latch begin // gate: allow-latch
        if (!clk) begin
            en_latched <= en;
        end
    end

    assign gclk = clk & en_latched;

endmodule

`default_nettype wire

//=============================================================================
// Module      : pulse_stretch
// Description : Retriggerable pulse stretcher with configurable width.
// Features    : Output high for at least N cycles per input pulse.
// Parameters  : N - stretched pulse width in cycles, minimum 1.
// Limitations : Input must be synchronous to clk; long input keeps output high.
//=============================================================================
`default_nettype none

module pulse_stretch #(
    parameter   int N   =   4
) (
    input   logic   clk         ,
    input   logic   rst_n       ,
    input   logic   in_pulse    ,
    output  logic   out_pulse
);

    localparam int CNT_W = (N > 1) ? $clog2(N) : 1;
    localparam [CNT_W-1:0] RELOAD = (N > 1) ? (N - 1) : 0;

    logic [CNT_W-1:0] cnt;

    generate
        if (N < 1) begin : g_param_check
            $error("pulse_stretch: N must be >= 1");
        end
    endgenerate

    assign out_pulse = in_pulse | (cnt != '0);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= '0;
        end else if (in_pulse) begin
            cnt <= RELOAD;
        end else if (cnt != '0) begin
            cnt <= cnt - 1'b1;
        end
    end

endmodule

`default_nettype wire

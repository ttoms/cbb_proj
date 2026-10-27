//=============================================================================
// Module      : binmux
// Description : Binary selected data multiplexer with valid flag.
// Features    : Valid select drives data_out; out-of-range returns 0/vld=0.
// Parameters  : N - input count; W - data width.
// Limitations : Non-power-of-two N leaves invalid select codes.
//=============================================================================
`default_nettype none

module binmux #(
    parameter int N = 4,
    parameter int W = 32
) (
    input  logic [((N>1)?$clog2(N):1)-1:0] sel,
    input  logic [N-1:0][W-1:0]            data,
    output logic [W-1:0]                   data_out,
    output logic                           vld
);

    localparam int SEL_W = (N > 1) ? $clog2(N) : 1;

    generate
        if (N < 1 || W < 1) begin : g_param_check
            $error("binmux: N and W must be >= 1");
        end
    endgenerate

    always_comb begin
        data_out = '0;
        vld = (sel < N);
        if (vld) begin
            data_out = data[sel];
        end
    end

endmodule

`default_nettype wire

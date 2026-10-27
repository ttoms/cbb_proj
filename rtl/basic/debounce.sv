//=============================================================================
// Module      : debounce
// Description : N-cycle stable-value debouncer.
// Features    : Output changes only after input is stable for N cycles.
// Parameters  : N - required stable cycles, minimum 1.
// Limitations : Input must be synchronous to clk; no internal synchronizer.
//=============================================================================
`default_nettype none

module debounce #(
    parameter   int N   =   4
) (
    input   logic   clk     ,
    input   logic   rst_n   ,
    input   logic   in      ,
    output  logic   out
);

    localparam int CNT_W = (N > 1) ? $clog2(N) : 1;
    localparam [CNT_W-1:0] HOLD = (N > 1) ? (N - 1) : 0;

    logic [CNT_W-1:0] cnt;
    logic             out_q;

    generate
        if (N < 1) begin : g_param_check
            $error("debounce: N must be >= 1");
        end
    endgenerate

    assign out = out_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt   <= '0;
            out_q <= 1'b0;
        end else if (in != out_q) begin
            if (cnt == HOLD) begin
                cnt   <= '0;
                out_q <= in;
            end else begin
                cnt <= cnt + 1'b1;
            end
        end else begin
            cnt <= '0;
        end
    end

endmodule

`default_nettype wire

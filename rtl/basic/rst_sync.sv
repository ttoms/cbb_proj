//=============================================================================
// Module      : rst_sync
// Description : Async assert, synchronous release reset synchronizer.
// Features    : Configurable synchronizer depth, active-low reset.
// Parameters  : STAGES - synchronizer stages, minimum 2.
// Limitations : Output is only a reset release signal; no reset stretch.
//=============================================================================
`default_nettype none

module rst_sync #(
    parameter   int STAGES  =   2
) (
    input   logic   clk         ,
    input   logic   rst_n       ,
    output  logic   rst_sync_n
);

    localparam int STAGES_MIN = 2;
    localparam int STAGES_USE = (STAGES < STAGES_MIN) ? STAGES_MIN : STAGES;

    logic [STAGES_USE-1:0] sync_q;

    generate
        if (STAGES < STAGES_MIN) begin : g_param_check
            $error("rst_sync: STAGES must be >= 2");
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_q <= '0;
        end else begin
            sync_q[0] <= 1'b1;
            for (int i = 1; i < STAGES_USE; i++) begin
                sync_q[i] <= sync_q[i-1];
            end
        end
    end

    assign rst_sync_n = sync_q[STAGES_USE-1];

endmodule

`default_nettype wire

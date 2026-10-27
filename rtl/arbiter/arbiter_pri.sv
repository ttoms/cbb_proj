//=============================================================================
// Module      : arbiter_pri
// Description : Fixed-priority arbiter, lowest index has highest priority.
// Features    : Combinational grant, one-hot grant, no-request handling.
// Parameters  : N - requester count, minimum 1.
// Limitations : Low-index request can starve higher indexes by design.
//=============================================================================
`default_nettype none

module arbiter_pri #(
    parameter   int N   =   4
) (
    input   logic [N -1:0]  req     ,
    output  logic [N -1:0]  gnt     ,
    output  logic           gnt_vld
);

    generate
        if (N < 1) begin : g_param_check
            $error("arbiter_pri: N must be >= 1");
        end
    endgenerate

    always_comb begin
        gnt = '0;
        for (int i = N - 1; i >= 0; i--) begin
            if (req[i]) begin
                gnt = '0;
                gnt[i] = 1'b1;
            end
        end
        gnt_vld = |req;
    end

endmodule

`default_nettype wire

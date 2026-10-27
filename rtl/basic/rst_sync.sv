`default_nettype none
//==============================================================================
// Module : rst_sync
// Description : 异步复位、同步释放
// Features :
//   - 复位异步拉低立即生效
//   - 释放经 STAGES 级同步，避免复位撤销亚稳态
//   - STAGES 小于 2 时钳位为 2 并在 elaboration 阶段报错
// Parameters :
//   STAGES - 同步级数，默认 2，必须 >= 2
// Limitations :
//   - 复位输入必须来自同一复位源
//   - 仅适用于单时钟域，跨时钟域复位需各自同步
//==============================================================================
module rst_sync #(
    parameter   int STAGES  =   2
) (
    input   logic   clk         ,
    input   logic   rst_async_n ,
    output  logic   rst_n
);

localparam int STAGES_MIN = 2;
localparam int STAGES_USE = (STAGES < STAGES_MIN) ? STAGES_MIN : STAGES;

logic [STAGES_USE-1:0] rst_sync_ff;
logic [STAGES_USE-1:0] nxt_rst_sync_ff;

assign nxt_rst_sync_ff = {rst_sync_ff[STAGES_USE-2:0], 1'b1};

generate
    if (STAGES < STAGES_MIN) begin : g_param_check
        $error("rst_sync: STAGES must be >= 2");
    end
endgenerate

dffr #(
    .W          (STAGES_USE ),
    .RESET_VAL  ('0         )
) U_RST_SYNC_FF (
    .clk    (clk                ),
    .rst_n  (rst_async_n        ),
    .en     (1'b1               ),
    .d      (nxt_rst_sync_ff    ),
    .q      (rst_sync_ff        )
);

assign rst_n = rst_sync_ff[STAGES_USE-1];

`ifdef SVA_ON
`include "rst_sync.sva"
`endif

endmodule

`default_nettype wire

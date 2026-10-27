`default_nettype none
//==============================================================================
// Module : arbmux
// Description : flit 级选通 mux，内部集成 arbiter_wrapper
// Features :
//   - 多路 flit 输入按 ARB_TYPE 仲裁，选中一路输出
//   - 未选中通道 in_rdy=0，无请求时 out_vld=0
//   - 反压期间锁存选通结果，out_pld 保持稳定，不丢数、不重复
//   - 仲裁核 upd 采用输出握手 out_vld & out_rdy，仅在 flit 被消费时推进
//   - weight / qos 透传给 arbiter_wrapper 对应类型
// Parameters :
//   N        - 输入通道数，默认 4，必须 >= 1
//   PLD_W    - flit 负载位宽，默认 32，必须 >= 1
//   ARB_TYPE - 仲裁类型 000~100，默认 001（轮询）
//   WEIGHT_W - 权重位宽，默认 2
//   QOS_W    - QoS 位宽，默认 2
// Limitations :
//   - 反压锁存期间仲裁核状态冻结；解锁后又回到同一通道时仍按该次授权计一次
//   - 不保持 packet 边界，逐 flit 重新仲裁；packet 粒度请用 strmux
//==============================================================================
module arbmux #(
    parameter   int         N           =   4       ,
    parameter   int         PLD_W       =   32      ,
    parameter   logic [2:0] ARB_TYPE    =   3'b001  ,
    parameter   int         WEIGHT_W    =   2       ,
    parameter   int         QOS_W       =   2
) (
    input   logic                   clk     ,
    input   logic                   rst_n   ,
    input   logic [N          -1:0] in_vld  ,
    output  logic [N          -1:0] in_rdy  ,
    input   logic [N*PLD_W    -1:0] in_pld  ,
    input   logic [N*WEIGHT_W -1:0] weight  ,
    input   logic [N*QOS_W    -1:0] qos     ,
    output  logic                   out_vld ,
    input   logic                   out_rdy ,
    output  logic [PLD_W      -1:0] out_pld
);

    logic [N -1:0]  gnt         ;
    logic           gnt_vld     ;
    logic [N -1:0]  hold_oh     ;
    logic [N -1:0]  sel_oh      ;
    logic [N -1:0]  nxt_hold_oh ;
    logic           hold_vld    ;
    logic           hold_set    ;
    logic           hold_clr    ;
    logic           hold_en     ;
    logic           arb_upd     ;

    assign hold_vld = |hold_oh;
    assign sel_oh   = hold_vld ? hold_oh : gnt;

    assign out_vld = hold_vld ? |(in_vld & hold_oh) : gnt_vld;
    assign in_rdy  = {N{out_vld & out_rdy}} & sel_oh;

    assign arb_upd = out_vld & out_rdy;

    assign hold_set = out_vld & ~out_rdy & ~hold_vld;
    assign hold_clr = out_vld & out_rdy & hold_vld;
    assign hold_en  = hold_set | hold_clr;
    assign nxt_hold_oh = hold_clr ? '0 : (hold_set ? gnt : hold_oh);

always_comb begin
    out_pld = '0;
    for (int i = 0; i < N; i++) begin
        if (sel_oh[i]) begin
            out_pld = in_pld[i*PLD_W +: PLD_W];
        end
    end
end

arbiter_wrapper #(
    .N          (N          ),
    .ARB_TYPE   (ARB_TYPE   ),
    .WEIGHT_W   (WEIGHT_W   ),
    .QOS_W      (QOS_W      )
) U_ARB (
    .clk        (clk        ),
    .rst_n      (rst_n      ),
    .upd        (arb_upd    ),
    .req        (in_vld     ),
    .weight     (weight     ),
    .qos        (qos        ),
    .gnt        (gnt        ),
    .gnt_vld    (gnt_vld    )
);

dffr #(
    .W          (N  ),
    .RESET_VAL  ('0 )
) U_HOLD (
    .clk    (clk            ),
    .rst_n  (rst_n          ),
    .en     (hold_en        ),
    .d      (nxt_hold_oh    ),
    .q      (hold_oh        )
);

`ifdef SVA_ON
`include "arbmux.sva"
`endif

endmodule

`default_nettype wire

`default_nettype none
//==============================================================================
// Module : strmux
// Description : stream 级选通 mux，内部集成 arbiter_wrapper，GRAN 选择 flit/packet 粒度
// Features :
//   - 多路 stream 输入按 ARB_TYPE 仲裁，选中一路输出
//   - GRAN_FLIT：逐 flit 重新仲裁
//   - GRAN_PACKET：hop=1 锁定选通，top=1 释放，packet 内（含 vld 间隙）不切换
//   - 反压期间锁存选通结果，out_hop/out_top/out_pld 保持稳定，不丢数、不重复
//   - 仲裁核 upd = 输出握手；GRAN_PACKET 下仅在 packet 头 flit 握手时计一次
//   - weight / qos 透传给 arbiter_wrapper 对应类型
// Parameters :
//   N        - 输入通道数，默认 4，必须 >= 1
//   PLD_W    - flit 负载位宽，默认 32，必须 >= 1
//   ARB_TYPE - 仲裁类型 000~100，默认 001（轮询）
//   WEIGHT_W - 权重位宽，默认 2
//   QOS_W    - QoS 位宽，默认 2
//   GRAN     - 仲裁粒度，0=flit 级，1=packet 级，默认 1
// Limitations :
//   - 要求 packet 成对：hop=1 起始、top=1 结束，同一 packet 的 flit 连续来自同一通道
//   - GRAN_PACKET 锁定期间不响应其他通道；被锁通道违约（中途撤销 vld 或不给 top）会长期占用
//   - 反压或 packet 锁定期间仲裁核状态冻结，每个 packet 只推进一次指针
//   - 不缓存整包，GRAN_PACKET 只锁选通，不锁数据
//==============================================================================
module strmux #(
    parameter   int         N           =   4       ,
    parameter   int         PLD_W       =   32      ,
    parameter   logic [2:0] ARB_TYPE    =   3'b001  ,
    parameter   int         WEIGHT_W    =   2       ,
    parameter   int         QOS_W       =   2       ,
    parameter   logic       GRAN        =   1'b1
) (
    input   logic                   clk     ,
    input   logic                   rst_n   ,
    input   logic [N          -1:0] in_hop  ,
    input   logic [N          -1:0] in_top  ,
    input   logic [N          -1:0] in_vld  ,
    output  logic [N          -1:0] in_rdy  ,
    input   logic [N*PLD_W    -1:0] in_pld  ,
    input   logic [N*WEIGHT_W -1:0] weight  ,
    input   logic [N*QOS_W    -1:0] qos     ,
    output  logic                   out_hop ,
    output  logic                   out_top ,
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
    logic           sel_hop     ;
    logic           sel_top     ;
    logic           set_bp      ;
    logic           set_pkt     ;
    logic           hold_set    ;
    logic           hold_clr    ;
    logic           hold_en     ;
    logic           arb_upd     ;
    logic [N -1:0]  arb_req     ;

    assign hold_vld = |hold_oh;
    assign sel_oh   = hold_vld ? hold_oh : gnt;

    assign out_vld = hold_vld ? |(in_vld & hold_oh) : gnt_vld;
    assign in_rdy  = {N{out_vld & out_rdy}} & sel_oh;

    // 锁存期间只把被锁通道喂给仲裁器：保证 upd 推进的是实际被服务的通道。
    assign arb_req = hold_vld ? hold_oh : in_vld;

    assign sel_hop = |(in_hop & sel_oh);
    assign sel_top = |(in_top & sel_oh);

    // GRAN_FLIT 每 flit 计一次；GRAN_PACKET 只在 packet 头 flit 握手时计一次
    assign arb_upd = out_vld & out_rdy & ((GRAN == 1'b1) ? sel_hop : 1'b1);

    // 反压或 packet 头 flit 触发锁定；GRAN_FLIT 退化为纯反压锁存
    assign set_bp    = out_vld & ~out_rdy & ~hold_vld;
    assign set_pkt   = (GRAN == 1'b1) & out_vld & ~hold_vld & sel_hop & ~sel_top;
    assign hold_set  = set_bp | set_pkt;
    assign hold_clr  = out_vld & out_rdy & hold_vld & ((GRAN == 1'b1) ? sel_top : 1'b1);
    assign hold_en   = hold_set | hold_clr;
    assign nxt_hold_oh = hold_clr ? '0 : (hold_set ? gnt : hold_oh);

always_comb begin
    out_hop = 1'b0;
    out_top = 1'b0;
    out_pld = '0;
    for (int i = 0; i < N; i++) begin
        if (sel_oh[i]) begin
            out_hop = in_hop[i];
            out_top = in_top[i];
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
    .req        (arb_req    ),
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
`include "strmux.sva"
`endif

endmodule

`default_nettype wire

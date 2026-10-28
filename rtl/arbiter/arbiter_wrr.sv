`default_nettype none
//==============================================================================
// Module : arbiter_wrr
// Description : 加权轮询仲裁，credit 计数 + 内部 arbiter_rr，O(log N) 选择
// Features :
//   - 输出独热 gnt，gnt_vld=OR(有效请求)
//   - weight=0 的通道不参与仲裁；全零时无授权
//   - 每轮按权重发放 credit，耗尽后同拍重装，无气泡
//   - 同权重通道由内部 arbiter_rr 轮询，长期公平
// Parameters :
//   N        - 请求路数，默认 4，必须 >= 1
//   WEIGHT_W - 每路权重位宽，默认 2，必须 >= 1
// Limitations :
//   - weight 视为静态配置，运行期变化可能导致 credit 越界
//   - 一轮内同一通道可能连续获得授权，瞬时存在突发
//   - 面积随 N*WEIGHT_W 线性增长
//==============================================================================
module arbiter_wrr #(
    parameter   int N           =   4   ,
    parameter   int WEIGHT_W    =   2
) (
    input   logic                   clk     ,
    input   logic                   rst_n   ,
    input   logic                   upd     ,
    input   logic [N          -1:0] req     ,
    input   logic [N*WEIGHT_W -1:0] weight  ,
    output  logic [N          -1:0] gnt     ,
    output  logic                   gnt_vld
);

    logic [N*WEIGHT_W -1:0] credit      ;
    logic [N*WEIGHT_W -1:0] nxt_credit  ;
    logic [N          -1:0] req_w       ;
    logic [N          -1:0] has_credit  ;
    logic [N          -1:0] elig        ;
    logic                   no_credit   ;
    logic                   credit_en   ;

always_comb begin
    logic [WEIGHT_W -1:0] cred_i;

    req_w      = '0;
    has_credit = '0;
    elig       = '0;
    no_credit  = 1'b0;

    for (int i = 0; i < N; i++) begin
        req_w[i]      = req[i] & (|weight[i*WEIGHT_W +: WEIGHT_W]);
        has_credit[i] = |credit[i*WEIGHT_W +: WEIGHT_W];
    end

    no_credit = (|req_w) & ~|(req & has_credit);

    for (int i = 0; i < N; i++) begin
        cred_i  = no_credit ? weight[i*WEIGHT_W +: WEIGHT_W]
                            : credit[i*WEIGHT_W +: WEIGHT_W];
        elig[i] = req[i] & (|cred_i);
    end
end

// credit 更新由内部 RR 的独热 gnt 直接选择，不做索引比较
always_comb begin
    logic [WEIGHT_W -1:0] base_i;

    for (int i = 0; i < N; i++) begin
        base_i = no_credit ? weight[i*WEIGHT_W +: WEIGHT_W]
                           : credit[i*WEIGHT_W +: WEIGHT_W];
        nxt_credit[i*WEIGHT_W +: WEIGHT_W] = gnt[i] ? (base_i - 1'b1)
                                                    : base_i;
    end
end

assign credit_en = gnt_vld & upd;

arbiter_rr #(
    .N  (N  )
) U_SEL (
    .clk        (clk        ),
    .rst_n      (rst_n      ),
    .upd        (upd        ),
    .req        (elig       ),
    .gnt        (gnt        ),
    .gnt_vld    (gnt_vld    )
);

dffr #(
    .W          (N*WEIGHT_W ),
    .RESET_VAL  ('0         )
) U_CREDIT (
    .clk    (clk        ),
    .rst_n  (rst_n      ),
    .en     (credit_en  ),
    .d      (nxt_credit ),
    .q      (credit     )
);

`ifdef SVA_ON
`include "arbiter_wrr.sva"
`endif

endmodule

`default_nettype wire

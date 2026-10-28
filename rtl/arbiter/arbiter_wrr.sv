`default_nettype none
//==============================================================================
// Module : arbiter_wrr
// Description : 加权轮询仲裁，按 weight 分配每轮授权次数
// Features :
//   - 输出独热 gnt，gnt_vld=OR(有效请求)
//   - weight=0 的通道不参与仲裁；全零时无授权
//   - 每轮按权重发放 credit，耗尽后同拍重装，无气泡
//   - 仅当 upd=1（当前 gnt 被使用）时 credit 与 ptr 更新
//   - 同权重通道从 ptr 起轮询，长期公平
// Parameters :
//   N        - 请求路数，默认 4，必须 >= 1
//   WEIGHT_W - 每路权重位宽，默认 2，必须 >= 1
// Limitations :
//   - weight 视为静态配置，运行期变化可能导致 credit 越界
//   - upd 必须与当前 gnt 的消费拍对齐；upd 恒 1 等价于逐拍推进
//   - 一轮内同一通道可能连续获得授权，瞬时存在突发
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

    localparam int IDX_W = (N > 1) ? $clog2(N) : 1;
    localparam int SUM_W = IDX_W + 1;
    localparam logic [SUM_W-1:0] N_LIMIT = SUM_W'(N);

    logic [N*WEIGHT_W -1:0] credit      ;
    logic [N*WEIGHT_W -1:0] nxt_credit  ;
    logic [N          -1:0] req_w       ;
    logic [N          -1:0] has_credit  ;
    logic [N          -1:0] elig        ;
    logic                   no_credit   ;
    logic [IDX_W      -1:0] ptr         ;
    logic [IDX_W      -1:0] gnt_idx     ;
    logic [IDX_W      -1:0] nxt_ptr     ;
    logic [IDX_W      -1:0] idx         ;
    logic                   credit_en   ;
    logic                   ptr_en      ;

always_comb begin
    logic [WEIGHT_W -1:0] cred_i;
    logic [WEIGHT_W -1:0] base_i;
    logic [SUM_W    -1:0] sum;

    req_w      = '0;
    has_credit = '0;
    elig       = '0;
    gnt        = '0;
    gnt_vld    = 1'b0;
    gnt_idx    = '0;
    idx        = '0;
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

    for (int i = 0; i < N; i++) begin
        // 窄位回绕：ptr + i 在 SUM_W 位内，减一次 N 即可，避免 32 位取模
        sum = {1'b0, ptr} + SUM_W'(i);
        idx = IDX_W'(sum >= N_LIMIT ? (sum - N_LIMIT) : sum);
        if (!gnt_vld && elig[idx]) begin
            gnt[idx] = 1'b1;
            gnt_vld  = 1'b1;
            gnt_idx  = idx;
        end
    end

    for (int i = 0; i < N; i++) begin
        base_i = no_credit ? weight[i*WEIGHT_W +: WEIGHT_W]
                           : credit[i*WEIGHT_W +: WEIGHT_W];
        if (gnt_vld && (gnt_idx == IDX_W'(i))) begin
            nxt_credit[i*WEIGHT_W +: WEIGHT_W] = base_i - 1'b1;
        end else begin
            nxt_credit[i*WEIGHT_W +: WEIGHT_W] = base_i;
        end
    end
end

assign credit_en = gnt_vld & upd;
assign ptr_en    = gnt_vld & upd;
assign nxt_ptr   = (gnt_idx == IDX_W'(N - 1)) ? '0 : (gnt_idx + 1'b1);

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

dffr #(
    .W          (IDX_W  ),
    .RESET_VAL  ('0     )
) U_PTR (
    .clk    (clk        ),
    .rst_n  (rst_n      ),
    .en     (ptr_en     ),
    .d      (nxt_ptr    ),
    .q      (ptr        )
);

`ifdef SVA_ON
`include "arbiter_wrr.sva"
`endif

endmodule

`default_nettype wire

`default_nettype none
//==============================================================================
// Module : arbiter_rr
// Description : 轮询仲裁，从 ptr 指向的索引开始扫描，长期公平
// Features :
//   - 输出独热 gnt，gnt_vld=OR(req)
//   - 无请求时 gnt=0、gnt_vld=0，ptr 保持
//   - 仅当 upd=1（当前 gnt 被使用）时 ptr 才指向被授权索引的下一路
// Parameters :
//   N - 请求路数，默认 4，必须 >= 1
// Limitations :
//   - gnt 为组合输出，授权方需保证请求在握手周期内有效
//   - upd 必须与当前 gnt 的消费拍对齐；upd 恒 1 等价于逐拍推进
//   - 同一索引持续独占时，其余请求最多等待 N-1 次授权
//==============================================================================
module arbiter_rr #(
    parameter   int N   =   4
) (
    input   logic           clk     ,
    input   logic           rst_n   ,
    input   logic           upd     ,
    input   logic [N -1:0]  req     ,
    output  logic [N -1:0]  gnt     ,
    output  logic           gnt_vld
);

    localparam int IDX_W = (N > 1) ? $clog2(N) : 1;

    logic [IDX_W -1:0]  ptr     ;
    logic [IDX_W -1:0]  gnt_idx ;
    logic [IDX_W -1:0]  nxt_ptr ;
    logic [IDX_W -1:0]  idx     ;
    logic               ptr_en  ;

always_comb begin
    gnt     = '0;
    gnt_vld = 1'b0;
    gnt_idx = '0;
    idx     = '0;

    for (int i = 0; i < N; i++) begin
        idx = IDX_W'((int'(ptr) + i) % N);
        if (!gnt_vld && req[idx]) begin
            gnt[idx] = 1'b1;
            gnt_vld  = 1'b1;
            gnt_idx  = idx;
        end
    end
end

assign ptr_en  = gnt_vld & upd;
assign nxt_ptr = (gnt_idx == IDX_W'(N - 1)) ? '0 : (gnt_idx + 1'b1);

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
`include "arbiter_rr.sva"
`endif

endmodule

`default_nettype wire

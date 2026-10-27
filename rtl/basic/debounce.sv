`default_nettype none
//==============================================================================
// Module : debounce
// Description : N 拍稳定值去抖器，输入稳定 N 拍后输出才翻转
// Features :
//   - 输入与输出不同时启动计数
//   - 计数达到 N 拍后更新输出
//   - 输入与输出相同则清零计数
// Parameters :
//   N - 稳定判定拍数，默认 4，合法范围 N >= 1
// Limitations :
//   - 输入必须与 clk 同步
//   - 短于 N 拍的抖动会被拒绝，N 越大响应延迟越大
//==============================================================================
module debounce #(
    parameter   int N   =   4
) (
    input   logic   clk     ,
    input   logic   rst_n   ,
    input   logic   in      ,
    output  logic   out
);

localparam int CNT_W = (N > 1) ? $clog2(N) : 1;

localparam logic [CNT_W-1:0] HOLD = CNT_W'(N - 1);

logic [CNT_W -1:0]  cnt         ;
logic [CNT_W -1:0]  nxt_cnt     ;
logic               out_q       ;
logic               nxt_out_q   ;
logic               in_diff     ;
logic               cnt_en      ;
logic               out_en      ;

assign in_diff = in ^ out_q;
assign out     = out_q;
assign cnt_en  = in_diff | (cnt != '0);
assign out_en  = in_diff & (cnt == HOLD);

always_comb begin
    nxt_cnt   = cnt;
    nxt_out_q = out_q;
    if (in_diff) begin
        if (cnt == HOLD) begin
            nxt_cnt   = '0;
            nxt_out_q = in;
        end else begin
            nxt_cnt = cnt + 1'b1;
        end
    end else if (cnt != '0) begin
        nxt_cnt = '0;
    end
end

dffr #(
    .W          (CNT_W  ),
    .RESET_VAL  ('0     )
) U_CNT (
    .clk    (clk        ),
    .rst_n  (rst_n      ),
    .en     (cnt_en     ),
    .d      (nxt_cnt    ),
    .q      (cnt        )
);

dffr #(
    .W          (1  ),
    .RESET_VAL  ('0 )
) U_OUT_Q (
    .clk    (clk        ),
    .rst_n  (rst_n      ),
    .en     (out_en     ),
    .d      (nxt_out_q  ),
    .q      (out_q      )
);

`ifdef SVA_ON
`include "debounce.sva"
`endif

endmodule

`default_nettype wire

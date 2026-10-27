`default_nettype none
//==============================================================================
// Module : clkgate
// Description : 自动时钟门控，根据 wakeup / idle 自动开启和关闭时钟
// Features :
//   - 复位后默认开启时钟，保证下游可完成初始化
//   - wakeup 优先级最高，单拍即可请求开启
//   - idle 连续保持 IDLE_CYCLES 拍后自动关闭时钟
//   - 内部调用 icg，门控时钟无毛刺
// Parameters :
//   IDLE_CYCLES - 空闲判定拍数，默认 8，必须 >= 1
// Limitations :
//   - wakeup / idle 必须与 clk 同步，且属于未门控时钟域
//   - 开启/关闭在 en 更新后的下一个时钟沿生效，延迟 1 拍
//   - 综合时 icg 需替换为目标工艺库 ICG 单元
//==============================================================================
module clkgate #(
    parameter   int IDLE_CYCLES =   8
) (
    input   logic   clk     ,
    input   logic   rst_n   ,
    input   logic   wakeup  ,
    input   logic   idle    ,
    output  logic   gclk    ,
    output  logic   active
);

    localparam int CNT_W = (IDLE_CYCLES > 1) ? $clog2(IDLE_CYCLES) : 1;
    localparam logic [CNT_W -1:0] IDLE_MAX = CNT_W'(IDLE_CYCLES - 1);

    logic [CNT_W -1:0]  idle_cnt    ;
    logic [CNT_W -1:0]  nxt_cnt     ;
    logic               cnt_clr     ;
    logic               cnt_en      ;
    logic               en          ;
    logic               nxt_en      ;
    logic               en_set      ;
    logic               en_clr      ;
    logic               en_en       ;

assign cnt_clr = wakeup | ~idle;
assign nxt_cnt = cnt_clr ? '0 : (idle_cnt + 1'b1);
assign cnt_en  = cnt_clr | (idle & (idle_cnt != IDLE_MAX));

assign en_set = wakeup | ~idle;
assign en_clr = en & idle & (idle_cnt == IDLE_MAX);
assign nxt_en = en_set;
assign en_en  = en_set | en_clr;

dffr #(
    .W          (CNT_W  ),
    .RESET_VAL  ('0     )
) U_CNT (
    .clk    (clk        ),
    .rst_n  (rst_n      ),
    .en     (cnt_en     ),
    .d      (nxt_cnt    ),
    .q      (idle_cnt   )
);

dffr #(
    .W          (1      ),
    .RESET_VAL  (1'b1   )
) U_EN (
    .clk    (clk    ),
    .rst_n  (rst_n  ),
    .en     (en_en  ),
    .d      (nxt_en ),
    .q      (en     )
);

icg U_ICG (
    .clk    (clk    ),
    .en     (en     ),
    .gclk   (gclk   )
);

assign active = en;

`ifdef SVA_ON
`include "clkgate.sva"
`endif

endmodule

`default_nettype wire

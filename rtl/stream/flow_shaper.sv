`default_nettype none
//==============================================================================
// Module : flow_shaper
// Description : 令牌桶流整形，反压限速，不丢包
// Features :
//   - 1 令牌 = 1 拍数据，长期速率 = TOKENS_PER_TICK / TICK_CYCLES
//   - BURST 控制最大突发拍数，令牌补充饱和到 BURST
//   - 令牌不足只拉低 in_rdy，不丢数、不重复
//   - 数据路径直通，无内部缓冲
// Parameters :
//   W               - 数据位宽，默认 32
//   TICK_CYCLES     - 补充周期，默认 8，必须 >= 1
//   TOKENS_PER_TICK - 每 tick 补充令牌数，默认 1，必须 >= 1
//   BURST           - 令牌桶容量，默认 8，必须 >= 1
//   INIT_TOKENS     - 复位令牌数，默认 0，范围 0..BURST
// Limitations :
//   - 逐拍整形，不保证 packet 内连续
//   - 参数为 elaboration 常量，运行期不可改
//   - 无内部 FIFO，上游必须能承受反压
//==============================================================================
module flow_shaper #(
    parameter   int W               =   32  ,
    parameter   int TICK_CYCLES     =   8   ,
    parameter   int TOKENS_PER_TICK =   1   ,
    parameter   int BURST           =   8   ,
    parameter   int INIT_TOKENS     =   0
) (
    input   logic           clk         ,
    input   logic           rst_n       ,
    input   logic           in_vld      ,
    output  logic           in_rdy      ,
    input   logic [W -1:0]  in_data     ,
    output  logic           out_vld     ,
    input   logic           out_rdy     ,
    output  logic [W -1:0]  out_data
);

localparam int TICK_W  = (TICK_CYCLES > 1) ? $clog2(TICK_CYCLES) : 1;
localparam int TOKEN_W = $clog2(BURST + 1);
localparam int SUM_W   = $clog2(BURST + TOKENS_PER_TICK + 1);

logic [TICK_W  -1:0]    tick_cnt        ;
logic [TICK_W  -1:0]    nxt_tick_cnt    ;
logic                   tick            ;
logic [TOKEN_W -1:0]    tokens          ;
logic [TOKEN_W -1:0]    nxt_tokens      ;
logic [SUM_W   -1:0]    add_tokens      ;
logic [SUM_W   -1:0]    avail_raw       ;
logic [SUM_W   -1:0]    avail           ;
logic                   token_ok        ;
logic                   fire            ;
logic                   tokens_en       ;

assign tick       = (tick_cnt == TICK_W'(TICK_CYCLES - 1));
assign add_tokens = tick ? SUM_W'(TOKENS_PER_TICK) : '0;
assign avail_raw  = SUM_W'(tokens) + add_tokens;
assign avail      = (avail_raw > SUM_W'(BURST)) ? SUM_W'(BURST) : avail_raw;
assign token_ok   = (avail != '0);

assign out_vld  = in_vld && token_ok;
assign out_data = in_data;
assign in_rdy   = token_ok && out_rdy;
assign fire     = in_vld && in_rdy;

assign nxt_tokens   = avail - SUM_W'(fire);
assign tokens_en    = tick || fire;
assign nxt_tick_cnt = tick ? '0 : (tick_cnt + 1'b1);

dffr #(
    .W          (TICK_W ),
    .RESET_VAL  ('0     )
) U_TICK_CNT (
    .clk    (clk            ),
    .rst_n  (rst_n          ),
    .en     (1'b1           ),
    .d      (nxt_tick_cnt   ),
    .q      (tick_cnt       )
);

dffr #(
    .W          (TOKEN_W                ),
    .RESET_VAL  (TOKEN_W'(INIT_TOKENS)  )
) U_TOKENS (
    .clk    (clk        ),
    .rst_n  (rst_n      ),
    .en     (tokens_en  ),
    .d      (nxt_tokens ),
    .q      (tokens     )
);

`ifdef SVA_ON
`include "flow_shaper.sva"
`endif

endmodule

`default_nettype wire

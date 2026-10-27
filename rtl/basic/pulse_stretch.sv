`default_nettype none
//==============================================================================
// Module : pulse_stretch
// Description : 可重触发的脉冲展宽器，输出至少 N 拍高电平
// Features :
//   - in_pulse 当拍立即拉高 out_pulse
//   - 输入撤销后由计数器保持 N-1 拍
//   - 输入持续为高时输出持续为高
// Parameters :
//   N - 展宽拍数，默认 4，合法范围 N >= 1
// Limitations :
//   - 输入必须与 clk 同步
//   - 重触发语义：in_pulse 期间重新装载计数
//==============================================================================
module pulse_stretch #(
    parameter   int N   =   4
) (
    input   logic   clk         ,
    input   logic   rst_n       ,
    input   logic   in_pulse    ,
    output  logic   out_pulse
);

localparam int CNT_W = (N > 1) ? $clog2(N) : 1;

localparam logic [CNT_W-1:0] RELOAD = CNT_W'(N - 1);

logic [CNT_W -1:0]  cnt     ;
logic [CNT_W -1:0]  nxt_cnt ;
logic               cnt_en  ;
logic               active  ;

assign active    = in_pulse | (cnt != '0);
assign out_pulse = active;
assign cnt_en    = active;

always_comb begin
    nxt_cnt = cnt;
    if (in_pulse) begin
        nxt_cnt = RELOAD;
    end else if (cnt != '0) begin
        nxt_cnt = cnt - 1'b1;
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

`ifdef SVA_ON
`include "pulse_stretch.sva"
`endif

endmodule

`default_nettype wire

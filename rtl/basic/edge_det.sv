`default_nettype none
//==============================================================================
// Module : edge_det
// Description : 单周期上升/下降/双边沿检测
// Features :
//   - 输入打一拍后与当前值比较
//   - rise/fall/both 均为组合输出，宽度 1 拍
// Parameters :
//   无
// Limitations :
//   - 输入必须与 clk 同步，内部不含 CDC 同步器
//==============================================================================
module edge_det (
    input  logic clk   ,
    input  logic rst_n ,
    input  logic sig   ,
    output logic rise  ,
    output logic fall  ,
    output logic both
);

localparam logic EN_ALWAYS  = 1'b1;
localparam logic RESET_ZERO = 1'b0;

logic sig_q;

assign rise = sig & ~sig_q;
assign fall = ~sig & sig_q;
assign both = rise | fall;

dffr #(
    .W          (1          ),
    .RESET_VAL  (RESET_ZERO )
) U_SIG_Q (
    .clk    (clk        ),
    .rst_n  (rst_n      ),
    .en     (EN_ALWAYS  ),
    .d      (sig        ),
    .q      (sig_q      )
);

endmodule

`default_nettype wire

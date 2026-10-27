`default_nettype none
//==============================================================================
// Module : parity
// Description : 参数化奇偶校验生成与检查，纯组合
// Features :
//   - parity_bit = ^data ^ MODE，MODE=0 为偶校验，MODE=1 为奇校验
//   - err = ^data ^ data_parity ^ MODE，1 表示 check 失败
//   - 仅需生成时把 data_parity 接 0，忽略 err
// Parameters :
//   W    - 数据位宽，默认 8，必须 >= 1
//   MODE - 校验模式，0=偶校验，1=奇校验，默认 0
// Limitations :
//   - 只覆盖单 bit 错误检测；多 bit 偶数位错误无法发现
//   - 组合逻辑，无流水线寄存
//==============================================================================
module parity #(
    parameter   int     W       =   8       ,
    parameter   logic   MODE    =   1'b0
) (
    input   logic [W -1:0]  data        ,
    input   logic           data_parity ,
    output  logic           parity_bit  ,
    output  logic           err
);

assign parity_bit = ^data ^ MODE;
assign err        = ^data ^ data_parity ^ MODE;

`ifdef SVA_ON
`include "parity.sva"
`endif

endmodule

`default_nettype wire

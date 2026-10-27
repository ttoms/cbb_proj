`default_nettype none
//==============================================================================
// Module : gray_conv
// Description : 二进制与格雷码互转，MODE 选择方向，纯组合
// Features :
//   - MODE=0：bin -> gray，dout = din ^ (din >> 1)
//   - MODE=1：gray -> bin，dout[i] = ^din[W-1:i]（前缀异或，实现按从高到低递推）
//   - 两种方向均满足往返一致：gray2bin(bin2gray(x)) == x
// Parameters :
//   W    - 数据位宽，默认 8，必须 >= 1
//   MODE - 转换方向，0=bin2gray，1=gray2bin，默认 0
// Limitations :
//   - 格雷码只在相邻计数值之间单 bit 变化时有 CDC 意义；本模块不做编码合法性检查
//==============================================================================
module gray_conv #(
    parameter   int     W       =   8       ,
    parameter   logic   MODE    =   1'b0
) (
    input   logic [W -1:0]  din     ,
    output  logic [W -1:0]  dout
);

always_comb begin
    dout = '0;
    if (MODE == 1'b0) begin
        dout = din ^ (din >> 1);
    end else begin
        dout = din;
        for (int i = W - 2; i >= 0; i--) begin
            dout[i] = dout[i + 1] ^ din[i];
        end
    end
end

`ifdef SVA_ON
`include "gray_conv.sva"
`endif

endmodule

`default_nettype wire

`default_nettype none
//==============================================================================
// Module : bin2ohot
// Description : 二进制到独热译码器，纯组合
// Features :
//   - 任意输入值都输出恰好一位有效
//   - 输出位宽为 2**W
// Parameters :
//   W - 二进制输入位宽，默认 4，必须 >= 1
// Limitations :
//   - 输出宽度随 W 指数增长，建议 W <= 6
//==============================================================================
module bin2ohot #(
    parameter   int W   =   4
) (
    input   logic [W      -1:0] bin     ,
    output  logic [(1<<W) -1:0] ohot
);

generate
    if (W < 1) begin : g_param_check
        $error("bin2ohot: W must be >= 1");
    end
endgenerate

always_comb begin
    ohot      = '0;
    ohot[bin] = 1'b1;
end

endmodule

`default_nettype wire

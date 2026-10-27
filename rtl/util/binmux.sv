`default_nettype none
//==============================================================================
// Module : binmux
// Description : 二进制选择的数据 mux，带有效标志，纯组合
// Features :
//   - sel < N 时输出对应数据且 vld=1
//   - sel >= N 时 data_out=0、vld=0
// Parameters :
//   N - 输入路数，默认 4，必须 >= 1
//   W - 数据位宽，默认 32，必须 >= 1
// Limitations :
//   - N 非 2 的幂时存在越界编码，越界即无选择
//==============================================================================
module binmux #(
    parameter   int N   =   4   ,
    parameter   int W   =   32
) (
    input   logic [((N>1)?$clog2(N) :1)-1:0]            sel         ,
    input   logic [N                   -1:0] [W -1:0]   data        ,
    output  logic [W                   -1:0]            data_out    ,
    output  logic                                       vld
);

generate
    if (N < 1 || W < 1) begin : g_param_check
        $error("binmux: N and W must be >= 1");
    end
endgenerate

always_comb begin
    data_out = '0;
    vld      = 1'b0;
    if (sel < N) begin
        data_out = data[sel];
        vld      = 1'b1;
    end
end

endmodule

`default_nettype wire

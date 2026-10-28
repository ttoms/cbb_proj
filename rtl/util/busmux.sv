`default_nettype none
//==============================================================================
// Module : busmux
// Description : 独热选择的数据 mux，带有效标志，纯组合
// Features :
//   - 恰好一位选择有效时输出对应数据且 vld=1
//   - 全零或非一热时 data_out=0、vld=0
// Parameters :
//   N - 输入路数，默认 4，必须 >= 1
//   W - 数据位宽，默认 32，必须 >= 1
// Limitations :
//   - 多热不按 OR 或优先级合并，直接视为无选择
//==============================================================================
module busmux #(
    parameter   int N   =   4   ,
    parameter   int W   =   32
) (
    input   logic [N -1:0]          sel         ,
    input   logic [N -1:0] [W -1:0] data        ,
    output  logic [W -1:0]          data_out    ,
    output  logic                   vld
);

logic sel_ohot;

assign sel_ohot = (sel != '0) && ((sel & (sel - 1'b1)) == '0);

// 独热选择：用掩码 OR（平衡逻辑），不要写成优先级 if 链
always_comb begin
    data_out = '0;
    vld      = sel_ohot;
    for (int i = 0; i < N; i++) begin
        data_out |= data[i] & {W{sel_ohot && sel[i]}};
    end
end

`ifdef SVA_ON
`include "busmux.sva"
`endif

endmodule

`default_nettype wire

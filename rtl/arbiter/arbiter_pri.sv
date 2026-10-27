`default_nettype none
//==============================================================================
// Module : arbiter_pri
// Description : 固定优先级仲裁，索引 0 优先级最高，纯组合
// Features :
//   - 输出独热 gnt，gnt_vld=OR(req)
//   - 无请求时 gnt=0、gnt_vld=0
//   - 多请求时索引最小者获得授权
// Parameters :
//   N - 请求路数，默认 4，必须 >= 1
// Limitations :
//   - 低索引持续请求会饿死高索引，固定优先级语义如此
//==============================================================================
module arbiter_pri #(
    parameter   int N   =   4
) (
    input   logic [N -1:0]  req     ,
    output  logic [N -1:0]  gnt     ,
    output  logic           gnt_vld
);

always_comb begin
    gnt     = '0;
    gnt_vld = 1'b0;
    for (int i = 0; i < N; i++) begin
        if (req[i] && !gnt_vld) begin
            gnt[i]  = 1'b1;
            gnt_vld = 1'b1;
        end
    end
end

`ifdef SVA_ON
`include "arbiter_pri.sva"
`endif

endmodule

`default_nettype wire

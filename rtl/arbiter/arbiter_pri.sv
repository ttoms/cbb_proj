`default_nettype none
//==============================================================================
// Module : arbiter_pri
// Description : 固定优先级树仲裁，索引 0 优先级最高，O(log N) 组合深度
// Features :
//   - 输出独热 gnt，gnt_vld=OR(req)
//   - 无请求时 gnt=0、gnt_vld=0
//   - 多请求时索引最小者获得授权
// Parameters :
//   N - 请求路数，默认 4，必须 >= 1
// Limitations :
//   - 低索引持续请求会饿死高索引，固定优先级语义如此
//   - 面积随 N 线性增长，深度为 log2(N)
//==============================================================================
module arbiter_pri #(
    parameter   int N   =   4
) (
    input   logic [N -1:0]  req     ,
    output  logic [N -1:0]  gnt     ,
    output  logic           gnt_vld
);

pri_tree #(
    .N  (N  )
) U_PRI (
    .req    (req    ),
    .gnt    (gnt    )
);

assign gnt_vld = |req;

`ifdef SVA_ON
`include "arbiter_pri.sva"
`endif

endmodule

`default_nettype wire

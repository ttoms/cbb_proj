`default_nettype none
//==============================================================================
// Module : arbiter_qrr
// Description : QoS + 轮询仲裁，max_tree 选最高 QoS 组，内部 arbiter_rr 轮询
// Features :
//   - 输出独热 gnt，gnt_vld=OR(req)
//   - qos 数值越大优先级越高，只在最高 QoS 请求组内授权
//   - 同 QoS 通道由内部 arbiter_rr 轮询
//   - 仅当 upd=1（当前 gnt 被使用）时内部轮询指针才推进
// Parameters :
//   N     - 请求路数，默认 4，必须 >= 1
//   QOS_W - 每路 QoS 位宽，默认 2，必须 >= 1
// Limitations :
//   - 高 QoS 持续请求时低 QoS 可能饿死，需要严格公平时改用 RR / WRR
//   - qos 视为静态配置，运行期变化会影响已有轮询指针语义
//   - 最高 QoS 选择为 O(log N) 树，面积随 N 线性增长
//==============================================================================
module arbiter_qrr #(
    parameter   int N       =   4   ,
    parameter   int QOS_W   =   2
) (
    input   logic                   clk     ,
    input   logic                   rst_n   ,
    input   logic                   upd     ,
    input   logic [N       -1:0]    req     ,
    input   logic [N*QOS_W -1:0]    qos     ,
    output  logic [N       -1:0]    gnt     ,
    output  logic                   gnt_vld
);

    logic [N     -1:0]  req_hi      ;
    logic [QOS_W -1:0]  max_qos     ;
    logic [N     -1:0]  max_oh_nc   ;
    logic               unused_nc   ;

    max_tree #(
        .N  (N      ),
        .W  (QOS_W  )
    ) U_MAX (
        .vld    (req        ),
        .val    (qos        ),
        .onehot (max_oh_nc  ),
        .max    (max_qos    )
    );

    assign unused_nc = &{1'b0, max_oh_nc};

always_comb begin
    req_hi = '0;
    for (int i = 0; i < N; i++) begin
        if (req[i] && (qos[i*QOS_W +: QOS_W] == max_qos)) begin
            req_hi[i] = 1'b1;
        end
    end
end

arbiter_rr #(
    .N  (N  )
) U_RR (
    .clk        (clk        ),
    .rst_n      (rst_n      ),
    .upd        (upd        ),
    .req        (req_hi     ),
    .gnt        (gnt        ),
    .gnt_vld    (gnt_vld    )
);

`ifdef SVA_ON
`include "arbiter_qrr.sva"
`endif

endmodule

`default_nettype wire

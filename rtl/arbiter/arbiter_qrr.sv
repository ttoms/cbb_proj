`default_nettype none
//==============================================================================
// Module : arbiter_qrr
// Description : QoS + 轮询仲裁，先选最高 QoS 组，组内轮询
// Features :
//   - 输出独热 gnt，gnt_vld=OR(req)
//   - qos 数值越大优先级越高，只在最高 QoS 请求组内授权
//   - 同 QoS 通道复用 arbiter_rr 的指针轮询
// Parameters :
//   N     - 请求路数，默认 4，必须 >= 1
//   QOS_W - 每路 QoS 位宽，默认 2，必须 >= 1
// Limitations :
//   - 高 QoS 持续请求时低 QoS 可能饿死，需要严格公平时改用 RR / WRR
//   - qos 视为静态配置，运行期变化会影响已有轮询指针语义
//==============================================================================
module arbiter_qrr #(
    parameter   int N       =   4   ,
    parameter   int QOS_W   =   2
) (
    input   logic                   clk     ,
    input   logic                   rst_n   ,
    input   logic [N       -1:0]    req     ,
    input   logic [N*QOS_W -1:0]    qos     ,
    output  logic [N       -1:0]    gnt     ,
    output  logic                   gnt_vld
);

    logic [N -1:0]      req_hi      ;
    logic [QOS_W -1:0]  max_qos     ;
    logic [QOS_W -1:0]  qos_i       ;

always_comb begin
    max_qos = '0;
    req_hi  = '0;
    qos_i   = '0;

    for (int i = 0; i < N; i++) begin
        if (req[i]) begin
            qos_i = qos[i*QOS_W +: QOS_W];
            if (qos_i > max_qos) begin
                max_qos = qos_i;
            end
        end
    end

    for (int i = 0; i < N; i++) begin
        qos_i = qos[i*QOS_W +: QOS_W];
        if (req[i] && (qos_i == max_qos)) begin
            req_hi[i] = 1'b1;
        end
    end
end

arbiter_rr #(
    .N  (N  )
) U_RR (
    .clk        (clk        ),
    .rst_n      (rst_n      ),
    .req        (req_hi     ),
    .gnt        (gnt        ),
    .gnt_vld    (gnt_vld    )
);

`ifdef SVA_ON
`include "arbiter_qrr.sva"
`endif

endmodule

`default_nettype wire

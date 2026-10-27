`default_nettype none
//==============================================================================
// Module : arbiter_wrapper
// Description : 仲裁器统一封装，按 ARB_TYPE 选择仲裁核
// Features :
//   - 统一 req/gnt/gnt_vld 接口，weight/qos 仅对应类型使用
//   - generate case 只综合选中的仲裁核
//   - 非法 ARB_TYPE 时输出锁零，仿真期由 SVA 报错
// Parameters :
//   N        - 请求路数，默认 4，必须 >= 1
//   ARB_TYPE - 仲裁类型 000~100，默认 001（轮询）
//   WEIGHT_W - 权重位宽，默认 2，仅 ARB_WRR 使用
//   QOS_W    - QoS 位宽，默认 2，仅 ARB_QRR 使用
// Limitations :
//   - 运行期不可切换 ARB_TYPE
//   - ARB_FIXED 不使用 clk/rst_n/weight/qos，ARB_RR/LRU 不使用 weight/qos
//==============================================================================
module arbiter_wrapper #(
    parameter   int         N           =   4       ,
    parameter   logic [2:0] ARB_TYPE    =   3'b001  ,
    parameter   int         WEIGHT_W    =   2       ,
    parameter   int         QOS_W       =   2
) (
    input   logic                   clk     ,
    input   logic                   rst_n   ,
    input   logic [N          -1:0] req     ,
    input   logic [N*WEIGHT_W -1:0] weight  ,
    input   logic [N*QOS_W    -1:0] qos     ,
    output  logic [N          -1:0] gnt     ,
    output  logic                   gnt_vld
);

    localparam  logic [2:0] ARB_FIXED   =   3'b000  ;
    localparam  logic [2:0] ARB_RR      =   3'b001  ;
    localparam  logic [2:0] ARB_WRR     =   3'b010  ;
    localparam  logic [2:0] ARB_LRU     =   3'b011  ;
    localparam  logic [2:0] ARB_QRR     =   3'b100  ;

generate
    case (ARB_TYPE)
        ARB_FIXED: begin : g_fixed
            logic unused_nc;

            assign unused_nc = &{1'b0, clk, rst_n, weight, qos};

            arbiter_pri #(
                .N  (N  )
            ) U_ARB (
                .req        (req        ),
                .gnt        (gnt        ),
                .gnt_vld    (gnt_vld    )
            );
        end

        ARB_RR: begin : g_rr
            logic unused_nc;

            assign unused_nc = &{1'b0, weight, qos};

            arbiter_rr #(
                .N  (N  )
            ) U_ARB (
                .clk        (clk        ),
                .rst_n      (rst_n      ),
                .req        (req        ),
                .gnt        (gnt        ),
                .gnt_vld    (gnt_vld    )
            );
        end

        ARB_WRR: begin : g_wrr
            logic unused_nc;

            assign unused_nc = &{1'b0, qos};

            arbiter_wrr #(
                .N          (N          ),
                .WEIGHT_W   (WEIGHT_W   )
            ) U_ARB (
                .clk        (clk        ),
                .rst_n      (rst_n      ),
                .req        (req        ),
                .weight     (weight     ),
                .gnt        (gnt        ),
                .gnt_vld    (gnt_vld    )
            );
        end

        ARB_LRU: begin : g_lru
            logic unused_nc;

            assign unused_nc = &{1'b0, weight, qos};

            arbiter_lru #(
                .N  (N  )
            ) U_ARB (
                .clk        (clk        ),
                .rst_n      (rst_n      ),
                .req        (req        ),
                .gnt        (gnt        ),
                .gnt_vld    (gnt_vld    )
            );
        end

        ARB_QRR: begin : g_qrr
            logic unused_nc;

            assign unused_nc = &{1'b0, weight};

            arbiter_qrr #(
                .N      (N      ),
                .QOS_W  (QOS_W  )
            ) U_ARB (
                .clk        (clk        ),
                .rst_n      (rst_n      ),
                .req        (req        ),
                .qos        (qos        ),
                .gnt        (gnt        ),
                .gnt_vld    (gnt_vld    )
            );
        end

        default: begin : g_illegal
            logic unused_nc;

            assign gnt     = '0;
            assign gnt_vld = 1'b0;
            assign unused_nc = &{1'b0, clk, rst_n, req, weight, qos};
        end
    endcase
endgenerate

`ifdef SVA_ON
`include "arbiter_wrapper.sva"
`endif

endmodule

`default_nettype wire

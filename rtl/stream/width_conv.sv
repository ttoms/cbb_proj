`default_nettype none
//==============================================================================
// Module : width_conv
// Description : 整数倍位宽转换（窄↔宽），带 lane keep 与 packet last
// Features :
//   - IN_W < OUT_W 时窄转宽，IN_W > OUT_W 时宽转窄，IN_W == OUT_W 时直通
//   - RATIO = max(IN_W, OUT_W) / min(IN_W, OUT_W)，必须整除
//   - 宽侧 keep 为 lane 粒度连续掩码，last 标记 packet 尾拍
//   - 窄转宽完成拍组合输出，不加 skid；宽转窄单宽字缓冲
// Parameters :
//   IN_W  - 输入位宽，默认 32，必须 >= 1
//   OUT_W - 输出位宽，默认 64，必须 >= 1
// Limitations :
//   - 仅支持整数倍位宽比；非整数倍需外部速率匹配
//   - 宽侧 keep 必须从 lane 0 起连续，不支持中间空洞
//   - 窄转宽完成拍存在 out_rdy -> in_rdy 组合路径
//==============================================================================
module width_conv #(
    parameter   int IN_W    =   32  ,
    parameter   int OUT_W   =   64
) (
    input   logic                                       clk         ,
    input   logic                                       rst_n       ,
    input   logic                                       in_vld      ,
    output  logic                                       in_rdy      ,
    input   logic [IN_W                          -1:0]  in_data     ,
    input   logic [((IN_W>OUT_W)?(IN_W/OUT_W) :1)-1:0]  in_keep     ,
    input   logic                                       in_last     ,
    output  logic                                       out_vld     ,
    input   logic                                       out_rdy     ,
    output  logic [OUT_W                         -1:0]  out_data    ,
    output  logic [((OUT_W>IN_W)?(OUT_W/IN_W) :1)-1:0]  out_keep    ,
    output  logic                                       out_last
);

localparam  int NARROW_W    =   (IN_W < OUT_W) ? IN_W : OUT_W   ;
localparam  int WIDE_W      =   (IN_W > OUT_W) ? IN_W : OUT_W   ;
localparam  int RATIO       =   WIDE_W / NARROW_W               ;
localparam  int LANE_W      =   (RATIO > 1) ? $clog2(RATIO) : 1 ;

generate
    //--------------------------------------------------------------------------
    // 直通
    //--------------------------------------------------------------------------
    if (IN_W == OUT_W) begin : gen_bypass

        assign in_rdy   = out_rdy;
        assign out_vld  = in_vld;
        assign out_data = in_data;
        assign out_keep = 1'b1;
        assign out_last = in_last;

    //--------------------------------------------------------------------------
    // 窄转宽：已存 RATIO-1 个 lane，当前拍 inline 拼入完成拍
    //--------------------------------------------------------------------------
    end else if (IN_W < OUT_W) begin : gen_n2w

        localparam logic [RATIO -1:0] ONE = {{(RATIO -1){1'b0}}, 1'b1};

        logic [RATIO  -2:0] [NARROW_W -1:0] acc_data    ;
        logic [LANE_W -1:0]                 cnt         ;
        logic [LANE_W -1:0]                 nxt_cnt     ;
        logic [RATIO  -1:0]                 cnt_oh      ;
        logic [RATIO  -2:0]                 acc_wr_en   ;
        logic [RATIO  -1:0]                 keep_low    ;
        logic [RATIO  -1:0]                 keep_mask   ;
        logic [WIDE_W -1:0]                 wide_word   ;
        logic                               completing  ;
        logic                               in_fire     ;

        assign completing = (cnt == LANE_W'(RATIO - 1)) || in_last;
        assign in_rdy     = completing ? out_rdy : 1'b1;
        assign in_fire    = in_vld && in_rdy;

        assign out_vld  = in_vld && completing;
        assign out_last = in_last;

        // 写 lane 使能：独热选择当前 cnt，完成拍不写 acc
        assign acc_wr_en = cnt_oh[RATIO -2:0] & {(RATIO -1){in_fire && (!completing)}};

        // 低位连续掩码：cnt 个低位全 1
        assign keep_low  = ONE << cnt;
        assign keep_mask = keep_low | (keep_low - ONE);

        assign out_keep = keep_mask;

        always_comb begin
            wide_word = '0;
            for (int i = 0; i < RATIO - 1; i++) begin
                wide_word[i * NARROW_W +: NARROW_W] = acc_data[i];
            end
            wide_word[int'(cnt) * NARROW_W +: NARROW_W] = in_data;
        end

        assign out_data = wide_word;

        assign nxt_cnt = completing ? '0 : (cnt + 1'b1);

        bin2ohot #(
            .N  (RATIO  )
        ) U_CNT_OH (
            .bin    (cnt    ),
            .ohot   (cnt_oh )
        );

        dffr #(
            .W          (LANE_W ),
            .RESET_VAL  ('0     )
        ) U_CNT (
            .clk    (clk        ),
            .rst_n  (rst_n      ),
            .en     (in_fire    ),
            .d      (nxt_cnt    ),
            .q      (cnt        )
        );

        for (genvar i = 0; i < RATIO - 1; i++) begin : gen_acc
            dff #(
                .W  (NARROW_W   )
            ) U_ACC (
                .clk    (clk            ),
                .en     (acc_wr_en[i]   ),
                .d      (in_data        ),
                .q      (acc_data[i]    )
            );
        end

    //--------------------------------------------------------------------------
    // 宽转窄：1 个宽字缓冲，按 lane 顺序输出
    //--------------------------------------------------------------------------
    end else begin : gen_w2n

        logic [WIDE_W -1:0] buf_data        ;
        logic [RATIO  -1:0] buf_keep        ;
        logic               buf_last        ;
        logic               buf_vld         ;
        logic [LANE_W -1:0] lane_cnt        ;
        logic [LANE_W -1:0] nxt_lane_cnt    ;
        logic [LANE_W -1:0] last_lane       ;
        logic               lane_last       ;
        logic               nxt_buf_vld     ;
        logic               buf_vld_en      ;
        logic               in_fire         ;
        logic               out_fire        ;
        logic               lane_en         ;

        assign out_vld  = buf_vld;
        assign out_keep = 1'b1;
        assign out_fire = buf_vld && out_rdy;
        assign lane_last = (lane_cnt == last_lane);
        assign out_last = buf_last && lane_last;

        assign in_rdy = (!buf_vld) || (out_fire && lane_last);
        assign in_fire = in_vld && in_rdy;

        assign nxt_buf_vld = in_fire ? 1'b1
                           : ((out_fire && lane_last) ? 1'b0 : buf_vld);
        assign buf_vld_en  = in_fire || out_fire;

        assign nxt_lane_cnt = in_fire ? '0
                            : ((out_fire && lane_last) ? '0
                            : (out_fire ? (lane_cnt + 1'b1) : lane_cnt));
        assign lane_en = in_fire || out_fire;

        // lane keep 要求从 lane 0 连续；取最高有效 lane 作为本宽字的最后一个 lane
        always_comb begin
            last_lane = '0;
            for (int i = 0; i < RATIO; i++) begin
                if (buf_keep[i]) begin
                    last_lane = LANE_W'(i);
                end
            end
        end

        assign out_data = buf_data[int'(lane_cnt) * NARROW_W +: NARROW_W];

        dff #(
            .W  (WIDE_W )
        ) U_BUF_DATA (
            .clk    (clk        ),
            .en     (in_fire    ),
            .d      (in_data    ),
            .q      (buf_data   )
        );

        dff #(
            .W  (RATIO  )
        ) U_BUF_KEEP (
            .clk    (clk        ),
            .en     (in_fire    ),
            .d      (in_keep    ),
            .q      (buf_keep   )
        );

        dffr #(
            .W          (1      ),
            .RESET_VAL  (1'b0   )
        ) U_BUF_LAST (
            .clk    (clk        ),
            .rst_n  (rst_n      ),
            .en     (in_fire    ),
            .d      (in_last    ),
            .q      (buf_last   )
        );

        dffr #(
            .W          (1      ),
            .RESET_VAL  (1'b0   )
        ) U_BUF_VLD (
            .clk    (clk            ),
            .rst_n  (rst_n          ),
            .en     (buf_vld_en     ),
            .d      (nxt_buf_vld    ),
            .q      (buf_vld        )
        );

        dffr #(
            .W          (LANE_W ),
            .RESET_VAL  ('0     )
        ) U_LANE_CNT (
            .clk    (clk            ),
            .rst_n  (rst_n          ),
            .en     (lane_en        ),
            .d      (nxt_lane_cnt   ),
            .q      (lane_cnt       )
        );

    end
endgenerate

`ifdef SVA_ON
`include "width_conv.sva"
`endif

endmodule

`default_nettype wire

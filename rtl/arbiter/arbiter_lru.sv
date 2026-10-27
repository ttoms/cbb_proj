`default_nettype none
//==============================================================================
// Module : arbiter_lru
// Description : 最近最少使用仲裁，优先授权等待最久的请求
// Features :
//   - 输出独热 gnt，gnt_vld=OR(req)
//   - 每路维护“距上次授权”的饱和年龄，年龄最大者优先
//   - 年龄相同按索引从小到大，复位后从索引 0 开始
// Parameters :
//   N - 请求路数，默认 4，必须 >= 1
// Limitations :
//   - 年龄计数器饱和后可能出现并列，退化为固定索引优先
//   - 只记录授权历史，不记录请求到达顺序
//==============================================================================
module arbiter_lru #(
    parameter   int N   =   4
) (
    input   logic           clk     ,
    input   logic           rst_n   ,
    input   logic [N -1:0]  req     ,
    output  logic [N -1:0]  gnt     ,
    output  logic           gnt_vld
);

    localparam int IDX_W   = (N > 1) ? $clog2(N) : 1;
    localparam int AGE_W   = (N > 1) ? ($clog2(N) + 1) : 1;
    localparam logic [AGE_W -1:0] AGE_MAX = '1;

    logic [N*AGE_W -1:0]    age         ;
    logic [N*AGE_W -1:0]    nxt_age     ;
    logic [IDX_W   -1:0]    gnt_idx     ;
    logic [IDX_W   -1:0]    sel         ;
    logic                   sel_found   ;
    logic [AGE_W   -1:0]    best_age    ;
    logic                   age_en      ;

always_comb begin
    gnt       = '0;
    gnt_vld   = 1'b0;
    gnt_idx   = '0;
    sel       = '0;
    sel_found = 1'b0;
    best_age  = '0;

    for (int i = 0; i < N; i++) begin
        if (req[i] && (!sel_found || (age[i*AGE_W +: AGE_W] > best_age))) begin
            sel_found = 1'b1;
            best_age  = age[i*AGE_W +: AGE_W];
            sel       = IDX_W'(i);
        end
    end

    if (sel_found) begin
        gnt[sel] = 1'b1;
        gnt_vld  = 1'b1;
        gnt_idx  = sel;
    end

    for (int i = 0; i < N; i++) begin
        if (gnt_vld && (gnt_idx == IDX_W'(i))) begin
            nxt_age[i*AGE_W +: AGE_W] = '0;
        end else if (gnt_vld && (age[i*AGE_W +: AGE_W] == AGE_MAX)) begin
            nxt_age[i*AGE_W +: AGE_W] = AGE_MAX;
        end else if (gnt_vld) begin
            nxt_age[i*AGE_W +: AGE_W] = age[i*AGE_W +: AGE_W] + 1'b1;
        end else begin
            nxt_age[i*AGE_W +: AGE_W] = age[i*AGE_W +: AGE_W];
        end
    end
end

assign age_en = gnt_vld;

dffr #(
    .W          (N*AGE_W    ),
    .RESET_VAL  ('0         )
) U_AGE (
    .clk    (clk        ),
    .rst_n  (rst_n      ),
    .en     (age_en     ),
    .d      (nxt_age    ),
    .q      (age        )
);

`ifdef SVA_ON
`include "arbiter_lru.sva"
`endif

endmodule

`default_nettype wire

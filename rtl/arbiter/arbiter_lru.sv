`default_nettype none
//==============================================================================
// Module : arbiter_lru
// Description : 最近最少使用仲裁，max_tree 选年龄最大者，O(log N) 选择
// Features :
//   - 输出独热 gnt，gnt_vld=OR(req)
//   - 每路维护“距上次授权”的饱和年龄，年龄最大者优先
//   - 仅当 upd=1（当前 gnt 被使用）时年龄向量更新
//   - 年龄相同按索引从小到大，复位后从索引 0 开始
// Parameters :
//   N - 请求路数，默认 4，必须 >= 1
// Limitations :
//   - 年龄计数器饱和后可能出现并列，退化为固定索引优先
//   - 只记录授权历史，不记录请求到达顺序
//   - 面积随 N*AGE_W 线性增长，选择深度 log2(N)
//==============================================================================
module arbiter_lru #(
    parameter   int N   =   4
) (
    input   logic           clk     ,
    input   logic           rst_n   ,
    input   logic           upd     ,
    input   logic [N -1:0]  req     ,
    output  logic [N -1:0]  gnt     ,
    output  logic           gnt_vld
);

    localparam int AGE_W = (N > 1) ? ($clog2(N) + 1) : 1;
    localparam logic [AGE_W-1:0] AGE_MAX = '1;

    logic [N*AGE_W -1:0]    age         ;
    logic [N*AGE_W -1:0]    nxt_age     ;
    logic [AGE_W   -1:0]    max_age_nc  ;
    logic                   unused_nc   ;
    logic                   age_en      ;

    max_tree #(
        .N  (N      ),
        .W  (AGE_W  )
    ) U_MAX (
        .vld    (req        ),
        .val    (age        ),
        .onehot (gnt        ),
        .max    (max_age_nc )
    );

    assign unused_nc = &{1'b0, max_age_nc};
    assign gnt_vld   = |req;
    assign age_en    = gnt_vld & upd;

always_comb begin
    for (int i = 0; i < N; i++) begin
        if (!age_en) begin
            nxt_age[i*AGE_W +: AGE_W] = age[i*AGE_W +: AGE_W];
        end else if (gnt[i]) begin
            nxt_age[i*AGE_W +: AGE_W] = '0;
        end else if (age[i*AGE_W +: AGE_W] == AGE_MAX) begin
            nxt_age[i*AGE_W +: AGE_W] = AGE_MAX;
        end else begin
            nxt_age[i*AGE_W +: AGE_W] = age[i*AGE_W +: AGE_W] + 1'b1;
        end
    end
end

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

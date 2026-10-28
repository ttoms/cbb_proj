`default_nettype none
//==============================================================================
// Module : max_tree
// Description : 树形最大值选择，输出最大值与对应独热通道（同值取最低索引）
// Features :
//   - vld 非零时 onehot 恰好一位有效
//   - 递归二分，深度 ceil(log2(N))
// Parameters :
//   N - 通道数，默认 8，必须 >= 1
//   W - 数值位宽，默认 8，必须 >= 1
// Limitations :
//   - 纯组合；面积 O(N)
//   - 仲裁器内部复用，不单独作为 CBB 发布
//==============================================================================
module max_tree #(
    parameter   int N   =   8   ,
    parameter   int W   =   8
) (
    input   logic [N -1:0]          vld     ,
    input   logic [N -1:0] [W -1:0] val     ,
    output  logic [N -1:0]          onehot  ,
    output  logic [W -1:0]          max
);

generate
    if (N == 1) begin : g_one
        assign onehot = vld;
        assign max    = vld ? val[0] : '0;
    end else begin : g_split
        localparam int NL = N / 2;
        localparam int NR = N - NL;

        logic [NL -1:0] oh_l        ;
        logic [NR -1:0] oh_r        ;
        logic [W  -1:0] max_l       ;
        logic [W  -1:0] max_r       ;
        logic           vld_l       ;
        logic           vld_r       ;
        logic           choose_l    ;

        max_tree #(
            .N  (NL ),
            .W  (W  )
        ) U_L (
            .vld    (vld[NL-1:0]    ),
            .val    (val[NL-1:0]    ),
            .onehot (oh_l           ),
            .max    (max_l          )
        );

        max_tree #(
            .N  (NR ),
            .W  (W  )
        ) U_R (
            .vld    (vld[N-1:NL]    ),
            .val    (val[N-1:NL]    ),
            .onehot (oh_r           ),
            .max    (max_r          )
        );

        assign vld_l    = |vld[NL-1:0];
        assign vld_r    = |vld[N-1:NL];
        assign choose_l = vld_l && (!vld_r || (max_l >= max_r));
        assign onehot   = choose_l ? {{(NR){1'b0}}, oh_l}
                                   : {oh_r, {(NL){1'b0}}};
        assign max      = choose_l ? max_l : max_r;
    end
endgenerate

endmodule

`default_nettype wire

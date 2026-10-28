`default_nettype none
//==============================================================================
// Module : fifo_sync_af
// Description : 同步 FIFO + 水位标志（almost_full / almost_empty）
// Features :
//   - 包装 fifo_sync，不复制存储体与指针逻辑
//   - 占用计数与阈值比较，almost 标志寄存输出
//   - 阈值参数化，标志与 FIFO 状态同拍更新
// Parameters :
//   DATA_W    - 数据位宽，默认 32
//   DEPTH     - 深度，默认 16（2 的幂且 >= 2）
//   AF_THRESH - almost_full 阈值，默认 DEPTH-1，范围 1..DEPTH
//   AE_THRESH - almost_empty 阈值，默认 1，范围 0..DEPTH-1
// Limitations :
//   - 阈值为 elaboration 常量，运行期不可改
//   - almost 标志为寄存输出，比组合水位晚 1 拍
//   - DEPTH 继承 fifo_sync 的 2 的幂约束
//==============================================================================
module fifo_sync_af #(
    parameter   int DATA_W      =   32          ,
    parameter   int DEPTH       =   16          ,
    parameter   int AF_THRESH   =   DEPTH - 1   ,
    parameter   int AE_THRESH   =   1
) (
    input   logic               clk             ,
    input   logic               rst_n           ,
    input   logic               wr_vld          ,
    output  logic               wr_rdy          ,
    input   logic [DATA_W -1:0] wr_data         ,
    output  logic               rd_vld          ,
    input   logic               rd_rdy          ,
    output  logic [DATA_W -1:0] rd_data         ,
    output  logic               empty           ,
    output  logic               full            ,
    output  logic               almost_full     ,
    output  logic               almost_empty
);

localparam int CNT_W = $clog2(DEPTH + 1);

localparam logic [CNT_W -1:0] AF_LIMIT = CNT_W'(AF_THRESH);
localparam logic [CNT_W -1:0] AE_LIMIT = CNT_W'(AE_THRESH);

logic [CNT_W -1:0]  count               ;
logic [CNT_W -1:0]  nxt_count           ;
logic               wr_en               ;
logic               rd_en               ;
logic               count_en            ;
logic               nxt_almost_full     ;
logic               nxt_almost_empty    ;

assign wr_en    = wr_vld && wr_rdy;
assign rd_en    = rd_vld && rd_rdy;
assign count_en = wr_en || rd_en;

// 同拍读写净变化为 0，这里直接用 +1/-1 计算下一拍占用数
assign nxt_count = count
                 + {{(CNT_W -1){1'b0}}, wr_en}
                 - {{(CNT_W -1){1'b0}}, rd_en};

assign nxt_almost_full  = (nxt_count >= AF_LIMIT);
assign nxt_almost_empty = (nxt_count <= AE_LIMIT);

fifo_sync #(
    .DATA_W (DATA_W ),
    .DEPTH  (DEPTH  )
) U_FIFO (
    .clk        (clk        ),
    .rst_n      (rst_n      ),
    .wr_vld     (wr_vld     ),
    .wr_rdy     (wr_rdy     ),
    .wr_data    (wr_data    ),
    .rd_vld     (rd_vld     ),
    .rd_rdy     (rd_rdy     ),
    .rd_data    (rd_data    ),
    .empty      (empty      ),
    .full       (full       )
);

dffr #(
    .W          (CNT_W  ),
    .RESET_VAL  ('0     )
) U_COUNT (
    .clk    (clk        ),
    .rst_n  (rst_n      ),
    .en     (count_en   ),
    .d      (nxt_count  ),
    .q      (count      )
);

dffr #(
    .W          (1      ),
    .RESET_VAL  (1'b0   )
) U_AF (
    .clk    (clk                ),
    .rst_n  (rst_n              ),
    .en     (count_en           ),
    .d      (nxt_almost_full    ),
    .q      (almost_full        )
);

dffr #(
    .W          (1      ),
    .RESET_VAL  (1'b1   )
) U_AE (
    .clk    (clk                ),
    .rst_n  (rst_n              ),
    .en     (count_en           ),
    .d      (nxt_almost_empty   ),
    .q      (almost_empty       )
);

`ifdef SVA_ON
`include "fifo_sync_af.sva"
`endif

endmodule

`default_nettype wire

`default_nettype none
//==============================================================================
// Module : counter
// Description : 参数化上/下计数器，支持同步加载与饱和/回绕
// Features :
//   - load 优先于 en
//   - up=1 递增，up=0 递减
//   - SATURATE=1 时边界保持，SATURATE=0 时回绕
//   - 显式 en 驱动 dffr，便于时钟门控
// Parameters :
//   W        - 计数位宽，默认 8
//   SATURATE - 1 边界保持，0 回绕，默认 1'b0
// Limitations :
//   - 单时钟域
//   - load 与 en 同拍时 load 优先
//==============================================================================
module counter #(
    parameter   int W           =   8       ,
    parameter   bit SATURATE    =   1'b0
) (
    input   logic           clk         ,
    input   logic           rst_n       ,
    input   logic           en          ,
    input   logic           load        ,
    input   logic           up          ,
    input   logic [W -1:0]  load_val    ,
    output  logic [W -1:0]  count
);

localparam logic [W -1:0] CNT_MAX = '1;

logic [W -1:0] nxt_count;
logic          count_en;

assign count_en = load | en;

always_comb begin
    nxt_count = count;
    if (load) begin
        nxt_count = load_val;
    end else if (en) begin
        if (up) begin
            if (count == CNT_MAX) begin
                if (!SATURATE) begin
                    nxt_count = '0;
                end
            end else begin
                nxt_count = count + 1'b1;
            end
        end else begin
            if (count == '0) begin
                if (!SATURATE) begin
                    nxt_count = CNT_MAX;
                end
            end else begin
                nxt_count = count - 1'b1;
            end
        end
    end
end

dffr #(
    .W          (W  ),
    .RESET_VAL  ('0 )
) U_COUNT (
    .clk    (clk        ),
    .rst_n  (rst_n      ),
    .en     (count_en   ),
    .d      (nxt_count  ),
    .q      (count      )
);

endmodule

`default_nettype wire

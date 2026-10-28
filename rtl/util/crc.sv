`default_nettype none
//==============================================================================
// Module : crc
// Description : 参数化 CRC 生成器，每拍处理 DATA_W 位
// Features :
//   - 多项式、初值、输出异或、输入/输出位序可配置
//   - DATA_W=1 即逐位模式；DATA_W>1 为多 bit 并行输入
//   - init 优先于 en；复位值等于 INIT
// Parameters :
//   CRC_W   - CRC 位宽，默认 32，必须 >= 1
//   POLY    - 生成多项式低 CRC_W 位，x^CRC_W 项隐含，默认 CRC-32
//   INIT    - 初值，默认全 1
//   XOROUT  - 输出异或值，默认全 1
//   REFIN   - 输入位序，0=MSB 先，1=LSB 先，默认 0
//   REFOUT  - 输出是否位反转，默认 0
//   DATA_W  - 每拍处理位数，默认 8，必须 >= 1
// Limitations :
//   - 关键路径随 DATA_W 线性增长
//   - REFIN 是整字位序；DATA_W>8 时不等于逐字节反射
//   - 无 byte enable，无自动比较
//==============================================================================
module crc #(
    parameter   int                 CRC_W   =   32              ,
    parameter   logic [CRC_W -1:0]  POLY    =   32'h04C11DB7    ,
    parameter   logic [CRC_W -1:0]  INIT    =   '1              ,
    parameter   logic [CRC_W -1:0]  XOROUT  =   '1              ,
    parameter   bit                 REFIN   =   1'b0            ,
    parameter   bit                 REFOUT  =   1'b0            ,
    parameter   int                 DATA_W  =   8
) (
    input   logic               clk     ,
    input   logic               rst_n   ,
    input   logic               init    ,
    input   logic               en      ,
    input   logic [DATA_W -1:0] data    ,
    output  logic [CRC_W  -1:0] crc_out
);

logic [CRC_W -1:0]  crc_q       ;
logic [CRC_W -1:0]  nxt_crc     ;
logic [CRC_W -1:0]  state_d     ;
logic               state_en    ;

function automatic logic [CRC_W -1:0] crc_step(
    input logic [CRC_W -1:0] st,
    input logic              bit_in
);
    logic fb;

    fb       = st[CRC_W -1] ^ bit_in;
    crc_step = (st << 1) ^ (fb ? POLY : '0);
endfunction

function automatic logic [CRC_W -1:0] bit_rev(
    input logic [CRC_W -1:0] v
);
    for (int i = 0; i < CRC_W; i++) begin
        bit_rev[i] = v[CRC_W -1-i];
    end
endfunction

always_comb begin
    nxt_crc = crc_q;
    for (int i = 0; i < DATA_W; i++) begin
        if (REFIN) begin
            nxt_crc = crc_step(nxt_crc, data[i]);
        end else begin
            nxt_crc = crc_step(nxt_crc, data[DATA_W -1-i]);
        end
    end
end

assign state_en = init || en;
assign state_d  = init ? INIT : nxt_crc;

assign crc_out = (REFOUT ? bit_rev(crc_q) : crc_q) ^ XOROUT;

dffr #(
    .W          (CRC_W  ),
    .RESET_VAL  (INIT   )
) U_CRC (
    .clk    (clk        ),
    .rst_n  (rst_n      ),
    .en     (state_en   ),
    .d      (state_d    ),
    .q      (crc_q      )
);

`ifdef SVA_ON
`include "crc.sva"
`endif

endmodule

`default_nettype wire

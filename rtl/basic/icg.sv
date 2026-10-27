`default_nettype none
//==============================================================================
// Module : icg
// Description : latch 型集成时钟门控单元的行为模型
// Features :
//   - en 在 clk 低电平期间被 latch 捕获
//   - gclk = clk & en_latched，输出无毛刺
// Parameters :
//   无
// Limitations :
//   - 无复位，上电后 en_latched 可能为 X
//   - 综合时必须替换为目标工艺库 ICG 单元
//==============================================================================
module icg (
    input  logic clk  ,
    input  logic en   ,
    output logic gclk
);

logic en_latched;

always_latch begin // gate: allow-latch
    if (!clk) begin
        en_latched <= en;
    end
end

assign gclk = clk & en_latched;

endmodule

`default_nettype wire

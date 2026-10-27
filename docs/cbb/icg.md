# icg CBB 文档（简单件）
## 1. 基本信息
`CBB-BASIC-010` · `icg` · `basic` · 已发布
## 2. 功能与范围
- **功能**：latch 型集成时钟门控单元的行为模型，输出无毛刺门控时钟。
- **不包含**：不做自动 idle 检测、不做 enable 同步、不做 test bypass。
- **典型场景**：`clkgate` 内部单元、低功耗时钟门控、门级替换参考。
## 3. 端口表
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 原始时钟 |
| `en` | input | 1 | - | 门控使能 |
| `gclk` | output | 1 | - | 门控后时钟 |

无 valid-ready 接口。
## 4. 参数表
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| 无 | - | - | - | 固定单元模型 |

## 5. 使用说明
- **时钟/复位/初始化**：无复位；`en` 在 `clk=0` 期间被 latch 捕获。
- **延迟/吞吐**：`gclk = clk & en_latched`；`en` 在时钟高电平期间变化不影响当前高电平。
- **反压/握手**：无。

```systemverilog
icg U_ICG (
    .clk  (clk),
    .en   (clk_en),
    .gclk (gclk)
);
```
## 6. 限制
- 这是行为模型，综合时必须替换为目标工艺库的 ICG 单元。
- 无复位，上电后 `en_latched` 可能为 X，仿真需先给低电平使能。
- 源码中 `always_latch` 行必须保留 `// gate: allow-latch` 豁免注释。
## 7. 验证状态
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS（latch 行级豁免） |
| 定向 TB | `tb/basic/icg_tb.sv` PASS |
| SVA | 不需要（简单单元） |
| 仿真器 | iverilog 12.0 |
| 未覆盖项 | 未做门级/工艺库 ICG 对比 |

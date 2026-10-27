# parity CBB 文档（简单件）

## 1. 基本信息
`CBB-UTIL-004` · `parity` · `util` · 已发布

## 2. 功能与范围
- **功能**：参数化奇偶校验生成与检查。输出校验位 `parity_bit`，并给出与输入校验位比对后的错误标志 `err`。
- **不包含**：不做多 bit 纠错、不做 CRC、不做跨拍累积、不寄存结果。
- **典型场景**：总线/存储单 bit 奇偶保护、串行链路校验位附加、简单错误检测。

## 3. 端口表
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `data` | input | `W` | - | 被校验数据 |
| `data_parity` | input | 1 | - | 已有的校验位；仅生成时接 0 |
| `parity_bit` | output | 1 | - | 生成的校验位 |
| `err` | output | 1 | - | 校验失败标志，1 表示不匹配 |

无时钟、无复位、无 valid-ready。

## 4. 参数表
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `W` | `int` | `8` | `W >= 1` | 数据位宽 |
| `MODE` | `logic` | `1'b0` | `0` / `1` | `0`=偶校验，`1`=奇校验 |

## 5. 使用说明
- **时钟/复位/初始化**：纯组合逻辑，无时钟和复位。
- **延迟/吞吐**：组合延迟（`W` 输入异或树）；每拍可处理一个码字。
- **反压/握手**：无。

```systemverilog
parity #(
    .W    (8),
    .MODE (1'b0)
) U_PARITY (
    .data        (data),
    .data_parity (rx_parity),
    .parity_bit  (tx_parity),
    .err         (parity_err)
);
```

公式：
- 偶校验（`MODE=0`）：`parity_bit = ^data`
- 奇校验（`MODE=1`）：`parity_bit = ~^data`
- 检查：`err = ^data ^ data_parity ^ MODE`

## 6. 限制
- 只能检测奇数位错误；偶数位错误（含 2 bit 翻转）无法发现。
- 仅需生成时可把 `data_parity` 接 0 并忽略 `err`。
- 组合实现，深位宽形成较大异或树，必要时在外部插入流水线。

## 7. 验证状态
| 项 | 结果 |
|---|---|
| `quality_gate.py` | 0 error（PASSED）；对齐后复跑 |
| 定向 TB | `tb/util/parity_tb.sv` PASS（W=8 偶/奇：全零、单个/多个 1、匹配与错误注入；W=1 边界） |
| SVA | `parity.sva` 参数检查；需 Verilator 5.x（`--assert -DSVA_ON`） |
| 仿真器 | iverilog 12.0 通过；Verilator 5.020 `--lint-only -Wall` 无告警 |
| 未覆盖项 | 未覆盖 `W > 8` 的时序/面积；未做 2 bit 以上错误注入；未做综合评估 |

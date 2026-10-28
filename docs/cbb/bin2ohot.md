# bin2ohot CBB 文档（简单件）

## 1. 基本信息
`CBB-UTIL-005` · `bin2ohot` · `util` · 已发布

## 2. 功能与范围
- **功能**：把二进制输入译码为 `N` 路独热输出；`bin < N` 时恰好一位有效，`bin >= N` 时输出全 0。
- **不包含**：不做优先级编码、不做多热输入处理、不做流水线寄存。
- **典型场景**：独热译码、one-hot mux 选择、FIFO 指针 → 独热写使能。

## 3. 端口表
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `bin` | input | `$clog2(N)`（N=1 时为 1） | - | 二进制输入 |
| `ohot` | output | `N` | - | 独热输出；越界编码时全 0 |

无时钟、无复位、无 valid-ready。

## 4. 参数表
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `N` | `int` | `16` | `N >= 1` | 独热输出路数；**不要求 2 的幂** |

## 5. 使用说明
- **时钟/复位/初始化**：纯组合逻辑，无时钟和复位。
- **延迟/吞吐**：组合延迟；每拍可转换一个值。
- **反压/握手**：无。
- **越界**：`bin >= N` 时 `ohot` 全 0，调用方需要时用 `|ohot` 判断有效。

```systemverilog
bin2ohot #(
    .N (16)
) U_DEC (
    .bin  (sel_bin),   // 4 bit
    .ohot (sel_ohot)   // 16 bit
);

bin2ohot #(
    .N (5)
) U_DEC5 (
    .bin  (sel_bin5),  // 3 bit；5~7 越界输出全 0
    .ohot (sel_ohot5)  // 5 bit
);
```

## 6. 限制
- 纯组合译码器，面积随 `N` 线性增长。
- 越界编码输出全 0；不做饱和/回绕。
- `bin` 含 X 时仿真输出不可信。

## 7. 验证状态
| 项 | 结果 |
|---|---|
| `quality_gate.py` | 0 error（PASSED） |
| 定向 TB | `tb/util/bin2ohot_tb.sv` PASS（`N=5/8/16`：in-range 逐值独热，越界全 0） |
| SVA | `bin2ohot.sva` 参数检查 + 组合独热断言；需 Verilator 5.x（`--assert -DSVA_ON`） |
| 仿真器 | iverilog 11/12 均通过；SVA 需 Verilator 5.x |
| 未覆盖项 | 未做综合面积与时序评估；`bin` 含 X/Z 的行为未建模 |

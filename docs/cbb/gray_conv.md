# gray_conv CBB 文档（简单件）

## 1. 基本信息
`CBB-UTIL-003` · `gray_conv` · `util` · 已发布

## 2. 功能与范围
- **功能**：二进制码与格雷码互转，`MODE` 选择方向；纯组合。
- **不包含**：不做格雷码合法性检查、不做跨时钟域同步（CDC 由 `cdc_gray` 负责）、不寄存结果。
- **典型场景**：异步 FIFO 指针编码（配合 `cdc_gray` / `fifo_async`）、低翻转计数总线、相邻值单 bit 变化需求。

## 3. 端口表
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `din` | input | `W` | - | 输入码字 |
| `dout` | output | `W` | - | 转换结果 |

无时钟、无复位、无 valid-ready。

## 4. 参数表
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `W` | `int` | `8` | `W >= 1` | 数据位宽 |
| `MODE` | `logic` | `1'b0` | `0` / `1` | `0`=bin→gray，`1`=gray→bin |

## 5. 使用说明
- **时钟/复位/初始化**：纯组合逻辑，无时钟和复位。
- **延迟/吞吐**：组合延迟；`MODE=1` 为从高位到低位的异或链，延迟随 `W` 线性增长。
- **反压/握手**：无。

```systemverilog
gray_conv #(
    .W    (8),
    .MODE (1'b0)
) U_B2G (
    .din  (bin_cnt),
    .dout (gray_cnt)
);
```

转换公式：
- bin→gray：`gray = bin ^ (bin >> 1)`
- gray→bin：`bin[i] = ^gray[W-1:i]`

## 6. 限制
- 格雷码“相邻值仅一位变化”的性质只对二进制顺序计数成立；任意跳变不保证单 bit 翻转。
- 不做输入合法性检查；`MODE=1` 对任意 `W` 位输入都能给出确定结果。
- 组合实现，深位宽时 `MODE=1` 的异或链会形成较长组合路径。

## 7. 验证状态
| 项 | 结果 |
|---|---|
| `quality_gate.py` | 0 error（PASSED）；对齐后复跑 |
| 定向 TB | `tb/util/gray_conv_tb.sv` PASS（W=4 两方向全 16 值遍历 + 往返一致；W=1 边界） |
| SVA | `gray_conv.sva` 参数检查；需 Verilator 5.x（`--assert -DSVA_ON`） |
| 仿真器 | iverilog 12.0 通过；Verilator 5.020 `--lint-only -Wall` 无告警 |
| 未覆盖项 | 未覆盖 `W > 8` 的时序/面积；未做综合评估 |

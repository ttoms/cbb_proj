# edge_det CBB 文档（简单件）

## 1. 基本信息
`CBB-BASIC-006` · `edge_det` · `basic` · 已发布

## 2. 功能与范围
- **功能**：检测输入信号的上升沿、下降沿和双边沿，输出单周期脉冲。
- **不包含**：不做输入同步、不做去抖、不做跨时钟域处理。
- **典型场景**：按键/GPIO 边沿事件、使能跳变检测、中断触发。

## 3. 端口表
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟 |
| `rst_n` | input | 1 | `clk` | 异步复位、同步释放，低有效 |
| `sig` | input | 1 | `clk` | 待检测信号 |
| `rise` | output | 1 | `clk` | 上升沿单周期脉冲 |
| `fall` | output | 1 | `clk` | 下降沿单周期脉冲 |
| `both` | output | 1 | `clk` | 双边沿单周期脉冲 |

无 valid-ready 接口。

## 4. 参数表
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| 无 | - | - | - | 固定结构 |

## 5. 使用说明
- **时钟/复位/初始化**：`sig_q` 由 `dffr` 实现，异步复位值为 0；复位释放由 `rst_sync` 保证。
- **延迟/吞吐**：`sig` 到 `rise`/`fall`/`both` 为 1 拍组合输出；每拍最多一个边沿脉冲。
- **反压/握手**：无 valid-ready 接口；输出为单周期脉冲，不可保持。

```systemverilog
edge_det U_EDGE (
    .clk   (clk),
    .rst_n (rst_sync_n),
    .sig   (event_sig),
    .rise  (event_rise),
    .fall  (event_fall),
    .both  (event_both)
);
```

## 6. 限制
- `sig` 必须与 `clk` 同步；异步输入需先经 2FF 同步器。
- 复位期间 `sig_q` 保持 0；复位释放时若 `sig=1`，首拍会产生一次 `rise`，属正常边沿而非假脉冲。
- 输入抖动会产生多个脉冲，需先配合 `debounce` 使用。

## 7. 验证状态
| 项 | 结果 |
|---|---|
| `quality_gate.py` | 0 error（PASSED，对齐后复跑） |
| 定向 TB | `tb/basic/edge_det_tb.sv` PASS（上升/下降/双边沿、复位后无假脉冲） |
| SVA | 不需要（单级寄存器 + 组合输出） |
| 仿真器 | iverilog 11/12 均通过 |
| 未覆盖项 | 未覆盖异步输入、抖动输入与跨时钟域场景 |

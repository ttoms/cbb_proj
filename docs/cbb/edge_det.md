# edge_det CBB 文档（简单件）
## 1. 基本信息
`CBB-BASIC-006` · `edge_det` · `basic` · 已发布
## 2. 功能与范围
- **功能**：检测输入信号的上升沿、下降沿和双边沿，输出单周期脉冲。
- **不包含**：不做输入同步、不做去抖、不做跨时钟域处理。
- **典型场景**：按键边沿、使能跳变、事件触发。
## 3. 端口表
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟 |
| `rst_n` | input | 1 | `clk` | 异步复位、同步释放，低有效 |
| `sig` | input | 1 | `clk` | 待检测信号 |
| `rise` | output | 1 | `clk` | 上升沿单周期脉冲 |
| `fall` | output | 1 | `clk` | 下降沿单周期脉冲 |
| `both` | output | 1 | `clk` | 双边沿脉冲 |

无 valid-ready 接口。
## 4. 参数表
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| 无 | - | - | - | 固定结构 |

## 5. 使用说明
- **时钟/复位/初始化**：复位后内部寄存为 0；复位后若 `sig=1`，首拍会产生一次 `rise`。
- **延迟/吞吐**：输入到脉冲输出 1 拍；每拍最多一个脉冲。
- **反压/握手**：无。

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
- `sig` 必须与 `clk` 同步；异步输入需先加 2FF 同步器。
- 输入抖动会产生多个脉冲，需配合 `debounce` 使用。
## 7. 验证状态
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS |
| 定向 TB | `tb/basic/edge_det_tb.sv` PASS |
| SVA | 不需要（简单单元） |
| 仿真器 | iverilog 12.0 |
| 未覆盖项 | 未覆盖异步输入和抖动场景 |

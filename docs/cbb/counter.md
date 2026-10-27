# counter CBB 文档（简单件）
## 1. 基本信息
`CBB-BASIC-005` · `counter` · `basic` · 已发布
## 2. 功能与范围
- **功能**：参数化上/下计数，支持同步加载、使能、饱和或回绕。
- **不包含**：不做格雷码输出、不做多通道计数、不做中断生成。
- **典型场景**：定时器分频、PWM 周期、超时计数、状态机步进。
## 3. 端口表
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟 |
| `rst_n` | input | 1 | `clk` | 异步复位、同步释放，低有效 |
| `en` | input | 1 | `clk` | 计数使能 |
| `load` | input | 1 | `clk` | 同步加载，优先级高于 `en` |
| `up` | input | 1 | `clk` | 1 向上计数，0 向下计数 |
| `load_val` | input | `W` | `clk` | 加载值 |
| `count` | output | `W` | `clk` | 当前计数值 |

无 valid-ready 接口。
## 4. 参数表
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `W` | `int` | `8` | `W >= 1` | 计数位宽 |
| `SATURATE` | `bit` | `0` | `0/1` | 1 边界保持，0 回绕 |
## 5. 使用说明
- **时钟/复位/初始化**：异步复位后 `count=0`；复位释放由 `rst_sync` 保证。
- **延迟/吞吐**：加载/计数均为 1 拍；每拍最多更新一次。
- **反压/握手**：无；`en=0` 时保持。

```systemverilog
counter #(
    .W        (8),
    .SATURATE (1'b1)
) U_CNT (
    .clk      (clk),
    .rst_n    (rst_sync_n),
    .en       (cnt_en),
    .load     (cnt_load),
    .up       (cnt_up),
    .load_val (cnt_load_val),
    .count    (cnt_value)
);
```
## 6. 限制
- `load` 优先于 `en`，同一拍加载时不计数。
- `SATURATE=1` 时在边界保持，不会产生回绕事件。
## 7. 验证状态
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS |
| 定向 TB | `tb/basic/counter_tb.sv` PASS（回绕/饱和双实例） |
| SVA | 不需要（简单计数逻辑） |
| 仿真器 | iverilog 12.0 |
| 未覆盖项 | 未做随机激励和大位宽覆盖 |

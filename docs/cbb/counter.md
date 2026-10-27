# counter CBB 文档（简单件）

## 1. 基本信息
`CBB-BASIC-005` · `counter` · `basic` · 已发布

## 2. 功能与范围
- **功能**：参数化上/下计数器，支持同步加载、计数使能，以及边界饱和或回绕。
- **不包含**：不产生中断/溢出标志，不做格雷码输出，不做多通道计数。
- **典型场景**：定时器分频、PWM 周期计数、超时计数、状态机步进。

## 3. 端口表
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟 |
| `rst_n` | input | 1 | `clk` | 异步复位、同步释放，低有效 |
| `en` | input | 1 | `clk` | 计数使能；`en=0` 时保持 |
| `load` | input | 1 | `clk` | 同步加载，优先级高于 `en` |
| `up` | input | 1 | `clk` | 1 向上计数，0 向下计数 |
| `load_val` | input | `W` | `clk` | 加载值 |
| `count` | output | `W` | `clk` | 当前计数值 |

无 valid-ready 接口。

## 4. 参数表
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `W` | `int` | `8` | `W >= 1` | 计数位宽 |
| `SATURATE` | `bit` | `1'b0` | `0/1` | 1 边界保持，0 回绕 |

## 5. 使用说明
- **时钟/复位/初始化**：`count` 由 `dffr` 实现，异步复位值为 0；复位释放由 `rst_sync` 保证。
- **延迟/吞吐**：加载和加/减计数均在一个时钟沿完成，每拍最多更新一次。
- **反压/握手**：无 valid-ready 接口；`en=0` 时计数保持。

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
- `load` 优先于 `en`，同一拍既加载又使能时只执行加载。
- `SATURATE=1` 时在 `0`/`2^W-1` 边界保持，不产生回绕；`SATURATE=0` 时回绕。
- 单时钟域；`load`、`en`、`up`、`load_val` 必须与 `clk` 同步。
- 不输出到达边界或回绕事件，需要时由外部对 `count` 译码。

## 7. 验证状态
| 项 | 结果 |
|---|---|
| `quality_gate.py` | 0 error（PASSED，对齐后复跑） |
| 定向 TB | `tb/basic/counter_tb.sv` PASS（`W=8`，`SATURATE=0/1` 双实例） |
| SVA | 不需要（简单计数逻辑） |
| 仿真器 | iverilog 11/12 均通过 |
| 未覆盖项 | 未做随机激励、`W>8` 大位宽和 `W=1` 边界仿真 |

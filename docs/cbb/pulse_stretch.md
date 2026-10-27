# pulse_stretch CBB 文档（简单件）
## 1. 基本信息
`CBB-BASIC-007` · `pulse_stretch` · `basic` · 已发布
## 2. 功能与范围
- **功能**：将输入脉冲展宽到至少 `N` 个时钟周期，支持重触发。
- **不包含**：不做输入同步、不做去抖、不做精确脉宽测量。
- **典型场景**：短脉冲驱动、事件保持、慢速外设采样。
## 3. 端口表
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟 |
| `rst_n` | input | 1 | `clk` | 异步复位、同步释放，低有效 |
| `in_pulse` | input | 1 | `clk` | 输入脉冲 |
| `out_pulse` | output | 1 | `clk` | 展宽后的脉冲 |

无 valid-ready 接口。
## 4. 参数表
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `N` | `int` | `4` | `N >= 1` | 单周期输入对应的输出高电平周期数 |
## 5. 使用说明
- **时钟/复位/初始化**：异步复位后输出为低；复位释放由 `rst_sync` 保证。
- **延迟/吞吐**：输入当拍输出立即为高；单周期输入产生 `N` 拍高电平。
- **反压/握手**：无。

```systemverilog
pulse_stretch #(
    .N (4)
) U_STRETCH (
    .clk       (clk),
    .rst_n     (rst_sync_n),
    .in_pulse  (short_pulse),
    .out_pulse (wide_pulse)
);
```
## 6. 限制
- `in_pulse` 必须与 `clk` 同步。
- 输入持续为高时输出持续为高，并在输入撤销后再保持 `N-1` 拍，属重触发语义。
## 7. 验证状态
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS |
| 定向 TB | `tb/basic/pulse_stretch_tb.sv` PASS（N=2 / N=1） |
| SVA | 不需要（简单计数逻辑） |
| 仿真器 | iverilog 12.0 |
| 未覆盖项 | 未做随机脉宽和背靠背极限覆盖 |

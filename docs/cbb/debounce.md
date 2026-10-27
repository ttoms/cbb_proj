# debounce CBB 文档（简单件）

## 1. 基本信息
`CBB-BASIC-008` · `debounce` · `basic` · 已发布

## 2. 功能与范围
- **功能**：输入连续稳定 `N` 拍后，输出才跟随输入变化。
- **不包含**：不做输入同步、不做边沿检测、不做可配置计数方向。
- **典型场景**：按键、机械开关、慢速 GPIO 采样。

## 3. 端口表
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟 |
| `rst_n` | input | 1 | `clk` | 异步复位、同步释放，低有效 |
| `in` | input | 1 | `clk` | 原始输入 |
| `out` | output | 1 | `clk` | 去抖后的输出 |

无 valid-ready 接口。

## 4. 参数表
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `N` | `int` | `4` | `N >= 1` | 稳定判定拍数；`N<1` 由 `debounce.sva` 的参数检查报错 |

## 5. 使用说明
- **时钟/复位/初始化**：`cnt` 与 `out_q` 分别由 `dffr` 实现，异步复位值均为 0；复位释放由 `rst_sync` 保证。
- **延迟/吞吐**：输入翻转后需连续 `N` 拍与 `out_q` 不同，输出才更新；`N=1` 时下一拍即跟随。
- **反压/握手**：无 valid-ready 接口；输出为寄存器输出。

```systemverilog
debounce #(
    .N (4)
) U_DEB (
    .clk   (clk),
    .rst_n (rst_sync_n),
    .in    (raw_key),
    .out   (clean_key)
);
```

## 6. 限制
- `in` 必须与 `clk` 同步；异步按键需先经 2FF 同步器。
- 输入与 `out_q` 不同时计数；相同且 `cnt!=0` 时计数清零，短于 `N` 拍的抖动被拒绝。
- `N` 越大抗抖能力越强、响应延迟越大。

## 7. 验证状态
| 项 | 结果 |
|---|---|
| `quality_gate.py` | 0 error（PASSED，对齐后复跑） |
| 定向 TB | `tb/basic/debounce_tb.sv` PASS（`N=3`，稳定 1/2 拍不翻转、稳定 3 拍翻转、1/2 拍抖动被拒绝） |
| SVA | `debounce.sva` 参数检查 PASS（verilator 5.020，`--assert -DSVA_ON`） |
| 仿真器 | iverilog 12.0 + verilator 5.020 |
| 未覆盖项 | 未覆盖 `N=1`/`N=2` 参数边界、真实机械抖动模型和异步输入 |

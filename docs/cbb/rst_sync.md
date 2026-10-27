# rst_sync CBB 文档（简单件）

## 1. 基本信息
`CBB-BASIC-003` · `rst_sync` · `basic` · 已发布

## 2. 功能与范围
- **功能**：异步复位拉低立即生效、释放经 `STAGES` 级触发器同步的复位同步器。
- **不包含**：不做复位展宽、不做复位域隔离、不检测复位毛刺、不跨时钟域分发。
- **典型场景**：单时钟域内所有 `dffr` 的复位释放；SoC 各时钟域各自例化一份。

## 3. 端口表
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟 |
| `rst_async_n` | input | 1 | 异步 | 原始异步复位，低有效 |
| `rst_n` | output | 1 | `clk` | 同步释放后的复位，低有效 |

无 valid-ready 接口。

## 4. 参数表
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `STAGES` | `int` | `2` | `STAGES >= 2` | 同步级数；小于 2 时钳位为 2，建议不超过 8；参数检查在 `rst_sync.sva` |

参数约束：`STAGES < 2` 时用 localparam 钳位为 2，保证不会产生非法位选；RTL 内不含 `$error`/`$fatal`，参数检查由 `rst_sync.sva` 的 `initial $fatal` 完成（`SVA_ON`），给出 `2 <= STAGES <= 8` 的建议范围。

## 5. 使用说明
- **时钟/复位/初始化**：`rst_async_n` 异步拉低后 `rst_n` 立即为低；释放后经 `STAGES` 个 `clk` 上升沿 `rst_n` 拉高。
- **延迟/吞吐**：复位释放延迟为 `STAGES` 拍；不影响数据吞吐。
- **反压/握手**：无。

```systemverilog
rst_sync #(
    .STAGES (2)
) U_RST (
    .clk         (clk),
    .rst_async_n (rst_async_n),
    .rst_n       (rst_n)
);
```

## 6. 限制
- 只适合单时钟域；跨时钟域复位需在每个时钟域各自同步。
- 输出只作为复位释放信号，不能当数据信号使用。
- 复位源必须同源，禁止把不同复位源拼到同一同步链。

## 7. 验证状态
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS（0 error） |
| 定向 TB | `tb/basic/rst_sync_tb.sv` PASS（异步立即拉低、释放后经 2 拍拉高、运行中再次异步复位） |
| SVA | `rst_sync.sva` 参数检查；需 Verilator 5.x（`--assert -DSVA_ON`） |
| 仿真器 | iverilog 11/12 均通过；SVA 需 Verilator 5.x |
| 未覆盖项 | 非法 `STAGES` 的参数检查未跑（仅验证合法参数路径）；已另验证 `STAGES=1` 经钳位后按 2 级正常工作、无非法位选；未做门级亚稳态建模 |

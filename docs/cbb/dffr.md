# dffr CBB 文档（简单件）
## 1. 基本信息
`CBB-BASIC-002` · `dffr` · `basic` · 已发布
## 2. 功能与范围
- **功能**：带异步复位、复位常量和显式 `en` 的控制寄存器。
- **不包含**：不做复位同步、不提供 valid-ready、不做多时钟域处理。
- **典型场景**：状态机寄存器、配置寄存器、计数器、指针。
## 3. 端口表
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟 |
| `rst_n` | input | 1 | 异步 | 异步复位，低有效 |
| `en` | input | 1 | `clk` | 写使能；`en=1` 时 `q <= d` |
| `d` | input | `W` | `clk` | 数据输入 |
| `q` | output | `W` | `clk` | 数据输出 |

无 valid-ready 接口。
## 4. 参数表
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `W` | `int` | `32` | `W >= 1` | 数据位宽 |
| `RESET_VALUE` | `logic [W-1:0]` | `'0` | 任意 | 复位值 |
## 5. 使用说明
- **时钟/复位/初始化**：`rst_n` 低有效、异步拉低；释放必须由 `rst_sync` 同步。
- **延迟/吞吐**：`en=1` 时 1 拍写入；`en=0` 时保持。
- **反压/握手**：无内建反压，上游通过 `en` 控制写入。

```systemverilog
dffr #(
    .W           (DATA_W),
    .RESET_VALUE ('0)
) U_DATA (
    .clk   (clk),
    .rst_n (rst_sync_n),
    .en    (data_en),
    .d     (data_d),
    .q     (data_q)
);
```
## 6. 限制
- 复位释放不能直接接原始异步复位，必须经 `rst_sync`。
- `RESET_VALUE` 必须是与 `W` 匹配的常量，禁止动态值。
## 7. 验证状态
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS |
| 定向 TB | `tb/basic/dffr_tb.sv` PASS |
| SVA | 不需要（简单单元） |
| 仿真器 | iverilog 12.0 |
| 未覆盖项 | 复位释放亚稳态由 `rst_sync` 覆盖 |

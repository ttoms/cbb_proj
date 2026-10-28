# arbiter_pri CBB 文档（简单件）

## 1. 基本信息
`CBB-ARB-001` · `arbiter_pri` · `arbiter` · 已发布

## 2. 功能与范围
- **功能**：固定优先级仲裁，索引 0 优先级最高，输出独热授权。
- **不包含**：不做轮询/加权/QoS、不做授权寄存、不做背压。
- **典型场景**：固定优先级中断、简单请求合并、测试平台选通。

## 3. 端口表
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `req` | input | `N` | - | 请求位图 |
| `gnt` | output | `N` | - | 独热授权，索引最小者获得 |
| `gnt_vld` | output | 1 | - | `OR(req)`，无请求时为 0 |

无时钟、无复位、无 valid-ready。

## 4. 参数表
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `N` | `int` | `4` | `N >= 1` | 请求路数 |

## 5. 使用说明
- **时钟/复位/初始化**：纯组合逻辑，无时钟和复位。
- **延迟/吞吐**：组合树延迟，深度 `log2(N)`；每拍最多一个授权。
- **反压/握手**：无；授权方需自行保证被授权请求仍有效。

```systemverilog
arbiter_pri #(
    .N (4)
) U_ARB (
    .req     (req),
    .gnt     (gnt),
    .gnt_vld (gnt_vld)
);
```

## 6. 限制
- 低索引持续请求会饿死高索引，固定优先级语义如此。
- 需要公平性时改用 `arbiter_rr` / `arbiter_wrr`。

## 7. 验证状态
| 项 | 结果 |
|---|---|
| `quality_gate.py` | 0 error（PASSED） |
| 定向 TB | `tb/arbiter/arbiter_pri_tb.sv` PASS（N=4：无请求、四路单请求、两两组合的索引优先级、全请求）；`tb/arbiter/arbiter_scale_tb.sv` 覆盖 `N=64/128` |
| SVA | `arbiter_pri.sva` 参数检查；需 Verilator 5.x（`--assert -DSVA_ON`） |
| 仿真器 | iverilog 11/12 均通过；SVA 需 Verilator 5.x |
| 未覆盖项 | `req` 为 X/Z 的行为；未做综合面积与时序评估 |

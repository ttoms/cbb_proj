# clkgate CBB 文档（复杂件）

## 1. 基本信息 [M]
| 项 | 内容 |
|---|---|
| CBB ID | `CBB-BASIC-009` |
| 模块名 | `clkgate` |
| 类别 | `basic` |
| 状态 | 已发布 |
| 版本 | `v0.1.0` |
| 维护人 | - |
| 更新时间 | 2026-10-27 |

## 2. 功能与范围 [M]
- **功能**：自动时钟门控。复位后默认开启时钟；`wakeup` 请求立即开启；`idle` 连续保持 `IDLE_CYCLES` 拍后自动关闭；门控单元由内部 `icg` 实现，输出无毛刺。
- **不包含**：不做 `idle` 判定本身（由业务逻辑给出）、不做跨时钟域同步、不做 test bypass、不做多级门控树。
- **典型场景**：子系统空闲时自动关钟降功耗；替代手写 `assign gclk = clk & en` 的毛刺写法。

## 3. 端口表 [M]
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 未门控原始时钟 |
| `rst_n` | input | 1 | `clk` | 异步复位、同步释放，低有效 |
| `wakeup` | input | 1 | `clk` | 唤醒请求，与 `clk` 同步；优先级最高，单拍即可请求开钟 |
| `idle` | input | 1 | `clk` | 空闲指示，与 `clk` 同步；连续 `IDLE_CYCLES` 拍为 1 后关钟 |
| `gclk` | output | 1 | `clk` | 门控后时钟，无毛刺 |
| `active` | output | 1 | `clk` | 当前门控使能状态，1 表示时钟开启 |

无 valid-ready 握手。`wakeup` / `idle` 必须是未门控时钟域的同步信号。

## 4. 参数表 [M]
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `IDLE_CYCLES` | `int` | `8` | `IDLE_CYCLES >= 1` | 关钟前的空闲判定拍数；1 表示无迟滞 |

参数约束：`IDLE_CYCLES >= 1` 由 `clkgate.sva` 检查；`IDLE_CYCLES=1` 时计数器退化为 1 bit 常量 0。

## 5. 使用说明 [M]
- **时钟/复位**：单时钟；`rst_n` 异步拉低、同步释放，建议由 `rst_sync` 产生。复位期间及复位后 `active=1`，保证下游寄存器可完成初始化。
- **延迟/吞吐**：`en` 在 `clk` 上升沿更新，`icg` 在随后的低电平锁存，因此开钟/关钟都在 `en` 更新后的下一个上升沿生效，延迟 1 拍。
- **反压/握手**：无。
- **优先级**：`wakeup` > `idle`；两者同拍为 1 时按唤醒处理。
- **迟滞**：`idle=1` 连续 `IDLE_CYCLES` 拍才关钟；中途 `idle=0` 或 `wakeup=1` 立即清零计数。
- **限制**：`idle` 若由门控域自身产生，关钟后会冻结为高，必须由未门控域或 `wakeup` 侧提供。

```systemverilog
clkgate #(
    .IDLE_CYCLES (8)
) U_CG (
    .clk    (clk),
    .rst_n  (rst_n),
    .wakeup (wakeup),
    .idle   (idle),
    .gclk   (gclk),
    .active (active)
);
```

## 6. 复位与 CDC [M]
- **复位**：`en` 由 `dffr` 异步复位为 1（开钟），`idle_cnt` 异步复位为 0。
- **CDC**：无。`wakeup` / `idle` 要求已经与 `clk` 同步；跨域唤醒需外部先做同步（`cdc_2ff` 或 `cdc_pulse`，P4）。

## 7. 限制与注意 [M]
- `wakeup` / `idle` 必须同步且属于未门控域，否则关钟后无法采样唤醒。
- 开钟/关钟各有 1 拍延迟；需要当拍响应的场景不能用本模块替代组合门控。
- `IDLE_CYCLES=1` 时 `idle` 一旦为 1，下一个上升沿即关钟，无迟滞。
- `icg` 是行为模型，综合时必须替换为目标工艺库 ICG 单元；门控后时钟只应驱动触发器时钟端。

## 8. 验证状态 [M]
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS（0 error，0 warning） |
| 定向 TB | `tb/basic/clkgate_tb.sv` PASS：`IDLE_CYCLES=1/4/8` 三组，覆盖复位默认开钟、连续空闲关钟、关钟期间无时钟沿、`wakeup` 唤醒、短空闲窗口不关钟、`idle` 撤销保持开钟、`gclk` 无毛刺 |
| SVA | `clkgate.sva`：`IDLE_CYCLES >= 1` 参数检查、复位期间 `active=1`、`wakeup` 后开钟、非空闲保持开钟；需 Verilator 5.x（`--assert -DSVA_ON`） |
| 仿真器 | iverilog 11/12 均通过；SVA 需 Verilator 5.x（`--assert -DSVA_ON`）；`verilator --lint-only -Wall` 无 WIDTH / UNUSED / %Error |
| 未覆盖项 | `IDLE_CYCLES > 16`、`wakeup/idle` 为 X/Z、跨时钟域唤醒（需外部同步）、门级 ICG 单元替换与功耗收益、形式化验证 |

## 9. 微架构与数据流 [C]
- **模块划分**：控制部分（`en` 寄存器 + `idle` 计数器）运行在未门控 `clk` 域；门控部分只例化 `icg`。
- **框图**：

```text
  wakeup ──┬───────────────────────────────┐
           │                               │
  idle ────┼──> [idle 计数器] ──cnt==MAX──> [en 寄存器] ──en──> [icg] ──> gclk
           │        ^    │                    ^     │
           └────────┴────┴── cnt_clr ─────────┘     └──> active
```

- **数据流**：
  - 唤醒路径：`wakeup=1` → `en_set=1`、`cnt_clr=1` → `en` 置 1、计数器清零；`icg` 在低电平锁存后下一个上升沿恢复 `gclk`。
  - 关钟路径：`idle=1` 且 `en=1` 时计数器递增；到达 `IDLE_CYCLES-1` 后 `en_clr=1`，`en` 置 0，`icg` 在低电平锁存后停止输出。
  - 保持路径：`idle=0` 时 `en_set=1` 保持开钟，计数器清零；关钟后 `en_clr` 被 `en` 限定，控制寄存器不再翻转。
- **关键寄存器/存储体**：

| 名称 | 用途 | 复位 | 更新条件（en） |
|---|---|---|---|
| `U_EN.en` | 门控使能 | `dffr` 复位 1 | `wakeup` 或 `~idle` 置 1；计数到顶且 `idle` 置 0 |
| `U_CNT.idle_cnt` | 空闲拍数计数 | `dffr` 复位 0 | 唤醒/非空闲清零；`idle` 且未到顶时递增 |

- **关键设计决策**：控制逻辑全部在未门控域，保证关钟后仍能采样 `wakeup`；`en` 用 `dffr` 复位为 1，保证复位后时钟可用；关钟条件用 `en_clr = en & idle & (cnt==MAX)` 自锁，避免关钟后控制寄存器继续翻转。

## 10. 状态机 [C]
两状态，状态由 `en` 一位寄存器编码，无独立状态寄存器。

| 状态 | `active` | 转移 |
|---|---|---|
| `OFF` | 0 | `wakeup=1` 或 `idle=0` → `ON` |
| `ON` | 1 | `idle=1` 连续 `IDLE_CYCLES` 拍 → `OFF` |

转移条件（每个 `clk` 上升沿）：
- 复位：`ON`（`active=1`，计数 0）。
- `ON` + (`wakeup` 或 `~idle`)：保持 `ON`，计数清零。
- `ON` + `idle` + 计数未到顶：保持 `ON`，计数递增。
- `ON` + `idle` + 计数到顶：进入 `OFF`。
- `OFF` + `wakeup` 或 `~idle`：进入 `ON`。
- `OFF` + `idle` + 计数到顶：保持 `OFF`。

## 11. 时序、流水线与 PPA [C]
| 场景 | 延迟 | 吞吐 | 说明 |
|---|---|---|---|
| `wakeup` → `gclk` 恢复 | 2 个 `clk` 周期 | 1 次/事件 | `en` 打 1 拍 + `icg` 低电平锁存 |
| `idle` 连续 → `gclk` 停止 | `IDLE_CYCLES` + 1 拍 | - | 计数到顶后 1 拍关钟 |
| 正常开钟 | 0 拍 | - | `gclk` 跟随 `clk` |

- **关键路径/流水线**：`idle → 计数器比较 → en_clr → en` 为单级组合；`gclk` 由 `icg` 单元产生，不经过普通数据路径。
- **反压路径**：无。
- **面积/功耗**：1 个 `en` 触发器 + `CNT_W` 位计数器 + 1 个 ICG；关钟后控制寄存器 `en=0`，不再翻转，进一步降低动态功耗。
- **取舍**：单级迟滞结构简单、面积小；代价是开钟有 1~2 拍延迟，且 `idle` 必须由未门控域提供。

## 12. 风险与未覆盖项 [C]
- **风险**：`idle` 来自门控域会冻结，导致无法再次关钟/开钟；`wakeup` 未同步会产生亚稳态。
- **限制**：单时钟；无 test bypass / DFT 门控使能；`IDLE_CYCLES` 越大关钟越慢。
- **未覆盖项**：`IDLE_CYCLES > 16`、`wakeup/idle` 为 X/Z、跨时钟域唤醒、门级 ICG 替换与功耗收益、形式化验证。

## 13. 版本记录 [M]
| 版本 | 日期 | 变更 | 兼容性 |
|---|---|---|---|
| `v0.1.0` | 2026-10-27 | 初版：`wakeup` / `idle` 自动门控 + 内部 `icg` | - |

## 14. 相关文档 [O]
- 待开发清单：[`cbb-list.md`](../cbb-list.md)
- 时钟门控约束：[`cbb-list.md` §7.5](../cbb-list.md)
- 门控单元：[`icg.md`](icg.md)
- 复位释放：[`rst_sync.md`](rst_sync.md)
- 编码规范与模板：`my_env` 的 `rtl-developer` skill

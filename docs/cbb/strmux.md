# strmux CBB 文档（复杂件）

## 1. 基本信息 [M]
| 项 | 内容 |
|---|---|
| CBB ID | `CBB-ARB-008` |
| 模块名 | `strmux` |
| 类别 | `arbiter` |
| 状态 | 已发布 |
| 版本 | `v0.1.2` |
| 维护人 | - |
| 更新时间 | 2026-10-27 |

## 2. 功能与范围 [M]
- **功能**：stream 级选通 mux。多路链路层 stream（`hop` / `top` / `vld` / `rdy` / `pld`）经内部 `arbiter_wrapper` 选出唯一一路输出；`GRAN` 选择逐 flit 仲裁或按 packet 锁定仲裁。
- **不包含**：不实现仲裁算法（全部复用 `arbiter_wrapper`）；不缓存整包；不做 `crdt` / `rop` 信用与路由字段处理（stream 级只暴露 `hop` / `top` / `vld` / `rdy` / `pld`）；不做位宽转换、不做跨时钟域。
- **典型场景**：多通道链路数据流汇聚到单通道。`GRAN=0` 等价于带 packet 字段的 `arbmux`；`GRAN=1` 保证同一 packet 的 flit 连续从同一通道输出。

## 3. 端口表 [M]
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟 |
| `rst_n` | input | 1 | `clk` | 异步复位、同步释放，低有效 |
| `in_hop` | input | `N` | `clk` | 每路 packet 头标记 |
| `in_top` | input | `N` | `clk` | 每路 packet 尾标记 |
| `in_vld` | input | `N` | `clk` | 每路 flit 有效，作为仲裁请求 |
| `in_rdy` | output | `N` | `clk` | 每路反压；仅在输出握手拍对选中通道置 1 |
| `in_pld` | input | `N*PLD_W` | `clk` | 每路 flit 负载，扁平打包，第 `i` 路占 `in_pld[i*PLD_W +: PLD_W]` |
| `weight` | input | `N*WEIGHT_W` | `clk` | 每路权重，透传给 `arbiter_wrapper`；仅 `ARB_WRR` 使用 |
| `qos` | input | `N*QOS_W` | `clk` | 每路 QoS，透传给 `arbiter_wrapper`；仅 `ARB_QRR` 使用 |
| `out_hop` | output | 1 | `clk` | 输出 packet 头标记 |
| `out_top` | output | 1 | `clk` | 输出 packet 尾标记 |
| `out_vld` | output | 1 | `clk` | 输出 flit 有效 |
| `out_rdy` | input | 1 | `clk` | 下游 ready |
| `out_pld` | output | `PLD_W` | `clk` | 输出 flit 负载 |

valid-ready 语义：`out_vld` 与 `out_hop` / `out_top` / `out_pld` 同拍有效，`out_vld` 不依赖 `out_rdy`；`in_rdy[i]` 为 1 表示第 `i` 路 flit 在本拍被消费。

本模块不向外暴露 `upd`，内部按 `arb_upd = out_vld & out_rdy & ((GRAN == 1'b1) ? sel_hop : 1'b1)` 生成并接入 `arbiter_wrapper`：`GRAN=0` 每个被消费的 flit 计一次授权；`GRAN=1` 只在包头 flit（`sel_hop=1`）被消费时计一次，packet 内与反压锁存期间仲裁状态冻结。

## 4. 参数表 [M]
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `N` | `int` | `4` | `N >= 1` | 输入通道数 |
| `PLD_W` | `int` | `32` | `PLD_W >= 1` | flit 负载位宽 |
| `ARB_TYPE` | `logic [2:0]` | `3'b001` | `000 ~ 100` | 仲裁类型，透传 `arbiter_wrapper` |
| `WEIGHT_W` | `int` | `2` | `WEIGHT_W >= 1` | 权重位宽，仅 `ARB_WRR` 使用 |
| `QOS_W` | `int` | `2` | `QOS_W >= 1` | QoS 位宽，仅 `ARB_QRR` 使用 |
| `GRAN` | `logic` | `1'b1` | `0` / `1` | 仲裁粒度：`0`=flit 级，`1`=packet 级 |

参数约束由 `strmux.sva` 检查（`N >= 1`、`PLD_W >= 1`）；`ARB_TYPE` 的合法性由 `arbiter_wrapper.sva` 检查，非法类型在 wrapper 内锁零并在开启 SVA 时 `$fatal`。

## 5. 使用说明 [M]
- **时钟/复位**：单时钟；`rst_n` 建议由 `rst_sync` 产生。复位后 `hold_oh=0`，处于直通仲裁态。
- **延迟/吞吐**：无阻塞时 `in_vld/in_hop/in_top/in_pld → out_*` 为组合通路，0 拍额外延迟，持续请求时 1 flit/拍；packet 粒度下 packet 内允许 `vld` 间隙。
- **反压/握手**：`out_vld && !out_rdy` 时锁存当前选通结果，`out_hop` / `out_top` / `out_pld` 保持稳定；源端必须按 valid-ready 规则保持 `in_vld`、`in_hop`、`in_top`、`in_pld` 直到 `in_rdy` 拉高。
- **粒度选择**：`GRAN=0` 每个 flit 可切换通道；`GRAN=1` 在 packet 头 flit（`hop=1 && top=0`）锁定，直到尾 flit（`top=1`）握手后释放，packet 内（含 `vld` 间隙）不切换。
- **仲裁类型**：`ARB_TYPE` 为 elaboration 参数，只综合选中的仲裁核；`weight` / `qos` 仅对应类型生效。
- **upd 生成**：内部 `arb_upd = out_vld & out_rdy & ((GRAN == 1'b1) ? sel_hop : 1'b1)`，只在被消费时推进仲裁核。`GRAN=0` 每个 flit 计一次；`GRAN=1` 只在包头 flit 被消费时计一次，packet 内与锁定期间状态冻结，详见 §7 与 §9。

```systemverilog
strmux #(
    .N        (4),
    .PLD_W    (32),
    .ARB_TYPE (3'b001),
    .WEIGHT_W (2),
    .QOS_W    (2),
    .GRAN     (1'b1)
) U_STRMUX (
    .clk     (clk),
    .rst_n   (rst_n),
    .in_hop  (in_hop),
    .in_top  (in_top),
    .in_vld  (in_vld),
    .in_rdy  (in_rdy),
    .in_pld  (in_pld),
    .weight  (weight),
    .qos     (qos),
    .out_hop (out_hop),
    .out_top (out_top),
    .out_vld (out_vld),
    .out_rdy (out_rdy),
    .out_pld (out_pld)
);
```

## 6. 复位与 CDC [M]
- **复位**：唯一寄存器 `hold_oh` 由 `dffr` 异步复位到 0，复位后 `hold_vld=0`，走实时仲裁。
- **CDC**：无。单时钟模块，所有逻辑同域。

## 7. 限制与注意 [M]
- packet 必须成对：`hop=1` 起始、`top=1` 结束，且同一 packet 的 flit 连续来自同一通道；模块不做 packet 合法性检查。
- `GRAN=1` 锁定期间不响应其他通道；被锁通道违约（中途撤销 `vld` 或不给 `top`）会长期占用输出，直到复位。
- 单 flit packet（`hop=1 && top=1`）不进入锁定态，按普通 flit 处理，不占用锁存。
- 反压或 packet 锁定期间仲裁核状态冻结：内部 `arb_upd` 仅在输出握手拍有效（`GRAN=1` 还要求当前是包头 flit），`upd=0` 时 RR 指针、WRR credit、LRU age、QRR 轮询点保持不变。因此 `GRAN=1` 下每个 packet 只推进一次指针，“每 packet 一次仲裁”的语义成立。
- `GRAN=0` 反压锁存期间仲裁核冻结，但锁存释放的握手拍 `upd=1`，按仲裁核当拍 `gnt` 推进一次；该 `gnt` 可能与锁存的 `hold_oh` 不同，恢复后的指针以仲裁核当时授权为准，详见 §12 风险。
- 不缓存整包，`GRAN=1` 只锁选通，不锁数据；源端必须保持 packet 内 flit 的连续性责任。
- `ARB_TYPE` 不可运行期切换；切换需重新例化。

## 8. 验证状态 [M]
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS（0 error，0 warning；对齐后复跑） |
| 定向 TB | `tb/arbiter/strmux_tb.sv` PASS：`FIXED+FLIT`、`RR+FLIT`、`FIXED+PKT`、`RR+PKT`、`WRR+PKT weight=8'h83`、`LRU+PKT`、`QRR+PKT qos=8'h2B`、`N=1+PKT` 共 8 组；每组 300 拍随机 packet 流量（`MAX_PKT=4`，packet 内注入 `vld` 间隙）+ 全通道反压 + 无请求场景，逐 flit scoreboard 校验 `pld`/`hop`/`top`，并检查 packet 内不换通道、packet 头不嵌套 |
| SVA | `strmux.sva`：参数检查（`N`/`PLD_W`）+ `out_vld` 必来自有效输入、握手拍 `in_rdy` 独热、非握手拍 `in_rdy` 全零、`in_rdy` 只落在有效输入、反压期间 `out_vld`/`out_hop`/`out_top`/`out_pld` 稳定、输出三字段与被选中通道一致；`GRAN=1` 追加头 flit 锁定、packet 内保持、尾 flit 释放三条 packet 断言；需 Verilator 5.x（`--assert -DSVA_ON`） |
| 仿真器 | iverilog 11/12 均通过；SVA 需 Verilator 5.x（`--assert -DSVA_ON`）；`verilator --lint-only -Wall` 无 WIDTH / UNUSED / %Error |
| 未覆盖项 | `N > 8`、`GRAN=0` 下的 WRR/LRU/QRR 组合、`PLD_W=1`、`in_*` 为 X/Z、源端违反 valid-ready 或 packet 违约的非法输入、`GRAN=0` 锁存期间 `gnt` 与 `hold_oh` 不一致时的公平性偏移量化、门级/综合时序与面积、形式化验证 |

说明：TB 与 `arbmux_tb` 保持同一范式，直接用 packed 切片（`in_pld[i*PLD_W +: PLD_W]`）驱动负载，不经过 unpacked 数组 + `generate assign` 汇聚，以避免 Verilator 运行期不重新触发该连续赋值的限制。

## 9. 微架构与数据流 [C]
- **模块划分**：
  - `U_ARB`：`arbiter_wrapper`，按 `ARB_TYPE` 选择仲裁核，输出 `gnt` / `gnt_vld`。
  - 选通逻辑：`sel_oh = hold_vld ? hold_oh : gnt`，在实时仲裁与锁存之间二选一。
  - `U_HOLD`：`dffr`，保存锁定期间的选通通道。
  - packet 检测：`sel_hop` / `sel_top` 由被选中通道的 `in_hop` / `in_top` 归约得到。
  - `arb_upd`：`out_vld & out_rdy & ((GRAN == 1'b1) ? sel_hop : 1'b1)`，作为 `U_ARB.upd`。
- **框图**：

```text
 in_vld[N] ──────────────┬──────────────► U_ARB (arbiter_wrapper)
 weight/qos ─────────────┘                   │
                                             │ gnt[N] / gnt_vld
                                             v
                        ┌─────────────── sel_oh = hold_vld ? hold_oh : gnt
 in_hop/top/pld ────────┤                      │
                        │                      ├──► sel_hop = |(in_hop & sel_oh)
                        │                      ├──► sel_top = |(in_top & sel_oh)
                        │                      ├──► out_vld = hold_vld ? |(in_vld & hold_oh)
                        │                      │                        : gnt_vld
                        │                      ├──► in_rdy  = {N{out_vld & out_rdy}} & sel_oh
                        │                      └──► out_*   = mux(in_*, sel_oh)
                        │
                   U_ARB.upd = out_vld & out_rdy & ((GRAN == 1) ? sel_hop : 1)
                   U_HOLD (dffr, N bit)
                   hold_set: 反压 (out_vld & ~out_rdy & ~hold_vld)
                             或 GRAN=1 头 flit (out_vld & ~hold_vld & sel_hop & ~sel_top)
                   hold_clr: 握手拍 (out_vld & out_rdy & hold_vld)
                             GRAN=1 时还要求 sel_top
```

- **数据流**：
  - 请求分发：`in_vld` 直接作为仲裁请求进入 `U_ARB`，不因反压或 `GRAN=1` 锁定而屏蔽；`weight` / `qos` 透传；`arb_upd` 只在消费拍拉高，用于推进仲裁核状态。
  - 选择：无锁存时用 `gnt`；有锁存时用 `hold_oh`，忽略仲裁核当拍授权。
  - 输出有效：无锁存时等价于 `gnt_vld`；有锁存时要求被锁存通道的 `in_vld` 仍有效（`GRAN=1` 的 packet 内间隙因此表现为 `out_vld=0`，但锁存保持）。
  - 反压：`in_rdy` 只在 `out_vld & out_rdy` 的握手拍对 `sel_oh` 置位，未选中通道恒为 0。
  - 负载：按 `sel_oh` 做独热 mux，同时取 `in_hop` / `in_top` / `in_pld` 对应位；`sel_oh` 默认 0 时三字段全 0。
  - packet 释放：`GRAN=1` 下只在尾 flit（`sel_top=1`）握手时清锁存；`GRAN=0` 下任意握手拍都清。
- **关键寄存器/存储体**：

| 名称 | 用途 | 复位 | 更新条件（en） |
|---|---|---|---|
| `hold_oh[N]` | 反压 / packet 锁定期间锁存的选通通道（独热） | `dffr` 复位 0 | `hold_set \| hold_clr`；`hold_clr` 优先清 0，`hold_set` 写入 `gnt` |

- **关键设计决策**：
  - 只锁“通道选择”，不缓存 flit 数据；数据稳定性依赖源端遵守 valid-ready，节省存储面积。
  - `set_pkt` 与 `set_bp` 或运算：头 flit 被反压时也锁存，行为与 packet 锁定一致，避免同一 packet 头被两套机制重复处理。
  - 头尾同拍（单 flit packet）不锁，避免为只含一个 flit 的 packet 引入无意义锁存。
  - `hold_clr` 优先于 `hold_set`，避免释放拍与新锁定同拍时旧锁存残留。
  - **按消费计费（`upd`）**：`arb_upd = out_vld & out_rdy & ((GRAN == 1) ? sel_hop : 1)`。`GRAN=0` 每个被消费的 flit 推进一次；`GRAN=1` 只在包头 flit 消费时推进一次，packet 内与锁定期间指针/credit/age 冻结，因此“每个 packet 只计一次仲裁”成立。选择路径保持简单，无需对 `req` 做门控。
  - 锁定期间 `in_vld` 仍原样送入 `U_ARB`，仅靠 `upd=0` 冻结状态；`GRAN=0` 释放拍以仲裁核当拍 `gnt` 推进，可能与 `hold_oh` 不同，见 §12 风险。

## 10. 状态机 [C]
本模块为两状态控制（`hold_vld` 由 `hold_oh` 归约得到），`GRAN` 只改变进入/退出条件：

| 状态 | 编码 | 含义 | 选择源 |
|---|---|------|---|
| `S_RUN` | `hold_vld=0` | 实时仲裁，无锁存 | `gnt` |
| `S_HOLD` | `hold_vld=1` | 反压或 packet 锁定，选通冻结 | `hold_oh` |

| 当前状态 | 条件 | 次态 | 动作 |
|---|---|---|---|
| `S_RUN` | `out_vld & out_rdy`（`GRAN=0` 或非包头） | `S_RUN` | 完成一次 flit 传输，`hold_oh` 保持 0 |
| `S_RUN` | `out_vld & ~out_rdy` | `S_HOLD` | `set_bp`，下一沿写入 `gnt` |
| `S_RUN` | `GRAN=1 & out_vld & sel_hop & ~sel_top` | `S_HOLD` | `set_pkt`，下一沿写入 `gnt` |
| `S_RUN` | `~out_vld` | `S_RUN` | 无请求，`hold_oh=0` |
| `S_HOLD` | `out_vld & out_rdy & (GRAN=0 \| sel_top)` | `S_RUN` | 完成传输（或 packet 结束），`hold_clr`，下一沿清 0 |
| `S_HOLD` | `GRAN=1 & out_vld & out_rdy & ~sel_top` | `S_HOLD` | packet 未结束，保持锁存 |
| `S_HOLD` | `~out_rdy` | `S_HOLD` | 保持锁存，`out_*` 稳定 |
| `S_HOLD` | `~out_vld` | `S_HOLD` | 源端违约或 packet 内间隙；保持锁存，不产生假 valid |

异常处理：`S_HOLD` 下若被锁存通道 `in_vld` 撤销，`out_vld=0`，`hold_oh` 保持，`in_rdy` 全零；若撤销发生在 packet 中途（未给 `top`），锁存不会释放，输出长期被该通道占用，需复位恢复。这是已知限制，模块内无超时检测。

仲裁核仅在 `out_vld & out_rdy` 的握手拍推进：`GRAN=0` 任意握手拍计一次；`GRAN=1` 仅包头 flit 握手拍计一次，`S_HOLD` 期间的后续 flit 与反压拍均冻结。

## 11. 时序、流水线与 PPA [C]
| 场景 | 延迟 | 吞吐 | 说明 |
|---|---|---|---|
| 无阻塞直通 | 组合（0 拍） | 1 flit/拍 | `gnt → sel_oh → out_*` 同一拍 |
| 首次反压 | +1 拍锁存 | 反压期间 0 | 反压拍 `hold_set`，下一沿生效 |
| packet 头 flit | +1 拍锁存 | packet 内 1 flit/拍 | 头 flit 握手后锁存，直到 `top` |
| packet 内 `vld` 间隙 | - | 0 | `out_vld=0`，锁存保持 |
| 反压释放 / packet 结束 | 释放拍即完成传输 | 1 flit/拍 | `hold_clr` 在下一沿清锁存 |
| 无请求 | 组合 | 0 | `out_vld=0`，`in_rdy=0` |

- **关键路径/流水线**：`in_vld → arbiter_wrapper（组合仲裁）→ sel_oh → out_vld/out_hop/out_top/in_rdy/out_pld`。无反压时单级组合；反压/packet 锁定后经 `hold_oh` 旁路仲裁核。
- **反压路径**：`out_rdy → in_rdy` 为组合；`out_rdy` 只影响 `U_HOLD` 的 en/d，不组合回灌仲裁核。
- **面积/功耗**：面积 = 选中仲裁核 + `N` 位 `dffr` + `PLD_W` 位独热 mux + 2 位 hop/top 独热 mux + `in_rdy` 与门；相对 `arbmux` 只多 `hop` / `top` 两路归约与 mux。无额外 flit 存储。反压与 packet 锁定期间 `upd=0`、仲裁核状态不翻转，功耗低于“持续推进”方案。
- **取舍**：选择“只锁选通、不锁数据、按消费计费”，面积与控制路径最简；代价是要求源端严格遵守 valid-ready 与 packet 连续性。`GRAN=1` 下每 packet 只计一次仲裁，WRR credit 按 packet 而非 flit 扣减。

## 12. 风险与未覆盖项 [C]
- **风险**：源端违反 valid-ready（反压期间撤销 `in_vld` 或改 `in_*`）会导致丢数或字段错配，模块内无检测。
- **风险**：`GRAN=1` 下 packet 中途断流且不给 `top`，锁存无法释放，输出长期被占用。
- **风险**：`upd` 在消费拍生成，而消费通道可能由 `hold_oh` 决定；`GRAN=0` 反压锁存期间仲裁核的 `gnt` 可能随请求变化而与 `hold_oh` 不同，释放拍按 `gnt` 推进一次，恢复后的指针以仲裁核当时授权为准。严格公平性场景需评估该行为。
- **风险**：`GRAN=1` 只在包头 flit（`sel_hop=1`）消费时计一次仲裁；包头标记异常（缺失或错位）会改变每 packet 的计费次数。模块不做 packet 合法性检查，依赖源端保证 `hop`/`top` 成对。
- **限制**：单时钟；不做 packet 合法性检查；`ARB_TYPE` 不可运行期切换；未选中通道在锁定期间拿不到 `in_rdy`。
- **未覆盖项**：`N > 8`、`GRAN=0` 下的 WRR/LRU/QRR、`PLD_W=1`、`in_*` 为 X/Z、非法源端时序、`GRAN=0` 锁存期间 `gnt` 与 `hold_oh` 不一致时的公平性偏移量化、门级仿真与综合时序/面积、形式化验证。

## 13. 版本记录 [M]
| 版本 | 日期 | 变更 | 兼容性 |
|---|---|---|---|
| `v0.1.2` | 2026-10-27 | 仲裁核接入 `upd`：`GRAN=1` 每 packet 只计一次，反压/锁定期间状态冻结 | 兼容 |
| `v0.1.1` | 2026-10-27 | 补充 `GRAN=1` 锁定期间仲裁器不冻结的取舍说明；统一仿真器声明 | 兼容 |
| `v0.1.0` | 2026-10-27 | 初版：stream 级选通 + 反压锁存 + `GRAN` flit/packet 粒度 | - |

## 14. 相关文档 [O]
- 待开发清单：[`cbb-list.md`](../cbb-list.md)
- 仲裁家族约束：[`cbb-list.md` §7.3](../cbb-list.md)
- 底层封装：[`arbiter_wrapper.md`](arbiter_wrapper.md)
- flit 级版本：[`arbmux.md`](arbmux.md)
- 编码规范与模板：`my_env` 的 `rtl-developer` skill

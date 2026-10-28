# arbmux CBB 文档（复杂件）

## 1. 基本信息 [M]
| 项 | 内容 |
|---|---|
| CBB ID | `CBB-ARB-007` |
| 模块名 | `arbmux` |
| 类别 | `arbiter` |
| 状态 | 已发布 |
| 版本 | `v0.1.2` |
| 维护人 | - |
| 更新时间 | 2026-10-27 |

## 2. 功能与范围 [M]
- **功能**：flit 级选通 mux。多路 valid-ready flit 输入经内部 `arbiter_wrapper` 选出唯一一路输出；反压期间锁存选通结果，保证不丢数、不重复、不产生假 valid。
- **不包含**：不实现仲裁算法（全部复用 `arbiter_wrapper`）；不保持 packet 边界（逐 flit 重新仲裁）；不做位宽转换、不做跨时钟域。
- **典型场景**：多通道 flit 汇聚到单通道；与 `strmux` 对应，`arbmux` 面向无 packet 语义的 flit 流。

## 3. 端口表 [M]
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟 |
| `rst_n` | input | 1 | `clk` | 异步复位、同步释放，低有效 |
| `in_vld` | input | `N` | `clk` | 每路 flit 有效，作为仲裁请求 |
| `in_rdy` | output | `N` | `clk` | 每路反压；仅在输出握手拍对选中通道置 1 |
| `in_pld` | input | `N*PLD_W` | `clk` | 每路 flit 负载，扁平打包，第 `i` 路占 `in_pld[i*PLD_W +: PLD_W]` |
| `weight` | input | `N*WEIGHT_W` | `clk` | 每路权重，透传给 `arbiter_wrapper`；仅 `ARB_WRR` 使用 |
| `qos` | input | `N*QOS_W` | `clk` | 每路 QoS，透传给 `arbiter_wrapper`；仅 `ARB_QRR` 使用 |
| `out_vld` | output | 1 | `clk` | 输出 flit 有效 |
| `out_rdy` | input | 1 | `clk` | 下游 ready |
| `out_pld` | output | `PLD_W` | `clk` | 输出 flit 负载 |

valid-ready 语义：`out_vld` 与 `out_pld` 同拍有效，`out_vld` 不依赖 `out_rdy`；`in_rdy[i]` 为 1 表示第 `i` 路 flit 在本拍被消费。

本模块不向外暴露 `upd`，内部按 `arb_upd = out_vld & out_rdy` 生成并接入 `arbiter_wrapper`：每个被消费的 flit 计一次授权，反压锁存期间仲裁状态冻结。

## 4. 参数表 [M]
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `N` | `int` | `4` | `N >= 1` | 输入通道数 |
| `PLD_W` | `int` | `32` | `PLD_W >= 1` | flit 负载位宽 |
| `ARB_TYPE` | `logic [2:0]` | `3'b001` | `000 ~ 100` | 仲裁类型，透传 `arbiter_wrapper` |
| `WEIGHT_W` | `int` | `2` | `WEIGHT_W >= 1` | 权重位宽，仅 `ARB_WRR` 使用 |
| `QOS_W` | `int` | `2` | `QOS_W >= 1` | QoS 位宽，仅 `ARB_QRR` 使用 |

参数约束由 `arbmux.sva` 检查（`N >= 1`、`PLD_W >= 1`）；`ARB_TYPE` 的合法性由 `arbiter_wrapper.sva` 检查，非法类型在 wrapper 内锁零并在开启 SVA 时 `$fatal`。

## 5. 使用说明 [M]
- **时钟/复位**：单时钟；`rst_n` 建议由 `rst_sync` 产生。复位后 `hold_oh=0`，处于直通仲裁态。
- **延迟/吞吐**：无阻塞时 `in_vld/in_pld → out_vld/out_pld` 为组合通路，0 拍额外延迟，持续请求时 1 flit/拍。首次遇反压时在下一时钟沿锁存选通通道（1 拍），之后保持。
- **反压/握手**：`out_vld && !out_rdy` 时锁存当前选通结果，`out_pld` 保持稳定；源端必须按 valid-ready 规则保持 `in_vld` 与 `in_pld` 直到 `in_rdy` 拉高。
- **仲裁类型**：`ARB_TYPE` 为 elaboration 参数，只综合选中的仲裁核；`weight` / `qos` 仅对应类型生效。
- **upd 生成**：内部 `arb_upd = out_vld & out_rdy`，只在 flit 被下游消费时推进仲裁核状态；反压锁存期间指针/credit/年龄保持不变。
- **限制**：反压锁存期间仲裁状态冻结，解锁后回到同一通道时按该次授权计一次；不做 packet 边界保持，需要 packet 粒度请用 `strmux`。

```systemverilog
arbmux #(
    .N        (4),
    .PLD_W    (32),
    .ARB_TYPE (3'b001),
    .WEIGHT_W (2),
    .QOS_W    (2)
) U_ARBMUX (
    .clk     (clk),
    .rst_n   (rst_n),
    .in_vld  (in_vld),
    .in_rdy  (in_rdy),
    .in_pld  (in_pld),
    .weight  (weight),
    .qos     (qos),
    .out_vld (out_vld),
    .out_rdy (out_rdy),
    .out_pld (out_pld)
);
```

## 6. 复位与 CDC [M]
- **复位**：唯一寄存器 `hold_oh` 由 `dffr` 异步复位到 0，复位后 `hold_vld=0`，走实时仲裁。
- **CDC**：无。单时钟模块，所有逻辑同域。

## 7. 限制与注意 [M]
- 源端必须遵守 valid-ready：`in_rdy=0` 期间不得撤销 `in_vld`、不得改变 `in_pld`；否则输出可能丢数。
- 反压期间被忽略的非选中通道请求不会得到 `in_rdy`，源端需自行保持。
- 仲裁核在反压期间状态冻结（`upd=0`），释放后从同一授权点继续，不会因反压时长改变轮询/credit 进度。
- 逐 flit 重新仲裁，不保证同一 packet 的 flit 连续输出；packet 语义请用 `strmux`。
- `ARB_TYPE` 不可运行期切换；切换需重新例化。

## 8. 验证状态 [M]
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS（0 error，0 warning；对齐后复跑） |
| 定向 TB | `tb/arbiter/arbmux_tb.sv` PASS：`FIXED N=4`、`RR N=4`、`WRR N=4 weight=8'h83`、`LRU N=4`、`QRR N=4 qos=8'h2B`、`RR N=1` 共 6 组；每组 200 拍随机流量 + 全通道反压保持/释放 + 无请求场景，逐拍 scoreboard 校验 |
| SVA | `arbmux.sva`：参数检查（`N`/`PLD_W`）+ `out_vld` 必来自有效输入、握手拍 `in_rdy` 独热、非握手拍 `in_rdy` 全零、`in_rdy` 只落在有效输入、`upd` 推进时 `gnt` 与被选中通道一致、反压期间 `out_vld`/`out_pld` 稳定、`out_pld` 与被选中通道一致；需 Verilator 5.x（`--assert -DSVA_ON`） |
| 仿真器 | iverilog 11/12 均通过；SVA 需 Verilator 5.x（`--assert -DSVA_ON`）；`verilator --lint-only -Wall` 无 WIDTH / UNUSED / %Error |
| 未覆盖项 | packet 边界（不属于本模块）、`N > 8`、`in_vld`/`in_pld` 为 X/Z、源端违反 valid-ready 的非法输入、门级/综合时序与面积、形式化验证 |

说明：TB 直接用 packed 切片（`in_pld[i*PLD_W +: PLD_W]`）驱动负载，而不从 unpacked 数组经 `generate assign` 汇聚。原因是 Verilator 不会在运行期写 unpacked 数组元素后重新触发该连续赋值（iverilog 正常），会造成仅 Verilator 下的假失败。

## 9. 微架构与数据流 [C]
- **模块划分**：
  - `U_ARB`：`arbiter_wrapper`，按 `ARB_TYPE` 选择仲裁核，输出 `gnt` / `gnt_vld`。
  - 选通逻辑：`sel_oh = hold_vld ? hold_oh : gnt`，在实时仲裁与锁存之间二选一。
  - `U_HOLD`：`dffr`，保存反压期间的选通通道。
- **框图**：

```text
 in_vld[N] ──────────────┬──────────────► U_ARB (arbiter_wrapper)
 weight/qos ─────────────┘                   │
                                             │ gnt[N] / gnt_vld
                                             v
                        ┌─────────────── sel_oh = hold_vld ? hold_oh : gnt
 in_pld[N*PLD_W] ───────┤                      │
                        │                      ├──► out_vld = hold_vld ? |(in_vld & hold_oh)
                        │                      │                        : gnt_vld
                        │                      ├──► in_rdy  = {N{out_vld & out_rdy}} & sel_oh
                        │                      └──► out_pld = mux(in_pld, sel_oh)
                        │
                        └──► U_ARB.upd = out_vld & out_rdy
                   U_HOLD (dffr, N bit)
                   hold_set: out_vld & ~out_rdy & ~hold_vld → d = gnt
                   hold_clr: out_vld &  out_rdy &  hold_vld → d = 0
```

- **数据流**：
  - 请求分发：无锁存时 `in_vld` 进入 `U_ARB`；锁存时只把 `hold_oh` 作为 `arb_req` 喂给仲裁核，保证 `upd` 推进的是实际被服务的通道；`weight` / `qos` 透传；`upd` 由输出握手 `out_vld & out_rdy` 生成。
  - 选择：无锁存时用 `gnt`；有锁存时用 `hold_oh`，忽略仲裁核当拍授权。
  - 输出有效：无锁存时等价于 `gnt_vld`（有合法授权）；有锁存时要求被锁存通道的 `in_vld` 仍有效。
  - 反压：`in_rdy` 只在 `out_vld & out_rdy` 的握手拍对 `sel_oh` 置位，未选中通道恒为 0。
  - 负载：按 `sel_oh` 做独热掩码 OR，取 `in_pld` 对应切片；`sel_oh` 默认 0 时 `out_pld=0`。
- **关键寄存器/存储体**：

| 名称 | 用途 | 复位 | 更新条件（en） |
|---|---|---|---|
| `hold_oh[N]` | 反压期间锁存的选通通道（独热） | `dffr` 复位 0 | `hold_set \| hold_clr`；`hold_clr` 优先清 0，`hold_set` 写入 `gnt` |

- **关键设计决策**：
  - 反压只锁存“通道选择”，不额外缓存 flit 数据；数据稳定性依赖源端遵守 valid-ready，节省存储面积。
  - `hold_clr` 优先于 `hold_set`，避免释放拍与新反压同拍时旧锁存残留；二者互斥（`hold_vld` 条件相反），优先级仅用于表达式确定性。

## 10. 状态机 [C]
本模块为两状态控制（`hold_vld` 由 `hold_oh` 归约得到），状态语义如下：

| 状态 | 编码 | 含义 | 选择源 |
|---|---|------|---|
| `S_RUN` | `hold_vld=0` | 实时仲裁，无锁存 | `gnt` |
| `S_HOLD` | `hold_vld=1` | 反压锁存，选通冻结 | `hold_oh` |

| 当前状态 | 条件 | 次态 | 动作 |
|---|---|---|---|
| `S_RUN` | `out_vld & out_rdy` | `S_RUN` | 完成一次 flit 传输，`hold_oh` 保持 0 |
| `S_RUN` | `out_vld & ~out_rdy` | `S_HOLD` | `hold_set`，下一沿写入 `gnt` |
| `S_RUN` | `~out_vld` | `S_RUN` | 无请求，`hold_oh=0` |
| `S_HOLD` | `out_vld & out_rdy` | `S_RUN` | 完成传输，`hold_clr`，下一沿清 0 |
| `S_HOLD` | `~out_rdy` | `S_HOLD` | 保持锁存，`out_pld` 稳定 |
| `S_HOLD` | `~out_vld` | `S_HOLD` | 源端违约撤销 `in_vld`；保持锁存，不产生假 valid |

异常处理：`S_HOLD` 下若被锁存通道 `in_vld` 撤销，`out_vld=0`，`hold_oh` 保持，`in_rdy` 全零；不丢数、不误消费，直到源端恢复或复位。

## 11. 时序、流水线与 PPA [C]
| 场景 | 延迟 | 吞吐 | 说明 |
|---|---|---|---|
| 无阻塞直通 | 组合（0 拍） | 1 flit/拍 | `gnt → sel_oh → out_*` 同一拍 |
| 首次反压 | +1 拍锁存 | 反压期间 0 | 反压拍 `hold_set`，下一沿生效 |
| 反压释放 | 释放拍即完成传输 | 1 flit/拍 | `hold_clr` 在下一沿清锁存 |
| 无请求 | 组合 | 0 | `out_vld=0`，`in_rdy=0` |

- **关键路径/流水线**：`in_vld → arbiter_wrapper（组合仲裁）→ sel_oh → out_vld/in_rdy/out_pld`。无反压时单级组合；反压时经 `hold_oh` 旁路仲裁核，缩短释放拍组合路径。
- **反压路径**：`out_rdy → in_rdy` 为组合；`out_rdy` 参与 `hold_set/hold_clr`，只影响 `U_HOLD` 的 en/d，不组合回灌仲裁核。
- **面积/功耗**：面积 = 选中仲裁核 + `N` 位 `dffr` + `PLD_W` 位独热掩码 OR + `in_rdy` 与门；无额外 flit 存储。反压期间仲裁核 `upd=0`、状态不翻转，功耗低于“持续推进”方案。
- **取舍**：选择“只锁选通、不锁数据”，面积最小，代价是要求源端严格遵守 valid-ready；`upd` 让仲裁核只在消费拍推进，反压期间状态冻结，行为可预测。

## 12. 风险与未覆盖项 [C]
- **风险**：源端违反 valid-ready（反压期间撤销 `in_vld` 或改 `in_pld`）会导致丢数或负载错配，模块内无检测。
- **风险**：锁存期间仲裁核的 `gnt` 可能随请求变化而与 `hold_oh` 不同；`upd` 仍按握手计一次，恢复后的指针以仲裁核当时的授权为准。对严格公平性有要求的场景需评估该行为。
- **限制**：单时钟；无 packet 边界；`ARB_TYPE` 不可运行期切换；未选中通道在反压期间拿不到 `in_rdy`。
- **未覆盖项**：`N > 8`、`in_vld`/`in_pld` 为 X/Z、非法源端时序、门级仿真与综合时序/面积、形式化验证。

## 13. 版本记录 [M]
| 版本 | 日期 | 变更 | 兼容性 |
|---|---|---|---|
| `v0.1.2` | 2026-10-27 | 仲裁核接入 `upd = out_vld & out_rdy`，反压期间状态冻结 | 兼容 |
| `v0.1.1` | 2026-10-27 | 统一仿真器声明与门控检查项措辞 | 兼容 |
| `v0.1.0` | 2026-10-27 | 初版：flit 级选通 + 反压锁存选通通道 | - |

## 14. 相关文档 [O]
- 待开发清单：[`cbb-list.md`](../cbb-list.md)
- 仲裁家族约束：[`cbb-list.md` §7.3](../cbb-list.md)
- 底层封装：[`arbiter_wrapper.md`](arbiter_wrapper.md)
- 后续 stream 版本：[`strmux.md`](strmux.md)（待开发）
- 编码规范与模板：`my_env` 的 `rtl-developer` skill

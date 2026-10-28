# flow_shaper CBB 文档（复杂件）

> 状态：已发布。

## 1. 基本信息 [M]
| 项 | 内容 |
|---|---|
| CBB ID | `CBB-STREAM-006` |
| 模块名 | `flow_shaper` |
| 类别 | `stream` |
| 状态 | 已发布 |
| 版本 | `v0.1.0` |
| 维护人 | - |
| 更新时间 | 2026-10-28 |

## 2. 功能与范围 [M]
- **功能**：基于令牌桶的 valid-ready 流限速，用反压控制速率，不丢包；速率与突发由参数给定。
- **不包含**：不做丢包/标记；不做多队列调度；不做 packet 级原子性保证；不做 CDC；不内置 FIFO。
- **典型场景**：链路发送侧限速、NoC 出口流量整形、下游带宽保护、测试激励限速。

## 3. 端口表 [M]
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟 |
| `rst_n` | input | 1 | `clk` | 异步复位、同步释放，低有效 |
| `in_vld` | input | 1 | `clk` | 输入有效，与 `in_data` 同周期 |
| `in_rdy` | output | 1 | `clk` | 输入就绪；令牌不足或下游不 ready 时为 0 |
| `in_data` | input | `W` | `clk` | 输入数据 |
| `out_vld` | output | 1 | `clk` | 输出有效；`in_vld && token_ok` |
| `out_rdy` | input | 1 | `clk` | 下游就绪 |
| `out_data` | output | `W` | `clk` | 输出数据，直连 `in_data` |

valid-ready 约定：`out_vld` 不依赖 `out_rdy`；`in_rdy` 可依赖 `out_rdy`；传输成立条件为 `vld && rdy`；不丢数、不重复。

## 4. 参数表 [M]
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `W` | `int` | `32` | `W >= 1` | 数据位宽 |
| `TICK_CYCLES` | `int` | `8` | `TICK_CYCLES >= 1` | 每多少个时钟补充一次令牌 |
| `TOKENS_PER_TICK` | `int` | `1` | `TOKENS_PER_TICK >= 1` | 每个 tick 补充的令牌数（1 令牌 = 1 拍数据） |
| `BURST` | `int` | `8` | `BURST >= 1` | 令牌桶容量，决定最大突发拍数 |
| `INIT_TOKENS` | `int` | `0` | `0 <= INIT_TOKENS <= BURST` | 复位后的初始令牌数 |

参数约束：
- 长期速率 = `TOKENS_PER_TICK / TICK_CYCLES` 拍/时钟；瞬时突发上限为 `BURST`。
- `TOKENS_PER_TICK > BURST` 合法，但每 tick 有效补充会被桶容量截断到 `BURST`；通常建议 `TOKENS_PER_TICK <= BURST`，不把推荐值写成非法约束。
- 派生位宽：`TICK_W = $clog2(TICK_CYCLES)`，`TOKEN_W = $clog2(BURST+1)`，`SUM_W = $clog2(BURST+TOKENS_PER_TICK+1)`。
- `INIT_TOKENS` 默认 0，表示复位后先受限；需要上电即允许一个突发时设为 `BURST`。

## 5. 使用说明 [M]
- **时钟/复位**：单时钟；`rst_n` 异步拉低、同步释放。复位后 `tokens = INIT_TOKENS`、`tick_cnt = 0`。
- **延迟/吞吐**：数据路径无缓冲，`out_data = in_data`，`out_vld` 与令牌判断同拍组合；有令牌时 1 拍/项，令牌耗尽后按补充速率放行。
- **反压**：令牌不足时 `in_rdy=0`，上游保持数据；下游不 ready 时 `in_rdy=0`，令牌不被消耗。
- **突发**：桶满时允许连续 `BURST` 拍；随后按 `TOKENS_PER_TICK / TICK_CYCLES` 放行。
- **初始化**：复位后 `tick_cnt=0`，第一个 tick 在第 `TICK_CYCLES-1` 拍出现。
- **限制**：不保证 packet 内连续；若需要 packet 原子性，在上游加 FIFO 或 packet 级门控。

```systemverilog
flow_shaper #(
    .W               (DATA_W),
    .TICK_CYCLES     (8),
    .TOKENS_PER_TICK (1),
    .BURST           (8),
    .INIT_TOKENS     (0)
) U_SHAPER (
    .clk      (clk),
    .rst_n    (rst_n),
    .in_vld   (in_vld),
    .in_rdy   (in_rdy),
    .in_data  (in_data),
    .out_vld  (out_vld),
    .out_rdy  (out_rdy),
    .out_data (out_data)
);
```

## 6. 复位与 CDC [M]
- **复位**：`tokens`、`tick_cnt` 用 `dffr` 复位；`tokens` 复位值为 `INIT_TOKENS`；数据通路无寄存器。
- **CDC**：无。单时钟模块。

## 7. 限制与注意 [M]
- 令牌粒度是“拍”，不是 byte；不同位宽下相同参数对应的字节速率不同。
- 不做丢包/标记，令牌不足只会反压；上游必须能承受反压。
- 不保证 packet 内 beat 连续；若下游要求整包连续，需要外部缓冲或 packet 级锁。
- 速率是长期平均；`TICK_CYCLES` 越大，补充越集中，瞬时突发越明显。
- `TOKENS_PER_TICK > BURST` 时有效补充被截断，实际速率可能低于参数名义值。
- 所有参数为 elaboration 常量，运行期不可改。

## 8. 验证状态 [M]
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS（0 error） |
| 定向 TB | `tb/stream/flow_shaper_tb.sv` PASS（`TICK_CYCLES=4`、`TOKENS_PER_TICK=1`、`BURST=2`；`INIT_TOKENS=0` 与 `2` 两种配置各 200 拍随机 `out_rdy`，逐拍比对令牌模型） |
| SVA | `flow_shaper.sva`：参数检查 + 令牌上界/输出令牌门槛断言；需 Verilator 5.x（`--assert -DSVA_ON`） |
| 仿真器 | iverilog 11 通过 |
| Verilator lint | `--lint-only -Wall` 0 warning |
| 未覆盖项 | `TICK_CYCLES=1`、`TOKENS_PER_TICK > BURST`、长时间速率/抖动统计、复位发生在传输中 |

## 9. 微架构与数据流 [C]
- **模块划分**：单模块；`U_TICK_CNT`（`dffr`）产生周期 tick，`U_TOKENS`（`dffr`）保存令牌数，组合逻辑完成补充、饱和、消耗判断。
- **框图**：

```text
                 +-------------------+
                 | U_TICK_CNT (dffr) |-- tick = (cnt == TICK_CYCLES-1)
                 +-------------------+
                           |
                           v  add = tick ? TOKENS_PER_TICK : 0
  tokens(dffr) --> [ + ] --> [ 饱和到 BURST ] --> avail
                                                    |
                          +-------------------------+
                          |                         |
                    token_ok = (avail != 0)         |
                          |                         |
  in_vld -----------------+--> out_vld = in_vld & token_ok
  out_rdy -----------------+--> in_rdy  = token_ok & out_rdy
                          |
                    fire = in_vld & in_rdy
                          |
                    tokens_nxt = avail - fire
```

- **数据流**：`in_data` 直连 `out_data`；令牌桶只做门控。每个成功传输消耗 1 个令牌；每 `TICK_CYCLES` 拍补充 `TOKENS_PER_TICK` 个，补充后超过 `BURST` 的部分丢弃（饱和）。
- **关键寄存器/存储体**：

| 名称 | 用途 | 复位 | 更新条件（en） |
|---|---|---|---|
| `tick_cnt` | 补充周期计数，`0..TICK_CYCLES-1` | `dffr` 复位 0 | 恒为 1（自由运行） |
| `tokens` | 当前令牌数 | `dffr` 复位 `INIT_TOKENS` | `tick \| fire` |

- **关键设计决策**：令牌判断组合进行，避免每拍额外气泡；不做内部 FIFO，保持 CBB 轻量，反压由上游承担；用饱和加法而不是取模，保证桶容量语义直观。

## 10. 状态机 [C]
不适用。模块只有计数器、令牌寄存器和组合门控，没有多步控制序列。

## 11. 时序、流水线与 PPA [C]
| 场景 | 延迟 | 吞吐 | 说明 |
|---|---|---|---|
| 令牌充足 | 0 拍 | 1 项/拍 | 直通门控 |
| 令牌耗尽 | - | 0 | 反压上游，按补充速率恢复 |
| 下游反压 | - | 0 | 不消耗令牌 |

- **关键路径/流水线**：`tokens + add → 饱和比较 → 归零比较 → 与 out_rdy 相与`，约 3~4 级组合逻辑；数据路径无逻辑。
- **反压路径**：`out_rdy → in_rdy` 组合，1 级 AND。
- **面积/功耗**：约 `TICK_W + TOKEN_W` 个触发器、一个小加法器、两个比较器；无存储体。
- **取舍**：组合令牌判断换 0 拍延迟与 1 拍/项吞吐；若时序紧张，可把 `token_ok` 打拍，代价是每拍多 1 拍延迟并可能引入气泡。

## 12. 风险与未覆盖项 [C]
- **风险**：逐拍整形会把 packet 内 beat 拉开；若下游依赖 packet 连续到达，需要额外缓冲/锁。
- **风险**：`TOKENS_PER_TICK > BURST` 时名义速率与实际速率不一致，文档需明确。
- **风险**：`tick` 相位固定从复位开始，多实例之间的补充相位不保证对齐。
- **限制**：令牌粒度为拍；不支持运行期改速率；不区分 packet。
- **未覆盖项**：实现前未做任何仿真；长期速率误差与抖动未评估。

## 13. 版本记录 [M]
| 版本 | 日期 | 变更 | 兼容性 |
|---|---|---|---|
| `v0.1.0` | 2026-10-28 | 初版：架构 + 实现 + 定向 TB | - |

## 14. 相关文档 [O]
- 待开发清单：[`cbb-list.md`](../cbb-list.md)
- 基础计数器：[`counter.md`](counter.md)

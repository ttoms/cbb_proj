# arbiter_wrr CBB 文档（复杂件）

## 1. 基本信息 [M]
| 项 | 内容 |
|---|---|
| CBB ID | `CBB-ARB-003` |
| 模块名 | `arbiter_wrr` |
| 类别 | `arbiter` |
| 状态 | 已发布 |
| 版本 | `v0.1.1` |
| 维护人 | - |
| 更新时间 | 2026-10-27 |

## 2. 功能与范围 [M]
- **功能**：加权轮询（weighted round-robin）仲裁，按每路权重分配每轮的授权次数，同权重通道之间轮询。
- **不包含**：不做 QoS 分组、不做令牌桶限速、不做授权寄存、不做背压。
- **典型场景**：多通道按带宽比例共享单端口、`arbiter_wrapper` 的 `ARB_WRR` 分支、需要可配置带宽分配的数据通路。

## 3. 端口表 [M]
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟 |
| `rst_n` | input | 1 | `clk` | 异步复位、同步释放，低有效 |
| `upd` | input | 1 | `clk` | 当前 `gnt` 被消费；仅此时更新 `credit` / `ptr` |
| `req` | input | `N` | `clk` | 请求位图，每路 1 bit |
| `weight` | input | `N*WEIGHT_W` | `clk` | 每路权重，扁平打包，第 `i` 路占 `weight[i*WEIGHT_W +: WEIGHT_W]` |
| `gnt` | output | `N` | `clk` | 独热授权，最多一路有效 |
| `gnt_vld` | output | 1 | `clk` | 有有效请求（`weight>0`）且完成授权时为 1 |

无 valid-ready 握手；`gnt` 为组合输出，`req` 在授权周期内必须保持有效。

`upd` 表示“当前 `gnt` 已被下游消费”，仲裁核只在 `gnt_vld & upd` 的时钟沿扣减 `credit` 并推进 `ptr`。`upd` 必须与消费当前 `gnt` 的那一拍对齐；`upd` 恒为 1 时退化为旧行为。`arbmux` / `strmux` 内部用输出 `vld & rdy` 握手生成该信号。

## 4. 参数表 [M]
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `N` | `int` | `4` | `N >= 1` | 请求路数 |
| `WEIGHT_W` | `int` | `2` | `WEIGHT_W >= 1` | 每路权重位宽，权重范围 `0 ~ 2**WEIGHT_W-1` |

参数约束：`N >= 1`、`WEIGHT_W >= 1` 由 `arbiter_wrr.sva` 检查；索引位宽 `IDX_W = (N > 1) ? $clog2(N) : 1` 自动派生。

## 5. 使用说明 [M]
- **时钟/复位**：单时钟；`rst_n` 异步拉低、同步释放，建议由 `rst_sync` 产生。复位清 `ptr` 和所有 credit。
- **延迟/吞吐**：`req/weight → gnt` 纯组合；每拍最多一个授权，持续请求时 1 次授权/拍，无气泡。
- **反压**：无。授权方（`arbmux` / `strmux`）负责在未握手时保持请求并处理反压。
- **初始化**：复位后 `credit=0`，第一拍检测到“无可用 credit”时同拍按 `weight` 重装并授权。
- **upd 语义**：仅在 `gnt_vld & upd` 时扣减 `credit`、推进 `ptr`；`upd=0` 时仲裁状态冻结，授权可重复输出同一路。
- **权重语义**：`weight=0` 的通道不参与仲裁；全部为 0 时 `gnt_vld=0`。
- **限制**：`weight` 视为静态配置；`gnt` 为组合输出。

```systemverilog
arbiter_wrr #(
    .N        (4),
    .WEIGHT_W (2)
) U_ARB (
    .clk     (clk),
    .rst_n   (rst_n),
    .upd     (upd),
    .req     (req),
    .weight  (weight),
    .gnt     (gnt),
    .gnt_vld (gnt_vld)
);
```

## 6. 复位与 CDC [M]
- **复位**：`ptr` 与 `credit` 都是控制类寄存器，用 `dffr` 异步复位到 0；无数据通路寄存器。
- **CDC**：无。单时钟模块，所有逻辑同域。

## 7. 限制与注意 [M]
- `weight` 运行期变化可能使已累积的 `credit` 超过新权重，需保持配置稳定或在空闲期修改。
- 一轮内同一通道可能连续获得多次授权，瞬时存在突发；对平滑度要求高时改用 DRR/令牌桶。
- 请求位图在授权周期内必须稳定；组合撤销请求可能导致 `gnt` 抖动。
- `upd=0` 时 credit 与 `ptr` 冻结，同一路可重复获得授权，直到下游消费。
- `N=1` 时只有一路，`ptr` 恒为 0。

## 8. 验证状态 [M]
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS（0 error） |
| 定向 TB | `tb/arbiter/arbiter_wrr_tb.sv` PASS：`N=1`、等权重 `{1,1,1,1}`、混合权重 `{3,1,0,2}`（含零权重）、全零权重四组，各跑 3 轮授权计数 + 200 拍随机不变量检查 + `upd=0` 冻结/`upd=1` 恢复 |
| SVA | `arbiter_wrr.sva`：参数检查、`gnt` 独热、`gnt_vld == OR(req_w)`、授权属于请求、`!gnt_vld \|\| !upd` 时 `ptr`/`credit` 保持、`gnt_vld && upd` 后 `ptr` 推进、`credit <= weight`；需 Verilator 5.x（`--assert -DSVA_ON`） |
| 仿真器 | iverilog 11/12 均通过；SVA 需 Verilator 5.x（`--assert -DSVA_ON`） |
| 未覆盖项 | `WEIGHT_W > 4` 的权重组合、运行期改权重、`req` 为 X/Z、门级/综合时序与面积、形式化验证 |

## 9. 微架构与数据流 [C]
- **模块划分**：单模块，无子模块；组合 credit 计算/扫描 + 两个 `dffr`（`credit`、`ptr`）。
- **框图**：

```text
                req[N]  weight[N*WEIGHT_W]
                  |          |
                  v          v
        +-----------------------------------+
        | req_w = req & (weight != 0)       |
        | no_credit = |req_w & ~|(req&credit)|
        | elig = req & (eff_credit != 0)    |
        +----------------+------------------+
                         |
                从 ptr 起循环扫描 elig
                         |
                  +------+------+
                  v             v
                gnt[N]       gnt_idx
             (独热)             |
                                v
                    nxt_ptr = gnt_idx+1（回绕）
                                |
        +----------------+------+------+
        | U_CREDIT dffr  |  U_PTR dffr  |   en = gnt_vld & upd
        | 每路 credit    |    ptr       |
        +----------------+-------------+
```

- **数据流**：
  - 有效请求：`req_w[i] = req[i] & (weight[i] != 0)`；`weight=0` 的请求被直接屏蔽。
  - credit 重装：`no_credit = (|req_w) & ~|(req & has_credit)`。当有加权请求但所有请求通道的 credit 都为 0 时，本轮耗尽，同拍以 `weight` 作为有效 credit（`eff_credit`），不插入空闲拍。
  - 授权：从 `ptr` 开始按 `(ptr+i)%N` 扫描，首个 `elig` 通道获得独热 `gnt`。
  - credit 更新：授权被消费（`gnt_vld & upd`）时授权通道 `credit-1`，其余通道在重装拍恢复为 `weight`；无授权或 `upd=0` 时全部保持。
  - 指针更新：授权被消费后 `ptr = gnt_idx+1`，保证同权重通道轮询。
- **关键寄存器/存储体**：

| 名称 | 用途 | 复位 | 更新条件（en） |
|---|---|---|---|
| `credit[N*WEIGHT_W]` | 每路本轮剩余授权额度 | `dffr` 复位 0 | `gnt_vld & upd` |
| `ptr` | 同权重扫描起始索引 | `dffr` 复位 0 | `gnt_vld & upd` |

- **关键设计决策**：用 credit 计数而不是展开权重队列，面积随 `N*WEIGHT_W` 线性增长；`no_credit` 在同拍完成重装，避免每轮空一拍；`credit` 只在授权时更新，空闲时 `en=0` 可被门控。权重为扁平分包，便于 `arbiter_wrapper` 直接透传。扫描索引 `ptr + i` 用 `SUM_W = IDX_W + 1` 位窄回绕，不做 32 位取模。

## 10. 状态机 [C]
不适用。模块只有 `ptr` 和 `credit` 两组寄存器，没有多步控制序列；轮次边界由组合 `no_credit` 判定，不引入 FSM 状态编码。

## 11. 时序、流水线与 PPA [C]
| 场景 | 延迟 | 吞吐 | 说明 |
|---|---|---|---|
| 正常授权 | 组合（0 拍） | 1 次授权/拍 | 含 credit 重装拍 |
| 全零权重 / 无有效请求 | 组合 | 0 | `gnt_vld=0`，寄存器保持 |

- **关键路径/流水线**：`credit/weight → no_credit → elig → 扫描 → gnt` 为组合路径；`N` 和 `WEIGHT_W` 越大路径越长，必要时在 `arbiter_wrapper` 外层用 `reg_slice` 切分。
- **反压路径**：无。仲裁核不感知下游 ready。
- **面积/功耗**：`N*WEIGHT_W` 个 credit 触发器 + `IDX_W` 个指针触发器；连续授权时 credit 每拍更新，空闲时 `en=0` 可门控。
- **取舍**：credit 方案换 0 拍延迟和可配置带宽；不做平滑整形，突发由使用方通过 `flow_shaper` 处理。

## 12. 风险与未覆盖项 [C]
- **风险**：权重动态变化可能破坏 `credit <= weight` 不变量；零权重通道被长期屏蔽属于预期语义。
- **限制**：单时钟；无背压；无平滑；权重位宽受参数限制。
- **未覆盖项**：`WEIGHT_W > 4`、运行期改权重、`req` 为 X/Z、门级仿真与综合时序/面积、形式化验证。

## 13. 版本记录 [M]
| 版本 | 日期 | 变更 | 兼容性 |
|---|---|---|---|
| `v0.1.1` | 2026-10-27 | 增加 `upd` 输入：仅在授权被消费时更新 `credit` / `ptr` | 端口不兼容 |
| `v0.1.0` | 2026-10-27 | 初版：credit 加权轮询 + 同权重指针轮询 | - |

## 14. 相关文档 [O]
- 待开发清单：[`cbb-list.md`](../cbb-list.md)
- 仲裁家族约束：[`cbb-list.md` §7.2](../cbb-list.md)
- 编码规范与模板：`my_env` 的 `rtl-developer` skill

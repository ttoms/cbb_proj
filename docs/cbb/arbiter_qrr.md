# arbiter_qrr CBB 文档（复杂件）

## 1. 基本信息 [M]
| 项 | 内容 |
|---|---|
| CBB ID | `CBB-ARB-005` |
| 模块名 | `arbiter_qrr` |
| 类别 | `arbiter` |
| 状态 | 已发布 |
| 版本 | `v0.1.1` |
| 维护人 | - |
| 更新时间 | 2026-10-27 |

## 2. 功能与范围 [M]
- **功能**：QoS 分级 + 轮询仲裁。先选出当前请求中的最高 QoS 组，再在组内用 `arbiter_rr` 轮询。
- **不包含**：不做加权、不做令牌桶、不做反压、不做运行期 QoS 调整。
- **典型场景**：带优先级的多个请求源共享单端口、`arbiter_wrapper` 的 `ARB_QRR` 分支。

## 3. 端口表 [M]
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟 |
| `rst_n` | input | 1 | `clk` | 异步复位、同步释放，低有效 |
| `upd` | input | 1 | `clk` | 当前 `gnt` 被消费；透传给内部 `arbiter_rr` |
| `req` | input | `N` | `clk` | 请求位图，每路 1 bit |
| `qos` | input | `N*QOS_W` | `clk` | 每路 QoS，扁平打包，第 `i` 路占 `qos[i*QOS_W +: QOS_W]`；数值越大优先级越高 |
| `gnt` | output | `N` | `clk` | 独热授权，最多一路有效 |
| `gnt_vld` | output | 1 | `clk` | 有请求时为 1，等价于 `OR(req)` |

无 valid-ready 握手；`gnt` 为组合输出，`req` 在授权周期内必须保持有效。

`upd` 表示“当前 `gnt` 已被下游消费”，透传给内部 `arbiter_rr`，只在 `gnt_vld & upd` 时推进组内轮询指针。`upd` 恒为 1 时退化为旧行为。`arbmux` / `strmux` 内部用输出 `vld & rdy` 握手生成该信号。

## 4. 参数表 [M]
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `N` | `int` | `4` | `N >= 1` | 请求路数 |
| `QOS_W` | `int` | `2` | `QOS_W >= 1` | 每路 QoS 位宽，QoS 范围 `0 ~ 2**QOS_W-1` |

参数约束：`N >= 1`、`QOS_W >= 1` 由 `arbiter_qrr.sva` 检查。

## 5. 使用说明 [M]
- **时钟/复位**：单时钟；`rst_n` 异步拉低、同步释放，建议由 `rst_sync` 产生。复位清内部 `arbiter_rr` 的轮询指针。
- **延迟/吞吐**：`req/qos → gnt` 纯组合；每拍最多一个授权，持续请求时 1 次授权/拍。
- **反压**：无。授权方（`arbmux` / `strmux`）负责在未握手时保持请求并处理反压。
- **初始化**：复位后最高 QoS 组内从索引 0 开始轮询。
- **upd 语义**：仅在 `gnt_vld & upd` 时推进组内指针；`upd=0` 时指针冻结。
- **限制**：高 QoS 持续请求会饿死低 QoS。

```systemverilog
arbiter_qrr #(
    .N     (4),
    .QOS_W (2)
) U_ARB (
    .clk     (clk),
    .rst_n   (rst_n),
    .upd     (upd),
    .req     (req),
    .qos     (qos),
    .gnt     (gnt),
    .gnt_vld (gnt_vld)
);
```

## 6. 复位与 CDC [M]
- **复位**：内部复用 `arbiter_rr`，其 `ptr` 为 `dffr` 异步复位到 0；本模块自身无额外寄存器。
- **CDC**：无。单时钟模块，所有逻辑同域。

## 7. 限制与注意 [M]
- 低 QoS 通道在高 QoS 持续请求时可能长期得不到授权，这是分级的预期语义；需要严格公平改用 `arbiter_rr` / `arbiter_wrr`。
- `qos` 视为静态配置；运行期改变 QoS 会立刻改变分组，轮询指针语义仍成立但历史公平性不再保证。
- 请求位图在授权周期内必须稳定；组合撤销请求可能导致 `gnt` 抖动。

## 8. 验证状态 [M]
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS（0 error） |
| 定向 TB | `tb/arbiter/arbiter_qrr_tb.sv` PASS：`N=1`、等 QoS `{1,1,1,1}`、混合 QoS `{3,1,2,0}`、双高 QoS `{2,0,2,0}` 四组，各跑 200 拍随机 scoreboard、最高 QoS 独占、低 QoS 回退、无请求、`upd=0` 冻结/`upd=1` 恢复；`tb/arbiter/arbiter_scale_tb.sv` 覆盖 `N=64/128` |
| SVA | `arbiter_qrr.sva`：参数检查、`gnt` 独热、`gnt_vld == OR(req)`、授权属于请求、授权只落在最高 QoS 组；指针稳定性由内部 `arbiter_rr.sva` 覆盖；需 Verilator 5.x（`--assert -DSVA_ON`） |
| 仿真器 | iverilog 11/12 均通过；SVA 需 Verilator 5.x（`--assert -DSVA_ON`） |
| 未覆盖项 | `QOS_W > 3`、运行期改 QoS、`req` 为 X/Z、门级/综合时序与面积、形式化验证 |

## 9. 微架构与数据流 [C]
- **模块划分**：本模块用 `max_tree` 求最高 QoS，组内仲裁直接例化 `arbiter_rr`，不重复实现轮询算法。
- **框图**：

```text
  req[N]  qos[N*QOS_W]
     |         |
     v         v
  +---------------------------+
  | max_tree 求最高 QoS         |--max_qos
  | req_hi = req & (qos==max)  |--req_hi[N]
  +-------------+-------------+
                |
        +-------v--------+
        | arbiter_rr     |----> gnt[N]（独热）
        | 组内指针轮询    |----> gnt_vld = |req_hi
        +----------------+
```

- **数据流**：
  - QoS 分组：`max_tree` 求请求中的最高 `qos`；再把 `qos` 等于最高值的请求拼成 `req_hi`。
  - 组内仲裁：`arbiter_rr` 对 `req_hi` 做指针轮询，授权被消费（`gnt_vld & upd`）后指针推进到下一路。
  - 输出：`gnt`、`gnt_vld` 直接来自 `arbiter_rr`；`gnt_vld` 恒等于 `OR(req)`（只要存在请求，最高组必非空）。
- **关键寄存器/存储体**：

| 名称 | 用途 | 复位 | 更新条件（en） |
|---|---|---|---|
| `U_RR.ptr` | 最高 QoS 组内轮询指针（one-hot） | `dffr` 复位 bit0 | 组内授权有效且 `upd=1` |

- **关键设计决策**：QoS 只做分组，不在组内引入第二套指针；复用 `arbiter_rr` 保证同 QoS 公平，也便于 `arbiter_wrapper` 统一维护。最高 QoS 用 `max_tree` 树形比较得到，深度 `O(log N)`，避免编码优先级表。

## 10. 状态机 [C]
不适用。模块由组合分组 + `arbiter_rr` 的指针寄存器组成，没有多步控制序列或状态编码。

## 11. 时序、流水线与 PPA [C]
| 场景 | 延迟 | 吞吐 | 说明 |
|---|---|---|---|
| 正常授权 | 组合（0 拍） | 1 次授权/拍 | 最高 QoS 比较 + RR 扫描 |
| 无请求 | 组合 | 0 | `gnt=0`，指针保持 |

- **关键路径/流水线**：`qos → max_tree → req_hi → arbiter_rr 树形轮询 → gnt`，两级均为 `O(log N)` 深度；不做流水。
- **反压路径**：无。仲裁核不感知下游 ready。
- **面积/功耗**：`max_tree` 的 `O(N)` 比较器 + `arbiter_rr` 的 `N` 位 one-hot 指针与优先级树；无请求时指针 `en=0`。
- **取舍**：两级结构清晰、复用 RR；代价是多一级组合延迟，低 QoS 可能饿死。

## 12. 风险与未覆盖项 [C]
- **风险**：高 QoS 持续请求时低 QoS 饿死；`qos` 动态变化会打乱历史公平性。
- **限制**：单时钟；无背压；无加权；QoS 位宽受参数限制。
- **未覆盖项**：`QOS_W > 3`、运行期改 QoS、`N > 8`、`req` 为 X/Z、门级仿真与综合时序/面积、形式化验证。

## 13. 版本记录 [M]
| 版本 | 日期 | 变更 | 兼容性 |
|---|---|---|---|
| `v0.1.1` | 2026-10-27 | 增加 `upd` 输入并透传给 `arbiter_rr` | 端口不兼容 |
| `v0.1.0` | 2026-10-27 | 初版：最高 QoS 分组 + `arbiter_rr` 组内轮询 | - |

## 14. 相关文档 [O]
- 待开发清单：[`cbb-list.md`](../cbb-list.md)
- 仲裁家族约束：[`cbb-list.md` §7.2](../cbb-list.md)
- 轮询核：[`arbiter_rr.md`](arbiter_rr.md)
- 编码规范与模板：`my_env` 的 `rtl-developer` skill

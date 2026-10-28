# arbiter_rr CBB 文档（复杂件）

## 1. 基本信息 [M]
| 项 | 内容 |
|---|---|
| CBB ID | `CBB-ARB-002` |
| 模块名 | `arbiter_rr` |
| 类别 | `arbiter` |
| 状态 | 已发布 |
| 版本 | `v0.1.1` |
| 维护人 | - |
| 更新时间 | 2026-10-27 |

## 2. 功能与范围 [M]
- **功能**：轮询（round-robin）仲裁，one-hot 指针 + 双优先级树，从指针位置开始轮询，输出独热授权。
- **不包含**：不做加权、不做 QoS 分组、不做授权寄存、不做背压；不处理请求撤销。
- **典型场景**：多通道公平共享单端口、`arbmux` / `strmux` 的默认仲裁核、轮询仲裁作为 `arbiter_wrapper` 的 `ARB_RR` 分支。

## 3. 端口表 [M]
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟 |
| `rst_n` | input | 1 | `clk` | 异步复位、同步释放，低有效 |
| `upd` | input | 1 | `clk` | 当前 `gnt` 被消费；仅此时推进 `ptr` |
| `req` | input | `N` | `clk` | 请求位图，每路 1 bit |
| `gnt` | output | `N` | `clk` | 独热授权，最多一路有效 |
| `gnt_vld` | output | 1 | `clk` | 有授权时为 1，等价于 `OR(req)` |

无 valid-ready 握手；`gnt` 为组合输出，`req` 在授权周期内必须保持有效。

`upd` 表示“当前 `gnt` 已被下游消费”，仲裁核只在 `gnt_vld & upd` 的时钟沿推进 `ptr`。`upd` 必须与消费当前 `gnt` 的那一拍对齐；`upd` 恒为 1 时退化为“每拍授权即推进”的旧行为。`arbmux` / `strmux` 内部用输出 `vld & rdy` 握手生成该信号。

## 4. 参数表 [M]
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `N` | `int` | `4` | `N >= 1` | 请求路数 |

参数约束：`N >= 1` 由 `arbiter_rr.sva` 检查；内部索引位宽 `IDX_W = (N > 1) ? $clog2(N) : 1` 自动派生。

## 5. 使用说明 [M]
- **时钟/复位**：单时钟；`rst_n` 异步拉低、同步释放，建议由 `rst_sync` 产生。复位后 `ptr` 为 one-hot 的 bit0，即索引 0 最先获得优先权。
- **延迟/吞吐**：`req → gnt` 纯组合；每拍最多一个授权，持续请求时 1 次授权/拍。
- **反压**：无。授权方（`arbmux` / `strmux`）负责在未握手时保持请求并处理反压。
- **初始化**：复位清 `ptr`；无请求或 `upd=0` 时不更新 `ptr`。
- **upd 语义**：`upd=1` 表示当前 `gnt` 被使用；仅在 `gnt_vld & upd` 时指针推进。若下游长期未消费授权，可保持 `upd=0` 冻结仲裁状态。
- **限制**：`gnt` 为组合输出；只做仲裁，不保证授权对应的数据通道已准备好。

```systemverilog
arbiter_rr #(
    .N (4)
) U_ARB (
    .clk     (clk),
    .rst_n   (rst_n),
    .upd     (upd),
    .req     (req),
    .gnt     (gnt),
    .gnt_vld (gnt_vld)
);
```

## 6. 复位与 CDC [M]
- **复位**：`ptr` 是控制类 one-hot 寄存器，用 `dffr` 异步复位到 bit0；无数据通路寄存器，无复位树开销。
- **CDC**：无。单时钟模块，所有逻辑同域。

## 7. 限制与注意 [M]
- 授权被消费（`gnt_vld & upd`）后 `ptr` 旋转到被授权索引的下一路，同一拍不能再改选，因此单拍只产生一个授权。
- `upd=0` 时授权可重复输出同一路，直到下游消费；这是有意的冻结语义，不是死锁。
- 请求位图在授权周期内必须稳定；组合撤销请求可能导致 `gnt` 抖动，需上游保证请求有效。
- `N=1` 时 `ptr` 恒为 bit0，`gnt_vld == req[0]`。
- 不做请求锁存；若上游请求是脉冲，需在 `arbiter` 外层用 `req` 保持寄存器。

## 8. 验证状态 [M]
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS（0 error） |
| 定向 TB | `tb/arbiter/arbiter_rr_tb.sv` PASS：`N=1/2/4` 各跑 200 拍随机 scoreboard、全请求轮询、单请求 + 指针推进、无请求保持、`upd=0` 冻结/`upd=1` 恢复；`tb/arbiter/arbiter_scale_tb.sv` 覆盖 `N=64/128` |
| SVA | `arbiter_rr.sva`：参数检查、`gnt` 独热、`gnt_vld == OR(req)`、授权属于请求、`ptr` 始终 one-hot、`!gnt_vld \|\| !upd` 时 `ptr` 保持、`gnt_vld && upd` 后 `ptr` 旋转到下一路；需 Verilator 5.x（`--assert -DSVA_ON`） |
| 仿真器 | iverilog 11/12 均通过；SVA 需 Verilator 5.x（`--assert -DSVA_ON`） |
| 未覆盖项 | `req` 为 X/Z 的行为、门级/综合时序与面积、形式化验证 |

## 9. 微架构与数据流 [C]
- **模块划分**：单模块；one-hot 指针 + 后缀 OR 掩码 + 两个 `pri_tree` + 一个 `dffr`。
- **框图**：

```text
  ptr(one-hot) --> 后缀 OR --> lower_mask
  req[N] --> req_hi = req & ~lower_mask --> pri_tree --> gnt_hi
         --> req_lo = req &  lower_mask --> pri_tree --> gnt_lo
  gnt = |gnt_hi ? gnt_hi : gnt_lo
  gnt --> rotate-left --> nxt_ptr --> U_PTR dffr (en = gnt_vld & upd)
```

- **数据流**：
  - 掩码：`lower_mask = 后缀OR(ptr) >> 1`，即“低于指针”的通道集合；`req_hi` 覆盖指针及其后，`req_lo` 覆盖回绕部分。
  - 选择：`pri_tree(req_hi)` 非零则取它（指针后最低索引），否则取 `pri_tree(req_lo)`（回绕后最低索引）。
  - 指针：消费拍 `ptr = rotate_left(gnt)`，one-hot 指针直接指向被授权索引的下一路；无授权或 `upd=0` 时保持。
  - 输出：`gnt` 来自两棵优先级树，`gnt_vld = |req`。
- **关键寄存器/存储体**：

| 名称 | 用途 | 复位 | 更新条件（en） |
|---|---|---|---|
| `ptr` | 下一轮优先起始指针（one-hot） | `dffr` 复位 bit0 | `gnt_vld & upd` |

- **关键设计决策**：用 one-hot 指针 + 后缀 OR + 双 `pri_tree`，避免线性扫描和取模；组合深度 `O(log N)`，指针面积 `N` 位、树面积 `O(N)`，N=64/128 可用。`upd` 把“仲裁”和“计费”解耦，使 mux 类使用方能在反压或 packet 锁定时冻结仲裁状态。

## 10. 状态机 [C]
不适用。模块只有一个指针寄存器，没有多步控制序列，也不存在非法状态编码；指针值域由窄位回绕保证始终合法。

## 11. 时序、流水线与 PPA [C]
| 场景 | 延迟 | 吞吐 | 说明 |
|---|---|---|---|
| 正常授权 | 组合（0 拍） | 1 次授权/拍 | `req → gnt` 组合路径 |
| 无请求 | 组合 | 0 | `ptr` 保持 |

- **关键路径/流水线**：`ptr → 后缀 OR → req_hi/req_lo → pri_tree → gnt` 为组合路径，深度 `O(log N)`；不做授权寄存，保持 0 拍延迟。
- **反压路径**：无。仲裁核不感知下游 ready。
- **面积/功耗**：`N` 位 one-hot 指针 + `O(N log N)` 后缀 OR + 两棵 `O(N)` 优先级树；无请求时 `ptr` 的 `en=0`，时钟可被门控。N=64/128 时面积仍是线性量级。
- **取舍**：用树形结构换 `O(log N)` 深度；指针用 one-hot 省掉二进制→独热译码和取模。

## 12. 风险与未覆盖项 [C]
- **风险**：组合 `gnt` 依赖 `req` 稳定；`req` 毛刺会直接传到 `gnt`。`upd` 若与消费拍错位，指针会多推或少推一拍，破坏公平性。
- **限制**：单时钟；无背压；无加权/QoS；面积随 N 线性增长，但深度只随 log N 增长。
- **未覆盖项**：`req` 为 X/Z 的仿真、门级仿真与综合时序/面积、形式化验证。

## 13. 版本记录 [M]
| 版本 | 日期 | 变更 | 兼容性 |
|---|---|---|---|
| `v0.1.1` | 2026-10-27 | 增加 `upd` 输入：仅在授权被消费时推进 `ptr` | 端口不兼容 |
| `v0.1.0` | 2026-10-27 | 初版：指针 + 循环扫描轮询仲裁 | - |

## 14. 相关文档 [O]
- 待开发清单：[`cbb-list.md`](../cbb-list.md)
- 仲裁家族约束：[`cbb-list.md` §7.2](../cbb-list.md)
- 编码规范与模板：`my_env` 的 `rtl-developer` skill

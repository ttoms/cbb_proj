# fifo_sync_af CBB 文档（复杂件）

> 状态：已发布。

## 1. 基本信息 [M]
| 项 | 内容 |
|---|---|
| CBB ID | `CBB-MEM-002` |
| 模块名 | `fifo_sync_af` |
| 类别 | `memory` |
| 状态 | 已发布 |
| 版本 | `v0.1.0` |
| 维护人 | - |
| 更新时间 | 2026-10-28 |

## 2. 功能与范围 [M]
- **功能**：在 `fifo_sync` 外增加占用计数，输出寄存型 `almost_full` / `almost_empty`，阈值由参数给定。
- **不包含**：不做 CDC；不提供运行期改阈值；不改变 `fifo_sync` 的读写语义；不对外输出 `count`（后续有需求再加）。
- **典型场景**：credit 流控、下游提前反压、DMA 水位管理、按水位触发调度。

## 3. 端口表 [M]
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟 |
| `rst_n` | input | 1 | `clk` | 异步复位、同步释放，低有效 |
| `wr_vld` | input | 1 | `clk` | 写有效，与 `wr_data` 同周期 |
| `wr_rdy` | output | 1 | `clk` | 写就绪，`~full` |
| `wr_data` | input | `DATA_W` | `clk` | 写数据 |
| `rd_vld` | output | 1 | `clk` | 读有效，`~empty` |
| `rd_rdy` | input | 1 | `clk` | 读就绪 |
| `rd_data` | output | `DATA_W` | `clk` | 读数据，组合来自 FIFO 存储体 |
| `empty` | output | 1 | `clk` | 空标志，寄存输出 |
| `full` | output | 1 | `clk` | 满标志，寄存输出 |
| `almost_full` | output | 1 | `clk` | 水位 `>= AF_THRESH`，寄存输出 |
| `almost_empty` | output | 1 | `clk` | 水位 `<= AE_THRESH`，寄存输出 |

valid-ready 约定继承 `fifo_sync`：`wr_en = wr_vld && wr_rdy`，`rd_en = rd_vld && rd_rdy`；`full=1` 时 `wr_rdy=0`，`empty=1` 时 `rd_vld=0`。

## 4. 参数表 [M]
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `DATA_W` | `int` | `32` | `DATA_W >= 1` | 数据位宽 |
| `DEPTH` | `int` | `16` | 2 的幂且 `>= 2` | FIFO 深度，继承 `fifo_sync` 约束 |
| `AF_THRESH` | `int` | `DEPTH-1` | `1 <= AF_THRESH <= DEPTH` | `count >= AF_THRESH` 时 `almost_full=1` |
| `AE_THRESH` | `int` | `1` | `0 <= AE_THRESH <= DEPTH-1` | `count <= AE_THRESH` 时 `almost_empty=1` |

参数约束：
- `DEPTH` 非 2 的幂或小于 2 属非法配置，由参数检查 SVA 报错。
- `AF_THRESH` / `AE_THRESH` 越界属非法配置，由参数检查 SVA 报错。
- `AF_THRESH <= AE_THRESH` 是合法配置，但两个标志可能同拍有效；通常属于配置错误，文档明确该行为，不在 RTL 中额外加严。

## 5. 使用说明 [M]
- **时钟/复位**：单时钟；`rst_n` 异步拉低、同步释放，建议由 `rst_sync` 产生。复位后 `count=0`、`almost_empty=1`、`almost_full=0`。
- **延迟/吞吐**：读写路径与 `fifo_sync` 完全一致，稳态 1 项/拍。`almost_full` / `almost_empty` 与 `full` / `empty` 同拍更新，均为寄存输出，反映本拍传输完成后的水位，比组合水位晚 1 拍。
- **反压**：`wr_rdy = ~full` 仍是唯一写反压；`almost_full` 只作预警，不自动拉低 `wr_rdy`。
- **初始化**：复位清 `count`、`entry_vld`、指针；`almost_empty` 复位为 1。
- **限制**：阈值为 elaboration 常量；不输出 `count`；水位标志为寄存输出，需要更早的组合预警时外部自行处理。

```systemverilog
fifo_sync_af #(
    .DATA_W    (DATA_W),
    .DEPTH     (DEPTH),
    .AF_THRESH (DEPTH-1),
    .AE_THRESH (1)
) U_FIFO_AF (
    .clk          (clk),
    .rst_n        (rst_n),
    .wr_vld       (wr_vld),
    .wr_rdy       (wr_rdy),
    .wr_data      (wr_data),
    .rd_vld       (rd_vld),
    .rd_rdy       (rd_rdy),
    .rd_data      (rd_data),
    .empty        (empty),
    .full         (full),
    .almost_full  (almost_full),
    .almost_empty (almost_empty)
);
```

## 6. 复位与 CDC [M]
- **复位**：`count`、`almost_full`、`almost_empty` 用 `dffr`；FIFO 内部指针与 `entry_vld` 由 `fifo_sync` 自己复位，存储体不复位。
- **CDC**：无。单时钟模块。

## 7. 限制与注意 [M]
- `almost_full` / `almost_empty` 是寄存输出，不能替代 `full` / `empty` 做精确满空判断。
- 阈值是参数，运行期不可改；需要动态水位时在外部对 `count` 做比较（本模块不对外提供 `count`）。
- `AF_THRESH <= AE_THRESH` 时两标志可同时为 1，属使用方配置问题。
- 深度仍要求 2 的幂，与 `fifo_sync` 一致。

## 8. 验证状态 [M]
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS（0 error） |
| 定向 TB | `tb/memory/fifo_sync_af_tb.sv` PASS（`DEPTH=4`、`AF_THRESH=3`、`AE_THRESH=1`；满/空、水位、同拍读写、满时写阻塞、排空） |
| SVA | `fifo_sync_af.sva`：参数检查 + 3 条断言；需 Verilator 5.x（`--assert -DSVA_ON`） |
| 仿真器 | iverilog 11 通过 |
| Verilator lint | `--lint-only -Wall` 0 warning |
| 未覆盖项 | 复位发生在传输中、非法阈值参数的参数检查路径、门级/综合时序与面积 |

## 9. 微架构与数据流 [C]
- **模块划分**：单个包装模块，例化 `fifo_sync U_FIFO`，外加 `U_CNT`、`U_AF`、`U_AE` 三个 `dffr` 和两个比较器。
- **框图**：

```text
wr_*  ---> +----------------+ ---> rd_*
           |   fifo_sync    | ---> empty / full
           |   U_FIFO       |
           +----------------+
             |  wr_en/rd_en（握手成立）
             v
        +---------+   nxt_cnt   +----------+
        | U_CNT   |------------>| >= AF_TH |
        | dffr    |             +----------+--> U_AF(dffr) --> almost_full
        | en=wr_en| rd_en       +----------+
        +---------+------------>| <= AE_TH |
                                +----------+--> U_AE(dffr) --> almost_empty
```

- **数据流**：FIFO 本体完全沿用 `fifo_sync`。`wr_en = wr_vld && wr_rdy`、`rd_en = rd_vld && rd_rdy`，`nxt_cnt = count + wr_en - rd_en`；比较器对 `nxt_cnt` 判断阈值，结果在同一个 `en = wr_en || rd_en` 下寄存，与 FIFO 的 `empty_q` / `full_q` 更新时机一致。
- **关键寄存器/存储体**：

| 名称 | 用途 | 复位 | 更新条件（en） |
|---|---|---|---|
| `count` | 当前占用量，`CNT_W = $clog2(DEPTH+1)` | `dffr` 复位 0 | `wr_en \| rd_en` |
| `almost_full_q` | 高水位标志 | `dffr` 复位 0 | `wr_en \| rd_en` |
| `almost_empty_q` | 低水位标志 | `dffr` 复位 1 | `wr_en \| rd_en` |

- **关键设计决策**：用包装而不是复制 `fifo_sync`，避免两份存储体/指针逻辑；用 `nxt_cnt` 而不是当前 `count` 做比较，保证与 `fifo_sync` 的寄存满空标志同拍；标志同样寄存输出，延续“full/empty 不用组合输出”的项目约束。

## 10. 状态机 [C]
不适用。模块只有计数器和比较器，没有多步控制序列。

## 11. 时序、流水线与 PPA [C]
| 场景 | 延迟 | 吞吐 | 说明 |
|---|---|---|---|
| 正常流 | 与 `fifo_sync` 相同 | 1 项/拍 | 读写路径未改动 |
| 水位标志 | 传输完成后 1 拍 | - | 与 `full` / `empty` 对齐 |

- **关键路径/流水线**：新增路径为 `count → +1/-1 → 比较 → dffr`，约 1 级加法 + 1 级比较；不进入 FIFO 的读数据 mux 路径。
- **反压路径**：没有新增反压路径；`wr_rdy` 仍由 `fifo_sync` 输出。
- **面积/功耗**：增加约 `$clog2(DEPTH+1) + 2` 个触发器、一个加减法器、两个比较器；相对 FIFO 存储体可忽略。
- **取舍**：用寄存标志换更干净的时序和与 `full/empty` 一致的行为；需要更早预警时由使用方提高阈值。

## 12. 风险与未覆盖项 [C]
- **风险**：`count` 依赖 `wr_en` / `rd_en` 与 `fifo_sync` 内部握手完全一致；若后续修改 `fifo_sync` 的握手定义，必须同步复核。
- **风险**：`DEPTH` 很大时计数器和比较器位宽随之增加，但仍是 `O(log DEPTH)`。
- **限制**：阈值不可运行期修改；不提供组合水位输出。
- **未覆盖项**：实现前未做任何仿真。

## 13. 版本记录 [M]
| 版本 | 日期 | 变更 | 兼容性 |
|---|---|---|---|
| `v0.1.0` | 2026-10-28 | 初版：架构 + 实现 + 定向 TB | - |

## 14. 相关文档 [O]
- 待开发清单：[`cbb-list.md`](../cbb-list.md)
- 基础模块：[`fifo_sync.md`](fifo_sync.md)

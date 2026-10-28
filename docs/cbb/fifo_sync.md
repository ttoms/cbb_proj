# fifo_sync CBB 文档（复杂件）

## 1. 基本信息 [M]
| 项 | 内容 |
|---|---|
| CBB ID | `CBB-MEM-001` |
| 模块名 | `fifo_sync` |
| 类别 | `memory` |
| 状态 | 已发布 |
| 版本 | `v0.1.0` |
| 维护人 | - |
| 更新时间 | 2026-10-27 |

## 2. 功能与范围 [M]
- **功能**：单时钟域同步 FIFO，valid-ready 握手，show-ahead 组合读，输出 `empty` / `full`。
- **不包含**：不做异步跨时钟；不提供 `count`、`almost_full` / `almost_empty`；不提供输出寄存读；不做存储体复位。
- **典型场景**：单时钟域内解耦上下游吞吐、跨模块缓冲、外设收发缓冲。

## 3. 端口表 [M]
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟 |
| `rst_n` | input | 1 | `clk` | 异步复位、同步释放，低有效 |
| `wr_vld` | input | 1 | `clk` | 写有效，与 `wr_data` 同周期 |
| `wr_rdy` | output | 1 | `clk` | 写就绪，`~full` |
| `wr_data` | input | `DATA_W` | `clk` | 写数据 |
| `rd_vld` | output | 1 | `clk` | 读有效，`~empty` |
| `rd_rdy` | input | 1 | `clk` | 读就绪，由下游给出 |
| `rd_data` | output | `DATA_W` | `clk` | 读数据，组合来自 `mem[rd_ptr]` |
| `empty` | output | 1 | `clk` | 空标志，`entry_vld` 全 0 |
| `full` | output | 1 | `clk` | 满标志，`&entry_vld` |

valid-ready 约定：`wr_vld` / `rd_vld` 与数据同周期，`vld` 不依赖 `rdy`；写握手 `wr_en = wr_vld && wr_rdy`，读握手 `rd_en = rd_vld && rd_rdy`；`full=1` 时 `wr_rdy=0`，`empty=1` 时 `rd_vld=0`。

## 4. 参数表 [M]
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `DATA_W` | `int` | `32` | `DATA_W >= 1` | 数据位宽 |
| `DEPTH` | `int` | `16` | 2 的幂且 `>= 2` | 条目数 |

参数约束：`DEPTH` 非 2 的幂或小于 2 时，由 `fifo_sync.sva` 的参数检查报错；指针位宽 `PTR_W = $clog2(DEPTH)`。RTL 内不含 `$error`/`$fatal`，参数检查只在 `SVA_ON` 下编译。

## 5. 使用说明 [M]
- **时钟/复位**：单时钟；`rst_n` 异步拉低、同步释放，建议由 `rst_sync` 产生。复位清 `wr_ptr` / `rd_ptr` / `entry_vld`，不清 `mem`。
- **延迟/吞吐**：写握手成立后，数据与 `entry_vld` 在下一拍对读侧可见（写 1 拍可见）；`rd_data` 与 `rd_vld` 同拍组合有效（读 0 拍）。稳态 1 项/拍。
- **反压**：`wr_rdy = ~full`、`rd_vld = ~empty` 均为组合输出；不丢数、不重复、不产生假 valid。`full` 时同拍读出的空位不能用于当拍写入，写握手需等下一拍。
- **初始化**：复位后 `entry_vld=0`、`empty=1`、`full=0`、`wr_ptr=rd_ptr=0`。
- **限制**：不支持运行期改 `DEPTH` / `DATA_W`；不支持非 2 的幂深度。

```systemverilog
fifo_sync #(
    .DATA_W (DATA_W),
    .DEPTH  (DEPTH)
) U_FIFO (
    .clk      (clk),
    .rst_n    (rst_n),
    .wr_vld   (wr_vld),
    .wr_rdy   (wr_rdy),
    .wr_data  (wr_data),
    .rd_vld   (rd_vld),
    .rd_rdy   (rd_rdy),
    .rd_data  (rd_data),
    .empty    (empty),
    .full     (full)
);
```

## 6. 复位与 CDC [M]
- **复位**：`rst_n` 异步复位、同步释放。控制类状态 `wr_ptr`、`rd_ptr`、`entry_vld` 用 `dffr` 复位为 0；存储体 `mem` 用无复位 `dff`，节省复位树。`mem` 只在对应 `entry_vld` 为 1 时可被读出，未写过的条目不会出现在 `rd_data` 有效窗口。
- **CDC**：无。单时钟模块，`mem` 与全部状态寄存器同域。

## 7. 限制与注意 [M]
- 仅支持 2 的幂深度；非 2 的幂深度需外部向上取整或改用其他 FIFO。
- `rd_data` 为组合读，不寄存；`DEPTH` 较大时读 mux 可能成为关键路径，需要寄存输出时外接 `dff`。
- `full` 时同拍读取腾出的条目不能在当拍写入（`wr_rdy` 仍为 0），满边界有一次吞吐气泡。
- 无 `count` / almost 标志；流控需由上下游自行维护余量。
- 单时钟全同步，不提供跨时钟能力。

## 8. 验证状态 [M]
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS（0 error） |
| 定向 TB | `tb/memory/fifo_sync_tb.sv` PASS（`DEPTH=2`：满/空边界、满时写阻塞、指针回绕、写满后读空、同拍读写条目数不变、数据顺序）；随机 scoreboard TB 覆盖 `DEPTH=4/8`、`DATA_W=1/16`（本地，未入库） |
| SVA | `fifo_sync.sva` 参数检查 + 3 条并发断言；需 Verilator 5.x（`--assert -DSVA_ON`） |
| 仿真器 | iverilog 11/12 均通过；SVA 需 Verilator 5.x |
| 未覆盖项 | 复位发生在传输中、非法 `DEPTH` 的参数检查未跑（仅验证合法参数路径）、`rd_data` 读 mux 时序、门级/综合面积 |

## 9. 微架构与数据流 [C]
- **模块划分**：内部例化 `U_WR_PTR` / `U_RD_PTR` / `U_ENTRY_VLD` / `U_EMPTY` / `U_FULL` 五个 `dffr`、两个 `bin2ohot`（指针 → 独热）以及 `gen_mem[i].U_MEM` 共 `DEPTH` 个无复位 `dff`。
- **框图**：

```text
             +--------------------------------------------------+
  wr_data -->| gen_mem[i].U_MEM : dff[DATA_W]                   |
  wr_vld  -->|   en = wr_en && wr_oh[i]                          |----> rd_data
  wr_rdy  <--|                                                  |   (mem[rd_ptr] 组合选择)
             | U_WR_PTR : dffr[PTR_W]  en=wr_en                 |
             | U_RD_PTR : dffr[PTR_W]  en=rd_en                 |
             | U_WR_OH / U_RD_OH : bin2ohot(ptr) -> wr_oh/rd_oh |
  rd_vld  <--| U_ENTRY_VLD : dffr[DEPTH] en=(wr_en | rd_en)     |
  rd_rdy  -->|   nxt_entry_vld = (entry & ~rd_mask) | wr_mask     |
             | U_EMPTY / U_FULL : dffr, en=(wr_en | rd_en)      |
  full    <--|   q = &nxt_entry_vld                            |
  empty   <--|   q = ~|nxt_entry_vld                           |
             +--------------------------------------------------+
```

- **数据流**：写侧在 `wr_en` 时把 `wr_data` 写入 `mem[wr_ptr]`（`mem` 是 packed 二维数组 `[DEPTH-1:0][DATA_W-1:0]`），同时置位 `entry_vld[wr_ptr]` 并推进 `wr_ptr`；读侧 `rd_data` 组合选择 `mem[rd_ptr]`，`rd_en` 时清 `entry_vld[rd_ptr]` 并推进 `rd_ptr`。`entry_vld` 的更新用独热掩码：`(entry_vld & ~rd_mask) | wr_mask`，同拍命中同一项时写优先；`wr_mask` / `rd_mask` 由 `bin2ohot` 把指针译码成独热，避免每项一个比较器；`full` / `empty` 由 `nxt_entry_vld` 译码后寄存，输出不再直接组合译码。
- **关键寄存器/存储体**：

| 名称 | 用途 | 复位 | 更新条件（en） |
|---|---|---|---|
| `mem` | 数据存储体，packed `[DEPTH-1:0][DATA_W-1:0]` | 不复位（`dff`） | 每项 `wr_en && wr_oh[i]` |
| `entry_vld` | 每项有效位 | 复位为 0（`dffr`） | `wr_en \| rd_en` |
| `wr_ptr` | 写指针 | 复位为 0（`dffr`） | `wr_en` |
| `rd_ptr` | 读指针 | 复位为 0（`dffr`） | `rd_en` |
| `wr_oh` / `rd_oh` | 指针独热 | 组合（`bin2ohot`） | 跟随 `wr_ptr` / `rd_ptr` |
| `empty_q` | 空标志 | 复位为 1（`dffr`） | `wr_en \| rd_en` |
| `full_q` | 满标志 | 复位为 0（`dffr`） | `wr_en \| rd_en` |

- **关键设计决策**：`full` / `empty` 由 `nxt_entry_vld` 译码后寄存，切断 `entry_vld → full/empty → wr_rdy/rd_vld` 的组合路径；寄存值与 `entry_vld` 同一拍更新，所以读写时序与组合译码版本一致。`DEPTH` 限制为 2 的幂，指针自然回绕；读采用 show-ahead，读延迟 0 拍。`rd_ptr` 与 `wr_ptr` 指向同一条目只可能发生在全满（此时 `wr_rdy=0` 禁止写）或全空（此时 `rd_vld=0` 禁止读），因此不存在同拍同地址读写冲突；`nxt_entry_vld` 用独热掩码组合，保证万一同拍命中同一项时写入优先。

## 10. 状态机 [C]
不适用。模块是纯数据流结构，没有多步控制序列；`full` / `empty` 由 `nxt_entry_vld` 译码后寄存，指针只在握手成立时推进，不需要 FSM，也不存在非法状态编码。

## 11. 时序、流水线与 PPA [C]
| 场景 | 延迟 | 吞吐 | 说明 |
|---|---|---|---|
| 正常读写 | 写 1 拍可见；读 0 拍 | 1 写 + 1 读/拍 | `rd_data` 与 `rd_vld` 同拍 |
| 空 | 读阻塞 | 0 读/拍 | `rd_vld=0`，写侧不受影响 |
| 满 | 写阻塞 | 0 写/拍 | `wr_rdy=0`，读侧不受影响 |
| 满且同拍读 | 写被拒 | 1 读/拍 | 腾出的条目下一拍才可写 |
| 非满非空同拍读写 | - | 1 写 + 1 读/拍 | `entry_vld` 位数不变 |

- **关键路径/流水线**：`entry_vld -> 与/或归约 -> full/empty -> wr_rdy/rd_vld` 为组合路径；`rd_ptr -> mem 读 mux -> rd_data` 为 `DEPTH:1` 组合选择，`DEPTH` 大时是主要延迟来源。无流水线，需要时可外接 `dff` 寄存读数据。
- **反压路径**：`full -> wr_rdy` 与 `empty -> rd_vld` 均组合，无反压寄存、无 skid buffer。
- **面积/功耗**：主要面积是 `DEPTH x DATA_W` 个 `dff`；控制部分为 `DEPTH` 位 `entry_vld` 与 `2 x PTR_W` 位指针。所有寄存器均有显式 `en`：存储体每项独立写使能，只有被写条目翻转，便于插 ICG；数据通路不复位，减小复位树。
- **取舍**：`entry_vld` 方案比“指针附加位 + count”多 `DEPTH` 位触发器，但省掉计数器比较并让 `full/empty` 更直观；show-ahead 省一级输出寄存，代价是组合读 mux。

## 12. 风险与未覆盖项 [C]
- **风险**：`full` 时同拍读不能补写，满边界存在吞吐气泡；`DEPTH` 较大时 `entry_vld` 归约和读 mux 延迟上升；`DEPTH` 参数非法时依赖 `fifo_sync.sva` 的参数检查，未定义 `SVA_ON` 时不会报错，需在集成时保证参数合法。
- **限制**：2 的幂深度；单时钟；无几乎满/空标志；无 `count`；`mem` 不复位，依赖 `entry_vld` 保证不读出未写数据。
- **未覆盖项**：复位发生在读写传输中的行为、`rd_data` 读 mux 的时序/面积、门级仿真与综合结果。

## 13. 版本记录 [M]
| 版本 | 日期 | 变更 | 兼容性 |
|---|---|---|---|
| `v0.1.0` | 2026-10-27 | 初版：`entry_vld` + `dffr` 指针 + `dff` 存储体的同步 FIFO | - |

## 14. 相关文档 [O]
- 待开发清单：[`cbb-list.md`](../cbb-list.md)
- 编码规范与模板：`my_env` 的 `rtl-developer` skill

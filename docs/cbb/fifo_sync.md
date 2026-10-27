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
- **功能**：单时钟同步 FIFO，valid-ready 握手，show-ahead 读，输出 `full` / `empty` / `count`。
- **不包含**：不做异步跨时钟；不做 almost_full / almost_empty；不做首字直通（fall-through）以外的读模式；不做数据通路寄存（`rd_data` 为组合输出）。
- **典型场景**：单时钟域内解耦上下游吞吐、跨模块缓冲、AXI-Lite / UART 等外设的收发缓冲。

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
| `full` | output | 1 | `clk` | 满标志，`count == DEPTH` |
| `empty` | output | 1 | `clk` | 空标志，`count == 0` |
| `count` | output | `$clog2(DEPTH+1)` | `clk` | 当前条目数 |

valid-ready 约定：`wr_vld` / `rd_vld` 与数据同周期；`vld` 不依赖 `rdy`；写握手 `wr_fire = wr_vld && wr_rdy`，读握手 `rd_fire = rd_vld && rd_rdy`。

## 4. 参数表 [M]
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `DATA_W` | `int` | `32` | `DATA_W >= 1` | 数据位宽 |
| `DEPTH` | `int` | `16` | 2 的幂且 `>= 2` | 条目数 |

参数约束：`DEPTH` 非 2 的幂或小于 2 时，elaboration 阶段 `$error` 报错；指针位宽 `PTR_W = $clog2(DEPTH)`，计数位宽 `CNT_W = $clog2(DEPTH+1)`。

## 5. 使用说明 [M]
- **时钟/复位**：单时钟；`rst_n` 异步拉低、同步释放，建议由 `rst_sync` 产生。复位清空指针与 `count`，不清 `mem`。
- **延迟/吞吐**：写入在 `clk` 上升沿生效，下一拍可读；`rd_data` 在 `rd_vld=1` 的同一拍组合有效（show-ahead），读出本身 0 拍。稳态 1 项/拍，满或空时为 0。
- **反压**：`wr_rdy = ~full` 组合给出；`full=1` 时写握手被拒绝。`rd_vld = ~empty` 组合给出；下游用 `rd_rdy` 反压。不丢数、不重复、不产生假 valid。
- **初始化**：复位后 `count=0`、`empty=1`、`full=0`、`wr_ptr=rd_ptr=0`。
- **限制**：不支持运行期改 `DEPTH` / `DATA_W`；`rd_data` 为组合读，`DEPTH` 较大时需关注读 mux 延迟。

```systemverilog
fifo_sync #(
    .DATA_W (DATA_W),
    .DEPTH  (DEPTH)
) U_FIFO (
    .clk     (clk),
    .rst_n   (rst_n),
    .wr_vld  (wr_vld),
    .wr_rdy  (wr_rdy),
    .wr_data (wr_data),
    .rd_vld  (rd_vld),
    .rd_rdy  (rd_rdy),
    .rd_data (rd_data),
    .full    (full),
    .empty   (empty),
    .count   (count)
);
```

## 6. 复位与 CDC [M]
- **复位**：`rst_n` 异步复位、同步释放；复位 `wr_ptr`、`rd_ptr`、`count_q`；`mem` 不复位（只在非空时被读，未写过的条目不会输出）。
- **CDC**：无。单时钟模块，`mem` 与全部状态寄存器同域。

## 7. 限制与注意 [M]
- 仅支持 2 的幂深度；需要非 2 的幂深度时先用深度向上取整，或用 `count` 做外部限制。
- `rd_data` 为组合读，不寄存；需要在读出侧打拍时外接 `dff` 或 `reg_slice`。
- 无 almost_full / almost_empty，流控需用 `count` 自行判断。
- 单时钟全同步，不提供跨时钟能力。

## 8. 验证状态 [M]
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS（0 error） |
| 定向 TB | `tb/memory/fifo_sync_tb.sv` PASS（DEPTH=2 边界、满/空、指针回绕、同时读写、`count`） |
| SVA | 未跑 |
| 仿真器 | iverilog 12.0 |
| 未覆盖项 | `DEPTH` 大于 2 的随机压力、复位发生在传输中的场景、`rd_data` 读 mux 时序 |

## 9. 微架构与数据流 [C]
- **模块划分**：单模块，无子模块。存储体 `mem`、写指针 `wr_ptr`、读指针 `rd_ptr`、条目计数 `count_q`。
- **框图**：

```text
             +--------------------------------------+
  wr_data -->| mem[DEPTH][DATA_W]                   |
  wr_vld  -->|   wr_fire: mem[wr_ptr] <= wr_data    |----> rd_data
  wr_rdy  <--|   wr_ptr++                            |      (组合读 mem[rd_ptr])
             |                                      |
  rd_vld  <--| count_q != 0                         |
  rd_rdy  -->|   rd_fire: rd_ptr++                  |
             |                                      |
  full    <--| count_q == DEPTH                     |
  empty   <--| count_q == 0                         |
  count   <--| count_q                              |
             +--------------------------------------+
```

- **数据流**：写侧 `wr_data` 在 `wr_fire` 时写入 `mem[wr_ptr]` 并推进 `wr_ptr`；读侧 `rd_data` 组合选择 `mem[rd_ptr]`，`rd_fire` 时推进 `rd_ptr`；`count_q` 按 `{wr_fire, rd_fire}` 加一/减一/保持。
- **关键寄存器/存储体**：

| 名称 | 用途 | 复位 | 更新条件 |
|---|---|---|---|
| `mem` | 数据存储体 | 不复位 | `wr_fire` |
| `wr_ptr` | 写指针 | 复位为 0 | `wr_fire` |
| `rd_ptr` | 读指针 | 复位为 0 | `rd_fire` |
| `count_q` | 条目计数 | 复位为 0 | 每拍按握手更新 |

- **关键设计决策**：用 `count` 判满/空，而非指针附加位比较，逻辑直观、边界不易出错；代价是多一组计数器。`DEPTH` 限制为 2 的幂，使指针自然回绕、无需取模。读采用 show-ahead，省去输出寄存，读侧延迟 0 拍。`wr_ptr == rd_ptr` 只出现在 `count=0` 或 `count=DEPTH`，此时 `wr_fire` 与 `rd_fire` 不会同拍发生，因此不存在同地址同拍读写冲突。

## 10. 状态机 [C]
不适用。模块是纯数据流 + 指针/计数状态，没有多步控制序列；`full` / `empty` 由 `count_q` 直接译码，不需要 FSM。

## 11. 时序、流水线与 PPA [C]
| 场景 | 延迟 | 吞吐 | 说明 |
|---|---|---|---|
| 正常读写 | 写 1 拍可见；读 0 拍 | 1 项/拍 | `rd_data` 与 `rd_vld` 同拍 |
| 满 | 写阻塞 | 0 项/拍（写） | `wr_rdy=0`，读侧不受影响 |
| 空 | 读阻塞 | 0 项/拍（读） | `rd_vld=0`，写侧不受影响 |
| 同拍读写 | - | 1 写 + 1 读 | `count` 保持不变 |

- **关键路径**：`count_q` 比较 → `full` / `empty` → `wr_rdy` / `rd_vld`，为组合路径；`rd_data` 为 `DEPTH:1` 的组合 mux，`DEPTH` 大时是主要延迟来源。
- **反压路径**：`full → wr_rdy` 与 `empty → rd_vld` 均组合，无反压寄存，也不含 skid。
- **面积/功耗**：主要面积为 `mem`（`DEPTH × DATA_W`）与 `count_q`；无 ICG、无操作数隔离。入口处可外加 `clkgate` 降低空转功耗。
- **取舍**：用 `count` 和组合读换取逻辑简单与 0 拍读延迟；若需要低延迟 + 高频，可在读侧加 `reg_slice` 或改为输出寄存 FIFO。

## 12. 风险与未覆盖项 [C]
- **风险**：`DEPTH` 较大时组合读 mux 可能成为关键路径；`count` 位宽随 `DEPTH` 增长，比较逻辑同步变宽。
- **限制**：2 的幂深度；单时钟；无 almost 标志；`mem` 不复位，依赖“非空才读”保证不输出未写数据。
- **未覆盖项**：复位发生在读写传输中的行为、`DEPTH > 2` 的随机压力、`DATA_W=1` 边界、门级时序与综合面积。

## 13. 版本记录 [M]
| 版本 | 日期 | 变更 | 兼容性 |
|---|---|---|---|
| `v0.1.0` | 2026-10-27 | 初版：show-ahead 同步 FIFO，`full` / `empty` / `count` | - |

## 14. 相关文档 [O]
- 待开发清单：[`cbb-list.md`](../cbb-list.md)
- 后续增强：`fifo_sync_af`（almost 标志）

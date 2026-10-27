# reg_slice CBB 文档（复杂件）

## 1. 基本信息 [M]
| 项 | 内容 |
|---|---|
| CBB ID | `CBB-STREAM-002` |
| 模块名 | `reg_slice` |
| 类别 | `stream` |
| 状态 | 已发布 |
| 版本 | `v0.1.0` |
| 维护人 | - |
| 更新时间 | 2026-10-27 |

## 2. 功能与范围 [M]
- **功能**：可配置 valid-ready 打拍切片，用 2 bit `RS_MODE` 选择 bypass / forward / backward / full 四种模式。
- **不包含**：不做位宽转换、不解析 packet 边界、不做 CDC、不做多路仲裁；`RS_BACKWARD` 就是 `skid_buffer`，不再单独提供模块。
- **典型场景**：长组合路径前向打拍、反压路径打拍、模块边界解耦、`arbmux` / `strmux` 内部的输入输出切片。

## 3. 端口表 [M]
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟 |
| `rst_n` | input | 1 | `clk` | 异步复位、同步释放，低有效 |
| `in_vld` | input | 1 | `clk` | 上游 valid，与 `in_data` 同周期 |
| `in_rdy` | output | 1 | `clk` | 上游 ready |
| `in_data` | input | `W` | `clk` | 上游数据 |
| `out_vld` | output | 1 | `clk` | 下游 valid，与 `out_data` 同周期 |
| `out_rdy` | input | 1 | `clk` | 下游 ready |
| `out_data` | output | `W` | `clk` | 下游数据 |

valid-ready 约定：`vld` 与 `data` 同周期，`vld` 不依赖 `rdy`；传输成立条件为 `vld && rdy`；任何模式下都不丢数、不重复、不制造假 valid。

## 4. 参数表 [M]
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `W` | `int` | `32` | `W >= 1` | 数据位宽 |
| `RS_MODE` | `logic [1:0]` | `2'b11` | `00` / `01` / `10` / `11` | 切片模式 |

| `RS_MODE` | 编码 | 前向路径 | 反向路径 | 延迟 | 说明 |
|---|---:|---|---|---|---|
| `RS_BYPASS` | `2'b00` | 组合直通 | 组合直通 | 0 拍 | 面积最小，只用于时序允许的场景 |
| `RS_FORWARD` | `2'b01` | 打拍 | 组合直通 | 1 拍 | 只切前向路径 |
| `RS_BACKWARD` | `2'b10` | 组合直通 + skid 表项 | 打拍 | 稳态 0 拍，反压吸收 1 拍 | 即 `skid_buffer` |
| `RS_FULL` | `2'b11` | 打拍 | 打拍 | 1 拍 | 双向切断，内部 2 表项保持吞吐 |

参数约束：`W >= 1` 由 `reg_slice.sva` 检查；2 bit 编码 `00`~`11` 全部合法，不存在非法编码，`default` 分支按 `RS_FULL` 防御。

## 5. 使用说明 [M]
- **时钟/复位**：单时钟；`rst_n` 异步拉低、同步释放，建议由 `rst_sync` 产生。复位清 valid / skid / 指针，不清数据寄存器。
- **延迟/吞吐**：`RS_BYPASS` 0 拍；`RS_FORWARD` / `RS_FULL` 1 拍；`RS_BACKWARD` 稳态 0 拍。四种模式在下游持续 ready 时均为 1 项/拍。
- **反压**：`RS_BYPASS` 的 `in_rdy` 直接由 `out_rdy` 驱动；`RS_FORWARD` 的 `in_rdy = ~vld_q | out_rdy`；`RS_BACKWARD` 用 skid 表项吸收 1 项后拉低 `in_rdy`；`RS_FULL` 满时拉低 `in_rdy`，读走一项后下一拍恢复写入。
- **初始化**：复位后所有 valid 为 0；`RS_FULL` 的 `entry_vld=0`，读写指针为 0。
- **限制**：不感知 packet 边界；`RS_BYPASS` 不能作为默认配置；`in_rdy` 为组合或寄存器输出，具体见第 9 章。

```systemverilog
reg_slice #(
    .W       (DATA_W),
    .RS_MODE (2'b11)
) U_SLICE (
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
- **复位**：`dffr` 复位 valid、skid valid、`entry_vld` 和读写指针；`dff` 保存数据、不复位，复位期间不会被 `out_vld` 选中。
- **CDC**：无。单时钟模块，所有寄存器同域。

## 7. 限制与注意 [M]
- 模式只能在参数 `RS_MODE` 中选择，运行期不可切换。
- `RS_BYPASS` 完全不切时序，长路径场景不能使用。
- `RS_BACKWARD` 在 skid 表项占用期间 `in_rdy=0`，上游会出现一拍气泡；输出侧吞吐不受影响。
- `RS_FULL` 满且同拍读时，写握手需等下一拍；2 表项保证输出侧不出现气泡。
- 不做 packet 边界保持；若用于 packet 流，packet 内不能插入无关 flit。

## 8. 验证状态 [M]
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS（0 error） |
| 定向 TB | `tb/stream/reg_slice_tb.sv` PASS：四种模式各跑延迟检查 + 400 拍随机 scoreboard + 排空；覆盖随机反压、同拍读写、skid 吸收 |
| SVA | `reg_slice.sva` 参数检查（`W >= 1`）；SVA 需 Verilator 5.x（`--assert -DSVA_ON`） |
| 仿真器 | iverilog 12.0 PASS；Verilator 5.020（`--assert -DSVA_ON`）PASS |
| 未覆盖项 | `W > 8` 的位宽组合、`RS_MODE` 为 X/Z 的行为、门级/综合时序与面积、形式化验证 |

## 9. 微架构与数据流 [C]
- **模块划分**：单模块，`generate case (RS_MODE)` 分四个分支，无子模块；分支内例化 `dff` / `dffr`。
- **框图**：

```text
RS_BYPASS:
  in_vld  ------------------------------> out_vld
  in_data ------------------------------> out_data
  in_rdy  <------------------------------ out_rdy

RS_FORWARD:
  in_vld --> U_VLD(dffr) --vld_q-------> out_vld
  in_data -> U_DATA(dff) --data_q------> out_data
  in_rdy  <-- (~vld_q | out_rdy)

RS_BACKWARD:
  in_vld  --------------------------\
                                     +--> out_vld
  skid_vld ------------------------/
  in_data --\                       \
             +--> mux --------------> out_data
  skid_data/         ^
                     |
  in_rdy <-- ~skid_vld
  cap = in_vld & in_rdy & ~out_rdy  --> U_SKID_VLD/U_SKID_DATA

RS_FULL (2 表项):
  in_data --> U_MEM0(dff) --\
                            +--> mux --> out_data
  in_data --> U_MEM1(dff) --/     ^
                                  |
                              rd_ptr(dffr)
  U_ENTRY_VLD(dffr[2]) --> full/empty --> in_rdy/out_vld
  U_WR_PTR(dffr) / U_RD_PTR(dffr)
```

- **数据流**：
  - `RS_BYPASS`：输入直连输出。
  - `RS_FORWARD`：输入握手时 `vld_q/data_q` 打拍；下游 ready 时可在同一拍替换表项，保持 1 项/拍。
  - `RS_BACKWARD`：skid 空时输入直通输出；下游不 ready 时把当前输入存入 skid，随后 `in_rdy` 拉低；skid 占用时输出选 skid 数据，消费后释放。
  - `RS_FULL`：2 表项环形缓冲；写入按 `wr_ptr` 选择 `mem0/mem1` 并使能对应 `entry_vld` 位，读出按 `rd_ptr` 选择 `mem0/mem1`。`full=&entry_vld`，`empty=~|entry_vld`。
- **关键寄存器/存储体**：

| 名称 | 用途 | 复位 | 更新条件（en） |
|---|---|---|---|
| `vld_q` | `RS_FORWARD` 输出 valid | `dffr` 复位 0 | `in_fire \| out_fire` |
| `data_q` | `RS_FORWARD` 输出数据 | `dff` 不复位 | `in_fire` |
| `skid_vld` | `RS_BACKWARD` skid 有效 | `dffr` 复位 0 | `cap \| (out_fire & skid_vld)` |
| `skid_data` | `RS_BACKWARD` skid 数据 | `dff` 不复位 | `cap` |
| `entry_vld[2]` | `RS_FULL` 每项有效 | `dffr` 复位 0 | `wr_en \| rd_en` |
| `wr_ptr` / `rd_ptr` | `RS_FULL` 读写指针 | `dffr` 复位 0 | `wr_en` / `rd_en` |
| `mem0` / `mem1` | `RS_FULL` 2 表项数据 | `dff` 不复位 | `wr_en & ~wr_ptr` / `wr_en & wr_ptr` |

- **关键设计决策**：`RS_BACKWARD` 的 `in_rdy=~skid_vld` 直接来自寄存器，切断 `out_rdy → in_rdy` 组合路径；skid 只在 `in_fire & ~out_rdy` 时写入，避免同拍直通时重复入队。`RS_FULL` 用 2 表项而不是单表项，保证下游恢复后输出侧仍为 1 项/拍；`entry_vld` 有效位直接译码 full/empty，省去计数器。各模式的数据寄存器均不复位，控制寄存器用 `dffr`，与项目寄存器规范一致。

## 10. 状态机 [C]
不适用。模块是纯数据流结构，没有多步控制序列；`RS_FULL` 的读写指针和 `entry_vld` 只是环形缓冲状态，不是 FSM，也不存在非法状态编码。

## 11. 时序、流水线与 PPA [C]
| 模式 | 延迟 | 吞吐 | 前向路径 | 反向路径 |
|---|---|---|---|---|
| `RS_BYPASS` | 0 拍 | 1 项/拍 | 组合 | 组合 |
| `RS_FORWARD` | 1 拍 | 1 项/拍 | 打拍 | 组合 |
| `RS_BACKWARD` | 稳态 0 拍；反压吸收 1 拍 | 输出 1 项/拍 | 组合 + skid | 打拍（`in_rdy` 来自寄存器） |
| `RS_FULL` | 1 拍 | 1 项/拍 | 打拍 | 打拍 |

- **关键路径/流水线**：`RS_BYPASS` 的路径完全透明；`RS_FORWARD` 前向只有一级寄存器，`out_rdy → in_rdy` 为组合反压；`RS_BACKWARD` 前向有 `in_data → mux → out_data` 组合路径，反向被 skid 寄存器切断；`RS_FULL` 两侧均由寄存器驱动，关键路径是 `entry_vld` 归约与 2:1 读 mux。
- **反压路径**：`RS_FORWARD` 组合反压；`RS_BACKWARD` / `RS_FULL` 均为寄存反压，不在 `out_rdy` 与 `in_rdy` 之间形成组合路径。
- **面积/功耗**：`RS_BYPASS` 仅连线；`RS_FORWARD` 约 `W+1` 个触发器；`RS_BACKWARD` 约 `W+1` 个触发器；`RS_FULL` 约 `2W+4` 个触发器（2 数据表项 + 2 位 `entry_vld` + 2 个指针）。所有触发器均有显式 `en`，数据寄存器不复位，便于插 ICG、减小复位树。
- **取舍**：`RS_FULL` 用 2 表项换吞吐与双向时序切断；`RS_BACKWARD` 用 1 表项换最小面积；`RS_BYPASS` 保留用于确实不需要切时序的旁路场景。

## 12. 风险与未覆盖项 [C]
- **风险**：`RS_BACKWARD` 的保守 `in_rdy` 会在 skid 排空时给上游引入气泡；`RS_FULL` 满且同拍读时写侧会停一拍；`RS_MODE` 为 X/Z 时 `default` 走 `RS_FULL`，行为可预测但非预期配置。
- **限制**：单时钟；无 packet 边界；无位宽转换；不支持运行期切换模式。
- **未覆盖项**：`W > 8` 的位宽组合、`RS_MODE` 为 X/Z 的仿真、门级仿真与综合时序/面积、形式化验证。

## 13. 版本记录 [M]
| 版本 | 日期 | 变更 | 兼容性 |
|---|---|---|---|
| `v0.1.0` | 2026-10-27 | 初版：四种 `RS_MODE` 切片，`RS_BACKWARD` 覆盖 `skid_buffer` | - |

## 14. 相关文档 [O]
- 待开发清单：[`cbb-list.md`](../cbb-list.md)
- 编码规范与模板：`my_env` 的 `rtl-developer` skill

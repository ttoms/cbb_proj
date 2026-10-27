# CBB 待开发清单

> 配套文档：[开发流程指南](development-guide.md)
> 状态定义：`模板已有` = my_env 已有参考实现，待收编验收；`待开发` = 简单 CBB，可直接实现；`待架构` = 复杂 CBB，先在同一模块文档中完成微架构/数据流/状态机等章节再实现。
> 文档落点：每项 CBB 只维护一个文档 `docs/cbb/<module>.md`。所有 CBB 必写端口/参数/使用说明等基础章节；复杂 CBB 追加微架构、数据流、状态机、时序/PPA、风险章节。模板见 `docs/cbb/_template.md`。

## 1. 总览

| 阶段 | 数量 | 说明 |
|---|---:|---|
| P0 基础件收编 | 5 | 来自 my_env 模板，补验收与目录收编 |
| P1 高频基础件 | 13 | 计数器、边沿/脉冲、仲裁家族、仲裁 mux、可配置 register slice |
| P2 数据通路与 CDC | 10 | CDC 同步、异步 FIFO、位宽转换、CRC/编码 |
| P3 总线与外设 | 11 | APB/AXI-Lite、UART/SPI/I2C、Timer/IRQ |
| **合计** | **39** | 5 项模板已有，34 项待开发（其中 23 项需先详细设计） |

> `skid_buffer` 已合并到 `reg_slice` 的 `RS_BACKWARD` 模式，不再单独开发 RTL，见 §9。

**建议首批迭代（P0 + P1，共 18 项）**：先收编 5 个基础件，再完成 13 个高频件，形成后续 CDC / FIFO / 总线开发的依赖底座。

## 2. P0：基础件收编（模板已有）

| ID | 模块名 | 目录 | 功能 | 复杂度 | 依赖 | 状态 | 关键验收点 |
|---|---|---|---|---|---|---|---|
| CBB-BASIC-001 | `dff` | `rtl/basic` | 无复位数据通路寄存器，显式 `en` | 简单 | - | 模板已有 | 编译 + 自检 + 对齐；作为数据通路默认单元 |
| CBB-BASIC-002 | `dffr` | `rtl/basic` | 异步复位控制寄存器，显式 `en` | 简单 | - | 模板已有 | 复位值常量、复位释放由 `rst_sync` 保证 |
| CBB-BASIC-003 | `rst_sync` | `rtl/basic` | 异步复位、同步释放 | 简单 | - | 模板已有 | 复位释放无亚稳态；含参数检查 SVA |
| CBB-BASIC-004 | `cdc_2ff` | `rtl/cdc` | 单 bit 2FF 同步器 | 简单 | - | 模板已有 | 仅限单 bit；多 bit 禁止裸 2FF |
| CBB-MEM-001 | `fifo_sync` | `rtl/memory` | 同步 FIFO（valid-ready） | 复杂 | `dff` / `dffr` | 模板已有 | 满/空、指针回绕、同时读写、`DEPTH=2` 边界 |

> 收编动作：复制模板为 `docs/cbb/<module>.md`，补全功能/端口/参数/使用说明（复杂件补齐微架构/数据流/状态机等章节），完成验收后更新本清单状态为“已发布”。`dff` 已提供示例文档：[`docs/cbb/dff.md`](cbb/dff.md)。

## 3. P1：高频基础件

| ID | 模块名 | 目录 | 功能 | 复杂度 | 依赖 | 状态 | 关键验收点 |
|---|---|---|---|---|---|---|---|
| CBB-BASIC-005 | `counter` | `rtl/basic` | 参数化上/下计数、load、饱和/回绕 | 简单 | `dffr` | 待开发 | 位宽边界、回绕、`en` 条件、复位值 |
| CBB-BASIC-006 | `edge_det` | `rtl/basic` | 上升/下降/双边沿检测，单周期脉冲 | 简单 | `dff` | 待开发 | 复位后无假脉冲；输入抖动场景 |
| CBB-BASIC-007 | `pulse_stretch` | `rtl/basic` | 脉冲展宽 N 拍 | 简单 | `counter` | 待开发 | `N=1`、超长输入、背靠背脉冲 |
| CBB-BASIC-008 | `debounce` | `rtl/basic` | N 拍稳定去抖 | 简单 | `counter` | 待开发 | 抖动/稳定边界、复位释放 |
| CBB-ARB-001 | `arbiter_pri` | `rtl/arbiter` | 固定优先级仲裁核 | 简单 | - | 待开发 | 无请求、全请求、优先级语义明确 |
| CBB-ARB-002 | `arbiter_rr` | `rtl/arbiter` | 轮询仲裁核 | 复杂 | `dffr` | 待架构 | 指针回绕、单请求、全请求、公平性 |
| CBB-ARB-003 | `arbiter_wrr` | `rtl/arbiter` | 加权轮询仲裁核 | 复杂 | `dffr` | 待架构 | 权重边界、零权重、公平带宽、无饿死 |
| CBB-ARB-004 | `arbiter_lru` | `rtl/arbiter` | 最近最少使用仲裁核 | 复杂 | `dffr` | 待架构 | 历史更新、连续请求、无饿死、复位 |
| CBB-ARB-005 | `arbiter_qrr` | `rtl/arbiter` | QoS + 轮询仲裁核 | 复杂 | `dffr` | 待架构 | QoS 分组、同 QoS 轮询、高 QoS 优先、低 QoS 饿死说明 |
| CBB-ARB-006 | `arbiter_wrapper` | `rtl/arbiter` | 仲裁器统一封装，`ARB_TYPE` 选择仲裁核 | 复杂 | `arbiter_pri` / `arbiter_rr` / `arbiter_wrr` / `arbiter_lru` / `arbiter_qrr` | 待架构 | 五种 `ARB_TYPE` 分支、统一端口、非法类型报错 |
| CBB-ARB-007 | `arbmux` | `rtl/arbiter` | flit 级选通 mux，内部集成 `arbiter_wrapper` | 复杂 | `arbiter_wrapper` | 待架构 | flit 粒度仲裁、选中通道 `rdy`、不丢数/不重复、各 `ARB_TYPE` 分支 |
| CBB-ARB-008 | `strmux` | `rtl/arbiter` | stream 级选通 mux，内部集成 `arbiter_wrapper`，`GRAN` 选择 flit/packet 粒度 | 复杂 | `arbiter_wrapper` | 待架构 | `hop/top/vld/rdy/pld` 接口、flit/packet 粒度、packet 内不切换、各 `ARB_TYPE` 分支 |
| CBB-STREAM-002 | `reg_slice` | `rtl/stream` | 可配置 valid-ready 打拍切片，`RS_MODE` 选择 bypass/forward/backward/full | 复杂 | `dff` / `dffr` | 待架构 | 四种模式、反压不丢数/不重复、吞吐与延迟、模式参数非法值 |

## 4. P2：数据通路与 CDC

| ID | 模块名 | 目录 | 功能 | 复杂度 | 依赖 | 状态 | 关键验收点 |
|---|---|---|---|---|---|---|---|
| CBB-CDC-001 | `cdc_pulse` | `rtl/cdc` | 单 bit 脉冲跨时钟域（toggle/握手） | 复杂 | `cdc_2ff` | 待架构 | 慢到快/快到慢、脉冲不丢失/不重复 |
| CBB-CDC-002 | `cdc_gray` | `rtl/cdc` | 多 bit 格雷码 CDC | 复杂 | `cdc_2ff` / `gray_conv` | 待架构 | 仅相邻变化；多 bit 禁止裸 2FF |
| CBB-CDC-003 | `cdc_handshake` | `rtl/cdc` | 多 bit req/ack 握手同步 | 复杂 | `cdc_2ff` | 待架构 | 背靠背、复位边界、吞吐说明 |
| CBB-CDC-004 | `fifo_async` | `rtl/cdc` | 异步 FIFO（格雷码指针） | 复杂 | `cdc_2ff` / `gray_conv` / `dff` / `dffr` | 待架构 | 满/空、指针同步、复位、跨域同时读写 |
| CBB-MEM-002 | `fifo_sync_af` | `rtl/memory` | 同步 FIFO + almost_full/empty | 复杂 | `fifo_sync` | 待开发 | 阈值边界、阈值参数校验、组合/寄存输出 |
| CBB-STREAM-003 | `width_conv` | `rtl/stream` | 位宽转换（窄↔宽） | 复杂 | `fifo_sync` / `reg_slice` | 待架构 | 非整数倍、尾包、背靠背 |
| CBB-UTIL-001 | `crc` | `rtl/util` | 参数化 CRC 生成/校验 | 复杂 | `dff` | 待开发 | 标准多项式、位序、初值/异或、逐位/并行 |
| CBB-UTIL-002 | `onehot_pri_enc` | `rtl/util` | 独热/优先编码器 | 简单 | - | 待开发 | 全零、多热、位宽边界 |
| CBB-UTIL-003 | `gray_conv` | `rtl/util` | 二进制 ↔ 格雷码转换 | 简单 | - | 待开发 | 位宽边界、往返一致 |
| CBB-UTIL-004 | `parity` | `rtl/util` | 奇偶校验生成/检查 | 简单 | - | 待开发 | 奇/偶模式、位宽 1 |

## 5. P3：总线与外设

| ID | 模块名 | 目录 | 功能 | 复杂度 | 依赖 | 状态 | 关键验收点 |
|---|---|---|---|---|---|---|---|
| CBB-BUS-001 | `apb_slave` | `rtl/bus` | APB 从机 + 寄存器访问 | 复杂 | `dffr` | 待架构 | setup/access 时序、等待态、读写、错误响应 |
| CBB-BUS-002 | `axil_reg_if` | `rtl/bus` | AXI-Lite 寄存器接口 | 复杂 | `dffr` / `fifo_sync` | 待架构 | 五通道握手、响应顺序、超时策略 |
| CBB-BUS-003 | `axil2apb` | `rtl/bus` | AXI-Lite → APB 桥 | 复杂 | `axil_reg_if` / `apb_slave` | 待架构 | 单 outstanding、错误传递、背靠背 |
| CBB-IO-001 | `uart_tx` | `rtl/io` | UART 发送 | 复杂 | `counter` | 待开发 | 波特率分频、起止位、背靠背发送 |
| CBB-IO-002 | `uart_rx` | `rtl/io` | UART 接收 | 复杂 | `counter` / `debounce` | 待开发 | 中点采样、噪声/帧错误、过采样 |
| CBB-IO-003 | `timer` | `rtl/io` | 可编程定时器 | 简单 | `counter` | 待开发 | 周期/单次、重载、中断输出 |
| CBB-IO-004 | `watchdog` | `rtl/io` | 看门狗 | 简单 | `timer` | 待开发 | 喂狗窗口、超时复位、复位后默认态 |
| CBB-IO-005 | `irq_ctrl` | `rtl/io` | 中断控制器 | 复杂 | `dffr` | 待架构 | 使能/屏蔽/清除、电平/边沿、聚合输出 |
| CBB-IO-006 | `spi_master` | `rtl/io` | SPI 主机 | 复杂 | `counter` / `fifo_sync` | 待架构 | CPOL/CPHA、片选、背靠背、位宽配置 |
| CBB-IO-007 | `i2c_master` | `rtl/io` | I2C 主机 | 复杂 | `counter` | 待架构 | 起始/停止、ACK/NACK、时钟拉伸 |
| CBB-IO-008 | `pwm` | `rtl/io` | PWM 生成 | 简单 | `counter` | 待开发 | 占空比 0%/100%、周期边界 |

## 6. 关键设计约束

### 6.1 `reg_slice`：用 `RS_MODE` 统一 vld/rdy 打拍

`reg_slice` 是可配置切片；`skid_buffer` 不再单独实现，作为 `RS_MODE=RS_BACKWARD` 的预设用法。

| `RS_MODE` | 编码 | vld/data 前向路径 | rdy 反向路径 | 延迟 | 说明 |
|---|---:|---|---|---|---|
| `RS_BYPASS` | `2'b00` | 组合直通 | 组合直通 | 0 拍 | 不打断时序，面积最小 |
| `RS_FORWARD` | `2'b01` | 打拍 | 组合直通 | 1 拍 | 只切前向路径 |
| `RS_BACKWARD` | `2'b10` | 组合直通 + skid 表项 | 打拍 | 稳态 0 拍，反压吸收 1 拍 | 只切反向路径；即 `skid_buffer` |
| `RS_FULL` | `2'b11` | 打拍 | 打拍 | 1 拍 | 双向切断；内部需 skid/双表项保持吞吐 |

- `RS_MODE` 为 2 bit 参数，默认 `RS_FULL`。
- 目标吞吐均为 1 项/拍（反压时 0）；所有模式必须不丢数、不重复、不制造假 valid。
- `RS_BACKWARD` / `RS_FULL` 内含 skid 存储，反压时先吸收当前数据再拉低上游 `rdy`。
- `RS_BYPASS` 仅用于时序允许的场景，不能作为默认。
- 非法编码在 elaboration 阶段报错。

### 6.2 仲裁器家族与 `arbiter_wrapper`

所有仲裁核统一命名为 `arbiter_*`，统一封装为 `arbiter_wrapper`。仲裁核保持独立、单一职责；`arbiter_wrapper` 只做参数选择和端口统一，不复制仲裁算法。

| `ARB_TYPE` | 编码 | 仲裁核 | 语义 |
|---|---:|---|---|
| `ARB_FIXED` | `3'b000` | `arbiter_pri` | 固定优先级，索引小者优先 |
| `ARB_RR` | `3'b001` | `arbiter_rr` | 轮询，保证长期公平 |
| `ARB_WRR` | `3'b010` | `arbiter_wrr` | 加权轮询，按 `weight` 分配带宽 |
| `ARB_LRU` | `3'b011` | `arbiter_lru` | 最近最少使用优先，降低饿死风险 |
| `ARB_QRR` | `3'b100` | `arbiter_qrr` | 先按 QoS 分级，同 QoS 内轮询 |

统一接口：

- `req[N-1:0]`、`gnt[N-1:0]` 独热，`gnt_vld = |gnt`。
- `weight[N*WEIGHT_W-1:0]` 仅 `ARB_WRR` 使用，其余类型忽略。
- `qos[N*QOS_W-1:0]` 仅 `ARB_QRR` 使用，其余类型忽略；QoS 数值越大优先级越高，同 QoS 内轮询。
- `ARB_TYPE` 为 3 bit，elaboration 参数，不是运行期切换；`generate case` 只综合选中的仲裁核。
- `arbiter_wrr` 的 `weight=0` 视为不参与仲裁；全零时 `gnt_vld=0`。
- `arbiter_qrr` 在高 QoS 持续请求时可能饿死低 QoS，需在文档中明确；需要严格公平时改用 RR / WRR。
- `N=1`、`req=0`、全请求、背靠背授予、非法 `ARB_TYPE` 均需覆盖。

### 6.3 `arbmux` / `strmux`

两类 mux 都只做选通，内部例化 `arbiter_wrapper`，不重复实现仲裁算法。

| 模块 | 选通层级 | 接口 | 说明 |
|---|---|---|---|
| `arbmux` | flit 级 | flit 通道，至少 `vld/rdy/pld` | 每个 flit 独立仲裁，不保持 packet 边界；其余 flit 字段后续展开 |
| `strmux` | stream 级 | `hop/top/vld/rdy/pld` | 只看到该子集，不包含 `rop/crdt`；`GRAN` 选择 flit/packet 粒度 |

`strmux` 的 `GRAN`：

| `GRAN` | 编码 | 行为 |
|---|---:|---|
| `GRAN_FLIT` | `1'b0` | 每个 flit 可重新仲裁，允许 flit 级切换 |
| `GRAN_PACKET` | `1'b1` | 以 `hop` 为 packet 起点、`top` 为终点锁定选通，packet 内（含 `vld` 间隙）不切换（边界语义后续按链路层定义确认；默认） |

通用要求：

- 未被选中的输入通道 `rdy=0`；无请求时输出 `vld=0`。
- 反压时不得丢数、不得重复、不得产生假 valid。
- `ARB_TYPE` 从 mux 参数透传到 `arbiter_wrapper`，只综合选中的仲裁核。
- `hop/top/rop/vld/rdy/crdt/pld` 的完整位宽与语义后续按链路层接口定义展开；当前 `strmux` 只依赖 `hop/top/vld/rdy/pld`。

## 7. 依赖关系速览

```text
dff / dffr ──┬── counter ──┬── pulse_stretch
             │             ├── debounce
             │             ├── timer ── watchdog
             │             └── uart_tx / uart_rx / pwm
             ├── reg_slice（RS_BACKWARD 即 skid_buffer）
             └── fifo_sync ── fifo_sync_af / width_conv

arbiter_pri ─┐
arbiter_rr ──┤
arbiter_wrr ─┼── arbiter_wrapper ──┬── arbmux
arbiter_lru ─┤                     └── strmux
arbiter_qrr ─┘

rst_sync ── 所有时序模块的复位释放

cdc_2ff ──┬── cdc_pulse
          ├── cdc_gray ── gray_conv
          ├── cdc_handshake
          └── fifo_async

apb_slave / axil_reg_if ── axil2apb
```

## 8. 通用验收基线

每个 CBB 发布前至少满足：

1. `docs/cbb/<module>.md` 已建，端口表、参数表、使用说明齐全，且与 `.sv` 一致。
2. 复杂 CBB 的唯一文档已包含微架构、数据流、状态机、时序/PPA、风险章节，且与实现一致。
3. 接口、参数、复位/CDC、valid-ready 行为有明确说明。
4. `quality_gate.py` 0 error；warning 已评估。
5. 有定向 TB 且仿真 PASS；未跑的项在交付说明中列明。
6. 协议/FSM/CDC 类 CBB 有同名 `.sva`，并由 `SVA_ON` 正确 include。
7. 已执行 `align.sh`，代码无对齐标记。
8. 本清单中的状态、依赖、备注已更新。

## 9. 已合并 / 已废弃

| ID | 模块名 | 状态 | 说明 |
|---|---|---|---|
| CBB-STREAM-001 | `skid_buffer` | 已合并 | 功能由 `reg_slice` 的 `RS_MODE=RS_BACKWARD` 覆盖，不单独开发 RTL；保留 ID 仅用于追溯 |

## 10. 暂不纳入首版

- 商用 IP 级验证产物：覆盖率报告、回归列表、随机种子管理、形式化。
- 工艺库相关的 SRAM/DFT/BIST 包装（等工艺确定后单独立项）。
- CPU 子系统、DMA、DDR 控制器等大型 IP（不属于 CBB 粒度）。

# CBB 待开发清单

> 配套文档：[开发流程指南](development-guide.md)
> 状态定义：`模板已有` = my_env 已有参考实现，待收编验收；`待开发` = 简单 CBB，可直接实现；`待架构` = 复杂 CBB，先在同一模块文档中完成微架构/数据流/状态机等章节再实现。
> 文档落点：每项 CBB 只维护一个文档 `docs/cbb/<module>.md`，实现开始时创建，不预建空文件。简单件用 `docs/cbb/_template_simple.md`（6 章）；复杂件用 `docs/cbb/_template.md`（追加微架构、数据流、状态机、时序/PPA、风险）。

## 1. 总览

| 阶段 | 数量 | 说明 |
|---|---:|---|
| P0 基础件收编 | 4 | 来自 my_env 模板，补验收与目录收编 |
| P1 高频基础件 | 19 | 计数器、边沿/脉冲、自动时钟门控、编码/选通、仲裁家族、可配置 register slice |
| P2 数据通路、接口与保序 | 11 | 同步 FIFO 增强、位宽转换、CRC/编码、接口适配、流整形、链表/ID 池 |
| P3 总线与外设 | 11 | APB/AXI-Lite、UART/SPI/I2C、Timer/IRQ |
| P4 CDC（最低优先级，无需求不启动） | 5 | 单时钟项目，CDC 同步/异步 FIFO 无需求不启动 |
| **合计** | **50** | 17 项已发布（首批 14 + 二批 3），1 项模板已有，32 项待实施 |

> `skid_buffer` 已合并到 `reg_slice` 的 `RS_BACKWARD` 模式，不再单独开发 RTL，见 §10。

**首批迭代（P0 4 项 + P1 10 个简单件，共 14 项，已完成）**：先收编 4 个基础件，再完成 10 个简单件。

- 首批 P1 简单件：`counter`、`edge_det`、`pulse_stretch`、`debounce`、`icg`、`bin2ohot`、`ohot2bin`、`busmux`、`binmux`、`arbiter_pri`。
- 第二批复杂件：`reg_slice`、`arbiter_rr`、`arbiter_wrr`（已完成）；`clkgate`、`arbiter_lru` / `arbiter_qrr` / `arbiter_wrapper`、`arbmux`、`strmux`（待启动）。
- CDC 全部保持 P4，不进入首批；单时钟项目，无需求不启动。

## 2. P0：基础件收编（首批，已发布）

| ID | 模块名 | 目录 | 功能 | 复杂度 | 依赖 | 状态 | 关键验收点 |
|---|---|---|---|---|---|---|---|
| CBB-BASIC-001 | `dff` | `rtl/basic` | 无复位数据通路寄存器，显式 `en` | 简单 | - | 已发布 | 编译 + 自检 + 对齐；作为数据通路默认单元 |
| CBB-BASIC-002 | `dffr` | `rtl/basic` | 异步复位控制寄存器，显式 `en` | 简单 | - | 已发布 | 复位值常量、复位释放由 `rst_sync` 保证 |
| CBB-BASIC-003 | `rst_sync` | `rtl/basic` | 异步复位、同步释放 | 简单 | `dffr` | 已发布 | 复位释放无亚稳态；含参数检查 SVA |
| CBB-MEM-001 | `fifo_sync` | `rtl/memory` | 同步 FIFO（valid-ready） | 复杂 | `dff` / `dffr` | 已发布 | 满/空、指针回绕、同时读写、`DEPTH=2` 边界 |

> 收编动作：实现开始时按简单/复杂件复制对应模板为 `docs/cbb/<module>.md`，补全端口/参数/使用说明（复杂件补齐微架构/数据流/状态机等章节），完成验收后更新本清单状态为“已发布”。首批 14 项均已完成并发布。

## 3. P1：高频基础件（首批 10 + 二批 9）

| ID | 模块名 | 目录 | 功能 | 复杂度 | 依赖 | 状态 | 批次 | 关键验收点 |
|---|---|---|---|---|---|---|---|---|
| CBB-BASIC-005 | `counter` | `rtl/basic` | 参数化上/下计数、load、饱和/回绕 | 简单 | `dffr` | 已发布 | 首批 | 位宽边界、回绕、`en` 条件、复位值 |
| CBB-BASIC-006 | `edge_det` | `rtl/basic` | 上升/下降/双边沿检测，单周期脉冲 | 简单 | `dffr` | 已发布 | 首批 | 复位后无假脉冲；输入抖动场景 |
| CBB-BASIC-007 | `pulse_stretch` | `rtl/basic` | 脉冲展宽 N 拍 | 简单 | `dffr` | 已发布 | 首批 | `N=1`、超长输入、背靠背脉冲 |
| CBB-BASIC-008 | `debounce` | `rtl/basic` | N 拍稳定去抖 | 简单 | `dffr` | 已发布 | 首批 | 抖动/稳定边界、复位释放 |
| CBB-BASIC-009 | `clkgate` | `rtl/basic` | 自动时钟门控，根据 `wakeup` / `idle` 自动开关时钟，内部调用 `icg` | 复杂 | `icg` | 待架构 | 二批 | wakeup 唤醒、idle 判定、自动开关钟、无毛刺、复位 |
| CBB-BASIC-010 | `icg` | `rtl/basic` | latch 型标准单元 ICG 行为模型/包装 | 简单 | - | 已发布 | 首批 | latch 透明/锁存、enable 时序、`// gate: allow-latch` 豁免、仿真与综合替换一致 |
| CBB-UTIL-005 | `bin2ohot` | `rtl/util` | 二进制 → 独热转换 | 简单 | - | 已发布 | 首批 | 全零、最大索引、位宽边界、输出仅一位有效 |
| CBB-UTIL-006 | `ohot2bin` | `rtl/util` | 独热 → 二进制转换 | 简单 | - | 已发布 | 首批 | 单热、全零、多热行为、位宽边界 |
| CBB-UTIL-007 | `busmux` | `rtl/util` | 独热选择信号的数据 mux | 简单 | - | 已发布 | 首批 | 单热、无选择、多热行为、数据位宽 |
| CBB-UTIL-008 | `binmux` | `rtl/util` | 二进制选择信号的数据 mux | 简单 | - | 已发布 | 首批 | 选择越界、无选择、位宽、组合延迟 |
| CBB-ARB-001 | `arbiter_pri` | `rtl/arbiter` | 固定优先级仲裁核 | 简单 | - | 已发布 | 首批 | 无请求、全请求、优先级语义明确 |
| CBB-ARB-002 | `arbiter_rr` | `rtl/arbiter` | 轮询仲裁核 | 复杂 | `dffr` | 已发布 | 二批 | 指针回绕、单请求、全请求、公平性 |
| CBB-ARB-003 | `arbiter_wrr` | `rtl/arbiter` | 加权轮询仲裁核 | 复杂 | `dffr` | 已发布 | 二批 | 权重边界、零权重、公平带宽、无饿死 |
| CBB-ARB-004 | `arbiter_lru` | `rtl/arbiter` | 最近最少使用仲裁核 | 复杂 | `dffr` | 待架构 | 二批 | 历史更新、连续请求、无饿死、复位 |
| CBB-ARB-005 | `arbiter_qrr` | `rtl/arbiter` | QoS + 轮询仲裁核 | 复杂 | `dffr` | 待架构 | 二批 | QoS 分组、同 QoS 轮询、高 QoS 优先、低 QoS 饿死说明 |
| CBB-ARB-006 | `arbiter_wrapper` | `rtl/arbiter` | 仲裁器统一封装，`ARB_TYPE` 选择仲裁核 | 复杂 | `arbiter_pri` / `arbiter_rr` / `arbiter_wrr` / `arbiter_lru` / `arbiter_qrr` | 待架构 | 二批 | 五种 `ARB_TYPE` 分支、统一端口、非法类型报错 |
| CBB-ARB-007 | `arbmux` | `rtl/arbiter` | flit 级选通 mux，内部集成 `arbiter_wrapper` | 复杂 | `arbiter_wrapper` | 待架构 | 二批 | flit 粒度仲裁、选中通道 `rdy`、不丢数/不重复、各 `ARB_TYPE` 分支 |
| CBB-ARB-008 | `strmux` | `rtl/arbiter` | stream 级选通 mux，内部集成 `arbiter_wrapper`，`GRAN` 选择 flit/packet 粒度 | 复杂 | `arbiter_wrapper` | 待架构 | 二批 | `hop/top/vld/rdy/pld` 接口、flit/packet 粒度、packet 内不切换、各 `ARB_TYPE` 分支 |
| CBB-STREAM-002 | `reg_slice` | `rtl/stream` | 可配置 valid-ready 打拍切片，`RS_MODE` 选择 bypass/forward/backward/full | 复杂 | `dff` / `dffr` | 已发布 | 二批 | 四种模式、反压不丢数/不重复、吞吐与延迟、模式参数非法值 |

## 4. P2：数据通路、接口与保序

| ID | 模块名 | 目录 | 功能 | 复杂度 | 依赖 | 状态 | 关键验收点 |
|---|---|---|---|---|---|---|---|
| CBB-MEM-002 | `fifo_sync_af` | `rtl/memory` | 同步 FIFO + almost_full/empty | 复杂 | `fifo_sync` | 待架构 | 阈值边界、阈值参数校验、组合/寄存输出 |
| CBB-STREAM-003 | `width_conv` | `rtl/stream` | 位宽转换（窄↔宽） | 复杂 | `fifo_sync` / `reg_slice` | 待架构 | 非整数倍、尾包、背靠背 |
| CBB-STREAM-004 | `intf_rx` | `rtl/stream` | 链路接口接收侧适配/解码 | 复杂 | - | 待架构 | `hop/top/rop/vld/rdy/crdt/pld` 接口映射、背压、packet 边界、复位 |
| CBB-STREAM-005 | `intf_tx` | `rtl/stream` | 链路接口发送侧适配/编码 | 复杂 | - | 待架构 | 接口映射、credit/rdy、packet 边界、不丢数/不重复 |
| CBB-STREAM-006 | `flow_shaper` | `rtl/stream` | 流级流量整形/速率控制 | 复杂 | `counter` | 待架构 | 令牌桶速率/突发、反压不丢包、参数越界、复位 |
| CBB-UTIL-001 | `crc` | `rtl/util` | 参数化 CRC 生成/校验 | 复杂 | `dff` | 待架构 | 标准多项式、位序、初值/异或、逐位/并行 |
| CBB-UTIL-002 | `ohot_pri_enc` | `rtl/util` | 独热/优先编码器 | 简单 | - | 待开发 | 全零、多热、位宽边界 |
| CBB-UTIL-003 | `gray_conv` | `rtl/util` | 二进制 ↔ 格雷码转换 | 简单 | - | 待开发 | 位宽边界、往返一致 |
| CBB-UTIL-004 | `parity` | `rtl/util` | 奇偶校验生成/检查 | 简单 | - | 待开发 | 奇/偶模式、位宽 1 |
| CBB-ORDER-001 | `link_list` | `rtl/order` | 链表管理，用于保序逻辑，配合 `idpool` 使用 | 复杂 | `idpool` / `dffr` | 待架构 | 节点分配/释放、插入/删除、顺序保持、满/空、复位 |
| CBB-ORDER-002 | `idpool` | `rtl/order` | ID 池分配与回收，配合 `link_list` 保序 | 复杂 | `dffr` | 待架构 | 分配/回收、满/空、重复释放、复位清空、无泄漏 |

## 5. P3：总线与外设

| ID | 模块名 | 目录 | 功能 | 复杂度 | 依赖 | 状态 | 关键验收点 |
|---|---|---|---|---|---|---|---|
| CBB-BUS-001 | `apb_slave` | `rtl/bus` | APB 从机 + 寄存器访问 | 复杂 | `dffr` | 待架构 | setup/access 时序、等待态、读写、错误响应 |
| CBB-BUS-002 | `axil_reg_if` | `rtl/bus` | AXI-Lite 寄存器接口 | 复杂 | `dffr` / `fifo_sync` | 待架构 | 五通道握手、响应顺序、超时策略 |
| CBB-BUS-003 | `axil2apb` | `rtl/bus` | AXI-Lite → APB 桥 | 复杂 | `axil_reg_if` / `apb_slave` | 待架构 | 单 outstanding、错误传递、背靠背 |
| CBB-IO-001 | `uart_tx` | `rtl/io` | UART 发送 | 复杂 | `counter` | 待架构 | 波特率分频、起止位、背靠背发送 |
| CBB-IO-002 | `uart_rx` | `rtl/io` | UART 接收 | 复杂 | `counter` / `debounce` | 待架构 | 中点采样、噪声/帧错误、过采样 |
| CBB-IO-003 | `timer` | `rtl/io` | 可编程定时器 | 简单 | `counter` | 待开发 | 周期/单次、重载、中断输出 |
| CBB-IO-004 | `watchdog` | `rtl/io` | 看门狗 | 简单 | `timer` | 待开发 | 喂狗窗口、超时复位、复位后默认态 |
| CBB-IO-005 | `irq_ctrl` | `rtl/io` | 中断控制器 | 复杂 | `dffr` | 待架构 | 使能/屏蔽/清除、电平/边沿、聚合输出 |
| CBB-IO-006 | `spi_master` | `rtl/io` | SPI 主机 | 复杂 | `counter` / `fifo_sync` | 待架构 | CPOL/CPHA、片选、背靠背、位宽配置 |
| CBB-IO-007 | `i2c_master` | `rtl/io` | I2C 主机 | 复杂 | `counter` | 待架构 | 起始/停止、ACK/NACK、时钟拉伸 |
| CBB-IO-008 | `pwm` | `rtl/io` | PWM 生成 | 简单 | `counter` | 待开发 | 占空比 0%/100%、周期边界 |

## 6. P4：CDC（最低优先级）

> 所有 CDC 相关 CBB 统一设为最低优先级，不进入首批。单时钟项目，无需求不启动。

| ID | 模块名 | 目录 | 功能 | 复杂度 | 依赖 | 状态 | 关键验收点 |
|---|---|---|---|---|---|---|---|
| CBB-BASIC-004 | `cdc_2ff` | `rtl/cdc` | 单 bit 2FF 同步器 | 简单 | - | 模板已有 | 仅限单 bit；多 bit 禁止裸 2FF |
| CBB-CDC-001 | `cdc_pulse` | `rtl/cdc` | 单 bit 脉冲跨时钟域（toggle/握手） | 复杂 | `cdc_2ff` | 待架构 | 慢到快/快到慢、脉冲不丢失/不重复 |
| CBB-CDC-002 | `cdc_gray` | `rtl/cdc` | 多 bit 格雷码 CDC | 复杂 | `cdc_2ff` / `gray_conv` | 待架构 | 仅相邻变化；多 bit 禁止裸 2FF |
| CBB-CDC-003 | `cdc_handshake` | `rtl/cdc` | 多 bit req/ack 握手同步 | 复杂 | `cdc_2ff` | 待架构 | 背靠背、复位边界、吞吐说明 |
| CBB-CDC-004 | `fifo_async` | `rtl/cdc` | 异步 FIFO（格雷码指针） | 复杂 | `cdc_2ff` / `gray_conv` / `dff` / `dffr` | 待架构 | 满/空、指针同步、复位、跨域同时读写 |

## 7. 关键设计约束

### 7.1 `reg_slice`：用 `RS_MODE` 统一 vld/rdy 打拍

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
- 2 bit 编码 `00`~`11` 全部合法，不存在非法编码；`default` 分支按 `RS_FULL` 防御。
- 实现：`rtl/stream/reg_slice.sv`；文档：`docs/cbb/reg_slice.md`。

### 7.2 仲裁器家族与 `arbiter_wrapper`

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

### 7.3 `arbmux` / `strmux`

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

`arbmux` / `strmux` 属第二批；启动前先补齐 `hop/top/rop/crdt/pld` 的位宽与 packet 边界语义。

通用要求：

- 未被选中的输入通道 `rdy=0`；无请求时输出 `vld=0`。
- 反压时不得丢数、不得重复、不得产生假 valid。
- `ARB_TYPE` 从 mux 参数透传到 `arbiter_wrapper`，只综合选中的仲裁核。
- `hop/top/rop/vld/rdy/crdt/pld` 的完整位宽与语义后续按链路层接口定义展开；当前 `strmux` 只依赖 `hop/top/vld/rdy/pld`。

### 7.4 接口、保序与流控模块

- `intf_rx` / `intf_tx`：链路接口接收/发送适配，接口字段为 `hop/top/rop/vld/rdy/crdt/pld`；位宽和字段语义后续展开。
- `link_list`：链表管理，用于保序相关逻辑，配合 `idpool` 使用；不是链路层封装。需覆盖节点分配/释放、插入/删除、顺序保持、满/空、复位。
- `idpool`：ID 分配/回收必须无泄漏；重复释放安全；复位清空；分配策略在模块文档中明确。
- `flow_shaper`：令牌桶/速率控制，默认通过反压限速而不是丢包；速率、突发参数越界在 elaboration 阶段报错。

### 7.5 时钟门控

- `icg`：latch 型标准单元 ICG 的行为模型/包装，只负责单元级门控行为。
- `clkgate`：自动时钟门控模块，不是简单的 `icg` 封装；根据 `wakeup` / `idle` 自动开关时钟，内部调用 `icg`。
- `clkgate` 需明确 wakeup 唤醒优先级、idle 判定条件/迟滞、门控后时钟无毛刺、复位默认状态。

## 8. 依赖关系速览

```text
dff / dffr ──┬── counter ──┬── pulse_stretch
             │             ├── debounce
             │             ├── timer ── watchdog
             │             ├── flow_shaper
             │             └── uart_tx / uart_rx / pwm
             ├── reg_slice（RS_BACKWARD 即 skid_buffer）
             ├── idpool ── link_list（链表/保序）
             └── fifo_sync ── fifo_sync_af / width_conv

icg ── clkgate

bin2ohot / ohot2bin / busmux / binmux

arbiter_pri ─┐
arbiter_rr ──┤
arbiter_wrr ─┼── arbiter_wrapper ──┬── arbmux
arbiter_lru ─┤                     └── strmux
arbiter_qrr ─┘

intf_rx / intf_tx（链路接口适配）

rst_sync ── 所有时序模块的复位释放

cdc_2ff ──┬── cdc_pulse
          ├── cdc_gray ── gray_conv
          ├── cdc_handshake
          └── fifo_async

apb_slave / axil_reg_if ── axil2apb
```

## 9. 通用验收基线

每个 CBB 发布前至少满足：

1. `docs/cbb/<module>.md` 已建（实现开始时创建），功能、端口、参数、使用说明、限制、验证状态齐全且与 `.sv` 一致。
2. 复杂 CBB 已追加微架构、数据流、状态机、时序/PPA、风险章节，且与实现一致。
3. 接口、参数、复位/CDC、valid-ready 行为有明确说明。
4. `quality_gate.py` 0 error；warning 已评估。
5. 有定向 TB 且仿真 PASS；未跑的项在交付说明中列明。
6. SVA 按需；创建时由 `SVA_ON` 正确 include。
7. 已执行 `align.sh`，代码无对齐标记。
8. 本清单中的状态、依赖、备注已更新。

## 10. 已合并 / 已废弃

| ID | 模块名 | 状态 | 说明 |
|---|---|---|---|
| CBB-STREAM-001 | `skid_buffer` | 已合并 | 功能由 `reg_slice` 的 `RS_MODE=RS_BACKWARD` 覆盖，不单独开发 RTL；保留 ID 仅用于追溯 |

## 11. 暂不纳入首版

- 商用 IP 级验证产物：覆盖率报告、回归列表、随机种子管理、形式化。
- 工艺库相关的 SRAM/DFT/BIST 包装（等工艺确定后单独立项）。
- CPU 子系统、DMA、DDR 控制器等大型 IP（不属于 CBB 粒度）。

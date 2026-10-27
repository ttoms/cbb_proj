# CBB 待开发清单

> 配套文档：[开发流程指南](development-guide.md)
> 状态定义：`模板已有` = my_env 已有参考实现，待收编验收；`待开发` = 简单 CBB，可直接实现；`待架构` = 复杂 CBB，先出架构方案再实现。

## 1. 总览

| 阶段 | 数量 | 说明 |
|---|---:|---|
| P0 基础件收编 | 5 | 来自 my_env 模板，补验收与目录收编 |
| P1 高频基础件 | 8 | 计数器、边沿/脉冲、仲裁、流控 |
| P2 数据通路与 CDC | 10 | CDC 同步、异步 FIFO、位宽转换、CRC/编码 |
| P3 总线与外设 | 11 | APB/AXI-Lite、UART/SPI/I2C、Timer/IRQ |
| **合计** | **34** | 5 项模板已有，29 项待开发（其中 17 项需先架构） |

**建议首批迭代（P0 + P1，共 13 项）**：先收编 5 个基础件，再完成 8 个高频件，形成后续 CDC / FIFO / 总线开发的依赖底座。

## 2. P0：基础件收编（模板已有）

| ID | 模块名 | 目录 | 功能 | 复杂度 | 依赖 | 状态 | 关键验收点 |
|---|---|---|---|---|---|---|---|
| CBB-BASIC-001 | `dff` | `rtl/basic` | 无复位数据通路寄存器，显式 `en` | 简单 | - | 模板已有 | 编译 + 自检 + 对齐；作为数据通路默认单元 |
| CBB-BASIC-002 | `dffr` | `rtl/basic` | 异步复位控制寄存器，显式 `en` | 简单 | - | 模板已有 | 复位值常量、复位释放由 `rst_sync` 保证 |
| CBB-BASIC-003 | `rst_sync` | `rtl/basic` | 异步复位、同步释放 | 简单 | - | 模板已有 | 复位释放无亚稳态；含参数检查 SVA |
| CBB-BASIC-004 | `cdc_2ff` | `rtl/cdc` | 单 bit 2FF 同步器 | 简单 | - | 模板已有 | 仅限单 bit；多 bit 禁止裸 2FF |
| CBB-MEM-001 | `fifo_sync` | `rtl/memory` | 同步 FIFO（valid-ready） | 复杂 | `dff` / `dffr` | 模板已有 | 满/空、指针回绕、同时读写、`DEPTH=2` 边界 |

> 收编动作：复制模板到对应目录，补模块级验收记录，更新本清单状态为“已发布”。

## 3. P1：高频基础件

| ID | 模块名 | 目录 | 功能 | 复杂度 | 依赖 | 状态 | 关键验收点 |
|---|---|---|---|---|---|---|---|
| CBB-BASIC-005 | `counter` | `rtl/basic` | 参数化上/下计数、load、饱和/回绕 | 简单 | `dffr` | 待开发 | 位宽边界、回绕、`en` 条件、复位值 |
| CBB-BASIC-006 | `edge_det` | `rtl/basic` | 上升/下降/双边沿检测，单周期脉冲 | 简单 | `dff` | 待开发 | 复位后无假脉冲；输入抖动场景 |
| CBB-BASIC-007 | `pulse_stretch` | `rtl/basic` | 脉冲展宽 N 拍 | 简单 | `counter` | 待开发 | `N=1`、超长输入、背靠背脉冲 |
| CBB-BASIC-008 | `debounce` | `rtl/basic` | N 拍稳定去抖 | 简单 | `counter` | 待开发 | 抖动/稳定边界、复位释放 |
| CBB-ARB-001 | `pri_arbiter` | `rtl/arbiter` | 固定优先级仲裁 | 简单 | - | 待开发 | 无请求、全请求、优先级语义明确 |
| CBB-ARB-002 | `rr_arbiter` | `rtl/arbiter` | 轮询仲裁 | 复杂 | `dffr` | 待架构 | 指针回绕、单请求、全请求、公平性 |
| CBB-STREAM-001 | `skid_buffer` | `rtl/stream` | valid-ready 防反压缓冲 | 复杂 | `dff` / `dffr` | 待架构 | 满时反压、无数据丢失/重复、背靠背 |
| CBB-STREAM-002 | `reg_slice` | `rtl/stream` | 流水线寄存器切片 | 简单 | `dff` | 待开发 | 直通/打拍模式、时序打断 |

## 4. P2：数据通路与 CDC

| ID | 模块名 | 目录 | 功能 | 复杂度 | 依赖 | 状态 | 关键验收点 |
|---|---|---|---|---|---|---|---|
| CBB-CDC-001 | `cdc_pulse` | `rtl/cdc` | 单 bit 脉冲跨时钟域（toggle/握手） | 复杂 | `cdc_2ff` | 待架构 | 慢到快/快到慢、脉冲不丢失/不重复 |
| CBB-CDC-002 | `cdc_gray` | `rtl/cdc` | 多 bit 格雷码 CDC | 复杂 | `cdc_2ff` / `gray_conv` | 待架构 | 仅相邻变化；多 bit 禁止裸 2FF |
| CBB-CDC-003 | `cdc_handshake` | `rtl/cdc` | 多 bit req/ack 握手同步 | 复杂 | `cdc_2ff` | 待架构 | 背靠背、复位边界、吞吐说明 |
| CBB-CDC-004 | `fifo_async` | `rtl/cdc` | 异步 FIFO（格雷码指针） | 复杂 | `cdc_2ff` / `gray_conv` / `dff` / `dffr` | 待架构 | 满/空、指针同步、复位、跨域同时读写 |
| CBB-MEM-002 | `fifo_sync_af` | `rtl/memory` | 同步 FIFO + almost_full/empty | 复杂 | `fifo_sync` | 待开发 | 阈值边界、阈值参数校验、组合/寄存输出 |
| CBB-STREAM-003 | `width_conv` | `rtl/stream` | 位宽转换（窄↔宽） | 复杂 | `fifo_sync` / `skid_buffer` | 待架构 | 非整数倍、尾包、背靠背 |
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

## 6. 依赖关系速览

```text
dff / dffr ──┬── counter ──┬── pulse_stretch
             │             ├── debounce
             │             ├── timer ── watchdog
             │             └── uart_tx / uart_rx / pwm
             ├── reg_slice / skid_buffer
             ├── fifo_sync ── fifo_sync_af / width_conv
             └── rr_arbiter / pri_arbiter

rst_sync ── 所有时序模块的复位释放

cdc_2ff ──┬── cdc_pulse
          ├── cdc_gray ── gray_conv
          ├── cdc_handshake
          └── fifo_async

apb_slave / axil_reg_if ── axil2apb
```

## 7. 通用验收基线

每个 CBB 发布前至少满足：

1. 接口、参数、复位/CDC、valid-ready 行为有明确说明。
2. `quality_gate.py` 0 error；warning 已评估。
3. 有定向 TB 且仿真 PASS；未跑的项在交付说明中列明。
4. 协议/FSM/CDC 类 CBB 有同名 `.sva`，并由 `SVA_ON` 正确 include。
5. 已执行 `align.sh`，代码无对齐标记。
6. 复杂 CBB 的架构方案与实现一致，验证要点逐条覆盖。
7. 本清单中的状态、依赖、备注已更新。

## 8. 暂不纳入首版

- 商用 IP 级验证产物：覆盖率报告、回归列表、随机种子管理、形式化。
- 工艺库相关的 SRAM/DFT/BIST 包装（等工艺确定后单独立项）。
- CPU 子系统、DMA、DDR 控制器等大型 IP（不属于 CBB 粒度）。

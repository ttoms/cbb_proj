# CBB 开发流程指南

> 基线：`my_env/skills/rtl-developer`（轻量、正向约束优先）。
> 适用范围：`cbb_proj` 内所有可综合 SystemVerilog CBB。
> 目标：80% 写前约束 + 20% 秒级自检，不做商用 IP 级 EDA flow。

## 1. 基本原则

- **单一职责**：一个 CBB 只解决一个明确问题，接口稳定、可复用。
- **参数化优先**：位宽、深度、数量用 `parameter`；派生值用 `$clog2` / `$bits`。
- **先约束后编码**：动手前过完写前 checklist；复杂 CBB 先出详细设计。
- **轻量验证**：简单模块一个定向 TB；有状态模块加随机激励和 scoreboard；不强制覆盖率 / 回归 / 形式化。
- **如实交付**：没跑仿真就写“未仿真”，缺少工具不伪造结果。

## 2. 目录与命名约定

```text
cbb_proj/
├── docs/
│   ├── development-guide.md     # 本文件
│   ├── cbb-list.md              # 待开发 CBB 清单与状态
│   ├── cbb/                     # 每个 CBB 的文档
│   │   ├── README.md            # 文档规范与索引
│   │   ├── _template.md         # 单文档模板（含章节必写/可省略标记）
│   │   └── <module>.md          # 每个 CBB 唯一文档
│   └── architecture/            # 跨 CBB / 子系统级架构方案
├── rtl/<category>/              # 可综合 RTL，<module>.sv 与同名 .sva 同目录
├── tb/<category>/               # 定向 TB，<module>_tb.sv
├── scripts/                     # quality_gate.py / align.sh
└── build/                       # 本地仿真产物，已被 .gitignore 忽略
```

| 目录 | 放什么 |
|---|---|
| `rtl/basic` | 寄存器、复位、计数器、边沿/脉冲、时钟门控 |
| `rtl/cdc` | 跨时钟域同步、异步 FIFO |
| `rtl/memory` | 同步 FIFO、RAM/ROM 包装 |
| `rtl/stream` | valid-ready 流控、`reg_slice`、位宽转换、`intf_rx` / `intf_tx`、`flow_shaper` |
| `rtl/order` | `link` 链表、`idpool` 保序资源池 |
| `rtl/arbiter` | `arbiter_*` 仲裁核、`arbiter_wrapper` 统一封装、`arbmux` / `strmux` 选通 |
| `rtl/bus` | APB / AXI-Lite 等总线粘合逻辑 |
| `rtl/io` | UART / SPI / I2C / Timer / IRQ 等外设 |
| `rtl/util` | CRC、格雷码、编码器、bin/onehot 转换、`busmux` / `binmux` |

文档落点：

| 文档 | 适用对象 | 内容 |
|---|---|---|
| `docs/cbb/<module>.md` | **所有 CBB 必备，且每模块仅此一个文档** | 必写章节：功能、端口、参数、使用说明、复位/CDC、限制、验证状态、版本；复杂 CBB 追加微架构、数据流、状态机、时序/PPA、风险 |
| `docs/architecture/` | 跨 CBB / 子系统 | 库级分层、多个 CBB 的组合方案 |

文档模板见 `docs/cbb/_template.md`，章节必写/可省略规则见 [`docs/cbb/README.md`](cbb/README.md)。

命名硬约束：

- 模块名与文件名一致，小写蛇形；一个文件一个 `module`。
- 实例名全大写（`U_*`）；`package` 用 `_pkg.sv`，`interface` 用 `_if.sv`，TB 用 `_tb.sv`，断言用 `.sva`。
- 端口无 `_i` / `_o` 方向后缀；按 `clk/rst → 配置 → 输入 → 输出 → 状态` 排序。
- 控制类寄存器 `dffr`（异步复位），数据通路寄存器 `dff`（无复位），每个寄存器显式 `en`。

## 3. CBB 准入条件（开工前）

一个 CBB 进入开发前，必须满足：

1. 已登记到 [cbb-list.md](cbb-list.md)，有唯一 ID、类别、优先级、依赖。
2. 功能边界、端口、参数范围、时钟/复位、valid-ready 行为已明确。
3. 依赖的 CBB 已存在或已排期；不允许“边写边等”。
4. 已确定唯一文档：`docs/cbb/<module>.md` 骨架已建。
5. 复杂 CBB 的文档已包含微架构、数据流、状态机等必须章节并通过确认。
6. 验收场景可描述：至少包含正常流、边界条件（最小位宽/深度）、复位释放。

## 4. 开发流程

```text
需求登记 → 复杂度分级 → [复杂] 详细设计 → 实现 → 秒级自检
        → 仿真验证 → 强制对齐 → 评审 → 发布 / 更新清单
```

| 阶段 | 输入 | 产出 | 退出条件 |
|---|---|---|---|
| 0. 需求登记 | 使用场景 | `cbb-list.md` 条目 + `docs/cbb/<module>.md` 骨架 | ID / 优先级 / 依赖 / 文档落点明确 |
| 1. 复杂度分级 | 需求 | 分级结论 | 简单直接实现；复杂进入设计 |
| 2. 详细设计 | 需求 + 规范 | 在 `docs/cbb/<module>.md` 中补微架构/数据流/状态机等章节 | 复杂 CBB 的必写章节确认 |
| 3. 实现 | 方案/模板 | `rtl/<cat>/<module>.sv`（+ `.sva`）+ 完整模块文档 | 代码合规；文档端口/参数/用法与实际一致 |
| 4. 秒级自检 | `.sv` | `quality_gate.py` 输出 | **0 error**（warning 需评估） |
| 5. 仿真验证 | `.sv` + TB | `tb/<cat>/<module>_tb.sv` + 仿真结果 | 定向场景 PASS；失败点有记录 |
| 6. 强制对齐 | `.sv` | 对齐后的源码 | `align.sh` 执行成功且幂等 |
| 7. 评审 | 全部产物 | 评审记录 / 修改项 | 评审 checklist 全部通过 |
| 8. 发布 | 通过评审的产物 | 状态更新为“已发布” | 代码、唯一文档、清单一致 |

### 4.1 复杂度分级

**简单模块**（直接实现）：单时钟、端口 ≤ 20、状态 < 4、无 FIFO / 状态化仲裁 / 协议 / CDC。

**复杂模块**（详细设计先行）：时钟域 ≥ 2 或含 CDC、状态 ≥ 4、端口 > 20、含 FIFO / 状态化仲裁 / 总线协议 / 完整数据通路。

复杂 CBB 的设计内容写入**同一个模块文档** `docs/cbb/<module>.md`，在必写章节之外追加：

1. 微架构与数据流：模块划分、框图、数据流向、关键寄存器/存储体
2. 状态机：状态表/转移、编码方式、异常处理；无 FSM 时写“不适用”及原因
3. 时序、流水线与 PPA：延迟/吞吐/反压、关键路径、面积/功耗、取舍
4. 风险与未覆盖项：设计风险、限制、未验证场景

微架构、数据流、状态机的具体原理和展开深度与模块功能强相关，规范只要求覆盖这些维度，不规定固定写法。

### 4.2 文档要求

**每模块一个文档：`docs/cbb/<module>.md`，不拆分 README / design。**

| 章节 | 简单 CBB | 复杂 CBB |
|---|---|---|
| 1. 基本信息 | 必须 | 必须 |
| 2. 功能与范围 | 必须 | 必须 |
| 3. 端口表 | 必须 | 必须 |
| 4. 参数表 | 必须 | 必须 |
| 5. 使用说明 | 必须 | 必须 |
| 6. 复位与 CDC | 必须 | 必须 |
| 7. 限制与注意 | 必须 | 必须 |
| 8. 验证状态 | 必须 | 必须 |
| 9. 微架构与数据流 | 可省略 | **必须** |
| 10. 状态机 | 可省略 | **必须**（无 FSM 写“不适用”及原因） |
| 11. 时序、流水线与 PPA | 可省略 | **必须** |
| 12. 风险与未覆盖项 | 可省略 | **必须** |
| 13. 版本记录 | 必须 | 必须 |
| 14. 相关文档 | 可选 | 可选 |

- 所有 CBB 必写：功能、端口、参数、使用说明、复位/CDC、限制、验证状态、版本记录。
- 复杂 CBB 追加：微架构与数据流、状态机、时序/PPA、风险与未覆盖项。
- 简单 CBB 可省略第 9~12 章，也可按需补充。
- 模块头注释只是代码内摘要，**不能替代**模块文档。

**一致性规则：**

- 文档中的端口/参数必须与 `.sv` 逐项一致。
- 复杂 CBB 的微架构、数据流、状态机章节必须与实现一致。
- 文档与 RTL 同一次变更提交；缺少文档或文档过期，不得标记为“已发布”。
- 模板：[`CBB 文档模板`](cbb/_template.md)；章节规则：[`CBB 文档规范`](cbb/README.md)。

### 4.3 实现约定

- 优先复用 `my_env/skills/rtl-developer/templates/` 的基础件，不重复造轮子。
- `module` 之前首个非注释内容为 `` `default_nettype none ``，文件末尾 `` `default_nettype wire ``。
- 模块头注释必须含 `Module / Description / Features / Parameters / Limitations`。
- `valid` 与 `data` 同周期；`vld` 不依赖 `rdy`。
- 例化端口只连信号名、参数名、字面常量；逻辑运算在外部 `assign` / `always_comb` 预处理。
- 组合逻辑用 `always_comb` + 默认值；`case` 必须有 `default`；禁止 latch。
- 模块 `.sv` 内不写断言；需要时建同名 `.sva`，在 `endmodule` 前用 `` `ifdef SVA_ON `` include。
- 禁止 `initial` / `force` / `#delay` / `casex` / `always @(...)` / `always_latch`；`.sva` 中允许 `initial` 做参数校验。
- 代码中不加任何对齐标记，交付前统一跑 `scripts/align.sh`。

### 4.4 自检与仿真命令

```bash
# 1) 秒级文本自检（0 error 才算通过；--lint 可选）
python3 scripts/quality_gate.py rtl/basic/counter.sv
python3 scripts/quality_gate.py rtl/basic/counter.sv --lint

# 2) 功能仿真（不定义 SVA_ON）
mkdir -p build
iverilog -g2012 -o build/counter.simv \
    rtl/basic/dff.sv rtl/basic/dffr.sv rtl/basic/counter.sv \
    tb/basic/counter_tb.sv
vvp build/counter.simv

# 3) 并发断言（有 verilator 时，可选）
verilator --assert -DSVA_ON --binary --top-module counter \
    rtl/basic/*.sv tb/basic/counter_tb.sv -o build/counter_sva

# 4) 强制对齐（需要 rtl_align 插件）
scripts/align.sh rtl/basic/counter.sv
```

`align.sh` 查找顺序：`$RTL_ALIGN_RTP` → `~/.vim/plugged/rtl_align` → `$MY_ENV/vim/rtl_align`。插件不可用时按规范手工对齐，并在交付说明中注明。

### 4.5 验证要求矩阵

| CBB 类型 | 最低验证 | SVA | 仿真器 |
|---|---|---|---|
| 纯组合 / 单级寄存器 / 连线 | 编译 + 一个定向 TB | 可省略 | iverilog |
| 有状态（FIFO / 仲裁 / FSM / CDC / 计数器边界） | 定向 TB + 随机激励 + scoreboard | 协议/FSM/CDC 需要 | iverilog；SVA 用 verilator |
| 复杂数据通路 / 总线 | 架构验证点逐条覆盖 + 边界场景 | 必须 | 优先 verilator，条件不足时说明边界 |

- iverilog 不支持 `assert property`；跑 SVA 时用 verilator `--assert -DSVA_ON`。
- 工具缺失时在交付说明中写清“未仿真 / 未 lint”，不得声称已验证。

## 5. 评审 checklist

- [ ] 文件 / 模块名一致，单文件单 `module`
- [ ] `default_nettype none / wire` 完整
- [ ] 模块头注释字段齐全
- [ ] 端口 ANSI 风格、顺序合规、无方向后缀
- [ ] valid-ready 行为符合约定
- [ ] 控制类寄存器已复位、数据通路寄存器无复位
- [ ] 每个寄存器有明确 `en`，无悬空
- [ ] 实例名全大写，例化端口无逻辑运算式
- [ ] `.sv` 内无断言；有 `.sva` 时已由 `SVA_ON` include
- [ ] `case` 有 `default`，无 latch / 禁用语法
- [ ] `quality_gate.py` 0 error
- [ ] 定向 TB 通过；未跑项已说明
- [ ] 已执行 `align.sh`，对齐幂等
- [ ] `docs/cbb/<module>.md` 已建，端口表 / 参数表 / 使用说明齐全
- [ ] 文档中的端口/参数与 `.sv` 逐项一致
- [ ] 复杂 CBB 的微架构、数据流、状态机、时序/PPA、风险章节已写且与实现一致
- [ ] `cbb-list.md` 状态、依赖、备注已更新

## 6. 交付物与完成定义

**每个 CBB 的最低交付物：**

- `rtl/<category>/<module>.sv`
- `rtl/<category>/<module>.sva`（协议 / FSM / CDC / 参数校验需要时）
- `tb/<category>/<module>_tb.sv`（需要验证时）
- `docs/cbb/<module>.md`（所有 CBB 必备，且仅此一个文档）
- 交付说明：做了什么、跑了哪些检查、哪些没跑

**完成定义（DoD）：** 评审 checklist 全过 + `quality_gate.py` 0 error + 仿真结论明确 + 已对齐 + 文档与实现一致 + 清单状态更新为“已发布”。

不附带 Makefile、覆盖率报告等非模块功能向产物，除非明确要求。

## 7. 版本与维护

- CBB ID 一旦分配不再复用；模块改名需同步更新清单、TB、SVA、`docs/cbb/<module>.md` 和所有依赖。
- 已发布 CBB 的端口 / 参数 / 时序语义变更视为不兼容变更，必须评审、同步模块文档并通知下游。
- 废弃 CBB 在清单中标记“已废弃”，保留至少一个发布周期后再删除。
- `my_env` 的编码规范或脚本更新后，通过独立 PR 同步 `scripts/` 与本文档，避免两套规则漂移。

## 8. 与 my_env 的关系

| 内容 | 来源 | 本项目处理方式 |
|---|---|---|
| 编码规范 | `my_env/skills/rtl-developer/references/rtl-coding-standard.md` | 本指南摘要引用，细则以 my_env 为准 |
| 基础模板 | `my_env/skills/rtl-developer/templates/` | 开发时复制改名，不重复维护 |
| 质量门控 | `my_env/.../scripts/quality_gate.py` | 已复制到 `scripts/`，保证仓库自包含 |
| 对齐脚本 | `my_env/.../scripts/align.sh` | 已复制并适配路径查找 |

# CBB 开发流程指南

> 定位：外网个人小项目，暂按单时钟全同步；流程轻量，先跑通闭环。
> 基线：`my_env/skills/rtl-developer`，编码细则以其规范为准。
> 不强制覆盖率/回归/形式化；没跑仿真就写“未跑”，不伪造结果。CDC 保持 P4，无需求不启动。

## 1. 目录与命名

```text
cbb_proj/
├── docs/{development-guide.md, cbb-list.md, cbb/, architecture/}
├── rtl/<category>/              # 可综合 RTL
├── tb/<category>/               # 定向 TB
├── vendor/my_env/               # git submodule：skill / agent / 规范 / 模板 / 对齐插件
├── scripts/                     # 薄包装，委托 vendor/my_env 里的 quality_gate.py / align.sh
└── build/                       # 仿真产物，git 忽略
```

`vendor/my_env` 固定到一个提交；更新底层：`git submodule update --remote --merge vendor/my_env` 后提交。skill / agent 只放在子模块里，注册到 `~/.claude` 由使用者自行完成。

| 目录 | 放什么 |
|---|---|
| `rtl/basic` | DFF、复位、计数器、边沿/脉冲、自动时钟门控 |
| `rtl/cdc` | CDC 同步、异步 FIFO（P4，无需求不启动） |
| `rtl/memory` | 同步 FIFO、RAM/ROM 包装 |
| `rtl/stream` | valid-ready 流控、`reg_slice`、位宽转换、接口适配、流整形 |
| `rtl/order` | `link_list` 链表、`idpool` 保序资源池 |
| `rtl/arbiter` | `arbiter_*`、`arbiter_wrapper`、`arbmux` / `strmux` |
| `rtl/bus` | APB / AXI-Lite 粘合逻辑 |
| `rtl/io` | UART / SPI / I2C / Timer / IRQ |
| `rtl/util` | CRC、格雷码、`ohot_pri_enc`、`bin2ohot` / `ohot2bin`、mux |

文档：简单件用 `docs/cbb/_template_simple.md`，复杂件用 `docs/cbb/_template.md`，规则见 [`cbb/README.md`](cbb/README.md)。

命名硬约束：

- 模块名与文件名一致，小写蛇形；一个文件一个 `module`。
- 实例名全大写（`U_*`）；TB 用 `_tb.sv`，断言用 `.sva`。
- 端口无 `_i` / `_o` 后缀；按 `clk/rst → 配置 → 输入 → 输出 → 状态` 排序。
- 控制类寄存器用 `dffr`，数据通路寄存器用 `dff`，均显式 `en`。

## 2. 准入条件

开工前只检查两条：

1. 已在 [cbb-list.md](cbb-list.md) 登记，有唯一 ID、优先级、依赖。
2. 端口、参数、复位、valid-ready 行为已说清；复杂件先在文档中写微架构/状态机章节。

## 3. 开发流程

```text
实现 → 自检/仿真/对齐 → 文档收尾
```

| 步骤 | 动作 | 退出条件 |
|---|---|---|
| 1. 实现 | 建 `docs/cbb/<module>.md`，写 RTL 和定向 TB | 代码可编译；文档端口/参数与实际一致 |
| 2. 自检/仿真/对齐 | `quality_gate.py`、iverilog/verilator、`align.sh` | 0 error；TB PASS 或写清未跑项 |
| 3. 文档收尾 | 补验证状态，更新 `cbb-list.md`，与 RTL 同一次提交 | 状态、依赖、备注一致 |

复杂度判定：

- **简单件**：单时钟、端口 ≤ 20、状态 < 4、无 FIFO / 状态化仲裁 / 协议 / CDC，用 `_template_simple.md`。
- **复杂件**：其余情况，用 `_template.md`，先补微架构、数据流、状态机、时序/PPA、风险。

## 4. 实现约定

- `module` 前首个非注释内容为 `` `default_nettype none ``，文件末尾 `` `default_nettype wire ``。
- 模块头注释必须含 `Module / Description / Features / Parameters / Limitations`。
- `valid` 与 `data` 同周期；`vld` 不依赖 `rdy`。
- 组合逻辑用 `always_comb` + 默认值；`case` 必须有 `default`。
- 禁止 `initial` / `force` / `#delay` / `casex` / `always @(...)` / `always_latch`。
- **latch 唯一例外**：`icg` 行为模型可在 `always_latch` 同行加 `// gate: allow-latch`，`quality_gate.py` 行级跳过。
- 模块 `.sv` 内不写断言；需要时建同名 `.sva`，用 `` `ifdef SVA_ON `` include。
- 代码中不加对齐标记，交付前统一跑 `scripts/align.sh`。

## 5. 自检与仿真命令

```bash
# 1) 秒级文本自检（0 error 才算通过）
python3 scripts/quality_gate.py rtl/basic/counter.sv
python3 scripts/quality_gate.py rtl/basic/counter.sv --lint

# 2) 功能仿真
mkdir -p build
iverilog -g2012 -o build/counter.simv \
    rtl/basic/dff.sv rtl/basic/dffr.sv rtl/basic/counter.sv \
    tb/basic/counter_tb.sv
vvp build/counter.simv

# 3) SVA（可选；Verilator >= 5.0）
verilator --assert -DSVA_ON --binary --timing --top-module counter_tb \
    rtl/basic/*.sv tb/basic/counter_tb.sv
# Verilator 4.x 不支持 --binary / --timing，只做 lint：
# verilator --lint-only -Wall --top-module counter_tb rtl/basic/*.sv tb/basic/counter_tb.sv

# 4) 强制对齐
scripts/align.sh rtl/basic/counter.sv
```

`align.sh` 查找顺序：`$RTL_ALIGN_RTP` → `vendor/my_env/vim/rtl_align` → `~/.vim/plugged/rtl_align`。

## 6. 评审 checklist

- [ ] 文件/模块名一致，单文件单 `module`，`default_nettype` 完整，无禁用语法
- [ ] 端口、参数、复位、valid-ready 行为与文档逐项一致
- [ ] `quality_gate.py` 0 error（latch 豁免仅限 `icg` 模型）
- [ ] 定向 TB 通过；SVA 按需；未跑项已说明
- [ ] `align.sh` 通过；文档与 RTL 同一次提交，清单状态已更新

## 7. 交付与完成

每个 CBB 交付：`rtl/<cat>/<module>.sv`、按需 `_tb.sv` / `.sva`、`docs/cbb/<module>.md`、交付说明。
**完成定义**：checklist 全过 + `quality_gate.py` 0 error + 仿真结论明确 + 已对齐 + 文档与实现一致 + 清单状态更新。
CBB ID 不复用；已发布件语义变更视为不兼容，必须评审。

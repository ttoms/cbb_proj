# cbb_proj

可复用数字 IC 公共构建模块（CBB）库，开发基线来自 `my_env` 仓库的 `rtl-developer` skill。

当前已完成**首批 14 项 CBB**（P0 基础件 4 项 + P1 简单件 10 项）、**第二批 9 项**（`reg_slice`、`arbiter_rr` / `wrr` / `lru` / `qrr`、`arbiter_wrapper`、`clkgate`、`arbmux`、`strmux`）与**第三批 3 项简单件**（`ohot_pri_enc`、`gray_conv`、`parity`）。业务模块的寄存器统一例化 `dff` / `dffr`，全部通过质量门控与定向仿真。

## 目录框架

```text
cbb_proj/
├── docs/
│   ├── development-guide.md     # 开发流程指南
│   ├── cbb-list.md              # 待开发 CBB 清单 / 状态
│   ├── cbb/                     # 每个 CBB 的文档
│   │   ├── README.md            # 文档规范与索引
│   │   ├── _template_simple.md  # 简单件模板（6 章）
│   │   ├── _template.md         # 复杂件模板
│   │   └── <module>.md          # 每个 CBB 唯一文档
│   └── architecture/            # 跨 CBB / 子系统级架构方案
├── rtl/
│   ├── basic/                   # DFF / 复位 / 计数器 / 边沿脉冲 / 时钟门控
│   ├── cdc/                     # CDC 同步 / 异步 FIFO
│   ├── memory/                  # 同步 FIFO / RAM / ROM 包装
│   ├── stream/                  # valid-ready 流控 / reg_slice / 位宽转换 / intf_rx/tx / flow_shaper
│   ├── order/                   # link_list 链表 / idpool 保序资源池
│   ├── arbiter/                 # arbiter_* 仲裁核 / arbiter_wrapper / arbmux / strmux
│   ├── bus/                     # APB / AXI-Lite 粘合逻辑
│   ├── io/                      # UART / SPI / I2C / Timer / IRQ
│   └── util/                    # CRC / 格雷码 / 编码器 / bin-ohot / mux
├── tb/<category>/               # 与 rtl 同构的定向 testbench
├── build/                       # 本地仿真产物（git 忽略）
└── .gitignore
```

## 前置依赖

本项目不自带 skill / agent / 质量门控脚本，使用前先在机器上安装 `my_env` 并注册到 Claude Code：

```bash
git clone git@github.com:ttoms/my_env.git ~/Documents/repo/my_env
ln -sfn ~/Documents/repo/my_env/skills/rtl-developer ~/.claude/skills/rtl-developer
mkdir -p ~/.claude/agents
for a in rtl-architect rtl-developer rtl-verifier; do
    ln -sfn ~/Documents/repo/my_env/agents/$a.md ~/.claude/agents/$a.md
done
```

之后更新底层只需 `git -C ~/Documents/repo/my_env pull`，所有项目共用这一份。
本文档后续命令用 `$SKILL` 指代全局 skill：

```bash
export SKILL=~/.claude/skills/rtl-developer
```

## 文档

- [开发流程指南](docs/development-guide.md)：准入条件、复杂度分级、实现约束、自检/仿真、评审与交付。
- [待开发 CBB 清单](docs/cbb-list.md)：50 项规划，含 P0 模板收编、P1~P3 待开发项、P4 CDC 与合并项。
- [CBB 文档规范](docs/cbb/README.md)：每模块唯一文档的落点、简单/复杂件章节规则与一致性要求。
- [dff 示例文档](docs/cbb/dff.md)：约 40 行的简单件填写示例。
- 编码规范细则以 `$SKILL/references/rtl-coding-standard.md` 为准（源在 my_env）。

## CBB 文档要求

每个 CBB **只有一个文档**：`docs/cbb/<module>.md`，实现开始时创建。

简单件只写 6 章：功能与范围、端口表、参数表、使用说明、限制、验证状态；基本信息用一行。
复杂件追加：微架构与数据流、状态机、时序/流水线与 PPA、风险与未覆盖项、版本记录。

- 模块头注释只是代码内摘要，**不能替代**模块文档。
- 文档与 RTL 同一次变更提交；端口/参数不一致或文档过期，不得标记为“已发布”。
- 模板：[简单件](docs/cbb/_template_simple.md) / [复杂件](docs/cbb/_template.md)；章节规则：[CBB 文档规范](docs/cbb/README.md)。

## 首批目标（已完成）

P0 4 项 + P1 10 个简单件，共 14 项（CDC 不进入首批），均已发布：

- P0 收编：`dff`、`dffr`、`rst_sync`、`fifo_sync`
- P1 开发：`counter`、`edge_det`、`pulse_stretch`、`debounce`、`icg`、`bin2ohot`、`ohot2bin`、`busmux`、`binmux`、`arbiter_pri`
- 第二批：`reg_slice`、`arbiter_rr` / `wrr` / `lru` / `qrr`、`arbiter_wrapper`、`clkgate`、`arbmux` 与 `strmux` 已完成（`reg_slice` 含 `skid_buffer` 模式；`strmux` 支持 `GRAN` flit/packet 粒度）
- 第三批：`ohot_pri_enc`、`gray_conv`、`parity` 三个 P2 简单件已完成

## 快速开始

```bash
# 1) 秒级自检：0 error 才算通过
python3 $SKILL/scripts/quality_gate.py rtl/basic/<module>.sv
python3 $SKILL/scripts/quality_gate.py rtl/basic/<module>.sv --lint   # 有 verilator 时可选

# 3) 功能仿真
mkdir -p build
iverilog -g2012 -o build/<module>.simv \
    rtl/basic/dff.sv rtl/basic/dffr.sv rtl/basic/<module>.sv \
    tb/basic/<module>_tb.sv
vvp build/<module>.simv

# 4) 强制对齐
$SKILL/scripts/align.sh rtl/basic/<module>.sv
```

`align.sh` 通过全局 skill 调用，会自动定位 my_env 的 `vim/rtl_align`；也可用 `$RTL_ALIGN_RTP` 覆盖，最后回退 `~/.vim/plugged/rtl_align`。

## 开发基线

- 模块名小写蛇形、文件名一致，一个文件一个 `module`。
- 控制类寄存器用 `dffr`（异步复位），数据通路寄存器用 `dff`（无复位），均显式 `en`。
- 每个 CBB 只有一个文档 `docs/cbb/<module>.md`；复杂 CBB 在同一文档中补齐微架构、数据流、状态机等章节。
- `.sv` 内不写断言；需要时同名 `.sva`，由 `SVA_ON` 在 `endmodule` 前 include。
- 交付前必须通过 `quality_gate.py`（0 error）并执行 `align.sh`。
- 不默认附带 Makefile、覆盖率报告等非模块功能向产物。

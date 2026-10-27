# cbb_proj

可复用数字 IC 公共构建模块（CBB）库，开发基线来自 `my_env` 仓库的 `rtl-developer` skill。

当前为**初版目录框架**：已建立分类目录、开发流程、质量门控脚本和待开发清单，尚未包含自研 CBB 实现。基础件可先参考 `my_env/skills/rtl-developer/templates/`。

## 目录框架

```text
cbb_proj/
├── docs/
│   ├── development-guide.md     # 开发流程指南
│   ├── cbb-list.md              # 待开发 CBB 清单 / 状态
│   ├── cbb/                     # 每个 CBB 的文档
│   │   ├── README.md            # 文档规范与索引
│   │   ├── _template/           # README / design 模板
│   │   └── <module>/
│   │       ├── README.md        # 所有 CBB 必备：端口/参数/使用说明
│   │       └── design.md        # 复杂 CBB 必备：详细设计
│   └── architecture/            # 跨 CBB / 子系统级架构方案
├── rtl/
│   ├── basic/                   # DFF / 复位 / 计数器 / 边沿脉冲
│   ├── cdc/                     # CDC 同步 / 异步 FIFO
│   ├── memory/                  # 同步 FIFO / RAM / ROM 包装
│   ├── stream/                  # valid-ready 流控 / 流水线 / 位宽转换
│   ├── arbiter/                 # 轮询 / 固定优先级仲裁
│   ├── bus/                     # APB / AXI-Lite 粘合逻辑
│   ├── io/                      # UART / SPI / I2C / Timer / IRQ
│   └── util/                    # CRC / 格雷码 / 编码器
├── tb/<category>/               # 与 rtl 同构的定向 testbench
├── scripts/
│   ├── quality_gate.py          # 秒级文本自检
│   └── align.sh                 # 非交互 RTL 对齐
├── build/                       # 本地仿真产物（git 忽略）
└── .gitignore
```

## 文档

- [开发流程指南](docs/development-guide.md)：准入条件、复杂度分级、实现约束、自检/仿真、评审与交付。
- [待开发 CBB 清单](docs/cbb-list.md)：34 项规划，含 P0 模板收编和 P1~P3 待开发项。
- [CBB 文档规范](docs/cbb/README.md)：每项 CBB 的文档落点、必备章节与一致性要求。
- [dff 示例文档](docs/cbb/dff/README.md)：端口表、参数表、使用说明的填写示例。
- 编码规范细则以 `my_env/skills/rtl-developer/references/rtl-coding-standard.md` 为准。

## CBB 文档要求

每个 CBB 在 `docs/cbb/<module>/` 下维护文档：

| 文档 | 适用对象 | 必备内容 |
|---|---|---|
| `README.md` | 所有 CBB | 功能与范围、端口表、参数表、使用说明/例化示例、复位与 CDC、限制、验证状态、版本记录 |
| `design.md` | 复杂 CBB | 模块划分、微架构、状态机、时序/PPA、复位/CDC、验证计划、风险与变更记录 |

- 模块头注释只是代码内摘要，**不能替代** `README.md`。
- 文档与 RTL 同一次变更提交；端口/参数不一致或文档过期，不得标记为“已发布”。
- 模板：[README 模板](docs/cbb/_template/README.md)、[design 模板](docs/cbb/_template/design.md)。

## 首批目标

P0 + P1 共 13 项：

- P0 收编：`dff`、`dffr`、`rst_sync`、`cdc_2ff`、`fifo_sync`
- P1 开发：`counter`、`edge_det`、`pulse_stretch`、`debounce`、`pri_arbiter`、`rr_arbiter`、`skid_buffer`、`reg_slice`

## 快速开始

```bash
# 1) 指向 my_env（align.sh 找不到插件时需要）
export MY_ENV=/path/to/my_env

# 2) 秒级自检：0 error 才算通过
python3 scripts/quality_gate.py rtl/basic/<module>.sv
python3 scripts/quality_gate.py rtl/basic/<module>.sv --lint   # 有 verilator 时可选

# 3) 功能仿真
mkdir -p build
iverilog -g2012 -o build/<module>.simv \
    rtl/basic/dff.sv rtl/basic/dffr.sv rtl/basic/<module>.sv \
    tb/basic/<module>_tb.sv
vvp build/<module>.simv

# 4) 强制对齐
scripts/align.sh rtl/basic/<module>.sv
```

`align.sh` 查找 `rtl_align` 插件的顺序：`$RTL_ALIGN_RTP` → `~/.vim/plugged/rtl_align` → `$MY_ENV/vim/rtl_align`。

## 开发基线

- 模块名小写蛇形、文件名一致，一个文件一个 `module`。
- 控制类寄存器用 `dffr`（异步复位），数据通路寄存器用 `dff`（无复位），均显式 `en`。
- 每个 CBB 必须有 `docs/cbb/<module>/README.md`；复杂 CBB 另需 `design.md`。
- `.sv` 内不写断言；需要时同名 `.sva`，由 `SVA_ON` 在 `endmodule` 前 include。
- 交付前必须通过 `quality_gate.py`（0 error）并执行 `align.sh`。
- 不默认附带 Makefile、覆盖率报告等非模块功能向产物。

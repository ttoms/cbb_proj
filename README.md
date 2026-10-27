# cbb_proj

可复用数字 IC 公共构建模块（CBB）库，开发基线来自 `my_env` 仓库的 `rtl-developer` skill。

当前为**初版目录框架**：已建立分类目录、开发流程、质量门控脚本和待开发清单，尚未包含自研 CBB 实现。基础件可先参考 `my_env/skills/rtl-developer/templates/`。

## 目录框架

```text
cbb_proj/
├── docs/
│   ├── development-guide.md     # 开发流程指南
│   ├── cbb-list.md              # 待开发 CBB 清单 / 状态
│   └── architecture/            # 复杂 CBB 架构方案
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
- 编码规范细则以 `my_env/skills/rtl-developer/references/rtl-coding-standard.md` 为准。

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
- `.sv` 内不写断言；需要时同名 `.sva`，由 `SVA_ON` 在 `endmodule` 前 include。
- 交付前必须通过 `quality_gate.py`（0 error）并执行 `align.sh`。
- 不默认附带 Makefile、覆盖率报告等非模块功能向产物。

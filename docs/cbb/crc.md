# crc CBB 文档（复杂件）

> 状态：已发布。

## 1. 基本信息 [M]
| 项 | 内容 |
|---|---|
| CBB ID | `CBB-UTIL-001` |
| 模块名 | `crc` |
| 类别 | `util` |
| 状态 | 已发布 |
| 版本 | `v0.1.0` |
| 维护人 | - |
| 更新时间 | 2026-10-28 |

## 2. 功能与范围 [M]
- **功能**：参数化 CRC 生成器，每个 `en` 拍处理 `DATA_W` 位，支持多项式、初值、异或输出、输入/输出位序配置；`DATA_W=1` 即逐位模式。
- **不包含**：不做自动比较/错误上报；不做多通道并行；不做矩阵并行优化（后续按需）；不做 byte enable。
- **典型场景**：链路层 flit 校验、存储/寄存块保护、协议帧 CRC、与软件模型对拍。

## 3. 端口表 [M]
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟 |
| `rst_n` | input | 1 | `clk` | 异步复位、同步释放，低有效 |
| `init` | input | 1 | `clk` | 重新载入 `INIT`，优先级高于 `en` |
| `en` | input | 1 | `clk` | 处理 `data`，每拍 `DATA_W` 位 |
| `data` | input | `DATA_W` | `clk` | 输入数据 |
| `crc_out` | output | `CRC_W` | `clk` | 当前 CRC 结果（组合异或/反射输出） |

无 valid-ready 握手：`init` / `en` 是同步控制信号，由使用方保证与数据对齐；`crc_out` 始终反映 `crc_q` 经 `XOROUT` / `REFOUT` 处理后的值。

## 4. 参数表 [M]
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `CRC_W` | `int` | `32` | `CRC_W >= 1` | CRC 位宽 |
| `POLY` | `logic [CRC_W-1:0]` | `32'h04C11DB7` | 任意 `CRC_W` 位 | 生成多项式低 `CRC_W` 位，`x^CRC_W` 项隐含为 1 |
| `INIT` | `logic [CRC_W-1:0]` | `32'hFFFF_FFFF` | 任意 `CRC_W` 位 | 初值 |
| `XOROUT` | `logic [CRC_W-1:0]` | `32'hFFFF_FFFF` | 任意 `CRC_W` 位 | 输出异或值 |
| `REFIN` | `bit` | `0` | `0` / `1` | 输入位序：0 = MSB 先，1 = LSB 先 |
| `REFOUT` | `bit` | `0` | `0` / `1` | 是否对最终 CRC 做位反转 |
| `DATA_W` | `int` | `8` | `DATA_W >= 1` | 每拍处理位数 |

参数约束：
- `POLY` 采用“低位系数”表示：`POLY[CRC_W-1:0]` 对应 `x^(CRC_W-1) ... x^0`，最高项 `x^CRC_W` 不写。例如 CRC-32 多项式 `0x04C11DB7`。
- `REFIN=1` 时按整个 `DATA_W` 位字反转顺序处理；`DATA_W=8` 时与标准“按字节反射”的 CRC 一致。`DATA_W>8` 且 `REFIN=1` 时，等价于整字 LSB 先，不等于逐字节反射，文档明确该语义。
- `REFOUT` 在 `XOROUT` 之前作用：`crc_out = (REFOUT ? bit_reverse(crc_q) : crc_q) ^ XOROUT`。
- 无推荐上限；`DATA_W` 越大组合路径越长。

## 5. 使用说明 [M]
- **时钟/复位**：单时钟；`rst_n` 异步拉低、同步释放。复位后 `crc_q = INIT`，等价于一次 `init`。
- **控制**：`init` 优先于 `en`，同拍同时有效时只载入 `INIT`，不处理 `data`。
- **延迟/吞吐**：`en` 后一拍 `crc_out` 更新；稳态 1 个 `DATA_W` 字/拍。
- **位序**：标准反射型 CRC（如 CRC-32/ISO-HDLC）用 `DATA_W=8, REFIN=1, REFOUT=1, INIT=0xFFFFFFFF, XOROUT=0xFFFFFFFF`；标准非反射型用 `REFIN=0, REFOUT=0`。
- **校验用法**：计算完数据后把 `crc_out` 与接收到的 CRC 比较；或使用“数据 + CRC 余数”约定，把接收 CRC 也送入后比较固定余数。具体约定由使用方定义，本模块只输出生成结果。
- **限制**：无 byte enable；不自动比较；`DATA_W` 较大时组合路径长。

```systemverilog
crc #(
    .CRC_W   (32),
    .POLY    (32'h04C11DB7),
    .INIT    (32'hFFFF_FFFF),
    .XOROUT  (32'hFFFF_FFFF),
    .REFIN   (1),
    .REFOUT  (1),
    .DATA_W  (8)
) U_CRC (
    .clk     (clk),
    .rst_n   (rst_n),
    .init    (crc_init),
    .en      (crc_en),
    .data    (crc_data),
    .crc_out (crc_out)
);
```

## 6. 复位与 CDC [M]
- **复位**：`crc_q` 用 `dffr`，异步复位值为 `INIT`；没有其他状态寄存器。
- **CDC**：无。单时钟模块。

## 7. 限制与注意 [M]
- 关键路径随 `DATA_W` 线性增长（每 bit 一级 LFSR 递推）；高频场景建议 `DATA_W <= 8`，或后续采用矩阵并行版本。
- `REFIN` 是整字位序，不是逐字节位序；`DATA_W>8` 时按标准协议使用时需确认字节序。
- 不支持中途插入无效字节（无 byte enable / 无 vld 门控）；`en=0` 即暂停。
- 不自动比较，不产生错误标志。
- `POLY` 的表示方式必须与软件模型一致，避免最高项重复。

## 8. 验证状态 [M]
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS（0 error） |
| 定向 TB | `tb/util/crc_tb.sv` PASS，4 组标准向量：CRC-32/ISO-HDLC（`DATA_W=8` 与 `DATA_W=1` 两种，均得 `0xCBF43926`）、CRC-16/CCITT-FALSE（`0x29B1`）、CRC-8/ATM（`0xF4`）；每组先喂 `0xAA` 再 `init`，覆盖 init 优先级 |
| SVA | `crc.sva`：参数检查 + 状态保持/init 优先级断言；需 Verilator 5.x（`--assert -DSVA_ON`） |
| 仿真器 | iverilog 11 通过；对 `always_comb` 内常量 bit-select 有 “constant selects ... all bits will be included” 提示，属敏感表范围提示，不影响标准向量结果 |
| Verilator lint | `--lint-only -Wall` 0 warning |
| 未覆盖项 | `DATA_W>8`、其它多项式/反射组合、复位发生在处理中、门级/综合时序与面积 |

## 9. 微架构与数据流 [C]
- **模块划分**：单模块；`crc_q`（`dffr`）保存状态，组合函数 `crc_step(state, bit)` 完成一次 LFSR 递推，`generate for` / 循环展开 `DATA_W` 次。
- **框图**：

```text
  init -------------------------> [ INIT 选择 ] --> dffr(crc_q) --> [ REFOUT ] --> [ ^ XOROUT ] --> crc_out
                                      ^                  |
                                      |                  v
  en & ~init -------------------------+            DATA_W 次 bit 递推
                                                        ^
  data[DATA_W-1:0] --> (REFIN ? 位反转 : 原序) ----------+
```

- **数据流**：每个 `en` 拍，按 `REFIN` 决定的顺序取 `DATA_W` 位，逐位执行：
  `feedback = crc_q[CRC_W-1] ^ bit; crc_q = (crc_q << 1) ^ (feedback ? POLY : 0);`
  展开后是 `DATA_W` 级串行异或/选择，综合后形成组合逻辑链。
- **关键寄存器/存储体**：

| 名称 | 用途 | 复位 | 更新条件（en） |
|---|---|---|---|
| `crc_q` | CRC 状态 | `dffr` 复位 `INIT` | `init \| en`；`init` 优先 |

- **关键设计决策**：v0.1 用通用位级递推展开，任何多项式都正确、代码简单；代价是 `DATA_W` 级组合延迟。矩阵并行版本（把 `DATA_W` 拍递推展开成 XOR 树）留作后续优化，不进入本版。

## 10. 状态机 [C]
不适用。模块只有一个状态寄存器和纯组合递推，没有多步控制序列。

## 11. 时序、流水线与 PPA [C]
| 场景 | 延迟 | 吞吐 | 说明 |
|---|---|---|---|
| 连续处理 | 1 拍 | 1 字/拍 | `en` 后一拍 `crc_out` 更新 |
| 暂停 | - | 0 | `en=0` 保持状态 |

- **关键路径/流水线**：`DATA_W` 级“异或 + 选择”链；`DATA_W=8` 约 8 级，`DATA_W=32` 约 32 级。可在 `DATA_W` 较大时外接流水或改用矩阵版本。
- **反压路径**：无 valid-ready，无反压。
- **面积/功耗**：约 `CRC_W` 个触发器，组合部分约 `DATA_W * CRC_W / 2` 个异或门；`en=0` 时状态不翻转，可自然省功耗。
- **取舍**：通用性与简单性优先，牺牲大 `DATA_W` 的时序；后续按需增加并行矩阵实现。

## 12. 风险与未覆盖项 [C]
- **风险**：`POLY` 表示、`REFIN/REFOUT` 顺序、字节序三者组合容易出错，必须用标准向量对拍。
- **风险**：`DATA_W>8` 且 `REFIN=1` 的语义不是标准逐字节反射，协议对接时需确认。
- **限制**：大 `DATA_W` 组合路径长；无 byte enable；无自动比较。
- **未覆盖项**：实现前未做任何仿真。

## 13. 版本记录 [M]
| 版本 | 日期 | 变更 | 兼容性 |
|---|---|---|---|
| `v0.1.0` | 2026-10-28 | 初版：架构 + 实现 + 4 组标准向量 | - |

## 14. 相关文档 [O]
- 待开发清单：[`cbb-list.md`](../cbb-list.md)
- 奇偶校验：[`parity.md`](parity.md)

# width_conv CBB 文档（复杂件）

> 状态：已发布。

## 1. 基本信息 [M]
| 项 | 内容 |
|---|---|
| CBB ID | `CBB-STREAM-003` |
| 模块名 | `width_conv` |
| 类别 | `stream` |
| 状态 | 已发布 |
| 版本 | `v0.1.0` |
| 维护人 | - |
| 更新时间 | 2026-10-28 |

## 2. 功能与范围 [M]
- **功能**：整数倍位宽转换（窄↔宽），valid-ready 流接口，用 `keep` 标记宽侧有效 lane、用 `last` 标记 packet 尾拍，支持非整数倍 packet 长度。
- **不包含**：不做非整数倍位宽比（如 24↔32）；不做 CDC；不做 packet 存储/重排；`keep` 为 lane 粒度，不是 byte 粒度。
- **典型场景**：NoC flit 宽度与链路宽度不一致时的数据通路适配、窄总线聚合/拆分、跨模块数据位宽匹配。

## 3. 端口表 [M]
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟 |
| `rst_n` | input | 1 | `clk` | 异步复位、同步释放，低有效 |
| `in_vld` | input | 1 | `clk` | 输入有效，与 `in_data` / `in_keep` / `in_last` 同周期 |
| `in_rdy` | output | 1 | `clk` | 输入就绪 |
| `in_data` | input | `IN_W` | `clk` | 输入数据 |
| `in_keep` | input | `KEEP_IN_W` | `clk` | 宽侧输入 lane 有效掩码；窄侧输入固定为 1 bit，必须接 1 |
| `in_last` | input | 1 | `clk` | 输入 packet 尾拍 |
| `out_vld` | output | 1 | `clk` | 输出有效 |
| `out_rdy` | input | 1 | `clk` | 输出就绪 |
| `out_data` | output | `OUT_W` | `clk` | 输出数据 |
| `out_keep` | output | `KEEP_OUT_W` | `clk` | 宽侧输出 lane 有效掩码；窄侧输出固定为 1 bit，恒为 1 |
| `out_last` | output | 1 | `clk` | 输出 packet 尾拍 |

其中：
- `NARROW_W = min(IN_W, OUT_W)`，`WIDE_W = max(IN_W, OUT_W)`，`R = WIDE_W / NARROW_W`。
- `KEEP_IN_W = (IN_W > OUT_W) ? R : 1`，`KEEP_OUT_W = (OUT_W > IN_W) ? R : 1`。
- `IN_W < OUT_W` 时为窄→宽（N2W）；`IN_W > OUT_W` 时为宽→窄（W2N）；`IN_W == OUT_W` 时为直通。

valid-ready 约定：`vld` 与 `data/keep/last` 同周期，`vld` 不依赖 `rdy`；传输成立条件为 `vld && rdy`；不丢数、不重复、不制造假 valid。

## 4. 参数表 [M]
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `IN_W` | `int` | `32` | `IN_W >= 1` | 输入位宽 |
| `OUT_W` | `int` | `64` | `OUT_W >= 1` | 输出位宽 |

参数约束：
- `IN_W == OUT_W`（直通）或 `max(IN_W,OUT_W) % min(IN_W,OUT_W) == 0`；否则为非法配置，由参数检查 SVA 报错。
- 位宽比必须是整数倍；“非整数倍”指 packet 长度不必是 `R` 的整数倍，由 `keep` / `last` 处理，不是指 `IN_W/OUT_W` 可以非整数。
- `R` 由参数派生，不单独配置；不对 `R` 设推荐上限，面积随 `R` 线性增长。

## 5. 使用说明 [M]
- **时钟/复位**：单时钟；`rst_n` 异步拉低、同步释放，建议由 `rst_sync` 产生。复位清 valid / 计数器 / `last` 寄存器，不清数据寄存器。
- **N2W 延迟/吞吐**：第 `R` 个窄拍（或 `in_last` 提前到来）当拍组合形成宽字输出；首拍输入到宽字输出为 `R-1` 拍延迟，稳态 1 个宽字 / `R` 拍。
- **W2N 延迟/吞吐**：宽字寄存后逐 lane 输出，首 lane 延迟 1 拍，稳态 1 个窄拍/拍。
- **反压**：N2W 非完成拍 `in_rdy=1`；完成拍 `in_rdy = out_rdy`，下游不 ready 时上游保持当前窄拍，`acc` 已存内容不变。W2N 在缓冲占用期间 `in_rdy=0`，最后 lane 被读走的同拍允许装入下一宽字。
- **keep 约束**：宽侧 `keep` 必须从 lane 0 起连续为 1 且至少一位为 1；N2W 由模块产生连续掩码，W2N 要求上游满足该约束。
- **last 约束**：每个 packet 的最后一拍必须 `last=1`；N2W 若始终不置 `last`，只有凑满 `R` 拍的整组会被输出，尾部窄拍会滞留，属使用错误。
- **初始化**：复位后所有 valid 为 0，计数为 0。

```systemverilog
width_conv #(
    .IN_W  (32),
    .OUT_W (64)
) U_WIDTH_CONV (
    .clk      (clk),
    .rst_n    (rst_n),
    .in_vld   (narrow_vld),
    .in_rdy   (narrow_rdy),
    .in_data  (narrow_data),
    .in_keep  (1'b1),
    .in_last  (narrow_last),
    .out_vld  (wide_vld),
    .out_rdy  (wide_rdy),
    .out_data (wide_data),
    .out_keep (wide_keep),
    .out_last (wide_last)
);
```

## 6. 复位与 CDC [M]
- **复位**：控制状态（`acc_cnt`、`buf_vld`、`lane_cnt`、`buf_last`、`nxt_*`）用 `dffr` 复位为 0；数据寄存器 `acc_data`、`buf_data`、`buf_keep` 用 `dff`，不复位，未填充 lane 由 `keep` 屏蔽。
- **CDC**：无。单时钟模块。

## 7. 限制与注意 [M]
- 仅支持整数倍位宽比；非整数倍需外部速率匹配/缓冲。
- `keep` 只支持从 lane 0 起的连续掩码；不支持中间空洞。
- 不做 packet 边界存储；`last` 只用于尾拍对齐。
- N2W 完成拍存在 `out_rdy → in_rdy` 组合路径；需要切断时在外部加 `reg_slice`。
- N2W 未填充 lane 的数据是 don't-care，仿真中可能是 X，下游必须用 `keep` 屏蔽。
- `R` 很大时，N2W 的累加寄存器与写选择、W2N 的读 slice mux 面积/延迟线性或对数增长。

## 8. 验证状态 [M]
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS（0 error） |
| 定向 TB | `tb/stream/width_conv_up_tb.sv` PASS（8→32，packet 长度 1/4/5/3/8，随机反压，keep/last 逐 lane 检查）；`width_conv_down_tb.sv` PASS（32→8，keep 4'b1111/0011/1111/0001/0111，随机反压，同拍换字）；`width_conv_bypass_tb.sv` PASS（16→16，200 拍随机直通） |
| SVA | `width_conv.sva`：参数检查 + keep 非零/连续断言；需 Verilator 5.x（`--assert -DSVA_ON`） |
| 仿真器 | iverilog 11 通过 |
| Verilator lint | `--lint-only -Wall` 2 条 UNUSED：窄侧 `in_keep` 保留位、`cnt_oh` 最高位；均为接口/编码冗余，无功能影响 |
| 未覆盖项 | `RATIO=2/3/5` 等其它比例、非连续 keep 的负向测试、复位发生在传输中、门级/综合时序与面积 |

## 9. 微架构与数据流 [C]
- **模块划分**：单模块，`generate case` 分 N2W / W2N / 直通三个分支；分支内例化 `dff` / `dffr`，lane 写使能复用 `bin2ohot`。
- **框图**：

```text
N2W（IN_W < OUT_W）:
  in_data --> +-----------------------------+
              | acc_data[R-1 lanes] (dff)    |
              |   lane 写使能 = bin2ohot(cnt)|
              +--------------+--------------+
                             |  \ 
  in_data -------------------+   \--> 宽字组装（mask OR）--> out_data
  cnt(dffr) -----------------+   /                          out_keep = 低位连续掩码
  in_last -----------------------/                           out_last = in_last
  completing = (cnt == R-1) || in_last
  out_vld = in_vld && completing
  in_rdy  = completing ? out_rdy : 1'b1

W2N（IN_W > OUT_W）:
  in_data --> buf_data(dff) ----------------------\
  in_keep --> buf_keep(dff) --> last_lane 编码     +--> slice mux --> out_data
  lane_cnt(dffr) ----------------------------------/              out_keep = 1
  buf_vld(dffr) --> out_vld                                       out_last = buf_last && (lane_cnt == last_lane)
  in_rdy = ~buf_vld | (out_fire && (lane_cnt == last_lane))
```

- **数据流**：
  - **N2W**：窄拍按 lane 写入 `acc_data`；当前拍与已存 lane 在完成拍组合拼成宽字。`out_keep` 是 `cnt+1` 位低位连续掩码；`out_last` 直接取自当前拍 `in_last`。只有完成拍才需要 `out_rdy`，所以完成拍 `in_rdy=out_rdy`；上游在反压时保持当前拍，无需额外 skid 寄存器。
  - **W2N**：宽字连同 `keep/last` 装入缓冲；按 `lane_cnt` 选择窄 slice 输出，`last_lane` 由 `keep` 的最高有效 lane 得到（要求连续掩码）。最后 lane 被读走的同拍允许装入下一宽字，保持 1 窄拍/拍。
  - **直通**：`IN_W == OUT_W` 时 `out_vld=in_vld`、`in_rdy=out_rdy`、data/keep/last 直连。
- **关键寄存器/存储体**：

| 名称 | 用途 | 复位 | 更新条件（en） |
|---|---|---|---|
| `acc_data` | N2W 已累积 lane，`R-1` 个 lane | `dff` 不复位 | 非完成拍 `in_fire`，按 `bin2ohot(cnt)` 写 lane |
| `acc_cnt` | N2W 已累积拍数，`0..R-1` | `dffr` 复位 0 | 非完成拍 `in_fire` 加 1；完成拍 `in_fire` 清 0 |
| `buf_data` | W2N 当前宽字 | `dff` 不复位 | 装入新宽字 |
| `buf_keep` | W2N 当前宽字 lane 掩码 | `dff` 不复位 | 装入新宽字 |
| `buf_last` | W2N 当前宽字是否 packet 尾 | `dffr` 复位 0 | 装入新宽字 |
| `buf_vld` | W2N 缓冲有效 | `dffr` 复位 0 | 装入置 1；最后 lane 读走清 0 |
| `lane_cnt` | W2N 当前输出 lane | `dffr` 复位 0 | 装入清 0；每拍 `out_fire` 加 1 |

- **关键设计决策**：N2W 用“已存 `R-1` lane + 当前拍 inline”而不是先写满再输出，避免完成拍额外打拍造成吞吐气泡；W2N 用 1 个宽字缓冲即可维持 1 窄拍/拍；`keep` 采用 lane 粒度而不是 byte 粒度，适配任意位宽与非字节对齐的 flit。

## 10. 状态机 [C]
不适用。模块是数据通路加计数器，没有多步控制序列；`acc_cnt` / `lane_cnt` 只是 lane 位置计数，不是 FSM。

## 11. 时序、流水线与 PPA [C]
| 场景 | 延迟 | 吞吐 | 说明 |
|---|---|---|---|
| N2W 正常流 | 首宽字 `R-1` 拍 | 1 宽字 / `R` 拍 | 完成拍组合输出，无额外打拍 |
| N2W 反压 | 保持 | 0 | 完成拍 `in_rdy=out_rdy`，上游保持 |
| W2N 正常流 | 1 拍 | 1 窄拍/拍 | 宽字寄存后逐 lane 输出 |
| W2N 反压 | 保持 | 0 | 缓冲占用期间 `in_rdy=0`，最后 lane 同拍可换字 |
| 直通 | 0 拍 | 1 项/拍 | 纯连线 |

- **关键路径/流水线**：N2W 关键路径为 `acc_data + in_data` 的 lane 拼接与 `cnt` 译码；W2N 关键路径为 `R:1` slice mux 与 `last_lane` 优先编码。
- **反压路径**：N2W 完成拍 `out_rdy → in_rdy` 为组合；W2N `in_rdy` 依赖 `buf_vld` 与最后 lane 判断，基本为寄存器输出加一个末尾 AND。
- **面积/功耗**：N2W 约 `(R-1)*NARROW_W + log2(R)` 个触发器、lane 写译码与宽字 OR；W2N 约 `WIDE_W + R + log2(R) + 2` 个触发器、`R:1` 读 mux。
- **取舍**：N2W 用组合完成拍换吞吐；W2N 用 1 个宽字缓冲换 1 窄拍/拍。若时序紧张，可在完成拍后加 `reg_slice`，代价是 1 拍延迟。

## 12. 风险与未覆盖项 [C]
- **风险**：`keep` 连续性是接口契约，W2N 遇到空洞掩码会输出无效 lane 或错误 lane 数，需在 SVA/TB 中覆盖并明确。
- **风险**：N2W 的 `last` 若使用方漏置，尾部数据会滞留；文档与断言需明确。
- **风险**：未填充 lane 在仿真中可能为 X，下游必须用 `keep` 屏蔽。
- **限制**：不支持非整数倍位宽比；不做 packet 内 lane 重排。
- **未覆盖项**：实现前未做任何仿真；大 `R` 的时序/面积未评估。

## 13. 版本记录 [M]
| 版本 | 日期 | 变更 | 兼容性 |
|---|---|---|---|
| `v0.1.0` | 2026-10-28 | 初版：架构 + 实现 + 三个定向 TB | - |

## 14. 相关文档 [O]
- 待开发清单：[`cbb-list.md`](../cbb-list.md)
- 打拍/反压：[`reg_slice.md`](reg_slice.md)

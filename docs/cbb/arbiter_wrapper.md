# arbiter_wrapper CBB 文档（复杂件）

## 1. 基本信息 [M]
| 项 | 内容 |
|---|---|
| CBB ID | `CBB-ARB-006` |
| 模块名 | `arbiter_wrapper` |
| 类别 | `arbiter` |
| 状态 | 已发布 |
| 版本 | `v0.1.0` |
| 维护人 | - |
| 更新时间 | 2026-10-27 |

## 2. 功能与范围 [M]
- **功能**：仲裁器统一封装。按 elaboration 参数 `ARB_TYPE` 用 `generate case` 选择 `arbiter_pri` / `arbiter_rr` / `arbiter_wrr` / `arbiter_lru` / `arbiter_qrr` 之一，对外提供统一的 `req/gnt/gnt_vld`（外加 `weight/qos`）接口。
- **不包含**：不实现任何仲裁算法，不复制核内状态；不做运行期类型切换；不做反压/握手。
- **典型场景**：`arbmux` / `strmux` 的上层选通策略可参数化；子系统按场景切换仲裁策略而不改连线。

## 3. 端口表 [M]
| 端口 | 方向 | 位宽 | 时钟域 | 说明 |
|---|---|---|---|---|
| `clk` | input | 1 | - | 时钟；`ARB_FIXED` 不使用 |
| `rst_n` | input | 1 | `clk` | 异步复位、同步释放，低有效；`ARB_FIXED` 不使用 |
| `req` | input | `N` | `clk` | 请求位图，每路 1 bit |
| `weight` | input | `N*WEIGHT_W` | `clk` | 每路权重，扁平打包，第 `i` 路占 `weight[i*WEIGHT_W +: WEIGHT_W]`；仅 `ARB_WRR` 使用，其余类型忽略 |
| `qos` | input | `N*QOS_W` | `clk` | 每路 QoS，扁平打包，第 `i` 路占 `qos[i*QOS_W +: QOS_W]`；仅 `ARB_QRR` 使用，其余类型忽略 |
| `gnt` | output | `N` | `clk` | 独热授权，最多一路有效 |
| `gnt_vld` | output | 1 | `clk` | 有授权时为 1；除 `ARB_WRR`（全零权重）外通常等于 `OR(req)` |

无 valid-ready 握手；`gnt` 为组合输出（`arbiter_rr/wrr/lru/qrr` 内含指针/年龄寄存器），`req` 在授权周期内必须保持有效。

## 4. 参数表 [M]
| 参数 | 类型 | 默认值 | 合法范围 | 说明 |
|---|---|---|---|---|
| `N` | `int` | `4` | `N >= 1` | 请求路数 |
| `ARB_TYPE` | `logic [2:0]` | `3'b001` | `000 ~ 100` | 仲裁类型，见下表 |
| `WEIGHT_W` | `int` | `2` | `WEIGHT_W >= 1` | 权重位宽，仅 `ARB_WRR` 使用 |
| `QOS_W` | `int` | `2` | `QOS_W >= 1` | QoS 位宽，仅 `ARB_QRR` 使用 |

| `ARB_TYPE` | 编码 | 仲裁核 | 语义 |
|---|---:|---|---|
| `ARB_FIXED` | `3'b000` | `arbiter_pri` | 固定优先级，索引小者优先 |
| `ARB_RR` | `3'b001` | `arbiter_rr` | 轮询，长期公平 |
| `ARB_WRR` | `3'b010` | `arbiter_wrr` | 加权轮询，按 `weight` 分配带宽 |
| `ARB_LRU` | `3'b011` | `arbiter_lru` | 最近最少使用优先 |
| `ARB_QRR` | `3'b100` | `arbiter_qrr` | 先按 QoS 分级，同 QoS 内轮询 |

参数约束：`N >= 1`、`WEIGHT_W >= 1`、`QOS_W >= 1`、`ARB_TYPE <= 3'b100` 由 `arbiter_wrapper.sva` 检查；非法 `ARB_TYPE` 在 `generate` 中落到 `default` 分支，输出锁零，仿真期由 SVA `$fatal` 报错。

## 5. 使用说明 [M]
- **时钟/复位**：`ARB_FIXED` 为纯组合，`clk/rst_n` 悬空；其余类型使用单时钟与异步复位，建议 `rst_n` 由 `rst_sync` 产生。
- **延迟/吞吐**：`req → gnt` 组合；每拍最多一个授权，持续请求时 1 次授权/拍。
- **反压**：无。上层（`arbmux` / `strmux`）负责在未握手时保持请求。
- **参数选择**：`ARB_TYPE` 是 elaboration 参数，只综合选中的仲裁核；未使用类型的输入（`weight` / `qos` / `clk` / `rst_n`）在该分支被 `unused_nc` 吸收，避免 lint 悬空告警。
- **限制**：`ARB_WRR` 的 `weight=0` 表示该路不参与，全零时 `gnt_vld=0`；`ARB_QRR` 高 QoS 持续请求可能饿死低 QoS。

```systemverilog
arbiter_wrapper #(
    .N        (4),
    .ARB_TYPE (3'b001),
    .WEIGHT_W (2),
    .QOS_W    (2)
) U_ARB (
    .clk     (clk),
    .rst_n   (rst_n),
    .req     (req),
    .weight  (weight),
    .qos     (qos),
    .gnt     (gnt),
    .gnt_vld (gnt_vld)
);
```

## 6. 复位与 CDC [M]
- **复位**：`ARB_FIXED` 无寄存器；`ARB_RR` / `ARB_WRR` / `ARB_LRU` / `ARB_QRR` 的指针、credit、年龄寄存器由内部 `dffr` 异步复位到 0。
- **CDC**：无。单时钟模块，所有逻辑同域。

## 7. 限制与注意 [M]
- `ARB_TYPE` 不能运行期切换；切换必须重新例化。
- `ARB_FIXED` 的 `clk/rst_n` 不参与逻辑，综合后会悬空，属预期。
- `weight` / `qos` 在非对应类型下被完全忽略，连线可保留但不要依赖其效果。
- `gnt_vld` 在 `ARB_WRR` 全零权重时不等于 `OR(req)`，上层不得用 `gnt_vld == |req` 作为通用假设。
- 请求位图在授权周期内必须稳定；组合撤销请求可能导致 `gnt` 抖动。

## 8. 验证状态 [M]
| 项 | 结果 |
|---|---|
| `quality_gate.py` | PASS（0 error，0 warning） |
| 定向 TB | `tb/arbiter/arbiter_wrapper_tb.sv` PASS：`FIXED N=4/1`、`RR N=4/1`、`WRR N=4 weight={3,0,2,0}`、`LRU N=4`、`QRR N=4 qos={3,1,2,0}`、非法 `ARB_TYPE=3'b101` 共 8 组；每组 200 拍随机 + 全请求背靠背 + 无请求，逐拍与对应仲裁核参考输出比对 |
| SVA | `arbiter_wrapper.sva`：参数检查（`N`/`WEIGHT_W`/`QOS_W`/`ARB_TYPE`）、`gnt` 独热、授权属于请求、有授权必为请求、无请求不得授权；需 Verilator 5.x（`--assert -DSVA_ON`） |
| 仿真器 | iverilog 12.0 PASS；Verilator 5.020（`--assert -DSVA_ON`）PASS；`verilator --lint-only -Wall` 无 WIDTH / UNUSED / %Error |
| 未覆盖项 | 非法 `ARB_TYPE` 仅在 iverilog（未开 `SVA_ON`）下验证锁零，开启 SVA 时按参数检查 `$fatal`；`N > 8`、`req` 为 X/Z、运行期更换类型（不支持）、门级/综合时序与面积、形式化验证 |

## 9. 微架构与数据流 [C]
- **模块划分**：本模块只做参数译码与端口统一，仲裁算法全部在 5 个独立仲裁核内；`generate case` 保证同一时刻只有一个核被 elaborate。
- **框图**：

```text
                    ARB_TYPE[2:0]
                         |
                +--------v---------+
                | generate case    |
                +--+---+---+---+---+
                   |   |   |   |
      +------------+   |   |   +--------------+
      |                |   |                  |
+-----v------+  +------v---+ +------v------+ +------v------+  +------v------+
| arbiter_pri|  |arbiter_rr| |arbiter_wrr  | |arbiter_lru  |  |arbiter_qrr  |
| req -> gnt |  |ptr 轮询  | |credit 加权  | |age 老化     |  |QoS 分组+RR  |
+-----+------+  +----+-----+ +------+------+ +------+------+  +------+------+
      |              |              |               |                |
      +--------------+--------------+---------------+----------------+
                         gnt[N] / gnt_vld
```

- **数据流**：
  - 参数译码：按 `ARB_TYPE` 选中一个 `U_ARB` 分支，其余分支不产生网表。
  - 输入分发：`req` 始终接入选中核；`weight` 只接 WRR，`qos` 只接 QRR；其余输入在该分支被 `unused_nc = &{1'b0, ...}` 吸收。
  - 输出汇聚：选中核的 `gnt` / `gnt_vld` 直接驱动 wrapper 输出，无额外逻辑。
  - 非法类型：`default` 分支把 `gnt` / `gnt_vld` 锁 0，避免未驱动输出。
- **关键寄存器/存储体**：wrapper 自身无寄存器；状态全部位于选中核内部（`ptr` / `credit` / `age`）。

| 名称 | 用途 | 复位 | 更新条件（en） |
|---|---|---|---|
| 选中核内部寄存器 | 由 `ARB_TYPE` 决定（`ptr` / `credit` / `age`） | 选中核的 `dffr` 复位 0 | 由选中核内部决定 |

- **关键设计决策**：wrapper 不复制算法、不加流水，只做零成本抽象；`default` 分支锁零而非悬空，保证非法参数下仿真/综合都有确定行为。

## 10. 状态机 [C]
不适用。wrapper 无自身状态，状态机完全由选中的仲裁核内部实现（`arbiter_rr` 的指针、`arbiter_wrr` 的 credit、`arbiter_lru` 的年龄），详见各核文档。

## 11. 时序、流水线与 PPA [C]
| 场景 | 延迟 | 吞吐 | 说明 |
|---|---|---|---|
| 正常授权 | 组合（0 拍）+ 选中核的组合延迟 | 1 次授权/拍 | wrapper 不引入额外逻辑级 |
| 无请求 | 组合 | 0 | `gnt=0`，核内状态保持 |
| `ARB_FIXED` | 组合 | 1 次授权/拍 | 无时钟、无复位 |

- **关键路径/流水线**：wrapper 只是连线与参数译码，关键路径等于选中核的关键路径（RR 扫描 / WRR credit 选择 / LRU 年龄比较 / QRR QoS 比较）。
- **反压路径**：无。仲裁核不感知下游 ready。
- **面积/功耗**：只实例化一个核，面积等于该核；非选中核不产生网表。`ARB_FIXED` 无寄存器与时钟。
- **取舍**：统一接口换来一次参数化抽象，没有额外延迟/面积；代价是同一份 RTL 例化后只能固定一种策略。

## 12. 风险与未覆盖项 [C]
- **风险**：`weight` / `qos` 接错类型不会报错，只被静默忽略；非法 `ARB_TYPE` 在未开 SVA 的综合流程中会静默输出 0，需靠上层参数约束保证。
- **限制**：单时钟；无背压；运行期不可切换；`ARB_WRR` 全零权重时 `gnt_vld=0`。
- **未覆盖项**：`N > 8`、`req` 为 X/Z、运行期换类型、门级仿真与综合时序/面积、形式化验证。

## 13. 版本记录 [M]
| 版本 | 日期 | 变更 | 兼容性 |
|---|---|---|---|
| `v0.1.0` | 2026-10-27 | 初版：`ARB_TYPE` 五分支封装 + 非法类型锁零 | - |

## 14. 相关文档 [O]
- 待开发清单：[`cbb-list.md`](../cbb-list.md)
- 仲裁家族约束：[`cbb-list.md` §7.2](../cbb-list.md)
- 各仲裁核：[`arbiter_pri.md`](arbiter_pri.md)、[`arbiter_rr.md`](arbiter_rr.md)、[`arbiter_wrr.md`](arbiter_wrr.md)、[`arbiter_lru.md`](arbiter_lru.md)、[`arbiter_qrr.md`](arbiter_qrr.md)
- 编码规范与模板：`my_env` 的 `rtl-developer` skill

# CBB 文档规范

## 1. 一项 CBB 一个文档

- 每个 CBB 只维护一个文档：`docs/cbb/<module>.md`，文件名与 RTL 模块名一致。
- **实现开始时创建文档，不预先建空文件**；文档与 RTL 同一次提交。
- 简单 CBB 用 [`_template_simple.md`](_template_simple.md)；复杂 CBB 用 [`_template.md`](_template.md)。
- `docs/cbb/README.md` 只是规范与索引，不属于任何模块。

## 2. 简单 CBB 必写

基本信息用一行写清 `CBB ID · 模块名 · 类别 · 状态`，正文只写 6 章：

| 章节 | 内容 |
|---|---|
| 功能与范围 | 做什么、不做什么、典型场景 |
| 端口表 | 方向、位宽、时钟域、说明；valid-ready 行为 |
| 参数表 | 默认值、合法范围、约束 |
| 使用说明 | 时钟/复位/初始化、延迟/吞吐、反压/握手、例化 |
| 限制 | 已知限制、不可用法 |
| 验证状态 | `quality_gate.py`、定向 TB、SVA、仿真器、未覆盖项 |

不写维护人、版本记录、相关文档。

## 3. 复杂 CBB 追加

在简单件 6 章之外，必须追加：

| 章节 | 内容 |
|---|---|
| 微架构与数据流 | 模块划分、框图、数据流、关键寄存器 |
| 状态机 | 状态表/转移、编码、异常；无 FSM 写“不适用”及原因 |
| 时序、流水线与 PPA | 延迟/吞吐/反压、关键路径、面积功耗、取舍 |
| 风险与未覆盖项 | 设计风险、限制、未验证场景 |
| 版本记录 | 版本、日期、变更、兼容性 |

`相关文档` 可选。复杂件判定见 [开发流程指南 §3](../development-guide.md#3-开发流程)。

## 4. 状态枚举

`模板已有` / `待开发` / `待架构` / `已发布` / `已废弃`。

- `待开发`：简单 CBB，可直接实现。
- `待架构`：复杂 CBB，先完成微架构/状态机等章节再实现。

## 5. 一致性要求

- 端口表、参数表必须与 `.sv` 逐项一致。
- 复杂件的微架构、状态机、时序章节必须与实现一致。
- 端口、参数或时序语义变化时，同步更新本文档和 `cbb-list.md`。
- 缺少文档或文档过期时，CBB 不得标记为“已发布”。

## 6. 文档索引

| 模块 | CBB ID | 文档 | 类型 |
|---|---|---|---|
| `dff` | CBB-BASIC-001 | [`dff.md`](dff.md) | 简单件范例 |
| `dffr` | CBB-BASIC-002 | [`dffr.md`](dffr.md) | 简单件 |
| `rst_sync` | CBB-BASIC-003 | [`rst_sync.md`](rst_sync.md) | 简单件 |
| `fifo_sync` | CBB-MEM-001 | [`fifo_sync.md`](fifo_sync.md) | 复杂件范例 |
| `counter` | CBB-BASIC-005 | [`counter.md`](counter.md) | 简单件 |
| `edge_det` | CBB-BASIC-006 | [`edge_det.md`](edge_det.md) | 简单件 |
| `pulse_stretch` | CBB-BASIC-007 | [`pulse_stretch.md`](pulse_stretch.md) | 简单件 |
| `debounce` | CBB-BASIC-008 | [`debounce.md`](debounce.md) | 简单件 |
| `icg` | CBB-BASIC-010 | [`icg.md`](icg.md) | 简单件 |
| `bin2ohot` | CBB-UTIL-005 | [`bin2ohot.md`](bin2ohot.md) | 简单件 |
| `ohot2bin` | CBB-UTIL-006 | [`ohot2bin.md`](ohot2bin.md) | 简单件 |
| `busmux` | CBB-UTIL-007 | [`busmux.md`](busmux.md) | 简单件 |
| `binmux` | CBB-UTIL-008 | [`binmux.md`](binmux.md) | 简单件 |
| `arbiter_pri` | CBB-ARB-001 | [`arbiter_pri.md`](arbiter_pri.md) | 简单件 |
| `arbiter_rr` | CBB-ARB-002 | [`arbiter_rr.md`](arbiter_rr.md) | 复杂件 |
| `reg_slice` | CBB-STREAM-002 | [`reg_slice.md`](reg_slice.md) | 复杂件 |

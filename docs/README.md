# DSM IP 文档索引

更新时间：2026-08-09

本目录记录数字发射机 IP 的规格、验证、实现证据、DPD/AI 实验和已知限制。文档只陈述仓库中可追溯的能力，不把 behavioral、OOC 或预布局结果写成板级实测或硅后结论。

## 文档入口

| 文档 | 用途 |
|---|---|
| [SPEC.md](SPEC.md) | 详细产品规格、接口、寄存器、定点和时序契约 |
| [VPLAN.md](VPLAN.md) | 全中文分层验证计划及发布门槛 |
| [PROJECT_GUIDE.md](PROJECT_GUIDE.md) | 工程结构、主链路、构建方式和运行流程 |
| [UPDATE_LOG.md](UPDATE_LOG.md) | 按时间记录的完成度、证据等级、限制和下一步 |
| [PPA_VERIFICATION_RELEASE.md](PPA_VERIFICATION_RELEASE.md) | ZU15EG、28 nm DC、OOC 与 routed 证据 |
| [IP_HANDOFF.md](IP_HANDOFF.md) | AXI、PS/DMA、反馈和软件启动交接 |
| [DPD_AI_DPA.md](DPD_AI_DPA.md) | DPD、behavioral DPA 和 AI 校准的结论 |
| [BP_LITE_LINT_AUDIT.md](BP_LITE_LINT_AUDIT.md) | BP 主 SKU 的 lint 风险与精简决策 |
| [evidence/README.md](evidence/README.md) | 仓库内精简证据索引 |
| [UPDATE_LOG.md](UPDATE_LOG.md) | 经过整理的项目里程碑与最新变更 |

## 当前主线

```text
AXI4-Stream Q1.15 I/Q
 -> Memory-Poly5 4-tap DPD
 -> x32 interpolation
 -> full-precision Fs/4 IF
 -> one-bit BP EFDSM2
 -> rf_bit
```

当前主目标器件为 `xczu15eg-ffvb1156-2-i`，目标时钟为 100 MHz。旧 Zynq-7020 和 ZU48DR 结果仅作为历史对照。

## 阅读原则

- 先读 `UPDATE_LOG.md` 末尾的“当前交付状态”，确认哪些结论已经闭环。
- 再读 `SPEC.md` 和 `VPLAN.md`，确认接口和签核标准。
- 集成时读 `IP_HANDOFF.md` 和 `PROJECT_GUIDE.md`。
- 引用 PPA 或性能数字时必须同时引用其配置和证据目录。
- MATLAB behavioral、ADS、FPGA、ASIC pre-layout 和实测 RF 结果不得混用。

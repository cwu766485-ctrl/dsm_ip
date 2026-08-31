# 文档索引

本目录保存 DSM 数字发射机 IP 的公开交付文档。所有性能、验证和实现结论均以可复现的 RTL、模型、回归或已归档报告为边界；行为级 RF 模型、预布局 ASIC 估算和历史 FPGA 数据不会被表述为实测芯片结果。

| 文档 | 用途 |
|---|---|
| [SPEC.md](SPEC.md) | 主规格：冻结 SKU、接口、定点契约、架构取舍、PPA/CDC 边界、集成约定与后续计划 |
| [VPLAN.md](VPLAN.md) | 验证计划：block/subsystem/system 分层、UVM 矩阵、通过准则、覆盖率和待办 |
| [CRITICAL_PATH_REPORT.md](CRITICAL_PATH_REPORT.md) | 已归档 OOC/routed 时序证据、关键路径证据边界与后续报告要求 |
| [PDK_USAGE_GUIDE.md](PDK_USAGE_GUIDE.md) | 28 nm/40 nm 工艺库的本地使用指引和安全边界 |
| [UPDATE_LOG.md](UPDATE_LOG.md) | 变更记录、执行检查与已知限制 |
| [evidence/README.md](evidence/README.md) | 小型、可公开归档的证据汇总 |

## 冻结主 SKU

```text
Target:       xczu15eg-ffvb1156-2-i
Clock:        100 MHz
Datapath:     Memory-Poly5 (4 taps) -> x32 interpolation
              -> Fs/4 mixer -> one-bit BP EFDSM2
DPD features: memory path enabled; Poly/LUT execution disabled
```

被合并的旧文档不再单独维护。请以 `SPEC.md`、`VPLAN.md` 和 `CRITICAL_PATH_REPORT.md` 为当前来源。

# DSM IP 文档索引

本目录记录 `dsm_ip` 数字发射机 IP 的规格、接口、验证证据、DPD/AI 实验和已知限制。文档只描述仓库中已经实现或明确标注为实验的能力。

## 交付入口

| 文档 | 用途 |
|---|---|
| [SPEC.md](SPEC.md) | 详细产品规格、接口、寄存器、时序、验证和集成要求 |
| [IP_HANDOFF.md](IP_HANDOFF.md) | PS、DMA、AXI、反馈链路和上板交接说明 |
| [PROJECT_GUIDE.md](PROJECT_GUIDE.md) | 工程结构、构建配置和推荐工作流 |
| [STATUS_AND_LIMITS.md](STATUS_AND_LIMITS.md) | 当前状态、证据等级、风险和下一步 |
| [PPA_VERIFICATION_RELEASE.md](PPA_VERIFICATION_RELEASE.md) | FPGA/28 nm DC/RTL 验证证据及发布边界 |
| [DPD_AI_DPA.md](DPD_AI_DPA.md) | behavioral DPA、DPD 和 AI 校准实验结论 |
| [UPDATE_LOG.md](UPDATE_LOG.md) | 按时间记录的实现、验证和调试过程 |

## 阅读顺序

1. 先读 `SPEC.md`，确认接口和参数。
2. 集成 PS/PL 时读 `IP_HANDOFF.md`。
3. 评估当前是否可交付时读 `STATUS_AND_LIMITS.md` 和 `PPA_VERIFICATION_RELEASE.md`。
4. 了解 DPD/AI 研究价值时读 `DPD_AI_DPA.md`。

## 证据原则

- MATLAB behavioral 结果不能称为 ADS 或实测 RF 结果。
- 28 nm DC 是预布局综合估计，不是流片签核。
- Vivado OOC 只有在生成完整 utilization/timing/summary 报告后才算通过。
- AXI/PS 板级验证不能等同于真实 PA 闭环验证。

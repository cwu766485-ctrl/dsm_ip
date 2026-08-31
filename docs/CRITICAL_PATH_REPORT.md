# 时序与关键路径证据报告
## 1. 结论摘要

仓库当前可公开复核的 FPGA 时序证据主要是 `docs/evidence/ooc/` 下的汇总 CSV。它们能够说明不同 OOC 配置在指定器件、指定阶段下的 LUT/FF/DSP、WNS 和由 WNS 推导的估算 Fmax；但大多数汇总文件**不包含原始 `report_timing` 的起点、终点、逻辑级数或 net delay**。

因此，本报告不会编造 FPGA 关键路径端点。当前唯一明确写入历史 ASIC 汇总的关键路径描述是：**Memory-DPD 状态寄存器到 Memory-DPD 算术寄存器**。该结论是 28 nm、预布局、vectorless 的历史综合快照，不是当前 FPGA routed path，也不是 post-layout ASIC 签核。

## 2. 已归档实现证据

| 证据类别 | 器件/工艺与阶段 | 可用结论 | 不可得结论 |
|---|---|---|---|
| DSM/IP AXI post-synthesis OOC | `xczu15eg-ffvb1156-1-i`，综合后 OOC | 资源、WNS、估算 Fmax；例如 EFDSM2 x16/x32 的相对代价 | 精确关键路径端点、布线延迟、板级时序 |
| routed OOC subset | `xczu15eg-ffvb1156-1-i`，routed OOC 子集 | 已选择组合的 routed WNS 与资源 | 冻结主 SKU 的完整 routed signoff；详细起止端点 |
| 历史完整 TX 集成 | `docs/evidence/integration/` 中归档摘要 | 100 MHz 级集成基线和历史资源/时序摘要 | 当前冻结 SKU 的重新实现、bitstream 或板级 closure |
| ASIC 预布局基线 | 28 nm RVT TT，0.9 V、25 C，100 MHz | 历史 cell area、setup/hold 快照和候选算术路径 | 寄生、MCMM、IR/EM、DFT、动态功耗或流片性能 |

不同 speed grade、不同综合阶段、不同 top/feature 配置不可横向当作同一 Fmax。特别是 `-1-i` 的 OOC 汇总不能代替冻结主 SKU `xczu15eg-ffvb1156-2-i` 的 routed implementation 结论。

## 3. 已量化的路径相关事实

### 3.1 插值倍率的 post-synthesis OOC 权衡

归档矩阵显示 BP EFDSM2 主链在 x16 与 x32 插值间存在以下代价：

| 配置 | LUT | FF | DSP | 估算 Fmax |
|---|---:|---:|---:|---:|
| x16 | 7,586 | 7,668 | 936 | 256.15 MHz |
| x32 | 8,037 | 8,215 | 1,278 | 240.79 MHz |

x32 相比 x16 增加 451 LUT、547 FF、342 DSP，估算 Fmax 降低 15.36 MHz。该数据说明补偿 FIR 与高倍率插值算术路径是主链的重要 PPA 负担，但不能凭该汇总断言某个具体 FIR register-to-register 端点是最差路径。

### 3.2 routed OOC 子集

已归档 routed subset 中，若干组合在 100 MHz 目标下具有正 WNS，例如 EFDSM 一比特 bypass、MASH22 native x32 和 MASH111 multibit x32。它们仅用于证明该子集曾完成 routed OOC，不应被改写为完整主 SKU 的 100 MHz routed closure。

### 3.3 历史 ASIC 预布局路径

历史 28 nm 预布局报告记录了约 4.45 ns 的 setup delay，候选关键路径从 Memory-DPD state register 进入 Memory-DPD arithmetic register。这个结果与 Memory-Polynomial DPD 的 tap/radius/complex-coefficient arithmetic 结构一致，但仍需要使用当前标准单元库重新 link、综合、约束并导出原始 report 才能作为新的 ASIC PPA 数据。

## 4. 脚本能力与缺口

`syn/run_performance_sku_routed.tcl` 当前会导出 `report_utilization`、`report_timing_summary` 和 `report_power`。`report_timing_summary` 能给出 slack 概览，但不足以审查精确寄存器端点、逻辑深度和路由占比。

后续完整 implementation 完成后，必须在同一已实现设计上补充并归档：

```tcl
report_timing -delay_type max -max_paths 20 -file timing_paths_max.rpt
report_timing -delay_type min -max_paths 20 -file timing_paths_min.rpt
report_timing_summary -delay_type max -file timing_summary.rpt
report_clock_interaction -file clock_interaction.rpt
```

报告中还应保存 top、器件、speed grade、时钟约束、Vivado 版本、实现策略和 Git revision，避免后续把不同构建的路径混为同一结论。

## 5. 优化优先级

1. 先对冻结的 Memory-Poly5、4-tap、x32、BP EFDSM2 配置跑完整 routed implementation，获取真实 `report_timing` 起止端点。
2. 若关键路径位于 DPD complex multiply/add，优先比较 DSP 输出寄存、adder-tree 分割和 tap 累加流水，同时回归 MATLAB/Python/RTL bit-true 与 backpressure 延迟。
3. 若关键路径位于插值补偿 FIR，比较对称 pre-add、polyphase 分相、常系数映射和分级流水；不要仅通过改变约束掩盖路径。
4. 若关键路径在 AXI/control 或 observer CDC shell，应将控制面与高吞吐 datapath 时钟域/寄存器边界分离，而不是影响已冻结的算术语义。

## 6. 当前限制

本次仅整理已归档证据，未重新运行 Vivado 综合、place-and-route、板级 bitstream 或 ASIC DC。任何后续简历或交付表述应区分 post-synthesis OOC、routed OOC、历史集成基线和预布局 ASIC 估算。

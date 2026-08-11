# PPA 与实现证据报告

更新时间：2026-08-09

## 1. 报告原则

PPA 数字必须同时给出器件或工艺、工具、配置、约束和证据路径。OOC、全 TX routed、pre-layout DC 和真实板级功耗属于不同证据等级，不能相互替代。

## 2. 当前主 SKU

```text
top                 = dsm_ip_axi_top
target              = xczu15eg-ffvb1156-2-i
clock               = 100 MHz
ALGORITHM           = 3
DUC_MODE            = 3
INTERP_MODE         = 4
INTERP_IMPL         = 0
DPD                 = Memory-Poly5, 4 taps
ENABLE_DPD_POLY     = 0
ENABLE_DPD_LUT      = 0
ENABLE_DPD_MEMORY   = 1
```

## 3. ZU15EG DPD OOC 矩阵

证据：`docs/evidence/ooc/dpd_feature_ooc_zu15eg_ffvb1156_2_i_20260725_summary.csv`

| 配置 | LUT | FF | DSP | 100 MHz WNS |
|---|---:|---:|---:|---:|
| bypass | 52 | 75 | 0 | +9.221 ns |
| Poly3 | 471 | 576 | 18 | +7.044 ns |
| Poly5 | 505 | 644 | 26 | +6.572 ns |
| Poly7 | 691 | 676 | 34 | +5.911 ns |
| LUT | 199 | 141 | 4 | +9.163 ns |
| Memory-poly 1 tap | 677 | 873 | 30 | +6.572 ns |
| Memory-poly 2 tap | 1300 | 1620 | 60 | +6.572 ns |
| Memory-poly 4 tap | 2480 | 3058 | 120 | +6.572 ns |
| Memory-poly 6 tap | 3658 | 4494 | 180 | +6.572 ns |
| 开发版全部分支 | 3077 | 3691 | 150 | +6.572 ns |

该矩阵说明 memory depth 近似线性增加 DSP/LUT/FF。主 SKU 选择 5 阶、4 tap 是算法记忆能力与资源之间的工程折中，不代表它对所有 PA 都最优。

## 4. 历史 ZU15EG full-TX routed 基线

证据：`docs/evidence/integration/full_tx_zu15eg_20260726_memory_poly5_4tap_summary.csv`

| 指标 | 结果 |
|---|---:|
| 目标时钟 | 100 MHz |
| Routed WNS / TNS | +2.314 ns / 0 ns |
| LUT / FF / BRAM / DSP | 16296 / 20763 / 3 / 266 |
| Vivado power estimate | 4.114 W |
| bitstream / XSA | 已生成 / 已生成 |

此结果属于 `DUC_MODE=0` 的历史 Cartesian EFDSM + 固定 Fs/4 路线。它证明旧集成工程能够完成 implementation 和 bitstream，但不能证明当前 BP EFDSM2 主 SKU 已 routed 收敛。

## 5. 当前 BP SKU 的 FPGA 状态

Windows Vivado 2024.1 最近一次 BP AXI OOC 在 `synth_design` 阶段异常退出，没有生成完整 utilization/timing/summary。当前不得宣称主 BP SKU 已完成 ZU15EG OOC、routed 或 bitstream signoff。

下一次有效闭环必须同时保存：

- elaborated 参数和 source manifest；
- synth utilization/timing；
- routed utilization/timing；
- DRC、clock interaction 和 CDC/RDC 摘要；
- power estimate；
- bitstream 和 XSA；
- 对应 XSim/板级 smoke 结果。

## 6. 28 nm DC pre-layout

证据：`syn/reports/bp_ef2_axi_28nm_dc_20260805_231629/`

| 项目 | 结果 |
|---|---:|
| 工具 | Synopsys DC V-2023.12-SP1 |
| 库/PVT | TSMC28 RVT NLDM, TT, 0.9 V, 25 C |
| 目标周期 | 10.0 ns |
| Cell area | 125647.956304 |
| Leaf cells | 151170 |
| Sequential / combinational | 24141 / 127029 |
| Critical path | 4.45 ns |
| Setup / hold slack | +5.42 ns / +0.03 ns |
| Dynamic / leakage / total | 8.1476 / 0.0732 / 8.2218 mW |

这些数字不包含物理布局、时钟树、寄生、IR drop、EM、热、多角和硅后测量。

## 7. Lint 状态

证据：`syn/reports/lint_bp_ef2_axi_20260806_214119/`

流程完成且 Error/Fatal 为 0，但存在 signedness、宽度、未连接、常量、短接输出和未加载网络警告。具体分类见 `BP_LITE_LINT_AUDIT.md`。在逐项修复或有依据 waiver 前，不称为 lint-clean。

## 8. 历史器件结果

Zynq-7020 和 ZU48DR 的七种低通 DSM OOC 结果保留在 `docs/evidence/ooc/`，只用于算法结构和器件代际对照。当前产品决策只以 ZU15EG 主 SKU 为目标，不再把 Zynq-7020 作为发布门槛。

## 9. 发布门槛

- RTL：bit-true、协议、reset、backpressure、commit 和 fallback 回归通过；
- FPGA：主目标器件 routed WNS/TNS 达标并生成 bitstream；
- ASIC：无 unmapped logic，警告完成审计，明确标为 pre-layout；
- RF：EVM/SNDR/ACLR 标注 behavioral、ADS、capture 或实测来源；
- DPD：no-DPD、memoryless、memory-poly 使用同一 waveform、PA 和 receiver；
- AI：报告 blind/OOD、安全违规和候选搜索成本，不只报告最好样本。

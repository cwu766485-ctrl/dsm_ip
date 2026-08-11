# 验证证据索引

更新时间：2026-08-09

本目录只保留体积小、可追溯、被正式文档引用的 CSV/JSON/TXT。原始日志、波形、工具缓存、完整工作区和大型报告不进入 Git。

## 1. 当前证据等级

| 类别 | 路径 | 证据等级 |
|---|---|---|
| DPD feature OOC | `ooc/dpd_feature_ooc_zu15eg_ffvb1156_2_i_20260725_summary.csv` | ZU15EG post-synthesis OOC |
| DPD 算法 OOC | `ooc/dpd_ooc_xczu15eg_ffvb1156_1_i_20260725_summary.csv` | 早期器件 speed-grade 对照 |
| 历史 full-TX | `integration/full_tx_zu15eg_20260726_memory_poly5_4tap_summary.csv` | 旧 Cartesian EFDSM/Fs4 routed + bitstream |
| 低通 DSM 历史 | `ooc/p0_*.csv` | Zynq-7020/ZU48DR/ZU15EG OOC 对照 |
| LPDSM2 Fs/4 审计 | `frontend/p0_lp2_fs4_frontend_audit_20260804.csv` | Python 模型审计 |
| BP EFDSM 审计 | `frontend/p0_bp_ef2_frontend_audit_20260804.csv` | Python behavioral 审计 |
| BP 算法对比 | `frontend/p0_bp_dsm_comparison_20260805.csv` | Python behavioral 对比 |
| DPD/AI 离线 | `dpd/` | MATLAB/Python 离线或板级 replay 证据 |
| 100 MHz 历史摘要 | `closure/p0_100mhz_release_summary.csv` | 历史 P0 汇总 |

## 2. 重要边界

### 2.1 历史 full-TX

`full_tx_zu15eg_20260726_memory_poly5_4tap_summary.csv` 对应 `DUC_MODE=0` 的 Cartesian EFDSM + 固定 Fs/4 路线。它包含 routed timing、资源、功耗估计、bitstream 和 XSA，但不是当前 `DUC_MODE=3` BP EFDSM2 主 SKU 的最终证据。

### 2.2 当前主 BP SKU

当前 BP 主 SKU 的 ZU15EG full-TX routed/bitstream 仍待重跑。28 nm DC 和 lint 原始报告位于 `syn/reports/`，因体积和工具生成属性不复制到本目录。

### 2.3 算法指标

- LPDSM2 native complex I/Q EVM 为 0.6891%，但旧 Fs/4 RF 恢复约 94% EVM；两者不能混报。
- 初始 BP EFDSM EVM 3.5638%、SNDR 28.9617 dB，只是 behavioral 审计。
- hard-limited 一位 BP MASH 不满足当前一位 DPA 需求。

### 2.4 AI/DPD

`dpd/` 下的 LOSO、blind、seed、safety 和 replay 文件用于评估低速校准策略。它们不证明高速神经网络 RTL，也不证明真实 PA 的物理改善。

## 3. 引用规则

引用证据时必须同时说明：

- 文件路径；
- 日期和工具；
- 目标器件/工艺；
- compile-time 参数；
- waveform、PA profile 和 receiver；
- OOC、routed、behavioral、ADS 或实测等级。

没有这些信息的数字只能作为调试记录，不能进入 release 结论。

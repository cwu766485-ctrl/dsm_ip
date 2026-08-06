# 项目工程指南

## 1. 项目定位

`dsm_ip` 是可复用的数字 Delta-Sigma Modulator（DSM）与数字预失真（DPD）IP 交付包，目标是形成：

```text
PS/DDR -> AXI DMA -> AXI4-Stream Q1.15 I/Q
       -> DPD -> 插值 -> DSM/数字 IF
       -> 外部重构、IQ 上变频或一位 DPA
```

高速数据路径使用可综合定点 RTL；MATLAB 用于 bit-true 参考、DPD 建模和指标分析；PS 软件用于低速配置、观测和校准策略。AI 是低速校准辅助，不是高速神经网络数据通路。

当前唯一主验证闭环是：

```text
BP EFDSM2 RTL -> rf_bit -> MATLAB behavioral DPA -> observation receiver
               -> DPD quality metrics
```

因此，项目重点是验证 BP EFDSM2 作为一位 DPA 驱动调制器时的数字质量，以及验证针对同一 behavioral DPA 训练的 DPD 是否改善 EVM/SNDR/ACLR proxy。其他 DSM 结构和 DPD 分支属于兼容、历史对照或研究对象。

## 2. 两条 RF 路线

### 路线 A：模拟 IQ 次要集成路线

```text
DPD -> 插值 -> 低通一位 I/Q DSM
     -> 外部重构 LPF -> 模拟 IQ Mixer/LO -> PA
```

使用 `DUC_MODE=2`。此模式输出 `i_bit/q_bit`，`rf_valid` 保持无效。它是实际模拟上变频系统的推荐边界。

### 路线 B：数字 IF / BP EFDSM2 主验证路线

```text
DPD -> x32 插值 -> 全精度 Fs/4 IF Mixer
     -> 一位 BP EFDSM2 -> rf_bit -> 外部 DPA/BPF
```

使用 `ALGORITHM=3, DUC_MODE=3, INTERP_MODE=4`。该路线已经接入 `dsm_ip_top` 和 AXI 顶层，是当前主验证 SKU；其输出后接 behavioral DPA，而不是 ADS 或物理 PA，并使用统一 bit-true/接收机审计。

旧的低通 DSM 后直接做一位 `[+I,+Q,-I,-Q]` 合路不能作为通信性能结论。

## 3. 目录职责

| 路径 | 职责 |
|---|---|
| `rtl/dsm/` | 单环、误差反馈、MASH、低通和多位 DSM |
| `rtl/dpd/` | polynomial、LUT、memory-polynomial、observer 和安全逻辑 |
| `rtl/interp/` | x4/x8/x16/x32 插值滤波器 |
| `rtl/duc/` | 传统 Fs/4/NCO DUC |
| `rtl/tx_bandpass_if/` | 全精度 IF Mixer 与 BP DSM |
| `rtl/ip/` | 可复用 streaming datapath |
| `rtl/axi/` | `dsm_ip_axi_top` AXI-Lite/AXI-Stream 封装 |
| `matlab/` | 定点模型、向量生成、DPD 训练和指标 |
| `verif/` | XSim testbench、向量和回归脚本 |
| `ip/` | Vivado IP 打包 |
| `syn/` | Vivado OOC 和 Synopsys DC 流程 |
| `fpga/` | ZU15EG PS/DMA/ILA 集成 |
| `ads/` | 可选 DPA 电路/数值实验，不是数字 IP 必需项 |
| `docs/evidence/` | 精简、可追溯的验证证据 |

## 4. 推荐发布 SKU

| 参数 | 主 BP SKU |
|---|---:|
| `ALGORITHM` | 3，EFDSM2 标识；BP 分支实际使用 `BP_ALGORITHM=1` |
| `DUC_MODE` | 3 |
| `INTERP_MODE` | 4，x32 |
| `INTERP_IMPL` | 0 |
| DPD | 针对 behavioral DPA 的 Q2.14 memory-polynomial，C1/C3/C5，4 taps |
| `ENABLE_DPD_POLY` | 0 |
| `ENABLE_DPD_LUT` | 0 |
| `ENABLE_DPD_MEMORY` | 1 |
| 时钟 | 100 MHz |
| 输入 | 3.125 MS/s 复数 Q1.15 |

注意：`ALGORITHM/DUC_MODE/INTERP_MODE` 是编译期参数，寄存器只用于读取 build identity，不是运行时切换开关。

## 5. 必要检查

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_all_dsm.ps1 -Part xc7z020clg400-1
```

28 nm DC 和 SpyGlass/VCS 需要 Linux EDA 环境。工具不可用或崩溃时必须记录为未完成，不得伪造通过结果。

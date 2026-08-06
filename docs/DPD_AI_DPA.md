# DPD、AI 校准与 DPA 仿真报告

## 主线结论

本报告服务于一条明确主线：**BP EFDSM2 是 RTL/数字 IF 的主验证 DSM，behavioral DPA 是 DPD 训练和性能比较的被测对象**。DPD 不是针对抽象的理想 PA 训练，也不把 ADS 电路结果和 MATLAB 结果混用。

## 1. 研究边界

本项目的 DPA 目前主要是 MATLAB behavioral endpoint，用来给 DPD 提供增益误差、压缩、AM/AM、AM/PM、记忆、噪声、温漂和观测反馈。DPD 系数和 AI seed 的训练、验证必须基于这个冻结 behavioral DPA 配置。ADS/PDK 电路实验是可选辅助证据，不是当前 DPD 主门槛。

## 2. DPD 模型

当前比较对象：

1. no-DPD；
2. Q2.14 memoryless polynomial，C1/C3/C5；
3. Q2.14 memory-polynomial，默认 4 taps、C1/C3/C5；
4. LUT seed 或 AI seed 加确定性局部搜索。

RTL 高速路径是确定性的；AI 在低速控制环节预测安全 seed/package 或搜索起点，不替代 DPD datapath，也不直接开放不安全的一候选直通。

## 3. 结果分层

历史 `legacy_full` 诊断结果：no-DPD EVM 57.6301%，memoryless 39.3549%，memory-polynomial 39.3549%。该结果同时叠加了多个 impairment，数字链路基线未先验证健康，不能作为通信能力结论。

正式 staged behavioral 结果保存在 `matlab/out/dpd/staged_formal_20260804/`。线性等效链路 EVM 接近零；加入噪声阶段为 EVM 0.5979%、SNDR 44.4704 dB。AM/PM 阶段 DPD 从 0.3522% 改善至 0.3447%；AM/AM 和 memory 阶段 held-out 改善不显著，因此尚未发布新的 memory-polynomial 系数包。

另一组独立 behavioral memory-PA 研究曾得到 no-DPD 到 4-tap memory-poly 的平均 EVM 4.3050% 到 2.8278%，零 saturation/drive limiting；由于波形和 PA profile 不同，不能与 staged formal 表合并。

## 4. 数字 IF 路线

当前 BP 路线为：

```text
复数 Q1.15 -> DPD -> x32 插值 -> 全精度 Fs/4 IF
-> 一位 BP EFDSM2 -> rf_bit -> 外部 DPA/BPF
```

同一 P0 向量的初始 BP EFDSM 算法审计为 EVM 3.5638%、SNDR 28.9617 dB；BP single-loop 为 EVM 3.6597%、SNDR 28.7312 dB。BP MASH 需要多电平输出，硬限成一位会破坏噪声抵消，因此不是当前一位 DPA 候选。

BP 结果仍需 fixed-point RTL 等价、VCS/XSim、DPA behavioral 闭环和统一接收机审计；不能把该数字结果称作 ADS 或实测 RF。

## 5. AI 校准策略

```text
monitor/condition state
 -> 安全优先 seed/package 建议
 -> 确定性安全仲裁
 -> 14-candidate bounded local search
 -> 最终 replay 与安全计数检查
```

盲测 profile 永久隔离，不参与训练、门限选择或模型选择。AI 的评价目标是 unknown PA 下 seed 是否安全以及是否减少校准成本，不是单纯选择预测成本最低的 package。真实安全仍由 RTL/PS 的 deterministic gate 和局部搜索保证。

## 6. DPA 效率口径

Python 有限损耗筛选中的 3.3 V、25.044 MHz 点为 13.388 mW Pout、14.218 mW Pdc、94.165% 数值效率；89.109% 和 81.339% 是更大 RON/寄生/驱动损耗假设下的 sensitivity cases。它们不是 ADS、PDK、layout、silicon 或实测结果。

ADS PWL/PDK-MOS 流曾得到 256 bit transient 的约 -3.80 dBm、1.433 mW DC、约 29.06% pre-layout efficiency trend；这与 Python ideal/finite-loss screening 不能混用。

## 7. 可复现实验

```matlab
cd('E:/workspace/chip/dsm_ip/matlab');
path_setup;
run('scripts/entry_lpdsmdpa_bpf_dpd_closed_loop.m');
```

任何结果都必须注明 waveform、PA profile、训练/验证/测试划分、模型、量化格式、接收机和指标定义。

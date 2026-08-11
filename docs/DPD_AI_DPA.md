# DPD、AI 校准与 DPA 实验报告

更新时间：2026-08-09

## 1. 当前架构

```text
Q1.15 I/Q -> DPD -> x32 interpolation -> Fs/4 IF
           -> one-bit BP EFDSM2 -> rf_bit
           -> behavioral DPA/BPF
           -> observation receiver
           -> metrics -> PS/Python calibration
```

RTL 的高速数据通路是确定性的。AI/优化位于低速控制面，用于建议系数初值或候选 package；最终系数必须经过安全检查、有界搜索和原子 commit。

## 2. DPD 实现

仓库实现：

- bypass；
- memoryless polynomial 3/5/7 阶；
- LUT DPD；
- memory-polynomial 1/2/4/6 tap；
- Q2.14 系数、饱和检测、双 bank 和安全回退。

主 SKU 选择 Memory-Poly5 4-tap。原因是它能够描述有限 PA memory，同时资源明显低于 6 tap；是否最终采用必须由目标 PA sweep 和 PPA 共同决定。

## 3. behavioral DPA

MATLAB 模型可包含 AM/AM、AM/PM、压缩、memory、频响、噪声、温漂、clipping 和 observation receiver mismatch。每个结论必须冻结 PA profile、输入波形、backoff、BPF、receiver、数据分割和 seed。

behavioral DPA 是算法开发端点，不是 ADS 电路或实测 PA。ADS/PDK-MOS、Python screening 和 MATLAB behavioral 结果必须分别报告。

## 4. 已有结果

### 4.1 staged formal

结果位于 `matlab/out/dpd/staged_formal_20260804/`。线性等效链路 EVM 接近零；加入噪声后 EVM 0.5979%、SNDR 44.4704 dB；AM/PM 阶段 DPD 将 EVM 从 0.3522% 改善到 0.3447%。在 AM/AM 和 memory 阶段，held-out 改善不显著，因此没有发布新的通用 memory-poly 系数包。

### 4.2 独立 memory-PA 研究

另一组冻结 profile 上，no-DPD 到 4-tap memory-poly 的平均 EVM 从 4.3050% 改善到 2.8278%，且没有 saturation/drive limiting。由于 profile 和波形与 staged formal 不同，两个结果不能合并。

### 4.3 BP 前端

初始 BP EFDSM behavioral 审计为 EVM 3.5638%、SNDR 28.9617 dB；BP single-loop 为 3.6597%、28.7312 dB。硬限幅的一位 BP MASH 破坏多电平噪声抵消，不适合作为当前一位 DPA 候选。

这些数字不是完整 fixed-point RTL、ADS 或实测 RF 结果。

### 4.4 DPA 电路趋势

- Python 有限损耗筛选中的最佳点约为 84.165% 数值效率；这是参数化筛选，不是电路签核。
- ADS PWL/PDK-MOS 的短 transient 曾得到约 -3.80 dBm、1.433 mW DC、29.06% pre-layout efficiency trend。

二者使用的模型、损耗和测量窗口不同，不能直接比较。当前没有完成 DPA PVT、layout、匹配网络、稳定性或实测效率签核。

## 5. AI 辅助部分

当前 AI 能力是：

1. 根据 QAM、带宽、backoff、温度和 monitor condition 建议 seed/package；
2. 对 known/unknown/OOD 条件给出 fallback 元数据；
3. PS/Python 执行 14-candidate bounded local search；
4. 安全仲裁拒绝 clip、saturation、stall、error 或超限系数；
5. 通过 bank commit 更新 PL DPD。

这不是“神经网络直接线性化 PA”。AI 的价值应通过以下指标证明：

- 相比 cold start 是否减少候选次数；
- unknown/OOD 条件是否保持零安全违规；
- blind profile 上最终 EVM/ACLR 是否不退化；
- Python 与 PS C 决策是否一致。

## 6. monitor 与 cost

PL 实时累计 input/output power、peak、average magnitude、clip、saturation、slew、EVM/ACPR proxy 和 spectral bins。它们用于数字诊断、安全和候选排序。

当前 bare-metal `calibration_cost()` 使用 replay EVM proxy、saturation/clip/error/stall 惩罚、`MON_EVM_PROXY`、`MON_ACPR_PROXY` 和 `MON_SPEC_ADJ`。它不把 `MON_INPUT_POWER` 或 `MON_OUTPUT_POWER` 作为主要目标。

因此 monitor 正确需要 RTL/UVM 验证，但 monitor proxy 不能证明真实 DPA 的物理 EVM/ACLR 改善。

## 7. 正确闭环方法

1. 选定目标 DPA/PA 和输出网络；
2. 在 ADS、实测或可信 behavioral model 中获得训练/验证/测试反馈；
3. 训练 memoryless/memory-poly DPD 并量化；
4. MATLAB 与 RTL bit-true；
5. PS 写入 shadow bank 并安全 commit；
6. 重放同一 waveform；
7. 用同一 receiver 比较 no-DPD、Poly5、Memory-Poly5 和 AI-seeded search；
8. 只有物理反馈存在时才报告实测 RF 改善。

## 8. 当前结论

项目已经具备“可配置 DPD 执行器 + monitor + PS 校准控制 + 离线 AI seed”的完整数字架构。现有 behavioral 结果证明该方法在部分 PA profile 上有效，但尚未证明对真实 DPA/PA 的普遍改善。下一阶段应优先完成主 BP SKU 的 RTL/FPGA 签核和可校准的物理反馈端点，而不是扩大 AI 模型规模。

# 当前状态与限制

## 结论摘要

项目已经具备可交付的数字 IP 结构、AXI 接口、DPD/observer RTL、MATLAB 定点模型、IP 打包脚本和 28 nm DC 主 SKU 结果；但还不是“真实 RF PA 闭环”和“硅后签核”产品。

当前主验证对象已经收敛为：

```text
BP EFDSM2 -> behavioral DPA -> observation receiver -> DPD comparison
```

项目核心不是泛化比较所有 DSM，而是验证 BP EFDSM2 作为一位 DPA 驱动调制器时的数字质量，并验证针对同一 behavioral DPA 训练的 DPD 是否改善 EVM/SNDR/ACLR proxy。

## 已实现

- `dsm_ip_axi_top`：AXI-Lite 控制、AXI4-Stream I/Q 输入、反馈 AXI-Stream 和状态输出。
- DPD：bypass、polynomial、LUT、memory-polynomial 编译期分支；主验证使用针对 behavioral DPA 的 4 taps/5th order memory-polynomial branch。
- 安全：系数幅度检查、banked commit、saturation fault、拒绝非法 commit、bypass fallback。
- 插值：包含 `INTERP_MODE=4` x32 路径。
- `DUC_MODE=2`：低通一位 I/Q 输出，供外部模拟重构和 IQ 上变频。
- `DUC_MODE=3`：全精度 I/Q 到 Fs/4 IF 后进入 BP EFDSM2，输出一位 `rf_bit`。
- observer：复数反馈延迟、复增益、误差、功率、峰值、clip/saturation、slew 和频谱 proxy。
- AI：低速 seed/package 建议；必须经过确定性的安全仲裁和局部搜索。

## 当前证据

### 28 nm DC 主 BP SKU

证据目录：`syn/reports/bp_ef2_axi_28nm_dc_20260805_231629/`

| 指标 | 结果 |
|---|---:|
| 工艺/角 | TSMC28 RVT，TT，0.9 V，25 C |
| 目标周期 | 10 ns，100 MHz |
| Cell area | 125647.956 |
| Leaf cells | 151170 |
| Sequential / combinational | 24141 / 127029 |
| Critical path | 4.45 ns |
| Setup slack | +5.42 ns |
| Hold slack | +0.03 ns |
| Dynamic power | 8.1476 mW |
| Leakage | 0.0732 mW |
| Total power | 8.2218 mW |

这是预布局 DC 估计，不含布局、CTS、寄生提取、IR drop、EM、热和多角签核。

### RTL lint

最新 DC lint 目录：`syn/reports/lint_bp_ef2_axi_20260806_214119/`。`analyze/elaborate/link/check_design/check_timing` 成功，`Error/Fatal=0`，但仍有 unconnected、shorted output、constant output、unloaded net 和 signed/unsigned warning，因此不是 lint-clean。

### Vivado

当前 Windows 主机上的 BP AXI OOC 在 `synth_design` 阶段闪退，未形成新的完整 utilization/timing/summary 报告。因此 FPGA BP SKU 不宣称本轮综合通过。28 nm DC 结果不受该问题影响。

## 明确不声明

- MATLAB behavioral DPA 不是 ADS 电路仿真，也不是实测 RF。
- 当前没有真实 PA/ADC 反馈闭环测量。
- DPA 的输出功率、效率和温度可靠性尚未形成硅级结论。
- AI 尚未成为高速 RTL 神经网络；其价值是减少校准候选和搜索成本。
- 旧 LPDSM2 低通一位 Fs/4 合路的差 EVM 结果不能代表 DPD 性能。
- BP EFDSM2 的初始 EVM/SNDR 结果仍需完整 fixed-point RTL、统一接收机和 behavioral DPA/DPD 闭环审计。

## 下一步

1. 在 Linux EDA 环境直接以 `dsm_ip_axi_top` 为顶层跑 SpyGlass 和 VCS。
2. 修复并重新分类 DC lint 中的短接、未加载网络和 signed/unsigned 警告。
3. 在 Vivado 使用另一台主机或工具版本重跑 BP OOC。
4. 完成 BP RTL 与 MATLAB 逐样本等价，再接 behavioral DPA/DPD 指标。
5. 保持 `DUC_MODE=2` 模拟 IQ 路线和 `DUC_MODE=3` BP 数字 IF 路线的指标分离。

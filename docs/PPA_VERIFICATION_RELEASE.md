# PPA 与验证发布报告

## 1. 报告范围

本文只收录可追溯的 RTL、仿真和综合证据。PPA 数值必须同时给出工具、版本、工艺角、参数和报告目录。

## 2. 主 BP SKU

```text
top          = dsm_ip_axi_top
ALGORITHM    = 3
DUC_MODE     = 3
INTERP_MODE  = 4
INTERP_IMPL  = 0
DPD          = memory-polynomial, 4 taps, 5th order
poly/LUT     = disabled
memory       = enabled
clock        = 100 MHz
```

## 3. 28 nm DC 预布局结果

证据目录：`syn/reports/bp_ef2_axi_28nm_dc_20260805_231629/`。

| 项目 | 数值 |
|---|---:|
| 工具 | Synopsys Design Compiler V-2023.12-SP1 |
| 库 | TSMC28 RVT NLDM |
| PVT | TT，0.9 V，25 C |
| 时钟 | 10.0 ns / 100 MHz |
| Cell area | 125647.956304 |
| Leaf cells | 151170 |
| Sequential cells | 24141 |
| Combinational cells | 127029 |
| Critical path | 4.45 ns |
| Setup slack | +5.42 ns |
| Hold slack | +0.03 ns |
| Dynamic power | 8.1476 mW |
| Leakage | 0.0732 mW |
| Total power | 8.2218 mW |

这是 pre-layout 综合估计，不包含 placement、CTS、RC extraction、IR drop、EM、热分析、多角 signoff 或 silicon variation。

## 4. RTL 结构检查

最新目录：`syn/reports/lint_bp_ef2_axi_20260806_214119/`。

DC `analyze -> elaborate -> link -> check_design -> check_timing` 完成，日志中没有 `Error` 或 `Fatal`。但报告仍有结构 warning：未连接端口、短接输出、常量输出、未驱动 cell、未加载网络以及 signed/unsigned 转换。它是“结构检查完成，带 warning”，不是 lint-clean signoff。

## 5. FPGA 证据边界

历史 FPGA OOC/routed 报告只能按其目录和配置引用。当前 BP EFDSM2 AXI 在 Windows Vivado 2024.1 主机上进入 `synth_design` 后闪退，最近尝试没有生成完整 utilization/timing/summary，因此本轮不声称新的 ZU15EG BP OOC 通过。

## 6. 必要命令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_all_dsm.ps1 -Part xc7z020clg400-1
```

Linux EDA：

```bash
export DC_SHELL=/opt/Synopsys/syn/V-2023.12-SP1/bin/dc_shell
bash syn/run_lint_bp_ef2_axi.sh
```

## 7. 发布门槛

- RTL：XSim smoke、定点 bit-true、结构 lint 无未解释 blocking warning。
- IP：Vivado packaging 生成有效 component.xml。
- FPGA：目标器件 OOC/routed 报告存在且 WNS 满足时钟目标。
- ASIC：DC 报告非零面积、无 unmapped logic，并明确为 pre-layout。
- RF：EVM/SNDR/ACLR 必须注明 MATLAB behavioral、ADS、FPGA capture 或实测来源。
- DPD：no-DPD、memoryless、memory-polynomial 必须使用同一 PA/波形和 held-out 数据比较。

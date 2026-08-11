# 项目工程指南

更新时间：2026-08-09

## 1. 项目定位

`dsm_ip` 是面向数字 IC/FPGA 的可复用数字发射机 IP。项目将复数基带 I/Q 经过 DPD、插值、数字 IF 和 DSM 转换为确定性的数字输出，并提供控制、状态、验证和实现流程。

当前主链路：

```text
PS/DDR -> AXI DMA -> AXI4-Stream Q1.15 I/Q
       -> Memory-Poly5 4-tap DPD
       -> x32 interpolation
       -> full-precision Fs/4 IF
       -> one-bit BP EFDSM2
       -> rf_bit
```

外部 behavioral DPA/PA、BPF、接收机和 ADC 不在数字 RTL 内。

## 2. 两类集成路线

### 2.1 模拟 IQ 路线

`DUC_MODE=2` 输出 `i_bit/q_bit`，后接外部重构 LPF、模拟 IQ mixer、LO 和 PA。该路线是兼容集成方式，不是当前主验证 SKU。

### 2.2 一位数字 IF 路线

`DUC_MODE=3` 先做全精度 Fs/4 IF，再用 BP EFDSM2 量化为一位 `rf_bit`。该路线面向一位 DPA/开关功放，是当前主验证 SKU。

## 3. 目录职责

| 路径 | 职责 |
|---|---|
| `rtl/dsm/` | 单比特和多比特低通 DSM |
| `rtl/tx_bandpass_if/` | Fs/4 IF mixer 和 BP DSM |
| `rtl/interp/` | x4/x8/x16/x32 插值 |
| `rtl/dpd/` | polynomial、LUT、memory-poly、observer 和安全逻辑 |
| `rtl/axis/` | AXI4-Stream 缓冲与流控 |
| `rtl/ip/` | 与总线无关的数字数据通路顶层 |
| `rtl/axi/` | AXI-Lite/AXI-Stream 交付顶层 |
| `matlab/` | fixed/float 模型、向量、DPD 训练和指标 |
| `verif/` | 定向 SystemVerilog testbench 和 XSim 回归 |
| `uvm_verif/` | UVM scaffold 和后续完整验证环境 |
| `ip/` | Vivado IP 打包 |
| `syn/` | Vivado OOC/routed 与 DC 脚本/报告 |
| `fpga/zu15eg/` | ZU15EG BD、bare-metal、XSDB 和板级支持 |
| `ads/` | 可选 DPA 电路实验；生成 workspace/data 不入库 |
| `docs/evidence/` | 精简、可追溯的 CSV/JSON 证据 |

## 4. 配置方式

### 4.1 编译期参数

`ALGORITHM`、`DUC_MODE`、`INTERP_MODE`、`INTERP_IMPL`、DPD feature gate、polynomial order 和最大 tap 数决定实际综合硬件。修改后必须重新综合和生成 bitstream。

### 4.2 运行时寄存器

AXI-Lite 用于 enable/reset、DPD mode、系数/LUT、bank commit、observer、monitor 和状态读取。运行时寄存器只能控制已经编译进硬件的能力，不能恢复被 generate 裁剪的分支。

### 4.3 数据面

AXI4-Stream 每拍传送一个复数 Q1.15 样本：

```text
tdata[15:0]  = signed I
tdata[31:16] = signed Q
```

只在 `tvalid && tready` 时发生传输；stall 时上游必须保持数据和 sideband。

## 5. 运行流程

### 5.1 MATLAB

```matlab
cd('E:/workspace/chip/dsm_ip/matlab');
path_setup;
```

各模型入口和向量位置见 `matlab/README.md`。

### 5.2 RTL 回归

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1
```

DPD、插值、observer 和 BP 专项使用 `verif/scripts/` 下对应脚本。

### 5.3 IP 打包

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1
```

### 5.4 ZU15EG

推荐结构：

```text
PS DDR -> AXI DMA MM2S -> dsm_ip_axi_top
PS AXI master -> AXI-Lite
IP status/monitor -> PS reads
```

先验证 VERSION/CAPABILITY，再写系数、提交 bank、启动 DMA，最后读取计数器和错误。没有真实反馈硬件时，observer 只能使用数字 replay，不能宣称 PA 闭环。

## 6. 异步反馈扩展

未来物理反馈链路必须经过 clock converter 或异步 FIFO：

```text
DPA/PA -> BPF/coupler -> receiver/ADC
       -> Q1.15 feedback AXI4-Stream
       -> dpd_observer_async_bridge
       -> s_axis_obs -> observer -> PS
```

需要定义反馈时钟、FIFO 满策略、丢样计数、窗口完成、软复位 drain 和 CDC/RDC 检查。

## 7. 工程规则

- 不静默修改定点宽度、符号、缩放、截断、饱和或延迟；
- 行为变化必须同步 MATLAB、RTL、testbench、寄存器和文档；
- 生成日志、缓存、波形、ADS workspace 和大型报告不入库；
- 结果必须注明配置和证据等级；
- 当前主目标只关注 ZU15EG，历史器件结果不作为 release gate。

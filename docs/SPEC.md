# BP EFDSM2 Digital Transmitter IP Specification

## 1. 定位与边界

本项目实现可综合、可复用的固定点数字发射机 IP。它接收复数基带 I/Q
样本，经数字预失真、插值、`Fs/4` 数字上变频和带通 Delta-Sigma
调制后，输出与 `aclk` 同步的 `rf_valid`、`rf_bit` 和 `rf_signed`。

IP 的数字签核边界止于同步数字输出。功率开关的门极驱动、DPA/PA、匹配
网络、天线、物理 RF 滤波、真实反馈 ADC 和实测 EVM/ACLR 不属于当前 RTL
结论。它们可通过独立的行为模型、ADS 或板级系统继续评估。

## 2. 冻结主配置

| 项目 | 配置 |
|---|---|
| 主顶层 | `dsm_ip_axi_top` |
| FPGA 目标 | `xczu15eg-ffvb1156-2-i` |
| 主时钟 | `aclk = 100 MHz` |
| 输入 | Q1.15 signed complex I/Q，AXI4-Stream |
| DPD | 五阶、四 tap memory polynomial |
| 插值 | `INTERP_MODE=4`，x32，`INTERP_IMPL=0` |
| DUC | 无乘法实数 `Fs/4` mixer，中心 IF 为 25 MHz |
| DSM | 单比特 BP EFDSM2 |
| 控制 | AXI4-Lite、双系数 bank、安全边界 commit、sticky error |

冻结 SKU 只启用 memory-polynomial DPD；Poly/LUT 执行支路作为可选探索
特性关闭。其他 DSM、插值实现和 DPD 分支可用于 block 或 wrapper 级研究，
不与主 SKU 的 system-UVM 覆盖结论混用。

## 3. 数据通路与定点契约

```text
AXI4-Stream I/Q
  -> Memory-Poly5, four-tap DPD
  -> x2 halfband FIR -> x2 halfband FIR
  -> x8 CIC-equivalent FIR -> 63-tap compensation FIR
  -> real Fs/4 mixer
  -> one-bit BP EFDSM2
  -> rf_valid / rf_bit / rf_signed
```

### 3.1 DPD

五阶四 tap memory-polynomial 的抽象形式为：

```text
y[n] = sum(m=0..3) {
  C1,m*x[n-m]
  + C3,m*x[n-m]*|x[n-m]|^2
  + C5,m*x[n-m]*|x[n-m]|^4
}
```

RTL 使用历史 I/Q 寄存器、幅度平方、奇数阶基函数、复系数乘法和流水加法树。
系数写入 inactive bank；只有满足安全边界时，commit 才会原子切换 active bank。
非法系数、饱和或违反时序的请求会置 sticky error，且不允许半组系数生效。

### 3.2 插值

x32 主链分级完成：`2 x 2 x 8 = 32`。两个 halfband FIR 利用零抽头和对称
系数减少有效乘法；29-tap CIC-equivalent FIR 产生 x8 的平滑/低通响应；
63-tap compensation FIR 补偿通带下垂并抑制插值镜像。所有定点阶段明确了
符号位、扩展位宽、截断/舍入、饱和、状态更新顺序和 valid latency。

`INTERP_IMPL=1` 的直接 CIC 是备选实现，不是冻结主配置。其 `ORDER=4`
表示四阶 comb/integrator 数学结构，并不等同于四级物理流水；对递归积分器
插拍需要保持状态等价并重新进行 bit-true 验证。

### 3.3 Fs/4 mixer 与 BP EFDSM2

混频器以 phase `0,1,2,3` 顺序产生 `+I,+Q,-I,-Q`，等价于与
`cos(pi*n/2)`、`sin(pi*n/2)` 的特例相乘，因此不需要通用乘法器。BP EFDSM2
在 25 MHz 附近整形量化噪声，输出一比特序列，适合作为二值开关 DPA-facing
数字边界。

所有状态只在有效且接受的样本上推进；`phase_acc_dbg` 与其对应的 RF 输出对齐，
用于 ILA、scoreboard 与系统调试，不参与调制数学本身。

## 4. 接口与控制面

### 4.1 AXI4-Stream

输入 `s_axis_tx_tdata[31:0]` 的低 16 位为 I、高 16 位为 Q。`tvalid/tready`
决定一次样本传输；backpressure 时 payload 必须稳定。`tlast/tuser` 用于包边界
与错误注入/观测场景，具体语义以 RTL 寄存器表和验证环境为准。

可选 observation AXI-Stream 接口用于接收观测 I/Q。外部 `feedback_clk` 到
`aclk` 的跨时钟域只允许经过 `dpd_observer_async_bridge` 的异步 FIFO。

### 4.2 AXI4-Lite

AXI4-Lite 用于 enable/reset、DPD 系数 bank 写入、commit、monitor 清零、状态
读取与错误恢复。控制面分为：

| 类别 | 内容 |
|---|---|
| 控制 | enable、soft reset、模式/衰减等运行控制 |
| 系数 | DPD C1/C3/C5/C7 与 LUT/memory bank 写入 |
| 安全 | commit/reject、active bank、epoch、fallback、sticky error |
| 监测 | 输入/输出计数、饱和、峰值、功率 proxy、spectral proxy |
| 观测 | observer FIFO、窗口、快照与错误状态 |

地址数值和优先级以 `rtl/axi/dsm_ip_axi_top.v` 及拆分后的 AXI 模块为真源；
本文不复制寄存器位定义，避免文档与 RTL 漂移。

## 5. 架构选择与量化依据

在统一的 100 MS/s、`Fs/4`、OFDM 审计口径下，归档的单比特带通结果为：

| 候选 | 输出 | EVM | SNDR |
|---|---:|---:|---:|
| BP single-loop DSM | 1 bit | 3.659670% | 28.731161 dB |
| BP EFDSM2 | 1 bit | 3.563808% | 28.961713 dB |
| BP MASH1-1 native | 4 level | 3.581210% | 28.919404 dB |

BP EFDSM2 相对基础 BP 单环 EVM 降低 0.095862 个百分点（约 2.62% 相对改善），
SNDR 提升 0.230552 dB。MASH1-1 的 native 多级输出不是一比特二值 DPA 边界，
因此不作为主数据通路候选。七种 DSM 的完整资源比较保留在
`docs/evidence/ooc/`，应以同一器件、位宽和综合阶段的 CSV 为准。

## 6. PPA 与时序证据边界

下表是 `xczu15eg-ffvb1156-1-i` 的 post-synthesis OOC 汇总，反映插值倍率
的相对代价，不可替代冻结主 SKU 的 `-2-i` routed 结论：

| 配置 | LUT | FF | DSP | 估算 Fmax |
|---|---:|---:|---:|---:|
| BP EFDSM2 + x16 | 7,586 | 7,668 | 936 | 256.15 MHz |
| BP EFDSM2 + x32 | 8,037 | 8,215 | 1,278 | 240.79 MHz |

x32 相对 x16 增加 451 LUT、547 FF 和 342 DSP；估算 Fmax 降低 15.36 MHz。
这说明高倍率插值和补偿 FIR 是主链的重要 PPA 成本。

历史集成与 ASIC 预布局证据、routed OOC 子集以及缺失的 raw timing endpoint
详见 [CRITICAL_PATH_REPORT.md](CRITICAL_PATH_REPORT.md)。除非重新执行并归档
同一 top/part/constraint 的实现报告，不能把任何历史 OOC 数字表述为当前完整
routed/bitstream signoff。

## 7. 验证与 CDC 状态

MATLAB fixed-point 定义算法/定点规范，Python integer model 用于 Linux/VCS
日常 bit-exact golden，SystemVerilog/UVM 验证 RTL 事务和协议。已记录的主 SKU
系统回归为 15 个测试、每个 20 个 seed，共 300 次 VCS run；功能覆盖率记录为
100%。这不等价于 raw code coverage 100%，也不等价于所有可选 SKU 已做 system
signoff。完整测试矩阵、pass 判据和待办见 [VPLAN.md](VPLAN.md)。

对于 CDC，当前内部 TX 数据面使用 `aclk`。只有外部观测反馈进入异步桥时存在
`feedback_clk -> aclk` CDC；RTL 使用异步 FIFO、Gray pointer 与两级同步。已有
功能验证，但尚未执行静态 CDC/RDC 工具签核。

已进行的 VC Formal/SVA 仅覆盖选择的控制面安全属性；本文不把它扩展宣称为全
设计 formal equivalence 或全 CDC proof。

## 8. 集成与原型接口

目标 SoC/FPGA 集成关系为：

```text
PS/RISC-V software -> AXI4-Lite control
DDR -> DMA -> AXI4-Stream I/Q -> transmitter IP
transmitter outputs -> ILA capture / digital downstream
```

DMA 将 DDR 中的 I/Q buffer 作为 AXI-Stream 事务送入 IP；它不直接生成 RF。
ILA 捕获 `rf_valid/rf_bit/rf_signed/phase`，再由 Python 与同一输入向量产生的
golden 逐 transaction 比较。该路径是数字 FPGA 原型和回放接口，不是实际 PA
或天线性能的替代测量。

## 9. Future Plan

### 9.1 RTL 与验证

- 将 `dsm_ip_axi_top.v` 进一步拆成 AXI-Lite slave、register file、commit control
  和 status monitor；保持端口、地址、优先级、延迟与 bit-true 行为不变。
- 对主 SKU 做可达代码覆盖率 triage；对 feature-gated Poly/LUT 和数学不可达分支
  建立 source-linked exclusion/waiver，不制造违反协议的测试来追求 raw 100%。
- 补静态 lint、CDC/RDC、门级/SDF 及主 SKU 完整 routed implementation、bitstream
  与 DMA/ILA replay。

### 9.2 PPA 与高吞吐研究

- 先归档 raw `report_timing -from/-to`、utilization 与 power，比较 EFDSM/EFDSM2、
  x16/x32 和 DPD memory depth 的面积、频率与功耗。
- 高吞吐方案应拆分为低速前端、可展开的高频 DSM kernel、确定性 lane ordering，
  以及高速 serializer/external MUX/RF driver。x4/x8 并行数字验证可在 FPGA 进行；
  20 GHz 物理开关输出需要专用高速 I/O、低抖动时钟、deskew、driver 和 RFIC/ASIC，
  不能由普通 GPIO/FMC GPIO 直接承担。
- AI-assisted 校准保持在慢速控制面：观测 PA/DPA 输出、估计初始系数、受限搜索，
  再写入 inactive bank 并安全 commit；目前不宣称完成真实 PA+ADC 下的 AI 闭环
  性能签核。

## 10. 规范性声明

所有性能、面积、频率、功耗和 RF 指标必须标注模型、器件、工艺、时钟约束、
输入向量、测量口径和工具阶段。模型结果、post-synthesis OOC、routed OOC、
历史集成、预布局 ASIC 估算和真实板级/射频测量不得互相替代。

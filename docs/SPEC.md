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

历史集成、ASIC 预布局和 routed OOC 属于不同 top、part 和约束阶段；除非重新执行并
归档同一 top/part/constraint 的实现报告，不能把任何历史 OOC 数字表述为当前完整
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

### 8.1 Cartesian x4/TI64 raw-GTH prototype

This prototype is separate from the frozen BP-EFDSM2 SKU. It accepts sixteen
ordered I/Q samples per word, applies vector DPD (bypass or memoryless
polynomial), a x4 polyphase FIR, Fs/4 real mapping, 64 independent LP1 TI64
lanes, and a raw 64-bit GTH word. Lane 0 is the earliest sample. It is a
64-way time-interleaved LP1 implementation, not temporal BP-EFDSM2 and not
MASH.

The x4 FIR has five elastic stages. It preserves the prior fixed-point result
`(low + middle) + high`, rounding, saturation, history and lane order; only
latency changes. The ZU15EG `X1Y12` raw-GTH implementation closes at
`TXUSRCLK2=218.75 MHz`: WNS `+0.387 ns`, WHS `+0.010 ns`, TNS/THS `0`,
20,835 LUTs, 21,203 FFs, 385 DSPs and 4 BRAM. This is implementation evidence
at a 14 Gb/s raw one-bit serial boundary. `Fs/4` places the intended digital
center at 3.5 GHz; it is not evidence of a 14 GHz RF carrier or a physical
SFP0 link.

Before FPGA programming or ASIC migration, the x4 prototype must meet the
dedicated verification gates in `VPLAN.md`: long randomized bit-true testing,
transaction/lane-order assertions, reset/backpressure tests, lint and CDC/RDC
review, and coverage closure. Board loopback then verifies the physical serial
word order; ASIC work additionally requires a target-library synthesis, STA,
power and DFT plan.

## 9. 未来规划

### 9.1 RTL 与验证

- 继续将 `dsm_ip_axi_top.v` 按 AXI-Lite 从机、寄存器文件、commit 控制和状态监控
  拆分；必须保持端口、地址、优先级、延迟与 bit-true 行为不变。
- 对冻结主 SKU 做可达代码覆盖率审计。对编译期关闭的 Poly/LUT 分支及已证明的数学
  不可达分支，建立可追溯的 exclusion/waiver；不通过破坏协议制造测试来追求原始
  代码覆盖率的表面数字。
- 补齐 lint、CDC/RDC、门级/SDF、主 SKU 的完整 routed implementation、bitstream 与
  DMA/ILA 回放。当前文档中的 OOC 与历史 routed 结果不能替代这些检查。

### 9.2 PPA 与高吞吐研究原则

- 归档原始 `report_timing -from/-to`、utilization 与 power，量化 EFDSM/EFDSM2、
  x16/x32 插值和 DPD memory depth 的面积、频率及功耗取舍。
- 高吞吐设计拆为低速前端、可展开的高频 DSM 内核、确定性 lane 排序，以及高速
  serializer/external MUX/RF driver。x4/x8 并行数字架构可先在 FPGA 上验证；物理
  多 Gb/s 开关输出仍需要专用高速 I/O、低抖动时钟、deskew、driver 与 RFIC/ASIC，
  普通 GPIO 或普通 FMC SelectIO 不能直接承担。
- AI-assisted 校准保留在慢速控制面：观测 PA/DPA 输出，估计初始系数并进行受限搜索，
  随后写入 inactive bank 并安全 commit。当前不宣称已经完成真实 PA+ADC 反馈下的
  AI 闭环性能签核。

### 9.3 高速并行 DSM 研究目标（规划，不是当前实现结论）

本节基于 [`Cartesian_DSM_Survey.md`](Cartesian_DSM_Survey.md)
记录后续架构研究。它不表示当前 IP、板卡或连接器已经能输出多 GS/s 开关波形。

#### 速率与带宽定义

对一比特 DSM，单个采样点产生一个输出 bit：

```text
原始一比特数据率 = Fs × 1 bit/sample
Fs/4 载波中心频率 = Fs / 4
OSR = Fs / (2 × 占用带宽)
复数基带输入采样率 = Fs / 插值倍数
```

因此，`14 GS/s` 对应 `14 Gb/s` 的一比特原始数据负载，并不等价于 14 GHz RF
载波。采用 `Fs/4` 上变频时，`Fs=14 GS/s` 对应 3.5 GHz 数字 IF 中心。若经过线码、
成帧或高速串行链路，物理链路速率会高于这一定义下的原始一比特数据率。

插值倍数 `x32` 和 OSR 不是同一个参数：`x32` 仅表示采样率从复数输入域提高 32 倍；
OSR 则由最终采样率和实际占用带宽共同决定。只使用较少 OFDM 子载波时，实际带宽更窄，
OSR 会大于规划值；这不是矛盾，而是额外的带宽保护和噪声整形余量。

#### 当前已验证审计波形

当前 100 MS/s 审计使用确定性的 16QAM OFDM：`NFFT=64`、24 个有效子载波
（`-12:-1`、`+1:+12`）和 `CP=16`。其复数输入率为 3.125 MS/s：

```text
子载波间隔 = 3.125 MS/s / 64 = 48.828125 kHz
名义占用带宽 = 24 × 48.828125 kHz = 1.171875 MHz
审计 OSR = 100 MS/s / (2 × 1.171875 MHz) = 42.67
```

循环前缀降低有效载荷效率，但不增加占用 RF 带宽。插值提高采样率并将频谱镜像推远，
不会自动扩大信息带宽；信息带宽由 modem 的有效子载波数、子载波间隔和复数输入
采样率决定。

#### 冻结的首个 3.5 GHz 并行研究点

选择 3.5 GHz 作为第一阶段中心频率。它保留无乘法 `Fs/4` DUC，因此需要：

```text
中心频率 fc = 3.5 GHz
最终 DSM 采样率 Fs = 4 × fc = 14 GS/s
并行 lane 数 = 64
每 lane 速率 = 14 GS/s / 64 = 218.75 MS/s
插值倍数 = x32
复数基带输入率 = 14 GS/s / 32 = 437.5 MS/s
```

首个目标选择 **OSR=32、占用带宽 218.75 MHz**：

```text
占用带宽 = 14 GS/s / (2 × 32) = 218.75 MHz
```

这比 OSR=16、占用带宽 437.5 MHz 更适合作为第一阶段目标：OSR=32 给一比特 DSM
更多带内量化噪声整形余量，也让插值镜像抑制、定点范围、并行状态展开和 64QAM/256QAM
EVM 目标更可控。OSR=16 可作为后续高带宽扩展点，但不应在未完成新的并行 DSM、
滤波器与 PPA 验证前作为首个承诺。

| 场景 | Fs/4 中心 | 最终 Fs | 原始一比特数据率 | 占用带宽 | OSR | x32 复数输入率 | 64-lane 时钟 |
|---|---:|---:|---:|---:|---:|---:|---:|
| 当前已验证审计 | 25 MHz | 100 MS/s | 100 Mb/s | 1.171875 MHz | 42.67 | 3.125 MS/s | 未并行化 |
| 3.5 GHz 窄带备选 | 3.5 GHz | 14 GS/s | 14 Gb/s | 100 MHz | 70 | 437.5 MS/s | 218.75 MHz |
| **3.5 GHz 冻结研究点** | **3.5 GHz** | **14 GS/s** | **14 Gb/s** | **218.75 MHz** | **32** | **437.5 MS/s** | **218.75 MHz** |
| 后续高带宽扩展 | 3.5 GHz | 14 GS/s | 14 Gb/s | 437.5 MHz | 16 | 437.5 MS/s | 218.75 MHz |

`x32` 给出 `437.5 MS/s -> 14 GS/s` 的采样率关系，不会自行固定 100 MHz 或
218.75 MHz 的业务带宽。未来 OFDM modem 需要定义 `NFFT`、有效子载波数和保护带，
使其占用带宽不超过 218.75 MHz。当前 100 MHz 仅作为更保守的窄带备选 profile，
不再作为主研究点的默认带宽。

#### 64 lane、插值率与带宽的边界

64 lane 是**时间交织**，不是将一个宽带信号按频率切成 64 个独立子带。每条 lane
携带串行一比特流中每隔 64 个时间槽的一个样本；只有按照确定的 lane 顺序重新合并后，
才恢复同一条 14 GS/s 的 DSM 序列。因此，不能将业务带宽直接除以 64。

| 量 | 冻结研究点数值 | 含义 |
|---|---:|---|
| 最终 DSM 采样率 `Fs` | 14 GS/s | 合并 64 lane 后的一比特序列采样率 |
| 每 lane 速率 `Fs/64` | 218.75 MS/s | 每条并行 DSM lane 的时间槽速率，不是每 lane 的独立业务带宽 |
| x32 复数输入率 `Fs/32` | 437.5 MS/s | 进入插值器前的聚合复数 I/Q 采样率 |
| OSR=32 的总占用带宽 `Fs/(2*OSR)` | 218.75 MHz | 整个发射信号的目标占用带宽，不是每 lane 218.75 MHz |

若将低速复数前端也实现为 64 路向量化，其每路输入速率是
`437.5 MS/s / 64 = 6.8359375 MS/s`。这是**每路输入样本率**，不是 6.8359375 MHz
的独立射频带宽；单独观察解交织后的 lane 会发生频谱折叠，不能把它当作一个独立的
6.8359375 MHz 通信信道。只有采用额外的 64 路滤波器组/频分信道化架构时，才可以
讨论将总业务带宽划分为若干独立子带。

结论是：在 `Fs=14 GS/s`、64 lane、`OSR=32` 的当前规划中，
**218.75 MS/s 是每 lane 的工作速率，218.75 MHz 是整个系统的目标占用带宽，
437.5 MS/s 是 x32 插值前的复数输入率。** 若把 OSR 放宽至 16，系统总占用带宽
才扩展为 437.5 MHz。

#### 质量目标与验证边界

冻结目标为：

```text
EVM_rms <= 3%
数字链路 SNDR 目标 >= 33 dB
```

在误差已对齐且可近似为附加噪声的理想条件下：

```text
SNDR_ideal ≈ -20 × log10(EVM_rms)
EVM = 3% 时，SNDR_ideal ≈ 30.46 dB
```

因此 33 dB 是约 2.24% 理想等效 EVM 的实现余量目标。EVM 与 SNDR 在完整
RF 链路中并不严格等价；最终 EVM/ACLR 仍取决于重构滤波、DPA/PA、相位噪声、
时钟抖动和观测接收机。33 dB 仅是后续数字架构审计门限，而不是当前 FPGA 或 RF
性能结论。

#### 架构边界

```text
DDR / modem / DMA
  -> 共享 DPD + 插值前端
  -> 宽复数采样接口
  -> 含状态预测与 lane 顺序控制的并行 BP-DSM 内核
  -> serializer 或外部高速 MUX
  -> retiming、deskew、非重叠控制、gate driver
  -> switching DPA、RF BPF 与匹配网络
```

前端不应盲目复制 64 份；并行展开应集中在高频 DSM 内核。有效的 64-lane 设计必须
经状态预测或 loop unrolling 产生与单路串行参考一致的 DSM 序列，而不能将 64 个
彼此独立的反馈 DSM 环路随意交织。

当前 XCZU15EG RTL 适合进行 x4/x8 架构实验、lane 顺序验证和 PPA 探索。物理 14 Gb/s
一比特输出还需要经实物原理图确认的 GT/MGT 路由、参考时钟、serializer/MUX、SI
收敛以及兼容的外部接收端或 RF driver；普通 FPGA GPIO 和普通 FMC SelectIO 不能作为
这一物理接口的替代。

#### 当前高频实施顺序

当前先把 `218.75 MHz` 定义为单个并行 lane 的时钟/时间槽目标。它对应
`14 GS/s / 64` 的规划数值，时钟周期约为 `4.5714 ns`。这一步只验证冻结
BP-EFDSM2 主链在该时钟约束下的综合时序，不代表当前 FPGA 已经实现 64 lane、
8 lane 或 14 GS/s 物理输出。

实施顺序固定为：

1. 对现有单路 BP-EFDSM2 主链执行 `218.75 MHz` OOC 时序检查；
2. 建立 8-lane 时间交织的 lane map、串行参考和逐 bit 重组检查；
3. 对 8-lane BP 内核执行状态展开/预测设计，并与单路参考逐 bit 对齐；
4. 只有在 bit-true、时序和 PPA 均通过后，才讨论更高 lane 数或物理高速 I/O。

首个 8-lane 原型位于 `rtl/tx_bandpass_if/bp_ef2_parallel8.sv`。随后加入的
参数化实现 `rtl/tx_bandpass_if/bp_ef2_parallel.sv` 与包装模块
`rtl/tx_bandpass_if/bp_ef2_parallel64.sv` 将 64 个连续样本在一个时钟内按
时间顺序展开，并输出 `y_vec[0]` 到 `y_vec[63]`。这些模块当前都是独立
实验入口，不接入冻结 `dsm_ip_axi_top`；接入主链前必须完成标量 EFDSM2 的
逐 bit、signed 输出、状态和 reset/valid gap 等价验证。
配套 Python golden 生成器为
`uvm_verif/refmodel/python/generate_bp_ef2_parallel8_vectors.py`，XSim 入口为
`verif/scripts/run_xsim_bp_ef2_parallel8.ps1`。
8-lane 原型的独立综合入口为 `syn/run_ooc_bp_ef2_parallel8.ps1`，64-lane
原型的独立综合入口为 `syn/run_ooc_bp_ef2_parallel64.ps1`；这些入口仅用于衡量
sample 展开的时序和资源，不等价于已经完成 GTY 物理串行输出。
64-lane 的 VCS 回归位于 `verif/block/bp_dsm/vcs_parallel64/`；64-lane
`218.75 MHz` 的 Vivado OOC 结果必须以新生成的 `summary.csv` 为准。当前
Vivado OOC 已正常完成综合，但在 `218.75 MHz` 下得到 WNS=`-58.303 ns`、
估算 Fmax=`15.90 MHz`，因此该结构不满足目标。综合成功、功能通过和时序达标
必须分开记录。
工程主线只保留 `bp_ef2_parallel64` temporal64：64 个连续时间样本在一个
fabric 周期内展开，并通过 exact even/odd polyphase 变换保持原始反馈语义。
偶数样本和奇数样本各自形成 32-sample 状态链，最后按原始时间顺序交织输出。
独立状态 64-core 候选的可执行实现已经移除；历史报告仅作为审计记录，不属于
冻结 SKU、主 SPEC 或主 PPA 结论。

`syn/run_ooc_bp_ef2_lane_sweep.ps1` 已将 `218.75 MHz` 纳入默认目标列表。
该目标的 PASS 必须来自本次 OOC 运行生成的 `summary.csv`；历史的
`240.79 MHz` x32 结果不能替代本次单 lane 高频约束结果。
28 nm ASIC 预布局主线入口为 `syn/run_bp_ef2_parallel64_28nm_dc.sh`，其
`DSM28_STDCELL_DB` 必须指向包含 INV/BUF/NAND/NOR 等逻辑单元的完整映射库。
只有 library 非空、面积非零且没有 unmapped logic 时，28 nm PPA 才有效。
也可使用 `syn/run_ooc_bp_ef2_218p75.ps1` 只运行该目标。该脚本会同时将
`create_clock` 约束和 `CLK_FREQ_HZ` RTL 参数设置为 `218750000`。

#### temporal64 时序优化实验

为缩短反馈路径，已完成两个保持 bit-true 的调度实验：

| 版本 | 每周期计算 | II | 218.75 MHz 结果 | bit-true | 结论 |
|---|---:|---:|---:|---|---|
| `bp_ef2_parallel64` | 64 samples | 1 | Fmax 15.90 MHz | PASS | 原始 temporal64 基线，时序失败 |
| `bp_ef2_pipeline64` | 8 samples | 8 | Fmax 115.00 MHz | PASS | 路径改善，但吞吐率不足 |
| `bp_ef2_pipeline64_group4` | 4 samples | 16 | Fmax 243.05 MHz | PASS | 时序通过，但有效吞吐约 875 MS/s |

`bp_ef2_pipeline64_ii1_group4` 是失败的 II=1 实验，不属于当前 SKU。原因是
普通组间寄存器只能延迟数据，不能提前得到前一个 64-sample transaction 的最终
反馈状态。要同时保持 II=1、bit-true 和 14 GS/s，必须设计并证明精确的非线性
look-ahead/state-prediction 变换；不能把普通流水线结果当成这个目标已经实现。

#### 声称高速结果前的必要证据

1. 建立串行参考，证明 x4/x8/x64 并行输出在 reset、valid 间隙和 lane-skew 故障注入
   下保持逐 bit 一致。
2. 在目标时钟约束下综合并行内核，归档资源、原始时序端点和功耗估计。
3. 核对实际板卡高速收发器路由，并完成 BER、眼图或链路测试后，才能声称物理串行
   输出速率。
4. 将 RF 声称独立处理：DPA、BPF、匹配、PA 效率、EVM 与 ACLR 必须有明确的物理端点
   和测量方法。

## 10. 规范性声明

所有性能、面积、频率、功耗和 RF 指标必须标注模型、器件、工艺、时钟约束、
输入向量、测量口径和工具阶段。模型结果、post-synthesis OOC、routed OOC、
历史集成、预布局 ASIC 估算和真实板级/射频测量不得互相替代。

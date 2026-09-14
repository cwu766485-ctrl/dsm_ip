# Cartesian Delta-Sigma 全数字发射机调研与频率选择

**更新日期：** 2026-09-13
**范围：** Cartesian/正交、实数 IF 带通 Delta-Sigma、FPGA/MGT 全数字发射机，以及与低比特 PA、RF-DAC 和多频段可重构相关的参考工作。
**硬件假设：** 单条 FPGA 高速收发器的原始线速率上限约为 16.375 Gb/s；最终输出是低分辨率或单比特脉冲流，后接外部驱动器或开关 DPA 和模拟带通滤波器。

---

## 0. 本项目的有效架构边界

本文件保留 Cartesian LPDSM 文献的价值。原 exact temporal64 BP-EFDSM2
扩展路线已于 2026-09-13 删除；当前 FPGA/MGT 原型是独立的 TI64 路线：

```text
external frontend (not yet integrated) -> 64 real low-pass samples
    -> 64 independent LP1 TI-DSM lanes -> +,+,-,- Fs/4 sign sequence
    -> 64 ordered bits -> raw GT serializer
    -> external RF driver / switching DPA -> analog BPF
```

每个 TI64 lane 是独立的一阶 error-feedback loop：

```text
v_l[k] = x_l[k] + e_l[k]
q_l[k] = sign(v_l[k])
e_l[k+1] = v_l[k] - q_l[k] * full_scale
```

随后按 lane index 施加 `+,+,-,-` 符号序列，形成 `Fs/4` 的实数 IF。它是
64-way TI LP1 DSM，而非二阶 BP-EFDSM2，也不具有原递归路线的 bit-true
承诺。`lane[0]` 是最先串行化的样本，`lane[63]` 是最后一个。

当前数值频率规划为：

```text
64 x 218.75 MHz = 14 GS/s = 14 Gb/s raw serial rate
Fs/4 center = 14/4 = 3.5 GHz
```

所以 14 Gb/s 不是 14 GHz 载波。若要直接产生 14-GHz 的 `Fs/4` 载波，
需要 56 GS/s，例如四条严格对齐的 14-Gb/s 流和外部 4:1 聚合器，或者独立
的模拟上变频链路。高 Nyquist 区镜像可以作为实验，但必须以实际 serializer、
通道、驱动器和滤波器测试为准。

TI64 已完成 fabric OOC 与 GT-boundary 仿真，但真实 GT Wizard、板级信号
完整性和 RF 测量仍未签核。不能把功能仿真或 fabric OOC PASS 表述为
14-Gb/s 或 3.5-GHz 硬件输出 PASS。

---

## 1. 架构分类与本项目的位置

### 1.1 Cartesian/正交 LPDSM 发射机

典型链路为：

```text
I -> LPDSM_I --+
               +-> {I, Q, -I, -Q} digital upconversion -> serializer -> BPF
Q -> LPDSM_Q --+
```

优点是 I/Q 保持 Cartesian 形式，低通 NTF 容易分析，适合 polyphase、
time-interleaving 与 MGT 串行化。代价是 I/Q 路径的增益、延迟、占空比和
位序误差会产生镜像。

### 1.2 实数 IF 带通 BPDSM 发射机

先在多比特域完成 `+I,+Q,-I,-Q` 数字混频，再使用带通 DSM 直接把量化
噪声推离 RF 目标带。项目属于此类。它避免了在一位量化之后再作 I/Q 混频，
但递归状态的并行展开和时序收敛更难。

### 1.3 RF-DAC / 数字 PA / Polar 发射机

这些架构可能同样使用 DSM，但物理输出接口不同：

- RF-DAC 使用多单元、多比特 DAC，主要问题是量化误差和单元失配；
- 数字 PA 使用脉冲流直接控制开关级，主要问题是边沿、功率回退、滤波器和
  PA 非理想；
- Polar PA 还需要 AM/PM 映射、相位边沿选择和 LO/PA 协同。

它们可作为系统或 PA 参考，不能仅因都包含 DSM 就把其 RTL 直接嵌入
BP-EFDSM2。

---

## 2. 四篇用户提供论文的对照结论

| 论文 | 已展示的核心贡献 | 可借鉴内容 | 不能直接移植的部分 |
|---|---|---|---|
| Roverato et al., JSSC 2017 | 28-nm、10-bit RF-DAC；可编程带通 DSM 与 mismatch shaping；在可调 duplex offset 上约 -55 到 -63 dBc/Hz RX-band noise，LTE20 ACLR 约 -61 dBc。 | 把 RX-band、邻道和 OOB 噪声设为一等规格；建立可调 NTF、定点系数审计，并分离量化噪声和硬件误差。 | DEM/mismatch shaping 依赖 segmented multi-cell RF-DAC。单比特串行 DPA 没有对应的 DAC 单元选择，不能把该编码器直接复制到 RTL。 |
| Firmansyah, UBC MASc 2026 | 一阶 pipelined TIDSM、polyphase interpolation、I/Q 确定性串行化与 MGS；3.5 GHz 使用每路 I/Q 16 channel x 437.5 MHz，4 GHz 使用 32 channel x 250 MHz；4-GHz 64-QAM 测得 3.09% EVM/38-dB SNDR。 | 用 `L`、fabric clock、FIR transition band、DSP 数量与 MGS line rate 的联合权衡；采用 known-word、PRBS、位序、word boundary、jitter、EVM 与滤波器的完整验证链。 | 论文的 `L` 是每个 I/Q path 的 polyphase DSM channel 数；项目的 64 是实数 BP 流的一笔 temporal word。其一阶 TIDSM 状态方程不能替换二阶 BP-EFDSM2 的 exact state-map/prefix 证明。 |
| Zhang et al., ISSCC 2025 | 65-nm、CORDIC-less digital polar TX；三电平 I/Q DSM 后以 9-state LUT 做 AM/PM 映射，edge-selected 1-bit PA 输出八相；1.35 GHz 时 peak PAE 33.5% @ 24.2 dBm；50-MSym/s 256-QAM 为 20.2% average PAE、16.9 dBm、-28.7-dB EVM。 | 在多比特 Cartesian 域保留数据至最后阶段；低基数 LUT 可减少非线性坐标变换。若未来建立 phase-selecting PA，可研究 truncation-error feedback 与大于 180-degree phase step 的 overlap-error control。 | 需要 4fc LO、八相边沿选择、自定义 PA、两路 sub-PA 与 transformer 合成。这是新的 polar PA 架构，不是当前 raw GT 单比特流或 BP-EFDSM2 的小修改。 |
| Xu et al., TVLSI 2025 | 2-stage SMASH BPDSM；可独立调 NTF zero、可切 single/dual band、并行 DSM 之间显式传递状态；100-MHz FPGA 逻辑、x64 interpolation、6.4-GHz 输出 sample rate、256 DSP48；0.05-3.15 GHz dual-band，10/20-MHz ACLR below -45/-39.5 dBc、EVM below 1.6%。 | 用 stage count 控制 notch 数；`g_i = 2 - 2 cos(2*pi*f_c,i/f_s)` 移动每对 complex zero；`a_i` 调 pole/notch width/stability。其 delay-register state propagation 直接说明并行 DSM 必须显式设计 state handoff。 | 论文 RF 由 captured/serialized FPGA parallel data 经外部高速 AWG 重构，不是直接 6.4-Gb/s GT RF-pin 测量。SMASH 增加阶数、系数、稳定性约束和可能的多路 PA；不能直接改动冻结 `B1=0, B2=-1`。 |

---

## 3. 逐篇可借鉴内容

### 3.1 Roverato 2017：把可编程 OOB/RX-band 噪声做成系统规格

论文的关键不是“使用了 DSM”本身，而是同时处理：

```text
quantization noise + DAC mismatch/timing error + RF output filtering
```

对本项目最有价值的借鉴是方法论：

1. 对每个工作频点定义目标带、邻道、可能的 FDD RX-band 和所需抑制量；
2. 在定点模型中先扫 NTF 系数、输入 backoff 与 BPF，而不是只比较 SNDR；
3. 将硬件误差单列，不能把它误判为 DSM 算法差：GT jitter、word slip、
   polarity/duty-cycle error、外部 driver timing、DPA 与 BPF 响应都应单独注入；
4. 最终报告 EVM、ACLR、带内外积分噪声、输出功率和滤波器损耗。

当前 BP-EFDSM2 的零点固定在 `Fs/4`。如日后需要 programmable RX-band
notch，必须作为新算法重新完成稳定性、定点、时序和 temporal state-transfer
证明，而不是在线修改现有 SKU 的系数。

### 3.2 Firmansyah 2026：最接近的 FPGA/MGT 系统实现参考

该论文给出了高价值的速度分解方式：

```text
effective sample rate = L x fclk
MGS line rate = 4 x fc for its I/Q quarter-rate mapping
```

它说明降低 `L` 会提高每 channel clock，放宽 interpolation FIR 的 transition
band 并减少 DSP；提高 `L` 会降低 fabric clock，却使 FIR 更长、资源更多。
这个 trade-off 可直接用于项目前端 interpolation/DUC 与 GT gearbox 选择。

但必须保留一个关键区分：他们的 pipelined first-order TIDSM 是为该递归关系
专门推导的。项目 BP-EFDSM2 有 `e[n-2]` 反馈，普通寄存器不能在 64 sample
递归链中随意插入。项目必须继续使用 exact state-map、prefix composition 或已
证明的 state prediction，而不能把“每 lane 一个 DSM”称为 bit-true temporal64。

该论文还支持如下 GT 验证顺序：

```text
known non-symmetric word -> PRBS31 -> long counter -> frozen DSM vector -> RF chain
```

其中冻结 DSM vector 的恢复序列必须逐 bit 等于 Python/MATLAB oracle；GT 不能
使用 8b/10b、64b/66b、scrambler 或 padding，因为它们都会修改 RF 波形。

### 3.3 Zhang 2025：未来 PA 协同设计的候选，而不是现有 RTL 的补丁

这篇 ISSCC 工作的核心是：

```text
multi-bit I/Q -> three-level DSM I/Q -> 9-state LUT -> AM/PM
             -> phase-edge selection + 1-bit PA
```

它有三项可借鉴的洞察：

- 量化到有限状态后，小 LUT 可以替代大规模 CORDIC/极坐标转换；
- 截断到更低的 PA 控制分辨率会产生相关误差，因此需要 error feedback；
- phase transition 不是理想抽象，大于 180-degree 的跳变可能产生 overlap，
  必须在数字控制端显式处理。

不过，这些优势依赖完整的 PA/LO/transformer 协同实现。本项目目前的 GT 输出
是一个时序有序的实数 BP bitstream，尚无八相 PA 或 `4fc` LO。因此该论文适合
未来定义一个独立的 polar PA research branch；不应破坏现有 bit-true 合同。

### 3.4 Xu 2025：SMASH 的可调多带 NTF 与 state propagation

SMASH 将多个带通 stage 串接，并使每个 stage 对应一对可调 complex zeros：

```text
stage count N -> number of passbands/notches
g_i            -> center frequency of notch i
a_i            -> pole position, notch width, and stability margin
```

其中：

```text
g_i = 2 - 2 cos(2*pi*f_c,i/f_s)
```

在研究层面，这为单带/双带可重构提供了清晰的参数接口。更重要的是，论文将
parallel DSM 的 state propagation 明确放在 architecture 中，而不是假设各
lane 彼此独立。这个原则与项目 temporal64 完全一致。

如果多带是明确需求，安全的第一步应是 MATLAB/Python fixed-point feasibility
study：检查 `N`、`g_i`、`a_i`、量化系数、输入幅度稳定范围、两 band 最小间隔、
PA/BPF 响应及 ACLR/EVM。该结果通过后才设计 RTL 和高吞吐 state transfer。

---

## 4. 与项目相关的扩展文献地图

| 工作 | 架构与意义 | 对项目的作用 |
|---|---|---|
| Frappe et al., JSSC 2009 | 早期高速 DSM 数字 RF generator；DSM sample rate 达 4 GHz，并展示 image-band RF。 | 说明 effective DSM rate、RF carrier 与 image-band 不能混为一谈。 |
| Thiel et al., IMS 2011 | LPDSM + digital upconversion + switching PA。 | Cartesian LPDSM 的经典概念参考。 |
| Tanio et al., IMS 2016 | FPGA time-interleaved DSM，28-GHz effective DSM，但 WLAN RF 示例约 5.2 GHz。 | 反例：28-GHz DSM rate 不等于 28-GHz RF carrier。 |
| Tanio et al., IMS 2017 | 9.6-GHz second-order TI-DSM，500-MHz bandwidth。 | 高阶、宽带和 FPGA 资源/时序代价的参考。 |
| Wang et al., JLT 2019 | Virtex-7，32-pipeline、5-GSa/s real-time DSM。 | 高吞吐 FPGA 并行 DSM 的实现与验证参考。 |
| Pereira et al., TCAS-II 2023 | frequency-agile real-time ADT，1-GHz bandwidth。 | 高 Nyquist image 的潜力与风险参考。 |
| Pereira et al., TCAS-I 2023 | LUT-based resource-optimized ADT。 | 与实时计算 DSM 的资源/灵活性取舍基线。 |
| Zhang et al., JSSC 2024 | 1-bit DSM digital quadrature PA + hybrid FIR。 | 量化噪声与 PA/filter co-design 的现代 comparator。 |
| Chang et al., MWTL 2025 | 2 x 16-GS/s MGT 低成本 ADT。 | 与本项目 MGT 速率等级接近；仅用 MGT 产生 RF 不是新颖点。 |
| Li et al., ISSCC 2026 | 6-GHz quadrature digital TX，1-GHz signal bandwidth，28-nm RFIC。 | 作为 RFIC performance ceiling，不应与 FPGA 单比特 GT ADT 直接横比。 |

---

## 5. 频率选择与可报告边界

### 5.1 3.5 GHz 是当前主工作点

```text
Rraw = 14 Gb/s
Fs   = 14 GS/s
fc   = Fs/4 = 3.5 GHz
```

优点：

- 属于 sub-6-GHz/5G 常见应用区间；
- 比 16.375-Gb/s 理论上限保留约 14.5% raw line-rate margin；
- BPF、走线、连接器、仪器与调试风险低于更高频 stretch point；
- 与 FPGA ADT 和一比特数字 PA 文献都有合理比较对象。

### 5.2 4.09375 GHz 只能作为后续 rate-limit 实验

若 raw line rate 固定为 16.375 Gb/s 且采用 quarter-rate mapping：

```text
fc = 16.375 / 4 = 4.09375 GHz
```

这可作为 serializer-limit figure，但不应在 GT、时钟、板级和 BPF 尚未稳定前
作为首个硬件 demo。

### 5.3 高 Nyquist 镜像与模拟上变频

高区镜像可能在数字谱上存在，但 RF 输出幅度会受 pulse-shape/ZOH droop、
GT analog bandwidth、package/PCB loss、jitter 与 BPF 选择性的共同限制。必须
实际测量，不能从 `Fs/2` 或某个“有效 DSM rate”直接推断可用载波。

对于明确高于 3.5 GHz 的目标，模拟上变频是更稳妥的系统选择：先建立并验证
3.5-GHz 或更低 IF 的一位输出链，再以 LO/mixer 迁移到目标 GHz 频段；代价是
必须额外评估 mixer image、LO phase noise 和链路 EVM。

---

## 6. 对项目的分阶段推进计划

| 优先级 | 工作项 | 通过条件 |
|---:|---|---|
| P0 | 完成 TI64 的前端接入、raw-GT 和 BPF 单带验证路径。 | TI64 oracle equality、完整 218.75-MHz STA、GT known-word/PRBS、recovered-vector equality、filtered RF EVM/ACLR/OOB。 |
| P1 | 在现有 real-IF 模型增加 nonideality sweep。 | 给出 GT jitter、word slip、polarity/duty-cycle、driver delay、BPF/DPA response 的假设和 EVM/ACLR/OOB sensitivity curve；不改变冻结位真行为。 |
| P2 | 如果业务需要独立可调双带，先完成 SMASH fixed-point feasibility study。 | 系数、稳定性、两 band 间隔、量化、DPA/BPF 计划均明确；之后才允许 RTL。 |
| P3 | 仅在 custom `4fc` LO 与 multi-phase PA 进入范围时评估 Zhang polar TX。 | 独立架构规格、LUT/error-feedback proof、overlap-error test、PA power/linearity measurement。 |

P0 的验证顺序必须是：

```text
scalar Python/MATLAB oracle
 -> RTL bit-true simulation
 -> FPGA timing closure
 -> GT known word and PRBS
 -> recovered frozen-vector equality
 -> external driver/DPA/BPF RF measurement
```

任意较后一步不能替代较前一步。例如 ILA 只能观察 GT 前的并行 word，不能直接
采样 14-Gb/s pin；串行 bit-order 需要 GT loopback、BERT、外部 receiver 或
高带宽测量仪器。

### 6.1 当前 FPGA TI64 原型

为先完成 MGT 数据平面与板级流程，项目已新增独立的
`ti64_lp1_fs4_gt_tx` 原型。它采纳 Firmansyah 的时分 DSM 实现思路：每个
lane 有明确的一阶 LP error state，64 个有序 bit 经 raw GT 边界输出。其在
`218.75 MHz` 下对应 `14 Gb/s = 14 GS/s`，并由 `+,+,-,-` 的实数符号
序列映射到 `3.5 GHz`。该裸 TI64 内核本身不接收 I/Q，也没有 DPD 或插值器。

该原型的定向 XSim 已检查 128 个 word、8192 个样本在 GT 边界逐 bit 与其
独立 TI oracle 一致；ZU15EG 的 fabric-only OOC 在 `218.75 MHz` 下为
`WNS=+2.390 ns`、`WHS=+0.108 ns`、估算 `Fmax=458.42 MHz`。这说明新的
并行状态组织避免了原 exact 实现的时序瓶颈，但不证明其 RF 性能。该路径
必须在接入真实前端后以 EVM、ACLR、in-band/OOB noise 验收，才有资格成为
可交付调制器。

2026-09-13 已新增独立的 `ti64_cartesian_frontend_tx`。它以 64-sample I/Q
word 为接口，实际串接了 64 份 memoryless DPD、64 份 x1 插值器接口、
`[I,Q,-I,-Q]` 的 full-precision real Fs/4 packer 和 TI64。定向 XSim 在
DPD bypass 与 unity polynomial 两种设置下均通过 24 个 word / 1536 个 bit。
这里的“x1 插值”只保持现有接口与握手语义；现有标量 x4/x8/x16/x32 插值器不能
直接承担每拍 64 个连续样本，因而多倍率 64-phase polyphase 插值器仍是未完成的
下一项。LUT/memory-polynomial DPD 也仍未接入，因为它们需要跨 lane 的记忆状态
handoff，不能伪称为 bit-true。

该 frontend 的 ZU15EG fabric-only OOC 在 `218.75 MHz` 已通过：
`WNS=+1.143 ns`、`WHS=+0.093 ns`、估算 `Fmax=291.68 MHz`，资源为
27,346 LUT、30,722 FF、1,280 DSP48E2（36.28%）、0 BRAM。它比 bare TI64
（0 DSP）昂贵得多，说明前端 DPD 才是当前 FPGA 预算的主导项；这仍不是
GT、板级或 RF 指标通过。

它也不能完成 GT/板级签核：现有模块只到 raw user-data boundary，尚未有
真实 GTH Wizard、TXUSRCLK/reset/CDC 约束、loopback 或恢复位流证据。详见
`docs/SPEC.md` and `docs/VPLAN.md`.

---

## 7. Rocky 8.10 受审计执行环境

2026-09-13 已确认本机有可用的 `Rocky-8.10` WSL distribution，并通过全局
`rocky-wsl-bridge` skill 新增项目静态任务清单：

```text
tools/rocky-bridge.tasks.json
```

已验证：

```text
Rocky Linux 8.10
Python 3.6.8
VCS alias available
dc_shell: /opt/Synopsys/syn/V-2023.12-SP1/bin/dc_shell
Vivado: not installed in Rocky
```

该 bridge 只允许任务 JSON 中预先审阅的静态命令，不传递聊天文字或任意 shell
字符串。使用示例：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  C:\Users\惠普\.codex\skills\rocky-wsl-bridge\scripts\invoke-rocky.ps1 `
  -ProjectRoot E:\workspace\chip\dsm_ip `
  -ConfigPath E:\workspace\chip\dsm_ip\tools\rocky-bridge.tasks.json `
  -WslWorkingDirectory /mnt/e/workspace/chip/dsm_ip `
  -Task toolchain-doctor
```

这说明 AI Agent 可以在 Rocky 8.10 中运行已审计的项目任务。它不会自动获得
Vivado、板卡或远程服务器权限；当前 Rocky 中没有 Vivado，因此 FPGA STA 仍需
native Vivado 或另一台合规 EDA host。

---

## 8. 最终结论

四篇论文共同说明：GHz 低分辨率发射不是“增加 lane 数并串行化”就完成的。
可报告的系统必须同时满足：

```text
exact or explicitly specified DSM state transfer
+ bit-order-preserving raw serializer
+ NTF matched to the required spectral region
+ timing/error-aware RF model
+ measured driver/DPA/BPF chain
```

对当前项目，最合适的组合是：

- 以 Firmansyah 的 serializer/MGT/measurement 方法完成高速系统闭环；
- 以 Xu 的 state propagation 原则约束任何并行 DSM 结构；
- 以 Roverato 的 OOB/RX-band 噪声方法建立性能规格；
- 将 Zhang 的 polar PA 保留为后续硬件协同设计方向。

近期不应更换冻结 BP-EFDSM2。最有价值的下一步是完成 14 GS/s、3.5-GHz
目标下 exact temporal64 的时序和 GT/RF 证据闭环；多带 SMASH 和 polar PA
应在独立规格、模型与验证计划下推进。

---

## 9. 参考文献

1. A. Frappe et al., "An All-Digital RF Signal Generator Using High-Speed
   Delta-Sigma Modulators," *IEEE JSSC*, 2009.
   https://doi.org/10.1109/JSSC.2009.2028406
2. B. T. Thiel et al., "Lowpass Delta-Sigma Modulator with Digital
   Upconversion for Switching-Mode Power Amplifiers," *IEEE MTT-S IMS*, 2011.
   https://doi.org/10.1109/MWSYM.2011.5972816
3. E. Roverato et al., "All-Digital RF Transmitter in 28nm CMOS with
   Programmable RX-Band Noise Shaping," *ISSCC*, 2017.
   https://doi.org/10.1109/ISSCC.2017.7870341
4. E. Roverato et al., "All-Digital LTE SAW-Less Transmitter With DSP-Based
   Programming of RX-Band Noise," *IEEE JSSC*, 2017.
   https://doi.org/10.1109/JSSC.2017.2761781
5. J. Wang et al., "Delta-Sigma Modulation for Next Generation Fronthaul
   Interface," *Journal of Lightwave Technology*, 2019.
   https://doi.org/10.1109/JLT.2018.2872057
6. M. Tanio et al., "An FPGA-Based All-Digital Transmitter with 28-GHz
   Time-Interleaved Delta-Sigma Modulation," *IEEE MTT-S IMS*, 2016.
   https://doi.org/10.1109/MWSYM.2016.7540142
7. M. Tanio et al., "An FPGA-Based All-Digital Transmitter with 9.6-GHz
   2nd-Order Time-Interleaved Delta-Sigma Modulation for 500-MHz Bandwidth,"
   *IEEE MTT-S IMS*, 2017. https://doi.org/10.1109/MWSYM.2017.8058904
8. S. Pereira et al., "Frequency-Agile Real-Time All-Digital Transmitter With
   1 GHz of Bandwidth," *IEEE TCAS-II*, 2023.
   https://doi.org/10.1109/TCSII.2023.3259482
9. S. Pereira et al., "Scalable Resource Optimized LUT-Based All-Digital
   Transmitter," *IEEE TCAS-I*, 2023. https://doi.org/10.1109/TCSI.2023.3274432
10. Y. Zhang et al., "A Time-Mode-Modulation Digital Quadrature Power
    Amplifier Based on 1-bit Delta-Sigma Modulator and Hybrid FIR Filter,"
    *IEEE JSSC*, 2024. https://doi.org/10.1109/JSSC.2023.3349002
11. Y. Zhang et al., "A Power-Efficient CORDIC-Less Digital Polar
    Transmitter Using 1b DSM-Based PA Supporting 256-QAM," *ISSCC*, 2025.
    https://doi.org/10.1109/ISSCC49661.2025.10904639
12. J.-K. Xu et al., "Independently Reconfigurable Multiband All-Digital
    Transmitter Using SMASH Delta-Sigma Modulation," *IEEE TVLSI*, 2025.
    https://doi.org/10.1109/TVLSI.2025.3611974
13. Y.-C. Chang et al., "A Low-Cost All-Digital Transmitter Using
    Multigigabit Transceivers," *IEEE Microwave and Wireless Technology
    Letters*, 2025. https://doi.org/10.1109/LMWT.2025.3611387
14. Y. Li et al., "A 6GHz Quadrature Digital Transmitter Supporting a 1GHz
    Signal Bandwidth with <-20dB EVM Floor and >55dB Dynamic Range in 28nm
    CMOS," *ISSCC*, 2026. https://doi.org/10.1109/ISSCC49663.2026.11409161
15. D. C. Dinis et al., "Low-Resolution All-Digital RF Transceivers: Concepts,
    Innovations, Challenges, and Future Directions," *IEEE Microwave
    Magazine*, 2026. https://doi.org/10.1109/MMM.2026.3674963

## 10. 解释注意事项

跨论文比较时，不得混用以下量：

```text
effective DSM rate != RF carrier frequency
RFIC digital TX performance != FPGA/MGT one-bit ADT performance
AWG-reconstructed RF != direct serializer-pin RF
```

所有性能数字必须同时标注架构、采样/线速率、带宽、调制方式、滤波器、PA/输出
接口和测量位置。

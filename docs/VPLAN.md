# BP EFDSM2 + behavioral DPA/DPD 验证计划

文档版本：1.0

适用主验证 SKU：`dsm_ip_axi_top`，`ALGORITHM=3`、`DUC_MODE=3`、`INTERP_MODE=4`、`INTERP_IMPL=0`，4-tap/5th-order memory-polynomial DPD。

## 1. 验证目标

本计划只把下面链路作为主验证对象：

```text
AXI-Stream Q1.15 IQ
 -> memory-polynomial DPD
 -> x32 interpolation
 -> Fs/4 real-IF mixer
 -> one-bit BP EFDSM2
 -> rf_bit
 -> behavioral DPA + BPF
 -> observation/receiver
 -> EVM/SNDR/ACLR proxy
```

目标是：

- 证明 BP EFDSM2 RTL 的功能、定点行为、有效信号和复位行为正确；
- 证明 AXI-Lite、TX AXI-Stream、feedback AXI-Stream 和 observer 契约正确；
- 证明 DPD 在同一 behavioral DPA、同一波形、同一接收机和 held-out 数据上可重复比较；
- 证明安全 gate、bank commit、saturation fallback 和 AI 边界不被绕过；
- 形成可追溯的 RTL、MATLAB、XSim/VCS、SpyGlass、DC/Vivado 和 behavioral DPA 证据。

## 2. 验证对象与非目标

### 2.1 主要 DUT

```text
top: dsm_ip_axi_top
ALGORITHM=3
DUC_MODE=3
INTERP_MODE=4
INTERP_IMPL=0
ENABLE_DPD_POLY=0
ENABLE_DPD_LUT=0
ENABLE_DPD_MEMORY=1
DPD_MP_MAX_TAPS=4
DPD_POLY_ORDER=5
```

BP 主 RTL 为：

- `rtl/axi/dsm_ip_axi_top.v`
- `rtl/ip/dsm_ip_top.v`
- `rtl/tx_bandpass_if/bp_fs4_iq_mixer.sv`
- `rtl/tx_bandpass_if/dsm_core_bp_ef2.sv`
- `rtl/tx_bandpass_if/tx_bp_if_top.sv`
- `rtl/interp/` 中主配置使用的 x32 插值文件；
- `rtl/dpd/dpd_frontend.v`、`dpd_memory_poly.v`、`dpd_observer.v`；
- `rtl/axis/axis_skid_buffer.sv`。

验证不得复制一份 datapath RTL；source list 必须与 DC/Vivado BP flow 一致。

### 2.2 外部 behavioral DPA

behavioral DPA 位于 MATLAB 闭环，不属于 RTL DUT。每个 profile 必须声明：增益、压缩点、AM/AM、AM/PM、memory taps、噪声、温漂、输出 BPF、receiver、训练/验证/测试 seed。

### 2.3 非目标

- 不把 ADS transient 当作当前 DPD 必需门槛；
- 不把 behavioral 结果称为真实 PA 或硅后结果；
- 不在本计划验证 CNN/MLP 高速 RTL；
- 不把 LPDSM2 旧 Fs/4 合路结果作为 BP EFDSM2 结论；
- 没有真实 feedback receiver 时，不宣称板级 PA 闭环。

## 3. 验证层级

| 层级 | 目标 | 工具/入口 | 输出 |
|---|---|---|---|
| L0 静态 | 文件、参数、编码、接口一致性 | PowerShell、Git | manifest/check summary |
| L1 单元 | BP EF2、IF Mixer、插值、DPD memory、observer | VCS/XSim、MATLAB | unit log、CSV、波形 |
| L2 子系统 | Mixer+BP EF2、DPD+插值、observer pairing | VCS/XSim/MATLAB | scoreboard、bit-true CSV |
| L3 顶层 | AXI-Lite、TX、feedback、错误和状态 | VCS/XSim | smoke/regression summary |
| L4 算法 | MATLAB 与 RTL 逐样本等价 | MATLAB + XSim/VCS | mismatch report |
| L5 RF behavioral | BP 输出经 DPA/BPF 后的质量 | MATLAB | EVM/SNDR/ACLR 表 |
| L6 AI/safety | seed 安全、search、fallback、blind test | MATLAB/Python/PS | policy report |
| L7 实现 | lint、综合、时序、资源、功耗 | SpyGlass、DC、Vivado | implementation evidence |
| L8 板级 | DMA、AXI、ILA、UART、JTAG | Vitis/板卡 | board trace |

## 4. 测试矩阵

### 4.0 testcase 编写规则和 100% 覆盖定义

每个 testcase 必须同时声明以下字段，不能只写一句“场景可运行”：

| 字段 | 必填内容 |
|---|---|
| Test ID | 唯一 ID，例如 `BP-F-001` |
| 编译配置 | top、所有 compile-time parameter、source list hash |
| 激励 | 输入类别、幅度、符号、帧数、seed、stall/复位注入 |
| 运行时配置 | AXI-Lite 寄存器写入、DPD mode、tap/order、observer window |
| 观测点 | 输入/输出 transaction、valid、sideband、状态和计数器 |
| 覆盖 bin | 本 testcase 必须命中的 coverpoint/cross |
| 通过条件 | mismatch、error、fatal、计数器和数值阈值 |
| 证据 | log、波形、coverage database、CSV 和 manifest |

本计划的“100%”不是要求把所有可能的无限输入空间穷举，而是要求：

1. 主 SKU 的声明 functional coverpoint 达到 100% hit；
2. 主 SKU 的声明 cross coverage 达到 100% hit；
3. RTL statement/branch/toggle coverage 达到工具设定的 100% goal，或每个未命中
   分支有明确的 `excluded` 记录和代码/配置依据；
4. 所有 safety negative testcase 均执行，非法操作生效次数必须为 0；
5. 每个 testcase 的 checker、scoreboard、assertion 都启用，不能用关闭 checker
   来换取 coverage；
6. compile-time 被裁剪的分支不计入主 SKU 100%，但必须在对应 optional SKU 回归中
   单独达到同一要求。

覆盖率签核文件必须包含：`coverage_summary`、bin 明细、未命中原因、test-to-bin
   映射、仿真命令和 simulator/tool version。

### 4.1 BP EFDSM2 功能

| ID | 激励与配置 | 检查点 / 覆盖目标 | 通过条件 |
|---|---|---|---|
| `BP-F-001` | reset、零输入，8 个时钟后 enable | reset/enable bins；rf_valid、phase、状态 | 无 X/Z、无发散、复位计数正确 |
| `BP-F-002` | 正小幅常值 `+1,+4096,+32767` | 正幅度 bins；rf_bit 极性 cross | `rf_signed` 与 bit 逐样本一致 |
| `BP-F-003` | 负小幅常值 `-1,-4096,-32768` | 负幅度 bins；符号边界 | 输出符号和饱和规则正确 |
| `BP-F-004` | 正负交替、四相序列 | phase `{0,1,2,3}` cross；状态更新 | Mixer 顺序和 BP bit-exact |
| `BP-F-005` | I-only、Q-only、complex tone | I/Q pattern bins；IF valid latency | phase/valid 对齐正确 |
| `BP-F-006` | QPSK/16QAM/64QAM OFDM 帧 | modulation bins、tlast frame cross | 输入输出 transaction 无丢失 |
| `BP-F-007` | `0x7fff/0x8000` 及 ±1 LSB | min/max/saturation bins | 无错误符号扩展或 wrap |
| `BP-F-008` | 长时间大幅随机输入 | long-run、state range、toggle | 无非预期状态溢出 |
| `BP-F-009` | active stream 中异步复位 | reset-during-stream cross | valid、状态、计数器清晰恢复 |

### 4.2 AXI 流控

| ID | 激励与配置 | 检查点 / 覆盖目标 | 通过条件 |
|---|---|---|---|
| `AXI-F-001` | 连续 valid/ready | valid-ready 交叉；0/1 stall | 无丢失、重复、重排 |
| `AXI-F-002` | 25/50/75% 随机下游 stall | stall bins；payload stability assertion | stall 中 payload/sideband 保持 |
| `AXI-F-003` | valid 单周期、valid gap 1/7/31 | gap cross | 只在握手时接收 |
| `AXI-F-004` | 单帧、空帧、多帧 tlast | frame length `{1,24,256}` bins | frame count 正确 |
| `AXI-F-005` | tuser=0/1、连续错误 | tuser cross | error/user count 正确 |
| `AXI-F-006` | disabled 发送、重新 enable | enable cross | 不产生非法有效数据 |
| `AXI-F-007` | AW/W 同周期、AW 先、W 先 | channel ordering cross | 一次写只执行一次 |
| `AXI-F-008` | BREADY/RREADY 延迟 0/1/16 周期 | response hold bins | response 保持到 ready |

### 4.3 DPD 和安全

| ID | 场景 | 通过条件 |
|---|---|---|
| `DPD-F-001` | identity C1=1 | 输出与 bypass 对齐一致 |
| `DPD-F-002` | 合法 C1/C3/C5 | 与 MATLAB 定点结果一致 |
| `DPD-F-003` | 4-tap MP | tap/order 映射正确 |
| `DPD-F-004` | 超限系数 | shadow invalid，active 不变 |
| `DPD-F-005` | 非法 commit | failed，输出不切换 |
| `DPD-F-006` | 安全边界 commit | 只在 safe boundary 换 bank |
| `DPD-F-007` | saturation fault | fallback bypass，清 fault 后可恢复 |
| `DPD-F-008` | 未编译 mode | effective mode 回退 bypass |
| `DPD-F-009` | AI 危险 seed | 不绕过安全 gate/local search |

### 4.4 Observer

| ID | 场景 | 通过条件 |
|---|---|---|
| `OBS-F-001` | delay=0/gain identity | paired/error 正确 |
| `OBS-F-002` | 非零 delay | reference ring buffer 对齐 |
| `OBS-F-003` | complex gain | I/Q 旋转缩放正确 |
| `OBS-F-004` | feedback tlast | last_seen/done 正确 |
| `OBS-F-005` | invalid feedback | drop 增加，窗口无效 |
| `OBS-F-006` | feedback 早到 | ref unavailable 时 drop |
| `OBS-F-007` | accumulator overflow | overflow flag 正确 |
| `OBS-F-008` | temperature | start 时锁存温度 |

### 4.5 behavioral DPA/DPD

| ID | impairment/profile |
|---|---|
| `RF-F-001` | linear reference |
| `RF-F-002` | AM/AM gain/compression |
| `RF-F-003` | AM/PM |
| `RF-F-004` | memory taps |
| `RF-F-005` | observation noise |
| `RF-F-006` | gain/phase temperature drift |
| `RF-F-007` | combined controlled behavioral DPA |
| `RF-F-008` | permanently isolated blind PA profiles |

每个 profile 必须比较 no-DPD、memoryless DPD 和 memory-polynomial DPD；AI 还要比较 LUT seed、AI seed 和 mandatory local search。

### 4.6 Future work: FMC feedback-loop integration (not implemented)

This section is a future hardware-integration plan, not a current verification
test matrix. The current board BD ties `s_axis_obs_*` to synchronous zero
constants. No FMC DPA/PA, receiver, ADC, feedback DMA, or feedback clock-domain
crossing has been implemented or verified. The intended future connection is:

```text
rf_bit -> FMC 外部 1-bit DPA/PA -> 输出 BPF/耦合器
        -> 接收机下变频/ADC -> 复数 Q1.15 AXI-Stream
        -> 时钟转换/异步 FIFO -> s_axis_obs_*
        -> dpd_observer -> AXI-Lite 状态/统计 -> PS 校准控制
```

| Future ID | Planned hardware work | Required evidence before claiming closure |
|---|---|---|---|
| `FMC-PRE-001` | Add DPA/PA, output filter, coupler, receiver and ADC on an FMC design | Schematic, clock plan and calibrated power limits |
| `FMC-PRE-002` | Convert ADC I/Q to Q1.15 AXI4-Stream | Format, sample-rate and latency contract |
| `FMC-PRE-003` | Cross receiver clock to `aclk` through async FIFO/clock converter | CDC/RDC review and no loss/reorder evidence |
| `FMC-PRE-004` | Replace zero constants on `s_axis_obs_*` | Vivado BD, bitstream and ILA capture |
| `FMC-PRE-005` | Execute observer/DPD loopback validation | Measured feedback, EVM/ACLR and before/after DPD result |

Until all five items exist, `s_axis_obs_*` and `dpd_observer` are verified only
with simulation/digital replay contracts. They are not a measured RF feedback
loop and must not be used as such in project claims.

### 4.7 DPD calibration 与 AI policy

#### Current implementation status

| Item | Current state | Evidence / limitation |
|---|---|---|
| Q2.14 4-tap C1/C3/C5 MP DPD RTL | Implemented | `dpd_frontend.v` instantiates `dpd_memory_poly.v`; mode 3 is compiled in the main SKU |
| Coefficient shadow-bank write and safe commit | Implemented | PS writes `MP_SELECT`/`MP_DATA`, then `MP_COMMIT`; RTL changes bank only at a safe boundary |
| PS bare-metal candidate/package replay | Implemented as test/calibration-control software | `dsm_dpd_baremetal_smoke.c` writes packages, runs DMA, reads counters and emits `CAL_TRACE` |
| Internal monitor cost | Implemented | It measures input/DPD-output/RF-bitstream proxy values, not PA output EVM/ACLR |
| Feedback observer RTL contract | Implemented | It accepts digital feedback on `s_axis_obs_*`; current board sends no valid feedback samples |
| Physical DPA/PA -> receiver/ADC -> feedback | Not implemented | Board BD ties observation input to zero constants |
| Closed-loop DPA coefficient identification | Not implemented on hardware | MATLAB behavioral DPA supports this algorithmically; board has no physical feedback evidence |
| AI direct deployment | Disabled | Existing qualified policy forces a 14-candidate bounded local search |

Therefore, the existing board flow proves coefficient loading, mode selection,
safe bank commit, DMA replay and proxy-cost control flow. It does **not** prove
that the selected coefficients improve a physical DPA/PA.

#### Verification ownership and release gates

The verification domains below are deliberately separate. Passing one domain
does not close another domain's signoff obligation.

| Gate | Owner and scope | Required evidence | Current signoff boundary |
|---|---|---|---|
| `MON-RTL` | RTL/UVM: monitor arithmetic, window/reset behavior, and AXI-Lite register mapping | Apply known IQ and `rf_bit` sequences; compare `MON_INPUT_POWER`, `MON_OUTPUT_POWER`, `MON_EVM_PROXY`, `MON_ACPR_PROXY`, and `MON_SPEC_*` against a frozen MATLAB/Python reference for every completed window | Required before claiming monitor correctness; it does not establish physical RF power or ACPR |
| `RTL-PROTOCOL` | RTL/UVM: AXI-Lite, TX/observer AXI-Stream, DPD datapath, coefficient bank commit, fallback, and error paths | Scoreboard, assertions, negative tests, functional coverage, and long backpressure/reset regressions | UVM verifies the RTL/DUT; it does not validate the PS search policy or PA model |
| `PS-SW` | Bare-metal C: register sequencing, DMA replay, cost calculation, candidate sorting, and commit/fallback handling | C unit test plus C/Python fixed-point equivalence for each candidate result | Required before claiming a correct PS calibration controller; it does not prove RTL arithmetic or RF improvement |
| `POLICY` | Python/C policy: known/unknown/OOD decisions, seed selection, bounded search, and safety gates | Identical decision log and ranking for all vectors; 14 evaluated candidates and zero unsafe direct acceptance | Required before enabling a release policy; this is a slow control-plane algorithm, not an RTL neural network |
| `RF-BEHAVIORAL` | MATLAB/Python: behavioral DPA, receiver alignment, and metric calculation | Held-out no-DPD/memoryless/MP comparison using the same waveform, DPA, BPF, receiver, and metric script | Required for a behavioral EVM/SNDR/ACLR claim; it is not measured hardware RF evidence |
| `FMC-FEEDBACK` | Board integration: DPA/PA, coupler, receiver/ADC, feedback capture, and CDC | Calibrated physical feedback samples and before/after measured metrics | `NOT_IMPLEMENTED`; excluded from the current signoff claim |

`MON_INPUT_POWER` and `MON_OUTPUT_POWER` are RTL accumulators. They must be
numerically verified, but they are diagnostic and safety observables only.
In the current one-bit normalized RF output path, `MON_OUTPUT_POWER` has weak
candidate discrimination. The active bare-metal `calibration_cost()` uses the
replay EVM proxy, saturation/clip/error/stall penalties, `MON_EVM_PROXY`,
`MON_ACPR_PROXY`, and `MON_SPEC_ADJ`; it does not use either monitor-power
register as a primary optimization term. No `MON_*` proxy may be reported as a
measured PA output power, EVM, or ACPR value.

The selectable regression set is:

| ID | Verification objective | Pass condition |
|---|---|---|
| `MON-RTL-001` | Per-window monitor arithmetic | Reference and RTL register values match for all selected known-vector windows |
| `MON-RTL-002` | AXI-Lite monitor readback | Every monitor offset returns the frozen expected value after the matching window completes |
| `UVM-RTL-001` | DPD/AXI/observer nominal behavior | Scoreboard and assertions report zero errors |
| `UVM-RTL-002` | Bank commit, saturation fallback, observer faults, reset, and long stalls | No illegal active-bank update, dropped transaction, or unhandled error path |
| `PS-SW-001` | C/Python cost and ranking equivalence | Bit-exact cost and identical candidate ordering |
| `PS-SW-002` | Bounded search and safety fallback | Exactly 14 candidate evaluations; unsafe candidates cannot become active |
| `POLICY-001` | Known/unknown/OOD policy equivalence | Identical fallback reason and zero unsafe direct decisions |
| `RF-BHV-001` | Behavioral DPA DPD effectiveness | Reproducible held-out EVM/SNDR/ACLR comparison with declared DPA/receiver assumptions |
| `FMC-001` | Physical feedback-loop effectiveness | Pending external DPA/PA and receiver/ADC integration; not a current release gate |

The present UVM environment is a connectivity scaffold for the actual DUT. Its
implemented smoke covers basic AXI-Lite enable, TX AXI-Stream traffic, and RF
polarity/toggle checks. It must be extended with the `UVM-RTL-001` and
`UVM-RTL-002` suites before UVM signoff is claimed.

这里的 AI 是校准策略，不是高速数据通路神经网络。当前已接入的 RTL
`dpd_seed_predictor` 可以根据 condition/monitor 输入给出 seed package、
`condition_known`、fallback 和 local-search 标志；PS/离线代码负责候选评估、
成本比较和最终系数提交。当前策略要求始终保留 14-candidate bounded local
search，因此还没有启用“一候选直接放行”。

| ID | 激励/操作 | 检查点 | 通过条件 |
|---|---|---|---|
| `AI-F-001` | 已知 development condition | seed package 与 reference policy | seed 格式、候选起点和 policy decision 一致 |
| `AI-F-002` | 未知 QAM/BW/backoff/temperature | `condition_known=0` | fallback 标志正确，仍执行 14 候选 |
| `AI-F-003` | monitor clip/saturation/stall/error | monitor fault gate | 不论距离是否近，均进入保守搜索 |
| `AI-F-004` | OOD monitor state | feature range/OOD | 不允许 direct，记录 fallback reason |
| `AI-F-005` | 训练/验证 LOSO | development profiles only | held-out condition 不泄漏，结果可重复 |
| `AI-F-006` | 3 个 frozen blind profiles | frozen selector replay | blind 不参与训练/阈值/结构选择，安全违规=0 |
| `AI-F-007` | 合法 seed package | PS-C/Python 等价 | 每个决策 0 mismatch |
| `AI-F-008` | 危险 seed/超限系数 | safety gate + bank commit | active bank 不被非法更新 |
| `AI-F-009` | no-DPD/memoryless/MP/seeded search | 同一 DPA/waveform/receiver | 主表记录 EVM、SNDR、ACLR、cost、候选数 |
| `AI-F-010` | 校准后复测 | before/after observer metrics | 质量不退化，且安全计数为零 |

### 4.8 Future PS/FMC operation sequence

After the future FMC loop is implemented, its software operation must record:

1. `RESET`：清空 valid、计数器、observer 和 DPD fault。
2. `DISCOVER`：读取 `VERSION`、`CAPABILITY` 和 `EFFECTIVE_STATUS`。
3. `CONFIGURE`：写 DPD 模式、MP tap/order、observer delay/gain/window 和 condition。
4. `RUN_TX`：通过 DMA 发送固定 Q1.15 waveform，并保存 input count/frame count。
5. `CAPTURE_FB`：从 FMC 接收机/ADC 取得 feedback AXI-Stream，检查时钟域和 tuser。
6. `OBSERVE`：等待 `done`，读取 paired/drop/error/power/monitor/overflow。
7. `FIT`：只在 drop=0、overflow=0、无 clip/saturation 的窗口拟合系数。
8. `STAGE_COMMIT`：写 inactive bank，轮询 commit status，确认安全边界 ack。
9. `REPLAY`：重放同一 waveform，比较 no-DPD 与校准后指标。
10. `ACCEPT/FALLBACK`：质量退化、错误或未知状态时保持 bypass/14-candidate 安全路径。

## 5. 参考模型与 scoreboard

MATLAB reference 必须明确 Q1.15/Q2.14、二补码、舍入/截位/饱和、BP 状态初值、更新顺序、Mixer phase、插值 valid/latency、DPD 对齐和 output valid 对应的样本编号。

scoreboard 只在 `valid && ready` 时推进 transaction index。transaction 至少包含输入 I/Q、tlast/tuser、DPD 输出、IF sample、rf_bit、rf_signed、rf_valid、phase、错误和计数器快照。

bitstream、valid、sideband、错误状态必须 bit-exact；EVM/SNDR/ACLR 必须使用冻结 receiver/metric script。

## 6. 覆盖率计划

### 6.1 功能覆盖

必须覆盖 reset、enable/disable、AXI handshake、随机 stall、tlast/tuser、DPD mode/fallback、MP pending/inflight/ack/failed、saturation、observer start/clear/done/drop/overflow、condition known/unknown、seed fallback/local search。

### 6.2 数值覆盖

必须覆盖 0、正负小幅、满幅、符号翻转、Q1.15 最值、identity 系数、正负非线性系数、tap0/tap3、order1/order3/order5、delay0/最大 delay 和温度边界。

### 6.3 结构覆盖

VCS/XSim 需要 statement/branch/toggle coverage。编译期关闭的 polynomial/LUT 分支单独标为 excluded；BP 主路径、memory DPD、AXI wrapper 和 observer 不得排除。

## 7. 回归命令

MATLAB：

```matlab
cd('E:/workspace/chip/dsm_ip/matlab');
path_setup;
run('scripts/entry_lpdsmdpa_bpf_dpd_bittrue_compare.m');
run('scripts/entry_lpdsmdpa_bpf_dpd_staged.m');
```

Windows XSim：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_tx_routes.ps1
```

Linux DC：

```bash
export DC_SHELL=/opt/Synopsys/syn/V-2023.12-SP1/bin/dc_shell
bash syn/run_lint_bp_ef2_axi.sh
bash syn/run_bp_ef2_28nm_dc.sh
```

SpyGlass/VCS 必须在 Linux EDA 环境使用与 DC/Vivado BP flow 相同的 source list、top 和参数，不得复制 datapath RTL。

Packaging/FPGA：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_bp_ef2_axi.ps1 -Part xczu15eg-ffvb1156-2-i
```

## 8. 通过判据

Blocker 包括语法/elaboration/link error、多个驱动、AXI protocol violation、valid transaction 丢失/重复、BP bit 极性错误、状态发散、非法系数替换 active bank、overflow 窗口被接受、错误回退失效、unmapped/zero-area PPA 报告。

可接受 warning 只能是已解释并记录的 compile-time pruned optional ports、兼容输出和工具 signedness warning。shorted outputs、unloaded nets、未约束端点和高扇出必须逐项分类。

质量门槛：bitstream/valid/AXI transaction 0 mismatch；安全 negative tests 0 次非法 package 生效；observer 有效窗口 drop=0、overflow=0；behavioral DPA 结果可重复且数据隔离；AI 不增加安全违规；PPA 报告非零 mapped 且注明 PVT/part。

## 9. 证据归档

每次回归生成唯一 run ID，记录 manifest、命令、工具版本、参数、输入向量 hash、结果摘要和失败日志。`docs/evidence/` 只保留精简摘要；原始大型波形和工具 cache 不进入公开交付包。

## 10. 变更影响矩阵

| 变更 | 必跑验证 |
|---|---|
| BP EFDSM2 算术/状态 | BP unit、MATLAB/RTL bit-true、IP smoke、PPA |
| Mixer phase/IF scaling | BP unit、RF metric、MATLAB/RTL bit-true |
| interpolation | interpolation unit、BP chain、PPA |
| DPD/系数格式 | DPD bit-true、DPA comparison、safety、PPA |
| AXI/register | AXI top、observer、packaging、lint |
| observer | observer unit、overflow/drop negative test |
| compile parameters | manifest、lint、simulation、synthesis |

## 11. 可执行 testcase 规范与 100% 覆盖签核

### 11.1 testcase 必填字段

每个 testcase 必须明确写出：

| 字段 | 要求 |
|---|---|
| Test ID | 唯一编号，例如 `BP-F-001` |
| 编译配置 | top、compile-time parameters、source list/hash |
| 激励 | 输入类别、幅度、符号、帧数、seed、stall/复位注入 |
| 运行时配置 | AXI-Lite 寄存器、DPD mode、tap/order、observer window |
| 观测点 | input/output transaction、valid、sideband、状态、计数器 |
| 覆盖目标 | coverpoint、cross、assertion 和应命中的 bin |
| 通过条件 | mismatch、error、fatal、计数器和数值门槛 |
| 证据 | compile/run log、波形、coverage database、CSV、manifest |

### 11.2 覆盖率 100% 定义

本项目的 100% 是对已经冻结的覆盖模型签核，不是对无限输入空间做穷举：

1. 主 SKU 声明的 functional coverpoint 命中率为 100%。
2. 主 SKU 声明的 cross coverage 命中率为 100%。
3. statement、branch、toggle 和 assertion coverage 达到 100% 目标；未命中项必须
   有独立 `excluded` 清单和代码/配置依据。
4. 所有 safety negative testcase 均执行，非法 package 生效次数为 0。
5. scoreboard、protocol checker 和 assertions 必须启用，不能关闭 checker 换覆盖率。
6. compile-time 被裁剪的 polynomial/LUT branch 不计入主 SKU，但必须在对应 optional
   SKU 回归中达到同样的覆盖目标。

任何未命中 bin 都必须增加 directed stimulus 或证明其确实不可达，不能直接删除 bin。
签核报告必须包含 bin 明细、未命中原因、test-to-bin 映射、命令和工具版本。

### 11.3 Directed testcase 清单

| Testcase | 主要覆盖内容 | 必须命中的场景 |
|---|---|---|
| `tc_bp_reset_boundary` | BP、复位和 enable | reset、enable、active stream reset、RF valid |
| `tc_bp_numeric_extremes` | 数值边界 | 正负小幅、满幅、`0x7fff/0x8000`、饱和、bit/sign |
| `tc_bp_phase_iq` | IF mixer | I-only、Q-only、complex、phase 0/1/2/3、valid latency |
| `tc_bp_frames_modulation` | 帧和调制 | QPSK/16QAM/64QAM、1/24/256 样本帧、tlast |
| `tc_axi_handshake_random` | AXI 流控 | 连续流、25/50/75% stall、valid gap、B/R backpressure |
| `tc_axi_sideband_order` | sideband 和 AXI-Lite | tlast/tuser、disabled、AW/W 同时/分离到达 |
| `tc_dpd_modes` | DPD 运行模式 | bypass、合法 MP、tap 1/2/3/4、order 1/3/5、未编译 mode |
| `tc_dpd_safety_commit` | DPD 安全 | `24576/24577` 边界、非法 commit、busy/idle commit、saturation |
| `tc_observer_nominal` | observer 正常路径 | delay 0/最大、identity/complex gain、tlast、temperature |
| `tc_observer_negative` | observer 异常路径 | invalid、early feedback、drop、overflow、窗口无效 |
| `tc_ai_policy_safety` | AI 策略 | known/unknown/OOD、seed fallback、14-candidate local search |
| `tc_rf_metric_matrix` | behavioral DPA | linear、AM/AM、AM/PM、memory、noise、temperature、3 blind profiles |

### 11.4 testcase 通过条件

- AXI transaction、valid/sideband、BP bit、signed 编码：0 mismatch。
- UVM fatal/error、protocol assertion、scoreboard error：0。
- 非法系数或非法 bank commit 生效：0 次。
- 有效 observer 窗口：`drop=0`、`overflow=0`、`last_seen=1`。
- blind profile 永久不进入训练、阈值选择或结构选择。
- 主 RF 比较使用同一 waveform、DPA、BPF、receiver 和 held-out 划分。
- 每次回归生成 test-to-bin hit list；未达到 100% 时不称为 signoff。

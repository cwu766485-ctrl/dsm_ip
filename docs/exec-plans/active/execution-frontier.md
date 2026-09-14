# 执行前沿

## 2026-09-14 x4 polyphase 时序闭环

- 已确认根因：原始单拍 x4 polyphase FIR 的 vector-DPD 寄存器到 FIR 输出寄存器路径为
  9.144 ns（其中逻辑 6.914 ns），无法满足 GTH `TXUSRCLK2=218.75 MHz` 的 4.571 ns 周期；
  不是 LUT、DSP、BRAM 资源不足。
- 已实现保持定点算术、舍入/饱和及 lane 时间顺序不变的 elastic 流水 FIR。三段部分和版本的
  routed 结果把 WNS 从 `-4.480 ns` 改善到 `-1.915 ns`，WHS 为 `+0.016 ns`；剩余关键级为
  high-tap 乘加、三部分和合并及 round/saturate。
- 四级 high-tap 寄存版本暴露了根因：Vivado 将三组部分和合并为一个三操作数 DSP，产生 96 条
  multi-driven-net critical warning；该 build 已停止且不作为 STA 证据。显式 `sum3()` 函数未改变该
  推断，亦已废弃。
- 已完成五级 elastic FIR：low/mid 部分和先在独立寄存级合并，再与 high 部分和相加并
  round/saturate。它只增加 latency，不改变 `(low+mid)+high` 算术、量化、饱和或 lane 时间顺序；
  steady-state 仍为每拍接收一个 16-sample word。
- 五级端到端 x4 oracle XSim PASS；P0 回归 7/7 PASS（每项 65,536 samples、零错误）；IP smoke
  五项 PASS。干净 ZU15EG routed build 以 0 errors、0 critical warnings 完成：`WNS=+0.387 ns`、
  `TNS=0`、`WHS=+0.010 ns`、`THS=0`，全部用户时序约束满足。外部产物已生成 bit/ltx/报告；
  资源为 20,835 LUT、21,203 FF、385 DSP、4 BRAM。
- 下一动作：将 `D:\TraeTemp\ti64_raw_gt14_sfp0_x4_fivestage_20260914\ti64_raw_gt14_sfp0_x4.bit`
  下载到 ZU15EG，进行 SFP0 物理回环和 ILA word-order 验证；在实际捕获前不能把实现通过等同于
  已观测到物理 14 Gb/s 串行输出，更不能宣称 14 GHz RF 载波。

## 2026-09-13 Supporting verification milestone

- Added the long-run UVM constrained-random extension: a 4,096-input pseudo-random Q1.15 bit-true vector, the dsm_longrun_bittrue_test, and a 4,096-item system-closure traffic burst.
- Added a second, communication-oriented bit-true path: MATLAB exports 10,240 quantized 16-QAM OFDM baseband I/Q samples (128 complete CP-OFDM symbols); Python generated 327,680 expected RF transactions and dsm_qam_ofdm_bittrue_test consumes the pair.
- Rocky-8.10 preflight found VCS as a login-shell alias, but the approved UVM task failed before compilation because VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1/linux lacks bin/vcs1 for the active WSL2 machine type. No UVM result is claimed.
- Next action: repair or select the compatible Rocky VCS installation, then run and archive queue-drain, UVM-error, and coverage evidence for both long-run tests before treating either as verified.

## 当前目标

交付可在 ZU15EG 上验证的发射链：16 个有序基带 I/Q 输入样本/拍，经
vector DPD、x4 polyphase、64-lane TI64 和 raw GTH，形成 14 Gb/s 的一位电气串行流。
`Fs/4` 对应的中心频率为 3.5 GHz；14 Gb/s 不是 14 GHz RF 载波。

## 当前状态

- x4 RTL 已接通：`16-lane I/Q -> 16-lane vector DPD -> 16x4 polyphase -> 64-lane
  I/Q -> [I,Q,-I,-Q] -> TI64 -> raw-GT word`。polyphase 保存 7 个跨 word 的时域历史，
  lane 0 始终是最早样本。
- vector DPD 当前支持 bypass 和 memoryless polynomial；LUT DPD 与 memory-polynomial
  仍未实现 vector 配置/历史交接，必须保持为独立后续项。
- 端到端 x4 XSim 已 PASS：32 个 16-sample 输入 word，经独立 FIR/DSM oracle 比对，
  覆盖 FIR 量化、跨 word 历史、Fs/4 映射、所有 GT bit 顺序及两种已支持的 DPD 模式。
- x4 数据通路修改后的必需 P0 回归已 PASS（7/7，每项 65,536 samples）；最终 IP smoke 也已
  PASS：top、AXI、active-stream reset、BP AXI 和 DPD v1.1 五项检查均完成。
- 板级 x4 top 已把该链路接到 `X1Y12` GTH Wizard 的 `TXUSRCLK2=218.75 MHz` 用户边界；
  暂以内部确定性 16-lane I/Q source bring-up，ILA 观察发出与恢复 word。SFP0 回环、
  主机数据入口、driver/BPF 和 RF 指标均未完成。
- 单实例 x4 board build 已完成 route，并在仓库外生成 bit/ltx；但 `tx_usrclk2=218.75 MHz`
  的 setup WNS=`-4.480 ns`、TNS=`-5091.708 ns`，有 3,102 个失败端点。因此 bitstream 不可
  用于目标速率验证。最差路径是 vector DPD 寄存器至 x4 polyphase 输出寄存器，数据路径为
  9.144 ns（逻辑 6.914 ns），根因是未流水的单拍 FIR。
- 该 routed build 的实现后资源是 13,355 LUT、7,985 FF、397 DSP、4 BRAM；资源均未成为
  当前限制。早先重复启动的 x4 fabric OOC 仍无有效 `summary.csv`，不得引用其结果。

## 下一步

1. 在保持 FIR 算术和逐样本顺序不变的前提下，将 x4 polyphase 拆为至少两级流水，并为
   DPD-to-FIR 和 FIR-to-TI64 加入明确的 valid/ready 延迟契约；用现有 oracle 做 bit-true
   回归，然后重跑单实例 board build。
2. 时序通过后，编程并做 SFP0 光纤或电回环：ILA 同时确认 `tx_ready`、`rx_ready`、`tx_word` 和
   `rx_word`，建立实际 raw-GT bit order；这一步之前不能声称物理 14 Gb/s 输出。
3. 单实例重跑 x4 fabric OOC，记录资源/时序基线；随后再做系数稀疏化、共享乘法或
   流水化优化，不能先牺牲当前逐样本行为。
4. 定义真实 16-lane 基带 ingress 的时钟/CDC/流控，再替换板内确定性 source。
5. 设计 LUT DPD 的 vector read/bank-commit 契约和 memory-polynomial 的 word-boundary
   history hand-off，并分别建立 bit-true oracle。

## 边界

- TI64 是 64 路独立 LP1 状态的 time-interleaved DSM，不是精确 temporal BP-EFDSM2，也不是 MASH。
- XSim 只证明所编译 RTL 和命名向量；fabric OOC 不证明 GT、I/O、CDC 或板级时序；板级实现
  也不证明实物回环或 RF EVM/ACLR/OOB。
- 只在复现失败、确认根因、完成实现/验证里程碑、暂停/交接或下一行动改变时更新本文件。

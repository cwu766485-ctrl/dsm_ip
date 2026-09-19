# 执行前沿
## 当前目标
在 `xczu15eg-ffvb1156-2-i` 上交付可验证的 64-lane 全数字发射数据面：
`64 × 218.75 MHz = 14 GS/s`，一次 `Fs/4` 数字搬移至 3.5 GHz IF。
`14 Gb/s` 是 raw-GTH 串行线速，不是 14 GHz RF 载波。
256-QAM 门槛：同一 OFDM、BPF、DDC、同步和解调口径下，EVM `<= 3.5 %`、
SNDR `>= 29.12 dB`。
任何“宽带”“14 GS/s”或“可上板”结论必须标明以下证据层级：
- 数字行为模型；
- MATLAB-to-RTL bit-true；
- 218.75 MHz fabric OOC；
- 实际 GTH target STA；
- 板级 recovered-word/BERT；
- 参数化 DPA/BPF/DDC 仿真；
- FPGA serializer loopback/BERT（可用时）。
## 当前主链路
`8 complex ingress @ 1.75 GS/s`
`-> x2 polyphase`
`-> 16-lane, shared-history Q2.14 4-tap 1/3/5-order memory-DPD interface`
`-> x2 polyphase`
`-> 32-lane thermometric Cartesian TID`
`-> four 64-bit thermo5 raw words`
`-> four serializer / switching-PA-model paths`
`-> equal-weight behavioural combiner -> BPF -> Fs/4 DDC -> OFDM receiver`。
输入 lane 0 是最早样本；两级 x2 不填零 lane。
四条 PA-model bitstream 采用等权 thermometric 合成 `{−2, -1, 0, +1, +2}` 五电平等效输出；当前没有四路物理 PA/GTH 板级证据。
启动后 feeder FIFO 必须连续供样；TID 输入 underflow 视为错误，不允许插入 bubble。
## 已签核的数字与时序证据
- 完整前端 MATLAB-to-XSim：64 ingress words / 2,048 最终复样本，两条 PA raw stream 均为 0 mismatch。
- 完整前端 OOC：`WNS +0.255 ns`、`WHS +0.027 ns`、TNS/THS 0、0 critical warning / 0 error。
- dual-SFP thermometric payload target：`X1Y12/X1Y13`、RAW/64-bit/14 Gb/s、post-route `WNS +0.324 ns`、`WHS +0.013 ns`、TNS/THS 0、bitstream 已生成。
- 上述 GTH build 的输入是 deterministic smoke pattern，不是板级 256-QAM feeder。
- 尚无 SFP loopback、BERT、recovered-word 或板测 14-Gb/s 结论。
## 接收机与 256-QAM 证据
- raw word 反交织与独立 scalar thermo3：固定 1,056 个 7-GS/s 样本延迟后 0 mismatch。
- 理想 BPF/DDC sanity：NMSE `1.8799e-6`、Fs/4 phase 0、额外 delay 0；该数值来自浮点滤波，不是位序错误。
- 当前完整前端 + behavioral switching-DPA 的 17.08984375 MHz / OSR 409.6 256-QAM test：identity EVM `2.3917 %`、SNDR `32.4257 dB`，通过。
- 该结果使用独立导频帧的每子载波均衡；单复增益仅为诊断，不能作为可否解调的判据。
- 当前完整链路尚未完成 100 MHz 或更高带宽的 PA/BPF/DDC + DPD 验收。
- 2026-09-17 identity 初筛（4/4/4 OFDM symbols、固定 seed 101/137/211、全部 raw mismatch 0）：mild 与 nominal 的最大通过点为 19.6533203125 MHz；synthetic severe profile 的最大通过点为 99.9755859375 MHz。
- severe 的 99.9755859375-MHz 数值通过来自整组 synthetic PA/BPF 参数的耦合；其 `Q=60` BPF 实际比 nominal (`Q=100`) 和 mild (`Q=140`) 更宽，不能归因于“更窄 BPF”或外推为物理 PA 结论。
- 2026-09-17 memory-DPD 候选筛查（2/2/2 symbols、同一隔离 seed）：六个 profile/带宽点均 `HeldOutDeploymentAccepted=0`；RTL 保持 identity 系数。
- 2026-09-17 完整复验（12/10/12 symbols、三套隔离 seed）：mild、nominal、severe 在 17.08984375 与 19.6533203125 MHz 均为 3/3 通过；最坏 case 是 mild / 19.6533203125 MHz，EVM `3.4734 %`、SNDR `29.1849 dB`。
- nominal / 17.08984375-MHz 频谱、EVM/SNDR、PA-side/BPF-side ACLR 对比已导出到 `matlab/out/tid32_thermo3_dpd_figures/`；candidate held-out 较 identity 退化，保持 identity 部署。
- 2026-09-17 在同一 `synthetic_dpa_memory_stress_v1`、17.09-MHz、隔离 6/5/6-symbol 帧下完成四路诊断比较：identity `2.0065 % / 33.9512 dB`，memoryless poly `1.9927 % / 34.0111 dB`，LUT `21.8888 % / 13.1956 dB`（失败），4-tap memory-poly `1.9664 % / 34.1266 dB`。四路 raw-word mismatch 均为 0；所有候选 validation 门禁均未接受，RTL 保持 identity；新增相对 identity 的 ΔPSD 图，未将细小 EVM 优势误画为 ACLR 优势。
## 带宽事实（不得混用）
- **当前完整链路、含行为 DPA/BPF/DDC**：仅已验证 `17.08984375 MHz`。
- **thermo3 TID 数字行为扫描**：五个 seed 在约 `229.86 MHz` 仍通过；此结果不含完整前端、PA、BPF、时钟相噪、GT 抖动或板级链路，推荐数字设计点不高于约 `230 MHz`。
- **三电平 BP-EFDSM 行为候选**：约 `99.9756 MHz` 有通过数值；尚未证明是可流水 temporal TID、未完成对应 RTL/GTH/PA 链路。
- 因此不能说“系统当前最多只能传 100 MHz”，也不能说“完整系统已经通过 100 MHz”。
## DPA / DPD 当前状态
`behavioral_switching_dpa_v1` 已接入两条 thermometric PA 支路：
- duty-cycle 热记忆 AM-AM；
- 开关极性不对称；
- 有限 FIR 记忆；
- 解析信号域 AM-PM；
- `Q=100`、插损 `0.6 dB` 的因果二阶 BPF。
所有参数均导出到 `tid32_thermo3_frontend_pa_profile.csv`，作为数字算法的可复现实验 profile。
它是可调行为 profile，不是 ADS、晶体管、EM、封装、板级或实测 PA 标定；实测标定不属于本项目范围。
12/10/12-symbol Q2.14 memory-DPD 训练结果：
- validation：`2.5254 % / 31.9535 dB -> 2.5122 % / 31.9990 dB`；
- held-out test：`2.3917 % / 32.4257 dB -> 2.3980 % / 32.4032 dB`；
- 结论：`HeldOutDeploymentAccepted=0`，部署系数保持 identity；候选系数只用于诊断。
行为模型中的 PA-side / BPF-side ACLR 为 `−24.0769 / −30.6297 dBc`。
它们不是 RF 签核结果，不得与实测 ACLR 混用。
## 当前风险与冻结项
- 无真实 PA/耦合器反馈数据；这是明确的项目边界，不阻断数字域和参数化仿真验证。
- memory-DPD 尚未通过泛化门禁，禁止写入 RTL/FPGA 寄存器。
- 板级缺少 JTAG target，故尚无 GTH loopback/BERT；Rocky 的 `dc_shell` 可用但 `DSM_ASIC_STDCELL_DB` 未设置，ASIC 综合尚无合法映射库。
- 当前 BPF 是行为级二阶模型，只用于可重复的数字系统仿真。
- 已移除 CRFB temporal8/temporal64 和 TID-MASH11 实验实现：它们没有形成可部署的 64-lane 闭环。保留标量 BP/EFDSM/MASH 基础 IP 与 P0 回归；不再维护这些高阶并行递推候选。
## 当前验收矩阵
### A. 样本节拍
- 外部输入：8 个复样本 / 1.75 GHz。
- 第一级插值：8 个复样本变为 16 个连续复样本。
- DPD 节拍：16 个复样本 / 218.75 MHz word。
- 第二级插值：16 个复样本变为 32 个连续复样本。
- TID 处理：32 个 I 样本和 32 个 Q 样本。
- Fs/4 展开：I/Q 两相位样本形成每 PA 64 个实数 bit。
- PA 支路：两条 raw word 同一拍有效。
- GTH：每条支路 64 bit / 218.75 MHz。
- 组合器：只在两支路时间对齐后相加。
- BPF：只观察等效三电平合成波形。
- DDC：使用已确认的 Fs/4 phase。
- 接收机：每子载波独立导频均衡后计算 EVM/SNDR。
### B. 数字正确性门禁
- 插值器必须保持连续时间次序。
- 不允许将插值产生的新 lane 置零。
- DPD history 必须跨 word 交接。
- DPD quantization 必须保持 Q2.14。
- DPD latency 允许增加但不得插入/丢失样本。
- TID 不能以独立 lane state 替代递推 state。
- raw word bit order 必须在 GT 边界固定。
- 双 PA word 必须同拍、同复位语义。
- de-interleave 必须逐样本匹配 scalar 参考。
- MATLAB-to-XSim 必须逐 bit 通过。
- P0 回归必须全项通过。
- 任一 mismatch 都阻断后续 RF 指标宣称。
### C. 综合与实现门禁
- OOC 仅验证 fabric 的 setup/hold/TNS/THS，不替代 GTH target。
- GTH target 必须使用实际 Wizard、clock/reset 约束，且无 implementation/timing critical warning。
- payload 必须进入 serializer 边界；smoke/bitstream 不等于 QAM feeder 或串行验收。
- loopback/BERT、recovered-word 匹配及板级 clock/reset/相位记录才可证明串行链路。
### D. RF / PA 评价门禁
- EVM/SNDR/ACLR 使用同一波形/带宽与独立导频均衡；ACLR 区分 PA-side 与 BPF-side。
- 行为 BPF/DPA 不是实物滤波器或器件表征。
- train/validation/test 的 seed 和 OFDM 符号必须隔离；profile、向量版本与驱动必须固定记录。
- DPD 仅接受 held-out 三项均改善且不限幅的系数；其他系数不得加载 RTL。
- 仿真结论必须声明 profile，不得外推为器件或板级签核。
### E. 带宽推进门禁
- 17.08984375 MHz 是完整行为链路的已验证点。
- 100 MHz 以上需重做 PA、BPF、DDC/接收滤波、pilot/均衡与 ACLR mask；保留独立 held-out。
- thermo3 的约 230 MHz 仅为数字行为建议上界，不能外推完整链路。
- 模型带宽/行为 EVM 不得宣传为系统吞吐/实测 EVM。
## 下一步（按依赖顺序）
1. 冻结数字签核 baseline：当前 17.08984375 MHz 端到端 256-QAM case、固定向量、profile、接收机和评分脚本。
2. 五电平 thermo5 的 raw Fs/4 DDC 已在 250 MHz 三组隔离 seed 通过；完整两级 x2 的严格 fair-RMS=0.095 复验仅 1/3 通过，但不裁剪的 peak-normalized 12/10/12-symbol、mild-DPA/BPF/DDC 三 seed 全部通过（最差 EVM `3.1831 %` / SNDR `29.9432 dB`，全部 raw mismatch 0）。同口径的 Q2.14 四 tap memory-DPD 仅第 3 组微幅改善、前两组 validation/held-out 退化，部署拒绝，RTL 保持 identity。这是参数化仿真的完整 250-MHz 通过点，不是恒定 RMS、实测 PA、四路 GTH 或板级签核。下一步扫 step/drive/polyphase，保持这组三 seed 资格门槛；只有稳健改善才再次训练 DPD。
3. 冻结并清理未闭环的 CRFB/MASH temporal 候选；若将来重启，必须先有可流水 state-transfer 架构与独立标量等价证明，不能复用已移除的组合链实验。
4. Q2.14 streaming frame-gain sideband 与 `8-lane -> x2 -> identity memory-DPD -> x2 -> thermo5` 全前端已完成：64 word / 2,048 输出样本 / 四平面 MATLAB-to-XSim 0 mismatch；ZU15EG 218.75-MHz routed OOC PASS，WNS `+0.178 ns`、WHS `+0.027 ns`、70,233 LUT / 88,839 FF / 2,064 DSP / 0 BRAM。OOC 的 `HD.CLK_SRC` 与边界 `HD.PARTPIN_LOCS` warning 限制其为 fabric 证据，不能替代 GTH/板级签核。
5. 已定义四支路 serializer/PA 合同并完成全链路 XSim：共享 218.75-MHz user clock、64x 14-Gb/s bit0-first、公共 reset、all-or-none ready；完整 thermo5 前端经四个 serializer/loopback 恢复 64 word / 每支路 4,096 bit，逐 word PASS。当前板仅有 dual-SFP 映射；四路物理 GTH/PA 的引脚、refclk 与 reset 资源尚未提供，不得伪称板级验证。
6. 在同一三 seed 门槛扫 step/drive/polyphase；memoryless/LUT/4-tap DPD 仅在 validation、held-out EVM/SNDR/ACLR 全部改善且不限幅时重训和部署。
7. 完成数字串行链路验证：下载 bitstream 后做 dual-SFP known-word/recovered-word loopback 或 BERT；没有 hardware target 时保留为待执行项。取得合法 `.db` 后另建 thermo5 ASIC pre-layout SKU。
## 最近验证
- `scripts/run_matlab_p0_bittrue_check.cmd`：7/7 PASS，每项 65,536 samples、0 mismatch。
- raw Fs/4 DDC receiver smoke（固定 RMS=0.13、seed=101、4 symbols）：thermo3 在 17.08984375 MHz 为 `3.0637 % / 30.275 dB`，99.12109375 MHz 为 `1.4275 % / 36.909 dB`；thermo5/step=6144 分别为 `3.0613 % / 30.282 dB`、`1.2639 % / 37.966 dB`，均 0 raw mismatch 且通过。thermo5 单 seed 进一步至 276.85546875 MHz / OSR 25.284 仍为 `3.4209 % / 29.3171 dB`；旧 I/Q shortcut 的低带宽失败无效，仍须多 seed/full-frontend DPA/BPF/DDC 复验，禁止接 RTL。
- 五电平 `tid32_thermo5_fs4_multipa_tx`：MATLAB-to-XSim 128 words / 4,096 complex samples / 四路 raw stream 均 0 mismatch；ZU15EG 218.75-MHz routed OOC PASS，WNS `+2.894 ns`、WHS `+0.030 ns`、估算 Fmax `596.15 MHz`，22,699 LUT / 21,464 FF / 0 BRAM / 0 DSP。它是四个完整 TID branch 的保守实现，不是四路 GTH target 或板级结论。
- RTL 改动后的项目回归：P0 7/7 PASS（每项 65,536 samples，0 errors）；IP smoke 的 top、AXI、active-reset、BP-AXI 与 DPD-v1.1 五项均完成且 PASS。
- 五电平 250-MHz raw Fs/4 DDC 三 seed 验收：`STEP=7168`、8 OFDM symbols、fair-RMS `0.11`、seeds `101/307/503`；实际占用带宽 `249.51171875 MHz`、OSR `28.055`、三组均 raw mismatch `0`，最差 EVM `3.2249 %`、最差 SNDR `29.8298 dB`，输入最大峰值 `0.3220 < 0.35`。固定 RMS `0.13` 会违反 0.35 峰值上限，已作为配置门禁记录；本项不含两级插值、memory-DPD、DPA/BPF 或板级 serializer。
- 五电平完整两级 x2 前端 / 250 MHz：four-plane raw sanity 为 0 mismatch，理想 RF/DDC NMSE `1.0981e-4`；但 ideal PA/BPF smoke 为 EVM `5.4454 %` / SNDR `25.2794 dB`，说明当前瓶颈先于 DPA。nominal DPA/BPF 的 identity 为 `3.7758 % / 28.4598 dB`，4-tap memory-DPD 为 `3.8513 % / 28.2878 dB` 且 validation/held-out 均退化，部署拒绝。mild DPA/BPF 的三组隔离 seed 亦为 0/3 通过（最差 `4.1122 % / 27.7185 dB`）。
- 250-MHz 完整链路严格复验（12/10/12 symbols、fair-RMS `0.095`、mild profile、三组隔离 seed）：`101/137/211` 为 `3.2241 % / 29.8318 dB`，但 `307/349/401` 与 `503/547/601` 分别为 `4.5765 % / 26.7894 dB`、`4.5525 % / 26.8350 dB`；故仅 1/3 通过，不能签核 250 MHz。RMS=`0.095` 在九帧的最大 PAPR `3.6673` 下峰值约 `0.348 < 0.35`，该失败不是裁剪或 raw-word 位序问题。
- 250-MHz 完整链路严格 peak-normalized 复验（12/10/12 symbols、mild profile、三组隔离 seed）：三组 identity 的 EVM/SNDR 分别为 `2.8221 % / 30.9884 dB`、`3.0846 % / 30.2161 dB`、`3.1831 % / 29.9432 dB`，均通过且 raw mismatch 为 0。每帧无裁剪地缩放到峰值 `0.35`，所以它是可复现的自适应数字驱动策略，不是 fair-RMS 等平均功率签核。
- 同一 peak-normalized 250-MHz 三 seed 的 Q2.14 四 tap memory-DPD：seed `101` 从 `2.8221 % / 30.9884 dB` 退化至 `2.9352 % / 30.6472 dB`，seed `307` 从 `3.0846 % / 30.2161 dB` 退化至 `3.1281 % / 30.0945 dB`，仅 seed `503` 从 `3.1830 % / 29.9432 dB` 微幅至 `3.1796 % / 29.9525 dB`。前两组 validation 亦退化，故 `HeldOutDeploymentAccepted=0`，DPD RTL 系数继续 identity。
- 最新 MATLAB P0：`LPDSM`、`LPDSM2`、`EFDSM`、`EFDSM2`、`MASH11`、`MASH111`、`MASH22` 均为 65,536 samples / 0 mismatch / PASS。
- 250-MHz 插值探索：6-tap causal Lagrange 的 ideal-PA EVM 为 `5.0474 %`，优于 legacy 4-tap 的 `5.4454 %` 但仍失败；31-tap windowed-sinc 试验因插值群延迟与当前 OFDM crop/equalizer 契约不一致而为 `5.7814 %`，不进入 RTL。默认 MATLAB/RTL 仍为原 4-tap bit-true 核。
- 已清除未闭环的 CRFB temporal8/temporal64 和 TID-MASH11 实验 RTL、模型、TB 及 OOC 脚本；基础标量 DSM P0 回归不依赖它们。
- 清理后 MATLAB P0（7×65,536 samples）、项目 P0 XSim（7/7）和 IP smoke（5/5）均 PASS。
- 本轮全前端 routed OOC 与全部回归：thermo5 frame-gain / 两级 x2 / identity memory-DPD wrapper 为 WNS `+0.178 ns`、WHS `+0.027 ns`、0 critical warning / 0 error；前端 XSim 64 word / 2,048 samples / 四平面 0 mismatch，MATLAB P0 7/7、项目 P0 XSim 7/7 与 IP smoke 5/5 均 PASS。
- 四支路 serializer/PA 数字链路：完整前端到四个 raw-64 bit0-first serializer/loopback 的 XSim PASS，64 word、每路 4,096 serial bits；共享 user/serial clock 比为 218.75 MHz/14 Gb/s，公共 reset 与 all-or-none ready 均被验证。它不是 GT 或板级 BERT。
- 已完成模块和历史细节见 `docs/exec-plans/completed/20260917-152449-completed-history.md`。

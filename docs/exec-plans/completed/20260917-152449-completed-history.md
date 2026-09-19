# 已完成模块归档 - 2026-09-17 15:24:49

本文件从 active execution frontier 迁出已完成的里程碑与历史结论。

## 64-lane 数字发送基座

- 建立 64 × 218.75 MHz = 14 GS/s 的时间交织数据面；14 Gb/s 是 raw-GTH line rate。
- 实现一次 Fs/4 数字搬移，目标 IF 是 3.5 GHz；不使用外部 LO，亦不把 line rate 误称为 RF 载波。
- 建立 8-lane complex ingress、两级 x2 polyphase、16-lane vector DPD 接口、32-lane thermometric TID 和双 64-bit raw-word 接口。
- 建立 dual-SFP GTH payload target（X1Y12/X1Y13）、真实 GT Wizard、TX/RX user clock、reset 和 smoke pattern。

## 前端 bit-true 与时序

- 两级 x2 polyphase 逐样本与 MATLAB 一致；输入 lane 0 为最早样本，未以零填充制造额外 lane。
- 四 tap、1/3/5 order memory-DPD 接口已采用跨 word 共享历史；固定点格式 Q2.14。
- 完整前端 MATLAB-to-XSim：64 ingress words、2,048 最终复样本、两条 PA raw stream 均为 0 mismatch。
- 完整前端 ZU15EG OOC routed：WNS +0.255 ns，WHS +0.027 ns，TNS/THS 0，0 critical warning / 0 error。
- dual-SFP thermometric payload target post-route：WNS +0.324 ns，WHS +0.013 ns，TNS/THS 0，bitstream 已生成。

## 接收机和行为级 RF 验证基座

- 建立 raw word de-interleave、双支路合成、因果 BPF、Fs/4 DDC 与 OFDM 接收机统一测试口径。
- raw word 反交织与 scalar thermo3 参考在 1,056 个 7-GS/s 样本固定延迟后 0 mismatch。
- 理想 BPF/DDC 对齐检验：NMSE 1.8799e-6，phase 0，extra delay 0。
- 当前完整前端 + behavior switching-DPA 已在 17.08984375 MHz、OSR 409.6 的 256-QAM OFDM case 达到 identity EVM 2.3917%、SNDR 32.4257 dB。

## DPA/DPD 行为模型

- 接入参数化 `behavioral_switching_dpa_v1`：热记忆 AM-AM、极性不对称、三 tap FIR 记忆、解析 AM-PM 和 Q=100 二阶 BPF。
- 形成 profile CSV 导出以及 PA-side、BPF-side 行为 ACLR 报告路径。
- 建立 long 12/10/12 symbol Q2.14 four-tap memory-DPD 训练、validation 与完全隔离 held-out test。
- 已确认当前 candidate 在 held-out test 轻微退化，因此 `HeldOutDeploymentAccepted=0`；identity 系数仍为唯一允许部署的设置。

## 已完成的回归与筛选结论

- `run_matlab_p0_bittrue_check.cmd` 最新：7/7 PASS，每项 65,536 samples，0 mismatch。
- thermo3 TID 数字行为扫频在约 229.86 MHz 仍通过五 seed；它仅作为数字模型能力上界，不是完整 RF/板级带宽签核。
- 三电平 BP-EFDSM 在约 99.9756 MHz 出现行为级通过点；它没有可流水 temporal TID、RTL、GTH 或 PA 路径证据。
- 旧 LP、独立 lane、纯 scalar 或未验证 CRFB/SMASH 高阶递推实现均不再作为 218.75 MHz、14 GS/s 架构结论。

## 未完成项的归属

未完成的 DPA 实测标定、memory-DPD 部署门禁、100 MHz+ 全链路验收、SFP loopback/BERT 和板外双 PA 合成均保留在 active execution frontier。

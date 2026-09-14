# 执行前沿

## 当前目标

在 ZU15EG 上完成发射链的板级验证：每拍 16 个有序基带 I/Q 输入，经 vector DPD、x4 polyphase、64-lane TI64、Fs/4 数字搬移和 raw-GTH，产生 14 Gb/s 的一位串行流。Fs/4 对应的中心频率为 3.5 GHz；14 Gb/s 不是 14 GHz RF 载波。

## 已完成

- x4 链路 RTL 已接通：`16-lane I/Q -> vector DPD -> 16x4 polyphase -> 64-lane I/Q -> [I,Q,-I,-Q] -> TI64 -> raw-GT word`。lane 0 始终为最早样本，FIR 保存 7 个跨 word 的时域历史。
- 原单拍 x4 FIR 的 9.144 ns 关键路径已由五级 elastic 流水实现消除；定点算术、舍入、饱和、历史和 lane 顺序不变，仅增加延迟。
- 独立 x4 bit-true XSim、P0 XSim（7/7，每项 65,536 samples）和五项 IP smoke 均 PASS。
- ZU15EG 单实例 x4/GTH routed build 通过：0 error、0 critical warning、WNS `+0.387 ns`、WHS `+0.010 ns`、TNS/THS 为 0；资源为 20,835 LUT、21,203 FF、385 DSP、4 BRAM。仓库外已生成 bit/ltx/报告。
- 已完成一次提交快照与一次清理提交；当前 `main` 与 `origin/main` 同步。清理后复跑 P0、IP smoke 与 x4 前端 XSim 均 PASS。

## 当前边界

- TI64 是 64 路独立 LP1 状态的 time-interleaved DSM，不是精确 temporal BP-EFDSM2，也不是 MASH。
- vector DPD 已支持 bypass 和 memoryless polynomial；LUT DPD 与 memory-polynomial 尚无跨 lane 配置/历史交接及 bit-true oracle。
- 已证明 RTL 功能与已约束设计实现；尚未下载到板卡并完成 SFP0 物理回环、ILA word-order 捕获，因此不能声称已实测物理 14 Gb/s，更不能声称 14 GHz RF。
- 板内确定性 16-lane source 仅用于 bring-up；真实基带 ingress 的时钟、CDC 与流控尚未定义。主机输入、driver/BPF、RF EVM/ACLR/OOB 亦未完成。
- Rocky-8.10 的 VCS 编译器位于 `linux64/bin/vcs1`，但该 VCS 版本明确拒绝当前 WSL2 内核；QAM-OFDM UVM 在编译前失败，不存在 UVM/coverage 通过结论。
- 2026-09-14 板卡连接预检：Vivado Hardware Manager 与本地 `hw_server` 可正常启动，但 `127.0.0.1:3121` 未枚举到任何 JTAG target；bitstream 尚未下载，须先接通并上电 ZU15EG 的 USB-JTAG，或提供可访问的远程 hw_server。

## 下一步

1. 接通并上电 ZU15EG USB-JTAG（或提供远程 hw_server），重跑 Hardware Manager target 枚举；随后下载 `D:\TraeTemp\ti64_raw_gt14_sfp0_x4_fivestage_20260914\ti64_raw_gt14_sfp0_x4.bit`，完成 SFP0 回环和 ILA 对 `tx_ready`、`rx_ready`、`tx_word`、`rx_word` 的 word-order 捕获。
2. 定义真实 16-lane 基带 ingress 的时钟、CDC 与 ready/valid 流控，并替换板内确定性 source。
3. 为 LUT DPD 定义 vector read/bank-commit 契约；为 memory-polynomial DPD 设计 word-boundary history hand-off，并分别建立 bit-true oracle。
4. 修复或选择兼容的 Rocky VCS 安装后，执行并归档 long-run/QAM-OFDM UVM 的 queue-drain、error 与 coverage 证据。

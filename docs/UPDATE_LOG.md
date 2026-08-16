# 项目更新日志

## 2026-08-16 19:16 +08:00：System-UVM 代码覆盖率收口、寄存器角落场景与反馈 FIFO 溢出策略

- 固定 Performance SKU 的 Linux VCS 扩展回归已实际完成：`dsm_axi_protocol_test`、`dsm_control_stress_test`、`dsm_memory_dpd_commit_stress_test`、`dsm_axis_coverage_test`、`dsm_system_closure_test`、`dsm_negative_control_test` 与 `dsm_register_corner_test` 各运行 20 个 seed，共 `140/140 PASS`。每项同时满足 simulator return code `0`、`UVM_ERROR=0`、`UVM_FATAL=0`、`[TEST_DONE]` 和 `[BP_SCORE]`；带 TX 数据的用例还要求 `rf_transactions>0`，因此该结果不是仅靠 shell exit code 得出的假通过。
- 已用 `run_ip_extended_coverage_linux.sh` 精确合并该 140 个 PASS 数据库。当前原始全工程 URG coverage 为：line `62.91%`、condition `61.37%`、toggle `64.52%`、branch `46.25%`、assert `77.42%`、functional group `100%`。此统计包含 UVM、testbench 和当前主 SKU 已裁剪的 Poly/LUT 分支，不能直接作为 DUT 可达代码签核分数。`dsm_ip_axi_top` 的局部结果为：line `88.91%`、condition `71.60%`、toggle `55.11%`、branch `63.30%`。
- 依据 `dsm_ip_axi_top` 的 URG 未覆盖项，新增 `dsm_register_corner_test`：覆盖 core-disable 时的 TX backpressure/sticky error/W1C、condition metadata readback、observer snapshot/start/clear、memory-DPD commit ACK/FAILED W1C，以及 DPD coefficient/LUT 寄存器与 disabled Poly/LUT fallback。
- AXI-Lite UVM transaction 新增 `WSTRB` 字段；driver 不再强制所有写为 `4'hf`。新 corner testcase 验证低半字、高半字及零字节使能写，确保未使能字节保持原值。这同时覆盖 RTL 中此前未触发的字节使能分支。
- `dsm_register_corner_test` 的 seed 11 曾暴露 testbench 的固定等待竞态：随机 AXI 读写可使 enable 写事务晚于固定等待周期。已改为轮询寄存器掩码等待硬件状态；DUT RTL 未修改。修复后全部 140 次回归通过。
- 新增 `tb_dpd_observer_async_bridge_drop.sv` 与 Linux VCS runner，验证 depth-4 异步反馈 FIFO 的 `DROP_ON_FULL=1` 策略。实际结果为 `sent=96`、`read=12`、`drops=84`，源端 stall 为零且 `read + drops = sent`。该模块不在当前单时钟 IP-system UVM DUT 内，因此 CDC/full/drop 策略保留为 focused block-level VCS 证据。
- 覆盖率目标保持为：冻结主 SKU 的所有**可达** RTL 代码达到 `100%`，并为 compile-time feature gate 裁剪项、协议禁止项和工具生成项保留逐项审计 exclusion；不通过违反 AXI/commit/reset 契约伪造覆盖率。

## 2026-08-16：冻结 Performance SKU 的 ZU15EG routed OOC 收口

- 交付范围继续冻结为单 lane `100 MHz`：`Memory-Poly5, 4-tap -> x32 CIC/compensation-FIR -> Fs/4 BP EFDSM2`。本轮不推进 `312.5 MHz` 扫频或多 lane/interleaving；此前 `312.5 MHz` 命令在 PowerShell 参数转换阶段失败，未进入 Vivado，不得解释为 RTL 时序失败。
- 实际运行 `syn/run_performance_sku_routed.ps1 -Part xczu15eg-ffvb1156-2-i -TargetMHz 100`，Vivado 2024.1 完成综合、实现、物理优化和布线。`dsm_ip_axi_top` 在 `aclk=100 MHz` 下 setup `WNS=+2.632 ns`、`TNS=0`、0 failing endpoints，估算 `Fmax=135.72 MHz`。
- routed 资源为 `12,964` CLB LUT、`15,316` CLB registers、`266` DSP48、`0` BRAM/URAM；Vivado 功耗估计为总片上 `1.099 W`、动态 `0.389 W`、静态 `0.711 W`，置信度为 Medium，未使用 SAIF/VCD 活动文件，不能作为板级实测功耗。
- routed DRC 无阻断错误，但保留 `DPOP-3`/`DPOP-4` 共 220 项 DSP `PREG/MREG` 流水建议，以及少量输入流水/无负载告警。它们不否定本次 100 MHz 时序收口，但说明 memory-DPD 乘加路径仍有后续 PPA 优化空间。
- Linux VCS 重新运行 `bash uvm_verif/sim/run_ip_coverage_linux.sh`：20/20 testcase 满足 return code 0、`UVM_ERROR=0`、`UVM_FATAL=0`、`[TEST_DONE]` 和 scoreboard 门槛。带数据用例还确认 `BP_SCORE rf=<N>` 且 `N>0`；control-only safety 用例被显式标注，不以 RF 数量作为通过条件。
- 尝试以 `/opt/Synopsys/syn/V-2023.12-SP1/bin/dc_shell` 运行当前 RTL lint。工具已找到，但日志返回 `DCSH-1: Design Compiler is not enabled`，因此本轮没有新的 DC lint 通过结论；需恢复对应 DC 许可证后重跑。
- 本地公开工作区仍缺少可重建板级 bitstream 所需的 ZU15EG `.xpr`、完整 BD 和板级 XDC。当前 routed OOC 不是 bitstream、I/O hold 或板级时序签核。

## 2026-08-15：冻结当前交付范围并修正主 SKU 集成配置

- 暂停单 lane 高频扫频和多 lane/interleaving 研究；`312.5 MHz` 的命令失败于 PowerShell 参数转换，未进入 Vivado，因此不是 RTL 时序失败，也不构成任何性能结论。
- 当前交付唯一主 SKU 固定为 `Memory-Poly5, 4-tap -> x32 CIC/compensation-FIR interpolation -> Fs/4 BP EFDSM2`，`ALGORITHM=3`、`DUC_MODE=3`、`INTERP_MODE=4`、`100 MHz`。
- 修正 `fpga/zu15eg/scripts/implement_full_tx.tcl` 的旧集成参数，使后续本地板级工程不会误综合 Cartesian EFDSM 历史基线。
- 新增完整 routed-OOC 入口 `syn/run_performance_sku_routed.ps1/.tcl`。该流程精确使用主 SKU 参数、运行 placement/routing、报告资源/时序/功耗/DRC，但不生成 board bitstream。
- 仍待完成：Linux VCS 防假 PASS 门槛复跑、主 SKU routed-OOC、DC lint 复跑；完整 board bitstream 依赖未纳入仓库的本地 ZU15EG Vivado 工程和板级约束。

## 2026-08-15：单 Lane 提速探索入口

- 更新 `syn/run_ooc_bp_ef2_axi.tcl`：支持通过 Tcl 参数指定目标时钟频率，默认仍为
  `100 MHz`；综合 summary 新增 `Target_MHz` 字段。
- 新增 `syn/run_ooc_bp_ef2_lane_sweep.ps1`：在 ZU15EG 上依次执行
  `150/175/200/225/250 MHz` 的完整 BP-EFDSM2 AXI OOC 综合，并汇总每个频点的资源、WNS
  与估算 Fmax。
- 当前 `200 MHz` 是单 lane 的待验证目标。未改变 DSM 反馈环、定点格式、流水延迟或
  MATLAB/RTL bit-true 语义；未运行 Vivado 扫频，因此尚无新的频率结论。
- 首次真实 ZU15EG OOC 在 `100 MHz` 通过：`WNS=+3.478 ns`、估算 `Fmax=153.33 MHz`。
  该数字来自完整 Performance SKU（Memory-Poly5 4-tap、x32 CIC/FIR、Fs/4 mixer、BP
  EFDSM2），因此当前配置不能支持 `312.5 MHz` 的 3.2 ns 周期。312.5 MHz 保留为独立
  RTL 优化/架构实验，不计入当前主 SKU 的交付承诺。
- 修复 `run_ooc_bp_ef2_lane_sweep.ps1` 的 PowerShell 参数解析：现在既接受
  `-TargetMHz 275,300,312.5,325`，也接受空格分隔的频率数组。同步修正 OOC Tcl 的
  mixed-direction wildcard false-path 写法，移除无效 startpoint/endpoint 警告，同时仍只
  评估内部 register-to-register 时序。
- 在 `docs/ALL_DIGITAL_TX_SURVEY.md` 新增第 19 节，冻结
  5 GHz Fs/4 的远期架构计算：`Fs=20 GS/s`，主选 `64 lanes x 312.5 MHz`。该章节同时
  明确 32 lanes x 312.5 MHz 只能达到 2.5 GHz Fs/4 中心频率，除非提高到 625 MHz 或由
  输出级实现每 lane 每周期两个时间序 bit。

## 2026-08-15：Linux System-UVM 回归复跑与单 Lane 时序证据边界

- 在 Linux VCS `V-2023.12-SP1`、Python `3.12` 与 Verdi `V-2023.12-SP2` 环境直接执行
  `bash uvm_verif/sim/run_ip_coverage_linux.sh`。20/20 testcase 均满足 simulator return code
  为零、`UVM_ERROR=0`、`UVM_FATAL=0`、`[TEST_DONE]` 与 `[BP_SCORE]`，因此本轮没有由早退、
  未执行 scoreboard 或仅 shell 成功造成的假 PASS。
- 强化 `run_regression.py` 的 scoreboard 门控：除 `[BP_SCORE]` 标记外，必须解析到
  `rf=<N>` 且 `N>0`；CSV 增加 `rf_transactions` 字段。零 transaction 的伪完成用例将被
  标为 `FAIL`。唯一的 `dsm_memory_dpd_safety_test` 是不发送 TX 的控制面负向用例，已显式
  标为 control-only，仍要求 scoreboard、`TEST_DONE` 与零 UVM error/fatal。
- 该结论仅说明当前固定 Performance SKU 的功能回归通过，不说明 ZU15EG 的高频时序通过。
- 复核历史 `syn/reports/bp_ef2_axi_ooc_*` 目录后，未发现 `summary.csv` 或时序报告；目录仅有
  `hs_err_pid*.log/.dmp`，对应 Vivado/Java launcher 异常。它们不得作为 `100 MHz` 或
  `312.5 MHz` 的 OOC 证据。新的带频率标签扫频结果生成前，单 lane 最大频率仍为未验证状态。

## 2026-08-15：负向控制覆盖与扩展随机回归

- 新增 `dsm_negative_control_test`，在固定 Performance SKU 下验证禁用 Poly/LUT 模式的
  安全 bypass 回退，以及 `ERROR` 寄存器的写一清除语义。
- 日常 Linux VCS coverage 脚本纳入该 testcase，基线回归由 19 项扩展为 20 项。
- 新增 20 seed、120 次运行的可选夜间 system-UVM 压力脚本；它复用同一 UVM env、agent、
  sequence、scoreboard 与 Python reference，不复制 block 或 subsystem testbench。
- 尚未执行本轮新增 testcase 与扩展回归；提交前必须至少运行新增 testcase，夜间回归按
  计算资源执行并记录结果。

## 2026-08-15：System UVM 回归防假通过门控

- 强化 `uvm_verif/sim/run_regression.py`：单条 testcase 除 simulator exit code 与
  `UVM_ERROR/UVM_FATAL` 外，还必须在 log 中出现 `[TEST_DONE]` 和 `[BP_SCORE]`。
- 缺少 UVM summary、正常结束标记或 scoreboard 统计均会在 CSV 中标为 `FAIL`，避免
  初始化失败、过早停止、未加载向量或 scoreboard 未执行时被 shell exit code 误判为 PASS。
- 本次只修改回归判定逻辑，尚未在 Linux bridge 上重跑；待 bridge host 正常领取新
  `command.sh` 后，以 20-run quick regression 的新 CSV 为准。

## 2026-08-15 02:38 +08:00：IP-system UVM 覆盖收口
- 新增 `dsm_system_closure_test` 及其虚拟序列，将已有 control、memory-DPD 和 AXI-Stream
  场景组成单一系统用例：active-stream soft reset、有效/非法 bank commit、memory-DPD mode、
  512 个随机 gap 的 TX 数据流、`tlast/tuser`、observer clean window、monitor/counter
  readback、sticky error 以及 W1C clear 均在同一运行中检查。
- 扩展 `dsm_system_closure_cg`：覆盖 DPD mode、commit outcome、reset、AXI-Lite response
  stall 和 observer idle/active/clean-complete 状态，并添加有依据的主 SKU exclusion。排除项
  是编译裁剪或控制协议禁止的组合，不是用忽略项掩盖未验证功能。
- 扩展 control 虚拟序列：对 observer idle、active、clean-complete 分别执行精确的无/短/长
  AXI 读响应延迟检查；保留 focused observer block 对 dirty/error 场景的验证责任。
- 实际执行 `bash uvm_verif/sim/run_ip_coverage_linux.sh`。Linux VCS V-2023.12-SP1 共 19/19
  通过，所有运行均为 `UVM_ERROR=0`、`UVM_FATAL=0`。合并 URG 结果为总分 66.58%、line
  59.74%、condition 57.56%、toggle 62.79%、branch 41.99%、assert 77.42%、group 100.00%；
  system closure covergroup 为 100.00%。
- 修改文件：`uvm_verif/env/dsm_uvm_scoreboard.svh`、
  `uvm_verif/env/dsm_control_virtual_sequences.svh`、
  `uvm_verif/env/dsm_system_closure_virtual_sequences.svh`、
  `uvm_verif/tests/dsm_system_closure_test.svh`、`uvm_verif/env/dsm_uvm_pkg.sv`、
  `uvm_verif/sim/run_ip_coverage_linux.sh`、`uvm_verif/sim/README.md`、`docs/VPLAN.md`。
- 仍未完成：全 RTL code coverage closure、lint、CDC/RDC、门级/SDF、所有其他 compile-time
  SKU 的完整回归、routed/bitstream/板级验证，以及真实 PA/ADC/RF 闭环。

## 2026-08-15 00:19 +08:00：VC Formal FPV 闭环与 memory-DPD commit/reset 缺陷修复
- 新增并实际运行固定 Performance SKU 的 VC Formal FPV 流程：真实 DUT 为
  `dsm_ip_axi_top`，配置为 BP EFDSM2、Fs/4 IF、插值 bypass、Poly5 与
  Memory-Poly5 4-tap；LUT DPD 关闭。形式模型无 black box。
- VC Formal `V-2023.12-SP2` 最终报告为 14/14 assertion proven、18/18 vacuity
  non-vacuous、7/7 cover covered。setup 门禁对 clock、glitch、组合/振荡环和
  multi-driver 的检查均为零违规；runner 会在报告缺失、setup 非零或性质存在
  falsified/inconclusive/undetermined/unprocessed 时返回失败。
- `core_rst_n = aresetn & ~soft_reset` 中的 `soft_reset` 是运行时功能，不是只允许初始化
  期间出现的复位。VC Formal 通用 reset-setup 规则因此按类别显式排除，但没有把
  `soft_reset` 约束为常零；soft reset 关闭 TX、清空 datapath、取消 commit 及其可达性仍由
  专用 assertion/cover 证明。该例外不代表 CDC/RDC 已签核。
- 形式验证发现并修复两个真实 RTL 缺陷：旧事务留下的 sticky
  `dpd_mp_commit_rejected` 可能在新 commit pulse 尚未被消费时误拒绝新事务；soft reset 与
  commit completion 同拍时可能错误增加 `mp_commit_epoch` 并留下旧的 wrapper transaction
  状态。现在 rejection 只在新 pulse 后判定，soft reset 会取消 pending/inflight/ack/failed，
  且硬件完成事件优先于同拍 W1C 清除。
- 修正 UVM 顶层 SVA 实例漏接 `mp_commit_pulse` 和 `mp_commit_success_event` 的问题，消除
  VCS `Too few instance port connections`，避免 assertion 使用悬空输入。
- 修复 FPV 报告脚本在全部性质通过时仍尝试导出反例而产生误导性 `[Error]` 的问题。
- 回归执行：Linux VCS `dsm_memory_dpd_bittrue_test` 通过，24 个 I/Q 输入对应 768 个 RF
  transaction 逐项匹配；`dsm_memory_dpd_safety_test` 命中非法 commit/reject 路径；两项均为
  `UVM_ERROR=0`、`UVM_FATAL=0`。剩余边界为 CDC/RDC、形式算术等价、其他编译 SKU、门级/SDF、
  物理实现和真实 RF/PA 反馈。

## 2026-08-14 21:55 +08:00：VC Formal 安装与许可证启动确认
- 确认 Rocky WSL 已安装 VC Formal `V-2023.12-SP2_Full64`，可执行文件为
  `/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf`；同时存在 Formality，但后者用于等价检查，
  不能替代 SVA property proof。
- 定位此前 `NO_SUPPORTED_FORMAL_ENGINE` 为环境探测误报：共享 bridge 进程已经退出，
  `status.txt/result.log` 是旧结果；非交互 shell 又未加载 `~/.bashrc` 中的
  `VC_FORMAL_HOME` 和 PATH。探测脚本现会强制重新进入一次交互式 shell，并新增不依赖
  bridge 常驻进程的 `run_formal_tool_check_wsl.ps1` 直接入口。
- `vcf -id` 已正常报告安装信息；`vcf -batch -no_ui -fmode FPV` 启动 smoke 打印
  `VCF_BATCH_STARTUP_PASS` 并以退出码 0 结束，确认 FPV 二进制和许可证可用。
- 当前结论仅是工具与许可证就绪。尚未建立冻结参数的 formal harness、assumption、property
  分组和 proof report，因此不能将已有 VCS 并发断言宣称为 formal proof 已完成。

## 2026-08-13 22:53 +08:00：Formal 工具可用性检查（已被 2026-08-14 复核纠正）
- 新增 `uvm_verif/formal/check_formal_tools_linux.sh`、
  `uvm_verif/formal/run_formal_tool_check_bridge.ps1` 以及
  `make -C uvm_verif/sim formal-check-tools`，用于在既有 Linux EDA bridge 中可重复探测
  property-formal / equivalence 工具。
- 实际通过 Linux bridge 检查：`vcs` 可用；`vcf`、`vc_formal`、`jaspergold`、`qverify`、
  `sby`、`yosys`、`formality` 均未找到，脚本按预期以 `last_exit=2` 结束并输出
  `FORMAL_TOOL_CHECK_RESULT=NO_SUPPORTED_FORMAL_ENGINE`。
- 该次结论由未加载完整 EDA 环境和陈旧 bridge 日志导致，已由 2026-08-14 的直接交互式
  WSL 检查纠正。当前断言证据仍严格限定为 Linux VCS 并发 SVA 仿真，不能标记为穷尽
  formal proof。
  后续使用现有 VC Formal 添加冻结参数的 harness、assumption、proof runset 和独立 proof
  状态报告。
- 本次未改动 RTL；检查执行：Linux bridge formal-tool probe。剩余限制：尚无法运行
  property proof、formal CDC/RDC 或等价检查。该历史限制已在 2026-08-14 更新为“工具可用但
  尚未完成证明”。

## 2026-08-13 22:35 +08:00：IP-system 随机压力、系统断言与异步反馈顺序检查
- 扩展 `dsm_memory_dpd_commit_stress_test`：保持 24 组 Q1.15 I/Q 和 768 组 RF golden
  transaction 不变，仅随机化 AXI-Lite 写地址/写数据/写响应和读响应的到达延迟。该测试在
  seed `1`、`7`、`31` 下验证 inactive bank 写入、受保护 commit、bank 切换与全链路
  Python bit-exact RF 比较可在不同控制面时序下保持正确。
- 扩展 IP-system 回归至 15 项：4 项确定性 bit-true/safety、AXI protocol 3 seed、control
  stress 3 seed、memory-DPD commit stress 3 seed、AXI-Stream sideband coverage 2 seed。
  Linux VCS V-2023.12-SP1 回归全部通过，所有运行均为 `UVM_ERROR=0`、`UVM_FATAL=0`。
- 扩展并在 `dsm_uvm_tb` 中实例化系统级 SVA：TX/OBS AXI-Stream 和 AXI-Lite stall 时
  payload 稳定；soft reset 关闭 TX 并在下一拍清空 skid/datapath 可见状态；commit 串行化、
  bank 变化对应 acknowledge/epoch、失败 commit 保持 active bank；observer ready 仅在
  enable 且窗口 active 时出现。它们均作为 VCS 仿真中的并发断言执行，尚未作为 formal
  proof 签署。
- 新增异步 FIFO 数据顺序检查器，并接入 `feedback` focused testbench。Linux VCS 统一
  subsystem 回归再次通过：`tx_frontend`、`if_dsm`、`feedback`、`control` 均为 `PASS`，
  日志包含 `SUBSYSTEM_VCS_SIGNOFF_PASS`；feedback 使用异步时钟、129 个输入 beat，逐项
  检查 `{data,last,user}` 的 FIFO 顺序。
- 未完成项保持不变：完整 code coverage closure、formal proof/CDC/RDC、lint clean、
  gate/SDF、当前主 SKU 的重新 routed/bitstream 以及真实 PA/ADC/RF feedback。

## 2026-08-13：Subsystem Linux VCS 统一回归通过
- 通过既有 `F:\sramc_uvm_bridge` 在 Rocky Linux 上执行统一回归。bridge 负责从 Windows
  工作区接收命令、在 Linux 的 VCS 环境运行脚本、将日志和退出状态写回共享目录；它不参与 RTL
  功能，也不替代 VCS/UVM。
- 为 bridge 的非交互 shell 增加 Linux 本机 EDA 环境重新执行机制，避免在仓库中记录许可证
  地址、服务器或其他本机凭据。此前的 `VCS_HOME` 与 license server 短暂不可达问题均已恢复。
- 本轮结果：`last_exit=0`，日志包含 `SUBSYSTEM_VCS_SIGNOFF_PASS`；生成的
  `verif/out_vcs_subsystem/subsystem_summary.csv` 显示 `tx_frontend`、`if_dsm`、`feedback`、
  `control` 均为 `PASS`。
- TX frontend、IF/DSM、feedback 分别通过 focused VCS SystemVerilog testbench 与 Python
  reference；control 运行 8 个 Linux VCS UVM 用例，所有用例均为 `UVM_ERROR=0`、
  `UVM_FATAL=0`。至此，当前 RTL revision 的四个 subsystem Linux VCS signoff 已完成。

## 2026-08-13：Subsystem 正式验证路径迁移至 Linux VCS
- 明确 Windows PowerShell 不能直接执行 `call settings64.bat`：`call` 是 `cmd.exe` 的批处理
  内建命令；即使经 `cmd` 执行，其环境变量也不会回写到当前 PowerShell。此前 `xvlog.bat`
  以 `0xC0000142` 启动失败属于 Vivado launcher/DLL 初始化问题，未进入 RTL 编译。
- 新增 `run_subsystem_vcs_linux.sh` 和 `run_subsystem_vcs_bridge.ps1`。正式 subsystem
  回归固定由 Linux VCS 执行，Windows 仅向既有 bridge 提交任务和读取结果。
- TX frontend、IF/DSM、feedback 使用 focused SV testbench 与 Python 逐样本/状态 oracle；
  control 使用现有 UVM AXI 回归。该划分避免将确定性 DSP 数值测试不必要地重写成 UVM，仍让
  多接口协议、随机时序与覆盖率场景保持在 UVM 中。
- XSim 的四项通过记录保留为 baseline evidence；Linux VCS 统一 subsystem suite 尚待 bridge
  执行，完成前不将本 RTL revision 标记为 subsystem signoff completed。

## 2026-08-13 03:34 +08:00：IP-system UVM 功能覆盖收口
- 新增 `dsm_axis_coverage_test` 与虚拟序列，定向覆盖 TX/OBS AXI-Stream 的
  `TLAST`、`TUSER[0]`、连续/短间隔/长间隔 transaction 组合；TX 和 OBS 分别使用符合各自
  微架构的 stall covergroup，避免将 observer 窗口状态机等待错误解释为通用 backpressure。
- 扩展 `dsm_axi_protocol_sva.sv`：断言 soft reset 与 memory-polynomial commit 期间关闭
  TX 接收、active coefficient bank 仅在 commit 期间切换、observer ready 仅在 enable 且
  active 时出现；同时增加对应 cover property。
- RF monitor 的交叉覆盖排除物理不可能的编码组合 `{rf_bit=1, rf_signed<0}` 与
  `{rf_bit=0, rf_signed>0}`，编码关系仍由 SVA 保持为错误检测条件。
- 新增 Linux/Windows bridge 回归入口，统一执行 12 项 VCS 用例并生成
  `ip_coverage_summary.csv`；其中包含 4 项确定性 bit-true/safety 测试、AXI protocol 与
  control stress 各 3 个 seed、AXI-Stream coverage 2 个 seed。
- Linux VCS V-2023.12-SP1 最终回归 12/12 通过，所有运行均为
  `UVM_ERROR=0`、`UVM_FATAL=0`。初次运行中 AXI sideband test 因错误要求单极性激励也必须
  产生 RF 正负翻转而失败；该 testbench 质量门限已改为仅检查其职责范围，最终复跑通过，RTL
  未修改。
- URG 合并结果：line 58.60%、condition 56.50%、toggle 62.02%、branch 40.33%、
  assert 77.78%、group 100.00%、total 65.87%。本次签署已定义功能点的 functional
  coverage closure；全代码覆盖、formal CDC/RDC、lint、门级/SDF、routed/bitstream 和真实
  RF/PA 反馈仍未签署。

## 2026-08-13：Control UVM 多 seed 压力回归与覆盖率报告
- 新增 `dsm_control_stress_test`，在真实 `dsm_ip_axi_top` 上联合驱动 AXI-Lite、TX
  AXI-Stream 和 OBS AXI-Stream。场景覆盖独立 AW/W 到达、B/R response stall、TX 长
  backpressure、active-stream soft reset、`tuser`/`tlast` 边界、observer 启动反压、
  counter clear 和 observer window 状态。
- AXI-Lite 与 AXI-Stream monitor 记录实际 handshake 延迟；scoreboard 的 covergroup 以
  实际通道偏斜、response stall、valid gap、ready stall 和 sideband 组合采样，而非仅依据
  driver 请求延迟推断覆盖率。
- 在 Linux VCS V-2023.12-SP1 上使用 seed `1`、`7`、`31` 运行 `dsm_control_stress_test`。
  三组均通过，均为 `UVM_ERROR=0`、`UVM_FATAL=0`；URG 已在
  `uvm_verif/sim/out/vcs/coverage/` 生成合并报告。
- 修正 observer window 完成状态的测试期望：读回 `0x0000001c` 表示 clean、last-seen 和
  done 置位；此前的 `0x00000028` 将错误位映射解释为完成状态，导致三组 seed 均出现一个
  testbench 误报。该修正不改变 RTL 行为。
- `dsm_ip_axi_top` 同时修复 active-stream soft reset 期间的 false sticky error：合法上游
  可保持 `TVALID`，只有软件明确禁用 IP 时才报告 stream-while-disabled。
- 当时该控制子系统回归的 URG 总覆盖率约为 59.22%；后续 IP-system 汇总结果及其边界见本日
  “IP-system UVM 功能覆盖收口”记录。

## 2026-08-13：控制子系统 active-stream soft-reset 验证
- 新增 `verif/subsystem/control/tb/tb_dsm_ip_axi_active_reset.sv`，在 AXI-Stream
  数据流运行期间经 AXI-Lite 请求 `CTRL.soft_reset`。
- 该用例验证复位窗口内源端 `TREADY` 去使能；复位释放后 16 个输入 transaction 全部恢复、
  软件复位计数增加一次、sticky error 保持为零并再次观察到 RF 输出。
- 修复 `dsm_ip_axi_top`：软件复位期间上游合法保持 `TVALID` 不再被错误记录为
  “stream while disabled”。只有软件明确写 `CTRL.enable=0` 时才产生该 sticky error。
- `run_xsim_ip_smoke.ps1` 已接入新用例，因此 `run_xsim_control_subsystem.ps1` 和
  `run_subsystem_signoff.ps1` 会自动执行该控制边界检查。

## 2026-08-12：子系统测试资产归位与四子系统入口统一
- 将已有 TX frontend、IF/DSM、feedback 的 testbench 分别迁入
  `verif/subsystem/<name>/tb/`；将 AXI 控制面 smoke 迁入
  `verif/subsystem/control/tb/tb_dsm_ip_axi_control.sv`，将 AXI-wrapped BP
  route smoke 迁入 `verif/subsystem/if_dsm/tb/`。测试代码、DUT 边界和 README
  现在位于同一子系统目录，生成输出仍保留在忽略的 `verif/out_xsim_*`。
- 新增 `run_xsim_control_subsystem.ps1`。由于 coefficient bank commit、sticky
  error、soft reset、AXI-Lite response backpressure 必须在
  `dsm_ip_axi_top` 的完整上下文中验证，该入口复用 IP smoke runner，而不复制
  一套易失配的顶层编译文件表。
- `run_subsystem_signoff.ps1` 扩展为四个子系统：TX frontend、IF/DSM、feedback
  和 control；同时修复 IF/DSM runner 的 `-Python` 参数声明，使总入口可切换
  Linux/Windows 上可用的 Python 可执行文件。
- 子系统层继续使用 focused SystemVerilog testbench；完整 UVM 仅在
  `uvm_verif/` 覆盖跨 AXI-Lite、TX/OBS AXI-Stream 和 RF 接口的随机协议、
  安全切换、scoreboard、assertion 与 coverage，避免在每个子系统复制 UVM 环境。

## 2026-08-12：Control 子系统 VCS 证据补齐与验证收口
- 在 Linux VCS V-2023.12-SP1 上以当前 RTL 重新编译并运行
  `dsm_memory_dpd_bittrue_test` 和 `dsm_memory_dpd_safety_test`，两个 testcase 均为
  `UVM_ERROR=0`、`UVM_FATAL=0`，并生成对应 `simv.vdb` 覆盖数据库。
- active memory-DPD testcase 完成 inactive bank 的 12 个 Q2.14 complex C1/C3/C5、4-tap
  系数写入，等待 `MP_COMMIT` acknowledge，检查 effective memory mode，并对 24 个输入产生的
  768 个 RF transaction 完成 Python golden 逐项比较和队列 drain。
- safety testcase 写入超限系数，确认 commit 被拒绝、active bank 保持不变、`ERROR.bit3` 置位，
  并按预期不产生 RF transaction。
- 至此，固定 RTL revision 的 block signoff、IF/DSM、TX frontend、feedback 及 control
  子系统证据齐全，可以作为项目级 RTL/block/subsystem 验证收口。未完成项仍包括多 seed
  coverage closure、formal CDC/RDC、完整 lint、门级/SDF、物理 PPA/RF feedback 签核。

## 2026-08-12：Feedback 子系统与一键子系统回归
- 新增 `dpd_observer_async_bridge -> dpd_observer` 联合 testbench；使用异步反馈时钟、
  小深度 FIFO、严格反压、invalid 标记和窗口结束状态，验证跨模块的顺序、计数和 monitor
  累加契约。
- 实际执行 `verif/scripts/run_xsim_feedback_subsystem.ps1`，结果为
  `FEEDBACK_SUBSYSTEM_PASS samples=129 pairs=117 invalid=12 stalls=191`。无 FIFO 丢样、
  `error_acc=0`、无 overflow，且观测到末拍。
- 新增 `verif/scripts/run_subsystem_signoff.ps1`，统一调用 IF/DSM、TX frontend 和 feedback
  的 XSim 回归。Control 子系统仍由 `uvm_verif/` 的 Linux/VCS AXI-Lite UVM testcase 覆盖，
  不在 Windows XSim 中复制另一套协议环境。

## 2026-08-12：TX frontend 子系统 bit-true 回归
- 新增 `DPD bypass -> x4 halfband interpolation` 的独立子系统 testbench 与 Python 向量生成器；
  使用 DPD bypass 隔离验证十拍 transport latency、ready/valid 传播与 x4 样本扩展，不重复
  DPD Poly/LUT/Memory 的 block 级算术签核。
- 实际执行 `verif/scripts/run_xsim_tx_frontend_bittrue.ps1 -Inputs 97`，XSim 通过：97 组 Q1.15
  I/Q 输入产生 388 组输出，逐样本零失配，并覆盖 140 个输出 backpressure 周期。
- 更新 `verif/subsystem/` 状态表、TX frontend DUT 边界和 `verif/RUN_REGRESSION.md` 的可复跑入口。

## 2026-08-12：Block 随机边界回归与阶段签核
- 为 DPD、插值、Fs/4 mixer、BP EFDSM2、observer bridge 和 monitor 补充或接入可重复的
  随机/边界 testbench；覆盖 signed 极值、valid/enable bubble、AXI-Stream backpressure、
  非法输入、状态 clear、双时钟 bridge 的顺序保持及无丢样约束。
- 各 block 的 `vectors/` 新增 manifest，明确 Python/MATLAB 生成器、固定随机种子、输入
  边界和生成目录。生成的 CSV 仍只保存在 `matlab/out/`、Python 输出目录或可删除的
  `verif/out_xsim_*`，不在多个 block 目录复制 golden 数据。
- 实际执行 `verif/scripts/run_block_signoff.ps1 -BpSamples 4096`，exit code 为 0：
  DPD Poly3/5/7 与 Memory-Poly 的三组 MATLAB/RTL 比较均为 256/256、零失配；插值
  mode 0 至 4 及 x32 I0/I1/I2/I3 各 4096 样本零失配；Fs/4 mixer 的 8 组角点和 257
  组随机样本通过；BP EFDSM2 的 4096 组随机/极值/enable bubble 向量通过；observer
  bridge 的 24 组定向和 129 组随机样本、225 次停顿通过；monitor 的 behavioral 向量和
  129 样本/12 invalid beat/clear 路径通过。
- 更新 `verif/block/README.md`、`verif/block/BLOCK_SIGNOFF.md` 和
  `verif/RUN_REGRESSION.md`，使每个 block 的 DUT、参考模型、测试范围、证据和一键命令
  可直接追溯。
- 本次完成的是固定 RTL 版本和已列参数下的项目级 block signoff；尚未完成 formal CDC/RDC、
  完整 lint、门级/SDF、物理签核及真实 PA/ADC/RF feedback 验证。下一阶段进入
  `verif/subsystem/`，验证模块间位宽、延迟、流控、复位与状态边界。

## 2026-08-12：IF/DSM 子系统回归启动
- 实际执行 `verif/scripts/run_xsim_if_dsm_bittrue.ps1 -Samples 4096`，将 Fs/4 mixer、
  BP EFDSM2、共享 EF2 核与 `tx_bp_if_top` 作为一个 DUT 边界进行 Python-to-RTL
  transaction 比较，结果为 `IF_DSM_PYTHON_BITTRUE_PASS samples=4096`。
- 更新 `verif/subsystem/if_dsm/README.md`，明确该子系统的 RTL 组成、参考模型、比较对象和
  可复现命令；更新 `verif/subsystem/README.md` 的状态表。TX frontend、feedback 和 control
  仍只有 block 或 UVM 层证据，尚未建立独立 subsystem scoreboard，不能写为已通过。

## 2026-08-12：Block 验证资产入口规范化

- 为 `verif/block/` 定义统一目录契约：每个 block 具有 `tb/`、`vectors/` 和 `refmodel/` 入口；README 明确列出 DUT RTL、参考模型、生成器、运行脚本与证据状态。
- `vectors/` 不复制 `matlab/out/`、`uvm_verif/refmodel/python/out/` 或 `verif/out_xsim_*` 的生成 CSV。MATLAB/Python 模型和生成器保持唯一真源，XSim 运行目录保持可删除，避免同一 golden vector 出现多份并逐渐失配。
- 明确 block 验证边界：DPD、插值、Fs/4 mixer、BP EFDSM2、observer bridge 和 monitor 采用定向 SystemVerilog testbench；UVM 仅承担 IP-system 的 AXI-Lite、AXI-Stream、RF monitor、跨接口时序和随机流控验证。
- 修复 `run_xsim_dpd_bittrue.ps1` 的七阶向量准备：脚本此前漏复制 `dpd7_expected_iq.csv`，导致 testbench 在 0 ps 无法打开期望向量。补齐后已重新运行完整 DPD XSim 流程，七阶、memory-polynomial、安全、协议、异步 observer、feature-gate 和编译配置矩阵均通过。
- 当前可复查 block 证据：Fs/4 mixer directed test 已通过 8 个角点样本；BP EFDSM2 Python-to-RTL test 已通过 2048 个样本；插值 XSim 已报告 I0/I1/I2/I3 x32 通过。observer/monitor 的 testbench 和向量入口已具备，后续 RTL 变化后需要重新运行。

## 2026-08-11：验证目录分层整理

- 将 DPD、插值、observer 相关的定向 testbench 迁移到各自的 `verif/block/<block>/tb/`，使 block、subsystem 与 IP-top 测试边界可见。
- 新增独立 `Fs/4 mixer` directed test，覆盖 `I/Q/-I/-Q` 选择、`valid` 门控、复位和最小负数取反角点。
- 新增独立 `BP EFDSM2` Python-to-RTL block bit-true test；它直接比较 real-IF 输入后的 bit、signed code 与 quantizer state。
- 将 `dpd_observer` 的数值累计验证归入 `block/monitor`，将双时钟 bridge 验证归入 `block/observer`；两者不再混为同一层级。
- 更新 XSim 脚本和回归文档路径。当前 Windows Vivado launcher 曾发生启动崩溃，故本次目录重构只完成静态路径审计，新增 block test 需要在工具恢复后运行。
- `python 3.12` 向量生成和 PowerShell 脚本语法检查已通过；`xvlog -version` 返回 `-1073741790` 且不生成日志，属于本机 Vivado launcher 问题，不可解释为 RTL 或 testbench 失败。
- 修复 `run_xsim_interp_frontend.ps1`、`run_xsim_dpd_bittrue.ps1` 和 `run_xsim_ip_smoke.ps1` 的工作目录恢复行为，脚本结束或报错后不再把调用者留在 `verif/out_xsim_*` 目录。

本文件按时间正序记录影响接口、验证证据、实现状态或交付边界的里程碑。工具日志、波形、覆盖率数据库和其他生成物不纳入版本控制。

## 2026-07-02：七种低通 DSM 基线

- 整理 LPDSM、LPDSM2、EFDSM、EFDSM2、MASH11、MASH111、MASH22 的 MATLAB 与 RTL 实现。
- 建立 P0 向量、MATLAB/RTL bit-true 回归和 OOC 资源/时序证据。
- 后续主目标转为 ZU15EG；Zynq-7020 与 ZU48DR 仅作为历史对照。

## 2026-07-05：多比特 DSM 探索模型

- 为七种低通 DSM 增加可参数化多比特 MATLAB/RTL 研究模型。
- 将单比特和多比特 RTL 分目录，并保留逐样本比较入口。

## 2026-07-08：AXI/IP 工程化

- 完成 `dsm_ip_axi_top` 的 AXI4-Lite 控制面和 AXI4-Stream TX 数据面封装。
- 增加使能、软复位、状态计数器、粘滞错误和样本/帧/stall 统计。
- 增加 Vivado IP 打包及 PS/DMA 集成脚本。

## 2026-07-12：插值前端

- 实现 bypass、x4/x8/x16 halfband FIR 级联与 x32 CIC 加补偿 FIR。
- 建立 MATLAB 浮点/定点模型、频响分析和 RTL bit-true 向量。
- 加入流水、对称系数预加法、零系数裁剪和 backpressure 支持。

## 2026-07-15：Memory-Polynomial DPD

- 增加 memory-polynomial MATLAB 定点模型、RTL 和 bit-true 向量。
- 支持编译期 tap 深度配置与 Q2.14 复系数。
- 建立无 DPD、无记忆 DPD 和 memory-polynomial DPD 的 behavioral 对比。

## 2026-07-17：AI 校准辅助与安全策略

- 增加系数种子预测、known/unknown/OOD 元数据、LOSO/blind profile 和安全策略。
- AI 仅提供低速系数初值或候选建议；最终系数仍需安全检查和有界搜索确认。

## 2026-07-22：PS 裸机校准框架

- 完成 AXI-Lite 系数写入、DMA 向量发送、计数器读取和候选重放框架。
- 增加 14 个候选的有界搜索与安全回退。
- 当前没有物理 PA feedback，因此该流程只证明数字控制和数据通路接口。

## 2026-07-25：DPD 编译期特性裁剪

- 在 ZU15EG 上完成 bypass、Poly3/5/7、LUT、Memory-Poly 1/2/4/6 tap 与全功能开发版的 OOC 比较。
- 证明编译期 feature gate 可以裁剪未选硬件。
- Memory-Poly5、4-tap OOC 历史结果为 2480 LUT、3058 FF、120 DSP，100 MHz WNS 为 +6.572 ns。

## 2026-07-26：历史全 TX 集成基线

- 完成旧 `DUC_MODE=0` Cartesian EFDSM、x32 插值、Memory-Poly5 4-tap 的 ZU15EG routed implementation。
- 历史结果为 100 MHz WNS +2.314 ns、16296 LUT、20763 FF、3 BRAM、266 DSP，并生成 bitstream/XSA。
- 该结果仅为历史集成基线，不代表当前 BP EFDSM2 主 SKU。

## 2026-07-28：高阶 DPD 定点回归

- 将 polynomial DPD 扩展到 3/5/7 阶。
- 修复 testbench 只检查样本数而未比较 golden 的问题。
- 建立 MATLAB expected vector、XSim 输出和逐样本 mismatch 检查，并扩展 memory-polynomial 1/2/4/6 tap 回归。

## 2026-07-29：DPD 安全机制与观测器

- 增加 Q2.14 系数范围检查、shadow/active bank、原子 commit、饱和故障和 bypass 回退。
- 增加 observer 的延迟、复增益、误差、功率、峰值、削顶、slew 与频谱代理统计。
- 增加 monitor/status 寄存器和 PS 读取流程。

## 2026-08-04：指标口径与 behavioral DPD 审计

- 明确 native complex-baseband 与 RF-recovered 两类指标口径，禁止混用。
- 对 linear、噪声、AM/PM、AM/AM 和 memory PA 条件分阶段评估；不将单一理想 profile 的最优结果宣传为通用结论。
- LPDSM2 native complex I/Q EVM 为 0.6891%；旧固定 Fs/4 RF 恢复约为 94% EVM，故旧合路路线不作为通信性能依据。

## 2026-08-05：BP EFDSM2 主 SKU 与 28 nm 预布局证据

- 主验证链路改为全精度 Fs/4 IF mixer 后的一位 BP EFDSM2，避免低通 DSM 后直接 Fs/4 合路的噪声折叠。
- 冻结主配置：`ALGORITHM=3`、`DUC_MODE=3`、`INTERP_MODE=4`、Memory-Poly5、4-tap。
- Python behavioral 初始审计：BP EFDSM2 EVM 3.5638%、SNDR 28.9617 dB；这是行为模型结果，不是实测 RF 结果。
- 在 TSMC28 RVT、TT/0.9 V/25 C、100 MHz 下完成 DC pre-layout：setup +5.42 ns、hold +0.03 ns、面积 125647.956、总功耗估计 8.2218 mW。

## 2026-08-07：主 SKU lint 审计

- 完成 DC 的 analyze、elaborate、link、check_design 和 check_timing。
- Error/Fatal 为 0，但仍存在 signedness、位宽、未连接、常量、短接和未加载警告。
- 当前结果是结构检查通过，不可称为 lint-clean 或物理签核。

## 2026-08-09：分层验证与 UVM 平台

- 明确三层验证：`verif/block/` 为模块级、`verif/subsystem/` 为子系统级、`uvm_verif/` 为完整 IP system UVM。
- UVM 采用三类 agent：AXI-Lite、AXI-Stream、RF；其中 AXI-Stream 实例化为 TX 与 OBS，因此环境中共有四个 agent 实例。
- AXI-Lite 支持独立 AW/W 时序和 response backpressure；TX/OBS 支持随机 valid gap；RF agent 为被动采集。
- XSim 基础 AXI、协议和 BP smoke 已通过，但不等价于完整 UVM signoff。

## 2026-08-10：Python bit-exact 参考模型与 Memory-DPD system testcase

- 增加不依赖 MATLAB 的 Python 整数参考模型，显式模拟补码、位宽、右移、饱和、回绕、状态和 transaction 顺序。
- 插值 mode 0/1/2/3/4 的 MATLAB/Python 与 Python/RTL XSim 已零失配；Memory-Poly C1/C3/C5、4-tap 的 MATLAB/Python 与 Python/RTL XSim 已零失配。
- 增加 `dsm_memory_dpd_bittrue_test`：写入 inactive bank、轮询 `MP_COMMIT`、检查 mode/bank、发送 AXI-Stream 向量并逐 transaction 比较 RF 输出。
- 增加 `dsm_memory_dpd_safety_test`：写入非法系数，检查 commit 拒绝、active bank 不变和 `ERROR.bit3`。
- Python reference 单元测试 8/8 通过；每个 system package 包含 24 个复 I/Q 输入和 768 个 RF transaction。

## 2026-08-11：Memory-DPD system UVM 闭环与状态快照

- Linux VCS 使用 Python 3.12 编译并执行 `dsm_memory_dpd_bittrue_test` 与 `dsm_memory_dpd_safety_test`。
- active Memory-DPD testcase 通过：768 个 RF transaction，`UVM_ERROR=0`、`UVM_FATAL=0`，`rf_bit`、`rf_signed` 与 Fs/4 phase 均与 Python reference 逐 transaction 一致。
- safety testcase 通过：非法系数包被拒绝，`UVM_ERROR=0`、`UVM_FATAL=0`，且未产生 RF 输出。
- 验证过程中发现并修复 BP phase debug 对齐缺陷：mixer 原先输出的是下一 Fs/4 slot，而 BP quantizer 又增加一拍，导致 `phase_acc_dbg` 相对对应 `rf_valid` 偏移两拍。现在 mixer 寄存产生 IF sample 的相位，BP top 再将该相位对齐到对应 RF transaction。该修复不改变 I/Q、DSM 或 `rf_bit` 数据计算。
- `verif/` 清理为空目录和 XSim/SpyGlass 生成物；保留 block、subsystem、历史 directed testbench、脚本、冻结向量与 C 等价测试。完整 UVM 保持在独立的 `uvm_verif/`。

### 当前交付状态

- 已有证据：七种低通 DSM 的定向 bit-true、插值与 Memory-Poly4-tap 的分层 bit-true、BP EFDSM2 主路径、Memory-DPD AXI control/data/safety system UVM、DPD OOC 和 28 nm pre-layout 结果。
- 不可宣称：完整 UVM coverage signoff、当前 BP SKU 的 ZU15EG routed/bitstream signoff、真实 DPA/PA/ADC 反馈闭环、物理 EVM/ACLR/效率或硅后 PPA。
- 下一阶段：补充 reset、长 backpressure、observer/monitor 数值和多 seed coverage；完成当前 BP SKU 的 routed implementation；有真实反馈硬件后再签核 DPD 的物理 RF 改善。

# BP EFDSM2 数字发射机 IP 验证计划

## 1. 目标与边界

本计划验证冻结主 SKU 的数字 RTL 行为、定点一致性、AXI 协议与安全控制行为。验证对象止于同步数字 `rf_bit/rf_signed/rf_valid` 输出；PA、匹配网络、天线、物理 RF 链路和实测 EVM/ACLR 不属于本计划的 RTL 签核范围。

验证责任按层级划分：MATLAB 定点模型定义算法和定点契约；Python 整数模型作为 Linux/VCS 回归 golden；SystemVerilog/UVM 验证 RTL；FPGA 实现和板级回放验证集成可实现性。软件校准策略、行为级 PA/DPA 模型和真实 RF 测量不得替代 RTL 结论。

## 2. 冻结主 SKU

| 项目 | 冻结配置 |
|---|---|
| 顶层 | `dsm_ip_axi_top` |
| FPGA 目标 | `xczu15eg-ffvb1156-2-i` |
| 主时钟 | `aclk = 100 MHz` |
| 输入格式 | 有符号 Q1.15 复数 I/Q，AXI4-Stream |
| DPD | 五阶、四 tap memory polynomial；memory 路径启用 |
| DPD 裁剪 | Poly/LUT 执行分支关闭 |
| 插值 | `INTERP_MODE=4`，x32；`INTERP_IMPL=0` |
| DUC | 实数 `Fs/4` mixer，100 MHz 时中心 IF 为 25 MHz |
| DSM | 一比特 BP EFDSM2 |
| 控制面 | AXI4-Lite、双 coefficient bank、安全边界 commit、sticky error |

其他 DSM、插值实现和 DPD 分支保留为 block 或 wrapper 级研究对象，不与冻结主 SKU 的 system-UVM 覆盖率混用。

## 3. 验证分层与 DUT

| 层级 | DUT/范围 | 主要输入与检查 | 当前证据定位 |
|---|---|---|---|
| 模型层 | DSM、DPD、插值、DUC 定点行为 | MATLAB fixed-point 与 Python integer 对齐；位宽、截断、饱和、状态更新、延迟 | `matlab/`、`uvm_verif/refmodel/python/` |
| Block 层 | DPD、插值、Fs/4 mixer、BP DSM、observer、monitor | 定向、随机、边界、reset、ready/valid 与 bit-true 向量 | `verif/block/` |
| Subsystem 层 | TX frontend、IF/DSM、feedback、control | 模块间位宽、延迟、流控、commit、observer 配对 | `verif/subsystem/` |
| System 层 | AXI-Lite、TX/OBS AXI-Stream、冻结数据链 | UVM agent、Python scoreboard、SVA、随机回归与功能覆盖率 | `uvm_verif/` |
| 集成层 | 时钟、实现、DMA/ILA 预留接口 | OOC/routed 证据、时序报告、板级回放脚本 | `syn/`、`fpga/`、`docs/evidence/` |

Block 层优先使用轻量 SV testbench 和确定性向量；System UVM 负责跨接口的事务、随机协议交互和覆盖率闭环。不能因为 block test 通过而省略 system 层的跨模块握手、reset 和寄存器安全场景。

## 4. 冻结主 SKU 的系统 UVM 矩阵

历史 300-run 回归由 15 类 test、每类 20 个 seed 构成。下表列出主覆盖意图；具体 class、sequence 和 filelist 以 `uvm_verif/` 为准。

| 分组 | 代表测试 | 核心检查点 |
|---|---|---|
| AXI 协议 | `dsm_axi_protocol_test`、`dsm_axi_lite_channel_backpressure_test` | AW/W/B、AR/R 独立握手，stall 期间 payload 稳定，响应顺序正确 |
| 普通控制 | `dsm_control_stress_test`、`dsm_register_corner_test` | 寄存器读写、W1C、状态读回、非法地址/字段处理 |
| DPD bank 安全 | `dsm_memory_dpd_commit_stress_test`、`dsm_memory_bank_roundtrip_coverage_test` | inactive bank 写入、原子 commit、epoch、reject/defer、active bank 保持 |
| AXI-Stream | `dsm_axis_coverage_test`、`dsm_memory_pipe_stall_coverage_test` | TX/OBS backpressure、长 stall、`tlast/tuser`、数据不丢失与顺序保持 |
| bit-true 数据链 | `dsm_system_closure_test`、`dsm_seed_observer_datapath_coverage_test` | Python 产生 I/Q、DPD、插值、mixer、BP EFDSM2 参考；RF transaction 逐项 drain |
| 安全负向 | `dsm_negative_control_test`、`dsm_commit_during_stream_test`、`dsm_commit_reset_interlock_test` | reset/stream/window 中的非法请求被拒绝或延后，sticky error、fallback 与恢复行为正确 |
| 监控与观测 | `dsm_csr_monitor_coverage_test`、`dsm_wstrb_semantics_coverage_test` | monitor 读回、窗口状态、counter clear、字节写语义、observer 语义 |

## 5. Golden、scoreboard 与通过准则

Python 整数模型以明确的补码、signed 位宽、算术右移、截断/饱和、状态更新顺序和 valid 延迟生成参考向量。System scoreboard 必须比较并耗尽预期队列；仅看到仿真进程退出码为零不足以构成 bit-true PASS。

每个回归 run 至少同时满足以下条件才标记为 PASS：

1. 仿真器退出码为零。
2. 日志中 `UVM_ERROR=0` 且 `UVM_FATAL=0`。
3. 测试完成标记出现。
4. 适用 scoreboard 的 expected queue 全部 drain，transaction 数量一致。
5. 回归汇总 CSV 中该 run 标记为 `PASS`。

对 RF bit-true 用例，额外要求输入 I/Q 事务、Python 生成的 RF 事务和 RTL monitor 实际事务三者数量一致。对 monitor/observer 用例，必须比较 counter、窗口完成、丢样/overflow 与配对顺序，而不是只检查运行完成。

## 6. 覆盖率、断言与 Formal

记录的 300/300 VCS 回归已达到声明的 system-UVM **functional coverage 100%**，覆盖正常数据流、backpressure、reset、配置、commit、W1C 和错误恢复的已定义 covergroup/bin。

这不等同于 raw DUT code coverage 100%。未覆盖的行、条件、分支和 toggle 必须区分：

- 冻结 SKU 通过 compile-time feature gate 裁剪而不可达的 Poly/LUT 分支；
- 协议禁止、只能拒绝的非法事务；
- 真实可达但尚未激励的分支，必须补定向 testcase；
- 数学不可达或防御性分支，必须有 source-linked waiver 或范围证明。

VC Formal/FPV 覆盖的是冻结 SKU 的选定 AXI-Lite 控制面安全属性，例如 commit 原子性、控制协议和安全边界。记录的 proof 不是完整 CDC/RDC、全算术等价、门级或全 SKU Formal 签核，不能扩大表述。

## 7. CDC、reset 与时序验证边界

`aclk` 是当前数据链、AXI-Lite、TX stream、DPD、插值、mixer、BP EFDSM2、monitor 的主时钟。仅当外部 observation receiver 使用不同 `feedback_clk` 时，`dpd_observer_async_bridge` 才形成 `feedback_clk -> aclk` CDC；该边界采用异步 FIFO、Gray pointer、同步器以及严格 backpressure 或可计数 drop 策略。

功能仿真已覆盖 bridge 的数据顺序和溢出行为，但尚未完成独立静态 CDC/RDC 工具签核。reset 断言、释放顺序、流排空和跨时钟 reset release 仍应在后续静态流程中审查。

## 8. 可复现执行入口

Linux/VCS 主入口位于 `uvm_verif/sim/`，Makefile 负责 filelist、编译依赖、testcase 选择、coverage database 合并；Python 负责向量生成、回归编排、日志和 CSV 汇总；shell 脚本负责加载 EDA 环境并调用工具。Windows PowerShell 脚本仅用于 Vivado/XSim 或跨 Windows-WSL 的便利启动，不是数字 IC 验证的唯一或首选执行环境。

推荐在已配置许可证的 Linux EDA shell 中执行：

```bash
cd /mnt/e/workspace/chip/dsm_ip
make -C uvm_verif/sim check-tools
make -C uvm_verif/sim vcs PYTHON=python3.12 COVERAGE=1
make -C uvm_verif/sim vcs-run-only UVM_TESTNAME=dsm_system_closure_test UVM_SEED=1 COVERAGE=1
```

实际回归应使用仓库中当前的 shell/Python 编排脚本；执行后必须审阅 CSV、日志标记和 coverage database，不能只看启动脚本是否返回。

## 9. 尚未完成的签核项

1. 对冻结主 SKU 的 raw code coverage 做可达性分类、定向补测和正式 waiver 审查。
2. 使用已授权静态工具执行 lint、CDC/RDC，并记录版本、规则集和 waiver。
3. 重建冻结 SKU 的完整 ZU15EG routed implementation、bitstream、I/O timing 和 DMA/ILA 回放。
4. 在明确的 PA、反馈接收机和测量口径下，单独评估 DPD 对 EVM/SNDR/ACLR 的改善；该结果不能由数字 monitor proxy 替代。

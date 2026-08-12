# UVM 验证平台

本目录是独立于原有 `verif/` smoke 回归的 UVM 验证工程，直接连接真实
`rtl/axi/dsm_ip_axi_top.v`，不复制 DUT 数据通路 RTL。

## 仓库分工

```text
rtl/        可综合 RTL 和 IP 封装
verif/      原有简单 testbench、XSim smoke 和回归脚本
uvm_verif/  独立 UVM 验证平台
docs/       规格、验证计划、状态和证据
```

## UVM 目录

```text
uvm_verif/agent/  AXI-Lite、AXI-Stream、RF 三类 agent 和 interface
uvm_verif/env/    配置、寄存器表、virtual sequence、scoreboard 和 environment
uvm_verif/formal/ 可选 SVA/formal 属性
uvm_verif/sim/    filelist、Linux Makefile、Python regression 和仿真输出
uvm_verif/tb/     DUT 顶层 testbench
uvm_verif/tests/  base test 和功能 testcase
uvm_verif/refmodel/python/ Linux/VCS bit-exact integer reference
```

## 当前 BP 配置

```text
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

## 当前验证数据流

```text
AXI-Lite active agent       -> DUT 控制/寄存器平面
TX AXI-Stream active agent  -> Q1.15 复数 IQ 输入
OBS AXI-Stream active agent -> PA/DPA feedback 输入
RF passive agent            <- rf_valid/rf_bit/rf_signed/phase_acc_dbg
scoreboard                  <- RF 输出事务
```

平台只有三种 agent 类型，但 AXI-Stream 类型实例化为 TX 和 OBS 两次，因此
environment 内共有四个 agent 实例。

## 如何编译和运行

Windows Vivado XSim 2024.1：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\uvm_verif\sim\run_xsim_uvm.ps1
```

进入 Linux EDA 环境后，在仓库根目录执行：

```bash
python3.12 --version
make -C uvm_verif/sim help
make -C uvm_verif/sim check-tools
make -C uvm_verif/sim vcs-run
make -C uvm_verif/sim vcs-run UVM_TESTNAME=dsm_performance_bittrue_test UVM_SEED=1
make -C uvm_verif/sim vcs-run UVM_TESTNAME=dsm_memory_dpd_bittrue_test UVM_SEED=1
make -C uvm_verif/sim vcs-run UVM_TESTNAME=dsm_memory_dpd_safety_test UVM_SEED=1
```

For a Windows host that cannot directly enumerate the registered EDA WSL
distribution, use the shared-drive Linux bridge after it has been started in
that Linux session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\uvm_verif\sim\run_control_coverage_bridge.ps1
```

The bridge submits only the repository script
`uvm_verif/sim/run_control_coverage_linux.sh`. It compiles once, runs the
three-seed `dsm_control_stress_test` regression, and creates
`uvm_verif/sim/out/vcs/coverage/dashboard.html`. It neither reads nor copies
licenses, PDKs, or external EDA installation files.

The Makefile uses `python3.12` by default. Override it for a different EDA
environment without editing the Makefile, for example `make -C uvm_verif/sim
vcs PYTHON=python3`.

正式回归由 Python 生成 testcase/seed 矩阵并并行运行：

```bash
python3 uvm_verif/sim/run_regression.py \
  --sim vcs --tests dsm_bp_test,dsm_axi_protocol_test \
  --seeds 1,2,3 --jobs 3
make -C uvm_verif/sim coverage-merge
```

需要 Verdi/FSDB 时，在编译和运行阶段同时传入 `FSDB=1` 与 `VERDI_HOME`，
再用 `make -C uvm_verif/sim verdi RUN_TAG=<test_seed>` 打开波形。

使用 Questa/ModelSim：

```bash
make -C uvm_verif/sim questa-run UVM_HOME=/path/to/uvm
```

也可以指定测试名和日志等级：

```bash
make -C uvm_verif/sim vcs-run \
  UVM_TESTNAME=dsm_bp_test UVM_VERBOSITY=UVM_MEDIUM
```

输出位于 `uvm_verif/sim/out/`，包括编译日志和运行日志。

## 冻结契约

- `env/dsm_uvm_reg_map.svh`：AXI-Lite byte address 的单一验证定义；
- `env/dsm_uvm_config.svh`：主 SKU、100 MHz 时钟和已确认 latency；
- DPD 四条模式统一为 10-cycle pipeline；
- x32 插值是带 backpressure 的变采样率弹性流水，端到端不得写死 cycle latency，必须按 `valid/ready` transaction 顺序对齐。

## 当前测试内容

当前 `dsm_bp_test` 会：

1. 通过 AXI-Lite 使能 BP IP；
2. 先读回 `VERSION/ALGORITHM/DUC_MODE/INTERP_MODE`，检查 DUT 与冻结 SKU 一致；
3. 发送一组 Q1.15 复数 IQ 样本；
4. 由 RF monitor 收集 `rf_valid` 事务；
5. 检查 `rf_bit` 是否同时出现 0 和 1；
6. 检查 `rf_signed` 是否和 `rf_bit` 极性一致；
7. 统计基础 RF bit、符号和相位 coverage。

`dsm_performance_bittrue_test` 是主 SKU 的确定性 system 数据通路检查：

1. Python integer reference 生成 24 个冻结 Q1.15 I/Q transaction；
2. TX agent 从 CSV 重放同一组 transaction；
3. scoreboard 同时检查 TX monitor 的 I/Q/`tlast` 顺序；
4. scoreboard 逐 transaction 检查 768 个 RF `rf_bit`、`rf_signed` 和 Fs/4 phase；
5. 所有输入和 RF expected queue 必须完整 drain，否则测试失败。

该测试当前固定 DPD runtime bypass，验证已编译的 Performance SKU 的 AXI-Stream ->
x32 interpolation -> Fs/4 mixer -> BP EFDSM2 主数据通路。

`dsm_memory_dpd_bittrue_test` 覆盖 active memory-DPD 的 system 场景：

1. AXI-Lite 向 inactive bank 写 4 tap x C1/C3/C5 的 12 个 Q2.14 complex coefficients；
2. 请求 `MP_COMMIT`，轮询 `MP_COMMIT_STATUS.ack`，检查 effective memory mode 和 bank；
3. Python 用相同 package 生成 DPD -> interpolation -> mixer -> BP EFDSM2 的 RF expected；
4. 逐 transaction 检查 TX 与 768 个 RF 输出，要求 expected queue 全部 drain。

`dsm_memory_dpd_safety_test` 单独写入绝对值 24577 的非法系数，要求
`MP_COMMIT_STATUS.failed` 和 `ERROR.bit3` 置位、active bank 保持不变。

`dsm_control_stress_test` is the control-subsystem UVM scenario. It uses the
real AXI-Lite, TX AXI-Stream, and observer AXI-Stream interfaces to exercise
independent AW/W arrival, B/R response stalls, long TX backpressure, a
software reset during an active TX transfer, `tuser`/`tlast` boundaries,
observer start-time backpressure, counter clear, and observer window status.
The test records actual handshaking delays in per-instance functional
covergroups; it does not infer coverage from requested driver delays.

On 2026-08-13, this test passed on VCS V-2023.12-SP1 with seeds `1`, `7`, and
`31`; every run reported `UVM_ERROR=0` and `UVM_FATAL=0`. URG generated the
merged report in `sim/out/vcs/coverage/`. This is control-scenario evidence,
not full-IP coverage closure: the merged total coverage score is about 59.22%.

`dsm_axi_protocol_test` 在同一真实 DUT 上进一步执行：

1. 随机打散 AXI-Lite `AW/W` 到达时间，并延迟 `BREADY/RREADY`；
2. 对 TX 和 OBS AXI-Stream 插入随机 `valid` gap；
3. 配置并启动 64 点 observer window；
4. 等待 x32 插值链路完全 drain，而不是依赖固定等待拍数；
5. 检查 64 个输入样本严格产生 2048 个 RF transaction；
6. 检查 observer `paired_count=64`、`drop_count=0` 和窗口完成状态；
7. 由 SVA 检查 AXI-Lite/AXI-Stream stall 期间 payload 稳定性。

coverage group 放在 package 级别，并在 scoreboard 构造函数中实例化，以兼容
VCS 对 UVM 派生类中 embedded covergroup 的构造限制。

协议级 sequence 位于对应 agent 目录；跨 AXI-Lite、TX 和 OBS 的 virtual
sequence 位于 `env/`；`tests/` 只负责配置环境并启动场景。

接口使用 `uvm_config_db` 配置到实际的 driver/monitor 实例路径，TX 和
feedback 两个同类型 AXI-Stream 接口分别绑定，避免相互覆盖。

这只是 UVM 平台连通性测试，不等于完整 IP signoff。

## 验证状态

2026-08-09 已在三类 agent 重构后使用 Vivado XSim 2024.1 的 UVM 1.2 库完成
真实 DUT 的编译、elaboration 和 `dsm_bp_test`：采集 768 个 RF transaction，0/1 均出现，
`UVM_ERROR=0`、`UVM_FATAL=0`。随后使用 VCS V-2023.12-SP1 运行
`dsm_bp_test` seed 1，结果同样为 768/400/368 和零 error/fatal，并生成
`simv.vdb`。XSim 还运行了 `dsm_axi_protocol_test` seed 7，得到 2048 个 RF
transaction，`UVM_ERROR=0`、`UVM_FATAL=0` 且协议断言无失败。当前尚未完成
VCS 多 seed regression、URG merge 和 coverage 签核；
Questa 未运行。

该结果签署基础连通、SKU readback、随机 AXI 时序、observer 基础窗口握手和
RF transaction 数量；它不单独签署 DPD bank commit、observer/monitor 数值或全链
MATLAB/RTL bit-true。

testbench 会在仿真时间 0 调用 `run_test()`，复位释放则在 8 个时钟后进行。
这是 UVM 的必要启动约束，不能在 `run_test()` 前放置带时间消耗的延时。

2026-08-12 已使用 VCS V-2023.12-SP1 在当前 RTL revision 上运行
`dsm_memory_dpd_bittrue_test` 与 `dsm_memory_dpd_safety_test`。前者对完整
Memory-Poly5/4-tap 链路的 768 个 RF transaction 完成 Python golden 逐项比较，后者验证
非法系数 commit 拒绝、active bank 保持及 `ERROR.bit3`；两者均为 `UVM_ERROR=0` 与
`UVM_FATAL=0`。这构成当前 control/data-path 的 system-level UVM 证据，但不等同于多 seed
coverage closure、reset/error 全矩阵或完整 IP signoff。

For the reproducible control-stress merge, use:

```bash
make -C uvm_verif/sim vcs PYTHON=python3.12 COVERAGE=1
python3.12 uvm_verif/sim/run_regression.py \
  --sim vcs --tests dsm_control_stress_test --seeds 1,7,31 --jobs 3 --skip-compile
make -C uvm_verif/sim coverage-merge \
  RUN_TAGS="dsm_control_stress_test_seed1 dsm_control_stress_test_seed7 dsm_control_stress_test_seed31"
```

# 仿真层

- `uvm_filelist.f`：UVM 平台和真实 BP EFDSM2 AXI RTL 的文件清单；
- `Makefile`：Linux VCS/Verdi 主流程，支持编译、单测、coverage merge 和 FSDB；
- `run_regression.py`：testcase/seed 矩阵、并行任务、日志判定和 CSV 汇总；
- `run_xsim_uvm.ps1`：Windows Vivado XSim 2024.1 编译、elaboration 和运行入口；
- `out/`：编译日志、运行日志和临时仿真文件，不应提交。

Windows XSim 只用于快速 smoke：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uvm_verif\sim\run_xsim_uvm.ps1
```

Linux VCS/Verdi 正式流程：

```bash
make -C uvm_verif/sim help
make -C uvm_verif/sim check-tools
make -C uvm_verif/sim vcs-run
python3 uvm_verif/sim/run_regression.py \
  --tests dsm_bp_test,dsm_axi_protocol_test --seeds 1,2,3 --jobs 3
make -C uvm_verif/sim coverage-merge
```

The reproducible IP-system closure entry point is:

```bash
bash uvm_verif/sim/run_ip_coverage_linux.sh
```

It runs 19 regressions: deterministic bit-true/safety tests once; AXI protocol,
control stress, and memory-DPD commit stress tests across seeds `1,7,31`; plus
AXI-Stream sideband coverage and system-closure tests across seeds `1,7,31`.
The system-closure testcase combines reset, DPD bank commit/reject, long random
TX traffic, observer windows, monitor readback, sticky-error behavior, and
counter clear checks. The Windows bridge submits this same Linux command; it is
not a simulator itself.

FSDB 调试示例：

```bash
make -C uvm_verif/sim vcs-run FSDB=1 VERDI_HOME=$VERDI_HOME \
  UVM_TESTNAME=dsm_bp_test UVM_SEED=1
make -C uvm_verif/sim verdi RUN_TAG=dsm_bp_test_seed1
```

PowerShell 脚本只负责调用 Windows Vivado 的 `xvlog/xelab/xsim`，不负责
Linux VCS regression、coverage merge 或 Verdi 调试，也不是正式 signoff 入口。

每次重新编译前建议先执行：

```bash
make -C uvm_verif/sim clean
make -C uvm_verif/sim vcs-run
```

这样可以避免继续读取旧的 `out/vcs/compile.log`。
## Regression Tiers

`run_ip_coverage_linux.sh` is the standard 20-run functional-coverage closure.
It includes the disabled Poly/LUT fallback and W1C sticky-error negative test.

`run_ip_extended_regression_linux.sh` is the optional overnight tier: six
protocol/control/system tests across 20 seeds (120 runs).  It increases random
stress; it is not required for the quick pre-commit loop.

On Windows, submit the overnight tier through
`run_ip_extended_regression_bridge.ps1`; the bridge is only a file-based
launcher into the Linux VCS host and does not implement or modify verification
logic.

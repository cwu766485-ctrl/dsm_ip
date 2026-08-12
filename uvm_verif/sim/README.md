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

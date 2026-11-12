# Frozen AXI-Lite Generic CDC/RDC

Actual product top, MAX_TAPS1, Generic FIFO; other product parameters retain
frozen defaults. Three unrelated clock domains and independent active-low
asynchronous reset inputs are declared. No reset correlation or waiver added.

Run each goal with its own output directory:

```bash
mkdir -p runs/static_fresh/cdc
THERMO5_STATIC_ROOT="$PWD" THERMO5_STATIC_OUT="$PWD/runs/static_fresh/cdc" \
THERMO5_STATIC_GOAL=cdc/cdc_verify_struct \
/opt/Synopsys/spyglass/V-2023.12-SP1/SPYGLASS_HOME/bin/sg_shell \
  -tcl dv/uvm/static/run_thermo5_axil_cdc.tcl
```

Other goals: cdc/cdc_setup_check and rdc/rdc_verify_struct. This conservative
boundary model does not assume all resets release together. Any justified
correlation must be reviewed against the SoC reset contract. Single-stage
AXI-Lite TB reset release is simulation behavior, not an RDC timing guarantee.
Tool success with violations is not signoff PASS.

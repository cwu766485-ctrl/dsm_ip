# Thermo5 Linux CDC/RDC bring-up — 2026-11-23

## Scope and decision

**OPEN.** This is a tool bring-up and raw triage checkpoint, not CDC, RDC,
formal, physical, or full-product signoff. Source baseline is commit
`1391a30f04c76117864ab82fb8fb5b23d60c0868`; the only source-tree change used
for the SpyGlass runs is the accompanying flow-script change. Product RTL is
unchanged. The actual project is `tid32_thermo5_compiletime_tx`, XPM FIFO
on, EF1 `DSM_ARCH=0`, MASH `DSM_ARCH=2`, with
`research/vcu118_arch/compiletime_product.sgdc` (three asynchronous clocks,
common asynchronous reset); no waivers were loaded. The design model and
constraints still require independent review against the final parent system.

## Results

| Check | Raw result | Decision |
| --- | --- | --- |
| EF1 CDC | 8 errors, 81 warnings; 0 waived | OPEN |
| MASH CDC | 8 errors, 83 warnings; 0 waived | OPEN |
| EF1 RDC structural | 4,417 errors, 74 warnings; 0 waived | OPEN |
| MASH RDC structural | 5,125 errors, 76 warnings; 0 waived | OPEN |
| Standalone reset synchronizer VCS test | 6 epochs, 18 releases, 27 checks; PASS | Scoped only |
| AXI-Lite configuration common-reset abort formal | 2 assertions proven non-vacuous; 2 covers hit at depth 10 | Scoped only |

Each RDC error is `Ar_resetcross01`; the companion CSVs group all reported
errors by rule, source and line (93 EF1 groups, 94 MASH groups). These are raw
counts, not independent root causes or approved exclusions. For example,
resettable control signals feed non-reset DPD data registers, but no path has
been disposed merely because its data is thought to be invalid after reset.

Both CDC reports contain three `Ac_cdc01a` fast-to-slow data-hold failures,
three `Ac_conv02` Gray-pointer convergence failures, one `Ac_conv04` Gray
encoding failure in XPM FIFO, and one `Reset_sync02` on the source-local reset
used by the FIFO core-clock reset synchronizer. These are tool findings, not a
conclusion that vendor FIFO or reset logic is faulty. Inspect trace, source,
clock and reset assumptions, XPM semantics and physical constraints before any
disposition. Both reports also flag two `SYNTH_12608` warnings in the
configuration module: independently inspect elaborated constant generate
branches before judging whether a latch exists in the product configuration.

The formal harness constrains `rst_n==1` after startup and exercises `epoch_n`
as the common abort; its reset setup check is explicitly disabled in the
existing script and the tool reported three potential reset setup issues. It
proves only the two named harness assertions and covers; it does not establish
system-level FIFO drain, independent reset behavior, or physical CDC safety.

## Reproduction and evidence

Tools: SpyGlass V-2023.12-SP1, VCS V-2023.12-SP1, VC Formal V-2023.12-SP2,
AMD XPM sources from Vivado 2026.1. Full reports and logs are local under
`runs/linux_cdc_rdc_probe/`; they are intentionally not committed. Copy and
archive them outside the workspace before cleaning generated artifacts.
The script now recognizes SystemVerilog 2009 and both `synopsys` and
`synthesis` pragma families. This permits XPM simulation-only translate-off
regions to be treated as intended. Vendor XPM internals remain in the design;
no CDC suppression was introduced.

From the isolated worktree, choose a **new** output directory on each run:

```sh
export VIVADO_ROOT=/mnt/d/AMDDesignTools/2026.1
export THERMO5_CTIME_ROOT="$PWD"
export THERMO5_CTIME_OUT="$PWD/runs/NEW_UNIQUE_OUTPUT"
export THERMO5_CTIME_ARCH=0 # use 2 for MASH
export THERMO5_CTIME_GOAL=cdc/cdc_verify # or rdc/rdc_verify_struct
/opt/Synopsys/spyglass/V-2023.12-SP1/SPYGLASS_HOME/bin/sg_shell \
  -tcl research/vcu118_arch/run_compiletime_spyglass.tcl
```

Do not use shell exit status alone as a pass indicator: invalid goals and design
read failures previously returned zero. Check the goal summary, fatal/error
counts, generated report and model assumptions. An attempt with the invalid
`rdc/rdc_verify` goal did not execute RDC; the table uses
`rdc/rdc_verify_struct` only.

```sh
mkdir -p runs/NEW_FORMAL_OUTPUT
export MAILBOX_FORMAL_ROOT="$PWD"
export MAILBOX_FORMAL_OUT="$PWD/runs/NEW_FORMAL_OUTPUT"
/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf -batch -fmode FPV \
  -f research/vcu118_arch/formal_cfg_common_reset_abort.tcl

vcs -full64 -sverilog -top tb_thermo5_reset_release_contract \
  rtl/axis/dsm_reset_sync.sv dv/verif/reset/tb_thermo5_reset_release_contract.sv \
  -o runs/NEW_RESET_SIM
runs/NEW_RESET_SIM
```

SHA-256 evidence identities:

| Artifact | SHA-256 |
| --- | --- |
| SpyGlass flow Tcl used for these runs | `4a7b12a92fa7e1b4949acbf5277feba21ea78a37a4e589a4e4be014aaaec4af3` |
| Product SGDC | `84bfa1507572d5ee0c0f83f12021e4e76bbf02a39886587b534573ac8b399c2d` |
| Formal harness | `a41dd7909ec9e6d9df2c97176b30b7751b225a69718fed755b38dec703016b22` |
| Formal script | `b922f279209c1d20310453ce78f59c3e06a21f000d907369f361629d7678a1d7` |
| EF1 CDC moresimple | `4f9f066ab7b29d294efe137446e06518f064f2cdf82acca5f37966fc2f4168a0` |
| MASH CDC moresimple | `750028e2940bac0572f7ca7727f69680f5d0d66a435b35c1aa103ceff264042f` |
| EF1 RDC moresimple | `503b71d13bf2abbef3f62586aff056042d5def0557358d6352b93c93b4581e98` |
| MASH RDC moresimple | `e442e996e45638cb1379a3cf67828321326cafa2ad390a3247bebf879bbd7894` |
| Formal property list | `0c2a5f57f20a7e6f70f00dc6d17205f5a15267e0abe00b5d300f85af43634415` |
| Reset simulation log | `ac594667ed5a43ac8cdd8399e5557955f62b234e4c42de9f888ce3a93c8f3f42` |

## Remaining gates

1. Audit all source/line clusters against actual reset cones and data-valid
   masking, validate XPM reset/Gray crossing contracts and physical constraints,
   then resolve each finding with evidence. No bulk waiver.
2. Close product-level reset, FIFO, mailbox, abort/restart properties with
   audited assumptions and non-vacuous activity witnesses.
3. Reconcile the existing EF1/MASH OOC Vivado reports with the final constraints
   and actual routed hierarchy. Prior positive OOC slack (+0.025/+0.026 ns EF1,
   +0.108/+0.015 ns MASH) does not meet the requested +0.15 ns reserve and is
   not parent-system or board signoff.
4. Run the three requested UVM configurations with independently checked EF1,
   EF2 and weighted MASH output contracts. This run did not execute product
   UVM regressions or claim functional/code coverage closure.

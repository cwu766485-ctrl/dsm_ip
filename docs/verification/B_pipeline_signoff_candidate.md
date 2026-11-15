# Thermo5 B Pipeline Signoff Candidate

Date: 2026-11-15 (SGT)  
Branch: `work/vcu118-ab-ppa`  
Source baseline before this candidate: `cc2c3ed5024ee86e244b6e1a4f0fc98b56facd7f`

## Decision

The B Pipeline ECO has positive routed setup slack under two implementation
strategies and passes the directed AXI-Lite DPD COMMIT test with Generic and
XPM FIFOs. This is a signoff candidate, not final product signoff: automated
XSim launch/capture is still unreliable, and the product reset, STOP/restart,
long random-backpressure, VCS and Formal checks remain open. No further Cubic
pipeline stage is proposed.

## Routed evidence

Vivado 2026.1, part `xcvu9p-flga2104-2L-e`, AXI-Lite product top
`tid32_thermo5_axi_lite_axis_frontend_tx`; elaborated configuration is
Centered-Cubic, `INTERP_TAPS=2`, `TIDSM_ORDER=1`, `STEP=5120`,
`DPD_MAX_TAPS=1`, `FPGA_USE_XPM_FIFO=1`, clocks 125/218.75/100 MHz.

| Implementation | WNS | WHS | Setup/hold failing endpoints | LUT | FF | DSP48 | BRAM tiles | URAM | Power |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Explore | +0.307 ns | +0.028 ns | 0 / 0 | 48,624 | 53,556 | 496 | 6.5 | 0 | 4.186 W vectorless |
| RuntimeOptimized | +0.249 ns | +0.028 ns | 0 / 0 | 48,624 | 53,556 | 496 | 6.5 | 0 | 4.186 W vectorless |

The worst routed path in the Explore report is 11 logic levels, 3.939 ns
(2.622 ns cell, 1.317 ns net). The power estimate has no SAIF activity and is
not measured workload power. Full reports and DCPs are retained in
`runs/thermo5_vcu118_B_pipeline_route_20261115/` and
`runs/thermo5_vcu118_B_pipeline_runtimeoptimized_20261115/`.

Routed DCP SHA-256:

- Explore: `1f5cd3c950c8da8b1a2781b7d788fd0c09f307549836aedb0098e6a645a9088f`
- RuntimeOptimized: `e694a728b7523a50d65683314d957316ef716dd6f63c2cffb0457cad42fe8173`

## COMMIT differential

All four tests used seed 1, 56 source words, identical vector files, frame
starts at sample indices 0, 14 and 35, centered-cubic EF1/STEP=5120, identical
AXI-Lite writes, and the same testbench scoreboard. The AXI-Lite simulation
top allows `DPD_MAX_TAPS=4` so it can commit a two-tap identity image; the
routed PPA product configuration is separately fixed at `DPD_MAX_TAPS=1`.
Each run reports 32 source beats, 59 accepted DPD
inputs, and 56 PA output words. DPD transactions 14, 36 and 58 are the three
`tail=1` lookahead vectors, one for each source frame; they are consumed at
the DPD boundary but do not create PA words. Every lane's DPD sample count is
59 and the four PA planes match the Python oracle.

| RTL/FIFO | First marked DPD input / COMMIT boundary | PASS log |
|---|---:|---|
| Original B / Generic | 638 ns | `runs/uvm_thermo5_i2_d1/axis_xsim_axil_generic_centered_ef1_seed1_words56_gate1_original_generic/xsim.log` |
| Pipeline B / Generic | 647 ns | `runs/uvm_thermo5_i2_d1/axis_xsim_axil_generic_centered_ef1_seed1_words56_gate1_pipeline_generic/xsim.log` |
| Original B / XPM | 839 ns | `runs/uvm_thermo5_i2_d1/axis_xsim_axil_xpm_centered_ef1_seed1_words56_gate1_original_xpm/xsim.log` |
| Pipeline B / XPM | 848 ns | `runs/uvm_thermo5_i2_d1/axis_xsim_axil_xpm_centered_ef1_seed1_words56_gate1_pipeline_xpm/xsim.log` |

The ECO adds the expected two Core cycles: 9 ns in the observed event timeline
for both FIFO implementations. Commit applies on the first marked DPD input
in all four cases. Each run directory also contains `axil_trace.vcd`, the
Vivado compile/elaboration logs and the exact vector files. The previous
Generic 59/56 and XPM handshake-timeout logs are retained in their original
directories.
The compact SHA-256 index for the four logs, four VCDs and two routed DCPs is
`docs/verification/data/b_pipeline_signoff_evidence.sha256`; run payloads
remain ignored under `runs/` per repository policy.

The Generic failure was a testbench expectation error: it compared 59 DPD
samples against 56 PA words and omitted the three tail transactions. The XPM
failure was caused by `USE_ADV_FEATURES="0000"`: Vivado 2026.1 maps bit 10 to
`EN_RDC`, which gates `rd_data_count`; the CDC gearbox's two-entry prefill
gate therefore never opened. The current XPM `USE_ADV_FEATURES="0400"` sets
only bit 10. The installed XPM FIFO model accepts this configuration for
`FIFO_MEMORY_TYPE="block"`, `READ_MODE="fwft"`, depth 16, and
`RD_DATA_COUNT_WIDTH=5`; its configuration DRCs pass and the XPM simulation
completes. There is no `DATA_DV_FEATURES` parameter on this `xpm_fifo_async`
interface; the relevant documented parameter is `USE_ADV_FEATURES`.

## Runner and reproduction

`run_xvlog` and `xelab` finish under the PowerShell runner, but its `cmd.exe`
XSim batch launch can report that `xsim.dir/.../xsimk.exe` is missing even
when that PE executable exists on disk. The tests above were run by launching
the compiled snapshot from a separate native Windows PowerShell session in
each run directory:

```powershell
Set-Location E:\workspace\chip\dsm_ip_thermo5_vcu118\runs\<run-directory>
& D:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat sim_thermo5_i2_d1_axis -runall -sv_seed 1 -testplusarg AXIL_TRACE
```

The runner fix is still OPEN; do not claim automated-runner closure from the
manual native launches. The exact successful command, full stdout, `$finish`
marker, trace VCD and tool logs are retained for each configuration.

A Linux-to-Windows reproduction was attempted on 2026-11-15 with a fresh
Pipeline B/Generic run directory. XVlog and Xelab passed, and
`xsim.dir/sim_thermo5_i2_d1_axis/xsimk.exe` existed, but the runner's nested
`cmd.exe /c call xsim.bat` emitted `ERROR: Please check the snapshot name ...
xsimk.exe does not exist` and did not produce the COMMIT PASS marker. Launching
the same snapshot with native PowerShell directly from that run directory
produced `THERMO5_AXIL_CONFIG_BITTRUE_PASS` and `axil_trace.vcd`. Two
PowerShell child-process variants tested during this session also failed to
produce a usable `xsim.log`; those unvalidated script edits were not retained.
The issue is therefore reproduced and localized to automated batch startup,
but no runner fix is claimed.

## Remaining checks

- Product reset during traffic and reset with occupied pipeline.
- Product STOP/restart and drain behavior.
- Long randomized backpressure with transaction-order comparison.
- VCS and VC Formal; neither is claimed as run in this candidate.
- Automated PowerShell XSim launch and log capture.

The Cubic ECO's two added registers are in the existing Core clock domain and
do not introduce a new clock crossing by construction. A fresh SpyGlass
CDC/RDC run on the final ECO was not performed, so static CDC/RDC closure is
not claimed. Reset/STOP behavior through the new stage and its branch/condition
coverage are additional OPEN obligations; no post-ECO URG/code-coverage merge
was run. The focused COMMIT and routed PPA evidence above does not close these
items.

The two routed strategies, source/configuration reports, and raw simulation
artifacts remain local under ignored `runs/`; generated tool outputs are not
added to Git. This candidate does not change the `thermo5` branch and has not
been pushed or merged.

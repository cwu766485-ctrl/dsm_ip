# MASH-to-GTY digital chain

Status: **BLOCKED** for live AXI-Stream-to-GTY full-chain verification. There is no integrated product path connecting the runtime frontend, a complete-frame buffer and GTY in one DUT. The existing raw serializer assumes four planes and flags a two-plane MASH mask; it also has a STOP/drain incompatibility. Do not treat the separate tests below as a single integrated pass or as physical RF evidence.

- PASS, separate product simulation: seed 281001, 8 symbols, identity DPD, actual accepted MASH PA capture; EVM 2.551442%, SNDR 31.864285 dB, 15 errors / 37,376 uncoded bits and combined digital adjacent-band proxy -16.177531 dBc. Fixed architecture source offset 528 samples. Evidence: `runs/three_arch_qam_281001/`.
- PASS, separate frame buffer test: all 5,264 real words of both PA lanes replayed bit-for-bit through the research two-bank prefill buffer, with input bubbles and STOP during frame, with fixed-rate output and metadata checking. Evidence: `runs/prefill_actual_qam_01/simulation.log`. This is a single-clock candidate, not a product integration or a proof of unlimited continuous frames.
- PASS, separate vendor digital simulation: nominal 14.000 Gb/s with 125 MHz reference and 64-bit words; GTY TX and PMA RX loopback passed 16,384 bits on each lane, aligned in that simulation. Evidence: `runs/gty_qsfp_loopback_launcher/console.log`. Hardware GTY clock programming, physical skew, eye, RF and ACLR are NOT_RUN.
- PASS, captured-PA-to-GTY replay: `runs/gty_pa_replay_04/project/gty_sim.sim/sim_1/behav/xsim/simulate.log` reports both TX serial and PMA RX bit-true for all 5,264 words / 336,896 bits per lane. Both TX sample offsets match (0 UI observed lane skew); both RX offsets match. Input bubbles, complete-frame prefill, per-word tail, fixed metadata and STOP during frame were checked. These are synthetic metadata on a captured PA replay, not metadata from a live frontend.
- PASS, recovered serial data and same receiver: SHA-256 PA0 `c71de3d15c33e3ee45d512ac29a0fd85986c9d244f4698abc3a9c2dd0b43ac1b`, PA1 `9c8360c85fbf33dbdc106d98d3e817e4418bf993118a15394c87e49b513a94b6`, exactly matching the source files; zero bit differences (`runs/gty_serial_receiver_01/compare.json`). Receiver EVM 2.551442%, SNDR 31.864285 dB, uncoded BER 15/37,376 (`runs/gty_serial_receiver_01/metrics.json`). Fixed receiver source offset is 528 samples. The separate Welch PSD of recovered serial bits has combined adjacent proxy -16.314892 dBc, lower -19.254889 dBc and upper -19.396653 dBc (`runs/gty_serial_psd_01/`). This PSD uses a different Welch window/FFT configuration from the three-architecture comparison, so compare like methods only.
- FAIL, preserved attempts: runs 01 and 02 could not find the simulation tool in PATH. Run 03 reached serial comparison but failed; a nominal 71.428571 ps UI rounded to 1 fs on every delay causes long-run testbench sampling drift. Run 04 uses exactly 500 ps per seven samples and passes. This is evidence for a testbench sampling-time issue, not a claim that the failed trace was physically correct.
- BLOCKED: live AXI-Stream-to-GTY integration, actual generated frame/tail metadata, independent reset/relock and cross-clock conditions remain unverified. The successful captured-PA replay does not establish this full-chain acceptance.

Reproduction from this worktree using a **new** output directory:

```powershell
& 'D:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat' -mode batch -source research/vcu118_arch/sim_gty14_pa_replay.tcl -tclargs runs/gty_pa_replay_NEW
```

The script uses the immutable capture under the neighboring `thermo5_runtime_product` worktree. Compare both dumped serial PA planes to that capture before invoking the same receiver; never search arbitrary OFDM timing to claim a pass. Fixed frame alignment must come from the documented serial and frontend contract. The digital adjacent-band proxy is not measured RF ACLR.

For the demonstrated serial reconstruction, copy the two `serial_pa*.mem` files
from the XSim working directory into a **new** capture directory as
`phase1_arch2_pa0.mem` and `phase1_arch2_pa1.mem`, then run:

```bash
python3 dv/uvm/refmodel/python/thermo5_runtime_qam.py evaluate --prepared ../thermo5_runtime_product/runs/runtime_qam281001 --capture runs/NEW_CAPTURE --out runs/NEW_CAPTURE/metrics.json
python3 research/vcu118_arch/fs4_psd_audit.py --pa0 runs/NEW_CAPTURE/phase1_arch2_pa0.mem --pa1 runs/NEW_CAPTURE/phase1_arch2_pa1.mem --out runs/NEW_PSD
python3 research/vcu118_arch/psd_band_metrics.py runs/NEW_PSD/actual_pa_psd.csv --out runs/NEW_PSD/bands.json
```

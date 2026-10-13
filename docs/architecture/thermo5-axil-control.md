# Thermo5 AXI4-Lite DPD control plane

## Scope

`tid32_thermo5_axi_lite_axis_frontend_tx` is an optional system wrapper around
the existing thermo5 AXI-Stream/CDC/frontend path. The frozen
`tid32_thermo5_axis_frontend_tx` parallel-configuration interface is unchanged.
The new wrapper adds a low-rate AXI4-Lite control plane and a synchronized
`run_request`; it does not claim calibrated PA linearization. The default DPD
coefficients still implement identity (`c1[0] = 1.0` in Q2.14 and all other
terms zero).

## Register map

All registers are 32-bit, byte-addressed and word-aligned. Unsupported
addresses return `DECERR`; coefficient registers are writable as shadow state.

| Offset | Register | Fields / behavior |
| --- | --- | --- |
| `0x00` | CONTROL | bit 0: stored `run_request`; write bit 1 as one to request atomic DPD configuration commit. Readback returns bit 0 only. |
| `0x04` | STATUS | bit 0 BUSY; bit 1 DONE; bit 2 ERROR. DONE and ERROR are sticky and write-one-to-clear. |
| `0x08` | DPD_TAPS | Shadow active tap count. Legal commit range is 1 through elaborated `MAX_TAPS` (1–4). An illegal count is rejected with `SLVERR`. |
| `0x0c` | IP_ID | `0x54483501`. |
| `0x10/0x14` | C1_RE | Low/high 32-bit halves of four packed signed 16-bit Q2.14 tap coefficients. Tap 0 occupies bits `[15:0]`. |
| `0x18/0x1c` | C1_IM | Same packing for imaginary linear coefficients. |
| `0x20/0x24` | C3_RE | Same packing for real cubic coefficients. |
| `0x28/0x2c` | C3_IM | Same packing for imaginary cubic coefficients. |
| `0x30/0x34` | C5_RE | Same packing for real fifth-order coefficients. |
| `0x38/0x3c` | C5_IM | Same packing for imaginary fifth-order coefficients. |

`MAX_TAPS` is an elaboration-time resource choice; software cannot exceed it.
The wrapper currently uses 16-bit coefficient precision and Q2.14 scaling,
matching the memory-polynomial RTL. The legal active tap count is 1-4.

`ERROR` is set for a rejected COMMIT (illegal tap count or a second COMMIT
while BUSY); unsupported addresses return `DECERR` but do not set this sticky
bit. Shadow coefficient/tap writes are allowed while a prior snapshot is in
flight, but a second COMMIT is rejected until the first one completes.

## Commit and clock-domain contract

AXI shadow registers are snapshotted into a bundled-data mailbox when CONTROL
bit 1 is written. The mailbox remains stable until the core acknowledges it.
Only the request/acknowledge controls pass through two-flop synchronizers;
coefficient data is captured as one coherent bundle after the synchronized
request is observed. The core holds a pending bundle until the next accepted
DPD input word whose frame-start marker is asserted. The marker travels with
the sample word through the gain/interpolation/elastic stages, and the new
configuration is selected on that exact DPD input handshake. Coefficients are
also pipelined with each DPD sample, so in-flight earlier samples retain their
old coefficients.

If no marked DPD word arrives, BUSY intentionally remains asserted and the
active configuration does not change. Software should poll STATUS before
issuing another commit. `run_request` is synchronized as a level; it is not a
reset or a pause/drain protocol. Do not clear it during an active frame or
while data is in flight: the existing frontend flushes its valid pipeline when
disabled. Stop only after the producer is quiescent and all expected PA words
have been accepted, or assert the common reset epoch.

The AXI-Lite and core reset inputs must assert in the same reset epoch;
deassertion must be synchronized separately to the AXI-Lite and core clocks.
The UVM top models this with common asynchronous assertion and an AXI-Lite
reset-release synchronizer. The AXI-Stream source reset remains the separate
FIFO write-side reset and must follow the existing CDC reset contract.

## Worked datapath example

The memory-DPD input is a 16-complex-sample vector: the first x2 interpolator
turns an 8-sample core word into 16 samples. For one lane, take
`x = 8192 - j4096`. With `c1[0] = 0x4000` (1.0 in Q2.14), all `c3/c5` terms
zero, and one active tap, the memory-polynomial output is `y = x`; the other
15 lanes are evaluated in parallel with the same coefficient set. A two-tap
configuration with tap 0 unity and tap 1 zero is also identity, but it proves
that software configuration changed the active tap count without changing
the frozen bit-true output.

Software writes shadow taps/coefficients and then COMMITs. The source domain
snapshots the 387-bit bundle and holds it stable while request/acknowledge
toggle controls cross the asynchronous 100-MHz AXI-Lite / 218.75-MHz core
boundary. The core waits until a valid frame-start-marked DPD input vector is
being accepted. On that exact handshake, the pending coefficient bundle is
selected for all 16 lanes; vectors already in the DPD pipeline retain their
previously captured coefficients. The second x2 interpolator then produces
32 complex samples, which the thermo5 TID/DSM maps into four aligned 64-bit
code-plane words.

## Verification

`thermo5_sku_axil_config_test` adds an independent AXI-Lite UVM agent while
reusing the existing AXI-Stream source agent, four-plane monitor and MATLAB
bit-true scoreboard. It checks ID/readback, illegal-tap `SLVERR`, sticky error
and W1C clearing, AW/W skew, BUSY while waiting for a frame boundary, no early
application, and a legal two-tap configuration that remains mathematically
identity (unity tap 0; all other coefficients zero). It then checks the full
four-plane output against the unchanged oracle.

The Vivado XSim runner exercises the actual UVM 1.2 class-based test with
`UVM_NO_DPI` (the simulator's bundled UVM package is used):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\uvm\sim\run_thermo5_axil_xsim.ps1 -Seed 101
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\uvm\sim\run_thermo5_axil_xsim.ps1 -XpmFifo -Seed 101
```

Both generic and real XPM FIFO versions passed this configuration test on
2026-10-11 with zero UVM errors/fatals and the 56-word MATLAB bit-true check.
The script stores the full logs under a unique `runs/` directory. The test is
also available in the licensed Linux VCS flow. Run from Linux VCS with:

```sh
make -C dv/uvm/sim thermo5-axil-config-vcs-run \
  THERMO5_FIFO_IMPL=generic UVM_SEED=101 \
  THERMO5_OUT="$PWD/runs/thermo5_axil_cfg_vcs_generic"
```

The VCS-UVM run was attempted on 2026-10-11 but could not check out a VCS
license; XSim UVM is the executed evidence for this change, not a claim that
VCS passed. The AXI-Lite wrapper's XPM full OOC synthesis completed with
71,537 LUTs, 52,255 registers, 1,936 DSPs and 334.5 BRAM tiles. The full
implementation run is still active; no routed WNS/WHS result is available yet.
This configuration/CDC regression is not a substitute for CDC/RDC analysis,
bundled-data timing constraints, routed STA, independent reset-stress testing,
or calibrated nonlinear DPD bit-true testing. Those remain separate signoff
items.

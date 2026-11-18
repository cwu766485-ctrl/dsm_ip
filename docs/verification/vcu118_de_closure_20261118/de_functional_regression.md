# DE functional regression

- Original product independent AXI-Lite reset: FAIL old pending configuration commits (`runs/cfg_independent_reset_epoch_01/`).
- DPD reset candidate isolated directed AXI-only reset and new configuration: PASS, `runs/de_independent_reset_candidate_01/`; original runtime mode mailbox not covered.
- Candidate substituted into AXI-Lite product in isolated worktree, existing independent Golden: PASS `THERMO5_AXIL_CONFIG_BITTRUE_PASS`, 32 input beats/56 output words, `runs/de_epoch_candidate_sandbox/runs/uvm_thermo5_i2_d1/axis_xsim_axil_generic_causal_ef1_seed880292_words56/`. Candidate SHA and baseline are recorded in sandbox manifest. This does not prove independent reset during full-chain traffic.
- Candidate product VCS functional regression with AXI-Lite and coverage disabled: bit-true test passed; bubble/backpressure test **FAIL** on timeout (`runs/de_epoch_candidate_sandbox/runs/de_candidate_vcs_01/`). An identical AXI-Lite bubble test on original RTL also times out (`runs/de_axil_backpressure_baseline_01/`). Test calls `env.control.core_on()` rather than the AXI-Lite `request_stream_enable` path used by the bit-true test. A test-driver correction switches to the existing AXI-Lite RUN/STOP helper and preserves all comparison and coverage assertions. The candidate with corrected test **PASS** (56 words, `i2=1`, held outputs 88/138, zero UVM error/fatal) in `runs/de_epoch_candidate_sandbox/runs/de_axil_bubble_test_repair_01/`. The correction is now also on this branch; baseline regressions for both parallel and AXI-Lite interface modes passed with 56 Golden words and zero UVM errors/fatals in `runs/de_bubble_test_repair_regression_01/`. The original timeout remains a failed run and is not overwritten.
- Frame/metadata, STOP/restart, backpressure, underflow, both reset domains and post-reset output epoch for the modified full runtime product remain OPEN. No Golden, limits or assertion were weakened.

Reproduce the baseline two-mode repaired bubble test using
`runs/de_bubble_test_repair_regression_01/run.sh` with fresh output paths;
the candidate repaired-driver result is under
`runs/de_epoch_candidate_sandbox/runs/de_axil_bubble_test_repair_01/`.
The remaining candidate-only PPA and formal jobs have not yet completed.

- Candidate Core-only reset/restart: **FAIL**, old request `0x1234` is
  replayed after reset (`runs/de_core_reset_candidate_witness_01/`). This
  failure motivated stopping the candidate PPA; the implementation and logs
  are preserved and the candidate is not promoted.

- Candidate 2 AXI-Lite and Core independent-reset tests, partial AW/W SLVERR,
  stalled-B stability/sticky status and pending mode abort/restart: scoped
  directed PASS; Core-only reset after completed mode 2 leaves incorrect AXI
  mode readback, FAIL (`runs/de_candidate2_mode_readback_01/`).
- Candidate 3 passes six directed cases, independent-Golden XSim (32 beats/56
  words) and two VCS tests with coverage disabled, but AXI-only reset changes
  the Core mode from MASH to EF2 while Core reset stays released; this
  candidate is therefore **FAIL / not product qualified**. Full-chain live
  traffic behavior, PA routing and all clock/reset phases remain OPEN.

Reproduce candidate 3's six directed checks plus its expected mode-change
witness using `bash research/vcu118_arch/run_de_candidate3_directed.sh
runs/NEW_DIR`. The final witness intentionally demonstrates an unresolved
mode change and must not be interpreted as product PASS.

- User-selected safe-stop integration prototype: isolated Runtime three-mode
  XSim test passed 448 output words, 6/6 transitions, 727 stalls and 187
  partial-ready events in `runs/de_abort_integration_sandbox/runs/runtime_abort_normal_01/`.
  This is a normal-operation test and does not itself exercise AXI-only reset.
  The live AXI-only reset during GT serialization test is running in
  `runs/live_axil_abort_01/`; no pass is claimed yet.

- Abort-wrapper Runtime VCS minimal regression (Generic FIFO, no coverage
  instrumentation) passed 448 words and 6/6 transitions, zero UVM errors/fatals
  in `runs/de_abort_integration_sandbox/runs/runtime_abort_vcs_01/`.
- Live GTY attempt 01 observed PA-mask clear during AXI-only reset while
  emitting, but also reported a pre-reset underflow with RUN still high. It is
  **FAIL** for continuous-frame qualification regardless of later markers.
  Test source was preserved under its `isolated_sources/`. Attempt 02 sends a
  legal STOP for the completed source frame and explicitly fails if pre-abort
  underflow/protocol flags appear; it is running in `runs/live_axil_abort_02/`.
  Do not treat STOP as hiding an underflow: attempt 01 remains preserved.

Attempt 01's post-reset frame serial TX and RX both matched 336,896 bits per
lane, with zero observed inter-lane skew, drain=1 and post-reset underflow=0.
The receiver applied to the actual post-reset serial bits gives EVM 2.551442%,
SNDR 31.864285 dB, 15/37,376 uncoded bit errors, with digital lower/upper
adjacent proxies -19.254889/-19.396653 dBc. Evidence:
`runs/live_axil_abort_receiver_01/`, `runs/live_axil_abort_psd_01/`,
`runs/live_axil_abort_01/`. The test scans for the serialized frame pattern
to identify the capture boundary; that diagnostic does not establish a fixed
hardware timing contract. The pre-reset underflow means the overall attempt
remains FAIL despite the simulator's final success marker. This is not RF ACLR.


## AXI-only reset during live GT serialization — attempt 02

**PASS, bounded digital research test only**: with a complete prefetched frame
and legal STOP, the actual RTL MASH chain and two GTY models emitted 100 PA
words before AXI-Lite alone was reset. The prototype wrapper asynchronously
suppressed PA valid and held the externally connected input/serializer epoch
resets active; the modeled serializer `out_mask` cleared. After reconfiguration,
the full 5,264-word frame, frame/config metadata and 336,896 TX and RX bits per
lane matched independent Golden; observed inter-lane skew was zero, drain=1,
underflow=0, protocol=0. No pre/post-reset `LIVE_FIRST_UNDERFLOW` or fatal was
reported. `runs/live_axil_abort_02/project/gty_sim.sim/sim_1/behav/xsim/simulate.log`
SHA-256 `e2ef9ebc9fe6f384e9e373307ac82b2e6f017f742149001bda06c529dbc7b507`.
The prior attempt 01 is still **FAIL** because of pre-reset underflow.

Actual post-restart serial bits at fixed receiver source offset 528 give
EVM 2.551442%, SNDR 31.864285 dB and BER 15/37,376 (0.000401327); positive-
frequency adjacent digital power is -19.254889/-19.396653 dBc in the stated
250 MHz Welch bands (`runs/live_axil_abort_receiver_02/`,
`runs/live_axil_abort_psd_02/`). These are not measured RF ACLR. The TX/RX
bitstream comparator scans for the serialized frame pattern to identify the
capture boundary, so this experiment does not establish a fixed physical
serializer phase/latency contract. Epoch input to the serializer remains
synthetic zero. The input and serializer buffers are research modules; the
additional resets must be connected by the parent and physical PA-enable
gating must be implemented. Core-only reset on the complete live chain,
unbounded/random starvation, true frame abort metadata, board GT and RF remain
OPEN. No full-Top routed timing or system CDC/RDC is established.

Vivado 2026.1 / nominal 14.000 Gb/s; source Git and SHA-256 hashes are in
`runs/live_axil_abort_launcher_02/manifest.json` (the testbench was a recorded
dirty source at launch; the source hash is authoritative). Reproduce with
`vivado -mode batch -source research/vcu118_arch/sim_live_axil_abort_restart.tcl
-tclargs <NEW_OUTPUT_DIR>` from a fresh working directory and require both
serial/RX markers, final drain diagnostics and no first-underflow/fatal marker.
Copy the actual `serial_pa{0,1}.mem` to a fresh capture directory and run the
receiver and PSD commands in
`docs/verification/vcu118_convergence_20261117/full_chain_gty_report.md`.

- An equivalent Runtime-mode abort PPA proxy passed the independent-Golden
  three-architecture VCS test: 448 words, 6/6 mode transitions, 738 stalls,
  no UVM errors/fatals (`runs/de_abort_integration_sandbox/runs/abort_ppa_equiv_01/`).
  Static EF1/MASH proxy modes and system reset behavior require further checks.
- Core-only reset during active GT serialization with AXI-Lite left live:
  **PASS for this bounded digital case** in `runs/live_core_abort_01/`. After
  100 emitted words the modeled PA mask clears; after reconfiguration and
  restart 5,264 words and 336,896 serial TX/RX bits per lane match Golden,
  observed lane skew 0, drain=1, underflow=0, protocol=0. The receiver applied
  to actual serial bits gives EVM 2.551442%, SNDR 31.864285 dB, BER 15/37,376;
  lower/upper digital adjacent proxies -19.254889/-19.396653 dBc
  (`runs/live_core_abort_receiver_01/`, `runs/live_core_abort_psd_01/`). This
  test does not have an AXI write/B response pending during the reset, and
  serial frame-boundary pattern search, synthetic epoch, research buffers
  and physical PA/RF limitations are the same as the AXI-only test.

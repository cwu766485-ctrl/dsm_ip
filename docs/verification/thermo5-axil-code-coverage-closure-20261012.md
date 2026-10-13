# AXI-Lite thermo5 exception and code-coverage closure

Date: 2026-10-12 (Asia/Singapore)

## Scope

This record covers the optional
`tid32_thermo5_axi_lite_axis_frontend_tx` configuration-control integration.
It is separate from the frozen parallel-configuration thermo5 SKU. The
generic and XPM runs use the same source/test suite; the XPM run uses the
Vivado 2024.1 XPM simulation sources.

## Tests run

`make -C dv/uvm/sim thermo5-axil-vcs-regression THERMO5_USE_AXIL=1` ran:

| Scenario | Check / expected result | Evidence |
| --- | --- | --- |
| AXI-Lite configuration + 56-word four-plane stream | Register read/write, AW/W skew, busy/illegal tap rejection, atomic frame-boundary apply, PA stall, bit-true output, reset defaults; zero UVM errors/fatals | `runs/thermo5_axil_covclosure_generic_retry2_20261012/` and `runs/thermo5_axil_covclosure_xpm_retry1_20261012/` |
| Illegal frame | Expected RTL assertion, sticky protocol error, public-reset recovery | `axil_illegal_frame_seed420102.log` in each run directory |
| Mailbox corruption | VPI corrupts the held bundle while request is pending; expected RTL `$error`, then public-reset recovery | `axil_mailbox_fault_seed420103.log` in each run directory |
| Invalid MAX_TAPS parameter | Separate tiny top elaborates `MAX_TAPS=0` and `MAX_TAPS=5`; both expected parameter errors observed | `runs/thermo5_axil_parameter_guard_clean_20261012/parameter_guard/run.log` |
| Defensive read-helper default | Unit probe calls `coeff_read_word(8'h40)` and checks zero; normal AXI decode rejects the address before the helper is called | Positive-test log and merged VDBs in the generic/XPM run directories |
| Address-channel backpressure | Holds a second legal `ARVALID` while the first `RVALID` is stalled; verifies `ARREADY` returns and both responses are correct | Positive-test log and merged VDBs in the generic/XPM run directories |

VCS V-2023.12-SP1 passed the generic and XPM AXI-Lite regression targets;
both URG merges passed. Each merged functional report shows `source_cg=100%`
and `core_cg=100%`. The two expected RTL `$error` events are negative-test
checks, not UVM errors or unexpected failures.

## Measured code coverage

The merged AXI-Lite **three-test** reports are targeted reports; they do not
contain the complete long-stream/reset/FIFO-boundary thermo5 suite.

| Scope / metric | Generic | XPM |
| --- | ---: | ---: |
| Targeted full-hierarchy score | 74.54% | 74.43% |
| Targeted full-hierarchy line | 80.75% | 73.53% |
| Targeted full-hierarchy condition | 61.77% | 59.50% |
| Targeted full-hierarchy toggle | 75.11% | 73.89% |
| Targeted full-hierarchy branch | 55.37% | 56.16% |
| Functional covergroups | 100% | 100% |
| `thermo5_dpd_axi_lite_cfg` line | 99.38% (159/160) | 99.38% (159/160) |
| `thermo5_dpd_axi_lite_cfg` condition | 95.95% (71/74) | 95.95% (71/74) |
| `thermo5_dpd_axi_lite_cfg` toggle | 33.50% | 33.50% |
| `thermo5_dpd_axi_lite_cfg` branch | 97.50% (78/80) | 97.50% (78/80) |

The separate invalid-parameter VDB is not merged into the integration report:
it uses a different top and proves the guard behavior, but cannot be counted as
an integration raw-coverage hit. The earlier complete frozen-SKU raw reports
remain in their own scope; do not compare the targeted three-test percentages
as if they were a replacement full-suite regression.

## Remaining exact items

| Bin / source | Status | Rationale / next action |
| --- | --- | --- |
| `thermo5_dpd_axi_lite_cfg` line 88 tuple `(!bvalid, aw_pending||aw_take, w_pending||w_take)=(0,1,1)` | Exact waiver recorded | Actual-RTL VC Formal property `a_line88_tuple_unreachable` is proven. Supporting property confirms BVALID is reachable (non-vacuous). Only this exact condition tuple is waived in `docs/evidence/THERMO5_AXIL_COVERAGE_WAIVERS.csv`; raw URG remains unchanged. |
| Line 315 tuple `(cfg_req_sync2,cfg_pending_valid,boundary)=(0,1,1)` | OPEN; no waiver | Matching-source VC Formal returned `inconclusive(depth=10)` for both the tuple and the supporting `pending_valid -> req_sync2` invariant. This is not proof of unreachability. Independent-reset behavior still needs a defined integration contract and targeted test. |
| Line 315 tuple `(1,0,1)` | Covered by legal external stimulus | UVM with legal RUN/COMMIT, one-cycle AW/W delays, early B response acceptance, and AXI clock phase sweep hit the tuple in 15/20 runs; matching URG condition row is Covered. No DUT state was forced. |
| Write-case `default` branch | Interface-unreachable candidate; not yet waived | Unsupported addresses are assigned DECERR before the sequential OKAY-only write case; all valid write addresses map to explicit cases. Preserve raw bin until a checksum-bound waiver is reviewed. |
| Initial invalid-parameter branch in the integration merge | Separate negative test PASS; not in integration VDB | The valid integration elaboration fixes `DPD_MAX_TAPS=4`; the separate top verifies both illegal values. Keep the integration raw metric honest. |
| AXI-Lite coefficient toggles | Functional transport PASS; VCS toggle bins OPEN | The matching VCS merge of the positive config test plus the 20-run boundary sweep confirms all six 64-bit shadow banks toggle both directions, but `cfg_mailbox_q[383:0]`, `cfg_pending_core[383:0]`, and `cfg_active_core[383:0]` were constant in that database (module toggle score 20.52%). A new legal payload test now checks mailbox/pending/active transfer and reset restoration in XSim for generic and XPM; XSim does not provide the VCS URG toggle-bin result. Re-run the new test under licensed VCS and merge its VDB before closing code-toggle bins. |

The exact line-88 waiver is a reviewed disposition, not a raw URG exclusion.
The raw report retains the uncovered tuple; no adjusted percentage is claimed.
Function coverage is not code coverage. The broader frozen thermo5 RTL still
has reachable high-order counter toggles and generic/XPM-specific gaps
documented in `thermo5-coverage100-assessment.md`; blanket raw 100% is not
achieved.

## Legal external boundary-bin search (2026-10-12)

Added `thermo5_sku_axil_boundary_phase_test` in
`dv/uvm/tests/thermo5/thermo5_sku_axil_config_test.svh`. It issues a legal
RUN+COMMIT through the AXI-Lite agent after observing a public DPD frame-start
handshake; it varies AXI AW delay, transaction offset, and (for exploratory
runs) source-valid bubbles and asynchronous clock phases. It does not force or
deposit into DUT state. Every checked trial completed the 56-word,
four-plane bit-true scoreboard with zero UVM errors/fatals.

| Search | Trials | Result | Evidence |
| --- | ---: | --- | --- |
| Original offset/AW/clock-phase search | 186 | All bit-true PASS; target not covered | `runs/thermo5_axil_boundary_phase_generic_20261012/` and focused subdirectories |
| RUN-relative delay / source-phase / AXI-phase / fine-phase searches | 255 | All bit-true PASS; target not covered | `runs/thermo5_axil_boundary_earlycommit_generic_20261012/`, `...sourcephase.../`, `...axilphase.../`, `...finephase.../` |
| Legal early-B response + AW/W gap 1 + AXI phase 0–9.5 ns in 0.5 ns steps | 20 | All 56-word bit-true PASS; trace hit `(1,0,1)` in 15 runs; URG reports Covered | `runs/thermo5_axil_boundary_bready_gap1_20261012/` |

Total: 461 passing legal matrix trials. Every trial completed with zero UVM
errors/fatals and all 56 four-plane words matching the bit-true oracle. The
earlier 16-cycle source pause before beat 8 triggered the expected
early-FIFO-starvation checker and is excluded from the passing count. The new
run varied legal AXI response-ready timing plus AW/W gaps and phase; no DUT
state was forced.

Matching-source formal evidence is in
`runs/thermo5_axil_cfg_formal_coverage_20261012/`. It proves only the exact
line-88 tuple; the line-315 `(0,1,1)` candidate and the supporting pending/request
invariant are inconclusive at depth 10 and remain OPEN. The exact line-88
waiver is recorded separately; the raw URG database/report is not modified.
Coefficient payload transport toggles, frozen-SKU counter bits31:23, and
XPM/FWFT bins remain independent OPEN workstreams and are not included in the
461 phase trials.

To replay the main AXI/AW sweep after compiling the generic AXI-Lite top:

```sh
bash dv/uvm/sim/run_axil_boundary_phase_sweep.sh runs/thermo5_axil_boundary_phase_generic_20261012
```

The original sweep scripts retain their nonzero closure gate when URG reports
the target uncovered. The follow-up replay that now closes `(1,0,1)` is
`bash dv/uvm/sim/run_axil_boundary_bready_gap_sweep.sh`; it requires both a
public-stimulus trace hit and the merged URG row to report Covered.

The later focused schedule sweeps are replayed with
`run_axil_boundary_earlycommit_sweep.sh`,
`run_axil_boundary_earlycommit_sourcephase_sweep.sh`,
`run_axil_boundary_earlycommit_axilphase_sweep.sh`, and
`run_axil_boundary_finephase_sweep.sh`. They document the earlier failed
search; the final successful search is the BREADY/AW/W-gap script above.

## Legal coefficient-payload CDC exercise (2026-10-12)

Added `AXIL_COEFF_TRANSPORT` mode to
`thermo5_sku_axil_config_test`. It keeps only tap 0 active with the identity
coefficient, writes nonzero values into inactive taps 1..3 through legal AXI
register transactions, commits the complete image, and checks the exact
mailbox, core-pending, and core-active payloads. After the stream drains, the
public reset is checked to restore all three payload banks to the documented
identity default. The four-plane 56-word scoreboard still matches the frozen
MATLAB oracle, confirming that the inactive coefficient taps do not alter the
selected one-tap data path.

| FIFO implementation | Seed | Result | Evidence |
| --- | ---: | --- | --- |
| Generic | 435505 | PASS; zero UVM errors/fatals; 56 output words bit-true | `runs/thermo5_axil_coeff_transport_xsim_generic_retry4_20261012/console_xsim.log` |
| XPM | 435506 | PASS; zero UVM errors/fatals; 56 output words bit-true | `runs/thermo5_axil_coeff_transport_xsim_xpm_retry1_20261012/console_xsim.log` |

The unmodified legal two-tap configuration mode was rerun after the testbench
changes and also passed for generic seed 435507 and XPM seed 435508; logs are
under `runs/thermo5_axil_config_xsim_generic_retry1_20261012/` and
`runs/thermo5_axil_config_xsim_xpm_retry1_20261012/`.

The run script accepts `-CoefficientTransport` for replay. A testbench-only
compatibility guard was also added for the different `uvm_hdl_release` API in
Vivado's no-DPI UVM build.

## Licensed VCS/URG coefficient-payload rerun (2026-10-12)

The VCS license setup is sourced by the interactive Rocky shell. A non-
interactive login-shell attempt did not inherit that environment and stopped
at license discovery; the interactive-shell retry compiled and ran VCS
V-2023.12-SP1 successfully. Generic seed 435509 and real Vivado XPM seed
435510 both passed `thermo5_sku_axil_config_test +AXIL_COEFF_TRANSPORT` with
zero UVM warnings/errors/fatals, exact mailbox/pending/active payload checks,
reset restoration, and 56 four-plane bit-true words.

The test-specific URG reports are under
`runs/thermo5_axil_coeff_vcs_generic_20261012/coverage/` and
`runs/thermo5_axil_coeff_vcs_xpm_20261012/coverage/`. Both report the
`thermo5_dpd_axi_lite_cfg` module at line98.12%, condition95.95%, toggle78.49%,
and branch95.00%. The report confirms both directions for the upper48-bit
slices in each 64-bit coefficient bank. The lower16-bit slices remain Not
Covered in all four image stages (`cfg_mailbox_q`, `cfg_pending_core`,
`cfg_active_core`, and `cfg_for_dpd`): the test preserves tap0 identity/zero
coefficients and only varies inactive tap slots1..3. Thus legal bundled-data
transfer is functionally verified, while complete raw coefficient toggle
coverage remains OPEN. No coefficient toggle bins were waived.

## Synthesis checkpoint evidence

The 2026-10-12 OOC synthesis attempts targeted
`tid32_thermo5_axi_lite_axis_frontend_tx` on
`xczu15eg-ffvb1156-2-i`, core 218.75 MHz, AXI-Lite 100 MHz,
`INTERP_TAPS=2`, `DPD_MAX_TAPS=4`, XPM FIFO. Vivado generated
The initial attempt generated
`runs/thermo5_axil_covclose_synth_20261012/synthesized.dcp` (56,924,304 bytes)
and `synth_utilization.rpt`. A second clean-output attempt generated
`runs/thermo5_axil_covclose_synth_retry_20261012/synthesized.dcp`
(56,925,518 bytes), `synth_utilization.rpt`, and `clocks.rpt`.
An independent Vivado process reopened the retry checkpoint, restored timing
and constraints, generated `checkpoint_validation_utilization.rpt`, and exited
0 (`checkpoint_validation.log`).

Synthesis resources from the retry report: 71,537 CLB LUTs, 52,255 registers,
1,936 DSP48E2, 334.5 BRAM tiles. Both top-level invocations returned nonzero
with `Failed to load feature 'vivado'` after checkpoint/report creation. The
independent checkpoint reopen passed, so the netlist artifact is readable, but
the flow-wrapper exit issue remains unresolved. This is not routed
implementation or timing signoff: no routed checkpoint, WNS/WHS, or parent
I/O constraints were produced.

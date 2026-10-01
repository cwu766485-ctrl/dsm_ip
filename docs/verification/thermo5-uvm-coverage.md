# Thermo5 UVM verification and coverage boundary

Date: 2026-10-01. Frozen configuration: thermo5, two-tap interpolation,
one-tap identity memory-DPD, 125-MHz 14-complex AXI ingress, 218.75-MHz core,
four 64-bit output planes. VCS UVM uses the portable generic FIFO.

## Ownership

- `thermo5_source_sequence` reads the MATLAB vectors and issues AXI beat items.
- `thermo5_source_agent` drives valid/data and independently monitors accepted
  handshakes and source stability. Its monitor alone updates accepted-beat
  count and publishes input transactions.
- `thermo5_control_bfm` owns reset, core enable, and common-plane ready.
- `thermo5_pa_monitor` publishes accepted four-plane words and checks stalls.
- `thermo5_pa_scoreboard` compares both monitor streams to the fixed MATLAB
  input/PA vectors. A core-reset assertion starts a new comparison epoch;
  tests never rewrite scoreboard indices.

## Test-to-check closure

| Test | Required checker/event | Functional coverage |
| --- | --- | --- |
| Bit-true plus PA stalls | 32 input beats, 56 four-plane words, exact MATLAB comparison, held output under stall, no early underflow | Three frame starts, PA word and PA stall bins |
| FIFO boundary | Source stable while full/backpressured; full 32/56 replay | Full and source-stall bins |
| FIFO empty | Four beats produce seven matched words, then sticky underflow without frame error | Underflow bin |
| Midstream reset | Partial 24-beat epoch discarded; fresh 32/56 bit-true replay | Reset reassertion and scoreboard epoch |
| Residual reset sweep | Reset at CDC residuals 2/4/6/10/12; fresh 32/56 replay | Five reset epochs; CDC FSM transitions |
| Illegal frame | Misaligned frame-start RTL assertion plus sticky protocol error; no PA golden expected | Protocol-error bin |

Each positive test requires zero UVM errors/fatals and its completion marker.
The illegal-frame test requires the precise RTL assertion and UVM observation
marker; it is intentionally not a clean positive simulation.

## Current measured result and open bins

Licensed VCS six-case regression and URG merge pass. Functional covergroups:
100%; total code-coverage score: 86.59%; line 86.85%, condition 72.54%,
toggle 83.90%, branch 72.33%, FSM 100%, assertion 90.48%. The CDC
`rem_count_q` FSM has 7/7 states and 12/12 transitions after correcting the
reset edge in the control BFM. These percentages are tool scores, not a claim
that every RTL behavior is verified.

The lowest reviewed module-level condition/toggle figures include
`dpd_memory_poly` (44.44% condition, 56.31% toggle), consistent with the
identity-only DPD configuration; this is a triage lead, not an automatic
waiver. Other unhit condition/branch/toggle bins need line-level URG review
and either legal stimulus, proof of configuration exclusion, or a justified
waiver. No blanket exclusion is applied here. The VCS UVM filelist does not
elaborate XPM FIFO or physical GT/PA. Separate full-chain XSim runs with
vendor XPM FIFO and PA stalls passed seeds 7/8/9; they are not merged into
the VCS UVM coverage score.

Initial line-level URG triage (no exclusion applied):

| RTL location | Unhit event | Classification and next check |
| --- | --- | --- |
| `tid32_thermo5_axis_frontend_tx.sv:54,58` | Ingress valid/ready while low-power ingress is disabled | This SKU elaborates with low-power control disabled; confirm static parameter pruning before a configuration-specific waiver. |
| `dsm_interp_x2_polyphase_vector.sv:70` | Stage-2 invalid while stage-3 not ready | Reachable bubble/backpressure combination; add a targeted ready/bubble test before waiver. |
| `dsm_interp_x2_polyphase_vector.sv:225` | Reset low with `enable` high | Current control BFM disables core during reset. Check whether the RTL permits this combination before classifying it as illegal. |
| `dpd_memory_poly.v:140` | `out_ready=0` while the last pipeline valid is zero | Idle/backpressure combination; add targeted control stimulus if legal. |
| `dpd_memory_poly.v:336` | Saturation flags under valid output | Current identity coefficients and OFDM vectors do not hit saturation; use a separate legal stress vector and oracle rather than changing the frozen bit-true gate. |
| `dpd_memory_poly.v` input toggles | `active_taps` and coefficients do not toggle | Fixed DPD1 identity settings by SKU contract; require a separate programmable-DPD target, not artificial toggles in this test. |

The remaining URG holes must be triaged at the instance/bin level before
calling code coverage closed. Functional event closure alone does not justify
waiving all condition or branch misses.

## Targeted reachable-bin follow-up (2026-10-01)

Two separate block-level VCS/URG tests now exercise legal states without
changing the frozen 32-beat/56-word thermo5 oracle:

| Frozen-SKU URG lead | Directed evidence | Disposition |
| --- | --- | --- |
| Interpolator line 70: `!s2_valid && !s3_ready` | `tb_interp_x2_vector_reachable` reaches it four cycles; all three feasible URG condition rows for line 70 are green. Twelve 2-tap output words match an independent half-sample oracle, including five stalled cycles. | Reachable at the block boundary; tested separately. The active thermo5 frame still forbids ingress bubbles, so do not merge this block VDB into its UVM score. |
| Interpolator line 225: `!rst_n && enable` | The same test holds `enable=1` during three reset clocks; reset takes priority and the subsequent output sequence matches. | Legal at the interpolator block; the full-chain control BFM deliberately lowers core enable on reset. No full-chain claim. |
| DPD line 140: `out_ready=0 && !out_valid` | `tb_dpd_memory_reachable` reaches 15 empty-pipeline blocked cycles; URG marks all three feasible line-140 condition rows green. | Reachable and tested in an isolated one-tap DPD. |
| DPD line 336: valid saturated I/Q | Programmable Q2.14 `c1_re=32767` produces five saturated words; positive/negative I and Q limits, six output words, order, sample count, and stall behavior are checked. URG marks valid/non-saturated and valid/saturated rows green, and both I-only and Q-only saturation rows green. | Tested only with a non-identity coefficient. The frozen identity-DPD SKU still has no saturation event. |

Reproduce with `LM_LICENSE_FILE` and `VCS_HOME` supplied externally:
`bash dv/verif/block/run_reachable_coverage_vcs.sh`. The test requires both
PASS markers, rejects simulator fatal/error text, and writes separate reports
under `runs/uvm_thermo5_i2_d1/reachable_{interp,dpd}/coverage/`. Neither VDB
is combined with the six-case thermo5 UVM database; its 86.59% score is
unchanged. No RTL or MATLAB numerical behavior changed.

Configuration-limited holes are assessed individually, not bulk-waived:

| Item | Elaboration/contract evidence | Scope decision |
| --- | --- | --- |
| Top ingress lines 54/58, low-power-off branch | `thermo5_sku_uvm_tb.sv` does not override `ENABLE_LOW_POWER_CTRL`; the top parameter defaults to zero, so `!ENABLE_LOW_POWER_CTRL` is constant true and the disabled-ingress choice is not elaborated in this SKU. | Excluded by this precise SKU parameter, not by DUT-wide waiver. A separate low-power-on target must verify ingress gating and prefill/drain. |
| DPD `active_taps` and coefficient input toggles | The UVM top ties `active_taps=1`, `c1_re=16384`, and every other coefficient to zero. The compiled DPD remains present (`BYPASS_DPD=0`), but these configuration pins cannot toggle in this instance. | Excluded only from fixed-SKU toggle expectations. A programmable-control target is needed before claiming runtime coefficient/tap coverage. |
| DPD valid-output saturation in thermo5 | Unity Q2.14 one-tap gain and the frozen vectors are bit-true identity; output saturation would require a different legal coefficient or altered samples. The isolated stress test changes only that block's coefficient. | Do not claim saturation covered by the UVM frozen SKU or an RF/DPD improvement. |
| DPD line 336 `!valid_pipe[last] && (sat_i || sat_q)` | Still red in the isolated URG result. The payload arithmetic may toggle while its valid bit is low; this is not an accepted output transaction. | Remains open for line-level reachability analysis; no waiver applied. |

The directed tests close the named reachable protocol/saturation leads at
block scope, not all remaining condition, branch, toggle, XPM, or GT coverage.

Additional VCS PA-stall and FIFO-boundary tests passed seeds 11 through 20
(20 simulations). The fixed MATLAB vectors remain unchanged across those
seeds; the random ready schedule varies. Therefore this is handshake stress,
not independent OFDM payload-seed coverage.

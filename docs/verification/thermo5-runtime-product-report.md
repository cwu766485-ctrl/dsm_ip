# Runtime DSM product integration report

Date: 2026-11-17 SGT. Candidate branch: `work/thermo5-runtime-product`.
Base: `599959a9ed84eeefb24354df88d0f5296178ecef` (remote thermo5).
Implementation revision: `7fe5bbb0c5e2ee35062ef797a18b73b3c9771bf5`.
Evidence hashes are recorded in `data/thermo5-runtime-product-summary.json`.

## Scope and first faults

The screenshot's BUBBLE_COVERAGE failure was a missing scenario witness, not
evidence of PA data corruption. Centered interpolation can legally assert
`!out_valid && !out_ready` while discarding a tail. At the direct/debug-VCD
witness time **1360170 ps**, interp2 q_count=2, head tail/end=1, downstream FIFO
occupancy=2, input valid/ready=1/1, output valid/ready=0/0, PA ready=1110.
The name does not mean that the internal queue is empty. The test now legally
holds this event with partial ready, counts the coincident witness, retains
all prior fatal requirements, and compares all 56 words against the independent
four-plane oracle. The optional non-AXI-Lite VCD reference to `dut.u_cfg` was
incorrect and is now guarded. Optimized VCS VCDs had misleading internal
occupancy values; `-debug_access+all` and a direct sampled structural assertion
bind the physical witness. No condition was deleted to make coverage pass.

The separate local PowerShell fault was the last line of the profile:
`. (Join-Path $PSScriptRoot "Microsoft.PowerShell_profile.ps1")`.
It recursively loaded itself. Only that line was removed after byte-exact
backup. Real profile startup and both `love`/`official` functions passed.
The profile and private configuration are outside project Git. Local backup
and SHA256 are under `runs/thermo5_runtime_product_preservation/` in the IDE root.

The original MASH QAM root causes were already isolated on preserved branch
`work/thermo5-mash-qam-root-cause`, revision
`964ed986c3ae4811ccb92b2f5beae21bbc5aabda`: incorrect x-q1 Stage2 drive and q1
accepted-stream alignment, plus an undeclared receiver FFT offset. Stage1 was
bit-true across all 168224 original Cartesian samples; changing Stage1 was not
the fix. This change promotes the corrected accumulator-residue/companion
implementation into canonical RTL, without merging the unrelated experimental
branch or changing the old Golden. The original failed 3004-beat/5257-word run
and its raw PA, VCD, source and SHA256 remain intact.

Code locations (candidate revision):

| Location | Role |
|---|---|
| `dv/uvm/tests/thermo5/full_ip/thermo5_sku_bubble_backpressure_test.svh:86` | Legal targeted partial-ready stimulus |
| `dv/uvm/tb/thermo5_sku_uvm_tb.sv:255` | Direct queue/FIFO witness, bound to sampled signals |
| `rtl/tx_bandpass_if/thermo5_mash_cartesian_stage.sv:83` | Centered accumulator error, not x-q1 |
| `rtl/tx_bandpass_if/thermo5_mash11_core.sv:111` | Stage2 consumes accumulator residue |
| `rtl/tx_bandpass_if/thermo5_mash11_core.sv:91` | q1 companion follows Stage2 accepted order |
| `rtl/axis/dsm_xpm_async_fifo.sv:74` | Enable the read count required for XPM startup |
| `rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv:426` | Locked core idle decision and backend reset |
| `dv/uvm/refmodel/python/thermo5_runtime_qam.py:16` | Explicit 528-source-sample FFT contract |

`data/thermo5-bubble-witness.csv` is independently extracted from the debug VCD
immediately before the edge, matching posedge monitor sampling before NBA updates.

The preserved failure's first mathematical mismatch is Stage2
`dut.u_mash_backend.g_weighted_mash.u_mash_adapter.u_core.residual_i_vec[15:0]`,
transaction0/I lane0 at **262890 ps**: historical +32767, scalar accumulator
error -32768. Historical source is
`research/thermo5_weighted_mash/rtl/tx_bandpass_if/tid32_mash11_fs4_multipa_tx.sv:126`
on the preserved root-cause branch. The first separate bubble-alignment fault
was PA word489, epoch1 at **4181094 ps**. Both fixes are now in the canonical
files above. The earlier VCD/scalar witnesses and all failed runs remain on
that branch, with the original raw capture hashes:

- PA0: `371b78ed29ae8854f0c470b8b6d8304840a388c166bdc443569d8d2cb756805a`
- PA1: `54f32d484aea866bff9c3da20615dd65e79a3417b0a0acbeb03f49a034790656`

Historical same-input receiver isolation (prior closure, not a new measurement):

| Path | Contract source offset | EVM |
|---|---:|---:|
| A ideal Fs/4, actual frontend, no DSM | 0 | 2.354286% |
| B scalar Stage1 | 0 | 12.002773% |
| C actual RTL Stage1 | 256 | 12.002773% |
| D historical RTL MASH, offset corrected only | 528 | 13.145892% |
| D corrected RTL MASH | 528 | 2.551442% |

Original unaligned D: 99.994117% EVM. New canonical runtime D repeats the
2.551442% result from actual PA words. Stage1's 12% matches scalar and is not a
bit-true defect. The prior timing report is
`docs/verification/thermo5-mash-timing-alignment-20261117.md` on the preserved
root-cause branch; its 66-word/528-source-sample contract is explicit here.

## Additional confirmed XPM startup defect

The stronger PA-pending reset setup exposed a product defect that the earlier
STOP-at-beat16 tests bypassed. At 10300ns after seven completed streams, software
RUN=1 and architecture=MASH, source stalled at beat17, PA valid=0, all frontend
valids=0, core_prefill_seen=0 and core_prefill_ready=0. The source FIFO was
blocked with queued data, yet read count was zero and core_datapath_enable=0.
`runs/runtime_reset_probe/probe3.log` independently reads the actual hierarchy.

`rtl/axis/dsm_xpm_async_fifo.sv` had `USE_ADV_FEATURES="0000"`, disabling the
read-data count that `dsm_axis14_to_core8_cdc.sv:122` now uses for prefill.
The installed AMD XPM source defines EN_RDC=USE_ADV_FEATURES[10] and explicitly
drives rd_data_count=0 when disabled. The localized fix enables only bit10
(`0400`); FIFO width, depth, resets and pointer/data ownership are unchanged.
Before the fix, `runtime_reset_bounded` fails RESET_SOURCE_TIMEOUT. Earlier
XPM tests passed because issuing STOP let core_draining bypass prefill, so they
are retained as narrower evidence and do not establish independent RUN startup.
The corrected test requires blocked PA before reset, with no STOP escape.
Final fixed-source replay and synthesis status are recorded in the summary.

## Product behavior

See `../spec/thermo5-runtime-dsm.md` for the complete register and PA contract.
The canonical runtime top and existing AXI-Lite top with ENABLE_RUNTIME_DSM=1
share one frontend. Reset defaults to EF2. Separate EF1, EF2 and corrected MASH
backends hold inactive state in reset. STOP/drain, a source lock acknowledgment,
an idle decision, backend reset and acknowledged readback govern handover.
Queued prefill rejects a request without losing data. Architecture and DPD
mailboxes remain distinct. Source-domain AXIS admission freezes during handover.

Runtime UVM adds an independent PA monitor and scoreboard. Expected words come
from separate scalar EF1/EF2/MASH models; expected mode/config follows the test's
software operations, not DUT outputs. The scoreboard checks every active bit,
inactive MASH data, channel/weight contract, frame metadata and config ID.
Stall checks include data and metadata. The sequence traverses all six directed
mode pairs and tests queued-prefill rejection, RUN-busy/live/draining rejection,
AW/W skew, B backpressure, WSTRB no-op, STOP/restart, 400-cycle output blockage,
partial ready and reset followed by default-EF2 replay. A strengthened reset
replay waits for blocked MASH PA data before asserting the paired resets.

## Verification status

Results and artifact hashes follow in the evidence summary. Only completed,
explicitly marked checks are PASS. Initial VCS attempts were license-blocked. A final retry obtained a license:
the required six legal tests and one expected-negative test PASS, both runtime
Generic/XPM UVM suites PASS, and the existing static AXI-Lite config test PASS.
The static test checks the unchanged 0x54483501 ID and coefficient mailbox. Vivado XSim runs the actual UVM monitor/scoreboard, not a substituted
behavioral DUT. The old directed XSim runner needed explicit executable launch
and its causal interpolation hierarchy probes updated before it could run.
Python reference tests: 66/66 passed. No MATLAB algorithm was changed.

Runtime QAM uses the original seed281001 RMS0.09 OFDM and unchanged receiver.
The full 42056-sample I/Q prefix matches preserved failed input sample-for-sample;
only 56 trailing zeros meet the formal 32-beat packet quantum. No nonzero sample,
Golden, EVM gate or alignment search is changed. MASH CP/FFT starts at the audited
528-source-sample offset. EVM <=3.5% and SNDR >=29.12 dB gates remain fixed.
Seed281001 gives EVM **2.551442%**, SNDR **31.864285 dB**, uncoded natural-binary
BER **15/37376 = 0.000401327** from actual canonical runtime PA capture. This is
a digital link measurement; scalar gain fitting and BER mapping follow the
existing receiver. Seed281004/32-symbol input is rejected by the unchanged
0.35 peak guard (peak0.355822); it is recorded as INPUT_REJECTED, never PASS.

| Canonical runtime PA experiment | EVM RMS | SNDR | Uncoded natural-binary BER |
|---|---:|---:|---:|
| seed281001, 8 symbols, Generic | 2.551442% | 31.864285dB | 15/37376 |
| seed281001, 8 symbols, corrected XPM | 2.551442% | 31.864285dB | 15/37376 |
| seed281002, 32 symbols, Generic | 2.510098% | 32.006187dB | 36/149504 |
| seed281003, 32 symbols, Generic | 2.529758% | 31.938422dB | 48/149504 |

Unique-seed total: 99/336384 bit errors (0.000294306); the repeated XPM capture
is not counted as new independent BER samples. Each long run also completes all
six directed architecture switches and eight checked streams (152768 accepted
PA words per 32-symbol run). Generic and corrected XPM PA0/PA1 match every bit
for all 5264 words of seed281001; phase1 and phase3 MASH replay also match exactly.
The fixed-source short suites check 448 words each; Generic reports6/6 mode pairs,
738 stalls/188 partial stalls, and XPM reports6/6,728 stalls/187 partial stalls.
The stronger XPM reset observes32 source beats, PA_VALID=3, ready=0 and active=1
before reset, then a fresh default-EF2 replay. No source/PA overflow or protocol
error is reported by the finish checks.

Fixed-source XPM synthesis PASS on ZU15EG: **92144 LUTs, 74767 FFs, 670 DSPs,
6.5 BRAM tiles**, with no latches or black boxes. The checkpoint and utilization
report are SHA256-indexed. The final log still records one worker-plugin load ERROR. The vendor tool then
explicitly reports single-core fallback, completes synth_design and writes the
DCP. The summary classifies this as PASS_WITH_RECOVERED_WORKER_ERROR rather
than an error-free tool log. Earlier stalled plugin attempts remain preserved.
No clocks/routing are constrained by this synthesis-only study, so it proves
elaboration/mapping and resource use, not a frequency or physical timing limit.
The existing static AXI-Lite OOC flow was attempted and fails its post-synthesis
exact-top-name assertion; that flow is FAIL, not timing PASS. No routed timing
was run. The required directed XSim Generic and XPM smokes pass after the
explicit launcher and stale causal hierarchy probe fixes.

The licensed CI workflow now includes both runtime FIFO implementations and
archives PA captures; hosted syntax/reference checks also include the new
Python tools. Workflow YAML parsing and whitespace checks pass locally. Remote
CI is separate from these local results.

## Remaining signoff boundaries

Runtime selection is a canonical, synthesizable digital configuration; it is
not a claim of routed full-top or physical RF signoff. Complete code/functional
coverage, new CDC/RDC/Formal closure, independent
live resets, VCU118 full-top routed PPA, weighted PA board routing and two
14-Gb/s GTY serializers remain separate work. Existing EF2 OOC timing cannot
be reused as runtime full-top/GTY signoff. Output transactions may contain
bubbles under backpressure; a physical serializer requires its own continuity
and underflow contract. No waiver or threshold relaxation is introduced.

## Reproduction

Use the exact commands in `../ai-native/commands.md`, section Runtime EF1 / EF2 /
MASH product. Raw artifacts remain below the candidate worktree's ignored
`runs/`; small reviewable summaries and SHA256 are tracked. Preserve all failed
launcher/compiler/license logs alongside successful reruns. No cleanup command
was run. The root IDE's six pre-existing uncommitted files are preserved with retained
stash `48ef33fb61069cb306b9af0eb5d8ed68eaed04a5` and a byte-exact backup; their
additions are restored as uncommitted work after integration.

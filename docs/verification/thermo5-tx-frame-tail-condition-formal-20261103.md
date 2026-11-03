# Thermo5 TX Frame-Tail Condition Formal Review

Date: 2026-11-03  
Verification source SHA: `2715b7a99042b3cd261884e53a82f287fe243ec6`  
Product RTL SHA: `1236d49c72360aa62e316aea147528d93a1b3705`  
Parent review base: `938176bb3e3c9850085889602306c1b861df8e76` (PR #35 head)  
Product configuration: Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 /
20-bit state, 32 chronological lanes, DPD_MAX_TAPS=1 with Identity reset
image, AXI-Lite, Generic FIFO.

## Scope and result

This focused Linux Formal run examined the three OPEN Condition records for
`rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:309`. Product RTL, DSM
algorithm, VCS Raw VDBs, URG inputs, and coverage denominators were not changed.

The two reset-low operand records are proven unreachable in the product stage
geometries: a non-vacuous runtime-reset proof first reaches a two-entry queue,
then asserts reset on the inactive clock edge, observes the cleared queue, and
finds the exact `rst_n=0, q_count=2, q0_end=1, q1_start=0` Cover uncoverable.

The stage-2 active operand record is a waiver candidate supported by a
non-vacuous proof over the directly composed production interpolation stages.
The source schedule follows the published TX contract: seven 8-lane vectors per
56-sample DSP frame, eight frames per 448-sample / 32-beat packet, and `TLAST`
only on the packet's 56th stage-1 vector. Stage 1's actual `out_frame_start`
and `out_tail` drive stage 2; output backpressure is composed across both
stages and source gaps are unbounded. The two exact active-condition Covers are
uncoverable while legal subframe-start, packet-end, tail-transfer, tail-drop,
and output-transfer Covers are reached.

The formal composition omits the product's two intervening registered
elastic FIFOs and the 11-stage DPD arithmetic pipeline. Their source wiring
passes the `{tail, frame_start}` metadata through in order, and existing
system-level bit-true tests exercise the path, but this Formal run does not
prove those intermediate blocks compositionally. Therefore all three records
remain visible and OPEN in the Raw coverage ledger pending independent
waiver review. No `.el` exclusion is generated. Approved waivers remain zero;
Raw equals Adjusted and the gate stays `RAW_100_OPEN`.

An earlier exploratory harness modeled `frame_end` at every 56-sample frame
boundary. Review against the TX contract showed that `frame_end/TLAST` belongs
at the 448-sample packet boundary instead. That run is superseded and is not
used as evidence here; the final harness uses the corrected schedule above.

## Exact Raw records

| Semantic Bin | Raw Bin | Instance | Raw operands | Formal evidence | Current treatment |
|---|---|---|---|---|---|
| `TXB-8ed12996edaade43bb74` | `8f6d3ab31932cb2fac24` | `g_interp1_centered.u_interp_1` | `309:0/1/1/1` | `a_append_reset_empty` proven non-vacuous; queue-full, runtime-reset and reset-empty Covers reached; exact reset Bin Cover uncoverable | `PROVEN_UNREACHABLE` evidence; Raw row retained; waiver review pending |
| `TXB-1a3c01edbe1a6cdf4f0f` | `622fb84f8bc9af1ca577` | `g_interp2_centered.u_interp_2` | `309:0/1/1/1` | `a_plain_reset_empty` proven non-vacuous; queue-full, runtime-reset and reset-empty Covers reached; exact reset Bin Cover uncoverable | `PROVEN_UNREACHABLE` evidence; Raw row retained; waiver review pending |
| `TXB-e04591df73cbd238b0f0` | `2aef3ac569e044b8a469` | `g_interp2_centered.u_interp_2` | `309:1/1/1/1` | Both composed-stage frame-end assertions proven non-vacuous; exact stage-2 active Bin Cover uncoverable; legal packet/frame/tail/output Covers reached | `WAIVER_CANDIDATE`; Raw row retained pending review of omitted FIFO/DPD composition |

For completeness, the composed proof also found the corresponding stage-1
active Cover uncoverable. There is no matching stage-1 active record among the
three current Raw records, so it is not added to the waiver inventory.

## Formal evidence

Tool: VC Formal V-2023.12-SP2 for linux64 (Jun 03, 2024); zero black boxes and
zero selected clock, glitch, loop, or multidriver setup violations. The
committed verification tree was clean at run time. Exact commands:

```bash
PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH \
python3.12 dv/uvm/formal/run_thermo5_scoped_formal.py \
  --jobs frame_tail_legal_metadata frame_tail_reset_condition \
  --out-dir runs/thermo5_tx_closure_current/frame_tail_composed_formal_20261103_rerun
```

| Job | Result | Assertions | Covers |
|---|---|---:|---|
| `frame_tail_legal_metadata` | PASS, 28.61 s | 2/2 proven, both non-vacuous | 6 covered, 2 exact active-condition Covers uncoverable |
| `frame_tail_reset_condition` | PASS, 21.46 s | 2/2 proven, both non-vacuous | 6 covered, 2 exact reset-condition Covers uncoverable |

The reset proof uses an initial `boot_n` reset and an unconstrained runtime
reset request sampled on the falling edge. The active-edge collision is
excluded, as in the repository reset Formal scope. It has no data, stream,
queue-state, or reset-occurrence assumption. The metadata proof's only
environment assumption is source `VALID` stability under backpressure; it is
reported non-vacuous. Both stages use the product parameters: stage 1
W=16/LANES=8/APPEND_TAIL_VECTOR=1, stage 2
W=16/LANES=16/APPEND_TAIL_VECTOR=0.

The runner's compact result and all logs remain locally under the ignored
`runs/thermo5_tx_closure_current/frame_tail_composed_formal_20261103_rerun/`
directory. SHA-256:

| Artifact | SHA-256 |
|---|---|
| `formal_summary.json` | `977661d358c45d5f5a2844fb10ce0f6cabd8ad2fafc0d8a5c7b1ffe075e89127` |
| metadata `console.log` | `637fb8f91f022e5fe949ea9add094b89ff84abbbc6fd68563f0040fdf6a7ae34` |
| metadata `setup.txt` | `9179ff820f8ccd52c831980266a856fb521fc62364086ba3188857dd4aa5685a` |
| metadata `properties.txt` | `dc988149e8283051366d629b41e1c45f68bc9faa76a14b9d63c44bedb6b2847a` |
| reset `console.log` | `b87e3a3b47a3061d6e94febcdda5c6d01a09d9c0e8e9ef711788a08e07d69c04` |
| reset `setup.txt` | `9179ff820f8ccd52c831980266a856fb521fc62364086ba3188857dd4aa5685a` |
| reset `properties.txt` | `c21444d195bda95a1fb5a04d817217fb7eb4f790f2e97fb460b784df94caef1d` |

The complete source hash map, exact property names/states, timings, setup
results, configuration, and Raw-bin mapping are in
[`thermo5-tx-frame-tail-condition-formal-20261103.json`](data/thermo5-tx-frame-tail-condition-formal-20261103.json).

## Coverage and signoff impact

No VCS simulation, URG merge, Raw/Adjusted report regeneration, or waiver
pipeline approval was run in this follow-up. The previously established
247-test Raw/Adjusted snapshot remains unchanged: Branch 525/637, Condition
658/849, Line 3351/3796, Toggle 84340/104480, FSM 13/13 states and 17/22
transitions, legal applicable Functional Coverage 392/392. The gate remains
`RAW_100_OPEN`; approved waivers=0, active exclusions=0. These Formal findings
do not change any numerator or denominator.

Checks run on the verification source: Python 3.12 `py_compile`,
`git diff --check`, and the two targeted VC Formal jobs above. No product
regression was repeated because no RTL or test/VDB source was changed. The
source-bound outstanding-counter Formal remains INCONCLUSIVE (PR #36); those
two Branch bins remain OPEN. Remaining Condition, Line, Branch, Toggle,
waiver-review, assertion-audit, and full-chain identity-DPD work also remain
OPEN. XPM, GT Wizard, FPGA PPA, and physical RF/QAM256 validation remain
outside Linux signoff.

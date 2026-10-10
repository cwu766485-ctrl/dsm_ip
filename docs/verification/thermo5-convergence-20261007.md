# Thermo5 coverage convergence, 2026-10-07

Later same-build follow-up: `runs/thermo5_followup_long_20261007/evidence_index.json`
extends the stream to 131075 words and reports raw87.49%/80.27%, adjusted
99.64%/97.08% (generic/XPM). The figures below are this earlier 65541-word
checkpoint and remain valid only for its recorded source/binary/report set.

Updated: 2026-10-07 13:28 SGT. Status: PARTIAL_COVERAGE_CLOSURE_NOT_100.
Actual licensed VCS/URG and scoped VC Formal results are recorded below.
No production RTL, counter width, MATLAB arithmetic or vendor source was changed
for this convergence work. Generic and XPM cover different DUT hierarchies.

## Actual URG results

| FIFO | Same-build raw before | Raw after | Adjusted after | Line | Condition | Toggle | FSM | Branch | Assertion |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Generic | 87.01% | 87.49% | 99.63% | 99.84% | 100.00% | 99.42% | 100.00% | 98.51% | 100.00% |
| XPM | 79.96% | 80.26% | 96.40% | 99.17% | 90.96% | 99.44% | 96.77% | 92.06% | 100.00% |

The last six columns describe adjusted coverage. Adjusted means exact native
URG configuration/scoped-proof exclusions with instance checksums and signatures;
it does not mean simulation hit or complete signoff. Raw reports are preserved.
The prior CI raw score was 87.48%/80.26%; the fresh long stream adds counter hits
although the XPM composite score still rounds to 80.26%.

Evidence:

- Fresh compile baseline: `runs/thermo5_converge_release_20261007/manifest.json`;
  14 directed plus 6 independent-payload seed cases PASS.
- Same-binary before/after and 24 additional passing cases:
  `runs/thermo5_converge_long_20261007/closure.json` (6 generic, 18 XPM).
- Raw after: `runs/thermo5_converge_long_20261007/{generic,xpm}_coverage_after/`.
- Generic adjusted: `runs/thermo5_generic_delivery_exclusions_20261007/coverage/`.
- XPM adjusted: `runs/thermo5_xpm_widecond_exclusions_20261007/coverage/`.
- Provenance/checker/directional gates:
  `runs/thermo5_converge_long_20261007/evidence_index.json`.
- Exact raw ledger and adjusted remaining statements/conditions/signals:
  `runs/thermo5_converge_long_20261007/{ledger,remaining}/`.

Compiled RTL/DV source SHA256:
`b0fd1a726b8e9a994ea7d2079176362e53c4c6ee4142fb4c2e2134b736e98845`.
Each implementation reused one binary for all baseline and directed VDBs.
Manifest gates verify current RTL/formal/vendor hashes and native exclusion hashes.
No failed phase12 VDB, force/deposit, shorter counter or edited VDB is included.

## Coverage gap closure evidence

| Gap / unhit reason | Legal stimulus or exact proof | Independent checker | Matching URG / disposition |
| --- | --- | --- | --- |
| TID bit15: prior payload did not reach signed endpoint after interpolation/offset | Signed endpoints and held range-stress endpoint words, actual legal AXI ready/valid | MATLAB four-plane PA scoreboard | All 162 formerly missing TID rows hit both directions in each FIFO; raw delta CSV retained |
| DPD bit15/16: prior 16387-word stream below the carry boundaries | MATLAB 65541-word range_stress seed610701; 37452 accepted AXI beats; then public reset | All four planes match; all16 counters equal65541; saturation counters zero; checked reset clears all16 counters | 32 bit/lane entries hit both directions, 64 newly hit directions per FIFO; high-bit missing directions544 ->480 |
| Interpolation exact elastic condition | State/ready-driven interp1 empty-blocked test | Full independent output replay and completion/error gates | Exact condition deltas recorded in closure.json; generic condition coverage100% after reviewed exclusions |
| DPD identity saturation and saturation_count | Production pipeline bounds:19/20 assertions proven, including no-sat I/Q, sum bounds and count zero; no promoted assumption required for these proofs | Signed endpoint, stall and recovery covers; exhaustive prior scalar corroboration | Exact frozen-SKU saturation exclusions; full payload identity formal remains inconclusive |
| Interpolation valid two-tap saturation | 16 accumulator-bound assertions proven when s2_valid; five endpoint/stall/accept/output covers | Formal nonvacuity and setup/blackbox gates | Valid-payload proof only; four line/four branch bins retained because round_sat also evaluates invalid slots |
| XPM residual/default/high data | Actual full-width XPM CDC,7:4 clocks:7 assertions proven,9 covers hit, no blackboxes | Legal held source plus residual/stall/accept covers | Exact134 generic-to-XPM residual-related records eligible under the saved scope; not analog CDC/RDC signoff |
| Reset condition1/0 | Existing falling-edge reset scoped proof; normal covers reached | Reachability/vacuity audit | Scoped exclusion only; arbitrary reset-edge timing remains outside proof |
| XPM WRST_OUT/EXIT -> WRST_IN | Actual vendor reset controller,2 nonvacuous assertions proven,4 normal covers hit,2 reentry goals uncoverable when no new request before busy ends | State and recovery cover goals | Precisely two transitions and corresponding reset branch/line entries excluded under the legal contract |
| Frozen alternate taps, constants, parameter errors / XPM optional paths | Exact frozen elaboration/port/guard review, vendor source hashes | PASS baseline plus saved exact raw predicates/statements | Individual URG entries; vendor ownership alone never excludes a bin |

The independent long oracle took approximately54 minutes to generate in MATLAB.
The checked simulation commands took47.564s generic and46.442s XPM.
The oracle includes65541 I/Q vector words, frame metadata and four PA streams;
all eight files were complete and length-checked before simulation started.

## Remaining bins and concrete reasons

| Adjusted metric | Generic missing | XPM missing |
| --- | ---: | ---: |
| Line | 4 / 2516 | 26 / 3148 |
| Condition | 0 / 276 | 45 / 498 |
| Toggle directions | 480 / 83192 | 517 / 92608 |
| Branch | 4 / 269 | 60 / 756 |

- Both: `dpd_memory_poly.v:334` sample_count bits31:17,16 lanes,480 directions.
  These are reachable and remain in the denominator. First bit31 rise needs
  2^31 accepted words; measured simulation scaling is about18days per FIFO,
  before the independent reference-generation cost. The existing full32-bit
  increment/hold/reset proof checks arithmetic behavior, not a raw toggle hit.
- Both: `dsm_interp_x2_polyphase_vector.sv:91-92`, positive/negative clamp arms.
  Valid two-tap values are bounded; initial invalid payload registers are not
  reset and can be symbolic in formal. The initial ungated proof failed.
  The valid-qualified proof cannot justify every invocation of round_sat.
- XPM: remaining memory collision/clock-window conditions and branches,
  legal wrapper reset/handshake operand combinations, reset-controller defaults
  and hold arm, and FWFT default/transition paths. Exact CSVs retain source
  statements, expressions, operands, signals and directions. Some reviewed
  configuration bins still lack an unambiguous native URG mapping and remain
  in the denominator; reviewed record count is not an URG hit count.
- XPM FWFT `stage1_valid -> invalid`:12 public reset phase cases0..11 PASS with
  independent flush/full56-word replay, but no exact hit. A qualified formal
  cover after genuine accepted traffic remains inconclusive (depth727);
  normal stage1/read covers hit depth65/66. Initial depth0/1 covers from earlier
  unconstrained vendor state are explicitly rejected as closure evidence.
- Vendor review:5845/5990 original vendor records have configuration evidence,
 145 remain unreviewed. This count includes aggregate FSM rows and is distinct
  from adjusted metric denominators. No blanket vendor-file/hierarchy waiver.

## Finalized formal evidence

| Scope | Current matching-source run | Result |
| --- | --- | --- |
| DPD | runs/thermo5_converge_identity_signoff_20261007 | SCOPED_SATURATION_PROVEN_PAYLOAD_OPEN;19 proven,1 identity inconclusive;4 covers |
| Valid interpolation bounds | runs/thermo5_converge_interp_signoff_20261007 | PASS;16 assertions,5 covers |
| Actual XPM residual | runs/thermo5_converge_residual_signoff_20261007 | PASS;7 assertions,9 covers |
| Legal XPM reset reentry | runs/thermo5_converge_reset_signoff_20261007 | PASS;2 assertions,4 covers,2 uncoverable goals |
| Qualified XPM FWFT | runs/thermo5_converge_fwft_accepted_20261007 | INCONCLUSIVE_OR_FAIL;1 proven,2 covers,1 inconclusive |

All finalized proof manifests record unchanged sources, actual vendor hashes
where used, zero blackboxes, and setup reports. No whole arithmetic formal PASS
is claimed. Formality LEC separately PASS:170869 equivalent compare points,
zero failing/aborted/unmatched; `runs/thermo5_fm_restored_20261007_retry1/`.

## Reproduction and next exit gates

Use `dv/uvm/sim/generate_thermo5_sku_vectors.ps1 -Profile range_stress
-Words 65541 -Seed 610701 -OutDir runs/<new-vector-run>/range65541`, then
`dv/uvm/sim/run_thermo5_gap_closure.py --baseline-dir <matching-PASS-baseline>
--out-dir runs/<new-closure> --xpm-root <installed-Vivado> --range-vectors
<complete-vectors> --range-words 65541 --gain-vectors <independent-gain-vectors>
--gain-toggle-vectors <independent-gain-toggle-vectors>`.
Run only inside the licensed Rocky environment. Baseline reuse fails on a
source-hash mismatch. Omit --baseline-dir to make a fresh compile baseline.

`tools/hw/thermo5_gap_ledger.py <closure> <new-ledger> --report-layout flat`
extracts the fresh raw ledger. `thermo5_xpm_bin_review.py` and
`thermo5_urg_exclusions.py` produce guarded record reviews and native exclusion
files; their manifests record proof/vendor/exclusion hashes. Apply to precisely
the passing baseline and directed VDB inputs in closure.json, preserve raw URG,
and reconcile the adjusted remaining CSVs against actual URG denominators.

Next: prove all evaluated interpolation payloads under an explicit initialization
model; close XPM reset/FWFT/default and collision contracts with qualified
reachability; map remaining reviewed signatures; execute incremental affordable
counter streams or formally discharge verification goals while keeping unhit raw
bits visible. Full100% requires all remaining bins hit or specifically justified
and an actual matching-build URG report. Current delivery is partial.

Checks run: actual VCS baseline and24 closure cases; native raw/adjusted URG;
final scoped VC Formal repeats; hash/binary/exclusion/counter gates; Python compile;
selected git diff --check. No new CI dispatch for these Oct7 source changes;
prior CI37462007850 remains PASS only at its recorded source. No board is available.

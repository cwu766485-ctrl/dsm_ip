# Thermo5 Branch Consolidation — Post-merge Verification

- Date: 2026-11-06 (SGT)
- Repository: `cwu766485-ctrl/dsm_ip`
- Product SHA tested: `8fddad5ba59814d9a0b95a9d94b88e7036efc16f`
- Product tree: `76b082af1c94a1082f3c68cc64fa42c1b63c6838`
- Merge commits: PR #40 `f8b14df743eeb6facfd0378b402f1670a6cf9b0f`; PR #41 `8fddad5ba59814d9a0b95a9d94b88e7036efc16f`
- Worktree: detached `/tmp/dsm_ip_thermo5_consolidation_final`, clean at test start

## Source and configuration binding

The tested configuration is Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 /
20-bit state, four 64-bit PA outputs, DPD_MAX_TAPS=1 with Identity reset
image, AXI-Lite, and Generic FIFO. Defines:

```text
THERMO5_AXIL_CONTROL
THERMO5_CENTERED_CUBIC
THERMO5_TIDSM_ORDER=2
THERMO5_STEP=5120
THERMO5_DPD_MAX_TAPS=1
```

The retained compile source manifest was created at Round 11 source commit
`d823654cba715e9093bb8cc08e6d819e8ae1365f` (tree
`244b49c4daf1561806d7f02d6dfb560227757571`). Its 96 listed compile inputs
were re-hashed against the final merged tree: **96/96 match**. The 21 product
RTL files also match byte-for-byte, with aggregate SHA-256
`c627e02758be102e379e5eb464590189f354894dc84fc967c8e408554be38fe8`.
The compile input fingerprint remains
`08e62a87420ee9a9acce7724d2cca3c909f8cb7265dac22563522ac97a74b300`.
PR #41 added only documentation/evidence after the tested source snapshot;
no RTL, UVM compile input, or product algorithm changed.

Tools: Python 3.12.13, VCS V-2023.12-SP1_Full64, URG V-2023.12-SP1,
VC Formal V-2023.12-SP2_Full64.

## Post-merge regression matrix

| Suite | Result | Scope |
|---|---|---|
| Generic FIFO VCS | PASS | `thermo5-vcs-regression`; seven directed scenarios; UVM error/fatal counts 0/0 |
| AXI-Lite product VCS | PASS | Product register/config, COMMIT, DPD transport, STOP/drain, frame/mailbox negatives, parameter guard, URG product merge |
| System Random | PASS | 100 packet seeds + 10 long-stream seeds = 110/110 |
| DPD × Gain × Input Profile | PASS | 60/60 legal one-tap coefficient/gain/profile tuples; Identity remains reset image |
| Randomized Reset | PASS | 24/24 |
| Randomized COMMIT | PASS | 24/24 |
| Python reference tests | PASS | 64/64, Python 3.12.13 |

The generic and AXI-Lite directed regressions reused the retained product
vector set with tree SHA-256
`7c9a5e6b7e60e193b6911d5e2437848a16707168c789bbac217e9c8814158fbb`; it
contains the required three frame starts. The System Random, DPD matrix, and
Reset/COMMIT summaries embed the exact tested source SHA and product
configuration. Earlier setup-only attempts (incomplete frame-start vector,
missing default runner vector path, and an output path outside a runner's
repository-relative constraint) were corrected; the successful runs above
are the acceptance evidence.

Exact command records and the SHA-256 values of all wrapper logs and campaign
summaries are in
[`thermo5-branch-consolidation-postmerge-20261106.json`](data/thermo5-branch-consolidation-postmerge-20261106.json).
Full logs, summaries, VDBs, traces, and URG products are retained under the
ignored `runs/thermo5_branch_consolidation_final_20261106/` directories and
the detached worktree's ignored `runs/` directory. Generated data was not
added to Git.

## Cross coverage and scoreboard evidence

The final 7 named system crosses remain closed at the audited exact-bin
counts: DPD × Gain × Input Profile 60/60; COMMIT × Frame Boundary × PA Stall
2/2; Reset × Pending COMMIT 4/4; STATUS × COMMIT × STOP 1/1; Source Gap × PA
Stall × FIFO Full 1/1; RUN × Prefill × Source Gap 1/1; STOP × TLAST × Drain
1/1. These counts come from the retained Round 11 VDB set, whose compile
fingerprint matches the merged source byte-for-byte; this post-merge rerun
did not rebuild the full 449-test URG aggregate.

The packet/Epoch scoping, strict STOP < accepted TLAST < Drain order, and
cross-packet and TLAST-before-STOP negative checks remain as audited in the
Round 11 report. The independent Python trace-oracle mutations detect missing,
duplicate, reordered, wrong-Frame-ID, stage-divergence, truncated-prefix, and
early-Apply errors. Direct mutation injection into the SystemVerilog Unified
Scoreboard remains OPEN.

## Coverage and Formal disposition

Raw and Adjusted use the same retained 449-test-VDB plus design-VDB manifest
SHA-256 `2dbdad75ac0a877381a30e46ece68ddef49cbdff1422943919a5585cc6faeb62`.
The source fingerprint matches the final merged compile inputs. No approved
waiver or active exclusion exists, so Raw equals Adjusted:

| Metric | Raw = Adjusted |
|---|---:|
| Branch | 524/637 (82.26%) |
| Condition | 657/849 (77.39%) |
| Line | 3338/3796 (87.93%) |
| Toggle | 91112/104480 (87.21%) |
| FSM states | 13/13 (100%) |
| FSM transitions | 18/22 (81.82%) |
| Legal applicable functional bins | 436/436 (100%) |

All 371 waiver candidates remain pending; 0 approved and 0 exclusions are
active. The gate remains `RAW_100_OPEN`; the code-coverage result is not a
final signoff.

Formal source files were re-hashed against the current tree and matched.
Formal was not rerun after merge because PR #41 changed only reports/docs and
the proof-input source hashes are unchanged. AXI-Lite config leaf proof is a
scoped PASS. Outstanding-counter saturation/underflow remains INCONCLUSIVE.
Frame-tail `q1_tail` and DPD Identity proofs remain scoped and do not prove
the complete FIFO/DPD/CDC product chain. Full COMMIT/Pending/Active lifecycle
Formal remains OPEN. No inconclusive result was promoted to PASS.

## Branch and PR disposition

- PR #40 and #41 are merged into `thermo5`.
- PR #27–#39 were commented as superseded by #40/#41 and closed, not merged,
  after the merged-source regression passed.
- Patch audit found no absent paths among 404 touched paths, 278 exact final
  blobs, and 303/404 per-file reverse-patch checks. The remaining 101 files
  evolved in later commits and are not mechanically proven equivalent by the
  original PR patch alone. Their remote refs remain recoverable for deeper
  review; no historical branch was deleted.
- Original refs were not deleted; they remain recoverable. The GitHub
  connector available in this environment has no branch-ref deletion
  operation. No force push was performed.
- Keep `main`, `thermo5`, `thermo3`, `dsm`, and
  `dv-de-portfolio-20261006`.
- The dirty `codex/thermo5-tx-frame-tail-full-chain-formal` worktree and the
  existing stash were preserved without modification.

## Acceptance decision

The integration milestone is complete: `thermo5` is the baseline, PR #40/#41
are merged, and PR #27–#39 are closed as superseded while their refs remain
recoverable. The patch audit found no absent paths, but 101 evolved per-file
changes are not mechanically proven equivalent by the old patches; keep those
refs available for review. The Linux regressions listed above pass at the
merged product SHA/content fingerprint. **Digital verification signoff is
still OPEN** because DUT code coverage is below 100%, 371 waivers are
unapproved, direct SV scoreboard mutations and some Formal obligations are
open. Real XPM/GT Wizard simulation, Vivado routed timing/PPA/power, and
physical RF/QAM256 validation are NOT_RUN and are not implied by this report.

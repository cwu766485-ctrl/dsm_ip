# Thermo5 DPD branch and counter audit

## Measured counter delta and scoped proof (2026-10-06)

Same-build generic/XPM URG in
`runs/thermo5_dv_package_delivery_20261006/coverage/` proves both toggle
directions for bits5:10 in all 16 DPD lane counters. Bit11 has 0->1 only;
bits31:12 remain red. The 2072-word plateau run checks 1184 accepted AXI
beats, all four independent golden planes and all 16 sample/saturation
counters. Complete per-bit before/after directions are in
`baseline/<fifo>/toggle_bit_delta.csv`; grouped-row shrinkage is not used as
a substitute for a direction check.

Production `dpd_memory_poly` formal with one identity tap proves
`sample_count==accepted`, `accepted<=2072`, and `sample_count[31:12]==0`.
The ghost counter tracks accepted interface inputs. Covers demonstrate
acceptance, count change, output stall and recovery; both environment
assumptions are non-vacuous, and no RTL arithmetic module is black-boxed.
See `formal/counter/properties.txt` and `formal/formal_summary.json`.

This is a proof **within the 2072 accepted-input budget since reset**.
It does not make high bits unreachable for an unlimited run. Bit11 cannot
fall through ordinary monotonic increment before 4096 inputs; the chosen
experiment stops at 2072. Unbounded counting and reset-driven toggle remain
OPEN in raw URG. No counter width, state, oracle, or RTL behavior is changed.

Date/time: 2026-10-06, 11:22 (Asia/Singapore)

## Scope and source reports

The current-source same-build follow-up at
`runs/thermo5_gap_baseline_20261006_v1/generic/coverage_long/` and its XPM
counterpart passes the independent 2072-word oracle and all 16 counters.
`sample_count[11]` now has a measured `zero_to_one` direction in both URG
merges. Grouped `sample_count[31:12]` remains directionless and OPEN; no
counter wrap or high-bit closure is claimed.

This audit covers the generic frozen thermo5 SKU only: `DPD_MAX_TAPS=1`,
`dpd_active_taps=1`, `c1_re=16384`, all other coefficients zero, and the 16
instances `dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[0..15].u_dpd`.
No RTL, coefficient, interface, or numerical behavior was changed.

The fresh VCS baseline is
`runs/thermo5_frozen_regression_hardened_20261006/generic/`. Its audit CSVs
are `audit/urg_uncovered_branch_lines.csv` and
`audit/urg_uncovered_toggle_signals.csv`; the module source detail is
`coverage/mod14.html`. The 16 branch rows each show line 198 with 6 branches,
5 covered, and 1 missing. The HTML branch table maps `-1-` to `!rst_n`, `-2-`
to `pipe_ce`, `-3-` to `in_valid`, and `-4-` to
`valid_pipe[PIPE_STAGES-1] && (sat_i || sat_q)`. The sole red combination is
`-1-=0, -2-=1, -3-=don't-care, -4-=1`. Therefore the missing arm is the
valid-output saturation condition; it is not a reset arm. The other five
branch combinations are green in the HTML detail.

Source/report identity: current `rtl/dpd/dpd_memory_poly.v` SHA256 is
`8939CF7002424BB22A5B0575562AF7E42332E85D88553FC5FB6CF83BC92A5F6A`;
baseline branch CSV SHA256 is
`2579592208CED24E273CAF8BB821AD2628F5586A83B68CBDA677FA0A9015A0F1` and
toggle CSV SHA256 is
`97DFFAC6B7E0E5EEDD80864D1E0CD8F93484AC416EAFD85F874BFDBAD7644D92`.

## Branch disposition

Under this frozen configuration, `MAX_TAPS=1` selects only tap zero,
`c1_re=2^14`, and `c1_im=c3_re=c3_im=c5_re=c5_im=0`. For each accepted lane
sample, the DPD result is `(sample * 2^14) >>> 14`, exactly the signed 16-bit
input, including `-32768`; invalid pipeline slots contribute zero. Neither
I nor Q can exceed the signed output range, so `sat_i || sat_q` is false when
the output-valid term is true. This is scoped to the exact frozen identity
configuration, not programmable coefficients.

The independent exhaustive block test
`dv/verif/block/dpd/tb/tb_dpd_identity_exhaustive.sv` exercised all 65,536
values on I and Q separately, plus a diagonal sweep. Its recorded XSim result
is `DPD_IDENTITY_EXHAUSTIVE_PASS accepted=196608 output=196608
invalid_sat_slots=0 min=-32768 max=32767` in
`runs/dpd_identity_exhaustive_xsim/xsim.log`. This is the numerical evidence
for the excluded arm. It does not create or update a VCS URG row.

| Instance | URG missing state | Disposition |
| --- | --- | --- |
| `g_lane[0].u_dpd` | `valid && (sat_i || sat_q)` | `PROVED_UNREACHABLE` for the frozen identity SKU |
| `g_lane[1].u_dpd` | same | `PROVED_UNREACHABLE` for the frozen identity SKU |
| `g_lane[2].u_dpd` | same | `PROVED_UNREACHABLE` for the frozen identity SKU |
| `g_lane[3].u_dpd` | same | `PROVED_UNREACHABLE` for the frozen identity SKU |
| `g_lane[4].u_dpd` | same | `PROVED_UNREACHABLE` for the frozen identity SKU |
| `g_lane[5].u_dpd` | same | `PROVED_UNREACHABLE` for the frozen identity SKU |
| `g_lane[6].u_dpd` | same | `PROVED_UNREACHABLE` for the frozen identity SKU |
| `g_lane[7].u_dpd` | same | `PROVED_UNREACHABLE` for the frozen identity SKU |
| `g_lane[8].u_dpd` | same | `PROVED_UNREACHABLE` for the frozen identity SKU |
| `g_lane[9].u_dpd` | same | `PROVED_UNREACHABLE` for the frozen identity SKU |
| `g_lane[10].u_dpd` | same | `PROVED_UNREACHABLE` for the frozen identity SKU |
| `g_lane[11].u_dpd` | same | `PROVED_UNREACHABLE` for the frozen identity SKU |
| `g_lane[12].u_dpd` | same | `PROVED_UNREACHABLE` for the frozen identity SKU |
| `g_lane[13].u_dpd` | same | `PROVED_UNREACHABLE` for the frozen identity SKU |
| `g_lane[14].u_dpd` | same | `PROVED_UNREACHABLE` for the frozen identity SKU |
| `g_lane[15].u_dpd` | same | `PROVED_UNREACHABLE` for the frozen identity SKU |

These are proof dispositions, not coverage waivers. The red VCS URG branch
rows remain red until a reviewed exclusion mechanism is separately approved;
no exclusion or waiver was added here.

## `sample_count` behavior and evidence

`rtl/dpd/dpd_memory_poly.v:200,327-335` asynchronously clears each 32-bit
counter while `rst_n=0`. Thereafter it increments by one only when
`pipe_ce && in_valid` is true. `in_ready` equals `pipe_ce`; the vector wrapper
drives every lane's `in_valid` from the same accepted vector transaction.
Frame-start is not an input to this counter and does not clear it. Thus each
lane counts accepted 16-sample DPD vector words continuously across frame
markers; reset alone restarts the count.

For exactly one legal 56-word frame starting from reset, the counter runs
from 0 through 56: bit 5 has a `0->1` transition at count 32, but no `1->0`
transition (that occurs at count 64). Bits 6 through 31 remain zero in that
bounded trace. Those missing directions are `PROVED_UNREACHABLE` only under
the explicit single-frame-after-reset bound. They are not globally
unreachable: without an intervening reset, another frame continues the same
counter. At cumulative count 64, bit 5 falls and bit 6 rises; bit 5 rises
again at 96. In general bit `n` rises at count `2^n` and falls at `2^(n+1)`.

A fresh full-chain generic XSim run used the existing legal 1,008-word
extreme-vector test and its four-plane MATLAB oracle:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_thermo5_i2_d1_axis.ps1 -StressPaReady -Words 1008 -Seed 61006 -VectorDir .\runs\uvm_thermo5_i2_d1\axis_xsim_seed505_words1008
```

It passed on 2026-10-06 at 11:21 Singapore time with 576 accepted AXI beats,
1,008 matching output words on each of four planes, and 295 PA stalls. The
test checked each hierarchical DPD lane counter against 1,008 and every
saturation counter against zero. The three frame-start markers in the
vector set confirm the count spans frame boundaries without DPD reset. Since
the counter starts at zero and its only non-reset update is `+1`, the exact
final value proves the traversed bit transitions for every lane:

| Lane | Counter at end | Bits 0-8 | Bit 9 | Bits 10-31 |
| --- | ---: | --- | --- | --- |
| `g_lane[0..15].u_dpd` (each lane checked separately) | 1008 | both directions traversed | `0->1` traversed; `1->0` not reached | neither direction reached |

For strict closure bookkeeping, these are full-chain **functional XSim
hits**, not VCS UVM coverage hits. No new VDB or URG merge was generated.
Therefore current generic UVM coverage remains `OPEN` for bit 5's
`1->0` direction and for grouped `sample_count[31:6]`; the XSim run proves
reachability through bit 8 and a rising transition on bit 9 but does not
change the fresh VCS URG rows. Bits 10-31 are also `OPEN`, not impossible:
the finite 1,008-word run does not reach their thresholds. They require
`2^n` accepted words from reset for a first rising transition and
`2^(n+1)` for a falling transition.

## Checks, artifacts, and remaining limits

- PASS: fresh generic full-chain XSim command above; output log:
  `runs/uvm_thermo5_i2_d1/axis_xsim_seed61006_words1008/console_xsim.log`.
- PASS evidence reused: exhaustive identity DPD block XSim log cited above.
- Not run: VCS, because the current VCS license failure is still in force;
  no retry was made. No URG/VDB was changed or merged.
- New tracked file: this audit document only. The shared execution frontier,
  coverage record, `UPDATE_LOG.md`, and task inventory were not edited.
- Remaining: per-bit VCS URG rows are `OPEN` pending license restoration and
  a reviewed merged-coverage run. A longer finite hit does not close bits
  whose transition thresholds it does not reach.

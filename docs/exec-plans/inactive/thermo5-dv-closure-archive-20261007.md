# Thermo5 digital verification closure plan

Date: 2026-10-05. Owner: primary agent plans and reviews; GPT-6 Luna executes
bounded work packages. The active design status remains in
`execution-frontier.md`; this document defines verification deliverables.

As of 2026-10-06, WP1–WP5 artifacts and the selected regressions are
delivered. The post-checker-hardening generic/XPM launcher manifest is
`runs/thermo5_frozen_regression_hardened_20261006/manifest.json` and reports
PASS. This closes the scoped execution package, not the outstanding
coverage, parent I/O, GT CDC/RX, or board signoff items.

## Scope and source of truth

- Frozen DUT: `tid32_thermo5_axis_frontend_tx`, `INTERP_TAPS=2`,
  `DPD_MAX_TAPS=1`, `BYPASS_DPD=0`, unity identity coefficients, with generic
  or real XPM async FIFO. The canonical filelist is
  `dv/uvm/sim/thermo5_sku_filelist.f`.
- One legal 32-beat frame transfers 448 complex input samples and produces 56
  four-plane output words. The MATLAB `.mem` files are the independent
  four-plane bit-true oracle. The scoreboard checks monitor-observed accepted
  source beats and PA words by reset epoch.
- The GT Wizard and physical serial outputs are outside this UVM DUT. Parent
  reset/GT tests, routed CDC, and STA are separate integration evidence.
- Preserve the frozen RTL, numerical behavior, oracle, and existing AXI-IP
  UVM target. Put generated data and logs under `runs/`.

## WP1: Traceable verification plan and functional coverage

Deliver a thermo5-specific English plan in `docs/verification/` mapping each
requirement to an existing or new test, observable checker/assertion, named
functional bin, evidence path, and status. Required rows: AXI hold under
stall; 14:8 ordering and FIFO full/empty; separate reset requests and epoch
flush; both x2 interpolation boundaries; frame gain; identity DPD including
signed minimum; four-plane order/alignment; PA stall; illegal frame; idle,
stop, and recovery. Record scope exclusions explicitly.

Exit gate: every row has a concrete checker and a measurable functional bin;
tests assert required event counts and scoreboard drain, rather than merely
sampling covergroups. No existing PASS is upgraded by writing the plan.

## WP2: Instance-level coverage closure

Use the latest licensed generic and XPM VDBs separately. Export uncovered
condition, branch, toggle, and assertion bins with exact instance/source
location. Classify each as HIT by a new run, parameter-proven unreachable
for this frozen SKU, or OPEN. A proof needs the parameter value, RTL branch
expression, and reasoning; an unobserved bin is not a waiver. Keep vendor
XPM internals separate from owned RTL.

Exit gate: a machine-readable inventory and a reviewed summary enumerate all
remaining owned-RTL gaps. Any reachable gap selected for closure has a
directed test that still passes the four-plane MATLAB oracle. Functional and
code coverage are reported independently.

## WP3: Fault-detection experiment

Create 3–5 one-fault-at-a-time mutants in isolated generated run directories,
without editing the canonical RTL. Candidate faults: stale FIFO word after
reset, swapped PA planes, dropped word under PA stall, and premature frame
gain update. For each mutant record injection site, reproducing test/seed,
first assertion or scoreboard failure, mismatch location, and clean-baseline
result. Keep only mutants that compile and reach the intended fault. Do not
count a compilation failure or timeout alone as detection.

Exit gate: each retained fault is caught by the intended checker before the
normal PASS marker, while the unchanged baseline passes the same test.

## WP4: Clock/reset and GT integration evidence

For the 125-MHz AXI to 218.75-MHz core boundary, tie each FIFO pointer/reset
crossing to an instance-level static report, directed two-reset/epoch XSim or
UVM test, and applicable assertion. Review release ordering and stale-data
flush. Keep the two generated-GT TX-active CDC-11 paths OPEN until a
path-specific supported disposition is obtained; do not waive them.

Exit gate: an evidence table cites exact report rows and tests. A partial
reset test does not imply metastability proof or board-level GT closure.

## WP5: Reproducible regression and handoff

Provide a single documented launcher for generic and real-XPM seven-case
regressions, independent MATLAB payload seeds, URG merges, and a concise
machine-readable summary. Capture commit/source hash, tool version, seed,
configuration, command, exit code, log/VDB path, scoreboard count, functional
coverage, owned-RTL code coverage, and open items. Fail the launcher on
missing evidence, UVM errors/fatals, missing expected negative assertion,
scoreboard mismatch, or incomplete queue drain. Never merge generic and XPM
VDBs into one percentage.

Exit gate: a clean repeat with an unused output directory produces the same
PASS/OPEN classification. Published claims link to the exact run manifest.

## Order and review

Run WP1, then WP2. WP3 uses the resulting checkers. WP4 can use existing
directed reset/CDC reports while WP3 executes. WP5 packages verified results
after all selected tests are stable. After each work package, review diffs,
run the applicable regression, update `execution-frontier.md` and
`docs/UPDATE_LOG.md`, and retain remaining OPEN items. A tool or license
failure is recorded as such, never converted to PASS.

# Thermo5 CDC/RDC root fix — Gates 1–3

Parent PR61 c3a84fee43630d6155d2b2fe3ebd62d32c68cee0, stacked on PR60
f6445a65a24970a86fe49bdbe76b463fe4494d0c. Independent ECO branch; no merge.
Scope: real AXI-Lite top/MAX_TAPS1/Generic FIFO, all product widths and depths.

## Gate1: exact raw accounting

Executed PR61 thermo5_rdc_rootcause_audit.py against original compressed native
inventory. Every parsed goal record count matches original moresimple report.
Ar_resetcross01 has10525records, not10525errors: Frontend7576 + DPD2680 +
Gain149 + GenericFIFO98 + Config12 + Top10. There are10506Error/15Warning/
76Info in the complete original RDC report. Baseline audit has109 normalized
groups including five CDC targets. Group totals retain all severity records;
normalization is diagnostic, not independent defect count or waiver.

## Gate2: actual source ECO

Five Ac_glitch03 destinations map to four source cones:

| Destination | Original source | ECO |
|---|---|---|
|u_cfg.tx_active_sync1|core_enable OR core_tx_active_q|core-domain tx_active_status_c register|
|core_active_s1|same activity cone|same registered source|
|u_cfg.draining_sync1|active_q AND NOT core_enable|core-domain draining_status_c register|
|prefill_gray_c1[0]|binary count XOR shifted count|single-bit registered count==2 predicate|
|ingress_closed_c1|RUN/seen/frame-open combinational conjunction|source-domain ingress_closed_status_s register|

Existing destination synchronizer chains remain. Public core_tx_active and
core_draining/datapath decisions retain original semantics; remote statuses
acquire one source-cycle delay. Prefill core start and ingress-closed status may
arrive one source cycle later. Numeric pipeline/scaling/rounding unchanged.
Binary prefill saturates at2: core consumed only Gray==11, so crossing a source
registered predicate avoids multi-bit Gray reset3→0 ambiguity. No Gray bus is
needed for this status. FIFO Gray pointers are unchanged.

Actual SpyGlass V-2023.12-SP1, no waived messages/no rule disabled:

|Goal|Before Error/Warning/Info|After Error/Warning/Info|
|---|---|---|
|CDC setup|0/15/65|0/15/65|
|CDC structural|5/29/101|0/27/101|
|RDC structural|10506/15/76|10506/15/70|

Unsynchronized crossings0. Reconvergence5→7; this is **OPEN**, not signoff.
Existing FIFO Gray encoding check remains DISABLED by original tool setup.
Remaining control/data reconvergence and bundled-data stability need explicit
protocol/metastability assumptions and physical constraints. This ECO closes
the five combinational fan-in diagnostics, not all CDC obligations.

State cost: four new single-bit source registers; replace two-bit×two-stage
prefill synchronizer by single-bit×two-stage (net+2bits). No ports or data
buffers added. Source register input cones remain combinational locally;
physical CDC placement/MTBF and bundled-data timing are not proven by RTL FPV.

Licensed product VCS regression PASS (legal cases zero UVM warning/error/fatal;
intentional illegal-frame/mailbox/parameter negative tests are expected errors).
STOP/restart112words PASS. Reset sweep9reassertions plus complete replay passes
independent Python trace Oracle:206CDC/101EF2/91PAwords, zero underflow.
New source-status FPV:7proven,6nonvacuous implications,2positive covers; selected
setup clock/glitch/loop/multidriver0. Initialized reset is constrained inactive
thereafter, so this source proof alone does not prove repeated reset epochs.

## Gate3: reset roots

[Owner-confirmed contract](../architecture/thermo5-reset-contract.md): common
assertion, independent synchronized release; runtime single-domain assertion
unsupported. This is an integration requirement, not newly implemented lease
or reset hardware. Conservative SGDC remains unchanged.

Frontend7576: unreset two-slot data/meta memories are controlled by reset count
and pointers. New actual FIFO FPV with symbolic repeated reset proves4/4:
capacity, reset-empty, masked-empty metadata and valid slot initialized in this
epoch;2covers include live→reset→fresh live. Initial unconstrained-state proof
failed at depth0, preserved; corrected with one boot reset while repeated epoch
request remains symbolic. No DUT change or assumed memory-zero. This proves
control masking for one actual W16/LANES8/META18 instance, not every downstream
arithmetic data dependency or all7576paths. Full vector/reset noninterference
and per-instance/path mapping stay OPEN.

DPD2680: one-tap arbitrary coefficient invalid-enable/term alignment lemmas
prove10/10 without promoted assumptions; remaining invalid-sum/no-saturation
prove2/2 after promoting only those proven lemmas. Positive output/bubble
covers hit and invalid saturation uncoverable. This is not arbitrary reset
metastability or all coefficient arithmetic proof. Repeated-reset pipeline
valid/hold proof is separately reported in evidence; no blanket waiver.

Generic FIFO98: source-reviewed write/read Gray pointers reset, memory stays
unreset, public product source Ready has local reset gate. New actual depth16
simulation covers6 common reset epochs, both release orders, full/pending write,
384fresh words with independent expected queue; no old epoch data observed.
Reset synchronizer component6epochs/18releases also PASS. Formal epoch/Gray
results are separately recorded; simulation is not exhaustive RDC proof.

Gain149/Config12/Top10: Gain FIFO composition proves4assertions/3positive
covers, two illegal metadata targets uncoverable under initialized reset.
Mailbox/common-reset product regression is scoped evidence only. Independent
reset counterexamples are outside the owner contract but cannot be removed
from the unconstrained static report by assertion. All remaining path
relationships require explicit mapping and independent disposition.

After ECO Ar_resetcross01 has10519records in104normalized groups; frontend,
DPD,Gain,FIFO counts unchanged. Config/Top combined22→16; Error10506unchanged,
Info76→70. This is structural cone change, not six fixed functional RDC bugs.
Approved RDC waivers=0; approved URG exclusions=0; no mixed databases/directives.

## Decision

Retain as an **ECO candidate for review**, not merged or globally signed off.
Five real source combinational CDC risks are removed structurally and covered
by regression/formal. Root accounting is exact. Remaining reconvergence,
Gray-check setup, reset physical assumptions, full datapath epoch proofs and
per-record RDC dispositions stay OPEN. No false zero-error RDC claim.

Reproduction commands, source/evidence hashes and individual pass/fail outcomes
are in data/thermo5-cdc-rootfix; run formal commands from separate directories
because VC Formal uses a cwd-local session.lock. Native raw reports/counts are
preserved; no URG exclusion or tool waiver is applied.

### Additional bounded proof outcomes

Repeated-reset one-tap DPD epoch/valid pipeline and stalled-output stability:
3/3 PROVEN,2/2 covers, with symbolic epoch_n after boot. This checks current
pipeline reset token alignment and hold, not arbitrary coefficients numeric
noninterference across every unreset intermediate register.

Actual depth16 async FIFO, common assertion plus local reset synchronizers:
4/5 assertions PROVEN (read/write Gray and reset push/pop exclusion); the
critical initialized-before-read epoch assertion is INCONCLUSIVE in the120s
budget, and live-reset-recovery cover also INCONCLUSIVE. Transfer cover hits.
No counterexample was found, but no epoch proof or waiver is claimed. Do not
replace this open obligation with the six passing simulation epochs.

Existing identity/stall arithmetic proof engine completed, but its manifest
validator rejects this dirty experimental worktree. That run is OPEN, not a
validated PASS; clean-checkpoint rerun is required. Broad source-frame contract
proof did not finish within this ECO's bounded run and remains OPEN. Initial
VC Formal cwd session-lock failures are environment failures; retries run in
separate directories. No existing session lock was removed.

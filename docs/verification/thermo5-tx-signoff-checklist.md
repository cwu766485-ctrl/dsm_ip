# Thermo5 TX Design and Verification Signoff Checklist

This checklist is tied to the frozen product definition in
[`thermo5-tx-final-baseline.md`](thermo5-tx-final-baseline.md). A PASS applies
only to the named configuration and evidence source. Candidate results do not
promote or replace the product configuration.

## Product definition and provenance

- [x] Actual GT-parent product parameters read from RTL and recorded:
  centered-cubic x2+x2, EF2 order 2, STEP 5120, 20-bit state, one-tap identity
  DPD, four output planes.
- [x] Linux VCS product substitution identified: Generic FIFO in place of XPM.
- [x] PR #2–#7 ancestry, exact heads, and unmerged state recorded.
- [x] Product VCS source SHA distinguished from current repository/report SHA.
- [x] Raw and adjusted coverage are reported separately; no unapproved waiver
  or denominator edit is used.
- [ ] Historical PR #5 directory-tree digest discrepancy fully explained.
- [ ] Stable, target-owned acceptance limits for BER/BLER, EVM, SNDR, ACLR,
  output power, and legal source-gap/backpressure envelope approved.

## Product functional and implementation verification

- [x] Existing Generic-FIFO UVM product tests and current product coverage
  evidence retained with exact source/configuration.
- [x] Current product FSM state/transition bins: 13/13 and 22/22.
- [x] Applicable positive functional scoreable records: 210/210.
- [ ] Four illegal-frame Raw records remain uncovered in the denominator
  (210/214 scoreable records); the complete 226-row audit includes 12
  pre-existing URG model Illegal/Excluded rows. The earlier 170/174 tally
  omitted 40 generated EF2 cross-bin records and is superseded.
- [ ] Raw DUT code coverage closure: current 81.99%; `RAW_100_OPEN`.
- [ ] All legal, reachable DUT branches, conditions, lines, and toggles closed
  or individually dispositioned with source-specific proof.
- [ ] DPD identity arithmetic proof completed; current 1/13 proven and 12/13
  inconclusive.
- [ ] Product EF2, FIFO, frame-tail, configuration atomicity, and STOP/Drain/
  Restart proofs reviewed at the full composed hierarchy.
- [ ] Mutation suite covers EF2 stall-state, plane order/data, DPD commit,
  TLAST, and FIFO duplication/loss with independent checker detection.

## Phase 1 Linux design studies

- [x] Four-cell architecture ablation complete with common QAM256 inputs,
  average RMS, held-out seeds, receiver and PA/noise settings.
- [x] First-order `STEP=7168` sensitivity rows separated from the common
  `STEP=5120` 2x2 architecture comparison.
- [ ] EVM, SNDR, uncoded BER and error count, PSD/image/adjacent-band proxy,
  PAPR, clamp counts, fixed-point error, stream look-ahead, and model timing
  recorded per candidate.
- [x] Pair Look-Ahead=1 Linux bit-true and Formal equivalence retained;
  extreme/tie/clamp/stall/reset corner coverage complete.
- [x] Fitted 2/4-tap DPD coefficients generated from development data,
  quantized to signed Q2.14, and evaluated on disjoint held-out data.
- [x] Fitted DPD coefficient image checked against Python fixed-point oracle
  and actual RTL (VCS); product one-tap identity remains unchanged.
- [x] Candidate disposition recorded as `ACCEPT`, `REJECT`, or `DEFER` with
  modeled assumptions and confidence limits.

## Phase 2–6 product and handoff closure (not part of the current Phase 0/1 task)

- [x] Existing Gate 2 finite-seed model campaign reused rather than rerun.
- [ ] Stress envelope, source-gap contract, clamp behavior, and output metrics
  receive target-owner limits and qualification criteria.
- [ ] Full legal functional coverage and code-coverage audit completed.
- [ ] Formal, checker mutation, and expected-negative results are separated
  from legal product coverage.
- [ ] Vendor XPM and exact GT Wizard simulation completed on a supported
  vendor host.
- [ ] Vivado OOC and selected-board routed PPA, timing, and power completed
  with exact part and constraints.
- [ ] GT synchronization and physical QAM256 BER/BLER verified on hardware.
- [ ] Final TX Linux and hardware signoff reports identify each result as
  `PASS`, `FAIL`, `NOT_RUN`, or `OPEN` with SHA and reproducible command.

## Current disposition

Phase 0 baseline and evidence reconciliation are complete. Phase 1 Linux
architecture ablation, pair look-ahead equivalence corners, and fitted DPD
development/held-out/RTL checks are complete. The frozen product remains
Centered-Cubic + EF2 + one-tap identity. Candidate DPD and pair look-ahead are
deferred; first-order/causal comparisons are not promoted. Target limits,
complete raw coverage, routed timing/PPA, vendor IP, and physical-link evidence
remain OPEN.

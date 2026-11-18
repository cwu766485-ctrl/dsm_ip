# EF1 / MASH routed timing

Previous EF1 OOC routed WNS -0.352 ns, TNS -4.915 ns, WHS +0.005 ns. Read-only STA adding one ACK source→first synchronizer exception gave WNS -0.337 ns, TNS -4.562 ns, WHS +0.005 ns; next worst Core `draining_status_c_reg` → AXI-Lite `draining_sync1_reg` is an asynchronous first-stage capture. Source is registered and destination is marked ASYNC_REG; absence of phase relation makes the near-coincident fixed-edge check an invalid model of this asynchronous crossing, but each exception still needs independently reviewed CDC, reset and physical evidence. Other crossing/reset paths remain, and no broad exception was added. Worst-20 and constraints: `runs/ef1_ack_first_stage_audit_02/reports/`.

Candidate-only EF1 full synthesis/place/route in isolated sandbox `runs/de_epoch_candidate_sandbox/runs/de_ef1_candidate_ppa_01/` was stopped after its Core-only reset replay witness failed. No routed candidate result was produced; incomplete synthesis logs remain preserved. It uses the unchanged research 4 ns mailbox max-delay, not a qualified CDC constraint set; its unqualified partial reports do not establish timing. Source hashes are in that run's manifest. MASH A/B previous OOC routed WNS -0.333/-0.363 ns, WHS +0.006/+0.004 ns; local data/frame/tail equivalence under stalls, reset and enable passed but full reset/STOP/config/underflow and product equivalence remain OPEN. A/B product selection and EF1+MASH dual top are NOT_RUN. See `docs/verification/vcu118_cdc_closure_20261118/mash_ab_ppa_functional_equivalence.md`.

## Reproduction and scope

Vivado 2026.1 build 6511674; `xcvu9p-flga2104-2L-e`, nominal 218.75 MHz
Core/125 MHz AXIS/100 MHz AXI-Lite. Read-only ACK exception audit source:
`research/vcu118_arch/audit_ef1_ack_first_stage_exception.tcl`; the source
routed DCP SHA-256 is
`8d30bf8351c62bb4494a2698e589afa8fa81e215ae6e6344dd9790bb33cb3153`.
The audit adds only ACK source→first-stage false path on top of the existing
exploratory mailbox 4 ns max delay. OOC input/output budgets and physical
clock source remain provisional. Invoke `vivado -mode batch -source
research/vcu118_arch/audit_ef1_ack_first_stage_exception.tcl -tclargs
<ABS_ROUTED_DCP> <NEW_OUTPUT_DIR>` from a fresh working directory.


## Abort-wrapper exploratory PPA

An isolated PPA proxy copy with the same source/Core reset coordination as the
research Runtime wrapper passed its runtime-mode Golden VCS test (`448` words,
`6/6` mode transitions, zero UVM errors/fatals) in
`runs/de_abort_integration_sandbox/runs/abort_ppa_equiv_01/`. This exercises
`PPA_MODE=-1`, not each statically pruned proxy. The EF1-only and MASH-only
proxies are now queued serially in
`runs/de_abort_integration_sandbox/runs/abort_ppa_queue_02/`. Attempt 01 was stopped because the new source epoch reset output was incorrectly assigned a Core output-delay clock; its original Tcl, logs and partial reports are preserved. Attempt 02 assigns that output to AXIS clock and the serializer reset output to Core. Both cases use the
same device, clocks, Cubic A, XPM FIFO and the same **exploratory**, unapproved
4 ns mailbox exception; they add source/serializer epoch output ports and
reset logic relative to the old PPA baseline, so report that boundary difference
when comparing resources. The manifests capture the dirty sandbox status and
SHA-256 of each substituted source; completion markers and native reports are
mandatory. No routed timing or PPA result is yet available. The research
`thermo5_ppa_abort_candidate.sv` and `run_ppa_abort_candidate.tcl` reproduce
the isolated proxy and script; copy into a fresh isolated checkout with the
recorded config candidate and use a new output directory. This is OOC, not
physical board or GT signoff.

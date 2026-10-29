# Thermo5 TX feature, testpoint, and coverage matrix — Gate 0

**Audited source SHA:** `eb1081bc7607ba2e9825d9e9fb32bcfa1c6a270e`; **verification SHA:** `04550289e1ecb5fa0e38168869d4f2539929cb80`

**Runtime evidence:** exact-source Python, VCS/URG, AXI-Lite, STOP/restart,
EF2 qualification, and scoped formal all rerun at verification SHA above.
See [`thermo5-tx-baseline.md`](thermo5-tx-baseline.md).

This is the Gate 0 inventory of the current TX product hierarchy. Coverage
values refer to raw Generic URG unless a row explicitly says targeted
functional coverage. See
[`thermo5-tx-coverage-ledger.csv`](thermo5-tx-coverage-ledger.csv) for each
reported source line, condition/branch vector, toggle direction, and
assertion disposition. No denominator or bin was adjusted.

| Feature / requirement | Current implementation and elaboration | Testpoint and stimulus | Independent observation / checker | Gate 0 evidence and disposition |
| --- | --- | --- | --- | --- |
| AXIS ingress and sample packing | 14 signed Q1.15 complex samples per accepted beat, 125 MHz source | Random 56-word payload, frame markers and gains | Python fixed-point word oracle; accepted/output counts | Python vector generation PASS at current SHA; exact-source Generic bit-true PASS |
| AXIS bubbles and downstream backpressure | Ready/valid flow through frontend and four output planes | Source bubbles; PA-ready masks and stalls | Per-plane data/valid ordering, no loss/duplication | Exact-source UVM bubble/backpressure test PASS |
| CDC FIFO storage / reset | 16-entry dual-clock FIFO; generic and XPM implementations are separate configurations | FIFO boundary/full/empty, underflow guard, reset and replay | FIFO/stream checker plus reset assertions | Exact-source Generic boundary/empty/reset tests PASS; real XPM NOT AVAILABLE; raw CDC gaps remain in CSV |
| 14:8 gearbox and residual phase | 14 ingress lanes map to 8 core lanes; frame alignment quantum 56 samples | Legal aligned frame starts, FIFO residual and restart sequences | Accepted source words vs core/output words and frame boundary checker | Exact-source Generic PASS for tested aligned sequences; exhaustive residual state closure not claimed |
| Frame gain | Per-frame gain applied before interpolation | Three frame starts with gain values 16384/14336/12288 | Bit-true vector oracle | Current Python vector generation PASS; exact-source Generic bit-true PASS; gain line/condition/branch gaps remain in CSV |
| First centered-cubic x2 FIR | Phase 0 exact; phase 1 midpoint `[-1,9,9,-1]/16`, lookahead queue and frame-tail rules | Frame boundaries, gaps, stalls, tail drain/reset | Python integer oracle and output count; RTL assertions | Exact-source Generic bit-true/reset tests PASS; FIR residual assertion and code gaps remain |
| Second centered-cubic x2 FIR | Same centered-cubic operator after DPD | Sustained and multi-frame stream tests | Four-plane output against oracle | Exact-source 2,072-word qualification PASS; all 2,072 outputs checked four-plane bit-true |
| DPD hardware SKU | ZU15EG parent elaborates one memory tap, bypass off; reset coefficients implement identity | Normal payload and AXI-Lite commit scenarios | Python DPD fixed-point oracle; config readback/commit checks | Exact-source one-tap identity mainline bit-true PASS; do not infer 2/4-tap GT hardware from AXI-Lite test elaboration |
| DPD programmable coefficients / tap history | Generic AXI-Lite test top can elaborate up to four taps; not selected by GT parent | Coefficient transport, legal tap4 identity, nonlinear coefficient test, boundary commit | Register/coefficient oracle and output bit-true scoreboard | Exact-source AXI-Lite regression PASS; this is separate from the Generic URG hierarchy; 2/4 taps are not current hardware SKU |
| AXI-Lite access and WSTRB | Configuration/control wrapper, separate from direct Generic test top | Register access and partial-write / protocol cases | Register readback and protocol checks | Exact-source AXI-Lite test PASS; map per-run records before claiming full cross coverage |
| Commit and frame-boundary behavior | DPD commit is coordinated with packet/stream state | Commit while busy, safe frame boundary, pending commit and STOP | Config epoch/ack/status plus data oracle | Exact-source tests cover selected interactions; full matrix remains open |
| Four thermometric branches | `{+3,+1,-1,-3}*5120`, lockstep output planes | Positive/negative values, branch alignment, partial PA-ready | Four independent plane comparisons and atomicity checks | Exact-source qualification targeted rail/stall crosses: 4/4 each; not all legal branch-state combinations |
| EF2 chronological recurrence | Order 2, STEP 5120, 20-bit state, 22-bit temporary; 32-lane vectors preserve sample order; lookahead disabled | Random/sustained stream, clamps, clamp candidate under stall, reset/replay | Independent Python integer model; state hold and four-plane checker; scoped formal monitor | Exact-source three-seed 2,072-word PASS; four targeted crosses each 4/4; formal 6 assertions/3 covers PASS |
| EF2 positive/negative saturation and recovery | Saturating state/error arithmetic; clamp not assumed absent for arbitrary input | Positive/negative clamp, clamp during PA stall, reset, exact replay | Clamp monitor, state-hold checker, oracle | Exact-source targeted qualification PASS; detailed per-record coverage gaps remain in CSV |
| STOP / drain / restart | AXI-Lite start/stop control and packet drain | Stop during packet, drain first packet, block second, restart and drain second | 112 ordered four-plane outputs; underflow/protocol checks | Exact-source AXI-Lite STOP/restart PASS; separate elaboration |
| TLAST / malformed frame | Frame marker alignment and sticky protocol error | Legal multi-frame TLAST; negative early/misaligned frame | Output count, sticky error/reset and RTL assertion | Exact-source expected negative test PASS. One raw URG assertion trip is intentional and retained for review; see baseline |
| Reset during stall / pending frame tail | Reset clears interpolation tail and feedback epoch | Nonzero EF2 state, stalled tail, reset then replay | Four-plane oracle, no stale state/output | Exact-source Generic reset/replay PASS; raw/source-line gaps remain |
| GT user four-plane serialization boundary | Four lockstep 64-bit words at digital boundary | Serializer loopback and active-packet link-health fault in controllable parent model | Word-to-bit ordering, immediate PA blanking, sticky fault and reset recovery | Historical behavioral tests PASS; GT Wizard/TXP, real XPM, CDR/deskew and board are NOT tested here |
| Idle / output fault gating | GT parent gates PA enable and clears on reset contract | Idle and injected GT-health loss/recovery | Parent monitor observes PA enable and sticky fault | Historical substitute-model PASS; not vendor GT qualification |
| Code coverage | Raw Generic URG report hierarchy includes DUT, UVM TB/package, and interfaces | Exact-current raw report at verification SHA 04550289 | URG HTML/XML and parsed row inventory | Raw aggregate 76.12%; 784-row exact-source ledger. No audited DUT-only score and no closure claim |

## Testpoint completeness limits

The matrix records known named testpoints and evidence. It does not certify
that every required feature cross is closed. In particular, the existing raw
coverage contains 214 uncovered condition vectors, 108 uncovered branch
vectors, 100 uncovered source-line records, 292 signal-direction toggle
records, three unattempted assertions, and one negative-test assertion failure
requiring explicit disposition. The detailed per-row file is the coverage
ledger. A later Gate 3
review must establish which bins are required, legal, reachable, and applicable
to the fixed SKU without changing the raw denominator silently.

Gate 0 is **PASS for Linux Generic/behavioral scope** at verification SHA
`04550289e1ecb5fa0e38168869d4f2539929cb80`. Real XPM, XSim/Vivado, GT Wizard,
routed PPA, and physical RF remain unavailable or outside this host. No RX,
AI-DPD, or RF behavior is part of this matrix.

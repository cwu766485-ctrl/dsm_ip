# DE/DV Handoff Checklist — Compile-Time DSM Top

Current status: architecture refactor and bounded digital tests are complete.
CDC/RDC, full Formal, parent-level STA, routed PPA completion, UVM coverage,
serializer/GTY integration, and physical RF are not closed by this work.

## Next-stage closure matrix

| Area | Check | Classification | Required evidence |
|---|---|---|---|
| Architecture elaboration | Build `DSM_ARCH=0/1/2`; one selected branch only | Product requirement | Elaborated/synthesized hierarchy for all three; no other DSM/runtime backend |
| PA contract | EF1/EF2 mask `F`, four equal planes; MASH mask `3`, weights 1:2 | Product requirement | UVM PA monitor validates active-mask `valid/ready`, stable stalled data, inactive zero planes and lane ordering |
| AXI-Lite | RUN/STOP and DPD configuration remain; static DSM mode write is rejected | Product requirement | Read/write response tests, reset during outstanding transactions, DPD atomic-commit checks |
| AXI/Core CDC | Independent 100 MHz AXI-Lite and 218.75 MHz Core clocks | Real CDC / constraint contract | Stable mailbox payload through acknowledge, request/ack synchronizers, reset-epoch handling, CDC/RDC report, targeted STA constraints |
| AXIS/Core CDC | Independent 125 MHz source and 218.75 MHz Core clocks | Legal async FIFO structure, pending RDC review | XPM/Generic FIFO Gray pointer, reset synchronization, prefill/drain and pointer bus-skew checks |
| Reset domains | Global, AXI-Lite, Core, source, serializer resets | Real protocol risk until proven | Async assert/sync deassert, no stale epoch commit, no FIFO data leak, reset during traffic; formal and randomized UVM |
| Timing constraints | Parent clock source, board I/O budgets, reset paths, clock relationships | Constraint/model gap | Board XDC and `HD.CLK_SRC`; audit `check_timing`, `report_clock_interaction`, exceptions and unconstrained endpoints |
| Timing exceptions | Synchronizer first-stage and asynchronous reset endpoints only | Potentially legal when structurally verified | Cell attributes, exact endpoint list and CDC protocol; no broad asynchronous clock groups or false paths over functional data |
| EF2 path | 32-lane feedback is a measured product timing failure | Real design timing issue | Keep EF2 research only; mathematical/bit-true equivalence must precede RTL optimization |
| Formal | Reset epoch, atomic DPD commit, FIFO reset/busy, mode isolation | Not run for full compile-time product top | Shared legal clock/reset assumptions, non-vacuity, cover reachability and counterexample review |
| UVM | Long stream, frame/tail, random stalls, reset, FIFO boundaries, DPD commit | Bounded tests only so far | Shared PA scoreboard and coverage across all three build variants; no runtime-mode coverage claimed for static top |
| Serializer/GTY | 64-bit × 218.75 MHz = nominal 14 Gb/s per active lane | Not proven by this top-level simulation | GT Wizard config, bit-true serial mapping, continuous valid supply, underflow/overflow and dual-lane alignment |
| RF metrics | EVM/SNDR/BER/PSD/ACLR | NOT_RUN in this compile-time experiment | Receiver reconstruction from current PA stream; physical ACLR requires board RF measurement |
| Routed PPA | EF1/MASH new top | FAIL (setup); hold PASS, OOC only | Current DCPs and worst-20 reports exist. EF1 WNS/TNS −2.712/−6264.759 ns; MASH −2.818/−4411.104 ns. Shared centered-cubic Interp2-to-FIFO path; parent board constraints remain absent |
| VCS/UVM coverage | Required project VCS regression | BLOCKED here | Install/enable VCS; then run the canonical UVM regression and coverage closure |

## Distinguish findings correctly

- **Real bug:** data or metadata changes while stalled; wrong PA mask/weight;
  stale configuration or FIFO data crosses reset epoch; unhandled overflow or
  underflow; bit order differs from independent Golden; actual constrained
  synchronous timing path fails.
- **Constraint/model issue:** parent clock source or board I/O budget is absent;
  unrelated clocks are modeled as phase-related; a port is unconstrained; a
  report omits paths because clock definitions are missing. Fix the model or
  obtain the parent constraints; do not record product timing PASS.
- **Potentially legal structure:** XPM asynchronous FIFO Gray-pointer crossing,
  reset synchronizer first stages, and four-phase stable-payload mailbox. Each
  still needs the exact structure, protocol, reset contract, attributes, and
  targeted exception reviewed. Never bulk-waive CDC/RDC rows by count.

## Suggested execution order

1. Freeze the compile-time top sources and generated per-architecture vectors.
2. Complete EF1/MASH VCU118-part routed OOC experiments, then rerun from the
   parent board top once complete XDC and clock-source placement are available.
3. Audit all CDC/RDC warnings against the static selected hierarchy; remove
   runtime DSM-switch mailbox findings only if synthesis confirms that logic is
   pruned, while retaining AXI-Lite DPD and FIFO crossings.
4. Prove reset/epoch and DPD atomic-commit properties with a shared legal
   environment. Include cover goals for each reset and commit sequence.
5. Extend UVM tests to multiple frames and reset/backpressure boundaries for
   each compile-time build; preserve the independent scalar Golden.
6. Close serializer/GTY and receiver metrics separately; keep physical RF
   measurements distinct from digital reconstruction.

# EF1 + MASH DE release candidate frontier

Status at research HEAD `1e8f8347cf726703ff45a15524c10ca6a8dd8090`: **BLOCKED**. No release candidate commit or tag is authorized by the gate evidence below. Results are scoped to their actual RTL and constraints; live-running flows do not supply final results.

## Existing implementation evidence

| Case | Routed evidence | LUT / FF / DSP / BRAM | Status and qualification |
|---|---|---|---|
| EF1 cubic candidate | Setup WNS -0.352 ns, TNS -4.915 ns; hold WNS +0.005 ns | 47060 / 49852 / 496 / 6.5 | FAIL, prior OOC run. The -0.337 ns audit is a read-only experimental targeted exception, not an approved routed result. |
| MASH A | Setup WNS -0.333 ns; hold WNS +0.006 ns | 35927 / 47726 / 496 / 6.5 | FAIL, prior OOC run; local streaming equivalence has limited scope. |
| MASH B | Setup WNS -0.363 ns; hold WNS +0.004 ns | See A/B report | FAIL, prior OOC run; no product-level equivalence disposition. |
| EF1 + MASH | No matched routed implementation | Not measured | NOT_RUN |
| EF2 research | Original feedback timing failure; 4/8 lane proof inconclusive | See matrix | BLOCKED |
| Three-mode Runtime | No current matched full routed evidence | Not measured | BLOCKED |

The previous results are not new coordinated-reset candidate results or board-level signoff. For full constraints, source identity and A/B caveats see `ef1_mash_routed_timing.md` and `updated_signoff_matrix.csv`. The new matching candidate EF1/MASH queue is in `runs/de_abort_integration_sandbox/runs/abort_ppa_queue_02/`; EF1 is in route and MASH has not started. The research XDC's 4 ns mailbox constraint is not approved and OOC clock port `HD.CLK_SRC` is unspecified; parent clock/skew and pin assumptions need proof.

## Reset, CDC and formal gate

The selected system target is to abort the current frame and mute safely on any reset, then reconfigure before restart. An already presented AXI B response must remain stable until accepted; an aborted pending configuration is reported via status. The coordinated-reset wrapper and its external source/serializer reset ports are a research prototype. Parent reset and physical PA-enable wiring are unverified.

Original RTL has an independent-reset stale-pending witness. Candidate 3 alone changes active mode under AXI-only reset; coordinated reset avoids that situation only if the parent implements the documented reset/PA contract. The candidate combined mailbox run is **5/7**, with stable-sample and stable-active assertions inconclusive, all non-vacuous and 4/4 covers; fixed 16:35 clocks and reset setup disabled limit the proof. A longer run is in `runs/de_candidate3_combined_formal_deep_01/`. Independent reset/epoch, arbitrary relative phase and parent integration are not proven.

Runtime Generic structural CDC reports three output clock-cone errors; RDC reports 45,778 errors in 239 groups, no waiver. The earlier 10,539 errors were from a different frontend-only top. The grouped CSV and `reset_cdc_rdc_root_cause.md` are triage evidence, not a safe disposition. Board XPM CDC/RDC is still open.

## Limited digital functional evidence

Live MASH AXI-reset and Core-reset tests passed for a single prefetched frame followed by restart: 5,264 PA words and 336,896 TX and loopback bits per lane matched the independent Golden; post-reset EVM 2.551442%, SNDR 31.864285 dB, BER 15/37,376. The Core-reset test also held an accepted status-write B response; a pending configuration transaction during full-chain transmission was not covered. The test uses pattern search to locate the serial frame and a synthetic epoch. No physical RF/ACLR is measured. Longer randomized stalls, independently timed resets, fixed hardware serial alignment and actual board PA mute remain open. `de_functional_regression.md` lists logs and configuration.

## Handoff to unified UVM after DE gates

- Drive AXI-Stream, AXI-Lite, source/Core/serializer clocks and resets independently; check accepted write responses and sticky abort status, epoch changes and stale request rejection.
- Exercise STOP/drain before EF1/MASH mode selection, illegal mode writes under traffic, PA mask and per-plane weight metadata, frame/tail/config IDs, and backpressure without drops or duplication.
- Compare independently modeled EF1 and MASH payloads to all valid PA words and bit0-first dual-lane serial data; check 64 bits per 218.75 MHz cycle, prefill, full/empty, underflow behavior, reset and restart.
- Exercise sustained traffic and randomized timing, coverage closure, independent reset release and system PA mute. Keep digital EVM/SNDR/BER/PSD separate from physical RF measurements.
- Retain immutable Golden vectors, source/constraint hashes, per-test seed and logs; classify any missing evidence as BLOCKED or NOT_RUN rather than PASS.

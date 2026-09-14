# Update Log

## 2026-09-14 18:37 +08:00 — Cartesian x4/TI64 timing closure

- Replaced the unpipelined x4 vector polyphase FIR with a five-stage elastic
  implementation. Fixed-point arithmetic, rounding, saturation, history and
  lane ordering are preserved; latency increased.
- The final ZU15EG `TXUSRCLK2=218.75 MHz` routed build completed with zero
  errors and zero critical warnings: WNS `+0.387 ns`, WHS `+0.010 ns`, TNS/THS
  `0`, 20,835 LUTs, 21,203 FFs, 385 DSPs and 4 BRAM tiles.
- Checks: independent x4 bit-true XSim PASS; P0 XSim 7/7 PASS, 65,536 samples
  per test; five IP-smoke tests PASS.
- Remaining boundary: timing closure does not prove an SFP0 physical link,
  serialized word order, RF quality, or a 14 GHz RF carrier.

## 2026-09-14 18:45 +08:00 — Documentation consolidation and verification-first decision

- Consolidated current x4/TI64 design and implementation facts into `SPEC.md`
  and its required verification gates into `VPLAN.md`.
- Removed obsolete prototype, interview, resume, notebook, bridge, timing and
  duplicate evidence-index documents. `docs/exec-plans/` is deliberately
  unchanged.
- The next project milestone is digital verification closure before FPGA
  loopback or ASIC implementation.

## 2026-09-14 19:00 +08:00 - Stale experiment and generated-artifact cleanup

- Removed the unreferenced BP-EFDSM2 parallel/look-ahead/map-compose experiment family, its dedicated OOC launchers, testbenches/refmodels, raw-playback experiment, and RF7G MATLAB generator.
- Retained every static EDA task and its current source dependency: P0, IP smoke, TI64 core/frontend/x4 frontend, OOC, GT generation, and ZU15EG build flows.
- Removed explicitly scoped ignored Vivado/XSim/VCS caches, generated vectors, crash dumps, logs, and temporary PDF text; `.gitignore` now prevents their reintroduction.
- Checks: P0 XSim 7/7 PASS, IP smoke PASS, and Cartesian x4/TI64 frontend XSim PASS after cleanup. Restricted `fpga/hardware/`, `ads/`, and `data/` content was intentionally left untouched.

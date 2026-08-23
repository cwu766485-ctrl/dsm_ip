# Update Log

## 2026-08-23 - Public Repository Cleanup

- Removed local tool products, temporary databases, reports, caches, and
  generated waveform data from the working tree.
- Removed historical scope captures, board-replay outputs, duplicate RFSoC
  fragments, duplicate FPGA ROM images, and a generated MATLAB stage dump.
- Expanded `.gitignore` for technology collateral, board collateral, EDA
  caches, coverage databases, and implementation products.
- Removed local PDK path documentation, resume material, and redundant research
  notes from the public handoff.
- Rewrote the public documentation set in concise English and removed claims
  that exceeded the available evidence.
- Replaced stale coverage history with one current audit, portable commands,
  and an explicit open-item list.

## 2026-08-22 - ASIC Flow Bring-Up

- Added an ASIC pre-layout flow for the frozen SKU.
- Confirmed that local Design Compiler can start with an approved 28 nm
  standard-cell database, but the full flow still requires link-clean source
  and library configuration before it can be treated as a new PPA result.

## 2026-08-21 - Verification and Coverage Audit

- Recorded a 15-test, 20-seed frozen-SKU system-UVM regression with 300 passing
  runs and declared functional coverage at 100%.
- Added a source-linked coverage audit. Raw DUT code coverage remains below
  100%; only reviewed compile-time-disabled or defensive items may be waived.
- Added a random ready/valid test for the memory-polynomial DPD datapath.

## 2026-08-16 - FPGA Integration Baseline

- Created the ZU15EG integration, bare-metal, and ILA support structure.
- Preserved the distinction between OOC evidence and a complete routed/board
  closure for the current frozen SKU.

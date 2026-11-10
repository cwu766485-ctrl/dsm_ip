# Round 21 counter coverage acceptance proposal

Status: PENDING INDEPENDENT REVIEW. No exception or exclusion is active.
Date: 2026-11-10 (Asia/Singapore).

## Product responsibility

`dpd_memory_poly.v` exposes two unsigned 32-bit diagnostic counters. The
16-lane wrapper leaves both output ports unconnected; they are not AXI-Lite
registers or a software-visible telemetry interface. Current RTL increments
sample_count on accepted input (`pipe_ce && in_valid`) and saturation_count
on enabled valid output with either rail saturated. Reset is asynchronous,
active low. Both wrap modulo 2^32. There is no lifetime bound that makes high
bits unreachable, and neither counter saturates at all ones.

This description records the implemented contract, not new product-owner
approval. The owner must explicitly accept whether unused internal telemetry
needs system-level exhaustive toggle coverage. If these outputs become public,
this proposal must be reconsidered and a software overflow/readout contract
specified. No RTL/interface behavior changes in this round.

## Independent block evidence

Run `bash dv/verif/block/dpd/run_memory_poly_counter_contract_vcs.sh` with
VCS_HOME set and a fresh THERMO5_OUT. The test checks independent fixed-point
output values, sample counts, I/Q saturation event totals, full-pipeline
backpressure hold, asynchronous reset before the next active edge, 31 binary
carry boundaries, and all-ones wrap for both real 32-bit registers.

Boundary cases deposit the isolated DUT counter registers immediately before
increments. This accelerates arithmetic verification; it does not demonstrate
legal reset-to-high-bit system reachability and must never enter product URG.
The block runner disables coverage collection and produces separate logs.

## Requested decision

Review the exact 930 residual directions in the R20 counter ledger (464 sample,
466 saturation). Requested acceptance is a scoped system-level coverage
exception supported by block arithmetic evidence, not PROVEN_UNREACHABLE.
Counters remain legal and reachable. No wildcard, entire-instance exclusion,
or removal of the counters is requested. Preserve the raw denominator and
report exceptions separately from approved unreachable/configuration bins.

Required approval record: reviewer identity, independent role, exact ledger
SHA-256, product source/configuration fingerprint, acceptance rationale,
linked block logs and hashes, explicit 930-bin scope, and approval reference.
Until that record exists, approved exceptions=0 and all 930 remain OPEN.

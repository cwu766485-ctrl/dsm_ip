# DSM V1.3 UVM Baseline Audit

Date: 2026-11-25
Branch: `work/dsm-v13-mash-uvm-round1`
Baseline commit: `c8fe4299e4d87ead3daca41800ce6c331e6c0ea6`

## Scope and isolation

This work was performed in `/home/ray/workspace/dsm-v13-mash-uvm-round1`, a
separate worktree created from the baseline commit. The active
`/home/ray/workspace/dsm_ip_cdc_rdc` Round 13 worktree was not used or modified.
Product RTL was not changed. Generated builds, VDBs, vectors, logs, and reports
remain under ignored `runs/dsm_v13_round1/`.

The repository branch contains the Thermo5 EF1/EF2 Product verification tree;
it does not contain a MASH Product Top. The MASH 1-1 core and legacy
`mash11_multipa_tx` wrapper were taken byte-for-byte from source revision
`8d260dacbece071bc3f53546fd2b2ee3d08c64cb` into the ignored run directory.
Their source hashes and import provenance are recorded in
`docs/verification/data/dsm-v13-round1/source_manifest.json`.

## Existing verification baseline

The UVM source of truth is `dv/uvm/sim/thermo5_sku_filelist.f`. The existing
Thermo5 environment already has reusable AXIS source, AXI-Lite configuration,
PA output, and scoreboard components. Its Product top elaborates EF1 or EF2
through `DSM_ARCH`; the common product suite checks 32 accepted input beats,
56 PA output words, all four 64-bit output planes, frame metadata, FIFO empty
and full behavior, stalls, reset, and configuration mailbox behavior.

Two verification-only baseline defects were found and fixed in this branch:

1. The reset test queried an EF2-only hierarchy even when EF1 was selected.
   A SKU-neutral state-zero observation now checks the state appropriate to
   the elaborated architecture. Free-running payload pipeline registers are
   not included in that state check.
2. The short FIFO-empty test reused a full-frame oracle. A dedicated vector
   generator now produces the exact seven-word short frame used by that test.

These fixes changed no Product RTL or output contract. The old failing attempts
are retained in the ignored run tree and are not counted as passing evidence.

## MASH source and interface audit

The imported wrapper instantiates exactly one `dsm_core_mash11` and exposes
`in_valid`, signed `if_sample[15:0]`, `out_valid`, two stage bits, and a signed
3-bit combined level. It has no `in_ready`, AXIS framing, AXI-Lite registers,
FIFO, reset epoch tag, four-plane PA interface, or serializer. Its `in_valid`
is the state advance enable and the wrapper registers `out_valid` from it.
Consequently, its UVM result proves only this block-level synchronous
always-accept contract; it does not integrate the block into the Thermo5
Product datapath.

The verified experiment uses `W=16`, `ACC_W=18`, `IN_SHIFT=0`, and saturating
accumulators to match the legacy MATLAB P0 invocation. The RTL default
accumulator is 28 bits, so the experiment's 18-bit setting is explicit and
must not be generalized to an eventual product SKU without approval.

The independent Python model uses state/transaction equations instead of
mirroring the RTL process structure. It implements ideal floating point,
signed fixed point, saturation or two's-complement wrap, two quantizer stages,
delayed first-stage error, and the delayed second-stage cancellation combiner.
It generates expected transactions and vectors for the SV UVM scoreboard.
Mutation tests alter output level and transaction order and confirm the Python
oracle comparison rejects both. This mutation check does not inject a fault
into RTL or directly mutate the compiled SV scoreboard.

## Current-run baseline

Fresh VCS and URG runs used VCS/URG V-2023.12-SP1 on Rocky/WSL2 Linux with
Python 3.12.13 and NumPy 2.5.5. `dsm-v13-multi-sku-regression` ran EF1, EF2,
MASH block, and separate EF1/EF2 AXI-Lite configurations. The main log records
compile-time selector values 1, 2, and 3. Each configuration elaborated one
selected DUT. All expected positive tests passed with zero UVM warnings,
errors, and fatals; the expected-negative frame protocol test observed the
specified sticky error and was reported separately.

The original default `thermo5_sku_uvm_tb` top was also freshly rebuilt and run
through `thermo5-vcs-regression` for EF1 and EF2. Both old entry points passed,
including the expected-negative protocol case. Their logs are retained under
`runs/dsm_v13_round1/legacy_compat/`.

The complete Python reference suite passed 72/72. Full MASH logs, test VDBs,
coverage reports, generated vector manifests, and SHA-256 digests are indexed
in `docs/verification/data/dsm-v13-round1/`. Detailed outcomes and limits are
in `docs/dsm_v13_round1_report.md`.

## Remaining baseline gaps

- No MASH Product top or SKU-level interface/register/PA mapping contract is
  present in this branch.
- No MASH product AXIS agent, AXI-Lite sequence, PA-plane/serializer scoreboard,
  or product reset epoch regression can be meaningfully run until that contract
  and RTL integration exist.
- The MATLAB oracle runtime was not available. Static inspection found the
  MATLAB `model_mash11` output register and wrapper output timing need a
  product-level latency decision; see `docs/dsm_v13_sku_contract.md`.
- Constrained-random budget, coverage closure targets, Formal, CDC/RDC,
  synthesis/PPA, calibrated RF metrics, and hardware receive-chain BER are not
  closed by this round.

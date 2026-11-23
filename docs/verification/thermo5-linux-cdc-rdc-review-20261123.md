# Thermo5 Linux CDC/RDC review — 2026-11-23

## Status and scope

**CDC OPEN; RDC OPEN; reset formal OPEN; DE freeze OPEN.** The product RTL and
constraints used here are those of commit `2bbe3b94ce1a0c6f33176d0da45c56916c95ce06`.
The accompanying new files are a review matrix, a DPD-lane harness, and a VCS
filelist generator; no product RTL or constraint was changed. Raw reports and
logs are preserved in the separate local `runs/linux_cdc_rdc_round2/` directory.
Original raw findings and source fingerprints remain in
`thermo5-linux-cdc-rdc-bringup-20261123.md`.

The GitHub remote at start had six heads: `main`, `thermo5`, `thermo5-ef1`,
`thermo5-ef2`, `thermo5-mash11`, and the existing independent work branch. The
five long-lived branches were not changed or deleted.

## CDC — exact paths and unresolved analysis

`data/thermo5-linux-cdc-rdc-20261123/cdc_error_path_matrix.csv` retains each of
16 native EF1/MASH IDs, original complete path message, file, line, preliminary
assessment, and OPEN status. The exact cross-domain findings are:

- Two `Ac_cdc01a` reports per architecture use read-pointer Gray source
  registers crossing core to source clock; a third uses the internal XPM FIFO
  read-reset synchronizer. The reports state generic fast-to-slow data-hold
  failure. These are pointer/reset synchronization paths; the ordinary
  bundled-data request/ack contract cannot be assumed to describe them.
- Three `Ac_conv02` reports are Gray-to-binary reconvergence; `Ac_conv04` is the
  FWFT extended write-pointer Gray check. The XPM FIFO contains four distinct
  `xpm_cdc_gray` pointer instances. The configured `CDC_SYNC_STAGES=2`; the
  FWFT extended write path uses `CDC_SYNC_STAGES+2`. Gray source encoding is
  registered before `dest_graysync_ff[0]` and converted to binary after the
  last stage in the installed XPM source. The extended read path uses a FWFT
  adjustment, so its single-step behavior must be separately verified rather
  than inferred from the name.
- `Reset_sync02` flags source local reset feeding `wr_reset_in_rd[0]` in the
  core clock domain. The wrapper asynchronously asserts and synchronously
  releases the two-stage read guard, and masks `rd_valid` until it releases.
  The shared-epoch parent contract, pulse width, write-clock progression,
  FIFO busy behavior and stale-data exposure still require end-to-end proof.

`run_ppa_abort_candidate_resetfix_xpm_v10.tcl` contains per-Gray-instance
`set_max_delay -datapath_only` and `set_bus_skew` bounded by source-clock period;
it discovers source registers and first destination stages. This is evidence
of intended constraints, **not** proof that the final routed parent resolves
all relevant endpoints or retains those constraints. Review the exact current
netlist, report exceptions and routed bus skew. CDC rule findings remain OPEN;
no tool issue or RTL bug has been conclusively ruled in or out.

## RDC — all paths retained, no blanket dispositions

`ef1_rdc_exact_paths.csv.gz` and `mash_rdc_exact_paths.csv.gz` retain each
native report ID, source location, complete source/destination/reset message and
OPEN status. The corresponding `*_rdc_review_matrix.csv` files provide
preliminary ownership and evidence needed per destination location; these are
not proof-based classifications. EF1 4,417 and MASH 5,125 errors are reconciled
to 93 and 94 locations respectively. No raw messages are waived.

In particular, `dpd_memory_poly.v` asynchronously clears `valid_pipe`, while
some data/coefficient pipeline registers are intentionally unreset. A resettable
control register feeding unreset payload is not automatically a bug or safe:
valid provenance alone does not prove payload correctness, absence of stale
output at system level, or reset recovery of upstream FIFOs and metadata.
Mailbox and frame/reset behavior must be assessed by actual cones even when
this raw location grouping has no separate mailbox destination row.

## Formal and reset

The new `formal_dpd_reset_epoch` harness instantiates one actual 16-bit,
`MAX_TAPS=1` DPD lane and a resettable reference valid shift register. It
checks valid provenance and reset clearing under arbitrary valid/ready, with
covers for abort while in flight, post-abort output, and stall. It does not
prove the DPD numeric payload or the product/FIFO/frame/PA chain.

VC Formal reported two proven assertions (`a_reset_clears` marked non-vacuous;
`a_epoch_valid` is a direct equality), and three covers at depths 3, 13, 13.
Power-on `por_n` is held high after initial reset; `epoch_n` is unconstrained.
**Not accepted as formal closure:** the enabled reset setup check reports one
group (`epoch_valid`, `dut.valid_pipe`) whose reset can remain active during
formal, expected to be examined because dynamic abort is the target. The check
was not disabled; no conclusion that this is harmless or a design bug is made.
The result does not establish EF1/MASH PA contract or whole-system data epoch.

## Current-source rerun

| Architecture | CDC errors/warnings | RDC errors/warnings | XPM UVM directed run |
| --- | --- | --- | --- |
| EF1 | 8 / 81 | 4,417 / 74 | 56 words match, mask f, PASS |
| MASH | 8 / 83 | 5,125 / 76 | 56 words match, mask 3, weighted, PASS |

Both UVM logs have zero errors and fatals. These tests use seed 610216, 32 AXIS
beats, Identity DPD and independently generated Python bit-true vectors.
They exercise partial PA backpressure and one run, but not reset-during-flight,
full random regression or analog behavior. Standalone synchronizer VCS reset
contract also passed (6 epochs, 18 releases, 27 checks). Separate
`rtl/axis/dsm_reset_sync.sv` and `dv/verif/reset/tb_thermo5_reset_release_contract.sv`
are the complete compilation inputs for that test. An initial VC Formal and VCS
attempt failed during license connection; successful retries are separate and
are the only new results quoted here. The first EF1 CDC retry timed out at 60s;
a second fresh-directory retry completed. Shell exit status alone does not
establish SpyGlass success.

## Reproduce from this worktree

```sh
export VIVADO_ROOT=/mnt/d/AMDDesignTools/2026.1
export THERMO5_CTIME_ROOT="$PWD"
# Run each combination with a new, nonexistent output directory.
export THERMO5_CTIME_ARCH=0  # 2 for MASH
export THERMO5_CTIME_GOAL=cdc/cdc_verify  # or rdc/rdc_verify_struct
export THERMO5_CTIME_OUT="$PWD/runs/NEW_SPYGLASS_DIR"
/opt/Synopsys/spyglass/V-2023.12-SP1/SPYGLASS_HOME/bin/sg_shell \
  -tcl research/vcu118_arch/run_compiletime_spyglass.tcl

export THERMO5_FORMAL_ROOT="$PWD"
export THERMO5_FORMAL_OUT="$PWD/runs/NEW_FORMAL_DIR"
/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf -batch -fmode FPV \
  -f research/vcu118_arch/formal_dpd_reset_epoch.tcl

python3 dv/uvm/refmodel/python/generate_thermo5_runtime_vectors.py \
  --output-dir runs/NEW_VECTORS --words 56 --seed 610216
python3 tools/hw/thermo5_compiletime_vcs_filelist.py \
  --output runs/NEW_FILELIST.f --vivado-root "$VIVADO_ROOT"
mkdir -p runs/NEW_VCS_DIR
/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -full64 -sverilog -ntb_opts uvm \
  -timescale=1ns/1ps +define+THERMO5_XPM_FIFO+COMPILETIME_ARCH_0 \
  -f runs/NEW_FILELIST.f -top thermo5_compiletime_uvm_tb -top glbl \
  -Mdir="$PWD/runs/NEW_VCS_DIR/csrc" -o "$PWD/runs/NEW_VCS_DIR/simv" \
  -l "$PWD/runs/NEW_VCS_DIR/compile.log"
# Use COMPILETIME_ARCH_2 and a separate directory for MASH.
cp runs/NEW_VECTORS/*.mem runs/NEW_VCS_DIR/
(cd runs/NEW_VCS_DIR && ./simv +ntb_random_seed=610216 -l simulation.log)
```

All four reruns used the original SGDC SHA-256
`84bfa1507572d5ee0c0f83f12021e4e76bbf02a39886587b534573ac8b399c2d` and
flow Tcl SHA-256 `4a7b12a92fa7e1b4949acbf5277feba21ea78a37a4e589a4e4be014aaaec4af3`.
The generated VCS filelist SHA-256 is
`b4b75c6332b556312e35faef7c9f0f2429df50d8e5dfc240e746e57a5be31843`;
the committed generator reproduced it byte-for-byte in this worktree.
The four raw report hashes (EF1 CDC, EF1 RDC, MASH CDC, MASH RDC) are
`6b046befa631ae3aa7a67c76efd1f35324b487bdc8f8eec41fe9c4f517787d4a`,
`a4b33a9ef47469ca5e10ce66e6035daabcb02257d341b4026fc2ee1983179fca`,
`0ccc9f6cfd166c903eb04efa21d5e9118d0f0aa9b88b579ea53d8aae5b2bc480`, and
`16da1222c6cc3da826af39a5a590a6be5f075b5fb6239534ee3147fbaadad10b`.
Formal property/setup hashes are
`3fcd6b9001baf7dd0db9b718560f519943c5100bfdb43bdc595ee127fa59639f` /
`aa7df4381204c2389837292659a2624fbe7acb31a87c00394ccb0a0bddb5f2e2`.
EF1/MASH UVM log hashes are
`9a5a46b700948be7e8f7addcdfe85c52f085b1af9178f13a6398cb5346b09d7d` /
`83123e12f2ecc5d4a2dbd78ed9c9ef8496a79c800f663f47da3423d10d6792bf`.

## Readiness decision

No RTL changes means this round introduces no new latency, II, AXIS or PA
contract change; it also supplies no new post-route timing evidence. Prior
positive OOC slack is below the requested +0.15 ns reserve, and parent timing,
physical CDC/RDC, board and RF remain unverified. Required next work is an
independent path-by-path CDC/RDC disposition, corrected reset-formal setup and
end-to-end abort/FIFO/commit/epoch assertions, full scenario regression, and
review of final routed timing against the actual final RTL and constraints.

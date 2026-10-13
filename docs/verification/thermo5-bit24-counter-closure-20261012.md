# Thermo5 counter bit24 long-stream closure (2026-10-12)

## Status at 10:50 SGT, 2026-10-13

The 16,777,222-word MATLAB-fixture-validated oracle is in
`runs/thermo5_bit24_oracle_20261012/`. Generic FIFO VCS/UVM seed610704 and its
separate same-binary URG plus per-lane delta audit now PASS. A fresh 56-word
XPM bit-true VCS smoke seed610709 also PASSed, confirming license checkout.
The first fresh XPM attempt seed610708 was stopped after47 CPU seconds because
the simulator repeatedly blocked in WSL `p9_client_rpc` while reading the
2.5 GB vector directory from `/mnt/e`; exit255 and its partial VDB are
excluded. The eight unchanged oracle `.mem` files were staged to
`/tmp/thermo5_bit24_xpm_610710/vectors`, and a new XPM bit24 long run seed610710
is now active with VDB `cov_thermo5_sku_long_counter_test_seed610710.vdb`.
Its automatic finalizer will merge only the XPM VDB set with URG and audit
all16 XPM `.u_dpd` counters. Previous XPM seeds610705-610707 also remain
excluded. Overall raw code coverage is still OPEN and has not reached100%.

## Oracle and generic result

`tools/hw/thermo5_range_oracle.py` generated all eight source/output files in
bounded chunks. The eight-file MATLAB fixture comparison, record counts and
SHA-256 manifest checks passed before simulation. No RTL or MATLAB arithmetic
was changed.

Generic seed610704 used `thermo5_sku_long_counter_test`,
`+CORE_WORDS=16777222`, `+EXPECT_SIGNED_EXTREMES`, and full line/condition/FSM/
branch/toggle/assert coverage on the generic build. It PASSed:

- `THERMO5_SKU_UVM_PASS source=9586984 output=16777222 four_planes=bittrue`
- `THERMO5_LONG_COUNTER_RESET_PASS`: all16 DPD lane counters cleared after
  the checked stream and public reset.
- UVM_ERROR=0, UVM_FATAL=0; source functional coverage100%, core coverage87.5%.
- VCS CPU time:11512.180s.

Evidence: `runs/thermo5_bit23_vcs_generic_20261012/`, log
`thermo5_sku_long_counter_test_seed610704.log` and VDB
`cov_thermo5_sku_long_counter_test_seed610704.vdb`.

The generic same-binary URG report and exact bit24 audit completed on
2026-10-13. `bit24_delta_audit/summary.json` reports 16 distinct lane
instances and both toggle directions in all16. The merged raw hierarchy score
is87.01% (line87.09, condition76.46, toggle85.50, FSM100, branch73,
assertion100); it must not be described as100% raw code coverage. Evidence:
`coverage_bit24_after/` and `bit24_delta_audit/`.

## Real-XPM run and audit gates

The first concurrent XPM seed610705 attempt was terminated before completion
after memory pressure; its partial log/VDB is excluded. A serial retry with
seed610706 later received SIGHUP when its foreground session ended and has no
completion markers; it is excluded too. Detached seed610707 had an explicit
VCS license-server connection failure (exit255) before UVM test start, so it
is not a design/UVM failure and its VDB is excluded. Resume with a fresh
seed/VDB only after license checkout is confirmed by a small licensed
compile/run in the execution shell.

The generic-only merger
`runs/thermo5_bit24_oracle_20261012/merge_generic_bit24_urg.sh` has now
completed with exit0 and produced the report and bit24 delta audit. The XPM
short smoke used the already-built real-XPM binary, 56-word MATLAB bit-true
test, seed610709, and a separate smoke VDB; it PASSed with UVM_ERROR/FATAL=0.
The initial seed610708 attempt was abandoned due to `/mnt/e` 9P filesystem
I/O stalls. The restart seed610710 uses a fresh VDB and reads the unchanged
oracle files staged on WSL ext4; its detached finalizer waits for the test
result, then performs XPM-only URG and the bit24 lane audit.
`tools/hw/thermo5_long_counter_delta.py --bit 24` must report both toggle
directions in all16 `.u_dpd` instances independently for each FIFO. No
cross-FIFO merge is permitted.

Bit23 already passed on both binaries: each had 8,388,611 four-plane words,
all16 lane counters reset, and same-binary URG deltas showing both bit23 toggle
directions in all16 lanes. Its record is
`docs/verification/thermo5-bit23-counter-closure-20261012.md`.

## Remaining coverage boundary

Generic bit24 is closed by URG and the 16-lane audit; XPM bit24 remains OPEN
until seed610708, its separate URG, and the XPM 16-lane audit complete.
Bits25-31 remain reachable and OPEN; bit31 requires a multi-day natural
stream at the measured simulator rate. Other fixed-configuration RTL and XPM
model bins and the XPM FWFT `stage1_valid->invalid` transition remain OPEN or
require exact per-bin review. The FWFT edge-observed 400-point reset search is
search evidence, not an unreachability proof; no blanket or FWFT waiver was
added. Raw100% code coverage is not claimed.

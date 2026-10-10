# Two AXI-Lite commit bug reproductions

Validated on 2026-10-06 with Vivado 2024.1 XSim and Synopsys VCS
V-2023.12-SP1. The historical corrective commit is
`6deb79903b80a01a8d03b97afe71a247c7319c60` in
`rtl/axi/dsm_ip_axi_top.v`.

The runner reconstructs two historical failure mechanisms on copies of the
current wrapper in an isolated run directory. These copies are not whole
historical revisions. Canonical RTL is unchanged. All stimulus uses legal
AXI-Lite transactions and, for the busy-commit case, an accepted AXIS sample;
the checker never forces DUT state.

## Case 1: stale rejection contaminates a valid commit

1. Enable coefficient safety (`0x40=0x100`), select coefficient storage
   (`0x90=0x400`), write an unsafe coefficient (`0x94=0x6001`), and request
   commit (`0x98=1`). Check that this transaction is rejected.
2. Disable safety (`0x40=0`), write a valid identity coefficient
   (`0x94=0x4000`), and request another commit without first clearing the
   sticky rejection indication.
3. Require the new transaction to acknowledge successfully, with failed=0,
   epoch=1, and active bank=1.

The old failure predicate observes the previous sticky rejection before the
new core commit pulse has cleared it. It incorrectly fails the new request.
The corrective predicate includes `!mp_commit_pulse`, preventing stale
rejection from being treated as the result of the newly issued transaction.
Removing only this guard reproduces `BUG_STALE_REJECTION`; current RTL
passes the same sequence.

## Case 2: reset does not cancel a busy commit

1. Complete one commit, establishing bank=1 and epoch=1.
2. Enable memory-DPD and the core, accept one AXIS sample, and request a
   commit while the datapath is busy.
3. Issue the following legal control write with soft reset. Check that reset
   overlaps pending/inflight state, then require the transaction to be
   cancelled: epoch stays 1, pending/inflight/ack/failed clear, bank resets 0.

The reconstructed old wrapper keeps pending/inflight state through reset and
can later interpret bank equality as successful completion. It reports
`epoch=2 ack=1 bank=1`, despite the intervening reset. The fix gates completion
with `!soft_reset` and explicitly cancels pulse, pending, inflight, ack,
failed, and target-bank state on soft reset. Current RTL passes with
`overlap=1 epoch=1 transaction_cancelled=1 bank=0`.

This sequence proves cancellation during a busy transaction. It does not
claim that bank switching and reset complete in precisely the same cycle.

## Evidence and reproduction

| Simulator | Fixed stale rejection | Faulty stale rejection | Fixed reset cancellation | Faulty reset cancellation |
| --- | --- | --- | --- | --- |
| XSim | PASS | expected failure detected | PASS | expected failure detected |
| VCS | PASS | expected failure detected | PASS | expected failure detected |

Machine-readable manifests include commands, exit codes, staged source
SHA256, current wrapper SHA256, and individual logs:

- `runs/commit_bug_repro_20261006_06/summary.json`
- `runs/commit_bug_repro_vcs_20261006_01/summary.json`
- Latest complete-package VCS repeat:
  `runs/thermo5_dv_package_delivery_20261006/bugs/summary.json` (PASS for
  both fixed cases and both detected historical negative controls).
- Fresh DV/DE delivery repeats: `runs/commit_bug_repro_delivery_vcs_20261006/summary.json`
  and `runs/commit_bug_repro_delivery_xsim_20261006/summary.json`: both PASS.
- Restored-license real CI37462007850 repeats all four VCS controls PASS:
  `runs/thermo5_real_ci_37462007850/bugs/summary.json`.

## Interview walkthrough

| Trigger | Incorrect behavior | Root cause | Fix | Independent check |
| --- | --- | --- | --- | --- |
| Reject one unsafe coefficient, then commit a legal identity value without W1C | New legal request is failed | Sticky status belongs to the previous transaction; wrapper samples it while issuing a new pulse | Qualify failure with `!mp_commit_pulse` | AXI readback must show ack, failed=0, epoch=1, bank=1; guard removal must fail |
| Commit while datapath busy, then soft reset | Cancelled transaction later acknowledges and advances epoch | Pending/inflight survive reset and bank equality is mistaken for completion | Reset cancels transaction state; completion requires `!soft_reset` | Observe real overlap, require epoch remains1 and bank0; old completion/cancellation behavior must fail |

Explain the transaction timeline first, then the root cause and the minimal
predicate/state fix. Both examples use legal public bus traffic, source hashes,
two simulators and negative controls. Distinguish reconstructed failure
mechanisms from checking out an entire historical revision.

Run from the repository root, choosing a new output directory:

```powershell
python dv/uvm/sim/run_commit_bug_repro.py --simulator xsim --out-dir runs/commit_bug_repro_review_xsim
wsl.exe -d Rocky-8.10 --cd /mnt/e/workspace/chip/dsm_ip -- bash -lic 'python3.12 dv/uvm/sim/run_commit_bug_repro.py --simulator vcs --out-dir runs/commit_bug_repro_review_vcs'
```

The testbench is `dv/uvm/tb/tb_dsm_commit_bug_repro.sv`. This is a directed
control-plane regression with negative controls, separate from thermo5
coverage closure and GT/hardware signoff.

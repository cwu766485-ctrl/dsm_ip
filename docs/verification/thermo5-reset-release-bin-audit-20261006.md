# Thermo5 reset release condition bin audit (2026-10-06)

## Scoped formal disposition (2026-10-06)

The production `dsm_reset_sync` is instantiated in
`dv/uvm/formal/thermo5_gap_harness.sv`. A runtime reset request remains
unconstrained, but a verification-only driver changes `arst_n` on the
falling local clock edge. VC Formal proves three assertions, all
non-vacuous: held reset clears stage0, held reset clears output, and released
output requires stage0. Four normal covers (held reset, first release,
released state, and runtime reassert/release) are covered. The exact
`!arst_n && sync_q[0]` collision cover is **uncoverable in this model**.

The reviewed run is
`runs/thermo5_dv_package_delivery_20261006/formal/reset/properties.txt`;
the runner gates zero black boxes, setup issues, assertion results,
cover classification, and vacuity. Focused VCS at
`runs/thermo5_reset_bin_audit_vcs_20261006_current/` separately passes
two epochs per domain and two-edge release with zero `1/0` samples.

This closes the analysis within the stated stable off-edge-reset contract.
Both raw full-chain URG rows remain visible and unhit. The proof excludes
same-slot active-edge assertion, recovery/removal, and metastability; it is
not a blanket asynchronous reset/CDC signoff. The same parameter-free reset
RTL is used for source and core domains, which the focused simulation checks
separately. Historical failed-tool notes below are superseded.

## Scope

Investigate the two frozen generic URG condition rows at line 27 of
`rtl/axis/dsm_reset_sync.sv`:

| Instance | Expression operands | Frozen status |
| --- | --- | --- |
| `thermo5_sku_uvm_tb.dut.u_cdc.u_s_reset` | `!arst_n=1`, `!sync_q[0]=0` (`1/0`) | `Not Covered`, `OPEN_RESET_RELEASE_REVIEW` |
| `thermo5_sku_uvm_tb.dut.u_cdc.u_c_reset` | `!arst_n=1`, `!sync_q[0]=0` (`1/0`) | `Not Covered`, `OPEN_RESET_RELEASE_REVIEW` |

The neighboring `1/1`, `0/1`, and `0/0` rows were already hit in the frozen
regression. This experiment focuses on state reachability and local release
timing, not CDC/RDC signoff.

After this attempt, the exact URG disposition is unchanged: there is no new
VCS VDB, so neither `1/0` row was remeasured. The XSim observation is listed
below as separate state/timing evidence and does not relabel these rows.

## State and timing analysis

The bin requires sampling a rising edge with `arst_n==0` and old
`sync_q[0]==1`. The asynchronous reset branch sets `sync_q` to `2'b00` as
soon as `arst_n` falls. If assertion is separated from the next active local
clock edge, stage 0 is already zero when the assertion line samples, so the
legal reset-held sample is `1/1`. Following asynchronous deassertion, the
first local edge samples `0/1` and schedules `sync_q=01`; the second samples
`0/0`, schedules `sync_q=11`, and releases `srst_n` after that edge.

Therefore `1/0` can only arise if asynchronous assertion and the local active
edge are scheduled in the same simulator time slot, letting the assertion
sample the pre-clear stage-0 value. That is a scheduling collision, not a
stable reset-held state. It is deliberately not used as closure stimulus.

## Directed artifact and result

`dv/verif/block/axis/tb_thermo5_reset_sync_release_audit.sv` instantiates the
unchanged reset synchronizer at the same hierarchy path names, runs separate
source/core clocks, checks asynchronous assertion and two-edge release for
both domains, and counts samples of the `1/0` operand pair. The run script is
`dv/verif/block/axis/run_thermo5_reset_sync_release_audit.sh`; its default
output is `runs/thermo5_reset_bin_audit_20261006_05/`. It records tool
path/version and non-secret architecture selection, without printing license
variable values.

The first VCS attempt at `_01/` used the Rocky login shell's selected
configuration (`VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1`,
`VCS_ARCH_OVERRIDE=linux`) and could not find the selected `linux` compiler.
Attempts `_02/` and `_04/` overrode architecture to `linux64`; VCS rejected
the WSL kernel before compile. Attempt `_03/` overrode `VCS_HOME` with an
invalid architecture subdirectory. These overrides have been removed from
the runner. The main frozen regression passed earlier today under the normal
Rocky setup, but its VDB does not include this focused test. No further VCS
run was made after the environment review because license connectivity was
failing.

Vivado 2024.1 XSim did run the focused test successfully at
`runs/thermo5_reset_bin_audit_xsim_20261006_01/console_xsim.log`, with two
reset epochs per domain, exactly two local rising edges to release each
reset, and zero reset-low/stage0-high samples. This supports the state/timing
analysis only. URG still needs a fresh VCS VDB; both frozen rows remain
`OPEN_RESET_RELEASE_REVIEW`. No CDC/RDC closure is claimed.

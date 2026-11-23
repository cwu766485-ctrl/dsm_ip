# Thermo5 Round 3 — Generic AFIFO assessment, 2026-11-23

## Decision

**Candidate only; no replacement or closure signoff.** RTL baseline is commit
`2fc960a` and the tested Generic source SHA-256 is
`1af57d6d8810cbf882add01ce4a268df94244a4dfb827694f3f0328b29012e61`.
The flow-script change only allows an explicit `THERMO5_CTIME_XPM=0` analysis;
it does not alter the product RTL or default XPM configuration.
The previous XPM findings remain open. Generic and XPM are different
elaborations: a smaller error count in one cannot close a finding in the other.

## FIFO implementation and prior verification

`dsm_async_fifo.sv` implements a depth-16 FIFO at the default `ADDR_W=4`, with
binary and Gray pointers, two local-clock synchronization stages in each
direction, registered full/empty and combinational memory read. The
compile-time frontend selects it with `FPGA_USE_XPM_FIFO=0`. The ingress
wrapper masks AXIS ready while its local reset is asserted; FIFO read and write
pointers each use a local reset. Earlier Generic FIFO UVM and directed tests
exist in the repository, but must be interpreted against the source/configuration
fingerprints in their respective reports.

The XPM configuration uses a synchronous write-clock reset and reset-busy
handshakes, block-memory selection and FWFT behavior. In contrast the Generic
FIFO has no XPM reset-busy contract, and an asynchronous array read may map to
LUT/distributed memory or other resources; its actual implementation requires
synthesis evidence. Simulated bit equality of accepted words does not establish
identical per-cycle ready, occupancy, startup, BRAM use, timing or CDC safety.
The Generic FIFO synchronizer registers have no explicit `ASYNC_REG` RTL
attribute. The current compile-time XPM PPA flow names XPM synchronizers;
`run_ppa_abort_candidate_resetfix.tcl` is an older Generic flow that uses
false paths to Gray first stages. Its use in any final build and additional
max-delay/bus-skew constraints must be audited. Do not infer multi-bit Gray
physical safety from a false path or simulation alone.

## Current-source checks

| Check | Result and scope |
| --- | --- |
| Generic FIFO full/reset VCS | PASS: 16-entry full, pending write, reset, 64 post-reset words checked |
| Generic FIFO skew-epoch VCS | PASS: six epochs, two release orders, 384 recovered words, full before reset |
| Generic product EF1 XPM-disabled UVM | PASS: 32 ingress beats, 56 PA words, independent precomputed integer reference, mask `f`, Identity DPD, partial ready |
| Generic product MASH XPM-disabled UVM | PASS: same data, 56 PA words, mask `3`, weighted flag, Identity DPD, partial ready |
| Generic EF1 CDC | 1 error / 30 warnings, zero waivers; OPEN |
| Generic MASH CDC | 1 error / 32 warnings, zero waivers; OPEN |
| Generic EF1 structural RDC | 4,379 errors / 11 warnings, zero waivers; OPEN |
| Generic MASH structural RDC | 5,087 errors / 13 warnings, zero waivers; OPEN |
| Generic FIFO epoch formal | 4 proven / 4 inconclusive assertions; 1 covered / 1 inconclusive cover; OPEN |

The Generic EF1 and MASH CDC error is `Ac_conv02` at `tid32_thermo5_axi_lite_axis_frontend_tx.sv:101`: SpyGlass reports reconvergence from FIFO pointer synchronizer and source error synchronizer at `runtime_idle`. The RTL references the second-stage `source_error_c2`; resolve the complete reconvergent cone and its use under fixed architecture before any disposition.

All Generic UVM logs report zero UVM errors and fatals. The corresponding
previous XPM runs also passed the same directed sequence. Completion times of
these particular runs differ (EF1 Generic 780 ns vs XPM 960 ns; MASH Generic
800 ns vs XPM 990 ns); these overall test times are not isolated latency or II
measurements. Both standalone FIFO tests intentionally use a shared reset epoch,
not arbitrary independently asserted FIFO resets.

The existing `thermo5_rdc_async_epoch_harness` proves read/write Gray one-bit
change and no accepted pop/push during local reset; the harness itself gates `wvalid` by `wn` and `rready` by `rn`, so these two properties do not prove the ungated FIFO interface independently. Its initialization, read
frontier, count bound and capacity properties are **inconclusive**; the live
reset cover is **inconclusive**, and the normal-transfer cover is reached.
The harness holds `boot_n==1` after startup while `epoch_n` is unconstrained;
its existing script disables reset setup checking and VC Formal also warns of
three potential reset setup issues. Core 4.572 clock period is rounded to 4.57
by this script. This is not a whole-product or physical CDC proof.

## Reproduction

Use the same SGDC and unique output per goal and architecture:

```sh
export THERMO5_CTIME_ROOT="$PWD" THERMO5_CTIME_ARCH=0 THERMO5_CTIME_XPM=0
export THERMO5_CTIME_GOAL=rdc/rdc_verify_struct
export THERMO5_CTIME_OUT="$PWD/runs/NEW_GENERIC_RDC"
/opt/Synopsys/spyglass/V-2023.12-SP1/SPYGLASS_HOME/bin/sg_shell \
  -tcl research/vcu118_arch/run_compiletime_spyglass.tcl
# For CDC: use cdc/cdc_verify and another output directory.
# For MASH: THERMO5_CTIME_ARCH=2.
```

Use the VCS compile-time command in the Round 2 review, omit
`THERMO5_XPM_FIFO` from `+define`, and use separate outputs for
`COMPILETIME_ARCH_0` and `COMPILETIME_ARCH_2`. The source, Python-generated
seed 610216 vectors, test and scoreboard are otherwise the same. Standalone
VCS tests compile `rtl/axis/dsm_reset_sync.sv`, `rtl/axis/dsm_async_fifo.sv`,
and respectively `dv/verif/axis/tb_thermo5_generic_fifo_epochs.sv` or
`tb_thermo5_generic_fifo_skew_epochs.sv`, with that testbench as `-top`.

```sh
mkdir -p runs/NEW_GENERIC_FORMAL
THERMO5_FORMAL_REPO="$PWD" THERMO5_FORMAL_OUT="$PWD/runs/NEW_GENERIC_FORMAL" \
  /opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf -batch -fmode FPV \
  -f dv/uvm/formal/run_thermo5_rdc_async_epoch.tcl
```

## Source and result identities

Tools: VCS V-2023.12-SP1, SpyGlass V-2023.12-SP1, VC Formal V-2023.12-SP2.
SGDC SHA-256 `84bfa1507572d5ee0c0f83f12021e4e76bbf02a39886587b534573ac8b399c2d`;
flow script `b0634c1054b891b94b9385eab69b556aef147e01fb5fdbb51c24d7231d8f86a9`.
The original reports and logs are preserved at `runs/linux_cdc_rdc_round3/`.

| Artifact | SHA-256 |
| --- | --- |
| FIFO reset VCS log | `a87b174911b768aa706a935c46ad28bdcd3341a18b406b0727cd2dff37774ea5` |
| FIFO skew VCS log | `327473f8589bc4d8ed57a4af435a1397c80fec5a17f969973f94a664573aeb48` |
| EF1 Generic UVM log | `92e2b78b0c552f913c221891b6801c5986d031329a4b873e98da477ca976bf9a` |
| MASH Generic UVM log | `82efb28225aef16f4f6b8f23391132a859449fee799eee061ed88b21da23167a` |
| Generic FIFO formal properties | `f63d36836788c1412dca1c26e67a5fa61ec116f19966cd008c4c94678158e4f8` |
| Generic FIFO formal setup | `9179ff820f8ccd52c831980266a856fb521fc62364086ba3188857dd4aa5685a` |
| MASH Generic CDC report | `86f9de46d9f3fb2fbcde960322fdb1da458a902fb0356cb200ff91a033d29e5f` |
| EF1 Generic CDC report | `34954ec385b9d6b47573f8036aa133a6b78e61952e8efde7b1e26285dfb12b3f` |
| MASH Generic RDC report | `1cb661222f74c9c041a6d808567ceed16a557b4c317431721146d1b4b51921d9` |
| EF1 Generic RDC report | `087c103a4b4a3ed6b701675b8a3bb6f26564e2713516bbee455640f0e10a2217` |

Next, close Generic FIFO reset/restart proofs and extend actual product tests
with variable clock ratios, full/empty wrap, sustained traffic, reset while
blocked, packet/frame boundaries and scoreboard mutation. Audit synchronizer
mapping, physical Gray constraints, memory resources and routed timing; compare
actual throughput/latency contracts and handle the original XPM path findings
independently. Existing XPM CDC/RDC, system reset/epoch proof and DE freeze
remain OPEN.

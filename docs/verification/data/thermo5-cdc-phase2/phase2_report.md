# CDC/RDC Phase2 execution and open obligations

2026-11-12 SGT; parent PR59 bb8fcf3e8e286d902b7a903ba76805557a6b1926.
Frozen635be681046b3ab7d6fdda7f4e9818d7226efd66 RTL diff is empty.

## Actual static execution

SpyGlass V-2023.12-SP1 successfully elaborates the actual AXI-Lite product top
with MAX_TAPS1/FPGA_USE_XPM_FIFO0, all19 elaborated module specializations,
three clock domains and three independently declared active-low async resets.
No depth/width reduction,RTL change,blackbox substitution or waiver is applied.

| Goal | Fatal | Error | Warning | Info |
|---|---:|---:|---:|---:|
| CDC setup check |0|0|15|65|
| CDC structural |0|5|29|101|
| RDC structural |0|10506|15|76|

The missing-Top setup blocker is closed. CDC reports0 unsynchronized clock
crossings and5 convergences, but5 Ac_glitch03 errors remain: tx_active_sync1,
draining_sync1,core_active_s1,prefill_gray_c1[0],ingress_closed_c1. These sample
combinationally derived status/Gray logic. Need endpoint-specific glitch safety,
encoding and reconvergence analysis; zero unsynchronized crossings alone is not
signoff. Gray encoding checks are reported DISABLED; separate encoding proof
and tool setup are required. Bundled-data stability is not proven by this run.

RDC10506 messages are individual structural errors, not10506 independent
functional bugs. Many involve reset control/data to unreset memory and
cross-domain reset dependencies. No reset equivalence assumption was added.
Every exact message/severity/source/destination is retained in
static_messages.csv.gz and full reports; all are OPEN_REVIEW_REQUIRED. Missing
source/destination parser fields remain in full native message (glitch messages
usually specify destination and fanin count rather than source names). No blanket
waiver. Requires per-root reset epoch, memory-valid gating and release contract
proof before disposition. These reports do not approve any code exclusion.

AXIL TB single-register reset release does not establish metastability-safe
hardware deassertion; product expects external reset contract on exposed ports.
Need SoC/reset-owner confirmation and RDC evidence. No silent TB/RTL change.

## Actual new block verification

1. Actual MAX_TAPS1 configuration module: at105000ps epoch0, legal STATUS W1C
write_fire and four-phase return-to-idle happen on the SAME AXIL edge. Monitor
checks busy=1,seen_ack=1,ack_sync2=0 before edge; after NBA DONE=1,busy=0.
Independent expected priority follows source NBA ordering; source-derived
behavior is verified, spec priority approval remains open. Subsequent W1C clears
DONE and STATUS reads verify both states. Functional cross has one explicit
same-edge bin,100%. Unmapped0x83 returnsDECERR; taps2 write followed byCOMMIT
returnsSLVERR and sticky error. All externally driven AXI operations are legal.
Watchdog passes. No force/deposit, no internal driving.

2. Actual default-depth16 Generic FIFO with real two-stage reset syncs: fill16,
observe full, hold17th pending write blocked for3 source edges, assert public
reset, check immediate reset-sync assertion, release, check empty, then64
continuous accepted write/read words independently checked for order/data and
old-epoch exclusion. Final drain and watchdog pass. This is FIFO block evidence,
not a whole-product FIFO-full/pending-COMMIT system test.

Block tests do NOT claim Python CDC/EF2/PA product Oracle coverage. No product
compile/VDB changed,block VDB is never merged into product URG. Same-edge cross
closes the named block priority obligation only; requested system monitor cross
and product-level acceptance remain OPEN. Existing reset6epochs/two phase
witnesses were not repeated. No unchanged inconclusive Formal rerun.

## Vendor model and remaining gates

Searches:/opt,/usr/local,/home/ray and /mnt for xpm_fifo.sv/xpm_fifo_async.v.
/mnt/d/Xilinx/Vivado exists but contains only dsm_out_bits.coe; desktop Vivado
shortcuts do not provide HDL. Required glbl/xpm_cdc/xpm_memory/xpm_fifo sources
are absent in searched locations. XPM tests BLOCKED,not generic-model PASS.
Supply/configure a licensed Vivado model installation before real XPM validation.

Remaining back-to-back COMMIT/BUSY/BREADY,STOP/pending/restart,product queue-tail,
empty/refill/backpressure and new source-protocol fault tests are NOT_RUN.
The DECERR/SLVERR checks here reconfirm block behavior,not new product negative
coverage beyond existing register-access tests. No full unified regression
started before completing requested new tests. No exact product coverage gain.

PR59 measured baseline remains Raw=Official:Branch526/637,Cond667/849,
Line3352/3796,Toggle92640/104480,FSM13/13states+22/22transitions. What-if:
Branch526/528,Cond667/713,Line3352/3352,Toggle92640/93576. New product HIT0,
approved exclusion0,accepted exception0;11599+2 candidates PENDING,46technical
unresolved,930counterOPEN. No official.el/denominator change/merge.

Code Coverage Signoff OPEN. Full Linux DV Signoff OPEN. This increment closes
static setup and two scoped block verification obligations,not the full Phase2.

## Commands

Static: dv/uvm/static/README.md. Block VCS examples from repository root:

```bash
mkdir -p runs/priority_fresh
vcs -full64 -sverilog -top tb_thermo5_done_w1c_priority \
 rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv \
 dv/verif/axil/tb_thermo5_done_w1c_priority.sv \
 -Mdir=runs/priority_fresh/csrc -o runs/priority_fresh/simv
runs/priority_fresh/simv -no_save -l runs/priority_fresh/test.log
# FIFO: substitute top tb_thermo5_generic_fifo_epochs and three sources:
# rtl/axis/dsm_reset_sync.sv rtl/axis/dsm_async_fifo.sv
# dv/verif/axis/tb_thermo5_generic_fifo_epochs.sv
python3.12 tools/hw/thermo5_cdc_phase2_results.py
python3.12 -m unittest discover -s tools/hw/tests
```

VCS V-2023.12-SP1_Full64; final cross version compile/run PASS;65utility tests
PASS. Actual native report and witness hashes in results.json. Parser validates
native severity counts,including SynthesisWarning,against console totals.

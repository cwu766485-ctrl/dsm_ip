# Thermo5 native CDC/RDC error debug

Frozen product SHA: `635be681046b3ab7d6fdda7f4e9818d7226efd66`.
This investigation preserves RTL, constraints, severity and every native message.
No errors have been waived and no independent approval is implied.

## Complete native error inventory

`data/thermo5-cdc-error-debug/native_error_obligations.csv.gz` retains all
10,511 Error messages including native IDs, paths, source/destination and exact
blocking obligation. These are tool messages, not 10,511 independent defects.

| Root | Error messages | Debug outcome / remaining obligation |
|---|---:|---|
| Combinational CDC sources | 5 | One Gray encoder delay-sensitivity reproduced; all five remain physical CDC obligations |
| Elastic FIFO unreset payload | 7,576 | Source-bound initialized-epoch ownership proof; consumer and physical reset composition still required |
| DPD unreset pipeline | 2,680 | Valid/tap-enable reset, unreset coefficient/data stages; full reset/stall composition OPEN |
| Gain unreset pipeline | 149 | Valid-gated stages; physical reset/qualifier recognition OPEN |
| Async FIFO unreset payload | 96 | Reset pointers/flags protect unreset RAM only under the reviewed common epoch contract; independent reset unsafe |
| Mailbox reset-domain crossing | 5 | Independent AXIL reset split reproduced; common epoch recovery PASS |

RDC NULL means the destination data flop has no asynchronous reset. It does not
mean the reset input is missing from elaboration. Resetting all payload RAM and
multipliers is not a justified fix and may change inference, timing and area.
A local sampled proof does not waive a physical reset crossing.

## Actual VCS experiments

`tb_thermo5_prefill_cdc_hazard.sv` drives two legal AXIS beats before RUN on the
actual frozen AXIL product, MAX_TAPS=1, Generic FIFO. At 68.040 ns it observes
count `01->10`: ideal Gray `01->11` but an independent read-only source-delay
model (100 ps MSB, 20 ps LSB) produces a low Gray bit with high endpoints.
The first test attempt started before local reset synchronization completed;
it failed the ready predecessor check. Waiting five source cycles corrected
the stimulus. No DUT state was forced or delayed.

This confirms combinational-encoding hazard sensitivity, not extracted silicon
timing, an actual receiver error or a failure probability. Suggested future ECO:
register the Gray encoding of the **next** source prefill count in the source
domain, preserving count clear/hold/increment semantics and receiver latency.
Reset `00`; compute registered Gray together with binary next state. A whole
bus `$onehot0` assertion would be wrong for the permitted `2->0` clear: it is a
reset-to-empty transfer gated by inactive/closed ingress, and needs its own
receiver-enable timing proof. Do not blindly apply a generic Gray waiver.

Other Ac_glitch03 locations are config lines224/226 (active/draining status),
wrapper line120 (active status) and188 (ingress closed). Review source-register
ECOs with reset values and RUN/STOP/drain latency explicitly, then recompile,
check token conservation and rerun static CDC. No stable-RTL-only argument
establishes physical glitch immunity for those paths.

`tb_thermo5_mailbox_reset_contract.sv` legally writes C1=0x2000 then COMMIT,
waits for pending capture and **deliberately violates the common epoch contract**
by asserting AXIL-only reset. At94.001ns core applies the old pending0x2000 while
the source mailbox has reset to0x4000. A subsequent common reset restores0x4000,
clears busy/pending and passes recovery checks. This is an environment-contract
counterexample, not a legal-regression PASS or proof of metastability behavior.
To support independent resets requires an explicit mailbox abort/epoch protocol;
reset correlation cannot be silently assumed in SGDC.

Both tests have watchdogs, observed predecessors, self-checks and retained VCD
hashes. They are diagnostics, never product URG hits or bit-true system tests.

## Reset payload proof

The new harness instantiates the real registered-ready FIFO, W16/LANES32/META18.
These widths exercise the largest product payload and a conservative metadata
width (actual specializations use18/2/1). Inputs and backpressure are arbitrary.
Ghost ownership clears in reset, clears on pop and sets on push; visible slots
must be owned and writes must target free slots. Empty metadata must be zero.

The first full-vector reference run: capacity, empty metadata, visible ownership
and write-free PROVEN; payload INCONCLUSIVE at depth10; three positive covers
(full, replacement, stall) COVERED. No counterexample was returned.
The revised proof uses a time-invariant arbitrary payload bit and complete
metadata reference, retaining the unchanged 512-bit RTL datapath. This reduces
only reference complexity, not the parameter scope. Its sole added assumption
is `$stable(tracked_bit)`; saved reset holds rst_n=1 during the proof. This is a
clock-sampled initialized-epoch proof, not asynchronous reset recovery/removal,
reassertion, downstream physical RDC closure or XPM signoff. Final revised run: 4 PROVEN, payload INCONCLUSIVE at depth29, 4 non-vacuous
checks and 3 positive covers. No unchanged proof retry is justified. Engine
results are retained in the evidence directory.

The reproducible VCS runner was executed end to end and both checks PASS.
65 utility tests PASS using Python3.12. An initial Python3.6 invocation failed
8 module imports (unsupported annotations); this was an interpreter selection
error, corrected without changing product or utility semantics.

## Reproduction

```bash
bash dv/verif/cdc/run_error_debug.sh "$PWD/runs/cdc_debug_fresh"
mkdir -p runs/cdc_proof_fresh
cd runs/cdc_proof_fresh
THERMO5_FORMAL_REPO="$(git rev-parse --show-toplevel)" \
THERMO5_FORMAL_OUT="$PWD" \
/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf -batch -fmode FPV \
-f ../../dv/uvm/formal/run_thermo5_fifo_reset_ownership.tcl
```

All native structural errors remain OPEN until exact-scope resolution/review.
No SGDC change justifies a new identical structural run; existing native report
hashes remain the baseline. Product compile/VDB/URG unchanged; new exact hits0,
approved exclusions0. XPM vendor models remain unavailable. Code Coverage and
Full Linux DV Signoff remain OPEN. The AXIL single-stage TB reset release still
cannot represent a hardware-safe synchronous release guarantee. Do not merge.

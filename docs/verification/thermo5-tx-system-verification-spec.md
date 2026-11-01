# Thermo5 TX Transaction and Verification Contract

## Scope and product configuration

This contract describes the current TX-only Linux verification configuration:
Centered-Cubic interpolation enabled for both x2 stages, EF2 TIDSM order 2,
STEP 5120, one active DPD tap with the reset-loaded identity image, Generic
asynchronous FIFO, and the AXI-Lite TX wrapper where control-plane behavior is
under test. The contract is derived from `tid32_thermo5_axi_lite_axis_frontend_tx`,
`dsm_axis14_to_core8_cdc`, `tid32_thermo5_frontend_tx`, and the UVM interfaces.

## Accepted transactions and identifiers

- **AXIS beat:** one handshake (`TVALID && TREADY`) transfers 14 signed 16-bit
  complex I/Q samples. Lane 0 is earliest. `TUSER_FRAME_START` and gain belong
  to the accepted beat; they are not sampled from an unaccepted presentation.
- **DSP frame:** a frame start is legal only at a 56-complex-sample boundary:
  four AXIS beats or seven 8-sample core words. The source marker must survive
  the gearbox with zero residual samples. The frame gain is selected at the
  accepted frame-start word. The same marker is the DPD configuration boundary
  after it traverses the frontend elastic path.
- **AXIS packet:** in the AXI-Lite wrapper, an accepted `TLAST` is legal when
  the accepted-beat phase is 31 modulo 32. Thus each packet is a positive
  multiple of 32 beats (448 samples, eight DSP frames). An early `TLAST` sets
  sticky protocol-error status but does not repair or shift gearbox alignment.
- **PA word:** the four 64-bit planes form one atomic output transaction. A
  transfer occurs only when all four `PA_VALID` and all four `PA_READY` bits
  are high. Partial `PA_READY` is legal backpressure; partial `PA_VALID` is a
  DUT protocol failure. Accepted PA words are ordered and compared against
  the same epoch's expected word index.
- **Reset epoch:** source and core resets are asserted together by the current
  testbench control BFM; AXI-Lite reset is synchronously derived from core
  reset. A reset discards queued, partial, and in-flight work and clears
  datapath/config state. No pre-reset sample may be matched to a post-reset PA
  word. The scoreboard restarts source/PA sequence indices at the epoch edge.

The existing source monitor supplies an accepted-beat index, the AXI-Lite
monitor supplies transaction IDs and sampled event cycles, and the PA monitor
publishes only accepted four-plane words. The optional JSONL recorder adds a
monotonic trace-event sequence, an epoch-local packet ID/beat index (advanced
only on accepted source beats and `TLAST`), a source frame ID (advanced only
on accepted `FRAME_START`), and an epoch-local accepted PA word index. Core
frame-boundary events have their own frame ID and are checked against the
accepted source frame sequence. The output association key is
`(reset_epoch, pa_word_index)`; expected data is calculated from accepted
source transactions and the configuration image reconstructed from AXI-Lite
write-fire, CDC-pending, and accepted frame-boundary events. The DUT's active
configuration payload and PA data are never inputs to expected-data
generation; PA data is used only as the comparison target.

## Flow control, STOP, drain, and underflow

Source gaps are allowed while the source is not backpressured, but the RTL
specifies no maximum safe gap. Before RUN, the wrapper requires two accepted
source beats to cross the FIFO before starting the gearbox. During an active
stream, if the gearbox has started and becomes empty outside drain, the RTL
sets sticky `core_underflow`. Therefore a legal normal-stream gap is one for
which the accepted-data backlog prevents underflow; a fixed maximum gap must
not be assumed without a measured directed test.

RUN is a request synchronized into the core clock domain. Clearing RUN closes
new ingress only after the already-open packet is accepted through its legal
`TLAST`; the core then drains FIFO/gearbox residuals, datapath pipeline, and
all four-plane output transactions. `core_tx_active` remains asserted through
drain and clears only when the drain predicate is satisfied. A subsequent RUN
waits for two newly accepted beats after the completed drain. STOP without a
packet-closing `TLAST` is not a legal completed-drain scenario.

Reset during a transaction is a separately classified recovery test. The
checker records the pre-reset accepted prefix, permits that epoch's queued
work to be discarded, and requires the first post-reset output to match only
post-reset input. A reset is not a normal-stream flush and is excluded from
the no-loss assertion across epochs.

## AXI-Lite configuration epochs

AXI-Lite AW and W are independent channels; a register write takes effect only
after both handshakes and the internal write-fire edge. The register predictor
uses that edge, not the delayed B response, as write acceptance. Shadow writes,
COMMIT acceptance, request crossing into the core domain, pending-bank
observation, and activation on an accepted DPD frame-start transfer are
distinct events. STATUS reads return the value sampled at the AR handshake;
RUN_ACTIVE and DRAINING are synchronized views and must be predicted using
the AXI-Lite sampling edge and the RTL's synchronizer/event priority.

The UVM register predictor snapshots all five defined STATUS bits on every
AXI-Lite clock before publishing same-edge AR or write-fire events. It compares
the returned sampled value without masking BUSY, DONE, ERROR, RUN_ACTIVE, or
DRAINING. The two-stage views are modeled from the observed core ACK, active,
and draining signals; therefore this checks the AXI-Lite synchronized view,
while directed STOP/Drain assertions independently check the core control
behavior. The predictor also checks shadow-register readback, WSTRB merges,
write response codes, read response codes, and transaction association.

## Error classification

Normal regressions require no source protocol violation, no unexpected
underflow, no loss/duplication/reorder, no four-plane mismatch, no wrong
configuration epoch, no deadlock, and no unexpected assertion failure.
Malformed early TLAST, invalid tap count, busy COMMIT, mailbox fault injection,
and reset during pending configuration belong to separate negative tests with
explicit expected response/error/recovery checks. They are not included in the
normal-pass count.

The first dynamic Python trace-oracle implementation supports complete legal
frame/packet epochs, arbitrary accepted-data gaps represented by accepted
transaction order, PA backpressure as accepted output ordering, multi-frame
packets, and configuration changes applied at observed frame boundaries. It
compares monitor-recorded PA words and reports underflow events separately so
normal and expected-fault classifications remain explicit. Reset-only epochs
are represented without payload comparison. Mid-frame reset truncation,
cycle-accurate starvation recovery, and independent Python assertions for
STOP/Drain/Restart behavior remain open extensions; directed UVM assertions
cover the current STOP/Drain/Restart sequence.

## Phase 0–2 implementation status

Phase 0 contract and the first Phase 1 predictor / Phase 2 trace-oracle
implementation are present. Focused VCS evidence includes the register-only
protocol test and a clean two-packet STOP/Drain/Restart product trace. The
one-tap stress trace and the four-tap configuration trace are diagnostic or
candidate-configuration evidence and are kept separate from normal product
PASS results. The Python oracle checks PA data against monitor transactions;
the `.mem` vector path remains in use as the existing static baseline.

This is an initial constrained-verification foundation, not completion of the
entire Phase 0–2 acceptance list. The predictor's source STATUS inputs are
observed core signals rather than an independent model of the core
controller. Arbitrary mid-frame reset recovery, timed source-gap behavior,
STOP/Drain state checking in Python, and dynamic randomized trace generation
remain open. No Phase 3–6 super-random framework or signoff is claimed. No DUT
algorithm RTL changed and no DUT code-coverage run was made for these edits.

The core clean-trace replay command is:

```bash
PYTHONPATH=dv/uvm/refmodel/python python3.12 \
  dv/uvm/refmodel/python/check_thermo5_monitor_trace.py \
  runs/stop_restart_trace.jsonl --step 5120 --tidsm-order 2 --max-taps 1
```

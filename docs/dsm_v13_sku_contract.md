# DSM V1.3 SKU Contract and MASH Integration Gaps

## Existing SKU profiles

| SKU | Current elaboration/configuration | Verified interface scope |
|---|---|---|
| EF1 Product | `DSM_ARCH=1`, centered-cubic x2+x2, `TIDSM_ORDER=1`, step 7168, one-tap identity DPD | Thermo5 Product Top, AXIS source, optional AXI-Lite, Generic FIFO, four 64-bit PA planes |
| EF2 Research | `DSM_ARCH=2`, centered-cubic x2+x2, `TIDSM_ORDER=2`, step 5120, one-tap identity DPD | Same Thermo5 Product verification boundary; separate settings and coverage database |
| MASH 1-1 experiment | `DSM_ARCH=3`, `W=16`, `ACC_W=18`, `IN_SHIFT=0`, `SATURATE=1` | Legacy scalar block wrapper only; no Thermo5 Product interface |

EF1 and EF2 remain separate compile-time configurations. The unified test shell
uses a generate-time selector and instantiates only one selected DSM datapath.
Their legacy regression entry points remain available.

## MASH arithmetic contract observed in the imported source

For the current experiment, `x` is signed 16-bit input after arithmetic
`IN_SHIFT`. The accumulator width is 18 bits and `SATURATE=1`:

1. Stage 1 computes `v1 = sat18(x + e1)`, selects the positive rail when
   `v1 >= 0` and the negative rail otherwise, then updates its residue from
   `v1 - q1`.
2. Stage 2 consumes the previous accepted stage-1 residue plus its own stored
   residue, computes the same sign quantizer and updates its residue.
3. The wrapper exposes the two stage bits and the signed combiner
   `y = delayed(q1_pm) + q2_pm - delayed(q2_pm)`. The normal steady-state
   combined levels are `{-3,-1,+1,+3}`; reset initialization can produce a
   transient value before steady state.
4. An invalid input cycle holds arithmetic state and output payload while
   `out_valid` deasserts. There is no `ready` input, so this block cannot accept
   output backpressure. Every valid input advances state.
5. Asynchronous active-low reset clears arithmetic state and output-valid
   history. Reset invalidates prior history; the first post-reset accepted
   sample starts a new model epoch.

The fixed model supports explicit saturation and wrap modes to test boundary
semantics. This experiment runs the saturating 18-bit variant. No claim is made
that rounded or truncated arithmetic is used: the observed MASH accumulator
path has no rounding stage; `IN_SHIFT` is an arithmetic right shift when
nonzero. Rail width is signed 16-bit with `Q_POS=32767`, `Q_NEG=-32767`.

### Latency decision still required

The legacy MATLAB `model_mash11` writes the stored `yreg` to the current output
sample before calculating its next combined value. The RTL wrapper registers
the combinational combined value on the same accepted edge and registers
`out_valid` from `in_valid`. Thus the apparent transaction alignment differs
by one accepted transaction between these two interfaces. MATLAB could not be
executed in this environment, and no MASH Product interface contract resolves
the intended latency. This remains **OPEN**; the block-level scoreboard follows
the actual RTL wrapper timing and does not claim MATLAB/RTL Product alignment.

## Product boundary not defined for MASH

The imported MASH wrapper does not specify any of the following. These must be
decided before calling MASH a Thermo5 Product SKU:

| Contract area | Evidence in current source | Required product decision |
|---|---|---|
| Input mapping | One signed scalar sample and valid enable | AXIS width, I/Q packing, accepted sample/lane order, frame/TLAST meaning |
| Ready/backpressure | No input ready or output ready | Buffering/credit policy and which interface owns backpressure |
| Lane mapping | Two stage bits and one 3-bit combined level | Whether lanes carry stage streams, combined output, or both; lane ordering |
| PA encoding | Signed four-level combiner exists | Weighted PA code mapping, sign/polarity, plane widths, serializer order |
| AXI-Lite | No register interface | SKU register map, reset image, coefficient/config behavior, write/read side effects |
| FIFO | None in the wrapper | Depth, payload width, metadata, full/empty behavior, reset flush and current-epoch isolation |
| Reset epoch | Core async reset only | Short-pulse capture, abort, external isolation, restart and stale payload contract |
| Latency/throughput | One state advance per `in_valid`; wrapper registers valid | End-to-end accepted-sample latency, frame latency, sustained sample rate |
| Numeric model | Legacy P0 uses 16-bit input and 18-bit saturating accumulator | Normative scales, rounding/shift rules, saturation versus wrap, legal input range |

## Required independent MASH verification additions

The round adds a float algorithm model, fixed-point bit-true transaction model,
vector generator, UVM scoreboard adapter, an elaboration-time selector, block
SVA, and captured output trace. The model mutation test changes expected
combined level and output ordering and requires comparison failure. The
directed suite includes zero, positive/negative constants, extrema, impulse,
step, quantizer boundaries, random values with valid bubbles, reset/restart,
and long state evolution.

For Product integration, add after contract approval:

- MASH-specific AXIS and AXI-Lite agents/sequences or explicit reuse adapters;
- independent model alignment for every sample, with lane/frame/config
  metadata carried alongside data;
- scoreboard comparison at each architectural boundary and at all four PA
  planes/serializer samples;
- full/backpressure/stall, partial frame, FIFO wrap/full/empty, runtime reset,
  repeated abort/restart, and reset-during-stall tests;
- coverage for state evolution, quantizer boundaries, cancellation alignment,
  output levels, lane ordering, frame markers, configuration transitions,
  reset epochs, FIFO occupancy and stalls;
- mutation injection into the compiled scoreboard/checker or DUT boundary,
  not only the Python oracle comparator;
- explicit latency/throughput and reset recovery requirements.

These are not claimed complete by the block-level experiment.

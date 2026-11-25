# DSM V1.3 MASH 1-1 Product Candidate Contract

Status: Round 2 candidate RTL contract; physical PA weighting is not yet
approved. This contract defines the simulation-visible behavior used by the
Round 2 MASH Product regression.

## Product boundary

`tid32_thermo5_axis_frontend_tx` selects MASH 1-1 with `DSM_ARCH=3`. Its
optional AXI-Lite control path uses the existing
`tid32_thermo5_axi_lite_axis_frontend_tx` with the same selector. Both builds
reuse the existing AXIS CDC/FIFO, frame gain, centered-cubic interpolation,
memory DPD, metadata handling, run/stop control, and four-plane output ports.
The MASH path replaces only the final four-branch TIDSM block.

The final MASH adapter accepts a 32-complex-sample vector on the core clock.
It evaluates the scalar MASH recurrence in lane order 0 through 31 and carries
the final state into the next accepted vector. This is one chronological
sample stream, not 32 independent MASH modulators. I and Q maintain independent
MASH state. One accepted vector produces one 64-bit word on each of four PA
planes. The output register holds the complete word and all MASH state while
any PA plane is backpressured. Sustained throughput is one vector per core
clock when all four PA sinks are ready; timing is not qualified.

## Arithmetic

The initial Product parameters are `W=16`, `ACC_W=18`, `IN_SHIFT=0`, and
`SATURATE=1`. Input shift is an arithmetic right shift. Each stage uses
signed two's-complement accumulation and saturates to the signed `ACC_W` rails
when enabled. There is no rounding. The quantizer chooses the positive rail
when its input is greater than or equal to zero and the negative rail
otherwise; the quantizer rails are `+32767` and `-32767`.

For each accepted scalar sample, stage 1 computes `v1 = sat(x + e1)`, chooses
`q1 = sign(v1)`, and stores `e1_next = v1 - q1_rail`. Stage 2 consumes the
previous accepted sample's stage-1 residue and computes
`v2 = sat(e1_delayed + e2)`, `q2 = sign(v2)`, and
`e2_next = v2 - q2_rail`. The combined output is
`y = q1_delayed + q2 - q2_delayed`, with each `q` represented as `+1` or
`-1`.

State is continuous across AXIS frames and STOP/restart. Core reset clears all
MASH state and invalidates the output word. The first accepted sample after
reset produces the inherited `+2` cancellation startup transient; subsequent
valid outputs are in `{-3,-1,+1,+3}`. The current wrapper/MATLAB latency
difference remains under review; the Round 2 reference model follows the
checked RTL recurrence and does not claim MATLAB equivalence.

## Four-plane weighted encoding

The electrical widths and handshakes match the Thermo5 four-plane output:
`pa_valid[3:0]`, four 64-bit `pa_data` words, and `pa_ready[3:0]`. For
simulation, each plane is assigned a logical weight:

| Plane | Logical weight |
|---|---:|
| 0 | -3 |
| 1 | -1 |
| 2 | +1 |
| 3 | +3 |

After undoing the existing Fs/4 lane polarity, the weighted sum of the four
bits reconstructs the exact MASH combined level:

| Combined level | Plane 0 | Plane 1 | Plane 2 | Plane 3 |
|---:|---:|---:|---:|---:|
| -3 | 1 | 0 | 0 | 0 |
| -1 | 0 | 1 | 0 | 0 |
| +1 | 0 | 0 | 1 | 0 |
| +2 reset transient | 0 | 1 | 0 | 1 |
| +3 | 0 | 0 | 0 | 1 |

Lane zero is earliest. Bit `2*lane` carries I and bit `2*lane+1` carries Q.
To retain the existing serializer's bit-zero-earliest Fs/4 convention, even
lanes transmit `I, ~Q` and odd lanes transmit `~I, Q` on every plane. The
encoder is codebook based; the weighted sum is checked independently in the
Python/UVM reference path.

This is a proposed weighted code for the existing four-plane electrical
interface. It requires physical branches with relative signed weights
`{-3,-1,+1,+3}` and the stated polarity handling. The current Thermo5 equal-
weight Product interpretation does not establish that hardware support.
Board mapping, PA calibration, serializer pin assignment, RF performance, and
physical sign-off remain OPEN.

## Reachability note

The two Round 1 combined-level holes `-2` and `0` are unreachable under this
reset contract. On the first accepted sample, `e1_delayed=e2=0`, so `q2=+1`
and `q2_delayed=0`; the reset value of `q1_delayed` is `+1`, producing only
`+2`. After that sample, both delayed quantizer terms are always `+1` or
`-1`, so their combination is only `-3`, `-1`, `+1`, or `+3`. A stall holds
all state, and reset reestablishes the same first-sample condition. This
algebraic reachability argument does not alter the Round 1 raw histogram or
authorize a coverage waiver. Raw bins remain recorded; any adjusted coverage
change still requires independent review.

## Clock/reset and software interfaces

The new MASH logic is wholly in `core_clk` and uses `core_aresetn`; it adds no
new clock-domain crossing. AXIS input CDC and AXI-Lite CDC/reset behavior are
inherited from the selected Thermo5 top. `DSM_ARCH`, accumulator width, input
shift, and saturation are elaboration-time parameters. AXI-Lite continues to
control the existing upstream DPD/run registers; Round 2 adds no MASH runtime
registers.

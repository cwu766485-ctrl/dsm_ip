# Thermo5 EF2 Throughput and Timing Study

## Current implementation

`rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv` implements a scalar
second-order error-feedback recurrence over each 32-sample I/Q vector. For
each sample index `k`, with `e1` and `e2` denoting the two prior quantization
errors, the RTL performs:

```text
u[k]   = x[k] + 2*e1[k-1] - e2[k-1]
q[k]   = +1 when u[k] > 0, otherwise -1
e1[k] = saturate(u[k] - q[k])
e2[k] = e1[k-1]
```

The I and Q recurrences are independent. The combinational loop at lines
73-123 evaluates all 32 time-ordered samples; the four loop-carried states
are committed only when the raw-word boundary accepts a complete vector
(lines 130-148). This preserves the Python scalar model's sample order and
produces one 64-bit I/Q/Fs4 word per accepted vector, but places a 32-step
nonlinear recurrence in one core-cycle path.

## Exact pairwise look-ahead experiment

The scalar transition has two quantizer decisions per sample pair. Starting
from `(e1,e2)` and two inputs `(x0,x1)`, the exact candidate computes:

```text
u0 = x0 + 2*e1 - e2
q0 = +Q if u0 > 0, else -Q
e0_pos = sat20(u0 - Q)
e0_neg = sat20(u0 + Q)
u1_pos = x1 + 2*e0_pos - e1
u1_neg = x1 + 2*e0_neg - e1
u1 = u1_pos if u0 > 0, else u1_neg
q1 = +Q if u1 > 0, else -Q
e1_next = sat20(u1 - q1)
```

This preserves the `u == 0` tie rule, both signed-20 clamps, the final state
`(e1_next,e0)`, and both quantizer outputs. It computes both second-sample
state candidates while the first quantizer decision is being evaluated. The
experimental RTL is selected only by `PAIR_LOOKAHEAD=1`; all wrappers and the
main-chain default leave it disabled. It adds parallel arithmetic and muxing,
so lower delay and area are hypotheses until FPGA mapping and routing.

The standalone VCS miter checks the full 32-sample candidate against the
scalar baseline through randomized valid/ready stalls, signed extrema,
positive/negative state saturation, back-to-back acceptance, and 4,096 clock
cycles. The formal harness proves the two-sample transfer for arbitrary
signed-16 inputs and states; because the transfer preserves both outputs and
the final state, it can be composed over the 16 chronological pairs in a
production vector. Together these checks establish recurrence equivalence and
unchanged interface II/latency at RTL; they do not establish an Fmax or
resource improvement.

## Why a direct pipeline split is not yet qualified

Registering an intermediate state after (for example) lane 7, 15, or 23
changes when the end state for a vector becomes available. The first sample
of the next vector requires that final state. A straightforward set of chunk
registers therefore has to either:

1. stall vector admission until the previous vector's final state returns,
   reducing the one-word-per-cycle initiation rate; or
2. use an old/speculative state, which changes quantizer decisions and is no
   longer bit-true to the current recurrence.

The existing finite-width saturation is another nonlinearity: an algebraic
look-ahead derivation that assumes an unclamped loop is not automatically
equivalent for arbitrary signed-16 inputs. Any optimized candidate must state
its legal input envelope or preserve the per-sample clamp exactly.

This is not a proof that an II=1 exact parallel implementation is impossible.
Published work describes predictive/look-ahead equations for particular
second-order sigma-delta topologies, and time-interleaved error-feedback
architectures require a deliberate transformation of the IIR loop. Those
methods are design leads, not drop-in replacements for this RTL's recurrence,
quantizer tie rule, signed fixed-point widths, saturation, and four-plane
encoding. The candidate therefore remains a correctness/quality prototype
until one such transformation is derived and checked against the precise
fixed-point oracle.

## Candidate architecture gates

Before adding a registered or pipelined EF2 implementation, produce a reviewed recurrence
derivation and a reference model that defines all corner behavior. Then:

- compare every output bit and final I/Q error state against the scalar model
  over directed extrema, random samples, long OFDM frames, stalls, frame
  boundaries, and the supported state-clamp envelope;
- prove vector ordering, state hold on backpressure, and one accepted vector
  per cycle after pipeline fill;
- run the full generic/XPM UVM suite and the corresponding functional
  covergroup/cross checks;
- run ZU15EG OOC timing-driven implementation with reviewed clock and I/O
  constraints, reporting routed setup/hold slack and resource usage.

If the look-ahead transformation changes the exact bit stream or noise-transfer
behavior, treat it as a new DSM architecture: regenerate the MATLAB/Python
oracle, repeat EVM/SNDR/BER and clamp studies, and do not describe it as
bit-true to the existing EF2 candidate.

## Baseline and research disposition

The current thermo5 main-chain configuration is centered-cubic x2 plus
fixed-point EF2 at STEP=5120. The pairwise candidate remains disabled in the
product wrappers until a reviewed implementation comparison and routed timing
result are available. The first-order TIDSM and causal interpolation remain
comparison configurations; neither implies timing qualification for EF2.
FPGA LUT/FF/DSP/Fmax and physical RF evidence remain open when Vivado, board
constraints, and measurement equipment are unavailable.

## References for future derivation

- F. Colodro et al., “Time-interleaving design of error-feedback sigma-delta
  modulators with infinite impulse response noise transfer function,” IET
  Circuits, Devices & Systems, 2021, DOI
  [10.1049/cds2.12040](https://doi.org/10.1049/cds2.12040). The paper notes that
  transforming an IIR error-feedback loop to time-interleaved form is not
  straightforward.
- H. Li et al., “A 21-GS/s Single-Bit Second-Order Delta-Sigma Modulator for
  FPGAs,” IEEE Transactions on Circuits and Systems II, 2019, DOI
  [10.1109/TCSII.2018.2855962](https://doi.org/10.1109/TCSII.2018.2855962). Its
  high-throughput design uses a MASH-1-1 plus bit-reduction architecture, so
  it is a useful alternative-architecture reference rather than a bit-true
  implementation of this EF2 recurrence.
- “An Efficient Parallel Structure for Sigma Delta Modulators for Use in High
  Speed Switching Power Amplifiers,” available from the
  [Maynooth University repository](https://mural.maynoothuniversity.ie/id/eprint/1344/2/efficientParallel.pdf),
  derives predictive equations for a specific second-order low-pass loop.
  Its equations and assumptions must be re-derived for thermo5's fixed-point
  error-feedback form before reuse.

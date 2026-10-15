# Scalar Low-Pass DSM Specification

## Scope

The design unit is one scalar DSM lane. On each rising edge with `enable=1`,
the core accepts one signed fixed-point input sample, advances its internal
error/state recurrence, and updates its quantized output. When disabled, the
state holds. `rst_n` is an active-low asynchronous reset.

The single-bit family is the low-pass LP1, LP2, EF1, EF2, MASH11, MASH111, and
MASH22 set in `rtl/dsm/singlebit/`. The multi-bit family uses
`rtl/dsm/multibit/dsm_core_multibit.sv`, selected by `MB_ALGORITHM` values 0
through 6, plus named wrappers for synthesis comparison.

## Interfaces

The cores use a synchronous scalar interface: clock, reset, enable, signed
sample input, and the algorithm-specific quantized output/state signals. They
do not implement AXI, stream framing, a clock-domain crossing, or a serializer.
Their output is a quantizer code, not an analog RF waveform.

The P0 wrappers under `rtl/top/` pair two independent scalar lanes for I and Q
and exercise the Fs/4 merge. They are validation shells, not part of the core
algorithm boundary.

## Numerical contract

The exact contract for each implementation is its RTL parameters and matching
MATLAB function. Tests must preserve two's-complement behavior, configured
state width, saturation/wrap mode, quantizer thresholds, feedback scaling,
output registration, and reset values. A parameter or algorithm comparison
must record those settings and use the corresponding model; generic native
metrics alone do not establish bit-true equivalence.

## Non-goals

This branch does not define PA behavior, digital predistortion, interpolation,
multi-lane time-interleaving, AXI control/data interfaces, GT electrical
behavior, board clocks, or RF output performance.

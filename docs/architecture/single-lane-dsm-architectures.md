# Scalar DSM Architecture Map

## What “single lane” means here

Each DSM core owns one recurrence state and accepts one scalar signed input
sample on each enabled clock. `enable` is a sample advance, not AXI `valid` or
`ready`. There is no lane interleaver in the core. A P0 wrapper may instantiate
two copies for I and Q, but those are two independent scalar instances.

```text
signed scalar x[n]
       │
       ▼
 algorithm-specific state / error feedback
       │
       ▼
 quantizer ───► registered bit or signed code
       ▲                  │
       └── feedback ◄─────┘
```

## RTL families

| Family | RTL | What varies | Model / verification entry |
|---|---|---|---|
| Single-bit low-pass | `rtl/dsm/singlebit/dsm_core.sv`, `dsm_core_dsm2.sv`, `dsm_core_ef1.sv`, `dsm_core_ef2.sv`, `dsm_core_mash11.sv`, `dsm_core_mash111.sv`, `dsm_core_mash22.sv` | LP, error-feedback, and MASH state structures; one-bit quantizer output | `matlab/bittrue/p0_dsm_bittrue.m`; P0 XSim suite |
| Multi-bit low-pass | `rtl/dsm/multibit/dsm_core_multibit.sv` | `MB_ALGORITHM` selects the same seven broad algorithm families; `Q_BITS` sets quantizer resolution | `matlab/cartesian_dsm/dsm_multibit/dsm_multibit_model.m`; multibit XSim capture |
| Named multi-bit wrappers | `rtl/dsm/multibit/dsm_core_multibit_*.sv` | Fixed algorithm selection around the parameterized core for integration/OOC comparison | OOC top wrappers in `syn/rtl/p0_ooc_tops.sv` |

The actual fixed-point contract is in the RTL parameters and matching MATLAB
model. Order alone does not determine PPA: accumulator width, saturation,
quantizer resolution, feedback arithmetic, and output registration all matter.

## P0 verification carrier

```text
rom_reader ──► I scalar DSM ──┐
                 Q scalar DSM ─┴─► Fs/4 merge ──► captured output dump
```

The P0 top-level stream is intentionally retained because existing regression
vectors and checks already exercise the scalar cores. It adds I/Q pairing,
ROM playback, and an Fs/4 merge for test purposes; those blocks are not claimed
as part of a standalone scalar DSM algorithm core.

## Comparison strategy

1. Use the same deterministic input corpus across all algorithm variants.
2. Capture the actual RTL output for each sample.
3. Compare against the corresponding fixed-point model, not just an average
   noise or signal metric.
4. Separately compare resource and routed timing under a documented part and
   clock target. Historical OOC results remain historical until rerun.

## Excluded boundaries

No interpolation, DPD, stream protocol, asynchronous FIFO, AXI-Lite control,
GT serialization, RF output, or board behavior is represented by this branch.

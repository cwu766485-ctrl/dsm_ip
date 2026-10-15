# Scalar DSM Cores

Every module in `singlebit/` and `multibit/` advances one scalar sample on an
enabled clock. For the exact recurrence, fixed-point widths, quantizer,
feedback, and reset behavior, use each RTL module together with its matching
MATLAB model and the branch [specification](../../docs/SPEC.md).

The P0 verification wrappers instantiate the single-lane cores as independent
I and Q paths. They do not alter the core's scalar lane semantics.

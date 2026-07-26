# DPD RTL

This directory contains the synthesizable fixed-point DPD execution path.
All sample interfaces use signed Q1.15 I/Q and all polynomial coefficients use
signed Q2.14 complex values.

| File | Purpose |
|---|---|
| `dpd_poly.v` | Memoryless polynomial DPD, compile-time order 3, 5, or 7. |
| `dpd_lut.v` | Double-buffered complex-gain LUT DPD. |
| `dpd_memory_poly.v` | Banked C1/C3/C5 memory-polynomial DPD, compile-time depth 1 to 6 and fixed ten-cycle latency. |
| `dpd_frontend.v` | Runtime mode selection, branch alignment, safety fallback, and coefficient-bank control. |
| `dpd_observer.v` | Synchronous observation-window monitor and metric proxies. |
| `dpd_observer_async_bridge.v` | Reusable dual-clock AXI-Stream bridge for observation feedback. |
| `dpd_seed_predictor.v` | Optional deterministic seed-prediction helper. |
| `dpd_tinyml_tree.v` | Optional fixed decision-tree helper; it is not a physical-PA model. |

`dpd_frontend` defaults to a development build with polynomial, LUT, and
memory branches enabled. `ENABLE_DPD_POLY`, `ENABLE_DPD_LUT`, and
`ENABLE_DPD_MEMORY` are compile-time product gates. A runtime request for a
disabled branch resolves deterministically to bypass.

The external feedback path remains outside `dpd_frontend`: use
`dpd_observer_async_bridge` before the synchronous `s_axis_obs_*` interface
whenever observation and TX clocks differ. The bridge is lossless by default
and reports explicit drops only when built with `DROP_ON_FULL=1`.

Run the DPD regression with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_dpd_bittrue.ps1
```

The regression includes MATLAB/RTL bit-true checks for the retained 5th-order,
7th-order, and four-tap memory vectors, plus a compile-time identity/configuration
matrix for orders 3/5/7 and tap counts 1/2/4/6.

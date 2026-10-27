# Thermo5 Full-IP UVM Scenarios

All tests use the common source agent, control BFM, four-plane monitor, and
Python fixed-point oracle scoreboard configured by `thermo5_sku_base_test`.
The current main-chain default is centered-cubic x2 interpolation and EF2
TIDSM with STEP=5120; set `THERMO5_CENTERED_CUBIC=0` for the causal FIR
fallback, or `THERMO5_TIDSM_ORDER=1 THERMO5_STEP=7168` for the first-order
TIDSM fallback. The nominal
`thermo5_sku_bittrue_test` is now a focused scenario derived from that base.
Each scenario class is kept in one file so stimulus intent and pass criteria
can be reviewed without searching a large omnibus file. The package includes
the corner files through `thermo5_sku_corner_tests.svh`, retained as a
compatibility include hub.

| Test class | Scenario and expected evidence |
|---|---|
| `thermo5_sku_bittrue_test` | Nominal 32-beat frame(s), optional random PA-ready stalls, source order/count, 56 words per frame and all four output planes bit-true against MATLAB. |
| `thermo5_sku_prestart_empty_test` | Starts the core with an empty ingress FIFO; expects no PA output, underflow, or protocol error before a separate normal bit-true stream. |
| `thermo5_sku_fifo_boundary_test` | Holds the consumer off until the source fills the 16-entry FIFO; expects `s_axis_tready` backpressure, then drains without losing or reordering a beat. |
| `thermo5_sku_fifo_empty_test` | Sends four source beats (56 samples / seven 8-lane words), then continues core consumption; expects sticky underflow after the valid data is exhausted. This is an intentional negative-stream condition. |
| `thermo5_sku_bubble_backpressure_test` | Adds a legal source-valid gap and PA backpressure; checks selected empty/held pipeline states and still requires complete MATLAB four-plane equality. |
| `thermo5_sku_interp1_empty_blocked_test` | Phase-aligns a legal source gap and PA stall to hit the specific interpolation-stage-1-empty/blocked state; also checks drain and bit-true outputs. |
| `thermo5_sku_reset_test` | Resets both public domains during a partial stream, checks nonzero EF2 state clears, then stalls the final centered frame-tail word under partial PA-ready, resets it, and bit-true replays the frame. |
| `thermo5_sku_reset_sweep_test` | Repeats reset at five gearbox residual populations (2, 4, 6, 10, 12 samples); expects residual state to clear each time and final replay to match MATLAB. |
| `thermo5_sku_fifo_reset_phase_test` | Sweeps reset timing after a source prefix; optional plusargs target XPM FWFT stage-1 and record the vendor read-reset edge transition before replay. |
| `thermo5_sku_long_counter_test` | Uses a long multi-frame oracle vector and controlled output stalls; checks the long run, then public reset clears per-lane DPD counters. |
| `thermo5_sku_sustained_test` | EF2 continuous-frame qualification: accepts 2,072 input words, requires one output per cycle after pipeline fill, zero output gaps, zero source stalls, and full four-plane oracle equality. |
| `thermo5_sku_ef2_corner_test` | Drives positive and negative EF2 state clamps, stalls PA during a clamp candidate, checks state hold, releases backpressure, then resets and replays the stream bit-true. |
| `thermo5_sku_illegal_frame_test` | Sends a frame marker at a non-56-sample boundary; expects the alignment assertion/sticky protocol error, then reset clears the error. The runner treats the RTL assertion as expected. |

The centered-cubic EF2 qualification runs three fixed-seed scenarios through
VCS: sustained 2,072-word traffic, two-stream saturation/stall/reset/replay,
and a 2,072-word random stream with PA backpressure and DPD-counter reset.
The generic full-IP and AXI-Lite regression targets also pass with the main
EF2 defaults. Exact run commands and current limitations are recorded in
`docs/verification/thermo5-ef2-stability.md`.

Run an individual test using the existing target, for example:

```bash
make -C dv/uvm/sim thermo5-vcs-run-only \
  THERMO5_TESTNAME=thermo5_sku_fifo_boundary_test UVM_SEED=2
```

AXI-Lite tests are in the sibling `../axil/` suite. The raw GT-user boundary,
serializer behavior loopback, and GT-parent integration are separate directed
block/integration flows, not represented by these UVM tests. A passing UVM test
does not claim physical GT/board signoff.

# CDC and STA Signoff Scope

## Clock Domains

The frozen Performance SKU has one synchronous transmit/control domain,
`aclk`, and one optional asynchronous observation-input domain,
`feedback_clk`.

- `aclk` drives AXI-Lite, TX AXI-Stream, DPD, interpolation, Fs/4 mixing,
  BP EFDSM2, observer processing, and monitor registers.
- `feedback_clk` is permitted only at the input of
  `rtl/dpd/dpd_observer_async_bridge.v` when an external ADC or observation
  receiver is used.
- `dpd_axis_async_fifo` transfers the observation stream using Gray-coded
  read/write pointers and two-flop pointer synchronizers. It either applies
  source backpressure or counts intentional drops when `DROP_ON_FULL=1`.

The current dual-clock block test checks ordering, reset, full FIFO behavior,
and drop/backpressure accounting. It is functional evidence, not a CDC/RDC
static-signoff result.

## CDC and Reset Requirements

1. Assert `feedback_rst_n` and `aresetn` together for the asynchronous FIFO.
   Their deassertion sequence must be reviewed by the selected CDC/RDC tool.
2. Constrain `aclk` and `feedback_clk` as asynchronous clock groups at the
   integration top when the bridge is instantiated.
3. Preserve the two-flop pointer synchronizers. Do not retime, merge, or
   replace them during synthesis.
4. Run a CDC/RDC static analysis on the integrated top, including reset
   release, before declaring board or ASIC signoff.

## STA Requirements

RTL simulation and UVM prove functional behavior; they do not prove timing.
STA evidence is required separately for every implementation target.

For the current 100 MHz FPGA target, the timing flow must define:

```tcl
create_clock -name aclk -period 10.000 [get_ports aclk]
create_clock -name feedback_clk -period <feedback-period> [get_ports feedback_clk]
set_clock_groups -asynchronous \
  -group [get_clocks aclk] \
  -group [get_clocks feedback_clk]
```

The final report must include post-route setup/hold slack, unconstrained-path
checks, clock interaction, and CDC exceptions. OOC and routed reports are
useful implementation evidence, but a board bitstream and I/O timing closure
need the complete board project, XDC constraints, and physical interfaces.

## Current Status

- Functional asynchronous feedback behavior: verified by focused VCS test.
- Single-clock Performance-SKU system UVM: verified separately.
- Formal control/protocol proof: does not replace CDC/RDC.
- Full CDC/RDC static signoff: not yet run.
- Final post-route STA/bitstream timing for the current BP EFDSM2 Performance
  SKU: not yet signed off from a complete board project.

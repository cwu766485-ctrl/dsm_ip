# Observer Block

## DUT

`rtl/dpd/dpd_observer_async_bridge.v` transports observation I/Q samples from
the feedback clock domain into the TX/observer clock domain.

## Testbench

`tb/tb_dpd_observer_async_bridge.sv` uses different source and destination
clocks, injects destination backpressure, and checks sample order, `tlast`,
`tuser`, stall count, and no-drop behavior.
`tb/tb_dpd_observer_async_bridge_random.sv` uses a depth-4 FIFO and randomized
sink ready. The 2026-08-12 regression passed 24 directed samples and 129
randomized samples with 225 stalls. Monitor arithmetic belongs to `../monitor/`.

## Reference and Vectors

This is a transaction-preservation block. Its deterministic sequence is created
inside the testbench, so no external CSV golden vector is required. Future
random CDC/overflow tests belong here; IP-level observation AXI integration
belongs in UVM.

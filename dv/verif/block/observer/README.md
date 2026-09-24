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
`tb/tb_dpd_observer_async_bridge_drop.sv` uses the same depth with
`DROP_ON_FULL=1`, holds the sink until full, and checks explicit drop count,
zero source stalls, accepted-sample ordering, and accepted-plus-dropped accounting.
The 2026-08-16 Linux VCS result passed with 96 sent samples, 12 accepted
samples, and 84 explicit drops. Run it in the Linux VCS environment with
`bash run_vcs_drop_on_full.sh`.

## Reference and Vectors

This is a transaction-preservation block. Its deterministic sequence is created
inside the testbench, so no external CSV golden vector is required. The
asynchronous FIFO is outside the current single-clock IP-system UVM DUT, so its
CDC/full/drop policy remains a focused block-level VCS verification. IP-level
observation AXI integration belongs in UVM.

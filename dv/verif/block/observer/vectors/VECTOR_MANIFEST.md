# Observer Bridge Vector Manifest

The bridge is transport-only, so its oracle is a transaction sequence rather
than a CSV. `tb_dpd_observer_async_bridge_random.sv` sends 129 ordered complex
samples with deterministic `tuser`/`tlast`, a depth-4 asynchronous FIFO, and
randomized sink readiness. It checks ordering, sideband preservation, strict
backpressure, and zero dropped samples.

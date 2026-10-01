# UVM Tests

`axi_ip/dsm_base_test.svh` creates the original AXI-IP configuration and
environment. Individual test
classes select a scenario, start a virtual sequence, and manage objections;
they do not drive DUT pins directly.

`thermo5/` is a separate test family for the two-clock, four-plane transmitter.
Its tests inherit from the thermo5 base test, start the MATLAB-vector source
sequence, and require specific monitor/checker events. The two families have
different filelists and DUT tops; neither is a base class for the other.

The test suite includes:

- basic BP smoke and frozen-SKU readback;
- deterministic Python-reference RF bit-true checks;
- memory-DPD inactive-bank programming, commit, and illegal-coefficient reject;
- AXI4-Lite channel ordering and response backpressure;
- TX and observation stream stalls, observer windows, reset, W1C, and error
  recovery;
- directed coverage tests for reachable corner behavior.

The full test matrix and closure boundary are maintained in `docs/VPLAN.md`.

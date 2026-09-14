# UVM Tests

`dsm_base_test.svh` creates the configuration and environment. Individual test
classes select a scenario, start a virtual sequence, and manage objections;
they do not drive DUT pins directly.

The test suite includes:

- basic BP smoke and frozen-SKU readback;
- deterministic Python-reference RF bit-true checks;
- memory-DPD inactive-bank programming, commit, and illegal-coefficient reject;
- AXI4-Lite channel ordering and response backpressure;
- TX and observation stream stalls, observer windows, reset, W1C, and error
  recovery;
- directed coverage tests for reachable corner behavior.

The full test matrix and closure boundary are maintained in `docs/VPLAN.md`.

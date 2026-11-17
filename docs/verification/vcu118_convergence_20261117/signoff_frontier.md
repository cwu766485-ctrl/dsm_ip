# VCU118 convergence signoff frontier

Status definitions: PASS means the specifically named test passed; FAIL means measured requirements are violated; BLOCKED means a prerequisite or proof is missing; NOT_RUN means no result exists. A PASS in a subtest is not system signoff.

| Item | Status | Evidence or next action |
|---|---|---|
| EF1 baseline routed core | FAIL | -2.797 ns WNS; see `ppa_matrix.csv` |
| EF1 cubic candidate overall | FAIL | -0.363 ns unexpanded asynchronous mailbox; core +0.075 ns only; physical CDC contract remains open |
| EF2 baseline routed core | FAIL | -97.149 ns, 409 levels, 190 CARRY8; no false path |
| EF2 two-sample candidate | PASS | Scoped pair equivalence assertions and covers; Full Top PPA NOT_RUN |
| EF2 32-lane equivalence | BLOCKED | Zero-black-box formal: 3 proven, 4 inconclusive, four covers reached; no full bit-true proof |
| MASH-only routed | FAIL | Core/overall WNS -2.879 ns, overall WHS +0.004 ns; vectorless total power 4.896 W |
| Runtime routed | BLOCKED | Synthesis is running; no routed report exists |
| Live AXI to GTY serial and receiver | BLOCKED | Frontend/PA, prefill and GTY have individual tests; no live integration |
| PA-capture to prefill and vendor GTY replay | PASS | 336,896 serial bits per lane; PMA loopback and serial-data receiver verified; not live AXI integration |
| 14.000 Gb/s two-lane GTY vendor digital pattern | PASS | 16,384 bits per lane and internal PMA loopback, no physical board evidence |
| MASH 1-1-1 model comparison | PASS | Same input, clocks and receiver at two seeds; model only, no hardware cost measurement |
| Board GTY, RF ACLR and system signoff | NOT_RUN | Board clocks, physical constraints, RF combiner and measurement needed |

Common reproducibility and versions: Vivado 2026.1 build 6511674; baseline SHA `67d68abb402f9bb2c9a87a43a99f46955acfe9d9`; EF1 candidate source SHA `3f88efef965e2d5705adc57d06f530c265af2e82`; common PPA Tcl SHA256 `12315c97539a62d8ed429b8a6c7898111c520397414cbe7dc7331cca80010226`. Original evidence lives in unique ignored `runs/` directories; never reuse an output directory. See `research/vcu118_arch/README.md` and `full_chain_gty_report.md` for exact commands and prerequisites.

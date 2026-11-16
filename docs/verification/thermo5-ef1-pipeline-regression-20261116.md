# EF1 Pipeline Regression

The four fresh AXI-Lite COMMIT runs are recorded in
[the combined report](thermo5-ef1-mash-regression-20261116.md) and its
[manifest](data/thermo5-ef1-mash-regression-20261116-manifest.json). All four
automated XSim runs passed with 32 source beats, 59 DPD inputs and 56 PA words.
The two routed Pipeline DCPs remain the fixed +0.307/+0.249 ns baseline.

Product reset during traffic, occupied-pipeline reset, STOP/restart and long
random backpressure were not run by this focused AXI-Lite bench and remain
OPEN. Existing VCS/VC Formal/SpyGlass evidence is not substituted for those
checks.

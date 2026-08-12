# Monitor Vectors

`prepare_dpd_observer_behavioral_vectors` generates the observer reference,
feedback, and metadata CSV files under `matlab/out/dpd/observer/`. The monitor
testbench consumes those files and compares pair/drop/error, magnitude, peak,
clip, saturation, slew, and fixed-bin spectral accumulators exactly.

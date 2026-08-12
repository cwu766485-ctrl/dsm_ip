# Python Bit-Exact Reference Model

This model is the Linux/VCS regression reference. It uses Python integers to
make two's-complement width, wrap, saturation, state order, and latency
explicit. It is not a floating-point approximation of the MATLAB model.

MATLAB remains the algorithm and fixed-point signoff reference. Python must
match MATLAB sample by sample before its vectors are used by the UVM
scoreboard.

Run the unit tests and deterministic MATLAB-vector comparison from this directory:

```bash
python -m unittest discover -s tests -v
python generate_bp_ef2_vectors.py
python compare_matlab_fixed_vectors.py
python compare_xsim_fixed_vectors.py
python generate_performance_sku_vectors.py
```

Then run the MATLAB cross-check:

```matlab
cd('E:/workspace/chip/dsm_ip/matlab');
path_setup;
T = compare_python_bp_ef2_reference;
assert(all(T.registered_mismatch == 0));
assert(all(T.core_mismatch == 0));
```

`registered_bit` matches the historical MATLAB registered trace. `core_bit`
matches the RF transaction observed when RTL `rf_valid` is asserted. The two
traces differ only by the documented output-register latency.

`interp.py` implements the shipped I0 coefficient tables for modes 0..4.
`dpd.py` implements Q1.15/Q2.14 memory polynomial C1/C3/C5 with one-, two-,
four-tap selection. `compare_matlab_fixed_vectors.py` is the MATLAB/Python
gate; it must pass before a Python expected sequence is used in UVM.
`compare_xsim_fixed_vectors.py` is the second gate after
`verif/scripts/run_xsim_interp_frontend.ps1` has generated RTL dumps.

`generate_performance_sku_vectors.py` emits the frozen system-SKU vectors
used by `dsm_performance_bittrue_test`: DPD bypass at runtime, x32 I0
interpolation, Fs/4 full-precision mixing, and BP EFDSM2 quantization.

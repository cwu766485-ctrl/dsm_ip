# Block-Level Verification

Block verification isolates arithmetic, state, and local protocol behavior
before subsystem or IP-system integration.

## Directory Contract

Each block uses the same layout:

```text
<block>/
  README.md       DUT boundary, evidence, and open work
  tb/             Directed SystemVerilog testbenches
  vectors/        Vector format and generation contract, not duplicate outputs
  refmodel/       Pointer to the single-source MATLAB/Python reference model
```

Generated CSV files belong in `matlab/out/`, `uvm_verif/refmodel/python/out/`,
or a disposable `verif/out_xsim_*` run directory. They are deliberately not
copied into every block directory: copying would create multiple golden-vector
sources that can silently diverge.

## DUT and Evidence Matrix

| Block | DUT RTL | Reference model | Test type | Current evidence |
|---|---|---|---|---|
| DPD | `rtl/dpd/dpd_poly.v`, `dpd_memory_poly.v`, `dpd_lut.v`, `dpd_frontend.v` | MATLAB `matlab/dpd/`; Python `dsm_refmodel/dpd.py` | SV bit-true, protocol, safety, feature-gate | 2026-08-12: Poly3/5/7 and Memory-Poly 256/256, zero mismatch; random protocol 113 samples, 47 stalls |
| Interpolation | `rtl/interp/dsm_interp_frontend.sv` and supporting FIR/CIC RTL | MATLAB `matlab/models/interp_frontend_fixed.m`; Python `dsm_refmodel/interp.py` | SV bit-true, valid/backpressure, random protocol | 2026-08-12: modes 0 to 4 and x32 I0/I1/I2/I3, 4096 samples each, zero mismatch; 97 inputs, 1084 stalls |
| Fs/4 mixer | `rtl/tx_bandpass_if/bp_fs4_iq_mixer.sv` | Python `dsm_refmodel/bp_ef2.py::Fs4Mixer` | SV directed and random protocol | 2026-08-12: 8 directed corners and 257 randomized samples passed |
| BP EFDSM2 | `rtl/tx_bandpass_if/dsm_core_bp_ef2.sv` | Python `dsm_refmodel/bp_ef2.py::BpEf2` | SV Python-to-RTL bit-true and enable-bubble protocol | 2026-08-12: 4096 seeded randomized/extrema vectors passed |
| Observer bridge | `rtl/dpd/dpd_observer_async_bridge.v` | Ordered transaction/sideband contract | SV dual-clock and randomized sink backpressure | 2026-08-12: 24 directed samples, 129 randomized samples, 225 stalls passed |
| Monitor | `rtl/dpd/dpd_observer.v` | MATLAB observer-vector generator | SV behavioral-vector and random invalid/clear protocol | 2026-08-12: 63 pairs/1 drop behavioral vector pass; 129 samples with 12 invalid beats passed |

"PASS" means the recorded run passed for the listed configuration only. It is
not a blanket signoff for future RTL changes.

## UVM Boundary

These block tests remain lightweight SV testbenches. A full UVM agent is not
needed when a block has one clock and a small local interface. UVM is required
at the IP-system level for reusable AXI-Lite, AXI-Stream, RF-monitor agents,
cross-interface sequencing, random backpressure, register programming, and
coverage. Those tests live under `uvm_verif/`.

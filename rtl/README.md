# RTL

This directory contains the P0 RTL set.

## Reading Order

For a top-down review of the reusable transmitter IP, read the following files
in order:

1. `axi/dsm_ip_axi_top.v`: AXI-Lite control plane, AXI-Stream boundaries,
   register map, counters, and safety status. Read `axi/README.md` first for
   its split between the stateful integration wrapper and the stateless
   readback selector.
2. `ip/dsm_ip_top.v`: integrated TX datapath and compile-time route selection.
3. `dpd/dpd_frontend.v`: DPD mode selection, coefficient banks, safety
   fallback, and the aligned ready/valid pipeline.
4. `interp/dsm_interp_frontend.sv`: compile-time interpolation mode and
   implementation selection.
5. `ip/dsm_ip_core.sv`: reusable DSM-core and DUC selection.
6. `tx_bandpass_if/`: full-precision Fs/4 mixer and the primary one-bit BP
   EFDSM2 IF route.

The arithmetic cores deliberately retain their fixed-point expressions and
register placement. Those details are bit-true contracts with the MATLAB and
Python reference models, not formatting choices.

Included top levels:

- `p0_top_lp1`
- `p0_top_lp2`
- `p0_top_ef1`
- `p0_top_ef2`
- `p0_top_mash11_mb`
- `p0_top_mash111_mb`
- `p0_top_mash22_mb`

Directory layout:

| Path | Purpose |
|---|---|
| `dsm/singlebit/` | Existing single-bit and native MASH baseline DSM cores |
| `dsm/multibit/` | Multibit Cartesian DSM RTL cores and per-algorithm wrappers |
| `axis/` | Small AXI-Stream helper blocks |
| `axi/` | AXI-Lite integration wrapper and stateless readback selector |
| `interp/` | Standalone interpolation/filter frontend RTL |
| `duc/` | Fs/4 merge and NCO upconversion blocks |
| `tx_analog_iq/` | Low-pass I/Q DSM route for external reconstruction and analog IQ mixing |
| `tx_bandpass_if/` | Experimental full-precision IF mixer and one-bit BPDSM route |
| `mem/` | ROM reader used by simulation and ROM-backed tops |
| `top/` | P0 wrapper tops |

Included cores and support blocks:

- `dsm/singlebit/dsm_core.sv`
- `dsm/singlebit/dsm_core_dsm2.sv`
- `dsm/singlebit/dsm_core_ef1.sv`
- `dsm/singlebit/dsm_core_ef2.sv`
- `dsm/singlebit/dsm_core_mash11.sv`
- `dsm/singlebit/dsm_core_mash111.sv`
- `dsm/singlebit/dsm_core_mash22.sv`
- `dsm/multibit/dsm_core_multibit.sv`
- `dsm/multibit/dsm_core_multibit_lp1.sv`
- `dsm/multibit/dsm_core_multibit_lp2.sv`
- `dsm/multibit/dsm_core_multibit_ef1.sv`
- `dsm/multibit/dsm_core_multibit_ef2.sv`
- `dsm/multibit/dsm_core_multibit_mash11.sv`
- `dsm/multibit/dsm_core_multibit_mash111.sv`
- `dsm/multibit/dsm_core_multibit_mash22.sv`
- `axis/axis_skid_buffer.sv`
- `interp/dsm_interp2_halfband.sv`
- `interp/dsm_interp_fir_fixed.sv`
- `interp/dsm_interp_frontend.sv`
- `duc/duc_fs4_merge.sv`
- `duc/duc_fs4_merge_signed.sv`
- `duc/duc_nco_mix_signed.v`
- `tx_analog_iq/dsm_iq_analog_top.sv`
- `tx_bandpass_if/tx_bp_if_top.sv`
- `mem/rom_reader.sv`

The primary compilation list is:

```text
rtl/filelist_p0.f
```

MASH paths are kept in their native multibit form for algorithm comparison.

`dsm/multibit/dsm_core_multibit.sv` is the shared bit-true multibit engine.
The `dsm_core_multibit_*` files are per-algorithm wrappers used by
`dsm_ip_core` algorithms `7` through `13`.

Multibit controls:

- `MB_Q_BITS`: compile-time quantizer resolution, default 4
- `DSM_OUT_W`: native output code width, default 8
- `ACC_W_MB`: multibit state width, default 28

The default 4-bit multibit modes are MATLAB/RTL bit-true over the current
65536-sample P0 vector set. Timing/resource OOC signoff for these modes is still
separate from the seven original P0 signoff paths.

`dsm_ip_core` supports `DUC_MODE=2` for analog-IQ integration. It keeps the
DSM I/Q outputs valid but forces `rf_valid=0`; downstream logic must not
interpret `rf_bit` or `rf_signed` as a physical RF waveform in this mode.
`dsm_ip_top` additionally supports `DUC_MODE=3` for the BP EFDSM2 research
SKU. It routes interpolated full-precision I/Q through the IF mixer before the
one-bit BPDSM and emits `rf_bit` for the DPA. This route remains qualification
only until fixed-point, RF-metric, RTL, and implementation evidence is closed.

Interpolation frontend:

- `INTERP_MODE=0`: bypass
- `INTERP_MODE=1`: x4 halfband FIR cascade
- `INTERP_MODE=2`: x8 halfband FIR cascade
- `INTERP_MODE=3`: x16 halfband FIR cascade
- `INTERP_MODE=4`: x32 halfband + CIC-equivalent FIR + compensation FIR

The RTL uses a single-clock valid/ready interface. One low-rate input sample is
accepted when `in_ready` is high; the frontend emits the interpolated output
stream over subsequent cycles. Modes 0 through 4 are MATLAB/RTL bit-true in the
standalone `tb_interp_frontend` regression. The frontend is inserted before
`dsm_ip_core` in `dsm_ip_top`; `INTERP_MODE` remains a compile-time parameter.
The halfband and FIR helper blocks use symmetric-coefficient pre-adds and skip
zero coefficients to reduce arithmetic cost.

Each FIR helper has a four-stage registered compute pipeline:

1. symmetric tap pre-add and coefficient multiply
2. first-level partial-sum grouping
3. second-level adder-tree reduction
4. round, saturate, and output register

The pipeline increases cycle latency through each FIR stage, but it preserves
the output sample sequence and MATLAB/RTL bit-true values. The standalone
regression checks both valid output samples and first-output latency:

| INTERP_MODE | First-output latency |
|---:|---:|
| 0 | 0 cycles |
| 1 | 8 cycles |
| 2 | 12 cycles |
| 3 | 16 cycles |
| 4 | 16 cycles |

AXI wrapper flow control:

- `rtl/axis/axis_skid_buffer.sv` provides a one-entry AXI-Stream register slice
  ahead of the interpolation/DSM frontend. It preserves `tdata`, `tlast`, and
  `tuser` together under backpressure.
- `s_axis_tready` can deassert when the frontend is busy. This is legal
  backpressure and increments `INPUT_STALL_COUNT`.
- `ERROR_STATUS[0]` is reserved for input asserted while the IP is disabled or
  held in reset.
- `ERROR_STATUS[1]` is set when an accepted AXI-Stream sample has nonzero
  `tuser`; this supports upstream error tagging without changing the DSM
  numerical datapath.
- `ERROR_STATUS[2]` latches a DPD safety fault, `[3]` latches a rejected
  memory-polynomial commit, and `[4]` latches a rejected LUT commit.

DPD calibration safety:

- `dpd_frontend` keeps the deployed default at four memory taps and fifth
  order, but `MP_MAX_TAPS` is a compile-time control for one to six taps.
- `DPD_CTRL[8]` enables coefficient safety. Writes above the configured Q2.14
  magnitude limit mark the inactive package unsafe; its later commit is
  rejected without replacing the active package.
- `DPD_CTRL[9]` is a write-one clear for the saturation fallback latch. A
  saturation event in the selected DPD mode causes later samples to use the
  bypass path until software clears the latch after loading a safe package.
- `s_axis_obs_*` is the optional Q1.15 complex observation-feedback stream.
  Its detailed transfer and calibration contract is in
  `docs/IP_HANDOFF.md`.

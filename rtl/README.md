# RTL

This directory contains the P0 RTL set.

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
| `interp/` | Standalone interpolation/filter frontend RTL |
| `duc/` | Fs/4 merge and NCO upconversion blocks |
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

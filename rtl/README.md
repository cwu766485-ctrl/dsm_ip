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

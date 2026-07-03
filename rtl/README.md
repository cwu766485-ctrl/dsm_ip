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
| `dsm/` | DSM algorithm cores |
| `duc/` | Fs/4 merge and NCO upconversion blocks |
| `mem/` | ROM reader used by simulation and ROM-backed tops |
| `top/` | P0 wrapper tops |

Included cores and support blocks:

- `dsm/dsm_core.sv`
- `dsm/dsm_core_dsm2.sv`
- `dsm/dsm_core_ef1.sv`
- `dsm/dsm_core_ef2.sv`
- `dsm/dsm_core_mash11.sv`
- `dsm/dsm_core_mash111.sv`
- `dsm/dsm_core_mash22.sv`
- `duc/duc_fs4_merge.sv`
- `duc/duc_fs4_merge_signed.sv`
- `duc/duc_nco_mix_signed.v`
- `mem/rom_reader.sv`

The primary compilation list is:

```text
rtl/filelist_p0.f
```

MASH paths are kept in their native multibit form for algorithm comparison.

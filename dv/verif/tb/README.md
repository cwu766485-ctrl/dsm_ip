# P0 Testbench Inventory

- `tb_p0_lp1.sv`, `tb_p0_lp2.sv`, `tb_p0_ef1.sv`, `tb_p0_ef2.sv`: single-bit
  low-pass algorithm carriers.
- `tb_p0_mash11_mb.sv`, `tb_p0_mash111_mb.sv`, `tb_p0_mash22_mb.sv`:
  multi-level MASH carriers.
- `tb_p0_multibit_all.sv`: all seven parameter selections of the generic
  multi-bit scalar core.
- `tb_p0_common.svh`, `tb_p0_assertions.svh`: common stimulus/check helpers.

Each P0 test feeds independent I and Q scalar cores from the same deterministic
ROM corpus. Sample dumps are compared against MATLAB references separately.

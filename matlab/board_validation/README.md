# Board Validation MATLAB Scripts

These scripts reproduce the retained board-output consistency checks for the
first-order Cartesian LPDSM RFSoC path.

Use this folder for:

- recovering bits from the preserved oscilloscope captures;
- comparing recovered board output with RTL reference sequences;
- regenerating RF/baseband spectrum comparison figures;
- checking the exact 69-bit DSM000 anchor evidence.

Recommended entry points:

```matlab
recover_scope_rf_bits('DSM000')
plot_dsm000_scope_vs_rtl_single
plot_exact_69bit_anchor_overlay
compute_recovered_bits_evm_sndr
```

Expected data location:

```text
data/board_validation/cartesian_dsm
```

The board-level claim is external-output consistency for the first-order
mainline, not full global sample-by-sample certification of the complete RFSoC
system.

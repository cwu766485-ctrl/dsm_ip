# Data

This folder contains the small-to-moderate evidence data needed to reproduce the
board-validation checks.

## `board_validation/cartesian_dsm`

Preserved inputs include:

- `DSM000.Wfm.csv`: principal oscilloscope capture used for the retained
  identity and spectrum evidence.
- `RefCurve_scope_aux.Wfm.csv`: supplementary capture used for
  recovery robustness checks.
- recovered `*_bits_01.txt` files used by the MATLAB board-validation scripts.
- ROM/COE/MAT files needed by the preserved first-order replay and comparison
  flow.

These files are intentionally committed even though the two waveform CSV files
are relatively large. They are below GitHub's hard 100 MB per-file limit and are
the minimum practical dataset for direct project reproduction without requiring
access to the original oscilloscope export folder.

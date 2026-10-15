# MATLAB DSM Models

- `bittrue/p0_dsm_bittrue.m`: fixed-point reference for the P0 single-bit
  low-pass cores.
- `cartesian_dsm/dsm_singlebit/`: small algorithm-name wrapper around the
  single-bit reference.
- `cartesian_dsm/dsm_multibit/`: multi-bit algorithm models, metrics, and
  sample-by-sample RTL output comparison.
- `scripts/entry_p0_*.m`: P0 vector generation, evaluation, and comparison.

Run `path_setup` from MATLAB after changing into the `matlab/` directory. The
input scale, accumulator width, saturation mode, and quantizer resolution are
part of a comparison; do not compare only by algorithm label.

# LP DSM Workspace

This directory keeps the retained low-pass / IF Cartesian DSM MATLAB flow.

## Structure

| Path | Purpose |
|---|---|
| `core/` | Waveform generation, DSM evaluation, metric helpers, and retained sweeps |
| `path_setup.m` | Adds `core/` to the MATLAB path |

The previous broad workspace split is not part of this cleaned handoff. Only
the retained `core/` path is expected to exist here.

## Usage

```matlab
cd matlab/cartesian_dsm/DSM_2nd/lp
path_setup
```

Most current flows are called through the top-level `matlab/scripts` entry
points, so users normally run `matlab/path_setup.m` from the top-level MATLAB
folder instead.

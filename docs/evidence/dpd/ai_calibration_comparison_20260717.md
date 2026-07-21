# AI-Assisted DPD Calibration Comparison

Generated from the held-out memory-polynomial DPD comparison and the isolated observer-v2 blind PA matrix. The PA is behavioral; no physical RF claim is made.

## DPD Linearization

| Mode | Mean EVM % | Mean NMSE dB | Mean SNDR dB | Mean ACLR dBc | DPD saturation | Drive limited |
|---|---:|---:|---:|---:|---:|---:|
| No DPD | 4.305013 | -27.326263 | 27.326263 | -32.159925 | 0 | 0 |
| Memoryless DPD | 3.117541 | -30.123855 | 30.123855 | -32.557627 | 0 | 0 |
| Memory-polynomial DPD | 2.827825 | -30.971072 | 30.971072 | -32.507411 | 0 | 0 |

## AI Seed and Search Policy

| Strategy | Seed source | Final selection | Candidate records | Safety evidence |
|---|---|---|---:|---|
| Fixed package + local search | Static package | Bounded local search | 14 | Baseline; final cost from search |
| Waveform LUT + local search | Training-waveform LUT | Bounded local search | 14 | LUT safety arbitration |
| Observer-v2 tree -> LUT + local search | Frozen Q12.20 tree, then LUT fallback | Bounded MP local search | 14 | Tree never enables direct execution |

## Isolated Blind PA Evaluation

| Blind profile | Conditions | Tree seeds | LUT seeds | Default fallback | Seed safety violations | Mean seed regret | Final candidates |
|---|---:|---:|---:|---:|---:|---:|---:|
| blind_compression_noise | 24 | 10 | 11 | 3 | 5 | 718.000 | 14 |
| blind_gain_memory | 24 | 12 | 9 | 3 | 5 | 216.708 | 14 |
| blind_thermal_memory | 24 | 8 | 13 | 3 | 9 | 675.333 | 14 |

Overall blind seed safety violations: `19`. Tree/LUT/default seed counts: `30`/`33`/`9`.

The blind policy evaluation judges only the seed package because the behavioral data labels package-stage costs. On PS, every selected seed still executes the same 14-record deterministic local search and final replay. The observer-v2 feature source must be a completed aligned complex-feedback window; post-DSM monitor proxies are not substituted for it.

# Observer-v2 Blind PA Evaluation

The frozen model and waveform LUT were fitted only on the 12-profile training matrix. Every evaluated action remains a mandatory 14-candidate local search.

| Blind profile | Conditions | Tree seeds | LUT seeds | Default fallback | Seed safety violations | Mean seed regret | Local candidates |
|---|---:|---:|---:|---:|---:|---:|---:|
| blind_compression_noise | 24 | 10 | 11 | 3 | 5 | 718.000 | 14 |
| blind_gain_memory | 24 | 12 | 9 | 3 | 5 | 216.708 | 14 |
| blind_thermal_memory | 24 | 8 | 13 | 3 | 9 | 675.333 | 14 |

Overall seed safety violations: `19`. Tree/LUT/default seed counts: `30`/`33`/`9`.

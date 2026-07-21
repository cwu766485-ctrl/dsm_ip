# Safety-First DPD Seed Policy

The three `blind_*` PA profiles are frozen final-test data and are never used for fitting, threshold selection, or model choice. A package is seeded only when all same-waveform nearest nonblind observations are safe and the nearest monitor state is inside the selected finite distance bound; cost ranks only those safety-qualified packages. Every action remains a 14-candidate local search.

| Data split | Conditions | Safety-qualified seeds | Fallback-14 | Unsafe selected seeds | Mean seed regret |
|---|---:|---:|---:|---:|---:|
| Development PA LOSO | 192 | 129 | 63 | 0 | 208.922 |
| Frozen final blind PA | 72 | 49 | 23 | 0 | 159.633 |

Selected only from development LOSO: `k=7`, `max_distance=4.0`. Promotion allowed: **True**. Direct execution remains disabled.

# Tiny MLP Seed Selector Strict LOSO

Simulation-only model. Every selected seed still runs the mandatory 14-candidate bounded search.

| Split | Accuracy | Mean regret | Max regret | Mean delta vs fixed package 3 | Wins | Failures selected/fixed/new | Promoted |
|---|---:|---:|---:|---:|---:|---:|---|
| profile | 0.7083 | 8.248 | 135.496 | -94.010 | 248/288 | 108/110/0 | True |
| waveform | 0.6076 | 12.782 | 372.107 | -89.476 | 242/288 | 108/110/0 | True |
| seed | 0.6042 | 15.854 | 638.247 | -86.404 | 226/288 | 109/110/0 | True |

Deployment remains disabled regardless of this behavioral result.

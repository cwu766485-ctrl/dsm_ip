# DSM V1.3 RF and Digital Performance Comparison

## Measurement boundary

One coherent tone vector set was used for EF1, EF2, and the MASH block
experiment: 448 complex input samples, tone bin 7, signed amplitude 3277
(approximately 0.1 full scale), with source frame markers at beats 1, 9, and
21 and Q14 frame gains 16384, 14336, and 12288. EF1 and EF2 produced actual
Thermo5 Product Top four-plane PA traces. MASH produced actual legacy wrapper
stage/combined outputs only; it has no Product PA/serializer route.

## RTL-captured results

| Metric | EF1 Product | EF2 Product | MASH 1-1 block |
|---|---:|---:|---:|
| Independent bit-true check | PASS, 56/56 words across 4x64-bit planes | PASS, 56/56 words across 4x64-bit planes | PASS, 448/448 output transactions at common-tone capture |
| Source handshakes | 32 AXIS beats | 32 AXIS beats | 448 scalar valid samples |
| First input-to-output latency | 145.746 ns | 141.174 ns | Not product comparable; wrapper output alignment still OPEN |
| Measured output throughput | 164.791 M PA words/s under this run's PA-ready pattern | 148.515 M PA words/s under this run's PA-ready pattern | 100 M combined-level samples/s in block capture |
| Captured output records | 56 PA words / 3,584 serialized bits | 56 PA words / 3,584 serialized bits | 448 combined-level records |
| Calibrated SNR / SNDR / EVM | NOT RUN | NOT RUN | NOT RUN as an RF metric |
| Standard ACLR / channel mask | NOT RUN | NOT RUN | NOT RUN |
| Calibrated output power | NOT RUN | NOT RUN | NOT RUN |
| Hardware receive-chain BER | NOT RUN | NOT RUN | NOT RUN |

The throughput and latency rows are observed simulation measurements from one
directed capture with PA-ready stress. They are not clockspec, sustained-rate,
or signoff guarantees. EF1 and EF2 raw PA PSD and reconstructed baseband are
saved in the run directory and indexed by hashes.

The MASH analysis script also reports a normalized digital diagnostic for the
captured signed combined-level samples: fitted-gain EVM proxy 1827.15%, full
record residual SNDR -25.24 dB, and 0–0.10 full-scale in-band SNDR 1.45 dB.
These values expose that the chosen low-amplitude tone and legacy output
alignment/combiner are not yet a calibrated performance test. They are not
comparable with a product RF EVM/SNDR requirement and have no pass threshold.
The script reports a 23.74 dB high-band to low-band residual power difference
for this diagnostic vector only; it is not a proven noise-shaping spec.

## Missing inputs for RF signoff

Standard EVM/SNR/SNDR/ACLR and transmit power require an agreed RF sample rate,
PA/lane encoding, gain normalization, channel offsets and measurement mask.
BER requires a receive chain, modulation/coding, channel and error-count
budget. None are defined for the MASH Product SKU in this branch. Do not infer
these outcomes from the digital PSD screen. Hardware RF measurements were not
run.

Machine metrics and PSD CSV hashes are indexed in
`docs/verification/data/dsm-v13-round1/evidence.json` and
`docs/verification/data/dsm-v13-round1/source_manifest.json`.

# Thermo5 TX algorithm and worst-case model campaign

**Status:** `LINUX_MODEL_CAMPAIGN_COMPLETE; SYSTEM_TARGET_UNDEFINED; PHYSICAL_SIGNOFF_OPEN`
**Date:** 2026-10-29 (Asia/Singapore)
**Product configuration:** centered-cubic x2 / EF2 order 2 / STEP 5120 / 20-bit state / four thermometric planes. No product default was changed.

The campaign is a deterministic Python behavioral study. It covers the Linux
software work in the TX closure plan: held-out EF2 parameter confirmation,
backoff/PAPR development sweep, state-width sensitivity, fixed-image DPD A/B,
and four-plane gain/skew/fault sensitivity. It does not model a calibrated
device or certify an RF link. Exact commands, source revisions, and hashes are
recorded in [`thermo5-tx-gate2-evidence.json`](thermo5-tx-gate2-evidence.json).

## EF2, input level, backoff, PAPR, and state width

The staged sweep uses four development seeds (`271001,271003,271005,271007`)
and four disjoint held-out seeds (`281001,281003,281005,281007`), 12 OFDM
symbols per seed, 256-QAM, 4096-point FFT, 512-sample cyclic prefix, and 584
active subcarriers. The held-out winner is tested on 224,256 uncoded bits.
The recorded development grid covers RMS drives 0.06/0.08/0.10, backoff
0/3/6 dB, no/7/9 dB radial PAPR limiting, STEP 4864/4992/5120/5248/5376,
and model state widths 18/19/20. The JSON records the staged cases rather
than claiming an unrun full Cartesian product.

| Held-out configuration | Result |
| --- | ---: |
| RMS drive 0.10, STEP 5120, 20-bit state, 0 dB backoff, no PAPR clip | 21 / 224,256 uncoded bit errors; BER `9.3643e-5`; mean EVM 2.4640%; mean SNDR 32.1675 dB |
| Same digital result through nominal modeled DPA/output/noise chain | 32 / 224,256 errors; BER `1.4269e-4`; mean EVM after noise 2.5952%; modeled output power -30 dBm |
| Same digital result through stress modeled DPA/output/noise chain | 173 / 224,256 errors; BER `7.7144e-4`; mean EVM after noise 2.9978%; modeled output power -50 dBm |
| 18-bit state model at the selected RMS/STEP | 30 state saturation samples across held-out set; not acceptable as a width-reduction basis |
| 19-bit state model at the selected RMS/STEP | No state saturation in this finite set; remains unqualified for RTL reduction |
| 20-bit state model at the selected RMS/STEP | No state saturation in this finite set; retain current width |

This is uncoded natural-binary BER, with no FEC. Errors are nonzero in every
selected case. No product BER/BLER/EVM/ACLR/power acceptance target was
provided, so the result is `TARGET_UNDEFINED`, not a claim of stable QAM256
transmission. The DPA AM/AM, AM/PM, memory, output network, signal power,
thermal noise and noise figure are explicit illustrative assumptions, not
device or board calibration. The reported adjacent-band quantity remains an
ACLR proxy; it is not standards-measured ACLR.

## Fixed-image DPD A/B

All candidates use the same four held-out seeds, 9 symbols per seed, RMS 0.10,
STEP 5120, and a 4097-tap offline receive filter. The 2/4-tap coefficients
are verification images already used by bit-true tests; they were not fitted
to invert the behavioral PA or to these held-out seeds.

| Fixed coefficient image | Digital BER | Digital EVM | Nominal modeled BER | Stress modeled BER | Disposition |
| --- | ---: | ---: | ---: | ---: | --- |
| 1-tap identity | 7 / 168,192 (`4.1619e-5`) | 2.4651% | `7.7293e-5` | `7.3131e-4` | Keep as reference |
| Non-identity 2-tap verification image | 126 / 168,192 (`7.4914e-4`) | 3.0433% | `1.2188e-3` | `3.0917e-3` | Reject this image only |
| Non-identity 4-tap verification image | 1,125 / 168,192 (`6.6888e-3`) | 4.0508% | `8.4725e-3` | `1.3217e-2` | Reject this image only |

The tested non-identity images are worse than identity in this experiment.
That rejects these coefficients, not every possible 2/4-tap predistorter.
Fitted coefficients, an RTL/PA bit-true calibration flow, and FPGA resource
cost are not established. The ZU15EG GT parent remains one-tap identity.

## Four-plane sensitivity and fault cases

The branch study uses the same 4 held-out seeds and 12 symbols per seed as the
EF2 result above. It applies a 4-point Lagrange envelope delay plus FS/4
carrier phase rotation, branch gain mismatch, or one-branch dropout before
reconstruction. These are sensitivity coordinates, not product tolerances.

| Scenario | Digital BER | Digital EVM | Stress modeled BER | Interpretation |
| --- | ---: | ---: | ---: | --- |
| Baseline | 21 / 224,256 (`9.3643e-5`) | 2.4640% | `7.7144e-4` | Reference |
| Skew 2–20 ps | `8.9184e-5` to `1.0256e-4` | 2.4642–2.4680% | `6.7300e-4` to `7.2685e-4` | Variation is small relative to the finite-seed uncertainty; no tolerance inferred |
| Gain mismatch 0.2–1 dB peak-to-peak | `9.3643e-5` | 2.4640–2.4644% | `7.4468e-4` to `7.8036e-4` | No product branch-matching limit inferred |
| Branch dropout 0–3 | `9.3643e-5` to `1.9620e-4` | 2.4689–2.5111% | `1.1861e-3` to `1.5652e-3` | Expected fault cases; not legal steady-state operation |

The sensitivity model omits GT electrical jitter, DAC reconstruction error,
package coupling, measured PA behavior, and calibrated receiver effects. No
hardware tolerance or fault-detection claim follows from this screen.

## RTL candidates and implementation comparison

The pair-look-ahead candidate remains separate from the product hierarchy.
Its Gate 1 4,096-cycle bit-true miter and scoped VC Formal pass establish the
tested equivalence contract; no Fmax/LUT/FF/DSP or routed comparison is
available in this Linux flow. Therefore `PAIR_LOOKAHEAD=0` remains the
product setting. The 2/4-tap bit-true UVM results are documented in the
Gate 1 report; this communication A/B does not support promoting those taps.

## Reproduction and limits

Python source, held-out seeds, exact sweep parameters, full JSON output, logs,
and SHA-256 evidence are indexed by
[`thermo5-tx-gate2-evidence.json`](thermo5-tx-gate2-evidence.json). Runtime
outputs stay under ignored `runs/`; generated reports and model data are not
checked into source control. Physical BER, calibrated EVM/ACLR/power, FEC
performance, DPA/DAC/GT hardware, and FPGA PPA remain OPEN.

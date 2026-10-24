# Python Bit-Exact Reference Models

The models use Python integers to make two's-complement width, wrap,
saturation, state order, and latency explicit. They require only Python's
standard library.

## Frozen Thermo5

`dsm_refmodel/thermo5.py` implements the thermo5 fixed-point chain: frame
Q2.14 gain, causal or centered-cubic interpolation, optional memory-polynomial
DPD, four Cartesian TID branches, and the four 64-bit output planes. Its
hexadecimal `.mem` files are consumed directly by the thermo5 UVM scoreboard.
MATLAB is not needed to generate vectors on Linux. The frozen SKU remains
identity DPD; `nonlinear_test` is a verification image, not a calibrated or
identified DPD solution.

Generate deterministic vectors:

```bash
python3 generate_thermo5_frontend_vectors.py \
  --output-dir ../../../../runs/thermo5_python_vectors \
  --words 56 --seed 20260930 --profile random --interp-taps 2 \
  --frame-start-words 1,15,36
```

Then use those vectors as the Linux UVM oracle by running from the repository
root:

```bash
make -C dv/uvm/sim thermo5-vcs-regression PYTHON=python3 \
  THERMO5_VECTORS="$PWD/runs/thermo5_python_vectors" \
  THERMO5_OUT="$PWD/runs/thermo5_python_vcs"
```

To check the Python model against an existing MATLAB stimulus set, reuse its
I/Q and frame-metadata files and write the Python output to a separate
directory:

```bash
python3 generate_thermo5_frontend_vectors.py \
  --input-dir /path/to/matlab/vectors \
  --output-dir ../../../../runs/thermo5_python_from_matlab
```

The frozen DPD configuration is identity (`active_taps=1`, `c1_re=0x4000`,
other coefficients zero). The optional polynomial model uses the RTL's signed
Q2.14 coefficients, arithmetic shifts, tap history, and signed-16 saturation.
The directed nonlinear image is a two-tap verification configuration with
nonzero cubic terms. PA behavior and RF effects remain outside this model.
Python-native random source vectors are deterministic but do not reproduce
MATLAB's `rng` sequence; use `--input-dir` for a sample-by-sample comparison on
shared stimulus.

Generate centered-cubic nonlinear DPD vectors for one short packet, or two
consecutive one-quantum packets:

```bash
python3 generate_thermo5_frontend_vectors.py \
  --output-dir ../../../../runs/thermo5_centered_nonlinear_vectors \
  --words 112 --seed 610214 --interp-mode centered_cubic \
  --dpd-profile nonlinear_test --frame-start-words 1,57 \
  --frame-gains 16384,16384
```

The UVM target `make -C dv/uvm/sim thermo5-axil-centered-nonlinear-bittrue-vcs`
generates 56-word and 112-word cases, programs the same two-tap coefficient
image, and compares all four PA planes. The low-power packet-drain target is
`make -C dv/uvm/sim thermo5-centered-cubic-low-power-vcs`.

## Interpolation Communications Screen

`benchmark_thermo5_interp.py` compares two cascaded x2 stages using the RTL
2-, 3-, and 4-tap presets, a forward midpoint average, and a centered cubic
Lagrange candidate. It runs deterministic 64-QAM OFDM and reports raw EVM,
EVM after one best-fit complex gain/phase per symbol, adjacent-band leakage
proxy, and first interpolation-image rejection:

```bash
python3 benchmark_thermo5_interp.py --symbols 64 --seed 20261022
```

The centered cubic candidate produced the lowest corrected EVM in the current
screen. An optional streaming implementation now exists behind
`INTERP_CENTERED_CUBIC=1`; the current causal path remains the default. The
centered path uses future samples, elastic ready/valid stages, and a tagged
synthetic zero-source lookahead vector to flush each frame through stage 2. Its
bit-true UVM target is `make -C dv/uvm/sim thermo5-centered-cubic-vcs` with
Python oracle vectors supplied through `THERMO5_VECTORS`. The reported
adjacent-band quantity is not standard ACLR; this screen excludes TID, PA, RF
filters, and receiver recovery.

The selected FIR candidate is the centered half-sample cubic
`[-1, 9, 9, -1]/16` in each of the two x2 stages. The FPGA preset remains on
the causal two-tap path; enable the optional implementation explicitly for
verification and later FPGA resource/timing evaluation.

### P0 FIR and input-drive A/B sweep

`benchmark_thermo5_architecture.py` runs the first architecture screen with a
shared 256-QAM OFDM waveform, 256-point FFT, 64 active carriers, 1 GHz complex
sample rate, and 250 MHz occupied bandwidth. It compares the frozen causal
2-tap baseline and other interpolation candidates under identical DPA,
output-network, and thermal-noise assumptions. The sweep covers fixed-average
power and peak-normalized inputs, no/7/9 dB radial PAPR limiting, and 0/6/12 dB
input backoff. The default split uses two development seeds and three held-out
seeds, with eight OFDM symbols per seed.

```bash
python3 benchmark_thermo5_architecture.py --symbols-per-seed 8 \
  --development-seed-count 2 \
  --seeds 20261024,20261025,20261026,20261027,20261028 \
  --json ../../../../runs/thermo5_architecture_ab_20261024/summary.json \
  --psd-csv ../../../../runs/thermo5_architecture_ab_20261024/psd.csv
```

The JSON reports raw and scalar-corrected EVM, in-band SNDR proxy, ACLR proxy,
PSD, input clipping, DPA overload, assumed output power, and both fixed-timing
and integer-delay-aligned metrics. Each candidate's delay alignment was
consistent across the cases in this run. Across 450 candidate/configuration/
seed cases, centered cubic ranked first in corrected EVM for all 18 held-out
normalization/PAPR/backoff combinations; it also ranked first in each of the
three held-out seeds when scored separately.

For fixed-average input power with no PAPR limiting, the three held-out seeds
gave centered-cubic corrected EVM means of 4.853%, 0.802%, and 0.871% at 0, 6,
and 12 dB backoff (ranges 4.777–4.947%, 0.791–0.822%, and 0.868–0.874%). The
corresponding assumed output powers averaged -30.00, -35.66, and -41.63 dBm;
in-band SNDR proxies averaged 27.75, 44.31, and 47.35 dB. Thus 6 dB is a
useful point in this model: it lowers corrected EVM substantially while
reducing assumed output power by about 5.66 dB; 12 dB adds little EVM gain and
costs another 5.97 dB. At 6 dB backoff, a 7 dB PAPR limit raised the held-out
mean corrected EVM from 0.802% to 2.233% and worsened the adjacent-band proxy
from -49.00 to -37.41 dBc. A 9 dB limit had little effect on average. These
results do not establish a universal backoff or clipping optimum.

The aligned RTL 2-tap baseline's corrected EVM was about 36.8% at 6 dB in
this exact waveform comparison, far above the centered-cubic result. The
follow-on raw TID receiver benchmark below now audits the RTL2 even/odd
sample-time convention and measures it through the actual four-plane output.
The centered cubic remains the preferred Python FIR candidate; the frozen
FPGA RTL is not changed by either screen.

This initial screen is a complex-baseband surrogate around the interpolation
FIR, behavioral DPA, output FIR, and kTB/NF noise. The DPA and noise settings
are illustrative, the PAPR limiter is radial clipping rather than a production
CFR, and centered interpolation uses periodic block edges. It did not include
the four-plane TID output. The next section adds that path and an OFDM receiver;
the results are still a three-seed, eight-symbol screen rather than calibrated
PA/board evidence or FPGA PPA/timing signoff. STEP and DSM-order sweeps remain
open.

### P0 raw TID-plane to OFDM receiver benchmark

`benchmark_thermo5_tid_receiver.py` closes the sample-time audit through the
frozen four-plane TID output and a baseband OFDM receiver. It uses the current
8-lane, 218.75-MHz ingress rate (1.75-GHz complex samples), two x2 stages
(7-GHz complex TID input), and the 14-GS/s serialized Fs/4 output. Bit zero is
the earliest serialized sample. The receiver combines each plane as bipolar
`-1/+1`, applies the Fs/4 NCO at 3.5 GHz, then uses declared Blackman FIRs at
14 and 7 GHz before decimating by 2 and 4 to 1.75 GHz. The 4,097-tap filters
use a `0.75 * occupied_bandwidth` cutoff and are centered offline for this
measurement; no timing search or per-subcarrier equalizer is used.

The TID output is checked against four independent scalar first-order EFM
recurrences, including each branch offset and I/Q parity. The frozen Python
frontend drops its first 32-sample TID word, so the aligned stream is cropped
by 1,024 complex samples at 7 GHz (2,048 raw samples) before demodulation.
The 250-MHz test uses 256-QAM, 4,096-point FFT, 512-sample CP, 584 active
carriers (249.512-MHz actual occupancy), eight OFDM symbols, and seeds 101,
307, and 503. To satisfy the same 0.35 peak-drive ceiling for all three Python
seeds, the common input RMS is 0.10; seed 307 exceeded the peak ceiling at
0.11 RMS and that run was excluded.

Three-seed results, with one global complex gain fit over active QAM symbols:

| Candidate | Digital EVM / SNDR | Nominal DPA + output network + kTB/NF | Stress DPA + output network + kTB/NF |
| --- | --- | --- | --- |
| Frozen RTL2 | 20.827% / 13.628 dB | 21.004% / 13.554 dB | 21.438% / 13.377 dB |
| Centered cubic | 3.273% / 29.702 dB | 3.370% / 29.447 dB | 3.685% / 28.671 dB |

Every branch/component scalar-TID audit had zero mismatches across 1,335,296
compared samples per candidate and seed. The centered-cubic digital and
nominal cases meet the current 3.5% EVM / 29.12-dB SNDR screen on all three
seeds; the illustrative stress case does not. The EVM difference also
confirms the time-label issue in the frozen two-tap setting: RTL2 outputs
`x[n]` at the even phase and `(x[n] + x[n-1])/2` at the following odd phase.
If that odd phase is labeled `n+0.5`, this causal average estimates the
previous midpoint. The centered cubic uses `[-1, 9, 9, -1]/16` around the
half-sample and needs future values.

For the two centered stages, the exact support analysis gives a maximum future
dependency of 2.25 source samples. A causal implementation therefore needs
three integer source samples of lookahead; with eight input lanes this crosses
one input transaction. At an explicit frame end, append three zero source
samples before the two stages and keep only the original frame's 4x output.
The current Python candidate does this block-mode extension; it is not a
streaming RTL implementation. The frozen parallel-config interface has no
`TLAST`, so variable-length frames need an explicit end marker or a known
fixed-length schedule before an RTL implementation can flush the tail. The
optional AXI-Lite wrapper already carries `TLAST`. No FPGA resource, timing,
or power evaluation was run.

The nominal/stress output profiles use behavioral DPA AM/AM, AM/PM and memory,
a complex output-network FIR, and stochastic AWGN using `kTB + NF`. They are
illustrative link sensitivities, not calibrated PA or board results. Digital
quantization/interpolation errors remain deterministic distortion; random
thermal noise is added only in the output-chain cases. The 6-dB backoff in the
earlier sweep means an amplitude scale of `10^(-6/20) = 0.501` and a power
scale of `10^(-6/10) = 0.251`; it is relative to a reference drive. A PAPR
limit instead caps the peak-to-average ratio and is not a drive backoff.
Reports are in `runs/thermo5_tid_receiver_20261024/summary.json`.

## Digital GT errors and analog output-chain screen

`benchmark_thermo5_gt.py` applies independent data-bit errors to the actual
four 64-bit TID output planes produced by the Python thermo5 bit-true model.
It reports bit and word error counts; this is a digital fault model, not
additive noise or an electrical GT/CDR simulation:

```bash
python3 benchmark_thermo5_gt.py --words 56 --seed 20261023 --ber 1e-3 \
  --json ../../../../runs/thermo5_gt_bit_errors/summary.json
```

`benchmark_thermo5_link.py` compares the interpolation candidates through a
deterministic complex-envelope DPA, an output-network FIR, and optional analog
thermal noise. It reports interpolation EVM, EVM after deterministic DPA and
network distortion, EVM after noise, and the noise-only EVM contribution:

```bash
python3 benchmark_thermo5_link.py --symbols 64 --seed 20261023 \
  --json ../../../../runs/thermo5_link_benchmark/summary.json
```

Customize the declared observation-plane power, noise bandwidth, receiver
noise figure, temperature and DPA assumptions (example values are illustrative):

```bash
python3 benchmark_thermo5_link.py --profiles custom --symbols 64 --seed 7 \
  --signal-power-dbm -40 --noise-bandwidth-hz 20000000 \
  --noise-figure-db 6 --temperature-k 290 \
  --dpa-saturation 0.76 --dpa-ampm-degrees 7
```

The digital RTL path is deterministic: quantization and interpolation error
are distortion, not injected random noise. The GT helper models discrete bit
errors at the TID-plane boundary, not timing jitter, line coding, CDR, or an
electrical eye. The DPA and output FIR parameters are deterministic behavioral
approximations. Thermal noise is calculated from `kTB + NF` and converted to
normalized waveform units using the declared average signal power at the
observation plane. Those power, bandwidth and NF values must be replaced by
board/circuit measurements before interpreting absolute EVM. The model does
not claim ADS or transistor-level accuracy and does not calculate standard
ACLR.

The EVM is measured in the oversampled waveform domain against an ideal 4x
reference, with one complex scalar fit per OFDM symbol. There is no receiver
demodulator, channel estimator, or per-subcarrier equalizer in this screen.

The earlier sample-payload GT/AWGN screen is superseded by these separated
models. The four-plane GT bit-error benchmark measures digital errors only;
the link screen measures deterministic distortion and analog noise separately.
Neither benchmark changes the frozen FPGA RTL configuration.

At 64 symbols and seed 20261023, centered cubic corrected EVM was 0.966% in
the ideal screen versus 4.939% for forward-linear. In the illustrative nominal
DPA/network/noise profile, corrected EVM was 1.699% versus 5.039%; in the
stress profile it was 3.404% versus 5.692%. Stress raw EVM was 6.337% for
cubic and 6.216% for forward-linear, so the winner depends on whether the
receiver's scalar gain/phase correction is part of the metric. The stress
profile's thermal-noise-only EVM contribution was about 1.3% at a calculated
37.95 dB SNR. These figures are sensitivity results, not calibrated link
predictions. The 56-word GT demonstration used BER 1e-3 and observed 14 flips
in 14,336 plane bits (13 affected words); that short run is only an injector
sanity check, not an estimate of a low production BER.

## Legacy AXI-IP Models

The remaining `interp.py`, `dpd.py`, and vector scripts model the older AXI-IP
regression. MATLAB remains its algorithm and fixed-point cross-check source.
The old mode-0..4 `interp.py` tables are not the thermo5 x2 interpolator.

Run the pure Python tests with:

```bash
python3 -m unittest discover -s tests -v
```

For the legacy AXI-IP MATLAB comparison, use the commands and comparison gate
documented by the AXI-IP test flow. The thermo5 Python generator is the
separate Linux route for the frozen four-plane UVM oracle.

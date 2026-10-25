# Thermo5 fixed-point EF2 boundedness and verification status

## Candidate recurrence

The optional `TIDSM_ORDER=2` branch processes each 32-sample vector in
lane order. I and Q are independent. In signed Q1.15 integer units, each
branch first applies its configured offset and signed-16 saturation, then
computes

```text
u[n] = x[n] + 2*e1[n-1] - e2[n-1]
y[n] = +32768, when u[n] > 0; otherwise -32768
e_raw[n] = u[n] - y[n]
e[n] = sat_signed_20(e_raw[n])
e2[n] = e1[n-1]
e1[n] = e[n]
```

The quantizer output is the sign bit used by the existing Fs/4 plane-packing
contract. The ideal, unsaturated error-feedback loop has
`NTF=(1-z^-1)^2`; when the state clamp activates, the nonlinear clamped loop no
longer has that exact NTF.

## Inductive no-wrap bound

For the default W=16 implementation, the input presented to the recurrence is
signed 16-bit and therefore `|x| <= 32768`. The two signed 20-bit Q4.15 state
registers are clamped to `[-524288, 524287]`, so `|e1|, |e2| <= 524288`.
Assume both states satisfy that bound. Then

```text
|u| <= 32768 + 2*524288 + 524288 = 1605632 = 49*32768
|e_raw| <= |u| + 32768 <= 1638400 = 50*32768
```

The signed 22-bit Q6.15 temporary covers `[-64, 64)`, so both `u` and
`e_raw` fit without arithmetic wrap. `e_raw` is then clamped into the signed
20-bit state range by construction. Reset initializes both states to zero;
therefore induction proves that all subsequent state values remain in range
for every sequence of signed-16 inputs, including inputs that trigger the
clamp. The same argument applies independently to I, Q, and each of the four
offset branches. The state only advances on an accepted input word, so
backpressure preserves the invariant.

This proves bounded fixed-point arithmetic and absence of state wrap. It does
not prove that the ideal, unclamped second-order loop remains unsaturated for
every possible input. A state clamp changes the loop dynamics and can degrade
noise shaping; that event is counted in the Python model and should remain
zero for an intended operating profile.

## RTL implementation and limits

`tid32_cartesian_ef2_fs4_gt_tx.sv` is an optional one-word-per-cycle prototype.
It unrolls the 32 scalar recurrences in a combinational chain and updates its
four error histories per I/Q branch only when the raw output boundary accepts
the input word. `TIDSM_ORDER=1` remains the default throughout the frontend
wrappers. The candidate's STEP is selectable through the wrapper; the current
communications finalist is STEP=5120.

This implementation deliberately favors scalar bit-true semantics over
timing. The 32 serial recurrence levels are a substantial combinational path.
No FPGA synthesis, resource, or timing result is claimed. A throughput-preserving
registered or look-ahead architecture would be a separate microarchitecture
change requiring a new proof and bit-true comparison.

## Python evidence

`thermo5.py` contains the fixed-point word oracle, and
`thermo5_experiments.py` contains an independent integer sample-stream model.
The unit test compares their four 64-bit planes for random 32-sample words.
The 56-word UVM oracle is generated with:

```bash
python3 dv/uvm/refmodel/python/generate_thermo5_frontend_vectors.py \
  --output-dir runs/thermo5_ef2_centered_vectors_20261024 \
  --words 56 --seed 1101 --profile random --interp-mode centered_cubic \
  --tidsm-order 2 --step 5120
```

The 256-QAM screen uses 4096-point FFT, 512-sample CP, 584 active carriers,
eight symbols each for seeds 101, 307, and 503, and centered-cubic x2
interpolation. With integer EF2 at STEP=5120, it reports 2.4724% mean /
2.4890% worst-seed digital EVM and 32.138 dB mean SNDR, with 4 symbol errors
and 5 natural-binary bit errors among 14,016 decisions. The nominal and stress
output-chain sensitivity cases report 2.6023% and 3.0036% mean EVM. Both input
and error-state saturation counts are zero; the largest observed state and
quantizer-input magnitudes are 4.9764 and 5.9764. The DPA, output network,
power, kTB, and noise-figure settings are illustrative, not measured device
data. These finite runs do not establish a production BER guarantee.

Python unit tests pass. On 2026-10-25, VCS V-2023.12-SP1 compiled and ran the
focused 56-word UVM bit-true test with `TIDSM_ORDER=2`, STEP=5120, and centered
cubic interpolation. It reported 32 source words, 56 four-plane output words,
zero plane mismatches, and zero UVM_ERROR/FATAL. The run is under
`runs/thermo5_ef2_robust_20261025/vcs/`; matching vectors are in the same
run directory. This closes the focused simulator check for the current 20-bit
candidate, not the full EF2 regression or a reduced-state RTL. No formal
engine is available on this host. XSim and FPGA mapping/timing were not run.
Do not label the candidate fully simulator- or formally-qualified until the
full regression and the remaining implementation checks run.

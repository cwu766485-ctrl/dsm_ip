# Thermo5 fixed-point EF2 boundedness and verification status

Current integrated thermo5 defaults are centered-cubic x2 interpolation and
EF2 TIDSM (`TIDSM_ORDER=2`, `STEP=5120`). The first-order TIDSM remains
available with `TIDSM_ORDER=1`, `STEP=7168`; causal interpolation remains
selectable with `INTERP_CENTERED_CUBIC=0`.

## Candidate recurrence

The main thermo5 configuration uses `TIDSM_ORDER=2` and `STEP=5120`. It
processes each 32-sample vector in lane order. I and Q are independent. In
signed Q1.15 integer units, each
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

`tid32_cartesian_ef2_fs4_gt_tx.sv` implements the main thermo5 TIDSM. The
frontend wrappers and ZU15EG GT parent default to centered-cubic
interpolation and `TIDSM_ORDER=2`, `STEP=5120`.
The first-order fallback remains available as `TIDSM_ORDER=1`; its benchmarked
setting is `STEP=7168`. EF2 unrolls the 32 scalar recurrences in a combinational
chain and updates its four error histories per I/Q branch only when the raw
output boundary accepts the input word.

This implementation deliberately favors scalar bit-true semantics over
timing. The 32 serial recurrence levels are a substantial combinational path.
No FPGA synthesis, resource, or timing result is claimed for the EF2 default.
A throughput-preserving registered or look-ahead architecture would be a
separate microarchitecture change requiring a new proof and bit-true comparison.

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

By 2026-10-28, VCS V-2023.12-SP1 passed the full generic-FIFO regression and
the AXI-Lite regression with the main EF2 defaults (`TIDSM_ORDER=2`,
`STEP=5120`). The centered-cubic EF2 qualification also passed: a 2,072-word
continuous frame had zero output gaps and zero source stalls; a two-stream
stress run produced 4,144 bit-true four-plane words, hit 194 positive and 12
negative state clamps, held a clamp candidate under PA backpressure for eight
cycles without state movement, then passed reset and replay checks. The random
2,072-word run included PA backpressure and cleared all 16 DPD counters on
reset. The Python oracle matched each checked PA plane.

The separate four-PA behavioral serializer loopback also passed in VCS for
the centered-cubic EF2/STEP=5120 configuration: 56 words and 3,584 serialized
bits per path were reassembled in order and matched the Python four-plane oracle. This
checks the modeled digital user/serial boundary, not the GT Wizard or a
physical link.

The EF2 qualification URG group covered all four positive-candidate/stall,
negative-candidate/stall, positive-rail, and negative-rail cross bins. This is
targeted functional coverage, not complete code-coverage closure. The
centered-cubic generic regression raw URG reports 81.39% aggregate score
(88.04% line, 70.04% condition, 81.16% toggle, 100% FSM, 73.45% branch, and
76.47% assertion); this includes UVM and RTL and is not a signoff threshold.
Runs and reports are under ignored `runs/thermo5_ef2_qualification/`.
`vcs_current_centered/qualification_manifest.json`
records the Git revision and changed-file hashes, VCS version, fixed
configuration/seeds, oracle SHA256 values, test-log hashes, URG hashes, and
required functional-bin disposition.

No formal engine, XSim, Vivado XPM source package, or GT Wizard simulation
model is available on this Linux host. Therefore XPM-specific coverage,
formal proof, GT serializer/TXP behavior, FPGA synthesis/timing, and PPA remain
open. The four PA planes are checked at the digital user-word boundary; this
does not establish stable physical QAM256 transmission. The held-out Python
QAM256 screen had nonzero uncoded bit errors and the analog-chain assumptions
are not calibrated. Keep the 20-bit EF2 state and require board/receiver
measurements before making a link-level BER claim.

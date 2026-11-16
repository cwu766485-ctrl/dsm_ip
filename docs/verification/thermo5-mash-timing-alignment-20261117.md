# Weighted MASH timing alignment report

2026-11-17 SGT. Product implementation: `1fd679d`; report checkpoint:
`b8dd38d`. This report separates source-sample identity, algorithmic word
history, clock transport, RF bit phase, FIR group delay and OFDM framing.


The dedicated timing contract is
`research/thermo5_integration/model/mash_timing_contract.py:1`.
Receiver correction is in `thermo5_mash_axis_qam.py:134-138`.

| Delay or boundary | Measured/derived treatment |
| --- | --- |
| Source guard | 2,576 source samples; unchanged |
| Source beat 0 -> Pre-DSM token 0 | 108000 -> 249174 ps; transport only |
| Pre-DSM -> Stage 1 token | 2 observed core cycles; no sample crop |
| Stage 1 algorithmic stream delay | 32 words = 1,024 Pre-DSM complex samples = 256 source samples |
| Historical internal alignment | 35 registers; includes clock-boundary alignment, not a 35-word receiver crop |
| Final MASH stream delay | 66 words = 2,112 Pre-DSM samples = 4,224 raw RF samples = 528 source samples |
| Pre-DSM -> final PA token | 8 observed cycles, including core/FIFO/encoder boundaries; do not assume 7 |
| FIR0 group delay | 2,048 raw RF samples, compensated by the existing centered convolution |
| FIR1 group delay | 2,048 samples at 7 GS/s, also compensated |
| Decimation phases | 0, 0 |
| CP / FFT | 512 / 4,096 source-rate samples |
| MASH first FFT sample | 2,576 + 528 + 512 = 3,616 in the decimated output |

The VCD core period is 4,572 ps because of testbench time precision; nominal
hardware cadence is 218.75 MHz. Timing tables use actual VCD timestamps.
The PSD/receiver sequence analysis explicitly assumes the nominal 14-GS/s RF
sample rate. No physical GT serializer clock was simulated.

The 66-word contract is 32 Stage 1 words + 32 aligned Stage 2 words + two
explicit output reset-FIFO words. The corrected q1 companion advances on the
same accepted Stage 2 transactions, preserving this delay through bubbles.
Every capture retains all RF samples. Acceptance moves the CP/FFT window by
the fixed contract; it does not search for an EVM-minimizing crop.

| Same-input isolation | Fixed source offset | EVM RMS | Diagnostic correlation lag |
| --- | ---: | ---: | ---: |
| A: ideal Fs/4, actual frontend IQ, no DSM | 0 | 2.354286% | 0 |
| B: independent scalar Stage 1 | 0 | 12.002773% | 0 |
| C: actual RTL Stage 1 | 256 | 12.002773% | 256 |
| D: original RTL weighted MASH, timing corrected only | 528 | 13.145892% | 528 |
| D: corrected RTL weighted MASH | 528 | 2.551442% | 528 |

The original unaligned D remains **99.994117% EVM**, approximately 0-dB SNDR
and 50% BER. Stage 1 alone is a noisy first-order quantizer; its 12% EVM
matches the independent scalar result and does not imply a bit-true fault.
All A/B/C/D paths use the same DDC, LPFs, decimation, FFT, and QAM decisions.
Normalized correlation-vs-lag CSVs are under the two isolation run directories;
correlation results are diagnostic and never inputs to acceptance offsets.

## Interpretation under stalls and reset

At continuous II=1, source Pre-DSM word0 appears in Stage1 output token32:
404622 ps minus its acceptance249174 ps = 34 core periods (32 algorithmic
words plus2 transport cycles). It enters Stage2 at409194 ps:35 periods after
acceptance. This explains the historical35-entry input delay without turning
it into a35-word receiver crop. Source word0 contributes to MASH output
token66 at587502 ps:74 periods after acceptance (66 algorithmic plus8 transport).

Under bubbles/backpressure, clock times vary while accepted-sample indices
remain ordered. The companion path preserves q1/q2 association. A held or
missing token is not automatically a continuous 14-GS/s physical sample;
there is no real serializer in these tests. Input-fire, Pre-DSM-fire, stage
valid and PA-fire timestamps are recorded; serializer-fire is unavailable.

Reset flushes quantizer state and queued transactions. The separate Stage1
replay clocks32 extra zero words only to observe every original input sample.
Full-chain QAM uses its original leading/trailing guards, unchanged. Its last
algorithmic pipeline samples are guard samples; a general no-guard packet
needs a separately specified tail/drain and frame/config timing contract.

Current Config ID/Frame/Tail metadata is checked as static-SKU transaction
metadata. The RF sample origin of output token n is n-66 after algorithmic
fill; output-token metadata must not be assumed to implement dynamic RF-sample
configuration switching. That integration requirement remains OPEN.

Evidence: `runs/mash_evidence_corrected/{source_events,pre_words,stage1_words,stage_pairs,events}.csv`,
`audit.vcd`, and the isolation `*_correlation_vs_lag.csv` records. The first
bit order, LO phase and both FIR compensation conventions are independently
checked by the receiver smoke. No EVM-optimized offset enters acceptance.

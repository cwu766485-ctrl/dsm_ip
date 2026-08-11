# Digital-IF BPDSM Transmitter Route

This is the single-bit DPA research route:

```text
complex I/Q after DPD and interpolation
-> full-precision real Fs/4 digital IF mixer
-> one-bit BP error-feedback DSM
-> DPA -> analog output BPF
```

`bp_fs4_iq_mixer.sv` performs `[+I,+Q,-I,-Q]` before quantization. Its phase
debug output is transaction-aligned: when `rf_valid` is asserted, `if_phase`
identifies the Fs/4 slot that produced that RF sample. The current
one-bit candidates are `dsm_core_bp_single.sv` and `dsm_core_bp_ef2.sv`; both
use an NTF with zeros at `+/- Fs/4`. The checked P0 comparison selects BP EFDSM
as the initial DPA candidate (`3.5638%` EVM, `28.9617 dB` SNDR), narrowly ahead
of the resonator single-loop (`3.6597%`, `28.7312 dB`).

This route is intentionally separate from the packaged AXI IP while its
algorithm, fixed-point limits, bit-true vectors, and RF metrics are qualified.
The exploratory BP MASH 1-1 combiner needs multilevel `{-3,-1,+1,+3}` output.
Hard limiting it to one bit destroys its cancellation, so it is not compatible
with the current one-bit DPA. It remains a research baseline rather than an
RTL/DPA candidate.

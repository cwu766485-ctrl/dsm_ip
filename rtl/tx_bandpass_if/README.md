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
use an NTF with zeros at `+/- Fs/4`. A narrow ideal-filter P0 audit showed BP
EFDSM2 (`3.5638%` EVM, `28.9617 dB` SNDR) marginally ahead of the resonator
single-loop (`3.6597%`, `28.7312 dB`). A subsequent common behavioral
DPA/RLC-BPF endpoint found the two one-bit candidates effectively tied. BP
EFDSM2 is therefore retained as the frozen, bit-true-verified binary-DPA route
for integration continuity, not as a claimed RF-quality winner.

The frozen Performance SKU integrates this route through `dsm_ip_top` with
`DUC_MODE=3`; `dsm_ip_axi_top` supplies the AXI4-Lite and AXI4-Stream system
boundary. Its RF metrics remain model-level evidence until a declared DPA,
feedback receiver, and board measurement chain are qualified.
The exploratory BP MASH 1-1 combiner needs multilevel `{-3,-1,+1,+3}` output.
Hard limiting it to one bit destroys its cancellation, so it is not compatible
with the current one-bit DPA. It remains a research baseline rather than an
RTL/DPA candidate.

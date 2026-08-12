# Fs/4 Mixer Block

## DUT

`rtl/tx_bandpass_if/bp_fs4_iq_mixer.sv` implements the registered `I, Q, -I,
-Q` IF sequence and its phase label.

## Testbench

`tb/tb_bp_fs4_iq_mixer.sv` checks phase selection, valid-gated phase advance,
reset, idle hold, and the signed-minimum negation corner.
`tb/tb_bp_fs4_iq_mixer_random.sv` adds 257 pseudo-random signed inputs,
valid bubbles, and phase/idle-hold checks. Both tests passed on 2026-08-12.
Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_fs4_mixer_block.ps1
```

## Reference and Vectors

The reusable Python reference is `uvm_verif/refmodel/python/dsm_refmodel/bp_ef2.py`
(`Fs4Mixer`). This directed test creates its eight corner-case vectors inside
the testbench; no generated CSV file is needed. `vectors/README.md` records
that contract.

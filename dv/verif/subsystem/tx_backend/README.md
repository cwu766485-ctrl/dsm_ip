# Thermo5 Four-Plane TID/Fs4 Backend Subsystem

This subsystem is the four-branch digital TX backend: four offset Cartesian
TID branches produce cycle-aligned Fs/4 words. For each accepted
32-complex-sample core word, the branches produce four synchronized 64-bit
code-plane words. Their bitwise combination represents the five normalized
levels {-1, -0.5, 0, +0.5, +1} at the digital PA-code boundary.

```text
32 complex samples/core word
        -> four offset TID32/Fs4 branches
        -> four aligned 64-bit PA-code words
```

The bit-true baseline, `tb/tb_tid32_thermo5_fs4_multipa_tx_bittrue.sv`, checks
128 MATLAB-generated vectors and compares all four plane words in the same
cycle with all sinks ready. The separate
`tb/tb_tid32_thermo5_fs4_multipa_tx_backpressure.sv` adds source bubbles and
per-plane partial-ready windows; it checks that valid/data remain aligned and
stable until the whole quartet is accepted, then compares accepted words to
the same MATLAB oracle. The raw GT-user continuous-TX policy is tested separately as an
adjacent **block**: it prepares the 256-bit bundle/idle words and reports
stream faults before the vendor GTH. A behavioral serializer loopback is a
third, separate **integration** test. None of these tests models a physical PA,
GT analog channel/CDR, serial deskew, or RF output.

Run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\subsystem\tx_backend\run_xsim_tid32_thermo5_fs4_multipa_tx.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\subsystem\tx_backend\run_xsim_tid32_thermo5_fs4_multipa_tx_backpressure.ps1
```

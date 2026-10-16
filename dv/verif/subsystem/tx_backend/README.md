# Thermo5 Four-Plane TID/Fs4 Backend Subsystem

This subsystem isolates the four offset Cartesian TID branches and their
cycle-aligned Fs/4 output words. For each accepted 32-complex-sample input
word, the four branches produce four synchronized 64-bit code-plane words.
Their bitwise combination represents the five normalized levels
`{-1, -0.5, 0, +0.5, +1}` at the digital PA-code boundary.

The directed test is `tb/tb_tid32_thermo5_fs4_multipa_tx_bittrue.sv`. It checks
128 MATLAB-generated vectors and compares all four plane words in the same
cycle. The test does not model a physical PA, GT serial pins, or RF output.

Run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_tid32_thermo5_fs4_multipa_tx.ps1
```

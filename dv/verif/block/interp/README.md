# Interpolation Block

`run_xsim_centered_cubic_sustained.ps1` exercises the optional centered-cubic
x2 FIR with 1,024 uninterrupted input vectors, a permanently-ready sink, and
the required synthetic frame-tail vector. It checks one accepted output vector
on every consecutive core cycle after initial lookahead, exact output count,
zero-input arithmetic, and frame-start/end placement. This test is distinct
from the 2-tap causal interpolation reachability test below.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\block\interp\run_xsim_centered_cubic_sustained.ps1
```

The retained thermo5 block test targets
`rtl/interp/dsm_interp_x2_polyphase_vector.sv` and checks reachable x2
interpolation behavior, valid bubbles, and output backpressure against its
integer expected sequence.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\block\interp\run_xsim_interp2_reachable.ps1
```

This block test covers the selected x2 configuration only. The two-stage
8-to-16-to-32 sample expansion is also exercised as part of the thermo5
subsystem and full-chain tests.

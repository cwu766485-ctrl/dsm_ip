# Thermo5 Integration-Boundary Verification

These tests cross subsystem or implementation boundaries and are deliberately
not counted as additional thermo5 subsystems.

- `serializer_loopback/` uses a fast, vendor-neutral behavioral serializer and
  deserializer to check four 64-bit plane ordering across modeled user/serial
  clocks. This complements, but does not replace, the generated GT test below.
- `gt_parent/` tests AXIS + AXI-Lite + thermo5 + the ZU15EG four-GTH parent
  using the Vivado GT Wizard behavioral model. The TX-pin test captures serial
  bits at the configured 14-Gb/s UI and compares complete four-lane frames
  against the parallel GT user words. Baseline, four seeded stress patterns
  (ramp/zero/signed-extreme/impulse), early-TLAST, and interrupted-frame
  scenarios are available. It is a digital vendor-model simulation, not a
  physical link measurement.
- RX user-clock/data recovery, physical four-lane deskew, CDC-11 closure, real
  I/O timing budgets, analog eye/jitter/BER, and board output remain open.

The raw64 test is a block test. The behavioral serializer loopback and the
generated GT Wizard parent simulation are separate integration tests. The
former is fast and vendor-neutral; the latter exercises the generated GT
Wizard model. The recorded Windows/Vivado 2026.1 GT-parent TXP scenarios use
the configuration current at their run date; rerun the parent at centered
cubic + EF2 (`TIDSM_ORDER=2`, `STEP=5120`) before treating them as end-to-end
evidence for the current main-chain default. Run the GT parent simulation from
a clean output directory with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_thermo5_qsfp_gt14_parent_sim.ps1 `
  -OutDir .\runs\thermo5_gt14_e2e_<unique> -SkipRxCompare
```

The `-SkipRxCompare` option disables only the known-unclosed GT RX loopback
comparison; AXIS traffic, GT startup/reset checks, serial TX-pin capture, and
payload bit comparison remain enabled. Vivado 2026.1 is the default and can be
overridden with `-VivadoBat`. For source-gap and signed-endpoint pressure, use
`-Scenario Stress -Pattern 0..3`; `-Scenario BadFrames` checks early TLAST and
mid-frame source interruption, then reset-and-replay behavior. See
`docs/GT_PARENT_STRESS_AND_ERROR_TESTS.md` for the exact scenario matrix and
PASS evidence.

Run the centered-cubic EF2 behavioral serializer check on Linux with VCS:

```bash
make -C dv/uvm/sim thermo5-ef2-serdes-vcs PYTHON=python3.12 \
  THERMO5_EF2_SERDES_DIR="$PWD/runs/thermo5_ef2_serdes"
```

It checks 56 words and 3,584 serialized bits per PA path against the Python
four-plane oracle. It models the digital user/serial boundary and does not
replace the GT Wizard/TXP test.

Run the fast behavioral serializer model from the repository root with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\integration\serializer_loopback\run_xsim_tid32_thermo5_serdes_loopback.ps1
```

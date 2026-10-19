# Thermo5 Integration-Boundary Verification

These tests cross subsystem or implementation boundaries and are deliberately
not counted as additional thermo5 subsystems.

- `serializer_loopback/` uses a behavioral digital serializer/deserializer
  model to check 4 × 64-bit plane ordering across modeled user/serial clocks.
  It is not a generated GT Wizard or physical serial-link test.
- `gt_parent/` holds the optional QSFP/GT parent test. Actual RX user-clock
  recovery, four-lane RX word comparison, CDC-11 closure, serial deskew, real
  I/O timing budgets, and board output remain separate open signoff items.

The raw64 test is a block test. The serializer loopback below is a separate
integration test because it models data crossing the user/serial boundary and
being reassembled; neither test instantiates physical GT hardware. Run the
behavioral serializer model from the repository root with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\integration\serializer_loopback\run_xsim_tid32_thermo5_serdes_loopback.ps1
```

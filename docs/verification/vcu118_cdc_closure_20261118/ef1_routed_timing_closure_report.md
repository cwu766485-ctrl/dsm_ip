# EF1 routed timing closure

Status **FAIL** on completed candidate; fresh synthesis/route **BLOCKED** pending completion. See `docs/verification/vcu118_convergence_20261118/timing_root_cause_report.md` and `docs/verification/vcu118_timing_live_20261117/ef1_cdc_timing_closure.md` for full metrics, source SHA, commands, constraints, routed DCP and Worst-20 reports.

Previous candidate overall WNS -0.352 ns, TNS -4.915 ns, WHS +0.005 ns and THS 0; core-only WNS +0.097 ns. Fresh synthesis and route: `runs/ef1_fresh_synth_route_20261118_01/`. Current route intermediate timing is not final. Source/control clock relationship, independent reset behavior, exception justification, I/O budget and whole-top/board constraints remain open. A new CDC-repaired architecture was not implemented in this work; the running design uses the prior candidate and must not be called fixed.

# Mailbox Formal disposition

VC Formal V-2023.12-SP2, original configuration RTL: `runs/mailbox_atomic_combined_de_01/properties.txt` reports **7/7 proven**, all non-vacuous, and **4/4 covers** in one run, same model and assumptions. It covers source hold, sample stability/capture, boundary atomic update and ACK ordering. Formal clocks have fixed 16:35 periods; boot reset is released (`rst_n==1`), reset setup check disabled. It is not an independent-reset, arbitrary-clock-phase, physical metastability or board-level proof. No assumption was added compared with the previous harness; only time limits increased. Reproduce with `MAILBOX_FORMAL_ROOT` and `MAILBOX_FORMAL_OUT` set to absolute paths and `vcf -batch -fmode FPV -f research/vcu118_arch/formal_cfg_mailbox_atomic_combined.tcl` in a new directory.

Candidate isolated independent-AXI-reset check: `runs/de_independent_reset_candidate_formal_01/` has 2/2 non-vacuous reset-state assertions proven and 2/2 covers, with independent AXI epoch input and Core reset held released. This does not prove the full mailbox contract under all reset epochs; reset checker is disabled and phase relationship is fixed. Full combined 7-property candidate proof including reset and mode switch is OPEN.

The candidate's seven-property combined fixed-phase/common-reset run is in
`runs/de_epoch_candidate_combined_formal_01/`; no result is claimed until
the full report and vacuity/cover are checked.

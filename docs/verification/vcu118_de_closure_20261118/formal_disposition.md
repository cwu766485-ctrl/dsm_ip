# Mailbox Formal disposition

VC Formal V-2023.12-SP2, original configuration RTL: `runs/mailbox_atomic_combined_de_01/properties.txt` reports **7/7 proven**, all non-vacuous, and **4/4 covers** in one run, same model and assumptions. It covers source hold, sample stability/capture, boundary atomic update and ACK ordering. Formal clocks have fixed 16:35 periods; boot reset is released (`rst_n==1`), reset setup check disabled. It is not an independent-reset, arbitrary-clock-phase, physical metastability or board-level proof. No assumption was added compared with the previous harness; only time limits increased. Reproduce with `MAILBOX_FORMAL_ROOT` and `MAILBOX_FORMAL_OUT` set to absolute paths and `vcf -batch -fmode FPV -f research/vcu118_arch/formal_cfg_mailbox_atomic_combined.tcl` in a new directory.

Candidate isolated independent-AXI-reset check: `runs/de_independent_reset_candidate_formal_01/` has 2/2 non-vacuous reset-state assertions proven and 2/2 covers, with independent AXI epoch input and Core reset held released. This does not prove the full mailbox contract under all reset epochs; reset checker is disabled and phase relationship is fixed. Full combined 7-property candidate proof including reset and mode switch is OPEN.

The first candidate seven-property combined fixed-phase/common-reset run
`runs/de_epoch_candidate_combined_formal_01/` completed: 6/7 proven, sample
stability inconclusive at depth 195, all 7 non-vacuous and 4/4 covers hit.
This candidate separately fails the Core-only-reset replay test and is not
qualified regardless of that formal outcome.


Candidate 2 and candidate 3 Core-only-reset scope each have 4/4 non-vacuous
assertions proven, 2/2 covers (`runs/de_candidate2_formal_02/`,
`runs/de_candidate3_formal_01/`). They cover source/Core reset state, stable B
response under backpressure and abort-status behavior, with fixed 16:35 clock
ratio, boot reset held released and reset setup checks disabled. They do not
prove live active-mode or PA contract safety. Candidate 2 formal attempt 01
is excluded from qualification because its harness was edited while the run
was starting; attempt 02 recorded input hashes before launch. Candidate 3
seven-property combined proof is running in `runs/de_candidate3_combined_formal_01/`;
its outcome does not erase the separate mode-reset witness.

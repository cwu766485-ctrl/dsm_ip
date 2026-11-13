# Thermo5 Coverage Signoff Checkpoint

Date: 2026-11-13. Status: `OPEN; NO_OFFICIAL_EXCLUSION_CHANGE`.

The corrected AXI-Lite full-stream directed test passed, but no fresh
integrated candidate VDB or Raw URG result was generated in this checkpoint.
The full 594-scenario inventory and complete negative regression were not
replayed. No new Raw coverage percentage or official coverage delta is
available.

The previous PR #62 seven-test legal-only snapshot had 14,972 open bins and
zero exclusions; it is not the full 594-scenario baseline. The inherited
12,580 versus 12,577 discrepancy is still unresolved at exact bin-ID level.
No official `.el` exclusion was added or approved. Formal INCONCLUSIVE and
tool-partial results are not treated as PASS or converted into exclusions.

Before signoff, compile the frozen integrated product commit to a fresh VDB,
replay all 594 scenarios plus approved legal additions and the separate full
negative suite, then run Raw, approved-adjusted and what-if URG against that
same source/VDB. Reconcile exact bin IDs and bind all evidence to the same
commit and source hashes. Current new approved waiver/exclusion count is zero.

The required full licensed replay and URG were NOT_RUN in this checkpoint.

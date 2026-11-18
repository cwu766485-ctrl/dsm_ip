# Open items — 2026-11-18

- **FAIL**: EF1 and MASH OOC overall setup timing; CDC first-stage and reset paths need a reviewed real clock/reset contract. Fresh EF1 synthesis and route are not yet complete.
- **BLOCKED**: mailbox independent-reset, arbitrary clock phase, physical bus skew/metastability and system CDC/RDC. No unrestricted exception has been approved.
- **BLOCKED**: MASH candidate selection until complete product bit-true, metadata, reset and backpressure proofs and comparable end-to-end latency are available.
- **BLOCKED**: live GTY signoff: real epoch, overflow/underflow recovery, sustained back-to-back frames, product integration, physical implementation and RF measurements.
- **BLOCKED**: EF2 4/8-lane relational proof (3 assertions inconclusive in each); 32-lane timing and equivalence follow only after proof. Original EF2 product RTL remains unchanged.
- **NOT_RUN**: matched EF1+MASH dual-architecture product PPA, UVM/coverage and GTY signoff. Runtime route was interrupted and has not completed.

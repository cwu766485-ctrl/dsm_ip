# Thermo5 integration reset contract

Confirmed by project owner for the CDC/RDC ECO review (2026-11-12): AXI-Lite,
Source and Core reset ports assert in one common reset epoch, and each releases
synchronously in its own clock domain. Runtime independent single-domain reset
is unsupported. STOP is not a substitute for reset coordination.

The parent must enforce common assertion even when a clock is stopped. Local
release requires a metastability-safe synchronizer (dsm_reset_sync, two stages)
and a stable local clock. All three domains must be held long enough to assert
their reset control state. No ordering of local release edges is assumed.
Software must discard RUN, pending configuration and in-flight data on reset,
then reconfigure/restart. Source/consumer traffic must obey reset qualifiers;
Ready without local reset released does not acknowledge a transaction.

The four-GTH parent in fpga/zu15eg/rtl/thermo5_qsfp_gt14_parent.sv drives all
three local dsm_reset_sync instances from link_ready_q. This is an example
implementation; external IP users must provide the same contract. The product
boundary does not contain a new reset controller or enforce remote reset.
The existing UVM AXIL release is a single simulation register and is not
physical metastability evidence. Arbitrary independent reset SGDC stays intact
for conservative before/after analysis; no global equivalence or waiver is set.

Required properties: no accepted transaction under local reset; valid/occupancy
clears before new output; each consumed unreset slot was written in this epoch;
FIFO pointers and mailbox requests from an old epoch cannot reappear; legal
skew release admits only fresh input and retains ownership. The evidence and
remaining proof limits are recorded in thermo5-cdc-rdc-rootfix.md.

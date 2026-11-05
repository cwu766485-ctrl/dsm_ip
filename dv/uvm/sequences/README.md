# AXI-IP Virtual Sequences

The `axi_ip/dsm_*_virtual_sequences.svh` classes coordinate the AXI4-Lite, TX
AXI4-Stream, and observation sequencers of `dsm_uvm_pkg.sv`. They target the
legacy `dsm_ip_axi_top` regression.

`thermo5/thermo5_source_sequence.svh` is separate: it reads the frozen MATLAB vectors
and issues AXI source items through the thermo5 source agent. It does not
coordinate the legacy AXI-IP agents.

`thermo5/thermo5_sku_virtual_sequence.svh` contains the initial cross-agent
product sequence. `thermo5_sku_axil_packet_vseq` sends one legal source packet,
requests RUN and STOP through the AXI-Lite sequencer, observes accepted output
through the PA monitor, and polls STATUS until drain completes. AXI-Lite,
AXIS, and PA protocol checks remain in their respective agents/monitors. This
is a deterministic smoke sequence; constrained-random system scenarios and
cross coverage are a later phase.

Protocol-local sequences remain under `../agent/`; test classes that choose
and start these virtual sequences remain under `../tests/`. Compile through
the target-specific filelist, which adds only its own scenario directory to
the include path. Agent-local sequences generate one interface's transactions;
system scenarios coordinate interfaces or select a reference-vector stream.

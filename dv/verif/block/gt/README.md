# GT User-Word Boundary

The tests in `tb/` exercise the digital 64-bit user-word boundary and
continuous source behavior. These are behavioral RTL tests only; there is no
physical GT primitive, serial waveform, receiver deskew, or board-level
verification in this block.

This is one focused module-level test, not a separate subsystem layer. It checks
the digital contract immediately before the vendor GT: all four PA-code words
must stay aligned, the source cannot wait for AXI-style ready, idle behavior is
defined, and missing/misaligned words raise sticky diagnostics. It does not
check the physical serial waveform or receiver.

Run it with
`dv/verif/block/gt/run_xsim_thermo5_raw64_continuous_tx.ps1`.

# Thermo5 DUT and UVM ownership

The frozen verification SKU instantiates `tid32_thermo5_axis_frontend_tx` with
`W=16`, `INTERP_TAPS=2`, `DPD_MAX_TAPS=1`, `BYPASS_DPD=0`, generic async FIFO
(`FPGA_USE_XPM_FIFO=0`), and default `ENABLE_LOW_POWER_CTRL=0`. This is a
digital raw-word transmitter, not a physically instantiated serializer, PA,
or RF output. The 14-GS/s figure is the serial sample cadence of each plane
(`64 * 218.75 MHz`); the `Fs/4` bit mapping represents a 3.5-GHz digital IF.

## DUT interface contract

| Clock/domain | Port group | Frozen-SKU meaning |
| --- | --- | --- |
| AXI source, 125 MHz | `s_axis_aclk`, active-low `s_axis_aresetn`; `s_axis_tvalid/tready` | One accepted beat has 14 consecutive complex samples. The source holds data and metadata stable under backpressure. |
| AXI source | `s_axis_i_vec`, `s_axis_q_vec` | Two signed 224-bit vectors: 14 lanes * 16 bits, lane 0 earliest. |
| AXI source | `s_axis_tuser_frame_start`, signed 16-bit `s_axis_tuser_frame_gain` | Frame-start/gain metadata travels with the beat. Legal starts align to a 56-sample superframe. No `TLAST` port exists. |
| AXI source status | `s_axis_fifo_full` | FIFO-full observation; not a substitute for `tready`. |
| Core, 218.75 MHz | `core_clk`, active-low `core_aresetn`, `core_enable`; `core_underflow`, `core_protocol_error` | Core run/reset and sticky CDC/protocol diagnostics. The FIFO must prefill before continuous-frame operation. |
| Core DPD configuration | `dpd_active_taps`, six signed 64-bit packed coefficient buses `c1_re/im`, `c3_re/im`, `c5_re/im` | Top-level programmable interface, but this SKU ties active taps to 1 and unity Q2.14 `c1_re=16384`; all other coefficient fields are zero. The memory-DPD RTL is instantiated, not bypassed. Only the least significant 16-bit tap slice is used with `DPD_MAX_TAPS=1`. |
| Core output | `pa_valid[3:0]`, `pa_data[0:3][63:0]`, `pa_ready[3:0]` | Four aligned thermometer code planes. They advance or stall as one word. Each plane is 64 raw bits per core clock; no GT/serializer or physical PA is in this DUT. |

The exact full-frame UVM gate is 32 accepted AXI beats = 448 complex ingress
samples = 56 core words of eight complex samples. Two x2 interpolators make
32 complex samples per core word; `Fs/4` mapping produces 64 ordered real
raw bits per plane. The four planes represent five possible summed levels,
not four independent QAM channels.

## RTL instance chain

```text
tid32_thermo5_axis_frontend_tx
  dsm_axis14_to_core8_cdc          125-MHz async FIFO + 14:8 gearbox
  tid32_thermo5_frontend_tx        218.75-MHz computation
    dsm_frame_gain_vector          frame-wise Q2.14 gain
    dsm_interp_x2_polyphase_vector 8 -> 16 complex, two-tap preset
    dpd_vector_elastic_buffer      word-atomic timing boundary
    dpd_vector16_memory_poly       16-lane identity-configured memory DPD
      dpd_memory_poly              per-lane recurrence and saturation
    dpd_vector_elastic_buffer      word-atomic timing boundary
    dsm_interp_x2_polyphase_vector 16 -> 32 complex, two-tap preset
    tid32_thermo5_fs4_multipa_tx   four offset branches
      tid32_cartesian_fs4_gt_tx    temporal TID + Fs/4 raw-word mapping
```

The canonical RTL is under `rtl/axis/`, `rtl/frontend/`, `rtl/interp/`,
`rtl/dpd/`, and `rtl/tx_bandpass_if/`; the precise compilation set and order
are in `dv/uvm/sim/thermo5_sku_filelist.f`.

## Reference model and UVM checking

Thermo5 **does have a bit-true reference**, but it is not a live SystemVerilog
algorithm model inside `dv/uvm/refmodel/python/`. MATLAB's
`matlab/tx_bandpass_if/gen_tid32_thermo5_frontend_bittrue_vectors.m`
generates source I/Q/metadata and four expected PA-plane `.mem` files. The
source sequence reads the source vectors; the scoreboard independently reads
the expected source and PA files and compares monitor-observed accepted
transactions. Thus, the sequence is stimulus and the `.mem` outputs are the
oracle; the scoreboard is a comparator. The Python reference models under
`dv/uvm/refmodel/python/` primarily serve the separate AXI-IP regression.
The thermo5 generator treats the frozen identity DPD as an exact pass-through;
it is **not** a reference for non-unity coefficients, 2/4-tap memory DPD, or
PA nonlinear behavior. Those configurations need a separate checked oracle.

The VCS thermo5 UVM target uses the portable generic FIFO. Vendor-XPM FIFO
full-chain XSim evidence is separate; neither target verifies physical GT,
board-level four-way serialization, analog PA, or RF EVM.

## Verification architecture

```text
tests/thermo5         test intent and pass criteria
  sequences/thermo5   MATLAB-vector source scenario
    agent/axis         AXI source item -> sequencer -> driver; independent
                       accepted-beat monitor -> analysis port
    agent/rf           passive four-plane output monitor -> analysis port
  env/thermo5         control BFM, config, coverage, reset-epoch scoreboard
  tb                  clocks, interface, frozen DUT parameters and pins
  sim                 target filelist, VCS/regression and URG entry points
```

An agent-local sequence such as `agent/axis/dsm_axis_sequences.svh` models
one reusable protocol endpoint. A scenario in `sequences/axi_ip/` coordinates
several agents; `sequences/thermo5/` owns a project-specific vector stream.
This is a responsibility distinction, not two copies of the same stimulus.
The active AXI-IP and thermo5 tops remain separate packages and filelists.

This layout follows Accellera UVM 1.2 User's Guide sections 3.8-3.10 (agent,
environment and scenario creation) and 4.7-4.10 (virtual sequences,
scoreboards and coverage). The guide specifies component responsibilities,
not a mandatory filesystem naming convention:
https://www.accellera.org/images/downloads/standards/uvm/uvm_users_guide_1.2.pdf

The test-to-check and coverage boundary is recorded separately in
`docs/verification/thermo5-uvm-coverage.md`.

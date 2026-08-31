# AXI Integration RTL

This directory contains the control-plane integration logic for the reusable
DSM transmitter IP.

## Module Responsibilities

| Module | Responsibility |
|---|---|
| `dsm_ip_axi_top.v` | External AXI-Lite and AXI-Stream interfaces, write-side register state, commit sequencing, datapath integration, counters, and telemetry ownership. |
| `dsm_ip_axi_read_mux.v` | Stateless combinational selection of one packed 32-bit readback word by AXI-Lite word address. |

`dsm_ip_axi_top` remains the integration wrapper. It owns the AXI-Lite read
response register, so `RDATA` is captured when an AR request is accepted and
remains stable while `RVALID` waits for `RREADY`.

## Readback Structure

The wrapper packs readable register values into `axi_read_words`. Word index
`0x00` occupies bits `[31:0]`; word index `n` occupies bits
`[32*n +: 32]`. `dsm_ip_axi_read_mux` returns zero for an address outside the
implemented `0x00` through `0x47` range.

This separation is structural only. It does not change the register map,
read-response timing, AXI-Lite write ordering, fixed-point datapath, or DPD
commit policy.

## Maintenance Boundary

Write-side register updates and the memory-polynomial commit state are kept in
`dsm_ip_axi_top.v` intentionally. They have established same-cycle priority
rules involving reset, stream drain, safety rejection, counters, and W1C
errors. Any future extraction of that logic must be treated as a behavior
change candidate and revalidated with the AXI control, reset, commit, and
full-chain bit-true regressions.

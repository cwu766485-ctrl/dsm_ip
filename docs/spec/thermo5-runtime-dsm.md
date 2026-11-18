# Thermo5 runtime DSM contract

The canonical product entry point is `rtl/tx_bandpass_if/tid32_thermo5_runtime_tx.sv`.
It uses the shared AXIS -> CDC -> frame gain -> Cubic1 -> DPD -> Cubic2
frontend and selects the backend at runtime. Reset selects EF2. The existing
parallel and static AXI-Lite tops retain their default interfaces/behavior;
`ENABLE_RUNTIME_DSM=0` keeps the old register ID and rejects new addresses.

Qualified configuration: 16-bit Cartesian input, 32 Pre-DSM lanes,
Centered-Cubic x2+x2, identity one-tap DPD, EF1 STEP7168, EF2 STEP5120,
MASH accumulator-residue cancellation, XPM or Generic CDC FIFO. Changing
DPD/interpolation parameters requires its own vector/regression qualification.
Each AXIS packet contains a positive multiple of 32 beats (14 complex samples
per beat). Each quantum produces 56 PA words. Bit0 is the earliest serial bit.

| Architecture | Register value | Active mask | Bipolar physical weights |
|---|---:|---:|---|
| EF1 | 0 | 0xf | 1,1,1,1 |
| EF2 (reset default) | 1 | 0xf | 1,1,1,1 |
| MASH 1-1 | 2 | 0x3 | 1,2 |

`active_dsm_arch`, `pa_contract_weighted`, and `pa_channel_mask` are core-domain
sidebands. All active valid/ready bits must handshake together. MASH ignores
ready bits 2/3 and drives inactive transport data to zero. Those zero words
must not enable physical PA channels. The integration must route the selected
physical contract before RUN; equal and weighted outputs cannot share an
unmodified four-equal-plane RF combiner. `pa_frame_start`, `pa_frame_end`,
`pa_tail`, and `pa_config_id` accompany the accepted PA word and hold through
stalls. Config ID counts successful mode commits, including same-mode commits,
and resets to zero with the core reset. It is distinct from DPD coefficient IDs.

## AXI-Lite extension

| Address | Access | Meaning |
|---|---|---|
| 0x0c | RO | Runtime product ID 0x54483502 |
| 0x40 | RW | Select 0/1/2; reads last successfully acknowledged mode |
| 0x44 | RO/W1C | [1:0] acknowledged mode; bit8 BUSY; bit9 DONE; bit10 ERROR |

0x40 requires byte0 WSTRB; zero strobe is a no-op. Values greater than two
return SLVERR. 0x44 bits9/10 clear on a byte1 write-one. Mode writes while
RUN, TX_ACTIVE, DRAINING, DPD CFG_BUSY, or mode BUSY return SLVERR. CONTROL
RUN/COMMIT writes while mode BUSY also return SLVERR. Existing STATUS.CFG_ERROR
is sticky on bus errors and follows the existing W1C rules.

A successful bus response accepts a request; it does not prove the core was
idle. BUSY stays set until a four-phase request/acknowledge round trip completes.
The AXI-domain payload stays stable. Source ingress first freezes and returns
a synchronized lock acknowledgment; only then does the core decide whether
CDC, frontend, backend, and PA work are empty. Queued boot-prefill data causes
ERROR and preserves that data and the old mode. A successful idle decision
updates mode/config and pulses backend reset before DONE is returned. Inactive
backends stay reset. Readback updates only on a successful acknowledgment.

## Software order

1. Quiesce new packets; finish any already-open packet through legal TLAST.
2. Write CONTROL.RUN=0 (0x00). Wait STATUS (0x04) TX_ACTIVE/DRAINING and CFG_BUSY
   clear. Do not wait for drain while withholding the rest of an open packet.
3. Clear 0x44 DONE/ERROR with 0x600. Write 0x40 architecture.
4. Poll 0x44 BUSY=0, DONE=1, ERROR=0; verify both mode readbacks.
5. Configure the board PA routing and receiver for the returned mask/weights.
6. Start the source and write CONTROL.RUN=1 using the existing prefill contract.

`tools/hw/thermo5_runtime_control.py` implements steps2-4 using supplied
board read/write callbacks and returns the physical PA contract. It leaves RUN
cleared so the caller can complete step5 before restarting.

Reset uses a common reset epoch: the integration must assert reset for AXI-Lite,
AXIS and Core together, and synchronize deassertion separately to each local
clock. Assertion aborts every in-flight frame and pending configuration or mode
transaction; software discards any interrupted result and reconfigures before
RUN. Reset restores the documented default configuration and architecture.
The three top-level reset inputs do not themselves enforce common assertion;
the parent must implement and verify that distribution and release contract.
Independent AXI-only/core-only live reset is unsupported. In particular, an
AXI-only reset can otherwise leave a pre-reset Core pending configuration that
applies at the next boundary. A directed local common-reset test covers one
pending DPD update and restart; system-level reset epoch, CDC/RDC, serializer,
and RF-board signoff remain open.
MASH's accepted-stream delay is 66 words = 528 source samples; the receiver
uses that explicit CP/FFT offset, without per-capture alignment search. Wall-clock
latency changes with bubbles/backpressure; a serializer must enforce continuity.

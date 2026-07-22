# ZU15EG AI-Seed Bounded-Search Board Evidence

Date: 2026-07-22 20:17:52 +08:00

## Configuration

- Device: `xczu15eg-ffvb1156`
- Input: deterministic 16-QAM OFDM, 48 used subcarriers, 256-point FFT,
  input backoff `0.58`, seed `1`
- Transfer length: 4096 packed Q1.15 I/Q samples
- Calibration policy: generated waveform policy seed followed by mandatory
  14-record bounded polynomial search
- Initial action: polynomial DPD, package 2

## Result

- Bitstream programming, PS initialization, A53 ELF download, and launch
  completed through XSDB.
- The calibration trace completed with 14 records and no overflow.
- Initial policy cost: `316604`
- Final selected cost: `313959`
- Cost reduction: `2645` (`0.8354%`)
- Final coefficients:
  - `C1=0x01893E35`
  - `C3=0xF72A1DDB`
  - `C5=0xC13D5356`
- Final mode/package: polynomial DPD / package 2
- All four 4096-sample datapath counters matched.
- Stall, sticky error, clipping, DPD saturation: all zero.

This is PS-controlled calibration using deterministic PL monitor proxies. It
does not measure RF EVM, SNDR, or ACLR and does not qualify an external PA or
observation receiver.

Files:

- `counter_readback.txt`: post-run AXI-Lite register snapshot and checks.
- `calibration_trace.csv`: complete JTAG-exported calibration trace.

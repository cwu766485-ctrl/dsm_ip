# DSM IP Packaging

This directory packages the reusable streaming DSM transmitter IP.

Vivado IP top module:

```text
dsm_ip_axi_top
```

Reusable streaming datapath module: `dsm_ip_top`.
Reusable RTL core module: `dsm_ip_core`.

`dsm_ip_axi_top` is the packaged SoC/RFSoC wrapper. It adds an AXI-Lite style
control/status port and AXI-Stream I/Q input around the reusable streaming
datapath.

Interface summary:

- `aclk`, `aresetn`
- `s_axi` AXI-Lite style control/status slave
- `s_axis` AXI-Stream I/Q sample input
- `dsm_valid`, `i_bit`, `q_bit`
- native signed `i_yout`, `q_yout`
- `rf_valid`, `rf_bit`, signed `rf_signed`
- `phase_acc_dbg`

AXI-Lite register summary:

- `0x00 CTRL`: bit0 enable, bit1 soft reset
- `0x04 STATUS`: ready/valid status
- `0x08 CFG_PHASE_INC`
- `0x0C ALGORITHM`
- `0x10 DUC_MODE`
- `0x14 VERSION`

AXI-Stream packing:

```text
s_axis_tdata[15:0]  = signed Q1.15 I
s_axis_tdata[31:16] = signed Q1.15 Q
```

Clock and frequency contract:

- The IP clock is the DSM sample clock.
- The default release target is `clk = 100 MHz`.
- `DUC_MODE=0` keeps the fixed Fs/4 DUC, so 100 MHz gives a 25 MHz IF.
- `DUC_MODE=1` enables NCO upconversion.
- NCO tuning word: `cfg_phase_inc = round(f_if / f_clk * 2^PHASE_W)`.
- Example for 25 MHz at 100 MHz with `PHASE_W=24`: `cfg_phase_inc = 24'h400000`.

Bandwidth contract:

- `CLK_FREQ_HZ`, `BB_SAMPLE_RATE_HZ`, and `SIGNAL_BW_HZ` are integration
  metadata parameters.
- The actual occupied bandwidth is determined by the input Q1.15 I/Q stream.
  This IP does not yet include a programmable interpolation/filter chain.

Package with Vivado:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1
```

Generated IP-XACT output:

```text
ip/ip_repo/dsm_ip_1_0/component.xml
```

# Low-Power DPA Baseline

## Purpose

This ADS schematic is the first electrical model for the digital transmitter
endpoint. It accepts the project one-bit, 100 MHz Fs/4 stream and reconstructs
a 25 MHz band-limited output. Its purpose is to characterize a low-power
switching DPA and produce an observation waveform for DPD model fitting.

## Required Topology

Build a differential H-bridge, not a single-ended switch connected directly
to a DC load.

```text
PWL_HI / PWL_LO -> non-overlap generator -> H-bridge switch controls
1.2 V supply   -> two bridge legs          -> differential output
differential output -> 25 MHz BPF -> 100 ohm differential smoke load
                                     -> 2:1 impedance transform -> 50 ohm load
```

For an initial ideal-switch schematic, use voltage-controlled switches with
the following starting values. These are tunable electrical assumptions, not
process parameters.

| Parameter | Start value | Reason |
|---|---:|---|
| `VDD` | 1.2 V | Low-voltage switching baseline |
| `R_ON` per switch | 0.5 ohm | Represents finite conduction loss |
| `C_OUT` per switch | 2 pF | Represents switching charge/loss trend |
| `V_TH_LO` / `V_TH_HI` | 0.5 V / 0.7 V | Switch hysteresis: low gate OFF, high gate ON |
| Non-overlap | 1 ns | Prevents H-bridge shoot-through at 100 MHz |
| BPF center | 25 MHz | Matches Fs/4 DUC at 100 MHz |
| BPF bandwidth | 5 MHz | Passes the current narrowband OFDM channel and suppresses images |
| Differential load | 100 ohm | Current pre-balun simulation reference; final transform ratio is TBD |
| Simulation step | <= 5 ps | Resolves 100 ps switch edges without numerical energy injection |
| Long validation window | 40.96 us | 4096 DSM bits after the short-window electrical smoke passes |

Drive the A and B bridge legs with opposite logic. Each high-side/low-side
pair must go through a non-overlap block. The PWL files are complementary
logic references, not final gate waveforms.

## Low-Power Checks

Record the following for every parameter sweep:

1. `P_DC = mean(VDD * I_VDD)`.
2. `P_OUT` in the current 100 ohm differential smoke load after the BPF.
3. A trend-level efficiency estimate `P_OUT / P_DC`.
4. Maximum supply current and switch-node voltage overshoot.
5. Evidence that no high-side/low-side overlap occurs in either bridge leg.
6. Output spectrum around 25 MHz and the reconstructed output waveform.

The initial acceptance targets are: no shoot-through, no persistent DC at the
differential output, no numerical convergence warning, and a positive
band-pass output around 25 MHz. Efficiency is used to compare operating
points, not as a silicon claim, until a transistor PDK and passive network are
substituted.

A full-scale 1.2 V differential 25 MHz square-wave smoke input is deliberately
not a 0 dBm stimulus: its fundamental can be around 10 dBm into an equivalent
100 ohm differential load. Do not dissipate this power in a large series
resistor to call the design low power. First use it only to validate switching
and filtering. The actual modulated PWL waveform, supply, matching network,
and output-power requirement determine the later low-power operating point.

## ADS Python Automation

The baseline cell can be created with the ADS 2025 Design Environment Python
API. The generator creates a new cell and never overwrites a hand-edited ADS
cell:

```powershell
$env:HPEESOF_DIR = 'D:\ADS2025'
$env:PATH = "D:\ADS2025\bin;D:\ADS2025\tools\python;$env:PATH"
& 'D:\ADS2025\tools\python\python.exe' .\ads\scripts\generate_low_power_dpa.py
```

The pulse-driven smoke cell is `workspace_lib:low_power_dpa_api_v10:schematic`.
The accepted long-window PWL electrical baseline is
`workspace_lib:low_power_dpa_api_v17:schematic`. It contains `VDD_SRC`, four
MATLAB-derived non-overlapping `VtPWL` controls, four voltage-controlled
switches, explicit upper/lower body-diode clamps, a series LC reconstruction
branch, a 100 ohm differential load, and a transient controller. The earlier
API cells are retained only as ADS automation debug records and are not
electrical signoff evidence.

ADS `V_DC` and `VtPulse` define their voltage from terminal 1 to terminal 2.
Because terminal 1 is grounded in this schematic, the source parameters use
`-VDD` so that the named supply and active gate-control nodes are positive.
The design variable remains `VDD = 1.2 V`.

Run the generated transient baseline without relying on GUI state:

```powershell
$env:HPEESOF_DIR = 'D:\ADS2025'
$env:PATH = "D:\ADS2025\bin;D:\ADS2025\tools\python;$env:PATH"
& 'D:\ADS2025\tools\python\python.exe' .\ads\scripts\run_low_power_dpa_tran.py
& 'D:\ADS2025\tools\python\python.exe' .\ads\scripts\analyze_low_power_dpa_tran.py
```

Run the real MATLAB `rf_bit` PWL baseline:

```powershell
cd E:\workspace\chip\dsm_ip
$env:HPEESOF_DIR = 'D:\ADS2025'
$env:PATH = "D:\ADS2025\bin;D:\ADS2025\tools\python;$env:PATH"
& 'D:\ADS2025\tools\python\python.exe' .\ads\scripts\generate_low_power_dpa.py --cell low_power_dpa_api_v17 --drive pwl
& 'D:\ADS2025\tools\python\python.exe' .\ads\scripts\run_low_power_dpa_tran.py --cell low_power_dpa_api_v17 --run-dir .\ads\low_power_dpa\simulation\low_power_dpa_api_v17_4096bit_pwl_tran
& 'D:\ADS2025\tools\python\python.exe' .\ads\scripts\analyze_low_power_dpa_tran.py --cell low_power_dpa_api_v17 --run-dir .\ads\low_power_dpa\simulation\low_power_dpa_api_v17_4096bit_pwl_tran
& 'D:\ADS2025\tools\python\python.exe' .\ads\scripts\analyze_low_power_dpa_spectrum.py --cell low_power_dpa_api_v17 --run-dir .\ads\low_power_dpa\simulation\low_power_dpa_api_v17_4096bit_pwl_tran --settling-s 4e-6
```

The run writes only ignored outputs under `simulation/`. A zero process return
code proves that the ADS transient solver accepted the current electrical
baseline. The analysis checks supply polarity, gate activity, bounded
differential bridge/load voltage, and a non-static filtered output. It exports
`ads_observation.csv` with the documented MATLAB feedback columns. The reported
power and efficiency are ideal-circuit trends, not PAE or a PDK implementation.
The checked v17 4096-bit PWL run produced a 2.631 Vpp load differential
waveform, 1.618 mW time-integrated load power, 1.937 mW time-integrated DC
power, and an 83.5% ideal-circuit efficiency trend. Its 3.43 A instantaneous
supply-current spike is a consequence of ideal switches/diodes and 100 ps
edges; it is not a physical current prediction. The separate spectrum report
measures filter-quality proxies only; the adjacent-band numbers are not ACLR.

## Stimulus Contract

Generate stimulus from MATLAB:

```matlab
cd('E:/workspace/chip/dsm_ip/matlab');
path_setup;
S = export_ads_low_power_dpa_stimulus('n_symbols', 8, 'n_samples', 256, 'seed', 211);
```

The command writes the following generated files to `data/`:

| File | Format | ADS use |
|---|---|---|
| `rf_bit_samples.csv` | sample index, time, bit, signed symbol, complementary drive voltages | Traceability and debug |
| `dpa_drive_hi_pwl.txt` | time in seconds, voltage | PWL source for the high logic reference |
| `dpa_drive_lo_pwl.txt` | time in seconds, voltage | PWL source for the low logic reference |
| `stimulus_manifest.csv` | scalar configuration values | Run record |

For manual ADS entry, use the `*_pwl.txt` files directly in PWL sources.
The automated v16 generator instead reads `rf_bit_samples.csv`, then derives
four gate PWL expressions so that `rf_bit=1` enables the A-high/B-low diagonal
and `rf_bit=0` enables A-low/B-high after the required dead time. The sample
period is 10 ns. Each transition contains a short hold point so a PWL source
does not interpolate across an entire sample.

The default `n_samples=256` is a 2.56 us ADS convergence smoke window. The
accepted long PWL baseline uses 4096 samples (40.96 us) after the switch
transient and BPF response are stable.

## Result Contract

Export an ADS CSV named `ads_observation.csv` with these header fields:

```text
time_s,vout_v,ivdd_a
```

`vout_v` is the BPF output measured across the current 100 ohm differential
bridge load. `ivdd_a` is the positive current drawn from the 1.2 V source.
Keep the waveform time base and the stimulus manifest with every export. The
first MATLAB importer uses the same 100 ohm differential reference. Change the
reference only after the balun/matching network and the final 50 ohm
single-ended measurement plane are explicitly modeled. The automation exports
this observation at a uniform 1 GHz rate; the native 5 ps transient dataset
remains under `simulation/` for electrical debug. Supply-current values in the
compact export are interval averages, not point samples, so DC power remains
consistent with an adaptive-step transient solver.

Analyze a compliant export with:

```matlab
R = analyze_ads_low_power_dpa_result;
```

The result records DC power, 100 ohm differential output power, trend-level efficiency,
peak voltage/current, DC offset, and FFT-bin power nearest 25 MHz. It does not
report EVM/ACLR or a physical PAE claim.

## PDK-MOS Switch-Core Evidence

A separate local-only PDK switch-core netlist is now available. It leaves the
editable ideal-switch ADS cell intact and builds a four-transistor H-bridge
from local RF-MOS HSPICE subcircuits. Its source files are
`ads/scripts/run_tsmc40_dpa_switch_core.py` and
`ads/scripts/analyze_tsmc40_dpa_switch_core.py`.

The initial topology is:

```text
ideal gate sources -> PDK PMOS/NMOS H-bridge -> 25 MHz series LC
                   -> ideal sqrt(2):1 turns transformer -> 50 ohm load
```

The transformer represents the required 2:1 impedance conversion from the
100 ohm differential bridge plane to the 50 ohm single-ended output. It is not
an extracted balun. The local model was screened at TT/SS/FF, 0/25/85 C, and
1.14/1.20/1.26 V using ADS-native temperature control. The 16-finger
configuration had no high-side/low-side overlap in 27/27 cases. Its current
pre-layout output range was -3.14 to +0.05 dBm, with a 18.56 to 24.35 percent
efficiency trend.

At TT/25 C/1.2 V, the RF-MOS finger screen was:

| Fingers | 50 ohm output | DC power | Efficiency trend |
|---:|---:|---:|---:|
| 4 | -11.09 dBm | 1.13 mW | 6.88% |
| 8 | -5.91 dBm | 2.02 mW | 12.73% |
| 16 | -1.02 dBm | 3.47 mW | 22.76% |
| 32 | +2.93 dBm | 5.43 mW | 36.17% |

`16` fingers is the current low-power sizing candidate for matching-network
optimization. It does not yet meet a guaranteed 0 dBm all-PVT output target.
Do not select `32` merely from this table: gate-driver loss, output-network
loss, layout parasitics, and thermal margins have not yet been included.

The runner also supports `--gate-driver pdk`, which inserts two local PDK CMOS
inverter stages per bridge gate, and `--switch-node-cap` for a declared
unextracted node-capacitance estimate. A checked TT/25 C/1.2 V, 16-finger case
with a 4-finger driver and 100 fF per switch node produced -1.02 dBm output,
3.48 mW DC power, a 22.73% efficiency trend, and zero overlap samples. This
demonstrates driver compatibility with the switch core; it is not a driver
optimization or parasitic-extraction result.

The same switch-core runner accepts the MATLAB `rf_bit_samples.csv` file using
`--pwl-file` and constructs four non-overlapping HSPICE PWL gate waveforms.
The checked 256-bit LPDSM2 run with the PDK driver and 100 fF declared
switch-node capacitance passed with zero overlap. It produced -3.80 dBm at the
50 ohm plane, consumed 1.433 mW DC, and had a 29.06% efficiency trend. Its
uniform observation CSV was accepted by
`analyze_ads_low_power_dpa_result` with `load_ohm=50`.

## Boundary

This baseline is not a taped-out RF design. The separate switch-core runner
uses local PDK MOS models, but neither it nor the editable baseline has a PDK
gate driver, layout/EM extraction, bond-wire/package model, balun loss, final
filter, or hardware measurement. Its value is a controlled, reproducible
electrical endpoint for the existing all-digital transmitter and DPD flow.

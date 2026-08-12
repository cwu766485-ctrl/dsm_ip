# DPA Simulation Endpoint

This directory contains an optional DPA simulation endpoint for the DPD
research flow. The DPA provides a plausible nonlinear, memory-bearing,
band-limited endpoint and feedback waveform. It is not a fabrication,
transistor signoff, RF measurement, PAE, or product-output power project.
The primary deliverable is DPD improvement in repeatable simulation.

The required path is the MATLAB behavioral DPA in
`matlab/dpd/run_lpdsmdpa_bpf_dpd_closed_loop.m`. ADS and local PDK-MOS
experiments are optional sanity checks and must not block DPD development.

The checked ADS PWL records in this directory were generated from the earlier
LPDSM2/Fs4 path and are retained as historical circuit experiments. The current
digital validation SKU uses full-precision Fs/4 IF followed by one-bit BP
EFDSM2. A new ADS result must regenerate its PWL stimulus from that BP output
before it can be compared with the current DPD/DSM chain.

The preferred circuit-level system experiment is a generic switched-DPA model:
finite `R_ON`, switch-node capacitance, explicit dead time, 25 MHz LC
reconstruction, and a declared load/supply. It needs no process PDK and may
use a declared 3.3 V supply. Its output is still an ADS analog transient
`vout(t)` with supply current `ivdd(t)`, but its efficiency is a generic
circuit trend rather than a silicon claim. The local 40 nm PDK flow is only an
optional process-specific appendix.

## Baseline

The first historical implementation is a differential switched H-bridge DPA
driven by the 100 MHz one-bit `rf_bit` stream from the LPDSM2, x32, Fs/4
transmitter configuration. It is not the current BP EFDSM2 release endpoint.

- Supply: 1.2 V
- Digital sample rate: 100 MHz
- Nominal output center: 25 MHz
- Nominal output load: 50 ohm single-ended through an ideal 2:1 impedance
  transformation, or 100 ohm differential at the bridge-side reference plane
- Output reconstruction filter: 25 MHz band-pass filter, 5 MHz nominal
  3 dB bandwidth
- Initial power target: characterize the modulated waveform before freezing an
  absolute output-power target
- Switching requirement: non-overlap must be present on both H-bridge legs;
  start with 1 ns and sweep 0.5 ns to 2 ns

The design objective is low static bias and controlled switching loss. A 1.2 V
full-scale differential square-wave smoke stimulus can produce substantially
more than 0 dBm into an equivalent 100 ohm differential load; do not add a
large series resistor merely to force a nominal low output power. Use
finite switch on-resistance and output capacitance in circuit simulation, and
record supply current, output power, peak current, and switch overlap. Do not
claim PAE, silicon power, or device reliability until a PDK device model,
layout parasitics, and a physical output network are available.

## Files

| Path | Purpose |
|---|---|
| `low_power_dpa/README.md` | ADS schematic topology, parameter values, and result contract |
| `scripts/generate_low_power_dpa.py` | ADS 2025 Python API generator for the editable baseline schematic |
| `scripts/run_low_power_dpa_tran.py` | Generates the ADS netlist and runs the transient smoke simulation |
| `scripts/analyze_low_power_dpa_tran.py` | Checks the ADS dataset and exports the MATLAB observation CSV |
| `scripts/analyze_low_power_dpa_spectrum.py` | Extracts time-integrated power and windowed spectrum trend proxies |
| `scripts/run_tsmc40_hspice_probe.py` | Local-only HSPICE-to-ADS RF-MOS compatibility probe |
| `scripts/run_tsmc40_dpa_switch_core.py` | Local PDK-MOS H-bridge, BPF, and 50 ohm transient runner |
| `scripts/analyze_tsmc40_dpa_switch_core.py` | Checks switch overlap and reports 50 ohm power/DC trend metrics |
| `scripts/run_tsmc40_dpa_pvt_matrix.py` | 27-case process, supply, and temperature screen |
| `scripts/run_tsmc40_dpa_size_sweep.py` | TT RF-MOS finger-count screen |
| `scripts/run_tsmc40_dpa_driver_deadtime_sweep.py` | PDK-driver non-overlap sweep over representative PVT extremes |
| `scripts/run_tsmc40_dpa_25mhz_screen.py` | 25 MHz L/C, RF-MOS, and gate-driver sizing screen before PVT closure |
| `scripts/analyze_tsmc40_dpa_spectrum.py` | 50-ohm circuit-endpoint spectral trend proxy extractor |
| `scripts/compare_tsmc40_dpa_candidates.py` | Same-endpoint no-DPD versus candidate electrical delta report |
| `scripts/extract_ads_complex_feedback.py` | Coherent IF downconversion, alignment, and forward memory-polynomial identification |
| `scripts/run_generic_dpa_efficiency_screen.py` | PDK-independent ADS 3.3 V generic switched-DPA screen; requires an ADS transient license |
| `scripts/run_generic_dpa_loss_model.py` | PDK-independent finite-loss time-domain DPA screen and 1 GHz `vout/ivdd` observation export |
| `low_power_dpa/DPA_REQUIREMENTS.md` | Frozen circuit baseline, measurement plane, and pre-PDK requirements |
| `low_power_dpa/data/` | Generated PWL stimulus and ADS waveform exports; ignored by Git |
| `../matlab/dpd/export_ads_low_power_dpa_stimulus.m` | Generates the 100 MHz one-bit PWL input from the project DSP model |

## Flow

1. In MATLAB, run `path_setup; export_ads_low_power_dpa_stimulus`.
2. Generate the ADS PWL cell. The generator reads the MATLAB `rf_bit` samples
   and expands them into four `VtPWL` gate controls with explicit non-overlap.
3. Run transient simulation and export the filter output and supply current
   using the column names described in the result contract.
4. Extract power and spectral trend proxies, then feed the observation export
   into MATLAB only after the circuit result has passed the baseline electrical
   checks.

The spectrum report is intentionally not an ACLR result. It is a repeatable
filter and switching-quality trend measurement at the current 100 ohm
differential pre-balun plane. The acceptance definitions and its physical
limitations are in `low_power_dpa/DPA_REQUIREMENTS.md`.

## Optional Local PDK Appendix

`scripts/run_tsmc40_hspice_probe.py` is a local-only compatibility check for
an extracted TSMC40 HSPICE model deck. It creates an ignored DC probe netlist;
it neither copies PDK content nor stores an absolute PDK path in the project.

```powershell
$env:HPEESOF_DIR = 'D:\ADS2025'
$env:TSMC40_PDK_ROOT = 'F:\path\to\local\pdk'
& 'D:\ADS2025\tools\python\python.exe' .\ads\scripts\run_tsmc40_hspice_probe.py
```

A successful probe proves only that the local ADS installation can parse the
selected HSPICE sections and MOS subcircuit. The separate switch-core flow has
now run a four-transistor H-bridge transient against that local model. It is
still a pre-layout circuit experiment, not transistor-level signoff.

The following PDK sections are retained as historical circuit evidence only.
They are not required for the DPD simulation milestone. A missing PDK,
transient license, balun model, or package model must not block DPD work.

## Optional Local PDK-MOS Switch-Core Flow

The local PDK path is provided at runtime and never copied into this project.
The bridge uses PDK PMOS/NMOS subcircuits, 1 ns explicit non-overlap, a
25 MHz series-resonant branch, and an ideal coupled transformer that presents
100 ohm differential at the bridge plane and 50 ohm single-ended at the output.
The initial PDK iteration used ideal gate sources and an ideal transformer.
The current runner can also insert two PDK CMOS inverter stages per gate and
an explicitly estimated passive-loss proxy. The proxy is not a balun, package,
PCB, EM, or extracted matching-network model.

```powershell
$env:HPEESOF_DIR = 'D:\ADS2025'
$env:TSMC40_PDK_ROOT = 'F:\path\to\local\pdk'
$env:PATH = "D:\ADS2025\bin;D:\ADS2025\tools\python;$env:PATH"

& 'D:\ADS2025\tools\python\python.exe' .\ads\scripts\run_tsmc40_hspice_probe.py
& 'D:\ADS2025\tools\python\python.exe' .\ads\scripts\run_tsmc40_dpa_switch_core.py --nmos-w 1u --pmos-w 1u --fingers 16
& 'D:\ADS2025\tools\python\python.exe' .\ads\scripts\analyze_tsmc40_dpa_switch_core.py
& 'D:\ADS2025\tools\python\python.exe' .\ads\scripts\run_tsmc40_dpa_pvt_matrix.py
& 'D:\ADS2025\tools\python\python.exe' .\ads\scripts\run_tsmc40_dpa_size_sweep.py
```

The checked 16-finger PVT screen passed 27/27 transient cases without a leg
overlap. Across TT/SS/FF, 0/25/85 C, and 1.14/1.20/1.26 V, the current
pre-layout 50 ohm output was -3.14 to +0.05 dBm and the efficiency trend was
18.56 to 24.35 percent. These are useful sizing bounds, not a proof of the
final 0 dBm product target across PVT.

For a first non-ideal-drive check, add `--gate-driver pdk --driver-fingers 4
--switch-node-cap 100f` to the switch-core command. This inserts two PDK CMOS
inverter stages per gate and a user-declared external switch-node capacitance.
At TT/25 C/1.2 V with 16 RF-MOS fingers, that checked case passed without leg
overlap and measured -1.02 dBm / 3.48 mW / 22.73% at the same 50 ohm plane.
The PDK driver is functional evidence only; it is not yet a sized or extracted
gate-driver implementation.

## Driver, PVT, and DPD PWL Comparison

The selected pre-layout configuration is 16 RF-MOS fingers, two PDK CMOS
inverter stages with four fingers per gate, 100 fF declared switch-node
capacitance, 1 ns dead time, and the estimated passive-loss proxy. That proxy
uses `k=0.990`, 0.20 ohm BPF series loss, 0.50 ohm primary loss, and 0.25 ohm
secondary loss. These values are sensitivity assumptions, not extracted or
vendor balun data.

The dead-time sweep over TT/25 C/1.20 V, SS/85 C/1.14 V, and FF/0 C/1.26 V
passed all 12 cases with zero overlap. One nanosecond is retained as the
nominal point: 0.5 ns gives no demonstrated output benefit, while 2 ns begins
to reduce output and raises the fast-corner peak-current trend. A complete
27-point screen for the selected configuration passed with zero overlap. Its
50-ohm output range is -3.21 to -0.07 dBm, DC power is 2.66 to 4.10 mW, and
the pre-layout efficiency trend is 17.97% to 24.00%. The 0 dBm target is not
met over PVT by this 16-finger configuration.

The original series network includes both `L_BPF=3.18 uH` and the `1 uH`
transformer primary in its series path. With `C_BPF=12.7 pF`, its simple
LC estimate is approximately 21.84 MHz rather than 25 MHz. The runner now
exposes `--l-bpf`, `--c-bpf`, `--l-pri`, `--l-sec`, and `--output-load-ohm`;
the historical defaults remain available for prior result reproduction. New
work must select `C_BPF` together with total series inductance and then repeat
PVT. The first centered estimate for 4.18 uH total inductance is 9.70 pF.

Run the nominal 25 MHz screen before choosing a new DPA candidate:

```powershell
& 'D:\ADS2025\tools\python\python.exe' .\ads\scripts\run_tsmc40_dpa_25mhz_screen.py
```

It compares `C_BPF`, RF-MOS fingers, and PDK-driver fingers at TT/25 C/1.2 V
with the same estimated passive-loss proxy. It ranks only zero-overlap cases
using 0 dBm target error, DC-to-load efficiency trend, and peak supply current.
Its winner must still pass the 27-point PVT matrix. The screen does not replace
a physical balun/matching network, package model, EM extraction, PAE test, or
reliability signoff.

Use the local-only commands below to reproduce the selected configuration:

```powershell
& 'D:\ADS2025\tools\python\python.exe' .\ads\scripts\run_tsmc40_dpa_driver_deadtime_sweep.py --fingers 16 --driver-fingers 4 --switch-node-cap 100f --passive-model estimated
& 'D:\ADS2025\tools\python\python.exe' .\ads\scripts\run_tsmc40_dpa_pvt_matrix.py --fingers 16 --gate-driver pdk --driver-fingers 4 --switch-node-cap 100f --dead-time 1n --passive-model estimated
```

`matlab/dpd/export_ads_dpd_candidate_pair.m` emits no-DPD and a
quality-gated Q1.15/Q2.14 Memory-Poly candidate PWL pair. The 256-bit paired
ADS run changed 126 output bits and held zero overlap in both cases. At the
same 50-ohm proxy endpoint, the candidate changed output power from -3.85 to
-4.39 dBm, DC power from 1.48 to 1.27 mW, and efficiency trend from 27.88% to
28.71%. The paired spectral report is only a 2.359 us, 423.9 kHz-resolution
trend proxy, not ACLR. This is evidence that behavioral-PA coefficients must
be reidentified from the ADS observation path before circuit-endpoint DPD
improvement can be claimed.

The runner accepts the existing MATLAB stimulus directly through
`--pwl-file .\ads\low_power_dpa\data\rf_bit_samples.csv --pwl-samples 256`.
A checked 256-bit LPDSM2 PWL run using the PDK driver, 16 RF-MOS fingers, and
100 fF switch-node capacitance passed with zero overlap. Its 50 ohm output was
-3.80 dBm, DC power was 1.433 mW, and the efficiency trend was 29.06 percent.
The analyzer exported 2,560 uniform 1 GHz observation samples; the existing
MATLAB importer consumed that CSV at the 50 ohm measurement plane successfully.

The current ADS model is an optional circuit-level sanity check. It is not
required to complete the behavioral DPD study and does not constitute a
measured or foundry-qualified transmitter.

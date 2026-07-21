## VNC IC Flow Resources

This VNC server provides a largely complete digital IC implementation flow.

| Stage | Tool | Server location / startup |
| --- | --- | --- |
| Synthesis | Design Compiler S-2021.06-SP3 | `module load syn`, then `dc_shell`; `/eda/synopsys_2021/syn/S-2021.06-SP3` |
| Static timing | PrimeTime | `module load pt`; `/eda/synopsys_2021/pt/S-2021.06-SP3` |
| Place and route | ICC / ICC2 | `module load icc` or `module load icc2`; ICC2 2022.12 is also available |
| Place and route | Innovus 21.10 | `module load innovus`; `/eda/cadence_2021/INNOVUS211` |
| Physical verification | Calibre 2021.4 | `module load calibre`; `/eda/mentor_2021/calibre2021.4_17.8` |
| Parasitic extraction | Quantus 21.1 | `module load quantus` |
| Simulation and debug | VCS / Verdi | Recommended: `module load vcs_2023 verdi_2023`; V-2023.12-SP2 |
| DFT | Tessent 2021.1 | `module load tessent` |
| Custom / analog | Virtuoso / Spectre / Assura | Cadence IC618/ICADVM201, Spectre 21.1, Assura 4.1 |

## Digital Process Libraries

### TSMC 28nm HPC+

- Root: `/qixin/public/pd_libs/tsmc28nmhpcplus`
- Standard cells: HVT, RVT, LVT, and clock-gating libraries.
- Views: `.lib`, `.db`, `.lef`, and `.gds` are available for synthesis, STA, P&R, and signoff.
- SRAM macros: `/qixin/public/pd_libs/tsmc28nmhpcplus/28nm_memory`
- Macro views include `.lib`, `.lef`, `.gds`, and Verilog models. Some macros also include MBIST and ATPG views.
- This is the preferred library for SRAMC, DMA, NPU, and compute-in-memory projects.

### TSMC 180nm Education Library

- Root: `/qixin/public/edu/libs/180nm`
- Standard cells: `stdcell/aci/sc`, with DC `.db`/`.lib` and P&R `.lef` views.
- SRAM macros: `memory/`, including 32x32, 128x32, 256x32, 512x32, and 8Kx8 macros.
- Macro views include `.lib`, `.db`, `.lef`, and Verilog models.
- Suitable for teaching-oriented full-flow projects.

### SMIC 180nm

- Root: `/qixin/public/layout_libs/smic180`
- Resources include PDK data, logic/analog layout libraries, and Calibre rules.
- Better suited to custom-layout and analog coursework.
- A complete SRAM hard-macro digital view set was not confirmed; use TSMC28 or TSMC180 for SRAM-based digital projects.

## Typical Digital Flow

```bash
module load syn pt icc2 calibre
dc_shell
pt_shell
icc2_shell
```

Use DC to synthesize RTL and generate a gate-level netlist. Use PrimeTime for STA, ICC2 or Innovus for floorplanning, placement, CTS, routing, and physical optimization, then use Calibre for DRC/LVS signoff.

## SRAM-Based Designs

Do not synthesize an SRAM macro's internal bitcell array. In the RTL, instantiate a wrapper around the selected SRAM macro:

- Simulate with the macro Verilog model.
- Add SRAM `.db` or `.lib` to the DC `link_library`; synthesize only the controller, DMA, compute array, address generation, and interconnect logic.
- Read the SRAM `.lef` during P&R and place it as a hard macro.
- Use matching PVT timing models for STA.
- Include the SRAM `.gds` during final GDS integration.

A Verilog array can synthesize into flip-flops and is acceptable only for small register files or buffers. It is not a practical replacement for an SRAM macro in a large SRAM or compute-in-memory accelerator.

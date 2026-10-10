# Thermo5 GT TX-active CDC-11 path audit

Date: 2026-10-06 (Asia/Singapore). Scope: the two CDC-11 rows in the routed
thermo5 parent report. This is a structural path audit, not a CDC waiver or
signoff.

## Routed evidence

Source report: `runs/thermo5_parent_cleanroute_20261005_2117/cdc.rpt`, generated
by Vivado 2024.1 from `routed.dcp` on `xczu15eg-ffvb1156-2-i`. Both findings
are under the `core_clk218` to `freerun_clk200` clock-pair section and are
classified `No Common Primary Clock` with `Asynch Clock Groups` in the
Exception column:

| CDC row | Depth | Launch pin | First destination pin |
| --- | ---: | --- | --- |
| 2 | 2 | `.../gtwiz_userclk_tx_active_sync_reg/C` | `tx_active_meta_reg/D` |
| 3 | 5 | same launch pin | `.../bit_synchronizer_gtwiz_reset_userclk_tx_active_inst/i_in_meta_reg/D` |

Vivado's exact rule summary is `CDC-11 Critical: Fan-out from launch flop to
destination clock`. The audit script reopens the existing routed checkpoint
read-only, reports the relevant cells, `ASYNC_REG`, clock pins, fanout
endpoints, and reruns `report_cdc -details` without changing constraints:
`syn/audit_thermo5_gt_cdc11_paths.tcl`. The completed read-only Vivado query
confirmed the mapped clock pins and fanout described below; its generated
stdout was inspected and not retained as a new run artifact.

## Path structures and uses

| Path | Source structure | Destination structure and use | Finding |
| --- | --- | --- | --- |
| Parent health/status | Generated `gtwiz_userclk_tx_active_meta` then `gtwiz_userclk_tx_active_sync`, both `ASYNC_REG=TRUE`, clocked on `gtwiz_userclk_tx_usrclk2_out` (`core_clk218`). The output is the generated `tx_active` port. | Parent `tx_active_meta` then `tx_active_sync`, both marked `ASYNC_REG=TRUE`, clocked by `freerun_clk200`. `tx_active_sync` gates link qualification and therefore the local resets for the AXI and core data domains. The raw `tx_active` also feeds `pa_enable` directly as the documented asynchronous fail-safe blanking gate. | A valid two-flop destination chain exists. Source Q has three routed endpoints: the parent meta D, Wizard reset meta D, and combinational `pa_enable`. CDC-11 remains open; the routed report does not explain beyond its fan-out rule label why it treats the path as critical. |
| Wizard reset controller | Same generated two-flop TX user-clock active chain above. | Generated `gtwizard_ultrascale_v1_7_gtwiz_reset.v` instantiates `gtwizard_ultrascale_v1_7_18_bit_synchronizer` on `gtwiz_reset_clk_freerun_in` (`freerun_clk200`). The five stages are `i_in_meta`, `i_in_sync1`, `i_in_sync2`, `i_in_sync3`, `i_in_out`; the first four have `ASYNC_REG="TRUE"`, and the final output stage is unmarked. The synchronized level gates `txuserrdy_out` and TX reset FSM progress in `ST_RESET_TX_WAIT_USERRDY`. | The full five-stage chain is present and its output is used in TX reset release sequencing. CDC-11 remains open pending supported vendor disposition or an IP configuration change with fresh evidence. |

The routed database query in the Tcl audit confirms the parent destination
first and second stages are FDCEs with `ASYNC_REG=1` on `freerun_clk200`, and
the Wizard destination stages are FDREs on that same clock. The generated
source TX active output flop is also an `ASYNC_REG=1` FDCE on `core_clk218`.
These attributes and stage counts support the intended synchronizer
structures; they do not override Vivado's critical CDC classification or
establish metastability/MTBF safety. The CDC exception is the existing
asynchronous clock-group classification. No CDC waiver, new false path, or
constraint change was added.

Functional parent loss/recovery simulation is indirect evidence for reset
behavior only. It does not assert the Wizard synchronizer stages, does not
prove the TX user clock stops on loss, and cannot settle either CDC-11 finding.

## Parent clock, pin, and I/O budget facts

The only parent-specific physical constraints located are in
`fpga/zu15eg/constraints/thermo5_qsfp_gt14_parent.xdc`. Its ordinary clock
periods (`axi_clk125` 8.000 ns, `freerun_clk200` 5.000 ns) and interface
budgets are explicitly prospective assumptions. The XDC assigns prospective
package pins for the MGT reference pair and four QSFP TX/RX pairs. It does not
provide package pins or verified source definitions for `axi_clk125`,
`freerun_clk200`, or `reset_n`.

Missing measured/authoritative parent timing inputs are:

- clock-generator part/register configuration and measured frequencies,
  tolerances, jitter, phase relationships, duty cycle, and startup behavior
  for AXI, the 200-MHz free-run clock, and the bank-128 MGT reference;
- actual board/package pin and source ownership for the two fabric clock
  inputs and reset, plus the parent SoC launch/capture clock definition;
- AXI ingress `set_input_delay -min/-max`, AXI ready/full
  `set_output_delay -min/-max`, all timed status/control output budgets, and
  reset assertion/release width and recovery/removal requirements from the
  actual consuming devices;
- actual system timing contract for the parent interface. The XDC's 0.20 to
  2.00 ns input and 0.00 to 1.50 ns output delays are placeholders, not
  measured or sourced limits.

`fpga/zu15eg/THERMO5_FOUR_PA_SERIALIZER_CONTRACT.md` records a local schematic
audit: four QSFP1 TX/RX pairs map to GTH bank 128, while the schematic labels
the bank-128 clock-generator output as 156.25 MHz. The referenced PDF exists
in the workspace but is untracked (`git ls-files` does not list it), so the
tracked board evidence is the summary in that contract, not the schematic
source itself. The contract also states that no
125-MHz bank-128 clock-generator configuration has been provided or verified;
the target 14.000-Gb/s GT configuration requires a 125-MHz reference. Thus
the available board documentation resolves lane feasibility and flags a
reference-frequency mismatch, but does not establish the assumed 125-MHz
reference, clock generator programming, fabric clock pins/sources, or system
I/O timing budgets. The XDC and current board documentation therefore do not
close the missing parent timing facts.

## Disposition

Both CDC-11 paths remain **OPEN**. The structure is identifiable and both
destination chains carry the expected synchronizer attributes, but there is
no AMD-supported disposition for these exact findings and no verified Wizard
configuration change that removes or safely reclassifies them. Next action:
obtain AMD guidance for the precise TX-active topology, or make a documented
Wizard configuration change and regenerate/reroute the design; then rerun
CDC and inspect each path. Keep both rows visible and do not add a broad
waiver or false path.

Separately, parent STA signoff remains **OPEN** until the actual clock source
configuration, pins, and minimum/maximum timing budgets are supplied and
applied, then the routed timing and CDC/RDC checks are repeated.

# Thermo5 SpyGlass Errors and Warnings — 2026-11-12

Scope: actual SpyGlass V-2023.12-SP1 setup, CDC, and RDC runs for the
thermo5 AXI-Lite product top, `DPD_MAX_TAPS=1`, `FPGA_USE_XPM_FIFO=0` (Generic
FIFO), three clock domains, and three independently declared active-low
resets. No waiver was applied.

## Counts

| Goal | Fatal | Error | Warning | Info |
|---|---:|---:|---:|---:|
| Setup | 0 | 0 | 15 | 65 |
| CDC structural | 0 | 5 | 29 | 101 |
| RDC structural | 0 | 10,506 | 15 | 76 |
| **Total reported records** | **0** | **10,511** | **59** | **242** |

The errors consist of five `Ac_glitch03` CDC findings and 10,506 individual
`Ar_resetcross01` RDC findings. The 10,506 RDC rows are structural source to
destination/reset relationships, not 10,506 independently established
functional defects. All exact native rows remain open for review; none is
waived. The complete native message inventory, including source, destination,
rule, severity, file, line, full message, and disposition fields, is available
in [static_messages.csv.gz](data/thermo5-cdc-phase2/static_messages.csv.gz).
It contains 10,812 rows: every Error and Warning above plus 242 Info rows.

## Errors

### CDC: 5 `Ac_glitch03`

SpyGlass reports combinationally derived signals feeding destination flops:

| Destination flop | Destination clock | Finding |
|---|---|---|
| `u_cfg.tx_active_sync1` | `s_axil_aclk` | Two same-domain fan-in sources; destination can glitch |
| `u_cfg.draining_sync1` | `s_axil_aclk` | Two same-domain fan-in sources; destination can glitch |
| `core_active_s1` | `s_axis_aclk` | Two same-domain fan-in sources; destination can glitch |
| `prefill_gray_c1[0]` | `core_clk` | One same-domain fan-in source; destination can glitch |
| `ingress_closed_c1` | `core_clk` | Three same-domain fan-in sources; destination can glitch |

The run reports zero unsynchronized clock crossings, but that does not resolve
these five glitch findings. Endpoint-specific glitch safety, encoding, and
reconvergence review remain required. Gray encoding checks are reported as
disabled, and bundled-data stability was not proven by this run.

### RDC: 10,506 `Ar_resetcross01`

The exact per-bit source/destination/reset relationships are in the complete
CSV and the raw [RDC report](data/thermo5-cdc-phase2/rdc_moresimple.rpt.gz).
The preserved root grouping is:

| Structural group | Error rows |
|---|---:|
| Elastic FIFO unreset-payload/reset-control relationships | 7,576 |
| DPD unreset-payload/reset-control relationships | 2,680 |
| Gain unreset-payload/reset-control relationships | 149 |
| Async FIFO unreset-payload/reset-control relationships | 96 |
| Mailbox reset relationships | 5 |
| **Total** | **10,506** |

These are reset crossings involving data/control into unreset storage and
cross-domain reset dependencies. They require root-specific reset-epoch,
memory-valid gating, and reset-release contract evidence. No blanket waiver or
physical RDC signoff is implied.

## Warnings

There are 59 warning records across the three goals. Fifteen base lint
warnings (four synthesis warnings and eleven `WRN_1024` findings) repeat in
setup, CDC, and RDC reports, accounting for 45 records. CDC adds 14 structural
warnings. The exact per-goal message IDs and wording are in the full CSV.

### Repeated base warnings: 15 findings per goal

| Rule | File and source lines | Finding |
|---|---|---|
| `SYNTH_5143` (4) | `rtl/gt/gt_tx_user_bridge.sv:19`; `rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv:347`; `rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv:95`; `rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv:273` | Initial blocks are ignored for synthesis |
| `WRN_1024` (1) | `rtl/dpd/dpd_memory_poly.v:285` | Already-signed `r4_full_s2[tap]` passed to `$signed` |
| `WRN_1024` (2) | `rtl/frontend/dsm_frame_gain_vector.sv:128,130` | Already-signed `s0_gain` passed to `$signed` |
| `WRN_1024` (4) | `rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv:175-178` | Already-signed `u0_check`, `e0_raw_check`, `u1_check`, and `e1_raw_check` passed to `$signed` |
| `WRN_1024` (4) | `rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv:296-299` | Already-signed `u_i_check`, `u_q_check`, `e_i_raw_check`, and `e_q_raw_check` passed to `$signed` |

### Additional CDC warnings: 14

| Rule | Count | Reported condition |
|---|---:|---|
| `Ac_coherency06` | 4 | `run_sync2` feeds `draining_sync1` and `tx_active_sync1`; `run_s2` feeds `run_s2_c1` and `ingress_closed_c1`; `prefill_count_s[1]` is synchronized as `prefill_gray_c1[1:0]`; `core_tx_active_q` feeds both drain/active synchronizers |
| `Ac_conv01` | 3 | Synchronizer reconvergence at `drain_complete`, `prefill_count_s[0]`, and `core_protocol_error` |
| `Ac_conv02` | 2 | Synchronizer reconvergence at FIFO `wr_full_next` and `rd_empty_next`; Gray encoding check is disabled for both |
| `Reset_sync04` | 5 | Repeated synchronization of `s_axis_aresetn` (two reports), `core_aresetn` (two reports), and `s_axil_aresetn` (one report) |

## Reproduction and Evidence

The archived raw reports are [setup](data/thermo5-cdc-phase2/setup_moresimple.rpt.gz),
[CDC](data/thermo5-cdc-phase2/cdc_moresimple.rpt.gz), and
[RDC](data/thermo5-cdc-phase2/rdc_moresimple.rpt.gz). Machine-checked counts,
rule totals, report hashes, and test status are in
[results.json](data/thermo5-cdc-phase2/results.json). The run context and open
obligations are documented in
[phase2_report.md](data/thermo5-cdc-phase2/phase2_report.md).

The Phase 2 run successfully elaborated the actual top and reported zero
unsynchronized clock crossings. It did not prove Gray encoding, bundled-data
stability, or physical reset-release safety. The report records two scoped
block tests as PASS, but they do not close product-level CDC/RDC findings.
Static CDC/RDC signoff remains OPEN.

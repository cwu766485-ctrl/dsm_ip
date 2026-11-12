# Thermo5 SpyGlass CDC/RDC root-cause triage (no waivers)

Scope: PR #60, product RTL SHA `635be681046b3ab7d6fdda7f4e9818d7226efd66`, AXI-Lite top, Generic FIFO, DPD_MAX_TAPS=1, three separately declared clock/reset domains.

## Native-report findings

- CDC: 5 `Ac_glitch03` errors, 29 warnings. The five destinations are `u_cfg.tx_active_sync1`, `u_cfg.draining_sync1`, `core_active_s1`, `prefill_gray_c1[0]`, `ingress_closed_c1`.
- RDC: 10,506 messages of severity Error, 15 warnings. `Ar_resetcross01` has 10,525 *records* across severities; these are not 10,525 independent silicon faults.
- From the original 10,525 `Ar_resetcross01` entries, source-file grouping yields 7,576 entries in `tid32_thermo5_frontend_tx.sv`, 2,680 in `dpd_memory_poly.v`, 149 in `dsm_frame_gain_vector.sv`, 98 in `dsm_async_fifo.sv`, 12 in `thermo5_dpd_axi_lite_cfg.sv`, 10 in the AXI-Lite top. Sum=10,525.
- The largest destination families are unreset data arrays in frontend elastic/registered-ready buffers and DPD pipeline registers. The generic asynchronous FIFO `mem[0..15]` accounts for only 96 exact paths with destination name matching `u_async_fifo.mem[*]`, not the majority.
- The native report explicitly includes `Reset: NULL` destination and `Q->EN` source dependencies. Distinguish intentional non-reset data *under validity masking* from genuinely unsafe reset-domain interactions.

## Risk prioritization

| Priority | Target | Required resolution |
|---|---|---|
| P0 | Clock-domain source combinational logic at 5 first-stage synchronizer inputs | Check glitch safety. Candidate product RTL ECO: register the *source-domain* status/Gray/ingress-closed signals before synchronizing. This is **not approved** until interface latency and end-to-end behavior are validated. |
| P0 | Independent vs common reset assumption | Get documented hardware/reset-owner contract. The SGDC currently declares 3 independent active-low resets. Do not globally assert equivalence unless hardware actually guarantees atomic assertion and bounded release. |
| P0 | Reset gating of unreset elastic/DPD memories | For each repeated root, prove valid/occupancy gating prevents stale data being consumed on reset assertion, during skew, and after release. Product-level reset epochs and proof are necessary. |
| P1 | Async FIFO memory and Gray pointers | Prove synchronizer/reset guard, no accepted push/pop in reset, and old-epoch exclusion. Do not reset the entire memory merely to silence RDC. |
| P1 | Config four-phase mailbox + independent reset | Prove reset abort/no stale ACK/DONE/payload, especially AXIL-only vs Core-only reset if supported. If unsupported, encode integration contract. |
| P1 | Quasi-static path, Gray reconvergence, reset equivalence constraints | Enable supported structural checks and bind assumptions to actual SoC reset/clock ownership; rerun exact goals. |

## Next actions

1. Run `python3 tools/hw/thermo5_rdc_rootcause_audit.py docs/verification/data/thermo5-cdc-phase2/static_messages.csv.gz --out-dir runs/thermo5_rdc_rootcause`. The script retains original IDs and exact source/destination in each representative group, with counts and reset relationships. **Grouping is not a waiver.**
2. Reconcile grouped counts against original `results.json`; preserve all original reports and hashes.
3. Independently inspect/verify the five `Ac_glitch03` synchronizer sources. For Gray prefill, check source register encoding and destination capture across changing binary counts.
4. Introduce a separate ECO proposal **only if** a real unsafe crossing is found. Do not update the frozen RTL directly. Require VCS, independent oracle, targeted Formal and fresh SpyGlass before and after.
5. RDC root-group proofs: data-valid masking, memory write enable, reset epoch, and reset release. Only then submit scoped *tool* waiver requests with native message IDs and independent review.
6. Static CDC/RDC waivers are distinct from **URG code-coverage exclusions**. Neither may be automatically approved or counted toward coverage signoff.

## Signoff

CDC/RDC: OPEN. Original 5 CDC / 10,506 RDC errors remain unchanged until new real SpyGlass results or approved narrowly scoped dispositions. No accepted waivers, product RTL modifications, or product URG changes in this triage commit.

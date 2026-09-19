# Update Log

## 2026-09-19 - Retire unclosed temporal BP/SMASH experiments

- Removed the CRFB-SMASH temporal8/temporal64 prototype and the TID32 MASH1-1 experiment, including their dedicated MATLAB models, vectors, XSim testbenches, and OOC scripts.  They had useful research evidence but did not constitute a deployable 64-lane streaming implementation.
- Retained scalar BP/EFDSM/MASH IP, the P0 regression set, and the thermo5 frontend.  The behavioural screening script no longer advertises the removed CRFB candidate.
- Rationale: keep the repository focused on the bit-true, routed thermo5 digital frontend and prevent unclosed experimental temporal chains from being mistaken for a 218.75-MHz implementation.
- Checks after removal: MATLAB P0 passed all seven designs at 65,536 samples with zero mismatch; XSim P0 passed 7/7; IP smoke passed top, AXI, active-reset, BP-AXI, and DPD-v1.1.
- Remaining limitation: this cleanup does not create four physical GTH or PA paths; serializer/PA evidence remains simulation-only until board resources exist.

## 2026-09-19 - Four-path raw serializer loopback contract

- Added a simulation-only four-path raw-64 serializer/receiver model and a full thermo5 frontend loopback test.  Each path serializes `TXDATA[0]` first at a 64x serial clock, and all paths share reset and word cadence.
- Corrected the initial model so the launch edge emits bit 0.  The prior version consumed 65 serial edges per word and reinterpreted a level-valid word as repeated requests; the toggle-based launch contract now consumes each user handshake exactly once.
- The full frontend serializer loopback passed: 64 ingress words recovered on all four paths, 4,096 serial bits per path, zero word mismatches.  This is functional digital evidence only; it is not a GT analog, channel, PA, or board-loopback result.
- Added `fpga/zu15eg/THERMO5_FOUR_PA_SERIALIZER_CONTRACT.md`.  The current public board mapping remains dual-SFP only, so four physical GT/PA pin assignments are deliberately left pending actual board resources.

## 2026-09-18 - Five-level streaming frontend RTL and routed OOC

- Added the Q2.14 `dsm_frame_gain_vector` streaming contract and the complete `8-lane -> x2 polyphase -> identity memory-DPD -> x2 polyphase -> thermo5` frontend wrapper.  Frame gain is accepted with its frame-start word, is applied to that word, and remains active until the next accepted frame start; reset initializes unity gain.  The deployed memory-DPD coefficients remain identity because the held-out qualification gate remains rejected.
- Added a MATLAB vector generator, a four-plane XSim testbench, and a ZU15EG OOC flow for the wrapper.  The new frontend XSim passed 64 ingress words / 2,048 final complex samples with zero mismatches on all four raw planes, including three frame-gain changes.
- Routed `xczu15eg-ffvb1156-2-i` OOC at 218.75 MHz passed: WNS `+0.178 ns`, WHS `+0.027 ns`, TNS/THS zero, 0 critical warnings, and 0 errors.  Post-route utilization is 70,233 LUT, 88,839 FF, 2,064 DSP48E2, and 0 BRAM.  The OOC timing report warns that `HD.CLK_SRC` is unset and some OOC boundary ports have no `HD.PARTPIN_LOCS`; this is a fabric result, not a board/GTH clock-skew or serializer signoff.
- Re-ran the required checks: MATLAB P0 (seven designs, 65,536 samples each, zero mismatch), project XSim P0 (7/7 pass), and IP smoke (top, AXI, active-reset, BP-AXI, and DPD-v1.1 pass).

## 2026-09-18 - Strict five-level 250-MHz fair-RMS gate

- Upgraded `entry_tid32_thermo5_fullchain_250_mild_three_seed.m` from an insufficient 2/2/3-symbol smoke to isolated 12/10/12-symbol fit/validation/held-out frames.  The fixed fair-RMS drive remains `0.095`; its worst measured PAPR over the nine fixed frames is `3.6673`, so it remains below the explicit 0.35 peak contract.
- The full two-x2-interpolator, four-branch behavioural DPA/BPF/DDC chain has zero raw-word mismatches for all three seed sets, but only the first set passes: `3.2241%` EVM / `29.8318 dB` SNDR.  The second and third are `4.5765%` / `26.7894 dB` and `4.5525%` / `26.8350 dB`.  Therefore 250 MHz is not qualified under a constant-RMS drive policy.
- Added a separate peak-normalized 12/10/12-symbol entrypoint.  It is an explicitly different, unclipped per-frame drive policy and will be reported separately from fair-RMS; it is not a replacement for the failed constant-average-power gate.

## 2026-09-18 - Peak-normalized five-level 250-MHz identity baseline

- The new full-chain peak-normalized gate uses the same mild behavioural DPA/BPF/DDC profile, two x2 interpolators, four code planes, BPF/DDC receiver, independent 12/10/12-symbol frames, and three seed sets as the strict fair-RMS run.  It scales each input frame without clipping to the fixed 0.35 peak contract; consequently the average drive is PAPR dependent and this result is intentionally not comparable as a constant-power result.
- All three identity cases pass with zero raw-word mismatches: `2.8221%` / `30.9884 dB`, `3.0846%` / `30.2161 dB`, and `3.1831%` / `29.9432 dB` (EVM / SNDR).  This is the first accepted 250-MHz **parameterized behavioural** point for the complete digital/DPA/BPF/DDC model, not a PA measurement, GTH target result, physical four-serializer result, or board result.
- Added the matching four-tap Q2.14 memory-DPD three-seed qualification entrypoint.  Its validation and held-out results must both improve before any coefficient replaces the identity RTL deployment.

## 2026-09-18 - Peak-normalized 250-MHz memory-DPD gate

- Ran the four-tap Q2.14 1/3/5 memory-polynomial indirect-learning candidate against the accepted peak-normalized identity baseline, using the identical mild four-branch DPA/BPF/DDC profile and isolated 12/10/12-symbol seed sets.  All six identity/candidate endpoints retained zero raw-word mismatches.
- The candidate is not deployable: seed 101 regressed from `2.8221%` / `30.9884 dB` to `2.9352%` / `30.6472 dB`; seed 307 regressed from `3.0846%` / `30.2161 dB` to `3.1281%` / `30.0945 dB`; only seed 503 improved marginally from `3.1830%` / `29.9432 dB` to `3.1796%` / `29.9525 dB`.  The first two validation gates also regressed, so `HeldOutDeploymentAccepted=0` and the Q2.14 RTL coefficients remain identity.
- This is a generalization decision, not a statement that DPD cannot help another PA profile.  Further DPD work must follow a demonstrated frontend/drive improvement and retain the same isolated train/validation/held-out gate.
- Re-ran `scripts/run_matlab_p0_bittrue_check.cmd`: LPDSM, LPDSM2, EFDSM, EFDSM2, MASH11, MASH111, and MASH22 all passed 65,536 samples with zero mismatch.

## 2026-09-17 - Five-level full-frontend 250-MHz isolation

- Parameterized `run_tid32_thermo3_frontend_pa_dpd.m` for an explicitly selected three- or five-level thermometric TID while retaining its default three-level behavior.  The five-level wrapper reuses the same two x2 interpolators, Q2.14 memory-DPD interface, DPA/BPF, DDC, OFDM receiver, and acceptance rules; it does not fork a second, drifting behavioral chain.
- Added five-level full-chain/profile entrypoints.  Four-plane raw-word sanity at 250 MHz passed with zero mismatches; ideal RF/DDC NMSE was `1.0981e-4`.
- The complete 250-MHz frontend does not yet qualify: even ideal four-path PA/BPF returned `5.4454%` EVM / `25.2794 dB` SNDR.  Nominal DPA/BPF identity returned `3.7758%` / `28.4598 dB`; four-tap memory-polynomial DPD returned `3.8513%` / `28.2878 dB` and was rejected by validation and held-out gates.  The synthetic mild profile failed all three isolated seeds, worst case `4.1122%` / `27.7185 dB`.
- The evidence isolates the current limit to the two-stage frontend/TID working point before DPA compensation.  Next work is polyphase image-rejection and drive/threshold co-optimization, followed by the same three-seed DPA/BPF/DDC gate.  No 250-MHz full-system, GTH, PA, or board claim is made.
- A six-tap causal Lagrange x2 exploration improved ideal-PA EVM from `5.4454%` to `5.0474%` but did not meet the gate.  A 31-tap windowed-sinc exploratory mode produced `5.7814%`; its group delay is not yet represented by the OFDM crop/equalizer contract.  It is MATLAB-only and deliberately not promoted to RTL.  The default four-tap MATLAB/RTL contract is unchanged.

## 2026-09-17 - Five-level thermometric RTL milestone

- Added the conservative four-branch `tid32_thermo5_fs4_multipa_tx` RTL, its MATLAB fixed-point vector generator, bit-true XSim testbench, and a ZU15EG 218.75-MHz OOC flow.  The four branch thresholds are `{+3, +1, -1, -3} * STEP`, producing four aligned raw code planes for a five-level thermometric switching-PA architecture.
- Corrected only the testbench memory loading topology after `$readmemh` failed to load a selected row of an unpacked two-dimensional memory reliably.  The testbench now uses four one-dimensional memories; RTL arithmetic, state update order, quantization, and vector contents are unchanged.
- Checks: five-level MATLAB-to-XSim PASS for 128 continuous words / 4,096 complex samples with zero mismatches on all four raw streams.  Routed ZU15EG OOC at 218.75 MHz PASS: WNS `+2.894 ns`, WHS `+0.030 ns`, estimated Fmax `596.15 MHz`, 22,699 LUT, 21,464 FF, 0 BRAM, 0 DSP.  Required P0 regression PASS: 7/7 designs, 65,536 samples each, zero errors.  Required IP smoke completed and passed its top, AXI, active-reset, BP-AXI, and DPD-v1.1 tests.
- Limitation: the result verifies only the four-code-plane fabric.  It is not a four-GTH target STA, physical four-PA implementation, board loopback/BERT result, full DPA/BPF/DDC qualification, or a 250-MHz system claim.

## 2026-09-17 - Five-level 250-MHz digital receiver gate

- Added `entry_tid32_thermo5_250mhz_three_seed_rawddc.m` to make the five-level raw-Fs/4 acceptance reproducible.  It uses `STEP=7168`, three isolated seeds (`101/307/503`), eight OFDM symbols per seed, fair-RMS drive `0.11`, the physical raw Fs/4 DDC receiver, and a 0.35 peak-drive ceiling.
- The initial fair-RMS `0.13` trial correctly stopped at the input peak assertion: the 250-MHz OFDM waveform exceeded the configured 0.35 peak drive.  This is an explicit back-off constraint, not a timing or bit-order failure.
- At RMS `0.11`, actual occupied bandwidth `249.51171875 MHz` / OSR `28.055`, all three seeds passed with zero raw-stream mismatches.  Worst case was `3.2249%` EVM and `29.8298 dB` SNDR; maximum input peak was `0.3220`.
- This is a digital raw-TID/Fs/4/DDC receiver gate.  The current result excludes both x2 interpolators, the memory-DPD deployment path, behavioral DPA/BPF, four-GTH target STA, and board verification; it must not be presented as a full 250-MHz transmitter signoff.

## 2026-09-17 - ASIC synthesis preflight

- Added the reviewed `asic-dc-preflight` Rocky bridge task and ran it through the audited Windows-to-Rocky bridge.  Rocky 8.10 resolves `dc_shell` at `/opt/Synopsys/syn/V-2023.12-SP1/bin/dc_shell`.
- The preflight stopped before synthesis because `DSM_ASIC_STDCELL_DB` is unset.  No standard-cell `.db`, mapped netlist, PPA number, or ASIC timing claim was generated.  A permitted nominal logic-cell `.db` is required before probing the library and running the existing pre-layout DC flow.

## 2026-09-17 - Readable DPD deltas and five-level TID feasibility screen

- Updated `plot_tid32_thermo3_dpd_four_way_delta.m` to give every non-identity DPD its own `DeltaPSD` panel (negative is lower BPF-side emission).  It makes explicit that the four-tap candidate is best only on one held-out EVM/SNDR point, not on ACLR; no visual inference of deployment quality is made.
- Added a behavioral four-branch five-level thermometric TID oracle and an offset-step screen.  Every screened point had zero temporal32/scalar raw mismatch.  The original screen used an I/Q shortcut that bypassed the raw Fs/4 sequence and produced a false low-bandwidth failure.  After replacing it with direct 14-GS/s Fs/4 DDC, fixed-RMS/seed-101 smoke passes at 17.09 MHz: thermo3 `3.0637%` / `30.275 dB`, and thermo5/step-6144 `3.0613%` / `30.282 dB`; the corresponding 99.12-MHz values are `1.4275%` / `36.909 dB` and `1.2639%` / `37.966 dB`.  These are single-seed behavioral screens only; no five-level RTL, serializer, or wideband deployment claim is made.
- Re-ran the existing two-stage MASH TID XSim: PASS for 128 words / 4,096 samples on both code planes.  Its previously recorded routed OOC remains timing-clean, but the independent OFDM qualification remains failed; more MASH stages are frozen pending a corrected transfer equation.
- Added input RMS/peak reporting, fixed-RMS mode, and selectable raw-Fs/4 DDC receiver mode to the OFDM screen.  The current sweep defaults to the raw DDC path; the I/Q shortcut is retained only to reproduce legacy data.
- In the same raw-DDC, fixed-RMS, seed-101, four-symbol smoke, thermo5/step-6144 also passes 157.23/198.24/239.26/259.77/276.86 MHz occupied bandwidth (OSR `44.52/35.31/29.26/26.95/25.28`).  The 276.86-MHz edge point is `3.4209%` EVM and `29.3171 dB` SNDR.  This is a single-seed behavioral feasibility boundary, not a DPA/BPF/full-frontend or RTL/FPGA qualification.

## 2026-09-17 - Four-way thermo3 DPD stress comparison

- Added `plot_tid32_thermo3_dpd_four_way_stress.m` plus a non-interactive entrypoint.  The comparison holds the exact thermo3 frontend, two switching-PA paths, BPF/DDC, 17.09-MHz OFDM frame, seeds, and synthetic memory-stress profile constant while changing only the DPD: identity, 1/3/5 memoryless polynomial, 16-bin LUT, or four-tap 1/3/5 memory polynomial.
- Held-out results were identity `2.0065% / 33.9512 dB`, memoryless `1.9927% / 34.0111 dB`, LUT `21.8888% / 13.1956 dB`, and four-tap memory polynomial `1.9664% / 34.1266 dB` (EVM / SNDR).  The LUT candidate fails 256-QAM.  All four raw-word checks were zero mismatch.
- None of the candidates met the existing validation/held-out deployment gate, so the vector16 RTL coefficient table remains identity.  The comparison is behavioral; LUT and memoryless candidates are not current vector16 RTL integrations.
- Exported PNG, PDF, metrics CSV, PSD CSV, and profile CSV under `matlab/out/tid32_thermo3_dpd_four_way_stress/`.  Checks: MATLAB P0 bit-true PASS (7/7 designs, 65,536 samples each, zero mismatch); no RTL changed.

## 2026-09-17 - Full-seed qualification and DPD spectrum export

- Added: `matlab/tx_bandpass_if/plot_tid32_thermo3_dpd_spectra.m`; updated the endpoint result to export diagnostic identity/candidate waveforms and made the MATLAB DPD model configurable for one to four active taps.
- Full 12/10/12-symbol, three-seed identity qualification passed for all three synthetic profiles at 17.08984375 and 19.6533203125 MHz.  Worst qualified case was mild/19.6533203125 MHz: 3.4734% EVM and 29.1849 dB SNDR.
- Exported nominal 17.09-MHz ideal/identity/candidate spectra plus EVM, SNDR and model-only ACLR CSV/PDF/PNG.  The candidate is diagnostic only: held-out EVM/SNDR regress versus identity, so deployment remains rejected.
- Checks: `scripts/run_matlab_p0_bittrue_check.cmd` PASS (7/7 designs, 65,536 samples each, 0 mismatch).

## 2026-09-17 - Corrected severe-profile interpretation

- Corrected: `docs/exec-plans/active/execution-frontier.md`.
- The synthetic severe profile uses `Q=60`, which is a wider (not narrower) second-order BPF than nominal `Q=100` and mild `Q=140`.  Its preliminary 99.9755859375-MHz pass is therefore retained only as a coupled-model result; no single-parameter mechanism or physical-PA inference is claimed.

## 2026-09-17 - Parameterized profile/bandwidth screen

- Added: `matlab/tx_bandpass_if/run_tid32_thermo3_profile_bandwidth_sweep.m`.
- Added a reproducible synthetic mild/nominal/severe switching-DPA/BPF profile sweep around the unchanged full digital frontend.  OSR is explicitly evaluated at the 7-GS/s complex DDC interface, consistent with the baseline.
- Identity screen (4/4/4 OFDM symbols, one isolated seed triplet) passed through 19.6533203125 MHz for mild and nominal profiles and through 99.9755859375 MHz for the synthetic severe profile.  The severe result is attributed to its narrow behavioural BPF and is not a physical-PA claim.
- Memory-DPD candidate screen (2/2/2 symbols, same isolated seed triplet) accepted no candidate on held-out data; the RTL deployment table remains identity.
- Checks: `scripts/run_matlab_p0_bittrue_check.cmd` PASS (7/7 designs, 65,536 samples each, 0 mismatch); profile sweep raw-word checks were 0 mismatch.  No RTL changed, so XSim, OOC, and GTH STA were not rerun.

## 2026-09-17 - Digital/FPGA simulation scope

- Changed: `docs/exec-plans/active/execution-frontier.md`.
- Confirmed that this project is scoped to digital IC/FPGA implementation and parameterized PA/BPF/DDC simulation.  Physical PA characterization, coupler feedback capture, and measured-RF signoff are explicitly out of scope.
- Replaced the feedback-capture dependency with reproducible mild/nominal/severe behavioral-DPA profiles, isolated train/validation/held-out OFDM datasets, robust memory-DPD acceptance gates, and a complete 20-to-200 MHz simulated bandwidth sweep.
- No RTL, fixed-point behavior, simulation result, or hardware evidence changed.  No regression was required for this documentation-only scope decision.

## 2026-09-17 - Execution-frontier consolidation

- Changed: `docs/exec-plans/active/execution-frontier.md`, `docs/exec-plans/completed/20260917-152449-completed-history.md`.
- Moved completed implementation and verification milestones out of the active execution frontier.  The active document now records only the current architecture, signed evidence, acceptance gates, active risks, and dependency-ordered next actions.
- No RTL, fixed-point behavior, simulation vector, synthesis result, or board state changed.  `docs/exec-plans/completed/20260917-152449-completed-history.md` preserves the completed-history summary.
- Checks: `git diff --check` PASS.

## 2026-09-17 - Parameterized switching-DPA model and held-out DPD decision

- Changed: `matlab/tx_bandpass_if/run_tid32_thermo3_frontend_pa_dpd.m`, `docs/exec-plans/active/execution-frontier.md`.
- Replaced the gain-mismatch/linear-FIR PA surrogate with `behavioral_switching_dpa_v1`: per-branch pulse-density AM-AM thermal memory, polarity asymmetry, finite output FIR memory, analytic-signal AM-PM, and a causal second-order RLC-equivalent BPF (`Q=100`, `0.6 dB` insertion loss).  Every profile parameter is exported as `tid32_thermo3_frontend_pa_profile.csv`; the profile is configurable, not a measured PA calibration.
- Corrected the Fs/4 receiver to search both 14-to-7-GS/s timing phases rather than hard-code a phase.  The raw-word sanity gate remains 0 mismatches; the ideal BPF/DDC numerical gate is `1.8799e-6` NMSE at phase 0.
- Ran 12/10/12-symbol fit/validation/held-out 256-QAM OFDM DPD experiment.  The Q2.14 4-tap 1/3/5-order candidate improved validation from `2.5254 %` / `31.9535 dB` to `2.5122 %` / `31.9990 dB`, but regressed held-out test from `2.3917 %` / `32.4257 dB` to `2.3980 %` / `32.4032 dB`.  Deployment is rejected and the exported deployment table remains identity; the candidate table is retained for diagnosis.
- The identity DPA endpoint remains 256-QAM-decodable at 17.08984375 MHz occupied bandwidth / OSR 409.6.  Its model-only PA-side ACLR is `-24.0769 dBc` and causal-BPF-side ACLR is `-30.6297 dBc`; neither is physical-RF signoff.
- Checks: `scripts/run_matlab_p0_bittrue_check.cmd` PASS (7/7 designs, 65,536 samples each, 0 mismatch).  No RTL changed, so no XSim, Vivado OOC, or GTH timing result was rerun.

## 2026-09-16 - TID32 frontend RF/DDC gate and memory-DPD hold

- Changed: `matlab/tx_bandpass_if/run_tid32_thermo3_frontend_pa_dpd.m`, `docs/exec-plans/active/execution-frontier.md`.
- Added a raw-word receiver gate. The two thermometric PA words decode to the independent scalar thermo3 reference with 0 mismatches after the fixed 1,056-sample latency. Ideal equal-weight PA combining, ideal BPF, Fs/4 DDC, LPF and the required 14-to-7-GS/s odd-phase selection reproduce that decoded reference with normalized MSE `4.6754e-7`; this finite numerical value is from floating-point FFT filters, not a bit-order error.
- Corrected the end-to-end receiver's DDC decimation order and FFT/CP parameterization. The two causal x2 interpolators introduce a deterministic per-subcarrier response, so a separately generated validation OFDM frame now estimates one pilot channel coefficient per active subcarrier. At 17.08984375 MHz occupied bandwidth (OSR 409.6), ideal equal PA paths and no DPD give held-out EVM `2.1503 %` and SNDR `33.3501 dB`; the deliberately stricter single-complex-gain diagnostic is `4.3397 %` / `27.2507 dB`.
- Exercised Q2.14, four-tap, 1/3/5-order indirect-learning memory DPD on the current gain-mismatch/linear-memory PA model. The validation candidate marginally reduced rate-MSE (`0.99008` to `0.98747`) but failed the held-out OFDM test (`8.3732 %` EVM / `21.5422 dB`) versus identity (`1.1380 %` / `38.8773 dB`). The script now writes identity as the deployment coefficient table and preserves the rejected candidate separately; no memory-DPD coefficient is authorized for RTL programming.
- Checks: frontend RF/DDC raw-word gate PASS; ideal endpoint 256-QAM pilot-EQ gate PASS; nonideal-model DPD candidate held-out gate FAIL/rejected; `scripts/run_matlab_p0_bittrue_check.cmd` PASS (7/7 designs, 65,536 samples each, 0 mismatch).
- Limitation: the present PA branches are gain-mismatched linear FIRs, not a calibrated nonlinear DPA. Their ideal brick-wall BPF drives filtered ACLR to a numerical floor, so neither the reported filtered ACLR nor the rejected DPD candidate is RF-signoff evidence. A calibrated nonlinear PA/feedback model or measured feedback capture is required before another DPD-training attempt.

## 2026-09-15 — TID32 OFDM-domain qualification correction

- Changed: `matlab/tx_bandpass_if/tid_pipelined_first_order_step.m`, `matlab/tx_bandpass_if/run_256qam_tid32_ofdm_demod.m`, `docs/exec-plans/active/execution-frontier.md`.
- Corrected TID32 EFM signed-input handling to 16-bit offset binary and restored adjacent-MSB XOR at the output.  The initial time-domain pointwise OFDM score is retained only as historical debug data: it is not a QAM demodulation EVM.
- Added an OFDM receiver qualification path with startup/tail guards, CP removal, FFT and active-carrier EVM.  At 14 GS/s and Fs/4 = 3.5 GHz, occupied BW 17.08984375 MHz (OSR 409.6), scalar EFM is 3.3545 % / 29.487 dB and TID32 is 3.3658 % / 29.458 dB (EVM / SNDR); the TID32 de-interleaved stream has zero mismatches to scalar after its fixed 1,056-sample latency.
- Checks: `run_tid_pipelined_scalar_contract` PASS (8,192 samples, 0 mismatch); TID32 16-symbol OFDM demodulation PASS for EVM/SNDR.  RTL XSim, rerun OOC and GTH payload integration remain pending.

## 2026-09-15 — TID32 RTL word-level contract

- Added: `matlab/tx_bandpass_if/gen_tid32_bittrue_vectors.m`, `verif/block/bp_dsm/tb/tb_tid32_cartesian_fs4_gt_tx_bittrue.sv`, `verif/scripts/run_xsim_tid32_cartesian_fs4_gt_tx.ps1`.
- Added the payload-target board top and build Tcl.  SFP0 receives the actual TID32 raw word; SFP1 retains a distinct known word.  Its local source is explicitly a board smoke pattern, not a substitution for the future 256-QAM sample feeder.
- Checks: `run_xsim_tid32_cartesian_fs4_gt_tx.ps1` PASS — 128 words / 4,096 samples, MATLAB-to-RTL 64-bit GT word 0 mismatch.

## 2026-09-15 — TID32 routed OOC closure

- Check: `syn/run_ooc_tid32_cartesian_fs4_gt_tx.ps1` PASS on `xczu15eg-ffvb1156-2-i` at 218.75 MHz: WNS +3.045 ns, WHS +0.034 ns, TNS/THS 0, estimated Fmax 655.12 MHz; implementation completed with 0 critical warnings and 0 errors.
- Limitation: This is an OOC fabric result.  It does not replace the pending payload-plus-GTH target STA or physical SFP loopback.

## 2026-09-16 — TID32 20-MHz-class qualification boundary

- Check: The OFDM-domain TID32 screen at the next 4096-point grid point, 20.5078125 MHz occupied BW / OSR 341.33, returned EVM 3.8036 % and SNDR 28.396 dB.  This fails the fixed 256-QAM gate.
- Decision: Retain 17.08984375 MHz / OSR 409.6 as the only currently verified 256-QAM operating point for the single-bit first-order TID32.  Do not characterize it as a 20-MHz-qualified transmitter.

## 2026-09-16 — GTH timing target decoupled from ILA

- The ILA-bearing payload build stalled before main synthesis because its ILA OOC child terminated without an end marker; GT Wizard synthesis did complete.  No GTH payload STA result was produced.
- Added `USE_ILA` to the payload top and a no-ILA payload STA Tcl.  This preserves the ILA build for board bring-up while preventing a debug-core failure from blocking TID32+GTH timing signoff.

## 2026-09-16 — TID32 dual-SFP GTH payload closure

- Check: The no-ILA target routed on `xczu15eg-ffvb1156-2-i` with the real TID32 SFP0 payload and independent SFP1 known word.  Post-route detailed STA: WNS +0.480 ns, WHS +0.014 ns, TNS/THS 0.  Bitstream generation completed with 0 warnings, 0 critical warnings and 0 errors.
- Artifact: `D:/TraeTemp/tid32_cartesian_gt14_dual_sfp_sta_20260916/tid32_cartesian_gt14_dual_sfp_sta.bit`.
- Limitation: The local board source is deterministic payload smoke data.  Hardware loopback/BERT and a verified board 256-QAM sample feeder remain required.

## 2026-09-16 — Regression after TID32/GTH integration

- Checks: `verif/scripts/run_xsim_p0_all.ps1` PASS — 7/7 configurations, 65,536 samples each, Failed=0. `verif/scripts/run_xsim_ip_smoke.ps1` PASS, including BP AXI route and DPD v1.1 smoke.

## 2026-09-15 20:55 - Seven DSM scalar reference/temporal64 contracts

- Changed files: `matlab/tx_bandpass_if/dsm_scalar_transition.m`, `matlab/tx_bandpass_if/run_all7_scalar_reference_equivalence.m`, `matlab/tx_bandpass_if/run_all7_temporal64_contract.m`, `docs/exec-plans/active/execution-frontier.md`.
- Reason: freeze observable sample phase and PA-branch outputs against the behavioral models that generate the EVM evidence before starting temporal64 RTL.
- Checks run: `run_all7_scalar_reference_equivalence('samples',16384)` and `run_all7_temporal64_contract('words',256)`; all seven candidates reported zero mismatch, and every packed word-end state matched the serial reference.
- Remaining limitation: these are MATLAB reference contracts only; no candidate has temporal64 RTL/XSim/OOC/GTH qualification yet.

## 2026-09-15 21:15 - Dual-SFP GTH CDC correction in progress

- Changed files: `fpga/zu15eg/rtl/ti64_raw_gt14_dual_sfp_loopback_top.sv`, `fpga/zu15eg/constraints/ti64_raw_gt14_dual_sfp_loopback.xdc`, `docs/exec-plans/active/execution-frontier.md`.
- Reason: the clock-port target met WNS/WHS but methodology reported TIMING-7 because an RX-clocked ILA sampled `tx_ready` directly. TX and recovered RX user clocks are asynchronous domains.
- Change: added a marked two-flop TX-to-RX status synchronizer and an explicit asynchronous clock group.
- Checks run: P0 XSim 7/7 PASS; IP smoke 5 checks PASS. The corrected physical target build is still running; no board or final GTH claim is made.

## 2026-09-15 21:30 - Dual-SFP GTH CDC target timing closure

- Changed files: `fpga/zu15eg/rtl/ti64_raw_gt14_dual_sfp_loopback_top.sv`, `fpga/zu15eg/constraints/ti64_raw_gt14_dual_sfp_loopback.xdc`, `docs/exec-plans/active/execution-frontier.md`.
- Checks run: xczu15eg-ffvb1156-2-i dual-SFP `cdcfix` target route. Detailed STA: WNS +1.355 ns, WHS +0.014 ns, TNS/THS 0; methodology has zero critical warnings.
- Remaining limitation: TIMING-28 is a non-critical warning on auto-derived clocks used by the async group. Hardware loopback/BERT remains unrun; the result qualifies only the generic serializer platform, not DSM payloads.

## 2026-09-15 21:32 - CRFB-SMASH2 exact temporal8 RTL prototype

- Changed files: `rtl/tx_bandpass_if/crfb_smash2_temporal8.sv`, `docs/exec-plans/active/execution-frontier.md`.
- Reason: start the bounded 8-step transition-composition proof before attempting 16/64 samples.
- Checks run: `xvlog -sv rtl/tx_bandpass_if/crfb_smash2_temporal8.sv` PASS.
- Remaining limitation: MATLAB-vector XSim, state/stream bit comparison, and 218.75-MHz OOC are not yet run; the design is an exact serial composition prototype, not a timing-safe lookahead implementation.

## 2026-09-14 18:37 +08:00 — Cartesian x4/TI64 timing closure

- Replaced the unpipelined x4 vector polyphase FIR with a five-stage elastic
  implementation. Fixed-point arithmetic, rounding, saturation, history and
  lane ordering are preserved; latency increased.
- The final ZU15EG `TXUSRCLK2=218.75 MHz` routed build completed with zero
  errors and zero critical warnings: WNS `+0.387 ns`, WHS `+0.010 ns`, TNS/THS
  `0`, 20,835 LUTs, 21,203 FFs, 385 DSPs and 4 BRAM tiles.
- Checks: independent x4 bit-true XSim PASS; P0 XSim 7/7 PASS, 65,536 samples
  per test; five IP-smoke tests PASS.
- Remaining boundary: timing closure does not prove an SFP0 physical link,
  serialized word order, RF quality, or a 14 GHz RF carrier.

## 2026-09-14 18:45 +08:00 — Documentation consolidation and verification-first decision

- Consolidated current x4/TI64 design and implementation facts into `SPEC.md`
  and its required verification gates into `VPLAN.md`.
- Removed obsolete prototype, interview, resume, notebook, bridge, timing and
  duplicate evidence-index documents. `docs/exec-plans/` is deliberately
  unchanged.
- The next project milestone is digital verification closure before FPGA
  loopback or ASIC implementation.

## 2026-09-14 19:00 +08:00 - Stale experiment and generated-artifact cleanup

- Removed the unreferenced BP-EFDSM2 parallel/look-ahead/map-compose experiment family, its dedicated OOC launchers, testbenches/refmodels, raw-playback experiment, and RF7G MATLAB generator.
- Retained every static EDA task and its current source dependency: P0, IP smoke, TI64 core/frontend/x4 frontend, OOC, GT generation, and ZU15EG build flows.
- Removed explicitly scoped ignored Vivado/XSim/VCS caches, generated vectors, crash dumps, logs, and temporary PDF text; `.gitignore` now prevents their reintroduction.
- Checks: P0 XSim 7/7 PASS, IP smoke PASS, and Cartesian x4/TI64 frontend XSim PASS after cleanup. Restricted `fpga/hardware/`, `ads/`, and `data/` content was intentionally left untouched.

## 2026-09-14 22:55 +08:00 - Rocky VCS and board-connectivity preflight

- Added reviewed Rocky bridge tasks for a read-only VCS installation audit and linux64 compiler-launch probe.
- The VCS compiler exists at `V-2023.12-SP1/linux64/bin/vcs1`, but it explicitly rejects the active WSL2 kernel. The QAM-OFDM UVM task therefore fails before RTL compilation; no UVM or coverage result is claimed.
- Vivado 2024.1 Hardware Manager and local hw_server start correctly, but no JTAG target is visible at `127.0.0.1:3121`; no bitstream was programmed.
- Next action: connect and power the ZU15EG USB-JTAG path (or provide a reachable remote hw_server), then repeat target discovery before programming the x4/TI64 bitstream.

## 2026-09-14 23:10 +08:00 - Correct TI64 Fs/4 translation ownership

- Confirmed and fixed a duplicate Fs/4 translation in the Cartesian x4/TI64 path. The frontend now sends `[I,Q,I,Q]` to the TI lanes; TI64 alone applies the one-bit `+,+,-,-` translation.
- The prior x4 bitstream is invalid for 3.5 GHz IF/RF metric claims because the two sign translations cancel under odd-symmetric lane quantization.
- Checks: x4 frontend bit-true XSim PASS; P0 XSim 7/7 PASS; IP smoke PASS.
- Remaining: implement the vector memory-polynomial state chain and a waveform-level RF metric oracle before rebuilding/programming the corrected board image.

## 2026-09-15 08:45 +08:00 - Experimental BP-EFDSM4 candidate and 256-QAM screen

- Added an explicitly experimental, one-bit Fs/4 BP-EFDSM4 core with
  `v=x-2e[n-2]-e[n-4]`, its Python integer golden model, direct-input XSim
  bit-true test, and MATLAB screen candidate. Its linearized NTF is
  `(1+z^-2)^2`; this does not establish a usable stability range by itself.
- Checks: BP-EFDSM4 Python-to-RTL XSim PASS for 2,048 random/boundary samples;
  P0 XSim 7/7 PASS; IP smoke PASS. At 39.31 MHz occupied bandwidth and
  drive 0.15, the idealized 256-QAM screen reports 3.725% EVM, 28.578 dB SNDR,
  and -32.888 dBc ACLR. It improves the second-order candidates but misses the
  frozen 3.5% / 29.12 dB gate and is not a board, PA, or RF result.
- Corrected the x128/x256 ingress-rate planning contract: fixed 16-sample
  words arrive once per 32/64 output clocks respectively, not through a
  superficial x4-style data interface.

## 2026-09-15 09:00 +08:00 - EFDSM4 feasibility boundary and x128 cadence contract

- Parameterized the experimental BP-EFDSM4 feedback terms and ran an integer
  coefficient plus drive sweep. The only non-divergent nearby combination was
  the original `C2=-2, C4=-1`; high-resolution 39.31-MHz results over drive
  0.08--0.20 remain 3.724--3.727% EVM and 28.573--28.579 dB SNDR. No point
  meets the frozen 256-QAM gate.
- Added `dsm_interp_word_cadence16`, a synthesizable x128/x256 ingress timing
  contract. With x128 it accepts one 16-sample source word every 32 output
  words and records underflow; it intentionally contains no FIR arithmetic.
- Checks: BP-EFDSM4 Python-to-RTL XSim PASS (2,048 samples); interpolator
  cadence XSim PASS; P0 XSim 7/7 PASS; IP smoke 5/5 PASS. The x128/x256
  polyphase FIR and SMASH multi-output implementation remain active work.

## 2026-09-15 09:10 +08:00 - MASH multi-PA interface reset correction

- Added a research-only MASH1-1 multi-PA/serializer boundary which exposes the
  two quantizer bitstreams and the uncompressed four-level combiner result.
  It is explicitly not the paper-derived CRFB-SMASH candidate.
- Fixed `dsm_core_mash11` reset state for its delayed stage-2 sign from zero to
  positive one, matching its MATLAB model and preventing an illegal initial
  combiner level of zero or plus/minus two.
- Checks: multi-PA interface XSim PASS (128 samples); P0 XSim 7/7 PASS.

## 2026-09-15 16:55 +08:00 - Packed BP2 and MASH feasibility screen

- Added the exact temporal packed-BP2 oracle and the existing BP-MASH1-1
  multilevel combiner to the identical 256-QAM IF screen. At 39.31 MHz
  occupied bandwidth and drive 0.15, packed BP2 is exactly BP-EFDSM2:
  4.409% EVM / 27.114 dB SNDR / -22.543 dBc ACLR. BP-MASH1-1 reports 4.410%
  / 27.112 dB / -22.518 dBc. Neither meets the frozen 3.5% / 29.12 dB gate.
- The initial CRFB-SMASH2 oracle reports 99.892% EVM and is declared invalid
  pending a verified state-equation derivation; it is not used to judge the
  referenced CRFB-SMASH architecture and has no RTL implementation.
- Check: `run_256qam_dsm_if_screen` completed at Fs=14 GS/s, Fc=3.5 GHz with
  identical BPF/DDC/synchronization/demodulation settings for every candidate.

## 2026-09-15 17:00 +08:00 - MASH11 reset-contract correction

- MATLAB P0 comparison reproduced one MASH11 mismatch at sample 2 after an
  attempted reset change. The source-of-truth fixed-point model initializes
  the cancellation-delay state to zero, so RTL was restored to that contract.
  The multi-PA interface test now permits only the resulting first-sample
  +/-2 transient; all later values must be normal four-level codes.
- Checks after restoration: P0 XSim 7/7 PASS; MATLAB-to-RTL P0 comparison
  7/7 with zero mismatches over 65,536 samples each; IP smoke PASS; multi-PA
  interface XSim PASS (128 samples).

## 2026-09-15 17:10 +08:00 - CRFB-SMASH paper transfer-function audit

- Added `crfb_smash2_transfer_audit.m` from Xu et al. Fig. 2 and equations
  (7), (10), and (14). It reports per-stage and two-stage NTF polynomials,
  zeros, poles, stability, Fs/4 notch depth, and the three-level PA-code
  contract without pretending to be a fixed-point state model.
- Checks: at 14 GS/s and 3.5 GHz, `g=[2,2]`, `a=[-1,-1]` is stable with the
  expected `-(1+z^-2)^2` total NTF; `a=[-0.5,-0.5]` is also stable. The
  next required artifact is the Fig. 2 state-equation derivation and its
  independent fixed-point oracle, before RTL or 256-QAM qualification.

## 2026-09-15 17:20 +08:00 - Three-level BP DSM feasibility screen

- Added fixed-point three-level BP-EFDSM2 and BP-EFDSM4 behavioral models.
  The {-1,0,+1} output maps to two one-bit PA branches with fixed gain
  normalization; it does not alter the final 14-GS/s OSR.
- At the frozen 39.31-MHz/drive-0.15 256-QAM point, three-level BP2 reports
  4.371% EVM / 27.189 dB SNDR and three-level BP4 reports 3.726% / 28.575 dB.
  Neither meets the gate; quantizer level count alone is therefore not the
  acceptance path. Check: `run_256qam_dsm_if_screen` completed.

## 2026-09-15 17:30 +08:00 - Final-rate OSR and channel-bandwidth screen

- Swept requested 5/10/20/40 MHz channels at the fixed final interleaved
  rate of 14 GS/s and Fc=3.5 GHz. OSR is therefore Fs/(2B), not a function of
  the 218.75-MHz fabric clock or an ingress interpolation factor.
- At actual 9.40 MHz (OSR 744.7) and 19.65 MHz (OSR 356.2), BPDSM2,
  BP-EFDSM2, BP-EFDSM4, packed TI64-BP2 and the existing BP-MASH1-1 pass the
  frozen EVM/SNDR gate. BP-EFDSM4 at 19.65 MHz reports 2.078% EVM, 33.649 dB
  SNDR and -34.180 dBc ACLR. No candidate passes at actual 39.31 MHz (OSR
  178.1). The 5-MHz run has too few occupied tones/BPF FFT bins and is marked
  as an oracle-resolution issue pending a longer-vector rerun.

## 2026-09-15 17:40 +08:00 - CRFB-SMASH temporal-64 architecture constraint

- Verified Xu et al. equation (15), `v1=y1-y2` for two stages, and its stated
  de-interlacing/parallel-DSM/interlacing implementation with delay-register
  state propagation. The project CRFB route is consequently constrained to an
  exact 64-step state composition per word, not 64 independent DSM lanes.
- The scalar CRFB state transition remains the required predecessor; no
  temporal-64 RTL or timing claim is made yet.

## 2026-09-15 17:55 +08:00 - Causal CRFB transition and temporal-64 oracle

- Added the causal fixed-point scalar transition derived from the audited
  CRFB transfer functions, plus a 64-step composition contract. At
  `g=[2,2]`, `a=[-1,-1]`, scalar and temporal-64 agree on y1, y2, v1 and final
  state for 256 words / 16,384 random samples with zero mismatches.
- The checked CRFB transition replaces the invalid initial CRFB candidate in
  the common screen. It passes at 19.65 MHz: 2.075% EVM / 33.659 dB SNDR /
  -34.837 dBc ACLR; it fails at 39.31 MHz: 3.725% / 28.578 dB / -33.492 dBc.
- This is behavioral evidence only. A naive 64-way unroll is a 64-deep
  data-dependent chain and cannot inherit 203.125/218.75-MHz closure from a
  single scalar core. State-map lookahead/prefix composition is now the next
  implementation gate before RTL/OOC/serializer work.

## 2026-09-15 18:05 +08:00 - 256-QAM candidate consolidation

- Consolidated all behavioral-pass candidates at the actual 19.65-MHz,
  OSR-356.2 point. The two implementation branches are BP-EFDSM4 (single
  one-bit serializer) and CRFB-SMASH2 (two one-bit serializer/PA branches);
  other passing models remain comparison baselines.
- Existing 100-MHz AXI-IP OOC matrix has reached 48/70 rows, but contains
  neither exact-temporal64 BP-EFDSM4 nor CRFB-SMASH2. It is not evidence of
  timing closure for either selected branch.

## 2026-09-15 18:15 +08:00 - Unified temporal64 qualification scope

- Clarified the active rate as 64 lanes at 218.75 MHz = 14 GS/s (3.5-GHz
  Fs/4 IF). The 203.125-MHz figure belongs only to an alternate 13-GS/s rate.
- Every behavioral-pass candidate now has the same required qualification:
  scalar fixed-point, scalar-vs-temporal64 word/state equality, temporal64
  RTL, 218.75-MHz OOC STA, and raw-serializer ordering. One-bit candidates
  need one stream; CRFB/three-level candidates need two phase-aligned streams.

## 2026-09-15 18:20 +08:00 - GT serializer is a mandatory timing gate

- Expanded the qualification contract: 218.75-MHz fabric OOC proves only the
  raw-GT user-word boundary. Each candidate must also use a real 14-Gb/s GTH
  target-routed build, pass TXUSRCLK2/reset/clock timing, and demonstrate
  serialized-loopback/BERT recovered-word and bit-order equality. Multi-PA
  candidates require every phase-aligned serializer branch to pass.

## 2026-09-15 18:30 +08:00 - Two-PA GTH collateral audit

- Confirmed that the checked board integration supports one physical 14-Gb/s
  RAW GTH stream on SFP0/X1Y12, including its GT Wizard, 218.75-MHz user clock,
  target build and recovered-word observability. No checked second GTH/SFP
  channel constraints or clock/routing data are in the repository.
- CRFB/two-PA physical serializer work is blocked on that board collateral;
  pin assignment will not be guessed. Single-stream candidate integration can
  proceed independently after temporal64 RTL closure.

## 2026-09-15 19:25 +08:00 - Seven-candidate scope and SFP1 collateral recovery

- Replaced the active frontier with the concise seven-candidate qualification
  matrix requested for BPDSM2, BP-EFDSM2, BP-EFDSM4, both three-level BP
  variants, BP-MASH1-1, and CRFB-SMASH2. All seven now require the identical
  scalar-to-temporal64-to-GTH-to-loopback acceptance chain; no branch is a
  baseline-only exception.
- Inspected the repository's restricted ZU15EG schematic and vendor UCF
  without copying board collateral into project sources. They identify SFP1
  TX `D6/D5`, RX `C4/C3`, and the same quad-230 reference clock `C8/C7` used
  by SFP0. The adjacent GT site still requires a Vivado device-site query
  before a dual-channel Wizard or XDC is generated.
- Reviewed the verified 19.65-MHz screen data from
  `crfb_smash2_verified_screen/screen.csv`; it remains behavioral evidence
  only. The older OSR-sweep CRFB rows are retained as historical invalid-model
  output and must not be used for decisions.

## 2026-09-15 19:35 +08:00 - Seven scalar temporal64 contracts

- Added the common scalar fixed-point transition and exact 64-step composition
  harness for all seven requested candidates. The BP-MASH transition explicitly
  follows its behavioral bandpass reference rather than reusing the existing
  low-pass MASH RTL under a misleading name.
- Check: `run_all7_temporal64_contract('words',256)` PASS. Every candidate
  has zero mismatches across all emitted one-bit/level streams and an equal
  word-end state after 16,384 random samples.
- This is reference-model evidence only; the temporal64 RTL, 218.75-MHz STA,
  GTH route and board loopback gates remain open for all seven candidates.

## 2026-09-15 20:05 +08:00 - Dual-SFP GTH timing-root cause

- Added the two-channel SFP0/SFP1 RAW GTH infrastructure, including the
  `X1Y12 X1Y13` Wizard configuration, dual-channel wrapper, dual-SFP known
  word ILA top, and the board-derived SFP1 pins.
- The first target-routed build produced a bitstream with WNS `+1.419 ns` and
  WHS `+0.013 ns` at the real 218.75-MHz user-clock rate. Detailed STA still
  raised TIMING-3/6/7/14 critical warnings because manually created user
  clocks duplicated the Wizard's generated clocks. This build is explicitly
  not accepted.
- Removed the duplicate primary user-clock constraints while retaining the
  primary clock at the GT reference-buffer output. The next identical build
  must show the Wizard-derived 218.75-MHz clocks and zero critical warnings.

## 2026-09-15 21:49 +08:00 - CRFB temporal8 functional baseline and timing limit

- Added MATLAB-vector generation and XSim comparison for the exact eight-step
  CRFB-SMASH2 transition. The test now compares both two one-bit output words
  and all nine word-end state registers. Check:
  `run_xsim_crfb_temporal8.ps1 -Words 256` PASS, zero mismatches across 2,048
  samples.
- During bring-up every word mismatched. The RTL implemented quantization
  error as `u-q`; the audited scalar reference uses `q-u`. Correcting that
  sign restored bit-true output and state equality. The runner now requires
  an explicit XSim PASS marker instead of trusting the simulator exit code.
- Check: routed ZU15EG OOC at 218.75 MHz FAIL, WNS `-12.088 ns`, WHS
  `+0.453 ns`; implementation completed without critical warnings or routing
  failures. The causal eight-transition combinational chain is therefore a
  functional reference baseline, not a timing-safe lookahead or a 64-lane
  implementation. A finite state-map/branch-prediction representation is now
  required before further exact temporal64 RTL expansion.

## 2026-09-15 22:24 +08:00 - Exact CRFB scalar timing boundary

- Added a `STEPS` synthesis knob to the temporal8 prototype so the routed
  OOC flow can measure causal-chain depth without changing arithmetic,
  latency, or the normal eight-step functional contract.
- Check: at 218.75 MHz on `xczu15eg-ffvb1156-2-i`, `STEPS=1` fails routed
  STA: WNS `-0.909 ns`, WHS `+0.074 ns`. Explore placement/routing plus
  pre/post-route `AggressiveExplore` physical optimization improved it only
  to WNS `-0.827 ns`, WHS `+0.084 ns`.
- The failing path is 5.461 ns from `e1d2_r` to `e2d1_r`, including 31 logic
  levels (21 CARRY8) and 2.726 ns routing. The blocker is therefore the
  exact scalar fixed-point transition, not merely its 8/64-way unroll.
- The OOC runner now fails its PowerShell invocation when `summary.csv`
  reports timing `FAIL`; `-AllowTimingFail` is an explicit measurement-only
  override. Vivado's successful implementation exit code can no longer be
  mistaken for a timing pass.
- Regression checks after the RTL update: P0 XSim 7/7 PASS, IP smoke 5/5
  PASS, and the serial MATLAB-to-RTL P0 comparison 7/7 PASS (65,536 samples
  per design, zero mismatches). A first parallel MATLAB launch correctly
  failed because its P0 dump had not yet been generated; the final serial
  result is the valid evidence. The updated default `STEPS=8` temporal test
  also passes MATLAB-vector XSim for 256 words / 2,048 samples, including all
  two-branch output bits and nine word-end state registers.

## 2026-09-15 23:10 +08:00 - 14-Gb/s 256-QAM architecture correction

- Audited the Firmansyah MASc thesis equations for the pipelined first-order
  TIDSM and the MGS serializer. At `Fc=3.5 GHz`, its DSM sample rate is
  `2Fc=7 GS/s` and its MGS line rate is `4Fc=14 Gb/s`. With this project's
  fixed `218.75 MHz` fabric and 64-bit GTH user word, the matching topology
  is `L=32` polyphase channels per I and per Q path, not 64 independent
  real-valued LP1 lanes.
- The thesis-derived pre-summation / feedback / XOR architecture has a
  one-adder critical path independent of `L`; this is architecturally distinct
  from the exact 28-bit CRFB transition that failed at 218.75 MHz. The active
  implementation path is therefore a new fixed-point-reference pipelined Cartesian TIDSM,
  followed by payload GTH integration and loopback, rather than further CRFB
  unrolling.
- Corrected the active project scope after review: this is a fully digital
  `3.5 GHz` `Fs/4` transmitter with `14 GS/s` equivalent sample rate and a
  `14 Gb/s` raw-GTH line rate. It has no external LO/mixer. The number `14`
  must not be described as a 14-GHz RF carrier.

## 2026-09-15 23:28 +08:00 - Pipelined Cartesian TIDSM routed timing

- Added `tid32_cartesian_fs4_gt_tx`, its MATLAB fixed-point transition model,
  a ZU15EG OOC wrapper and a routed OOC script. The design implements 32
  polyphase channels per I/Q path and emits a 64-bit raw-GT word.
- Check: routed OOC on `xczu15eg-ffvb1156-2-i` at 218.75 MHz PASS, WNS
  `+3.053 ns`, WHS `+0.032 ns`, estimated Fmax `658.58 MHz`.
- `xvlog` compiled the RTL/wrapper and a 64-word MATLAB model smoke test
  passed. MATLAB-to-XSim vectors, 256-QAM metrics, GTH payload target-route
  and physical loopback remain open; this result alone is not a bit-true or
  transmitter-system acceptance claim.

## 2026-09-15 23:35 +08:00 - First TIDSM 256-QAM screen failure

- Added a standalone 256-QAM screen that drives the new 32-channel-per-I/Q
  fixed-point TIDSM at 7 GS/s, applies its deterministic 14-GS/s Fs/4 word
  ordering, and evaluates EVM/SNDR/ACLR.
- Check: the first run requested 19.65 MHz and used the nearest 4096-point
  OFDM occupied bandwidth of 17.08984375 MHz. Its equivalent OSR was 409.6,
  yet EVM was `99.420 %`, SNDR `0.050 dB` and ACLR `-7.857 dBc` (FAIL).
- The timing-clean TIDSM is therefore not accepted for any QAM modulation.
  The next investigation is the EFM input representation, STF/NTF and I/Q
  serializer sequence; MATLAB-to-XSim bit-true verification is intentionally
  deferred until those behavioral invariants pass.
- Regression check: `scripts/run_matlab_p0_bittrue_check.cmd` PASS for all
  seven retained legacy P0 designs, each with 65,536 samples and zero
  mismatches. This guards existing IP only; it does not validate the new
  TIDSM candidate.

## 2026-09-16 09:18 +08:00 - Two-stage Cartesian TID-MASH prototype

- Added a new `tid32_mash11_fs4_multipa_tx` architecture with two cascaded
  `L=32` first-order Cartesian TIDSM stages. Stage 2 receives the aligned,
  saturated stage-1 `x-q1` residual. The two raw stage streams remain separate
  64-bit PA/serializer branches; no lossy one-bit recombination is applied.
- Added the corresponding MATLAB fixed-point oracle, deterministic vector
  generator, XSim bit-true testbench, and ZU15EG routed OOC flow. The reset
  token and registered inter-stage handoff are explicit parts of the oracle.
- Checks: MATLAB-to-XSim PASS for 128 words / 4,096 I/Q samples with zero
  mismatches on both PA branches. Routed OOC on `xczu15eg-ffvb1156-2-i` at
  218.75 MHz PASS: WNS `+1.315 ns`, WHS `+0.029 ns`, TNS/THS `0`, estimated
  Fmax `307.08 MHz`; 14,276 LUT, 13,439 FF, 0 DSP, 0 BRAM.
- Regression checks: `run_xsim_p0_all.ps1` PASS, 7/7 tests at 65,536 samples;
  `run_xsim_ip_smoke.ps1` PASS.
- Limitation: this proves only fixed-point/RTL equivalence and fabric timing.
  The two PA branches are not yet connected to the dual-SFP GTH payload top,
  and no 256-QAM OFDM EVM/SNDR/ACLR qualification has been claimed.

## 2026-09-16 09:23 +08:00 - TID-MASH OFDM qualification failure

- Added a corrected OFDM-domain screen for the two-stage TID-MASH. It models
  the required MASH cancellation `y1 + y2 - z^-1 y2` as two 1-bit PA code
  planes with ideal 1:2 analog combining; direct equal-weight stage outputs
  are explicitly rejected as an invalid MASH realization.
- At 17.08984375 MHz occupied bandwidth and OSR 409.6, drive values
  `0.05/0.10/0.20/0.35` produced EVM `32.380/32.316/32.338/32.362 %` and
  SNDR `9.794/9.812/9.806/9.799 dB`. None meets the 256-QAM gates.
- Root cause: the current aligned `x-q1` inter-stage recurrence/cancellation
  does not have the required STF. This is algorithmic; routed TID timing and
  PA backoff cannot repair it. The prototype remains a functional/timing
  research baseline and is excluded from GTH payload integration.

## 2026-09-16 09:36 +08:00 - Three-level BP behavioral OFDM gate

- Extended `run_256qam_tid32_ofdm_demod.m` with a common OFDM/DDC receiver
  path for the fixed-point three-level BP-EFDSM2 and BP-EFDSM4 feasibility
  models. This is a scalar behavioral comparison only; it is not a TID RTL
  or serializer implementation.
- At 19.6533203125 MHz occupied bandwidth (OSR `356.17`), three-level
  BP-EFDSM2 measured EVM `1.5327 %`, SNDR `36.291 dB`, ACLR `-31.627 dBc`;
  BP-EFDSM4 measured EVM `1.5261 %`, SNDR `36.328 dB`, ACLR `-32.246 dBc`.
  Both pass the project 256-QAM EVM/SNDR gate in this ideal digital model.
- At 99.9755859375 MHz (OSR `70.017`), BP-EFDSM2 measured `2.2725 %` /
  `32.870 dB`, while BP-EFDSM4 measured `0.60936 %` / `44.302 dB`; both pass
  the same ideal-digital gate. At 999.755859375 MHz (OSR `7.0017`),
  BP-EFDSM4 fails: EVM `13.527 %`, SNDR `17.376 dB`.
- Consequence: three-level output is a credible bandwidth path, but it must
  first receive a derived scalar-vs-pipelined-TID state/output contract. No
  GTH, PA, or FPGA-ready claim follows from these behavioral results.

## 2026-09-16 10:32 +08:00 - Two-PA three-level Cartesian TID prototype

- Added `tid32_thermo3_fs4_multipa_tx`: two threshold-symmetric, `L=32`
  first-order Cartesian TID branches. The branches share acceptance and output
  readiness, so their 64-bit raw-GT words remain locked for two equal-weight
  1-bit serializer/PA paths. This is a thermometer-coded three-level TID
  implementation, not BP-EFDSM2/4.
- Added a MATLAB fixed-point transition/vector source, a 128-word two-branch
  XSim test, and a ZU15EG routed OOC flow. Checks: MATLAB-to-XSim PASS for
  128 words / 4,096 I/Q samples, zero bit mismatches on both raw streams and
  no valid-alignment failure.
- Routed OOC on `xczu15eg-ffvb1156-2-i` at 218.75 MHz PASS: WNS `+2.953 ns`,
  WHS `+0.033 ns`, TNS/THS `0`, estimated Fmax `617.88 MHz`; 11,170 LUT,
  10,732 FF, 0 BRAM, 0 DSP. Standard OOC clock-source/port warnings remain
  non-signoff limitations of OOC, not errors or critical warnings.
- The same RTL’s required regressions passed: P0 `7/7` (65,536 samples each)
  and IP smoke (top, AXI, active-reset, BP AXI, DPD v1.1).
- The ideal equal-weight combined OFDM model passes 256-QAM at actual
  19.6533203125 MHz / OSR `356.17`: EVM `1.5283 %`, SNDR `36.316 dB`, ACLR
  `-32.094 dBc`; at 99.9755859375 MHz / OSR `70.017`: EVM `1.0781 %`, SNDR
  `39.347 dB`, ACLR `-26.414 dBc`. A dual-SFP GTH payload target build,
  physical PA-combiner calibration, and board loopback/BERT are still open.

## 2026-09-16 10:54 +08:00 - Dual-SFP 14-Gb/s target closure

- Added `tid32_thermo3_gt14_dual_sfp_payload_top`: the two locked 64-bit
  thermometer code planes feed GTH `X1Y12` and `X1Y13`, sharing the 125-MHz
  reference, generated 218.75-MHz TXUSRCLK2, reset, and deterministic
  lane-distinct bring-up stimulus. This is a target-STA build, not an OFDM
  sample feeder.
- The first target build reproduced five hierarchy-specific clock-group
  critical warnings and was rejected. A payload-specific XDC with identical
  physical pins/primary clocks and no nonexistent TX/RX data crossing fixed it.
- Acceptance build `D:/TraeTemp/tid32_thermo3_gt14_dual_sfp_sta_20260916_104432/`
  produced the bitstream. Post-route STA: WNS `+0.324 ns`, WHS `+0.013 ns`,
  TNS/THS `0`; link, opt, place, phys-opt, route, and bitstream all reported
  0 critical warnings and 0 errors.
- Board loopback, physical two-PA equal-gain/phase alignment, BPF/DDC and RF
  EVM/SNDR/ACLR measurement remain required.

## 2026-09-16 - Repeatable OFDM bandwidth screen for thermo3 TID

- Ran the same ideal two-PA thermo3 TID receiver contract at 14 GS/s with
  `NFFT=16384`, `NCP=2048`, eight OFDM symbols, drive `0.35`, and five
  independent seeds (`11/29/47/71/101`).  The 229.86 MHz occupied point
  (OSR `30.454`) passed all five; the 234.99 MHz point (OSR `29.789`) also
  passed all five with EVM `3.188--3.246 %` and SNDR `29.772--29.930 dB`.
- At 237.55 MHz (OSR `29.468`) every completed seed failed the 256-QAM
  EVM/SNDR gate; 240 MHz showed mixed failures and 259.77 MHz failed all five.
  The highest repeatably tested passing point is therefore about 235 MHz;
  230 MHz is the current margin-bearing digital recommendation.  This is not
  an RF signoff because PA, clock/GT jitter, board loss, and physical filtering
  are not modeled.

## 2026-09-16 - Vector x4 interpolation and memory-DPD frontend

- Added a synthesizable ingress chain: eight complex samples per 218.75-MHz
  word, causal x2 polyphase interpolation, 16-lane shared-history 4-tap
  complex memory polynomial DPD, a second causal x2 stage, and the existing
  32-lane thermometer Cartesian TID output. The DPD supports Q1.15 complex
  coefficients for orders 1/3/5 and provides explicit cross-word tap windows.
- Added a matching fixed-point MATLAB vector generator and full-chain XSim.
  With nonzero test coefficients, 64 ingress words / 2,048 final complex
  samples produced zero mismatches on both PA raw bitstreams.
- Corrected `tid32_cartesian_fs4_gt_tx` valid handling: a bubble no longer
  repeats stale raw-GT data. Continuous raw-GT transmission remains a system
  contract; an upstream feeder FIFO must detect underflow rather than insert a
  bubble into a running RF stream.
- Checks passed: full-chain frontend XSim, P0 XSim `7/7`, IP smoke, and MATLAB
  P0 bit-true check. The ZU15EG frontend OOC has completed synthesis with zero
  errors/critical warnings and 2,064 DSP48E2; routed STA is still running, so
  no timing-closure claim is made in this entry.
- The first placed OOC result was not accepted: post-placement WNS was
  `-0.850 ns`. The four-tap DPD reduction is now a registered balanced tree;
  it preserves numerical results and adds one cycle of latency. The full-chain
  bit-true test, P0 `7/7`, and IP smoke were rerun successfully. A fresh OOC
  implementation is in progress; the interrupted prior run also reproduced a
  transient Vivado realtime-helper Tcl-file failure before HDL elaboration.

## 2026-09-16 - Frontend timing closure and RF-model boundary

- The revised `tid32_thermo3_frontend_tx_ooc` routed implementation on
  `xczu15eg-ffvb1156-2-i` now passes 218.75 MHz detailed STA: WNS `+0.255 ns`,
  WHS `+0.027 ns`, TNS/THS `0`. The implementation reported 0 errors and 0
  critical warnings. This closes the fabric OOC boundary only; it does not
  include GTH payload integration or board loopback.
- Added `run_tid32_thermo3_frontend_pa_dpd.m`, a behavioral endpoint scaffold
  for the exact `8 -> x2 -> 16-lane memory DPD -> x2 -> 32-lane thermo3 TID`
  path, two switching-PA paths, equal-weight combining, BPF/DDC, and Q2.14
  indirect-learning DPD fitting. Its first RF/DDC reconstruction fails its
  mandatory sanity check even with ideal PA paths. Consequently its present
  EVM/SNDR/ACLR values are not accepted as PA/DPD results: Fs/4 receiver
  phase, latency and reconstruction must first match the established digital
  TID receiver on the same raw-word vectors. An ideal brick-wall BPF also
  makes post-filter ACLR unsuitable as an ACLR claim.
- Re-ran the required MATLAB P0 fixed-point regression after adding the
  behavioral model: LPDSM, LPDSM2, EFDSM, EFDSM2, MASH11, MASH111 and MASH22
  each passed 65,536 samples with zero mismatches. The new RF model is outside
  that P0 scope and remains blocked by its independent receiver sanity check.
- Added a separately runnable raw-word gate to the same model. It decodes both
  generated 64-bit PA words into Cartesian I/Q and compares them with an
  independently stepped scalar thermo3 reference after the known 1,056-sample
  TID latency. The gate passed with 0 mismatches, which eliminates raw-word
  order, branch polarity, and TID latency as causes of the RF-model mismatch.

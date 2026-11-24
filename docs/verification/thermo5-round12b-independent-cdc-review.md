# Thermo5 Round 12b — Independent CDC/RDC Closure Review

Date: 2026-11-25. Status: **OPEN — review only**.

Scope: This note reviews the user-provided Round 12b status screenshots against the previously reported Round 9–12 baselines. The Round 12b local RTL, raw SpyGlass reports, VC Formal harnesses, and checkpoints are not available on this remote review branch. This commit does not import, reproduce, or sign off those RTL changes.

## Reported status

For each of EF1 and MASH: CDC errors 0; RDC errors/warnings 0/0; CDC warnings 21 (previously 19). The increase follows repair of a drain race using a four-phase request/acknowledge handshake. These are reported results, not independently rerun results.

| Warning category | Count per architecture | Review status |
|---|---:|---|
| Ac_datahold01a (9), Ac_cdc01a (1), Ac_conv02 (2) | 12 | Two F2 configuration-handshake proofs reported complete; ten AFIFO-related findings need product-depth proof |
| Ac_conv01/03 independent reconvergence | 4 | Review each consumer and independence invariant |
| Drain-related reconvergence | 2 | F3 safety proof reported; progress under traffic and integration remain open |
| Reset_sync04 | 3 | Confirm exact topology and reset semantics before disposition |
| Total | 21 | Native warnings remain present |

## P0: Preserve the reset architecture; audit its contract

Do not reopen already-clean RDC indiscriminately. Prove freeze-before-reset, freeze throughout reset and recovery, and release-before-unfreeze at every relevant destination, including memory write address and final enable. Audit assertion/deassertion timing and asynchronous boundary isolation. The reported design requires clocks to keep running during reset and changes external handshake invalidation to within three cycles; this is a product contract change, not automatic equivalence. Prove the reported clock-ratio requirements over all legal phases and reset arrival times, or replace fixed delays with explicit acknowledged sequencing. Cover short pulses, repeated reset, reset during stall, and clock interruption if supported. If not supported, specify the clock/reset requirements explicitly.

## P1: Close the AFIFO data-hold and Gray convergence findings

Depth-4 unbounded proofs and depth-16 bounded results (reported depth 219–220) are useful but not interchangeable. Prove at DATA_W=466, DEPTH=16 or provide a reviewed parametric/compositional proof. Separate pointer arithmetic, slot ownership, write publication/read acquisition, no overwrite before release, ordered watched transactions, arbitrary stable symbolic bit, stall stability, reset-epoch exclusion, and read-data capture. Check the correspondence between abstract metastability model and actual synchronizers. Model all permitted relative clock phases; do not assume away legal traffic or runtime reset. Analyze Gray bus max delay/skew and bundled-data capture timing in the physical flow. Use an exact tool-supported FIFO/handshake model only after validating its implementation contract; keep partially proved or failed native findings visible.

## P2: Reconvergence and drain

For each remaining independent convergence, identify both sources, synchronizer stages, destination function, and consumer; model independent old/new observations and check every reachable combination. Independence of sources alone does not establish safety. Prove cfg/RUN arbitration and data-version consistency; sticky error OR semantics including clear/ack; FIFO full arithmetic and wrap; datapath startup readiness. Keep the four-phase drain handshake, prove no stale acknowledgement, one completion per accepted stop request, no pending data at completion, and no lost accepted traffic during rapid RUN/STOP changes. Establish progress with explicit justified fairness (running clocks, downstream acceptance, and eventual upstream quiescence). Add non-vacuous traffic-to-drain-completion covers and reset in each handshake phase. A safety proof is not a liveness proof.

## P3: Reset_sync04 decision

Keep the unfiltered baseline. First inspect exact reported paths and distinguish actual cascaded reset synchronization from multiple data synchronizers sharing a reset. Reproduce the finding on minimal RTL; inspect the installed SpyGlass version's documentation for filter_reset_resync. A separately labelled diagnostic/filtered run may be compared, but no blanket filtering or change of signoff policy is approved by this note. If the three cases are demonstrated safe, record exact instances, clock/reset ownership, topology, assertion/release behavior, and review disposition. If raw-zero reports are mandatory, consider a targeted RTL change only after proving the full reset contract and re-running CDC/RDC and functional checks. Changing asynchronous reset to synchronous reset changes assertion semantics and may introduce RDC; do not convert all synchronizers merely to eliminate a diagnostic.

## P4: Acceptance gates

- Run EF1/MASH full ASIC product CDC and RDC on the exact final candidate; report all raw Errors, Warnings, Info, waived counts and analysis coverage. No unapproved suppression or blackboxes.
- Map every native finding to exact paths, properties, assumptions, proof results, physical timing, and reviewer disposition; distinguish bounded, proved, and justified.
- Resolve or explicitly scope the four pre-existing failing regressions. No new failures; full product reset/drain tests, scoreboard, assertions and coverage.
- Re-run FPGA XPM configuration, XSim or equivalent, implementation and timing/CDC audit; separately resolve previously missing 5-bit Gray group.
- Perform synthesis/PPA, reset recovery/removal and relevant timing constraints; no unapproved latency/throughput/clock-contract change.
- Freeze the reviewed source and evidence together only after all gates. Do not merge the candidate on the basis of this review note.

Suggested execution order: preserve Round 12b candidate; parallelize AFIFO proof decomposition and reconvergence/drain review; then resolve Reset_sync04 using exact path evidence; rerun all configurations and signoff gates. Target zero unresolved CDC/RDC risks, not zero native warning lines at the expense of correctness.

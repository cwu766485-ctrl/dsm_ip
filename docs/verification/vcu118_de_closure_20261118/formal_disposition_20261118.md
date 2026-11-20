# Independent-reset mailbox Formal disposition — 2026-11-18

Run: `runs/de_candidate3_independent_reset_formal_06/` (valid run log: `console_retry03.log`; property summary: `properties.txt`). Research branch HEAD at run start: `30ba6cb5ef53d0a9bed4889e1b0efdb881bdecef`.

## Result

**PASS for the scoped candidate mailbox block proof.** VC Formal V-2023.12-SP2 completed 17/17 assertions, 20/20 non-vacuity goals, and 6/6 covers. The seven lossless slices of the pending-bank atomicity assertion all proved. Covers reached AXI reset with pending data, Core reset with pending data, Core reset with held B response, configuration apply, a new request after reset, and a legal tap-count change. No assertion was weakened and no environment assumption was added for these cases.

The three AXI assumptions constrain AW, W, and AR stability while stalled. Reset starts from a formal POR and then AXI-Lite and Core resets assert independently. The clock model uses AXI-Lite 35 ns with phase `{0,17}` and Core 16 ns with phase `{5,13}`. These are deterministic digital clocks; they do not model metastability or every analog phase relationship.

## Source identities

- `research/vcu118_arch/formal_cfg_mailbox_candidate3_independent_v5.sv`: `2f875938a8f2726f6cecc3e622755b1be7c0736e71b9a59e162cb81c55f624ec`
- `research/vcu118_arch/formal_cfg_mailbox_candidate3_independent_v5.tcl`: `2f2eccd80e2576e1aea4f790b6516af119e6e1e838a6d0dec7f782cc5283f912`
- `research/vcu118_arch/thermo5_dpd_axi_lite_cfg_epoch_candidate3.sv`: `c3bab95709089a7d62db68640c52076d473704fca11c05dc57cb4729294b37a6`
- `rtl/axis/dsm_reset_sync.sv`: `106db4f838c8cc4274718c326c4637f149f41f473389b34bb034c58fe9b36e1f`

## Disposition and limits

The earlier v4 run (`runs/de_candidate3_independent_reset_formal_05/`) is diagnostic only: `MAX_TAPS=1` made its final three-bit atomicity slice constant and vacuous. It was stopped after the v5 model was ready; its partial logs are retained. Two v5 launch attempts without the interactive license environment are also retained as failed startup evidence; only retry 03 is the proof result.

This proof does not sign off the Runtime architecture mailbox, physical reset distribution, output PA mute, CDC metastability, Vivado/SpyGlass constraints, or routed timing. Product/System signoff remains OPEN.

## Runtime architecture mailbox follow-up

The independent-clock v6 harness extends the same candidate3 proof model with
architecture-mailbox hold/capture/pending assertions, abort when the AXI reset
epoch gate closes, reset-default checks, and a requirement that the Core
observe the request low after a reset epoch before a later architecture
commit. It also adds covers for Core and AXI-Lite reset while an architecture
request is pending and for a post-reset commit. The assertions add no new
environment assumptions and do not weaken the v5 properties.

Source: `research/vcu118_arch/formal_cfg_mailbox_candidate3_independent_v6.sv`
SHA-256 `df7e10c44394e38b76c82ef029122937e078fd74ada980752d6e345baa12d6e1`.
Harness SHA-256 `9a54ae3fed7f6a2351575c466731787ca5fcd81529ab2b775b39e74ae526d606`.
Run script:
`runs/de_candidate3_independent_reset_formal_07.sh`. Output directory is
`runs/de_candidate3_independent_reset_formal_07/` and will be created only if
absent; the script refuses to overwrite an existing run.
This v6 run is superseded by the v7 result below. The v6 source remains
preserved for diagnosis; its 2 inconclusive properties were not silently
relabelled as passes.

## Runtime architecture mailbox combined proof — 2026-11-19

**PASS for the scoped candidate3 independent-reset mailbox block.** Fresh
VC Formal v7 completed 25/25 assertions, 28/28 non-vacuity goals, and 11/11
covers. No environment assumption was added and no assertion was weakened.
The AXI request is sampled through the Core-domain synchronized request
(`arch_req_c2`); an additional property requires each request rise to follow an
accepted successful AXI-Lite architecture write. The source-domain abort
property separately requires request/busy/ack state to clear while the AXI
reset epoch gate is closed.

The v6 failure was a checker clocking bug: it sampled AXI-domain
`arch_req_q` directly on `core_clk`. A legal write accepted after the AXI
epoch reopened, while Core reset recovery was still in progress, was therefore
misclassified as stale by a Core-clock assertion. V7 checks the receiving
synchronizer output and ties request origin to the accepted AXI write; it does
not add a reset-order assumption. The previously failed v6 run remains intact
under `runs/de_candidate3_independent_reset_formal_08/`.

V7 artifacts are in `runs/de_candidate3_independent_reset_formal_09/`.
Sources: `research/vcu118_arch/formal_cfg_mailbox_candidate3_independent_v7.sv`
SHA-256 `d35ac5a2718ab4c5c9d30f8bfd06a63539984e37c6751cfb0263c645ae0281cd`;
Tcl SHA-256 `46c17359b646dc331ab309d036190a6b73da61b3d3a68575a32baa25f2a4a1e5`;
candidate3 DUT SHA-256 `c3bab95709089a7d62db68640c52076d473704fca11c05dc57cb4729294b37a6`.
Formal V-2023.12-SP2. The fixed-clock digital model uses AXI-Lite 35 ns,
phase `{0,17}`, and Core 16 ns, phase `{5,13}`. Assumptions are AW/W/AR
stability while stalled and formal POR only. This is not proof for arbitrary
analog phase/metastability, top-level CDC/RDC, physical reset distribution,
PA mute, or routed timing.

Reproduction:

```bash
wsl.exe -d Rocky-8.10 -- bash -ilc 'cd /mnt/e/workspace/chip/dsm_ip/runs/thermo5_vcu118_arch_research && bash runs/de_candidate3_independent_reset_formal_09.sh'
```

## Reproduction

From Windows with WSL Rocky-8.10 and the configured Synopsys license environment:

```bash
wsl.exe -d Rocky-8.10 -- bash -ilc 'export VC_STATIC_HOME=/opt/Synopsys/vc_formal/V-2023.12-SP2; cd /mnt/e/workspace/chip/dsm_ip/runs/thermo5_vcu118_arch_research && bash runs/de_candidate3_independent_reset_formal_06/run.sh'
```

The captured run used `runs/de_candidate3_independent_reset_formal_06/console_retry03.log`.

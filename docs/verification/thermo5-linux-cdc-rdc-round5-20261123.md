# Thermo5 CDC/RDC Round 5 — port model and reset probes

## Decision and source

**CDC, RDC, product reset formal and DE freeze remain OPEN.** With the license
available, the opt-in port model from `b9cc9ac` was run on both XPM products.
No product RTL or default configuration changed; no rule suppression,
quasi-static claim, vendor black box, or waiver was added. Raw run directories
and full logs are preserved at `runs/linux_cdc_rdc_round5/` in this worktree.

## Candidate port SGDC results

Each run used `compiletime_product_ports_candidate.sgdc`, SHA-256
`f3a154f03d665e5179e722c71674c258d28aa08fd73bb4ac242050fb9ebf4733`, and
`run_compiletime_spyglass.tcl`, SHA-256
`988ddb6e88597039832e8125c734da0f1406f81c8d35788bdb5327c9f56989a8`.
SpyGlass V-2023.12-SP1 emitted each of the 43 named data/control ports with
its proposed clock into the SGDC dump in all four runs; for example, both
224-bit I/Q ports and the 256 PA data bits expand in the EF1 CDC dump. This
establishes that the tool read the proposed associations, not that the parent
system has approved them or that its timing budgets are represented.

| XPM product | Goal | Fatals | Errors | Warnings | Waived |
| --- | --- | ---: | ---: | ---: | ---: |
| EF1 | CDC | 0 | 8 | 81 | 0 |
| MASH | CDC | 0 | 8 | 83 | 0 |
| EF1 | RDC | 0 | 4,417 | 74 | 0 |
| MASH | RDC | 0 | 5,125 | 76 | 0 |

Counts equal the original SGDC run, so adding the port model did not close
these crossings. Native IDs may change. The eight CDC errors remain three
`Ac_cdc01a`, three `Ac_conv02`, one `Ac_conv04`, one `Reset_sync02` per
architecture. EF1 CDC warnings include 53 `SYNTH_89`, 16 `SYNTH_5143`,
3 `WRN_1024`, 2 `SYNTH_12608`, 3 `Reset_sync04`, and four other CDC warnings;
MASH has one additional `SYNTH_5143` and one `SYNTH_5166`. Their presence is
not cleared by this run. `SYNTH_12608`, XPM Gray/FWFT timing, reset crossings
and all raw RDC paths require individual evidence and independent disposition.
The installed SpyGlass help identifies `gray_signals` as used by `Ac_conv05`;
it was not asserted as a shortcut for the current `Ac_conv02`/`Ac_conv04`.

## Configuration abort and XPM prefill reset

Two directed tests ran using VCS V-2023.12-SP1:

1. A local copy of `tb_cfg_common_reset_abort.sv` changed only testbench
   `ENABLE_RUNTIME_DSM(1)` to `(0)` for the compile-time configuration. It
   passed `COMMON_RESET_ABORT_RESTART_PASS`: a pending old coefficient was
   aborted on common reset and a new coefficient applied at a later boundary.
   This is one configuration-block scenario, not a full AXIS/PA proof.
2. `dv/verif/axis/tb_thermo5_xpm_prefill_reset.sv` instantiated the actual
   XPM wrapper at product data width 466, address width 4, and common reset.
   For four epochs it wrote eight words, held reads during prefill, checked
   that threshold `rd_count>=2` did not occur before two accepted fresh writes,
   drained with an ordering/data checker, and left two unread old words
   before resetting. It reported `XPM_PREFILL_RESET_PASS epochs=4
   checked_words=32 threshold_samples=60`. Three subsequent epochs check
   recovery from the earlier unread words. Data patterns exercise the low
   bits; this is not full payload-bit coverage, arbitrary clock phases,
   full-product epoch verification or a formal proof of conservative count.

The previously reported 32-bit FIFO probe is retained as earlier local run
`xpm_prefill/`; the quoted product-width result is `xpm_prefill_466/`.

## Reproduction

For EF1/MASH CDC/RDC run the command in the Round 4 report with `DSM_ARCH`
0/2, goals `cdc/cdc_verify` / `rdc/rdc_verify_struct` and four unique output
directories. Report and SGDC-dump contents, not process exit alone, determine
the result.

```sh
mkdir -p runs/NEW_CFG
sed 's/ENABLE_RUNTIME_DSM(1)/ENABLE_RUNTIME_DSM(0)/' \
  research/vcu118_arch/tb_cfg_common_reset_abort.sv > runs/NEW_CFG/tb.sv
(cd runs/NEW_CFG && \
  /opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -full64 -sverilog \
  -top tb_cfg_common_reset_abort ../../rtl/axis/dsm_reset_sync.sv \
  ../../rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv tb.sv -o simv && ./simv)

mkdir -p runs/NEW_XPM
/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -full64 -sverilog -timescale=1ns/1ps \
  -top tb_thermo5_xpm_prefill_reset -top glbl \
  rtl/axis/dsm_reset_sync.sv rtl/axis/dsm_xpm_async_fifo.sv \
  /mnt/d/AMDDesignTools/2026.1/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv \
  /mnt/d/AMDDesignTools/2026.1/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv \
  /mnt/d/AMDDesignTools/2026.1/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv \
  /mnt/d/AMDDesignTools/2026.1/data/verilog/src/glbl.v \
  dv/verif/axis/tb_thermo5_xpm_prefill_reset.sv \
  -Mdir="$PWD/runs/NEW_XPM/csrc" -o "$PWD/runs/NEW_XPM/simv"
(cd runs/NEW_XPM && ./simv)
```

## Evidence hashes

| Artifact | SHA-256 |
| --- | --- |
| EF1 CDC report | `b3c5a502bfaac314a8cc4b97ebff22f90407b850c290daca58982b5e16136dc0` |
| EF1 RDC report | `3ed7389063a17b192f01a91973ed162c62b4e3afe5a0413904a71516d22d33b2` |
| MASH CDC report | `43cc14c7a40ed8359a351dd8592791dc5d5d7dc47b90d4c771d8ee5344e9fa5c` |
| MASH RDC report | `7e790741a6afcf60c701fc4546dd26cf903762da69e20709d6db5eb3eeb14875` |
| Product-width XPM testbench | `d03ecc559131775a837f3499ddbfff6ee116e8c849a07a7ef986f7763bda47e1` |
| Product-width XPM test log | `77ef16eb4fe87f676c11b34b72becd6edc5b4c5531b9c43682f30d8ac303096b` |
| Config testbench copy | `04cb26448425a8ae1554c03f9b9a1e54061e36c37e674db9a36d5e4892a36bd8` |
| Config abort log | `d84eb511c9dc36df2bb3c117325f29508f3534951b2ac2c4ec4959cf1c3b5366` |


## Remaining work

Prove or otherwise independently disposition each original XPM Gray and reset
crossing, including physical bus skew and the actual prefill contract. Prove
post-reset payload and metadata provenance, not only valid bits, across DPD,
FIFO, frame/elastic and backend; resolve formal setup warnings; complete
product abort/backpressure and long-flow regression, and audit final parent
and routed timing. The current directed tests and candidate SGDC do not justify
marking any remaining CDC/RDC errors closed.

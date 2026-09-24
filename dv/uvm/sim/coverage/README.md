# Frozen-SKU URG Exclusions

This directory contains the generator for reviewed, configuration-specific URG
exclusions. It must never contain a hand-written or stale `.elfile`.

The output format is tied to the VCS/URG database checksum and elaborated
instance path. Generate it from the exact VDB used by the intended merge:

```bash
cd <repository-root>
mkdir -p dv/uvm/sim/out/vcs/coverage/exclusions
urg -full64 -dir dv/uvm/sim/out/vcs/simv.vdb -metric line \
  -dump full_exclusions \
  -report dv/uvm/sim/out/vcs/coverage/exclusion_template
bash dv/uvm/sim/coverage/generate_frozen_sku_elfile.sh \
  dv/uvm/sim/out/vcs/coverage/exclusion_template/fullexclude.line \
  dv/uvm/sim/out/vcs/coverage/exclusions/frozen_performance_sku.line.elfile
```

The generator emits only reviewed, instance-scoped line exclusions:

- `FSKU-001`: the BP one-bit RF path cannot produce signed `-32768`.
- `FSKU-006` through `FSKU-009`: in the frozen x32 interpolation build, the
  two symmetric FIR specializations cannot select their unused coefficient
  table or mirrored coefficient-table entries.

The authoritative rationale is
`docs/evidence/FROZEN_SKU_COVERAGE_WAIVERS.csv`.  In the 300-run frozen-SKU
VDB reviewed on 2026-08-21, this file enables 287 line exclusions.  It changes
the reviewed line metric only; condition, toggle, branch, and assertion bins
still require a legal test, a separate proof, or their own reviewed waiver.

Do not add FSKU-004 (`abs_s32`), FSKU-005 active residual paths, or FSKU-010
memory-DPD pipeline flow control. They require legal tests or a proof, not an
exclusion. `FSKU-002/003` are feature-pruned in this elaborated VDB, so their
child execution bins do not exist in the VDB being reviewed.

Pass a generated file to a merge explicitly:

```bash
make -C dv/uvm/sim coverage-merge RUN_TAGS="$tags" \
  URG_ELFILE=dv/uvm/sim/out/vcs/coverage/exclusions/frozen_performance_sku.line.elfile
```

For the standard frozen-SKU review, use the wrapper rather than manually
reusing an old exclusion file:

```bash
cd <repository-root>
bash dv/uvm/sim/coverage/run_frozen_sku_coverage_triage_linux.sh
```

It rebuilds the URG template, regenerates the checksum-correct exclusion file,
and writes the reviewed report below `dv/uvm/sim/out/vcs/coverage_triage/`.

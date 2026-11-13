# Thermo5 RDC Root Closure

Date: 2026-11-13. Status: `NOT_CLOSED; SIGNOFF_OPEN`.

Reference PR #62 HEAD: `ac08611af825586dc378041d2568eb7ee1ea563c`. Candidate
branch `task/thermo5-cdc-quantified-research`, HEAD
`3b60f37929c23d014ab533ba80099e02f67c3e8d`. Candidate report:
`runs/cdc_quant_research/spyglass_rdc_v2/moresimple.rpt`; previous root inventory
and native report are under `docs/verification/data/thermo5-cdc-rootfix/`.

| Run | Ar_resetcross01 records | Errors | Warnings | Infos | Root groups |
|---|---:|---:|---:|---:|---:|
| Previous ECO report | 10,519 | 10,506 | 15 | 70 | 104 |
| Candidate RDC v2 | 10,549 | 10,539 | 15 | 67 | Not regrouped |
| Delta | +30 | +33 | 0 | -3 | OPEN |

Candidate RDC has more errors and native reset-cross records. Old normalized
root totals cannot be reused as candidate closure. No waiver is approved and
no global rule is disabled. A fresh grouping of all 10,549 candidate records
is required.

| Root class | Previous record count | Candidate disposition |
|---|---:|---|
| Elastic buffer storage/control | 7,576 | OPEN; selected two-slot proof does not cover every product instance or downstream data dependency |
| DPD pipeline/history | 2,680 | OPEN; local invalid/epoch lemmas do not prove every history/memory path |
| Frame Gain | 149 | OPEN; selected FIFO metadata/operand composition only |
| Async FIFO | 98 | OPEN; epoch initialization and live-reset recovery remain INCONCLUSIVE |
| Config/control/top | 16 | OPEN; no complete reset recovery mapping |

The counts above are from the previous 104-group inventory and are not a
candidate exact grouping after its +30 native records.

## Reset contract

The selected integration contract is common asynchronous reset assertion to
all three clock domains, followed by each domain's own-clock synchronized
release. Runtime independent reset is unsupported; release edges are not
assumed simultaneous. The SoC/FPGA parent must provide an executable assertion
that common assertion reaches each reset input, verify behavior while any
clock is stopped, and check cross-domain release skew. The checked reset
contract test covers selected common-assert/local-release cases, but does not
replace parent-level integration evidence or physical metastability/MTBF
analysis.

## Evidence and remaining risk

- Async FIFO Formal proves read/write Gray and no push/pop during reset;
  initialized-before-read epoch and live-reset recovery remain INCONCLUSIVE.
- Generic FIFO skew simulation covers six epochs, both release orders and 384
  fresh words without old-epoch observations. This is bounded simulation.
- Elastic FIFO Formal covers one selected two-slot instance, not all product
  specializations or all paths represented by 7,576 old records.
- DPD and Gain proofs cover selected local token/valid/operand properties,
  not every reset-crossing record.

No Formal Inconclusive is counted as PASS. No candidate RDC root is closed.
Closure requires path-level mapping, proof or reviewed waiver for every root,
and parent reset evidence including stopped-clock behavior.

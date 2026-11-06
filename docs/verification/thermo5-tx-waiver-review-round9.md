# Thermo5 TX Waiver Candidate Audit — Round 9

Date: 2026-11-04<br>
Product RTL SHA: `1236d49c72360aa62e316aea147528d93a1b3705`<br>
Product configuration: Centered-Cubic x2+x2; EF2 ORDER=2 / STEP=5120 / 20-bit state; DPD_MAX_TAPS=1 Identity reset image; AXI-Lite; Generic FIFO.

## Audit result

The fail-closed candidate audit rebound all 371 legacy candidate rows to the current source-linked Raw ledger, compile manifest, VDB manifest, and Raw/Adjusted report manifest. It classified 361 rows as `CONFIG_UNREACHABLE` and 10 as `FORMAL_UNREACHABLE`. These are candidate classifications only. All rows remain `PENDING`; approved=0, rejected=0, and active URG exclusions=0.

The audit did not change Raw bin status, coverage denominator, or functional behavior. The generated `.el` contains no active directives. Current code gaps remain OPEN and Raw equals Adjusted.

## Bound evidence

| Artifact | SHA-256 |
|---|---|
| Current product compile manifest | `36aacf88fa95269728eded27bc48e314c8e55877920379f70da00116b9a40d42` |
| Raw open-bin ledger | `11d16d1f1a942d19889a0130f8967867543c50b08a0e9b210d7e24f9d7ce7fab` |
| Candidate-audit Raw/Adjusted report manifest | `63b84c61804ed4ad40f75a37d017fad38498f34a17e28b02601df78321f3a8e1` |
| Final tracked-CSV Raw/Adjusted report manifest | `42861c12102b9cdd55cc51d8aed9a96ef9a70439839cc2e07434015def1fcf6a` |
| Ordered VDB manifest | `81d1c0c64441c366795c415a91f4405a8bbe190033550805baafbc1076749fe6` |
| Candidate audit JSON | `9716b1027b4b3851c7c88b7c7edfe53cef9cca4d24864323f700c18cc20906fe` |
| Tracked waiver CSV | `abd8a9b83440af5f27d2a2b22bff2fc170368c76697d0866fb06af1687e66830` |
| Fail-closed pipeline audit | `9246da2f9b5e4576ec74239c01acad14d261d04709f5b0d199f16db7bc65bc78` |
| Generated no-directive `.el` | `57d1f80c4862394d1a6e0fb0c12ed1ba57543d3b8e6d1ab8e9dfc452cc78c858` |

The detailed candidate records and Formal snapshots are in [`data/thermo5-tx-waiver-review-round9/`](data/thermo5-tx-waiver-review-round9/). Full URG and VDB payloads remain in the ignored local `runs/` tree; the current Linux signoff index records their exact paths and hashes.

## Reproduction

The exact audit and pipeline commands are recorded in [`thermo5-tx-linux-signoff-round9-20261104.json`](data/thermo5-tx-linux-signoff-round9-20261104.json) under `waiver_commands`. They can be rerun with Python 3.12.13 from the repository root. The pipeline passed after validating every CSV row against the same current Raw ledger and current compile configuration.

No candidate was independently approved in this round. A future reviewer must record a valid reviewer and approval reference before a candidate can produce an active `.el` exclusion.

# Round 21 AXI-Lite address-return coverage closure

Eight previously missing exact Toggle bins are hit by one legal protocol test.
The earlier register test ended its writes at address 0x82, leaving address
bits 7 and 1 high. The focused test now writes 0x83 (checked DECERR) followed
by CONTROL=0 at 0x00 (checked OKAY). W is delayed two cycles so AW is captured
in awaddr_q before the write. Error responses are expected register-map
responses, not expected assertion failures.

The changes are confined to the register-access UVM test and the optional
VCD hook (adding u_cfg). All frozen product RTL hashes match. No parameter,
force, deposit, assertion or official exclusion changed.

The exact IDs, instances, bit directions and source hashes are in
[data/thermo5-r21/address_return/exact_hits.json](data/thermo5-r21/address_return/exact_hits.json).
The six configuration-instance bins are write_addr[1/7], awaddr_q[1/7] and
s_axil_awaddr[1/7], all 1_to_0. Two corresponding wrapper-port bins also hit.
VCD shows port/write_addr falls at 5,010,000 ps and awaddr_q at 5,015,000 ps.
All transactions use public AXI-Lite handshakes and checked responses. The
independent AXI-Lite monitor/predictor ran; no datapath stream was launched.

| Metric | Incremental Raw / zero-approved Adjusted | Analysis-only What-if |
| --- | --- | --- |
| Branch | 524/637 | 524/529 |
| Condition | 662/849 | 662/741 |
| Line | 3338/3796 | 3338/3363 |
| Toggle | 92640/104480 | 92640/93710 |

Actual delta: +8 Toggle, zero other metrics. What-if OPEN=1,179 (249 non-counter
and 930 counters). Raw OPEN=12,598. Approved exclusions/exceptions remain zero.
The frozen homogeneous 584-Test report remains a historical baseline; this
incremental report combines that aggregate with one newly compiled DV test.
All three reports use identical inputs. URG logs contain no warning/error or
mapping/checksum diagnostics. This is verified incremental closure; a unified
compile and necessary replay are still required before final signoff.

Checks run: VCS full64 compile PASS; focused register-access simulation PASS,
UVM_ERROR=0/UVM_FATAL=0; standalone exact URG comparison PASS; VCD edge check
PASS; incremental Raw/Approved Adjusted/What-if URG PASS; git diff --check PASS.
The first standalone URG invocation omitted the Design VDB and emitted
UCAPI-DNYL; it was discarded and rerun with the matching Design VDB. Full
regression and Formal were not rerun for this DV-only change.

Evidence hashes, commands, summaries and the updated 249-bin ledger are under
[data/thermo5-r21/address_return/](data/thermo5-r21/address_return/).
Code Coverage and Full Linux DV signoff remain OPEN. Next prioritize the
138 interpolator bins with a proven legal single-entry replacement schedule;
no further random seed expansion is justified by this result.

#!/usr/bin/env python3
"""Retain every native error and attach debug obligations, never waive them."""
import csv, gzip, hashlib, json
from collections import Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/verification/data/thermo5-cdc-error-debug'
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
 OUT.mkdir(parents=True,exist_ok=True)
 source=ROOT/'docs/verification/data/thermo5-cdc-phase2/static_messages.csv.gz'
 rows=[]
 for row in csv.DictReader(gzip.open(source,'rt')):
  if row['severity']!='Error': continue
  if row['goal']=='cdc':
   group='COMBINATIONAL_CDC_SOURCE'; obligation='Source-register ECO or path-specific physical/temporal safety proof; prefill delay-sensitivity reproduced'
  elif 'cfg_mailbox_q' in row['source']:
   group='MAILBOX_RESET_EPOCH'; obligation='Review common-epoch contract and bundled-data reset timing; independent AXIL reset split reproduced'
  elif 'dsm_async_fifo.sv' in row['source_file']:
   group='ASYNC_FIFO_UNRESET_PAYLOAD'; obligation='Common epoch, pointer visibility, write-before-read and reset recovery/removal'
  elif 'tid32_thermo5_frontend_tx.sv' in row['source_file']:
   group='ELASTIC_FIFO_UNRESET_PAYLOAD'; obligation='Local ownership proof plus consumer/reset timing composition; no blanket waiver'
  elif 'dpd_memory_poly.v' in row['source_file']:
   group='DPD_UNRESET_PIPELINE'; obligation='Valid/tap-enable initialization and stalled reset composition including physical reset timing'
  else:
   assert row['source_file'].endswith('dsm_frame_gain_vector.sv'),row
   group='GAIN_UNRESET_PIPELINE'; obligation='Valid-gated payload initialization and downstream reset timing composition'
  row.update(root_cause_group=group,blocking_obligation=obligation,disposition='OPEN_NO_APPROVAL')
  rows.append(row)
 assert len(rows)==10511
 with gzip.open(OUT/'native_error_obligations.csv.gz','wt',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
 run=ROOT/'runs/cdc_error_debug'; evidence={}
 for name in ['hazard/compile.log','hazard/test.log','hazard/prefill_hazard.vcd','mailbox/compile.log','mailbox/test.log','mailbox/mailbox_reset.vcd','ownership/console.log','ownership/properties.txt','ownership/setup.txt','ownership/engines.txt','ownership_bit/console.log','ownership_bit/properties.txt','ownership_bit/setup.txt','ownership_bit/engines.txt']:
  p=run/name
  if p.exists():
   evidence[name]=dict(sha256=digest(p),bytes=p.stat().st_size)
   if p.suffix == '.txt':
    (OUT/name.replace('/','_')).write_text('\n'.join(line.rstrip() for line in p.read_text().splitlines()).rstrip()+'\n')
 sources=['rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv','rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv','rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv','dv/uvm/formal/thermo5_fifo_reset_ownership_harness.sv','dv/uvm/formal/run_thermo5_fifo_reset_ownership.tcl','dv/verif/cdc/tb_thermo5_prefill_cdc_hazard.sv','dv/verif/cdc/tb_thermo5_mailbox_reset_contract.sv']
 result=dict(source_hashes={p:digest(ROOT/p) for p in sources},input_sha256=digest(source),groups=dict(Counter(r['root_cause_group'] for r in rows)),native_errors=len(rows),approved=0,waived=0,product_rtl_modified=False,evidence=evidence)
 (OUT/'manifest.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps(result['groups'],indent=2))
if __name__=='__main__':main()

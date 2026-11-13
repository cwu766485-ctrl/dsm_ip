#!/usr/bin/env python3.12
import argparse,csv,gzip,hashlib,json,re,shlex
import xml.etree.ElementTree as ET
from pathlib import Path
from collections import Counter,defaultdict
ROOT=Path(__file__).resolve().parents[2]

def read_csv(p):
    if str(p).endswith('.gz'):
      with gzip.open(p,'rt',newline='') as f:return list(csv.DictReader(f))
    with open(p,newline='') as f:return list(csv.DictReader(f))

def main():
 p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=True)
 rem=read_csv(ROOT/'docs/verification/data/thermo5-pr55-application/remaining54.csv')
 bindings={}
 for label in ('dpd-ready-condition','cdc-data-empty'):
  path=ROOT/f'docs/verification/data/thermo5-tx-{label}-formal-20261103.json'
  d=json.loads(path.read_text()); hashes=d.get('source',{}).get('source_sha256') or d['formal']['compiled_source_sha256']
  checks={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in hashes.items()}
  bindings[label]={'record':str(path.relative_to(ROOT)),'record_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source_matches':checks,'proof':d['formal'],'fresh_run':False}
 assert all(bindings['dpd-ready-condition']['source_matches'].values()), 'DPD proof source drift'
 assert all(v for p,v in bindings['cdc-data-empty']['source_matches'].items() if p.startswith('rtl/') or p.endswith('harness.sv')), 'CDC RTL/harness drift'
 bindings['cdc-data-empty']['runner_drift']='Only report_fml_engines -no_summary removed; historical proof is not a new run. Clock-sampled proof does not settle event/delta coverage.'
 (a.out/'formal_reuse_binding.json').write_text(json.dumps(bindings,indent=2)+'\n')
 open87=read_csv(ROOT/'docs/verification/data/thermo5-rtl-invariants/open87_review.csv')
 byid={r['semantic_bin_id']:r for r in open87}
 supplement={r['semantic_bin_id']:r for r in read_csv(a.out/'supplemental_review6.csv')}
 rows=[]
 for r in rem:
  sid=r['source_bin_id'];src=byid.get(r['source_bin_id']) or next((x for x in open87 if x['semantic_bin_id']==r.get('semantic_bin_id')),None)
  inst=r['instance'];loc=r['source_location'];metric=r['metric'];state='UNRESOLVED';action='KEEP_OPEN';evidence=''
  if 'u_memory_dpd' in inst:
   state='PROVEN_UNREACHABLE';action='EXACT_REVIEW_PENDING';evidence='Existing source-bound a_empty_output_allows_input PROVEN/nonvacuous and c_line93_uncovered_tuple UNCOVERABLE; same MAX_TAPS=1, LANES=16. Procedural line93 evaluated only on active clock outside reset. Payload-hold property remains INCONCLUSIVE. No approval or exclusion applied.'
  elif 'u_cdc' in inst and ('113:' in loc):
   state='UNRESOLVED';action='FORMAL_OR_EVENT_ANALYSIS';evidence='Existing Generic FIFO proof has3 PROVEN assertions/3 positive covers/target UNCOVERABLE at clock sampling; RTL/harness hashes match. Continuous URG expression event/delta scope remains unresolved; no full-bin exclusion inferred.'
  elif 'u_cfg' in inst:
   state='UNRESOLVED';action='DIRECTED_COMMIT_TIMING';evidence='Request/pending/boundary synchronizer tuple requires four-phase mailbox timing; prior boundary COMMIT hit was different tuple.'
  elif 'u_frame_gain' in inst:
   state='UNRESOLVED';action='PREDECESSOR_ANALYSIS';evidence='Valid masks metadata update; stale FIFO metadata while empty remains possible only under timing context.'
  elif 'u_interp_' in inst:
   state='UNRESOLVED';action='QUEUE_RESET_EVENT_ANALYSIS';evidence='q_count/q0/q1 metadata and async reset predecessor required; prior ready-tail reset had URG delta0.'
  elif metric in ('toggle','branch') and inst.endswith('.dut'):
   state='UNRESOLVED';action='WEIGHTED_TOKEN_PROOF_OR_WITNESS';evidence='Weighted model conditional capacity28; full RTL refinement OPEN, no exclusion from max28 observation.'
  elif 'u_frontend' in inst:
   state='UNRESOLVED';action='LEGAL_SIDE_BAND_ANALYSIS';evidence='Frontend metadata/constant paths require exact consumer and valid context.'
  if r['semantic_bin_id'] in supplement:
   state='PROVEN_UNREACHABLE';action='EXACT_REVIEW_PENDING';evidence=supplement[r['semantic_bin_id']]['root_cause_group']+'; '+supplement[r['semantic_bin_id']]['scope']
  rows.append({**r,'v2_status':state,'v2_action':action,'v2_evidence':evidence,'v2_formal_or_vcs_witness':('docs/verification/data/thermo5-tx-dpd-ready-condition-formal-20261103.json' if 'u_memory_dpd' in inst else 'docs/verification/data/thermo5-tx-cdc-data-empty-formal-20261103.json' if 'u_cdc' in inst and '113:' in loc else 'docs/verification/data/thermo5-pr55-application/v2/new_formal_results.json' if r['semantic_bin_id'] in supplement else 'NONE'),'v2_current_product_sha':'635be681046b3ab7d6fdda7f4e9818d7226efd66','v2_actual_urg_delta':'0','v2_approval':'PENDING'})
 # Preserve the33 already reviewed technical candidates, without reclassification.
 for r in open87:
  if r['semantic_bin_id'] not in {x['semantic_bin_id'] for x in rows}:
   rows.append({**r,'v2_status':'CONFIG_UNREACHABLE','v2_action':'EXISTING_REVIEW_PENDING',
                'v2_evidence':r['rtl_evidence'],'v2_formal_or_vcs_witness':'docs/verification/thermo5-pr55-exclusion-decision.md',
                'v2_actual_urg_delta':'0','v2_approval':'PENDING','v2_current_product_sha':'635be681046b3ab7d6fdda7f4e9818d7226efd66'})
 fields=list(dict.fromkeys(k for r in rows for k in r))
 with (a.out/'coverage_exact_triage_v2.csv').open('w',newline='') as f:
  w=csv.DictWriter(f,fields,lineterminator="\n");w.writeheader();w.writerows(rows)
 # Parse actual log messages; report-count summaries are not event evidence.
 replay=json.loads((ROOT/'runs/rtl_invariants/replay_results.json').read_text())
 inv=[];audits=[]
 def inventory(x):
  log=Path(x['log']); text=log.read_text(); digest=hashlib.sha256(log.read_bytes()).hexdigest()
  if x.get('log_sha256'):assert digest==x['log_sha256'], 'Replay log drift'
  assert re.search(r'UVM_ERROR\s*:\s*0',text) and re.search(r'UVM_FATAL\s*:\s*0',text) and '[SKU_PASS]' in text, 'Missing UVM success evidence'
  if not x['negative']:assert not re.search(r'^Error:',text,re.M), 'Unexpected legal assertion error'
  records=[]
  for line in text.splitlines():
   if '[PACKET_CROSS_AUDIT] epoch=' in line:
    r=dict(re.findall(r'(\w+)=(\w+)',line));r['scenario_id']=x['index'];records.append(r);audits.append(r)
  checked=[r for r in records if r.get('integrity')=='PASS']
  def hit(*names):return sum(all(r.get(k)=='1' for k in names) for r in checked)
  trace=next((v.split('=',1)[1] for v in x.get('argv',[]) if v.startswith('+THERMO5_TRACE_JSONL=')),'')
  passes=[line.split('[SKU_PASS]',1)[1].strip() for line in text.splitlines() if '[SKU_PASS]' in line and 'UVM_INFO' in line]
  return {'scenario_id':x['index'],'test':x['test'],'negative':x['negative'],'status':x['status'],
   'stimulus':';'.join(x.get('argv',[])[1:]),'checker_observed_pass_message':' | '.join(passes),
   'checker_scope':'UVM scenario checks; Python CDC/EF2/PA trace check only if separately recorded',
   'event_trace':trace,'coverage_vdb':x['vdb'],'evidence':str(log),'log_sha256':digest,
   'packet_epoch_audit_records':len(checked),'gap_fifo_pa_same_packet':hit('source_gap','fifo_full','pa_stall'),
   'run_prefill_gap_same_packet':hit('run','prefill','gap_after_run'),
   'stop_tlast_drain_ordered_same_packet':hit('stop_before_tlast','tlast_after_stop','drain_after_tlast'),
   'missing_cross_evidence':'NOT_INSTRUMENTED_OR_NOT_HIT; never inferred from test name'}
 for x in replay:inv.append(inventory(x))
 for i,name,folder in [(586,'boundary_commit','boundary_commit'),(587,'stalled_reset','stalled_reset3'),(588,'ready_tail_reset','ready_tail3')]:
  log=ROOT/'runs/rtl_invariants'/folder/'test.log'
  info=list(log.with_suffix('.vdb').glob('**/siminfo.xml'));assert len(info)==1
  raw=info[0].read_bytes();raw=gzip.decompress(raw) if raw.startswith(b'\x1f\x8b') else raw
  argv=shlex.split(ET.fromstring(raw).find('srctest').attrib['cmdline'])
  inv.append(inventory(dict(index=i,test=name,negative=False,status='PASS',log=str(log),vdb=str(log.with_suffix('.vdb')),argv=argv)))
 directed=ROOT/'runs/dv_convergence_v2/nonidentity_commit_stall/result.json'
 if directed.exists():inv.append(inventory(json.loads(directed.read_text())))
 with (a.out/'system_scenario_inventory_v2.csv').open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(inv[0]),lineterminator="\n");w.writeheader();w.writerows(inv)
 (a.out/'packet_epoch_cross_evidence.json').write_text(json.dumps(audits,indent=2)+'\n')
 m={'remaining54':len(rem),'reviewed87':len(rows),'states':Counter(x['v2_status'] for x in rows),'scenarios':len(inv),'observed_same_packet_cross':{k:sum(r[k] for r in inv) for k in ('gap_fifo_pa_same_packet','run_prefill_gap_same_packet','stop_tlast_drain_ordered_same_packet')},'scenario_pass':sum(x['status']=='PASS' for x in inv),'product_sha':'635be681046b3ab7d6fdda7f4e9818d7226efd66','counter_930_separate':True,'approved':0,'new_hit':0,'actual_urg_delta':0}
 m.update({'pending_exclusion_candidates':11599,'existing_candidates':11593,'new_technical_candidates_pending':6,'formal_new_assertions_proven_nonvacuous':5,'formal_new_exact_covers_uncoverable':5,'new_verified_cross_windows':1,'official_remaining_open':12577,'counter930':'OPEN;no accepted product-scope decision','product_compile_parent_sha256':'421a36094a493a2345eff8f165a44197bff12bbcf32a09963a61628353bf599e'})
 for name,src in [('vdb_manifest_590.json','runs/dv_convergence_v2/vdb_manifest.json'),('directed_cross_witness.json','runs/dv_convergence_v2/nonidentity_commit_stall/cross_witness.json'),('urg_checks.json','runs/dv_convergence_v2/urg_checks.json'),('coverage_summaries_590.json','runs/dv_convergence_v2/coverage_summaries.json')]:
  (a.out/name).write_bytes((ROOT/src).read_bytes())
 m['evidence_sha256']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in a.out.iterdir() if p.is_file() and p.name!='triage_manifest.json'}
 (a.out/'triage_manifest.json').write_text(json.dumps(m,indent=2)+'\n');print(m)
if __name__=='__main__':main()

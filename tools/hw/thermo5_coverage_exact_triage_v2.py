#!/usr/bin/env python3.12
import argparse,csv,gzip,hashlib,json
from pathlib import Path
from collections import Counter,defaultdict
ROOT=Path(__file__).resolve().parents[2]

def read_csv(p):
    if str(p).endswith('.gz'):
      with gzip.open(p,'rt',newline='') as f:return list(csv.DictReader(f))
    with open(p,newline='') as f:return list(csv.DictReader(f))

def main():
 p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
 rem=read_csv(ROOT/'docs/verification/data/thermo5-pr55-application/remaining54.csv')
 open87=read_csv(ROOT/'docs/verification/data/thermo5-rtl-invariants/open87_review.csv')
 byid={r['semantic_bin_id']:r for r in open87}
 rows=[]
 for r in rem:
  sid=r['source_bin_id'];src=byid.get(r['source_bin_id']) or next((x for x in open87 if x['semantic_bin_id']==r.get('semantic_bin_id')),None)
  inst=r['instance'];loc=r['source_location'];metric=r['metric'];state='UNRESOLVED';action='KEEP_OPEN';evidence=''
  if 'u_memory_dpd' in inst:
   state='UNRESOLVED';action='REUSE_FORMAL_NO_REPEAT';evidence='Existing vector-ready Formal target line93 remains exact; no prior PASS for target tuple.'
  elif 'u_cdc' in inst and ('113:' in loc):
   state='UNRESOLVED';action='FORMAL_OR_EVENT_ANALYSIS';evidence='Generic FIFO empty/valid invariant harness exists; exact raw tuple with empty and valid is contradictory in settled RTL but delta-cycle proof pending.'
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
  rows.append({**r,'v2_status':state,'v2_action':action,'v2_evidence':evidence,'v2_formal_or_vcs_witness':'NONE','v2_actual_urg_delta':'0','v2_approval':'PENDING'})
 fields=list(rows[0]);(a.out/'coverage_exact_triage_v2.csv').open('w',newline='').write('')
 with (a.out/'coverage_exact_triage_v2.csv').open('w',newline='') as f:w=csv.DictWriter(f,fields);w.writeheader();w.writerows(rows)
 # Scenario inventory from the verified replay result plus three focused scenarios.
 replay=json.loads((ROOT/'runs/rtl_invariants/replay_results.json').read_text())
 inv=[]
 for x in replay:
  inv.append({'scenario_id':x['index'],'test':x['test'],'negative':x['negative'],'status':x['status'],'stimulus':';'.join(x['argv'][1:]),'event_witness':'trace_jsonl' if '+THERMO5_TRACE_JSONL' in ' '.join(x['argv']) else 'VDB','checker':'UVM/bit-true scoreboard','coverage_vdb':x['vdb'],'evidence':'runs/rtl_invariants/replay/'+Path(x['vdb']).stem+'.log'})
 for i,name,log,vdb in [(586,'boundary_commit','runs/rtl_invariants/boundary_commit/test.log','runs/rtl_invariants/boundary_commit/test.vdb'),(587,'stalled_reset','runs/rtl_invariants/stalled_reset3/test.log','runs/rtl_invariants/stalled_reset3/test.vdb'),(588,'ready_tail_reset','runs/rtl_invariants/ready_tail3/test.log','runs/rtl_invariants/ready_tail3/test.vdb')]:inv.append({'scenario_id':i,'test':name,'negative':False,'status':'PASS','stimulus':'public legal directed','event_witness':'VCD','checker':'four-plane independent bit-true oracle','coverage_vdb':vdb,'evidence':log})
 with (a.out/'system_scenario_inventory_v2.csv').open('w',newline='') as f:w=csv.DictWriter(f,fieldnames=list(inv[0]));w.writeheader();w.writerows(inv)
 m={'remaining54':len(rows),'states':Counter(x['v2_status'] for x in rows),'scenarios':len(inv),'scenario_pass':sum(x['status']=='PASS' for x in inv),'product_sha':'635be681046b3ab7d6fdda7f4e9818d7226efd66','counter_930_separate':True,'approved':0,'new_hit':0,'actual_urg_delta':0};(a.out/'triage_manifest.json').write_text(json.dumps(m,indent=2)+'\n');print(m)
if __name__=='__main__':main()

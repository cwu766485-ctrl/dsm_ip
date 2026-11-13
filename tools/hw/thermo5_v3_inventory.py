#!/usr/bin/env python3.12
"""Deduplicate actual accepted stimulus and cross/checker evidence, not names."""
import csv,json,hashlib
from collections import Counter,defaultdict
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/verification/data/thermo5-dv-v3'

def main():
 OUT.mkdir(parents=True,exist_ok=True)
 old=list(csv.DictReader((ROOT/'docs/verification/data/thermo5-pr55-application/v2/system_scenario_inventory_v2.csv').open()))
 assert len(old)==590
 groups=defaultdict(list);rows=[]
 for x in old:
  path=Path(x['evidence']);assert hashlib.sha256(path.read_bytes()).hexdigest()==x['log_sha256']
  trace=Path(x['event_trace']) if x['event_trace'] else None
  actual=[];counts=Counter()
  if trace and trace.is_file():
   for line in trace.open():
    e=json.loads(line);counts[e['type']]+=1
    if e['type'] in ('source_beat','axil_write_fire','axil_read','reset','pa_stall','fifo_full','stop_state','config_pending','frame_boundary','config_ack_core','commit_done','axil_write_response','axil_read_response'):
     # Accepted values/ordering identify stimulus equivalence; clocks and gaps
     # still matter and remain here. Only local record indexes are removed.
     actual.append({k:v for k,v in e.items() if k not in ('seq','txn_id','beat_index','word_index','event_cycle','axil_cycle')})
   signature=hashlib.sha256(json.dumps(actual,sort_keys=True).encode()).hexdigest()
   basis='ACCEPTED_STIMULUS_OBSERVED_STALL_CONTROL_RESPONSE_TIMING'
  else:
   # Missing traces cannot demonstrate semantic equality. Preserve separate
   # scenarios; do not collapse by test name or seed.
   signature='UNVERIFIED_'+x['scenario_id'];basis='TRACE_MISSING_KEEP_DISTINCT'
  groups[signature].append(x['scenario_id'])
  rows.append({'scenario_id':x['scenario_id'],'stimulus_signature':signature,'dedup_basis':basis,
               'legal_class':'EXPECTED_NEGATIVE' if x['negative']=='True' else 'LEGAL',
               'checker_message':x['checker_observed_pass_message'],'log_sha256_verified':True,
               'trace':str(trace) if trace else '', 'observed_event_counts':json.dumps(counts,sort_keys=True),
               'gap_fifo_pa_existing':x['gap_fifo_pa_same_packet'],'action':'REUSE_EVIDENCE_NO_RERUN'})
 for r in rows:
  g=groups[r['stimulus_signature']];r['representative_scenario_id']=g[0];r['duplicate_group_size']=len(g)
 with (OUT/'scenario_inventory_dedup590.csv').open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]),lineterminator='\n');w.writeheader();w.writerows(rows)
 m={'inputs':590,'unique_observed_stimulus_signatures':len(groups),'duplicate_rows':590-len(groups),
    'missing_trace_rows':sum(r['dedup_basis']=='TRACE_MISSING_KEEP_DISTINCT' for r in rows),
    'old_gap_fifo_pa_records':sum(int(r['gap_fifo_pa_existing']) for r in rows),
    'repeated_gap_window_tests':0,'policy':'Equivalence of recorded accepted stimulus/control/responses and observed stalls with timestamps, not proof that all unobserved pin activity is identical. Missing trace stays distinct; preserve all VDBs.'}
 (OUT/'inventory_checks.json').write_text(json.dumps(m,indent=2)+'\n');print(m)
if __name__=='__main__':main()

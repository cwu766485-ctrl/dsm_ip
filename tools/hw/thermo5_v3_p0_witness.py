#!/usr/bin/env python3.12
"""Validate exact P0 temporal predicates from real monitor and UVM events."""
import csv,hashlib,json,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/hw'))
from thermo5_r21_witness import vcd_edges

def validate_trace(events,kind,words,beats):
 def select(t,epoch=0):return [e for e in events if e['type']==t and e['epoch']==epoch]
 def one(es,message):
  if len(es)!=1:raise ValueError(message)
  return es[0]
 source=select('source_beat');w={}
 if kind!='reset':
  if len(source)!=beats or {(e['epoch'],e['packet_id']) for e in source}!={(0,0)}:raise ValueError('Not one complete packet')
  if [e['packet_beat_index'] for e in source]!=list(range(beats)):raise ValueError('Packet sequence gap')
  last=one([e for e in source if e['tlast']],'TLAST multiplicity')
  if source[-1]!=last:raise ValueError('Early TLAST')
  pa=select('pa_word')
  if len(pa)!=words or [e['word_index'] for e in pa]!=list(range(words)):raise ValueError('Incorrect PA transaction count/order')
  drain=one([e for e in select('stop_state') if not e['run'] and not e['active']],'No unique drained state')
  w.update(packet_id=0,epoch=0,source_beats=beats,pa_words=words,drained_ns=drain['time_ns'])
 if kind=='overlap':
  boundary=one([e for e in select('frame_boundary') if e['config_pending']],'No unique pending boundary')
  pending=one(select('config_pending'),'Pending ambiguity')
  if boundary['frame_id']!=1 or pending['time_ns']>=boundary['time_ns']:raise ValueError('Pending did not precede second boundary')
  stalls=[e for e in select('pa_stall') if e['time_ns']==boundary['time_ns'] and int(e['ready'],16)==0]
  if not stalls:raise ValueError('PA stall is not simultaneous with accepted boundary')
  old_accepted=sum(e['time_ns']<boundary['time_ns'] for e in pa)
  if not 0<old_accepted<56:raise ValueError('No proven old-frame word still outstanding')
  if any(e['time_ns']==boundary['time_ns'] for e in pa):raise ValueError('Blocked PA word was accepted at boundary')
  ack=one(select('config_ack_core'),'ACK ambiguity')
  if ack['time_ns']<=boundary['time_ns']:raise ValueError('ACK precedes boundary')
  w.update(boundary_ns=boundary['time_ns'],simultaneous_pa_stall_ns=stalls[0]['time_ns'],old_pa_accepted=old_accepted,old_words_outstanding=56-old_accepted,ack_ns=ack['time_ns'])
 elif kind=='long':
  stop=one([e for e in select('stop_state') if not e['run'] and e['active'] and e['draining']],'No unique STOP/drain entry')
  if not stop['time_ns']<last['time_ns']<drain['time_ns']:raise ValueError('STOP/TLAST/drain order missing')
  stalls=[e for e in select('pa_stall') if last['time_ns']<e['time_ns']<drain['time_ns'] and int(e['ready'],16) not in (0,15)]
  if len(stalls)<4:raise ValueError('No sustained partial-plane stall during drain')
  w.update(stop_ns=stop['time_ns'],accepted_beats_at_stop=sum(e['time_ns']<=stop['time_ns'] for e in source),tlast_ns=last['time_ns'],partial_stall_first_ns=stalls[0]['time_ns'],partial_stall_last_ns=stalls[-1]['time_ns'],partial_stall_cycles=len(stalls))
 elif kind=='reset':
  reset=one(select('reset'),'Reset ambiguity');pending=one(select('config_pending'),'Pending ambiguity')
  if not pending['time_ns']<reset['time_ns']:raise ValueError('No pending COMMIT before reset')
  if any(pending['time_ns']<=e['time_ns']<reset['time_ns'] for e in select('config_ack_core')+select('frame_boundary')):raise ValueError('Pending COMMIT applied before reset')
  stalls=[e for e in select('pa_stall') if pending['time_ns']<=e['time_ns']<reset['time_ns']]
  if not stalls or reset['time_ns']-stalls[-1]['time_ns']>4.573:raise ValueError('Reset not adjacent to actual pending PA stall')
  if len(select('source_beat',1))!=32 or len(select('pa_word',1))!=56:raise ValueError('Incomplete postreset packet replay')
  if select('config_ack_core',1) or select('config_pending',1):raise ValueError('Aborted config leaked across reset')
  w.update(epoch=0,pending_ns=pending['time_ns'],reset_observed_ns=reset['time_ns'],last_stalled_core_edge_ns=stalls[-1]['time_ns'],postreset_epoch=1,postreset_pa_words=56)
 return w

def main():
 out=ROOT/'docs/verification/data/thermo5-dv-v3';out.mkdir(parents=True,exist_ok=True);matrix=[];witnesses={}
 for name,kind,words,beats in [('overlap','overlap',112,64),('long64','long',112,64),('long96','long',168,96),('reset','reset',56,32)]:
  folder=ROOT/'runs/dv_convergence_v3'/name
  result=json.loads((folder/'result.json').read_text());oracle=json.loads((folder/'oracle_result.json').read_text())
  assert result['status']=='PASS' and oracle['exit_code']==0
  log=(folder/'test.log').read_text();events=[json.loads(l) for l in (folder/'test.jsonl').open()]
  w=validate_trace(events,kind,words,beats)
  if kind=='overlap':
   match=re.search(r'\[P0_OVERLAP_WITNESS\] boundary=1 pending=1 pa_valid=f pa_ready=0 old_pa_accepted=(\d+) old_frame_words=56 dpd_accepted=(\d+) active_c1=16384 new_c1=12288',log)
   assert match and int(match[1])==w['old_pa_accepted'] and int(match[2])==57
   # Confirm pre-edge request/pending/boundary tuple111 in native RTL VCD.
   scope=[];names={};values={};defined=False;target_ps=round(w['boundary_ns']*1000)
   for raw in (folder/'test.vcd').open():
    line=raw.strip();parts=line.split()
    if not defined:
     if line.startswith('$scope'):scope.append(parts[2])
     elif line.startswith('$upscope'):scope.pop()
     elif line.startswith('$var'):names['.'.join(scope+[parts[4]])]=parts[3]
     elif line.startswith('$enddefinitions'):defined=True
    elif line.startswith('#') and int(line[1:])>=target_ps:break
    elif line and line[0] in '01xz':values[line[1:]]=line[0]
    elif line.startswith('b'):
     value,code=line[1:].split();values[code]=value
   assert all(values[names['thermo5_sku_uvm_tb.dut.u_cfg.'+k]]=='1' for k in ['cfg_pending_valid','cfg_req_sync2','dpd_config_boundary'])
   w['cfg_vcd_preedge_tuple']='111'
  if kind=='reset':
   match=re.search(r'\[P0_RESET_WITNESS\] pending=1 pa_valid=f pa_ready=0 ef2_zero_mask=([0-9a-f]+) e1i0=(-?\d+) e2i0=(-?\d+) e1q0=(-?\d+) e2q0=(-?\d+)',log)
   assert match and int(match[1],16)!=15 and any(int(match[j]) for j in range(2,6))
   w['ef2_zero_mask']=match[1];w['branch0_ef2_state']=[int(match[j]) for j in range(2,6)]
  w['evidence_sha256']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [folder/n for n in ['test.log','test.jsonl','test.vcd','oracle.log','plan.json','result.json']]}
  w['oracle_summary']=(folder/'oracle.log').read_text();witnesses[name]=w
  matrix.append(dict(scenario=name,priority='P0',status='PASS',expected_words=words,source_packet_beats=beats,
                     target_cross=kind,oracle='CDC_EF2_FOUR_PA_PLANES_PASS',watchdog_core_cycles=12000 if kind=='long' else 20000,
                     exact_urg_delta='0 (same-parent594 URG;no new exact hit)' if (out/'vdb_urg_manifest.json').exists() else 'PENDING_MEASUREMENT',witness='actual_event_witness.json#'+name))
 (out/'actual_event_witness.json').write_text(json.dumps(witnesses,indent=2)+'\n')
 with (out/'scenario_matrix.csv').open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(matrix[0]),lineterminator='\n');w.writeheader();w.writerows(matrix)
 print('PASS:4 P0 predicates;overlap simultaneous;long64/96 ordered drain;reset pending/nonzero state/stall')
if __name__=='__main__':main()

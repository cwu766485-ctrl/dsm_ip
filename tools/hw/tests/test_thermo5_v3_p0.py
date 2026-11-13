"""Guard against turning unrelated/split event windows into P0 coverage."""
import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'tools/hw'))
from thermo5_v3_p0_witness import validate_trace


def overlap():
 e=[dict(type='source_beat',epoch=0,time_ns=float(i),packet_id=0,packet_beat_index=i,tlast=i==63) for i in range(64)]
 e += [dict(type='pa_word',epoch=0,time_ns=10.+i,word_index=i) for i in range(40)]
 e += [dict(type='pa_word',epoch=0,time_ns=71.+i,word_index=40+i) for i in range(72)]
 for kind,t,extra in [('config_pending',55,{}),('frame_boundary',70,dict(config_pending=True,frame_id=1)),
                      ('pa_stall',70,dict(ready='0x0')),('config_ack_core',71,{}),('stop_state',160,dict(run=False,active=False))]:
  e.append(dict(type=kind,epoch=0,time_ns=t,**extra))
 return sorted(e,key=lambda x:x['time_ns'])

class P0WitnessTests(unittest.TestCase):
 def test_real_simultaneous_overlap(self):
  self.assertEqual(validate_trace(overlap(),'overlap',112,64)['old_words_outstanding'],16)
 def test_later_stall_is_not_overlap(self):
  events=overlap();next(e for e in events if e['type']=='pa_stall')['time_ns']+=1
  with self.assertRaises(ValueError):validate_trace(events,'overlap',112,64)
 def test_other_epoch_stall_cannot_close(self):
  events=overlap();next(e for e in events if e['type']=='pa_stall')['epoch']=1
  with self.assertRaises(ValueError):validate_trace(events,'overlap',112,64)
 def test_no_old_data_is_not_overlap(self):
  events=overlap()
  for e in events:
   if e['type']=='pa_word' and 40<=e['word_index']<56:e['time_ns']=60+(e['word_index']-40)*.1
  with self.assertRaises(ValueError):validate_trace(events,'overlap',112,64)
 def test_incomplete_packet_rejected(self):
  events=overlap();events.remove(next(e for e in events if e['type']=='source_beat'))
  with self.assertRaises(ValueError):validate_trace(events,'overlap',112,64)
 def test_duplicate_output_index_rejected(self):
  events=overlap();next(e for e in events if e['type']=='pa_word')['word_index']=99
  with self.assertRaises(ValueError):validate_trace(events,'overlap',112,64)
 def test_applied_before_pending_rejected(self):
  events=overlap();next(e for e in events if e['type']=='config_pending')['time_ns']=75
  with self.assertRaises(ValueError):validate_trace(events,'overlap',112,64)
 def test_non_draining_stop_is_not_longpacket_cross(self):
  events=overlap()
  with self.assertRaises(ValueError):validate_trace(events,'long',112,64)

if __name__=='__main__':unittest.main()

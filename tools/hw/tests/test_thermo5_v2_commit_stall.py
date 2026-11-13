"""Reject temporal/identity/reset combinations that would fabricate a Cross hit."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from thermo5_v2_commit_stall import cross_witness


def packet():
    events = [dict(type='source_beat', epoch=0, packet_id=0,
                   packet_beat_index=i, tlast=i == 31, time_ns=float(i)) for i in range(32)]
    for kind, time, extra in [
        ('axil_write_fire',1,dict(addr='0x10',data='0x3cfe',strb='0x3',txn_id=1)),
        ('axil_write_response',1.1,dict(txn_id=1,resp=0)),
        ('axil_write_fire',2,dict(addr='0x00',data='0x02',strb='0x1',txn_id=2)),
        ('axil_write_response',2.1,dict(txn_id=2,resp=0)),
        ('config_pending',3,{}),('frame_boundary',4,dict(config_pending=True)),
        ('config_ack_core',5,{}),('commit_done',6,{}),('pa_stall',7,{}),
        ('stop_state',40,dict(run=False,active=False))]:
        events.append(dict(type=kind,time_ns=time,epoch=0,**extra))
    return sorted(events,key=lambda e:e['time_ns'])


class CommitWindowTests(unittest.TestCase):
    def test_single_packet_ordered_window(self):
        self.assertEqual(cross_witness(packet())['status'],'PASS')

    def test_stall_other_epoch_rejected(self):
        events=packet()
        next(e for e in events if e['type']=='pa_stall')['epoch']=1
        with self.assertRaises(ValueError):cross_witness(events)

    def test_two_packets_rejected(self):
        events=packet()
        events.append(dict(type='source_beat',epoch=0,packet_id=1,packet_beat_index=0,tlast=False,time_ns=42))
        with self.assertRaises(ValueError):cross_witness(events)

    def test_identity_not_nonidentity(self):
        events=packet()
        next(e for e in events if e.get('addr')=='0x10')['data']='0x4000'
        with self.assertRaises(ValueError):cross_witness(events)

    def test_later_identity_write_cannot_reuse_earlier_nonidentity(self):
        events=packet()+[dict(type='axil_write_fire',epoch=0,time_ns=1.5,addr='0x10',data='0x4000',strb='0x3',txn_id=3),dict(type='axil_write_response',epoch=0,time_ns=1.6,txn_id=3,resp=0)]
        events.sort(key=lambda e:e['time_ns'])
        with self.assertRaises(ValueError):cross_witness(events)

    def test_reset_cannot_join_windows(self):
        events=packet()+[dict(type='reset',epoch=0,time_ns=6.5)]
        with self.assertRaises(ValueError):cross_witness(events)

    def test_boundary_without_pending_rejected(self):
        events=packet()
        next(e for e in events if e['type']=='frame_boundary')['config_pending']=False
        with self.assertRaises(ValueError):cross_witness(events)

    def test_rejected_programming_not_a_cross(self):
        events=packet()
        next(e for e in events if e['type']=='axil_write_response')['resp']=2
        with self.assertRaises(ValueError):cross_witness(events)

if __name__=='__main__':unittest.main()

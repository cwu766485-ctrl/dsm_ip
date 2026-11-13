#!/usr/bin/env python3.12
"""Replay one existing non-identity vector with a directed COMMIT/stall window.

No new compile, product-state writes, random seed search, or waiver application.
The cross is a single-packet lifetime window, NOT simultaneous boundary/stall.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/hw'))
from thermo5_r21_replay import execute


def cross_witness(events):
    source = [e for e in events if e['type'] == 'source_beat']
    keys = {(e['epoch'], e['packet_id']) for e in source}
    if len(keys) != 1 or len(source) != 32 or sum(e['tlast'] for e in source) != 1:
        raise ValueError('Cross requires exactly one legal 32-beat packet')
    epoch, packet = next(iter(keys))
    if any(e['type'] == 'reset' for e in events):
        raise ValueError('Cross cannot span a reset')
    if [e['packet_beat_index'] for e in source] != list(range(32)):
        raise ValueError('Packet beat sequence is incomplete')
    scoped = [e for e in events if e['epoch'] == epoch]
    def first(kind, after=-1, predicate=lambda e: True):
        return next(e for e in scoped if e['type'] == kind and
                    e['time_ns'] > after and predicate(e))
    try:
        # Independent trace oracle validates coefficient application and all
        # output values. Here require an accepted non-identity C1 programming
        # transaction before this packet's COMMIT, not a plusarg/test name.
        commits=[e for e in scoped if e['type']=='axil_write_fire' and
                 int(e['addr'],16)==0 and int(e['strb'],16)&1 and int(e['data'],16)&2]
        if len(commits)!=1:raise ValueError('Cross requires one unambiguous COMMIT')
        commit=commits[0]
        commit_response = first('axil_write_response', commit['time_ns'], lambda e:
                                e['txn_id'] == commit['txn_id'] and e['resp'] == 0)
        writes=[e for e in scoped if e['type']=='axil_write_fire' and
                int(e['addr'],16)==0x10 and e['time_ns']<commit['time_ns']]
        if not writes:raise ValueError('No coefficient programming before COMMIT')
        coeff=writes[-1]
        if int(coeff['strb'],16)&3 !=3 or int(coeff['data'],16)&0xffff ==16384:
            raise ValueError('Latest C1 programming is not a complete non-identity write')
        response=first('axil_write_response',coeff['time_ns'],lambda e:
                       e['txn_id']==coeff['txn_id'] and e['resp']==0)
        if response['time_ns']>=commit['time_ns']:
            raise ValueError('Coefficient programming did not complete before COMMIT')
        pending = first('config_pending', commit['time_ns'])
        boundary = first('frame_boundary', pending['time_ns'], lambda e: e['config_pending'])
        ack = first('config_ack_core', boundary['time_ns'])
        done = first('commit_done', ack['time_ns'])
        stall = first('pa_stall', boundary['time_ns'])
        drain = first('stop_state', max(done['time_ns'], stall['time_ns']),
                      lambda e: not e['run'] and not e['active'])
    except StopIteration as exc:
        raise ValueError('Missing ordered same-epoch COMMIT/boundary/stall/drain event') from exc
    if source[0]['time_ns'] > commit['time_ns'] or source[-1]['time_ns'] > drain['time_ns']:
        raise ValueError('COMMIT/drain not in single packet lifetime')
    return {'status': 'PASS', 'epoch': epoch, 'packet_id': packet,
            'window': 'single packet: first source beat through drained idle',
            'simultaneous_boundary_stall': False,
            'events': {k: v for k, v in locals().copy().items() if k in
                       ('coeff','response','commit','commit_response','pending','boundary','ack','done','stall','drain')}}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--execute', action='store_true')
    a = p.parse_args(); out = a.out.resolve(); out.mkdir(parents=True, exist_ok=True)
    source = next(x for x in json.loads((ROOT/'runs/rtl_invariants/replay_results.json').read_text()) if x['index'] == 110)
    argv = []; skip = False
    for arg in source['argv']:
        if skip: skip = False; continue
        if arg in ('-cm_dir', '-l'): skip = True; continue
        if arg.startswith('+THERMO5_TRACE_JSONL='): continue
        argv.append(arg)
    argv += ['+THERMO5_REQUIRE_COMMIT_BOUNDARY_STALL', '+THERMO5_TRACE_JSONL='+str(out/'test.jsonl'),
             '-cm_dir', str(out/'test.vdb'), '-l', str(out/'test.log')]
    record = dict(index=589, test=source['test'], negative=False, argv=argv,
                  log=str(out/'test.log'), vdb=str(out/'test.vdb'))
    (out/'plan.json').write_text(json.dumps(record, indent=2)+'\n')
    if not a.execute: return
    result = execute(record)
    (out/'result.json').write_text(json.dumps(result, indent=2)+'\n')
    if result['status'] != 'PASS': raise SystemExit('Licensed UVM failed')
    cmd = [sys.executable, str(ROOT/'dv/uvm/refmodel/python/check_thermo5_monitor_trace.py'), str(out/'test.jsonl')]
    with (out/'oracle.log').open('w') as f:
        code = subprocess.run(cmd, cwd=ROOT, stdout=f, stderr=subprocess.STDOUT).returncode
    if code: raise SystemExit('Independent trace oracle failed')
    witness = cross_witness([json.loads(l) for l in (out/'test.jsonl').open()])
    witness['oracle_command'] = cmd
    witness['evidence_sha256'] = {n: hashlib.sha256((out/n).read_bytes()).hexdigest()
                                  for n in ('test.jsonl','test.log','oracle.log','plan.json','result.json')}
    (out/'cross_witness.json').write_text(json.dumps(witness, indent=2)+'\n')
    print(json.dumps(witness, indent=2))

if __name__ == '__main__': main()

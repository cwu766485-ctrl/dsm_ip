#!/usr/bin/env python3.12
"""Bind v2 Formal results to six exact procedural Condition bins (PENDING)."""
import csv
import gzip
import hashlib
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/verification/data/thermo5-pr55-application/v2'

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    remaining=list(csv.DictReader((OUT.parent/'remaining54.csv').open()))
    jobs={}
    for name,expected in [('mailbox',{'a_pending_requires_request':'proven','c_exact_line333':'uncoverable','c_apply':'covered','c_pending':'covered','c_return_to_idle':'covered'}),
                          ('gain',{'a_s0_start_valid':'proven','a_s0_end_valid':'proven','a_s1_start_valid':'proven','a_s1_end_valid':'proven',
                                   'c_line112':'uncoverable','c_line113':'uncoverable','c_line123':'uncoverable','c_line124':'uncoverable','c_live_metadata':'covered','c_invalid_input_metadata':'covered'})]:
        folder=ROOT/'runs/dv_convergence_v2'/f'{name}_formal'
        properties=(folder/'properties.txt').read_text()
        found={m[2]:m[1] for m in re.finditer(r'\[\s*\d+\]\s+(proven|covered|uncoverable)\s+.*?-\s+\w+\.(\w+)',properties)}
        assert found==expected,(name,found)
        for line in properties.splitlines():
            if re.search(r'\]\s+proven\s',line):assert '(non_vacuous)' in line
        console=(folder.parent/f'{name}_formal.stdout').read_text()
        assert 'Number of Black-Box Instances = 0' in console
        setup=(folder/'setup.txt').read_text()
        assert not re.search(r':\s*[1-9]\d*',setup),setup
        harness=f'thermo5_{"mailbox_boundary" if name=="mailbox" else "gain_metadata"}_v2'
        sources=[ROOT/f'dv/uvm/formal/{harness}_harness.sv', ROOT/f'dv/uvm/formal/run_{harness}.tcl',
                 ROOT/('rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv' if name=='mailbox' else 'rtl/frontend/dsm_frame_gain_vector.sv')]
        jobs[name]={'properties':found,'nonvacuous_assertions':sum(v=='proven' for v in found.values()),'blackboxes':0,'setup_violations':0,
                    'reset_scope':'Saved common-reset initialization; rst_n constrained1 thereafter; arbitrary external traffic; no protocol/boundary assumptions. Repeated reset effects require epoch composition.',
                    'source_sha256':{str(p.relative_to(ROOT)):digest(p) for p in sources},
                    'artifacts':{str(p.relative_to(ROOT)):digest(p) for p in [folder/'properties.txt',folder/'setup.txt',folder/'engines.txt',folder.parent/f'{name}_formal.stdout']},
                    'tool_warnings':[l for l in console.splitlines() if 'Warning' in l],
                    'product_parameters':('MAX_TAPS=1; clocks14:8; tx_active/draining unrestricted' if name=='mailbox' else 'W=16 LANES=8 GAIN_W=16 GAIN_FRAC=14 HOLD_STATE_ON_DISABLE=0')}
    (OUT/'new_formal_results.json').write_text(json.dumps(jobs,indent=2)+'\n')
    ids={'TXB-33613a1855fcc02e8ef4':'DPD_EMPTY_OUTPUT_READY','TXB-a8041f215017e6e9b5f5':'MAILBOX_PENDING_REQUIRES_REQUEST'}
    for r in remaining:
        if 'u_frame_gain' in r['instance'] and r['exact_urg_bin'] in ('112:0/1','113:0/1','123:0/1','124:0/1'):ids[r['semantic_bin_id']]='GAIN_REGISTERED_METADATA_REQUIRES_VALID'
    assert len(ids)==6
    old=list(csv.DictReader(gzip.open(OUT.parent/'approval_index_11593.csv.gz','rt')))
    assert not set(ids)&{r['semantic_bin_id'] for r in old}
    rows=[]
    for r in remaining:
        if r['semantic_bin_id'] not in ids:continue
        assert digest(ROOT/r['source_file'])==r['source_file_sha256'],r['semantic_bin_id']
        native=json.loads(r['native_mapping']);assert len(native)==1 and native[0]['kind']=='cond' and 'selected_vector' in native[0]
        rows.append({'semantic_bin_id':r['semantic_bin_id'],'root_cause_group':ids[r['semantic_bin_id']],
                     'instance':r['instance'],'source_file':r['source_file'],'source_sha256':r['source_file_sha256'],
                     'exact_urg_bin':r['exact_urg_bin'],'native_mapping':r['native_mapping'],'native_scope_checksum':r['native_scope_checksum'],
                     'product_sha':'635be681046b3ab7d6fdda7f4e9818d7226efd66','technical_status':'PROVEN_UNREACHABLE',
                     'scope':'Clock-sampled procedural expression outside reset; reset-initialized epoch. See bound proof assumptions, parameters and positive covers.',
                     'evidence':('formal_reuse_binding.json' if 'u_memory_dpd' in r['instance'] else 'new_formal_results.json'),
                     'reviewer_decision':'PENDING','approval_reference':'','official_exclusion_active':'NO'})
    with (OUT/'supplemental_review6.csv').open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]),lineterminator="\n");w.writeheader();w.writerows(rows)
    print('PASS:6 exact source/native-bound technical candidates;0 approvals;11599 unique pending IDs')
if __name__=='__main__':main()

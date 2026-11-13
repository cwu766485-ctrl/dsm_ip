#!/usr/bin/env python3.12
"""Generate only the 33 reviewed PR55 analysis directives from native URG dump."""
import argparse,csv,hashlib,json
from pathlib import Path
from thermo5_tx_native_exclusion import parse_native_template
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/verification/data/thermo5-pr55-application'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--previous141',action='store_true')
    args=parser.parse_args()
    if args.previous141:
        rows=[r for r in csv.DictReader((ROOT/'docs/verification/data/thermo5-stalled-reset/exact_dispositions_231.csv').open()) if r['final_disposition']=='EXCLUSION_CANDIDATE']
        expected=141
    else:
        rows=[r for r in csv.DictReader((ROOT/'docs/verification/data/thermo5-rtl-invariants/open87_review.csv').open()) if r['technical_decision']=='EXCLUSION_CANDIDATE']
        expected=33
    assert len(rows)==expected
    native={m:parse_native_template(ROOT/f'runs/pr55_exact/native/fullexclude.{f}') for m,f in [('line','line'),('cond','cond'),('branch','branch'),('toggle','tgl')]}
    chunks={'parameter':[],'legal_cdc':[]};mapping=[]
    for r in rows:
        assert hashlib.sha256((ROOT/r['source_file']).read_bytes()).hexdigest()==r['source_file_sha256']
        n=json.loads(r['native_mapping'])[0];scope=[s for s in native[r['metric']] if s['instance']==r['instance']];assert len(scope)==1
        s=scope[0];objects=s['objects'];metric=r['metric']
        if metric=='toggle':
            obj=[o for o in objects if o['name']==n['name']];assert len(obj)==1;obj=obj[0];assert obj['decl']==n['decl']
            bit=n['selected_signal'].split('[')[-1].rstrip(']') if '[' in n['selected_signal'] else '0'
            direction={'0_to_1':'0to1','1_to_0':'1to0'}[n['selected_direction']]
            directive=f'Toggle {direction} {obj["name"]} [{bit}] "{obj["decl"]}"'
        else:
            ident=str(n.get('id',n.get('block_id')))
            matches=[o for o in objects if o['id']==ident and o['checksum']==n['checksum']];assert len(matches)==1,(r['semantic_bin_id'],matches)
            obj=matches[0]
            if metric=='line':directive=f'Block {ident} "{obj["checksum"]}" "{obj["signature"]}"'
            elif metric=='cond':
                vid,truth=n['selected_vector'];assert (vid,truth) in obj['vectors']
                directive=f'Condition {ident} "{obj["checksum"]}" "{obj["signature"]}" ({vid} "{truth}")'
            else:
                selected=[(v,t) for v,t in obj['vectors'] if v==n['vector_id']];assert len(selected)==1
                vid,truth=selected[0];directive=f'Branch {ident} "{obj["checksum"]}" "{obj["signature"]}" ({vid}) "{truth}"'
        group='parameter' if args.previous141 else 'legal_cdc' if r['review_batch']=='LEGAL_FRAME_RESIDUAL_EIGHT' else 'parameter'
        entry='\n'.join([s['checksum'],s['module'],'INSTANCE: '+s['instance'],directive])
        if entry not in chunks[group]:chunks[group].append(entry)
        mapping.append(dict(semantic_bin_id=r['semantic_bin_id'],group=group,instance=r['instance'],metric=metric,scope_checksum=s['checksum'],directive=directive,shared_statement_lines=n.get('statement_lines',[]),approval='PENDING'))
    OUT.mkdir(exist_ok=True,parents=True)
    for k,entries in chunks.items():(OUT/(f'previous141_{k}_analysis_only.el' if args.previous141 else f'{k}_analysis_only.el')).write_text('// ANALYSIS ONLY; NOT APPROVED. Exact reviewed IDs only.\n'+'\n\n'.join(entries)+'\n')
    (OUT/('native141.json' if args.previous141 else 'native33.json')).write_text(json.dumps(mapping,indent=2)+'\n')
    print(f'{expected} semantic IDs; native directives={sum(map(len,chunks.values()))}; approval PENDING')
if __name__=='__main__':main()

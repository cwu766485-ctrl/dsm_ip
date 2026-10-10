"""Generate exact configuration/scoped exclusions; keep reachable/analytical bins."""
import argparse
from collections import Counter
import hashlib,json,re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def digest_path(value):
    p=Path(value)
    # Linux run manifests may be audited from the Windows workspace.
    if not p.exists() and value.startswith('/mnt/'):
        p=Path(value[5].upper()+':/'+value[7:])
    if not p.exists() and re.match(r'^[A-Za-z]:[\\/]',value):
        p=Path('/mnt/'+value[0].lower()+'/'+value[3:].replace('\\','/'))
    return sha(p)

def source_number(value):
    return int(str(value).split('.')[0])

def condition_match(row, expression, vector):
    raw=row['raw']; operand=raw['operand_bin']
    normalized=lambda value:re.sub(r'\s+','',value)
    saved=raw['expression'].split('EXPRESSION ',1)[1]
    # URG appends numbered operand rulers, including short '-1-' rulers.
    # Remove only that display suffix; preserve every expression operator.
    saved=re.split(r'\s+-+\d+-+',saved,maxsplit=1)[0]
    if 'Number Term' in saved:
        # URG displays a wide OR as a numbered term list instead of a bit
        # vector. Reconcile every comparison in order before mapping its
        # ALL ZEROS or one-hot row to a native signature.
        terms=re.findall(r'\(str_val_ascii\s*==\s*([^)]*)\)',saved)
        native=re.findall(r'\(str_val_ascii\s*==\s*([^)]*)\)',expression)
        if not terms or list(map(normalized,terms))!=list(map(normalized,native)):return False
        if operand=='ALL ZEROS':return vector=='0'*len(terms)
        match=re.match(r'^(\d+) \(str_val_ascii\s*==',operand)
        if not match:return False
        index=int(match[1])-1
        return 0<=index<len(terms) and vector==('0'*index+'1'+'0'*(len(terms)-index-1))
    return operand.replace('/','')==vector and normalized(saved)==normalized(expression)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--ledger',type=Path,required=True)
    ap.add_argument('--dump',type=Path,required=True)
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--identity-proof',type=Path)
    ap.add_argument('--interp-proof',type=Path)
    ap.add_argument('--xpm-residual-proof',type=Path)
    ap.add_argument('--vendor-review',type=Path)
    ap.add_argument('--xpm-reset-proof',type=Path)
    ap.add_argument('--xpm-defaults-proof',type=Path)
    ap.add_argument('--xpm-fwft-proof',type=Path)
    args=ap.parse_args()
    ledger=json.loads(args.ledger.read_text())
    for path,digest in ledger['source_sha256'].items():
        assert sha(ROOT/path.replace('\\','/'))==digest,('stale RTL',path)
    allowed={'CONFIGURATION_PROOF','SCOPED_FORMAL_PROVEN'}
    proofs={}
    for name,path in [('identity',args.identity_proof),('interp',args.interp_proof),('xpm_residual',args.xpm_residual_proof),('xpm_reset',args.xpm_reset_proof)]:
        if path:
            manifest=json.loads((path/'manifest.json').read_text())
            assert manifest['status'] in ('PASS','SCOPED_SATURATION_PROVEN_PAYLOAD_OPEN'),manifest['status']
            assert manifest['sources_unchanged'] and manifest['blackboxes']==['0']
            setup=(path/'setup.txt').read_text()
            assert setup and not re.search(r':\s+[1-9]\d*\s*$',setup,re.M),('formal setup violations',path)
            for p,h in manifest['source_sha256'].items():assert digest_path(p)==h,('stale proof',p)
            proofs[name]=sha(path/'manifest.json')
    if args.identity_proof:allowed.add('ARITHMETIC_PROOF_AND_EXHAUSTIVE_RTL')
    # The interpolation lemma is valid-qualified, whereas round_sat is
    # invoked for invalid slots too. Retain the raw bins until a proof of
    # every evaluated payload (including startup) exists.
    if args.xpm_residual_proof:allowed.add('OPEN_XPM_PROOF_TRANSFER')
    vendor={}
    if args.xpm_fwft_proof:
        path=args.xpm_fwft_proof
        manifest=json.loads((path/'manifest.json').read_text())
        assert manifest['exit_code']==0 and manifest['sources_unchanged']
        assert re.search(r'\] proven\s+-\s+thermo5_xpm_fwft_transition\.a_fwft_legal\s*$',(path/'properties.txt').read_text(),re.M)
        assert not re.search(r':\s+[1-9]\d*\s*$',(path/'setup.txt').read_text(),re.M)
        assert re.search(r'Number of Black-Box Instances\s*=\s*0',(path/'console.log').read_text())
        for p,h in manifest['source_sha256'].items():assert digest_path(p)==h
        # Only this named proven property; the transition stays inconclusive.
        proofs['xpm_fwft_legal_states']=sha(path/'manifest.json')
    if args.xpm_defaults_proof:
        path=args.xpm_defaults_proof
        manifest=json.loads((path/'manifest.json').read_text())
        assert manifest['status']=='PASS' and manifest['sources_unchanged']
        assert not re.search(r':\s+[1-9]\d*\s*$',(path/'setup.txt').read_text(),re.M)
        assert re.search(r'Number of Black-Box Instances\s*=\s*0',(path/'console.log').read_text())
        for p,h in manifest['source_sha256'].items():assert digest_path(p)==h
        proofs['xpm_defaults']=sha(path/'manifest.json')
    if args.vendor_review:
        review=json.loads(args.vendor_review.read_text())
        assert review['ledger_sha256']==sha(args.ledger)
        assert all(digest_path(p)==h for p,h in review['vendor_source_sha256'].items())
        vendor={r['bin_id']:r for r in review['reviewed']}
    bins={}
    for row in ledger['records']:
        if args.xpm_fwft_proof and row['instance'].endswith('xpm_fifo_base_inst'):
            if (row['metric']=='line' and str(row['raw']['line']) in ('1251','1292','1331') or
                row['metric']=='branch' and str(row['raw']['line']) in ('1220','1287','1309') and row['raw']['decisions'].startswith('default')):
                row={**row,'status':'SCOPED_FORMAL_PROVEN'}
        if args.xpm_defaults_proof and row['instance'].endswith('xpm_fifo_rst_inst'):
            exact_default=(row['metric']=='line' and str(row['raw']['line']) in ('1773','1778','1795','1825','1840') or
                           row['metric']=='branch' and (row['bin']=='1742:WRST_EXIT/-/-/-/-/-/0/0/0' or
                           row['raw']['decisions'].startswith('default') and str(row['raw']['line']) in ('1742','1789','1810','1835')))
            if exact_default:row={**row,'status':'SCOPED_FORMAL_PROVEN'}
        if args.xpm_reset_proof and row['instance'].endswith('xpm_fifo_rst_inst'):
            exact_reset=(row['metric']=='line' and str(row['raw']['line']) in ('1759','1767') or
                         row['metric']=='branch' and row['bin'] in (
                         '1742:WRST_OUT/-/-/-/1/-/-/-/-','1742:WRST_EXIT/-/-/-/-/-/1/-/-'))
            if exact_reset:
                row={**row,'status':'SCOPED_FORMAL_PROVEN'}
        if row['status'] in allowed or row['bin_id'] in vendor:
            bins.setdefault((row['instance'],row['metric']),[]).append(row)
    args.out.mkdir(parents=True,exist_ok=False)
    selected=[]; unmatched=[]
    metrics=[('line','line'),('cond','cond'),('branch','branch'),('toggle','tgl')]
    if args.xpm_reset_proof:metrics.append(('fsm','fsm'))
    for metric,ext in metrics:
        dumped=(args.dump/f'fullexclude.{ext}').read_text()
        result=[dumped[:dumped.index('// CHECKSUM:')]]
        instance=checksum=module=fsm=None; source_line=None
        for line in dumped.splitlines():
            if line.startswith('// CHECKSUM:'): checksum=line[3:]
            if line.startswith('// ANNOTATION: "ModuleName:'): module=line
            if line.startswith('// INSTANCE:'): instance=line[13:]
            if 'LineNumber:' in line:
                source_line=int(re.search(r'LineNumber:\s*(\d+)',line)[1])
            rows=bins.get((instance,metric),[])
            entries=[]
            if metric=='fsm':
                if line.startswith('// Fsm '):fsm=line[3:]
                # These two transitions require a new reset while busy. The
                # vendor legal-reset contract proof excludes precisely them.
                if line.startswith('// Transition ') and 'gen_rst_ic.curr_wrst_state' in (fsm or '') and any(t in line for t in ('WRST_OUT->WRST_IN','WRST_EXIT->WRST_IN')):
                    result.extend([checksum,module,f'INSTANCE: {instance}',fsm,line[3:]])
                    selected.append({'bin_id':'xpm_reset_contract_'+line.split()[2],'metric':'fsm','entry':line[3:],'instance':instance})
            if metric=='line' and line.startswith('// Block '):
                # A VCS basic block groups consecutive statements at its first
                # source line. Reconcile following lines only when every one
                # is already an individually justified missing-bin record.
                target=[r for r in rows if source_number(r['raw']['line'])==source_line]
                if target:
                    end=source_line
                    while any(source_number(r['raw']['line'])==end+1 for r in rows):end+=1
                    entries=[(line[3:],r) for r in rows if source_line<=source_number(r['raw']['line'])<=end]
                    # Macro expansion puts several distinct blocks at one
                    # source line. Match the saved expanded statement exactly;
                    # never exclude its startup force/release or normal update.
                    if any('.' in str(r['raw']['line']) for r in target):
                        norm=lambda value:re.sub(r'\s+','',value)
                        statement=re.search(r'^// Block \d+ "\d+" "(.*)"$',line)[1]
                        entries=[(line[3:],r) for r in target if norm(r['raw']['statement'])==norm(statement)]
                    elif len(target)==1 and target[0]['raw'].get('total',1)>1:
                        # Multiple branches share one source line. Select only
                        # the missing assignment, retaining condition/control
                        # blocks already exercised on that line.
                        statement=re.search(r'^// Block \d+ "\d+" "(.*)"$',line)[1]
                        if statement.startswith(('if (','case (')):entries=[]
            if metric=='cond' and line.startswith('// Condition ') and re.search(r'\(\d+ "[01]+"\)$',line):
                vector=re.search(r'\(\d+ "([01]+)"\)$',line)[1]
                expression=re.search(r'// Condition \d+ "\d+" "(.*) 1 -1"',line)[1]
                entries=[(line[3:],r) for r in rows if int(r['raw']['line'])==source_line
                         and condition_match(r,expression,vector)]
            if metric=='branch' and line.startswith('// Branch ') and re.search(r'\(\d+\) "[^"]+"$',line):
                vector=re.search(r'\(\d+\) ".*? ([01,\-a-zA-Z_ ]+)"$',line)
                if vector:
                    entries=[(line[3:],r) for r in rows if int(r['raw']['line'])==source_line and
                             re.findall(r'[A-Za-z_]+|[01]|-',r['raw']['decisions'])==re.findall(r'[A-Za-z_]+|[01]|-',vector[1])]
            if metric=='toggle' and line.startswith('// Toggle '):
                match=re.fullmatch(r'// Toggle (\S+) (".*")',line)
                if match:
                    signal,signature=match.groups()
                    for r in rows:
                        _,name,direction=r['bin'].split(':')
                        base=name.split('[')[0]
                        # URG lists an MDA element as a[0], unlike its bit a[0][7].
                        if name==signal or name.startswith(signal+'['):
                            suffix=name[len(signal):]
                            entries.append((f'Toggle {direction.replace("_to_","to")} {signal} {suffix} {signature}',r))
            unique={entry:r for entry,r in entries}
            for entry,row in unique.items():
                result.extend([checksum,module,f'INSTANCE: {instance}',f'// ANNOTATION: "Evidence: {row["bin_id"]}; {row["status"]}"',entry])
                selected.extend({'bin_id':r['bin_id'],'metric':metric,'entry':entry,'instance':instance}
                                for e,r in entries if e==entry)
        (args.out/f'reviewed.{ext}.el').write_text('\n'.join(result)+'\n',newline='\n')
    # Legacy ledger IDs can collide for a parent/sub-expression sharing the
    # same source line and operand vector. URG entry signatures disambiguate.
    selected=list({(r['bin_id'],r['entry']):r for r in selected}.values())
    done={r['bin_id'] for r in selected}
    unmatched=[r['bin_id'] for rows in bins.values() for r in rows if r['bin_id'] not in done]
    manifest={'status':'PARTIAL_EXCLUSIONS','selected_counts':dict(Counter(r['metric'] for r in selected)),
              'selected':selected,'unmapped_candidate_bins':unmatched,'ledger_sha256':sha(args.ledger),
              'exclusion_sha256':{p.name:sha(p) for p in args.out.glob('*.el')},
              'proof_manifest_sha256':proofs,
              'policy':'Only exact configuration or linked scoped proof entries. Interpolation bounds apply to valid payload; invalid startup payload is outside that proof. Reachable counters, vendor ownership and inconclusive payload equivalence are not exclusions.'}
    (args.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({k:manifest[k] for k in ['status','selected_counts']}))
if __name__=='__main__': main()

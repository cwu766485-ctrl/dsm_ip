"""Scoped production/vendor proofs with source hashes and strict result gates."""
import argparse,hashlib,json,os,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
TOPS={'identity':'thermo5_identity_lemmas_harness','xpm_reset':'thermo5_xpm_reset_contract_harness','xpm_residual':'thermo5_xpm_cdc_residual_harness','xpm_fwft':'thermo5_xpm_fwft_harness'}
TOPS['interp_bounds']='thermo5_interp_bounds_harness'
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--job',choices=TOPS,required=True)
    ap.add_argument('--out-dir',type=Path,required=True)
    ap.add_argument('--xpm-root',type=Path)
    ap.add_argument('--lemma-evidence',type=Path)
    ap.add_argument('--auto-lemmas',action='store_true')
    args=ap.parse_args();out=args.out_dir.resolve()
    if ROOT/'runs' not in out.parents or out.exists(): ap.error('Use a new runs/ directory')
    sources=list((ROOT/'rtl').rglob('*.sv'))+list((ROOT/'rtl').rglob('*.v'))
    sources += [ROOT/'dv/uvm/formal'/p for p in ['thermo5_gap_harness.sv','thermo5_convergence_harness.sv','run_thermo5_convergence.tcl']]
    if args.job.startswith('xpm'):
        if not args.xpm_root: ap.error('Actual installed XPM sources required')
        sources += [args.xpm_root/f'data/ip/xpm/{x}/hdl/{x}.sv' for x in ['xpm_cdc','xpm_memory','xpm_fifo']]
    hashes={str(p):digest(p) for p in sources}
    env=os.environ.copy();env.update(THERMO5_FORMAL_REPO=str(ROOT),THERMO5_FORMAL_OUT=str(out),THERMO5_FORMAL_TOP=TOPS[args.job])
    if args.xpm_root:env['THERMO5_XPM_ROOT']=str(args.xpm_root)
    if args.auto_lemmas:env['THERMO5_AUTO_LEMMAS']='1'
    lemmas=[]
    if args.lemma_evidence:
        evidence=json.loads(args.lemma_evidence.read_text())
        assert all(digest(Path(p))==h for p,h in evidence['source_sha256'].items())
        lemmas=[name.split('.',1)[1] for state,name in evidence['assertions'] if state=='proven' and '.model.' not in name]
        if not lemmas:ap.error('No independently proven intermediate lemmas')
        env['THERMO5_PROVEN_LEMMAS']=' '.join(lemmas)
    out.mkdir(parents=True);start=time.monotonic()
    argv=['vcf','-batch','-fmode','FPV','-f',str(ROOT/'dv/uvm/formal/run_thermo5_convergence.tcl')]
    with (out/'console.log').open('w') as f:
        code=subprocess.call(argv,cwd=out,env=env,stdout=f,stderr=subprocess.STDOUT)
    prop=out/('properties_compositional.txt' if lemmas or args.auto_lemmas else 'properties.txt')
    text=prop.read_text() if prop.exists() else ''
    assertions=re.findall(r'^\s*\[\s*\d+\]\s+(\w+)(?:\([^)]*\))?\s+.*? -\s+(\S*\.a_\S+)',text,re.M)
    covers=re.findall(r'^\s*\[\s*\d+\]\s+(\w+)(?:\([^)]*\))?\s+.*? -\s+(\S*\.c_\S+)',text,re.M)
    banner=(out/'console.log').read_text()
    bb=re.findall(r'Number of Black-Box Instances\s*=\s*(\d+)',banner)
    ok=code==0 and assertions and all(s=='proven' for s,n in assertions) and covers and bb and all(x=='0' for x in bb)
    if args.job=='xpm_reset':ok=ok and len(assertions)==2 and len(covers)==6 and all(s==('uncoverable' if n.endswith('reentry') else 'covered') for s,n in covers)
    elif args.job=='xpm_residual':ok=ok and len(assertions)==7 and len(covers)==9 and all(s=='covered' for s,n in covers)
    else:ok=ok and all(s in ('covered','uncoverable') for s,n in covers)
    setup=(out/'setup.txt').read_text() if (out/'setup.txt').exists() else ''
    ok=ok and bool(setup) and not re.search(r':\s+[1-9]\d*\s*$',setup,re.M)
    after={p:digest(Path(p)) for p in hashes};ok=ok and hashes==after
    scoped=False
    if args.job=='identity':
        base=(out/'properties.txt').read_text() if (out/'properties.txt').exists() else ''
        required=['model.a_no_saturation_i','model.a_no_saturation_q','model.a_saturation_count_zero','a_sum_i','a_sum_q']
        scoped=code==0 and all(re.search(r'\] proven\s+.* -  '+TOPS[args.job]+r'\.'+re.escape(n)+r'\s*$',base,re.M) for n in required)
        scoped=scoped and len(covers)==4 and all(s=='covered' for s,n in covers) and bb==['0'] and hashes==after
    result={'status':'PASS' if ok else 'SCOPED_SATURATION_PROVEN_PAYLOAD_OPEN' if scoped else 'INCONCLUSIVE_OR_FAIL','job':args.job,'argv':argv,'exit_code':code,'seconds':time.monotonic()-start,'source_sha256':hashes,'sources_unchanged':hashes==after,'assertions':assertions,'covers':covers,'blackboxes':bb,'promoted_proven_lemmas':lemmas,'lemma_evidence':str(args.lemma_evidence) if lemmas else None}
    (out/'manifest.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['status','job','seconds']}))
    return 0 if ok else 1
if __name__=='__main__':raise SystemExit(main())

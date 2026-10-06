"""Run legal AXI-Lite reproductions against current RTL and isolated historical regressions."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[3]

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out-dir',required=True)
    ap.add_argument('--simulator',choices=('xsim','vcs'),default='xsim')
    args=ap.parse_args()
    out=Path(args.out_dir).resolve()
    if ROOT/'runs' not in out.parents or out.exists():
        ap.error('Use a new directory below runs/')
    out.mkdir(parents=True)
    current=(ROOT/'rtl/axi/dsm_ip_axi_top.v').read_text(encoding='utf-8')
    variants={'fixed':current}
    old='''wire mp_commit_failure_event = mp_commit_inflight && !soft_reset &&
                                 !mp_commit_pulse &&'''
    assert current.count(old)==1
    variants['stale_reject']=current.replace(old,'''wire mp_commit_failure_event = mp_commit_inflight && !soft_reset &&''')
    old='if (mp_commit_inflight && !soft_reset) begin'
    assert current.count(old)==1
    variants['reset_completion']=current.replace(old,'if (mp_commit_inflight) begin').replace(
        'if (mp_commit_success_event) begin','if (mp_active_bank == mp_commit_target_bank) begin')
    cancel='''      if (soft_reset) begin
        mp_commit_pulse <= 1'b0;
        mp_commit_pending <= 1'b0;
        mp_commit_inflight <= 1'b0;
        mp_commit_ack <= 1'b0;
        mp_commit_failed <= 1'b0;
        mp_commit_target_bank <= 1'b0;
      end'''
    assert current.count(cancel)==1
    variants['reset_completion']=variants['reset_completion'].replace(cancel,'')
    filelist=(ROOT/'dv/uvm/formal/dsm_formal_filelist.f').read_text().splitlines()
    sources=[ROOT/p for p in filelist if p.startswith('rtl/')]
    tb=ROOT/'dv/uvm/tb/tb_dsm_commit_bug_repro.sv'
    records=[]
    for variant,source in variants.items():
        work=out/variant; work.mkdir()
        staged=work/'dsm_ip_axi_top.v'; staged.write_text(source,encoding='utf-8')
        paths=[staged if p.name=='dsm_ip_axi_top.v' else p for p in sources]+[tb]
        commands=[]
        def run(argv,name):
            if args.simulator=='xsim':
                settings=Path('D:/Xilinx/Vivado/2024.1/settings64.bat')
                script=work/(name+'.cmd')
                script.write_text('@echo off\ncall "'+str(settings)+'" >nul\n'+argv[0]+' '+' '.join('"'+a+'"' if not a.startswith('-') else a for a in argv[1:])+'\n',encoding='ascii')
                actual=['cmd.exe','/d','/c',str(script)]
            else: actual=argv
            with (work/(name+'.log')).open('w',encoding='utf-8') as log:
                result=subprocess.run(actual,cwd=work,stdout=log,stderr=subprocess.STDOUT)
            commands.append({'argv':argv,'exit_code':result.returncode,'log':str(work/(name+'.log'))})
            return result.returncode
        if args.simulator=='xsim':
            if run(['xvlog','-sv',*[str(p) for p in paths]],'compile')!=0: raise RuntimeError('xvlog failed')
            if run(['xelab','tb_dsm_commit_bug_repro','-s','commit_repro'],'elaborate')!=0: raise RuntimeError('xelab failed')
        else:
            if run(['vcs','-full64','-sverilog','-top','tb_dsm_commit_bug_repro',*[str(p) for p in paths],'-o',str(work/'simv')],'compile')!=0:
                raise RuntimeError('VCS compile failed')
        for case in (('stale_reject','reset_completion') if variant=='fixed' else (variant,)):
            argv=(['xsim','commit_repro','-runall','-testplusarg','CASE='+case] if args.simulator=='xsim'
                  else [str(work/'simv'),'+CASE='+case])
            code=run(argv,case)
            txt=(work/(case+'.log')).read_text(encoding='utf-8',errors='replace')
            passed='COMMIT_BUG_REPRO_PASS case='+case in txt and 'Fatal:' not in txt
            detected='BUG_'+case.upper().replace('STALE_REJECT','STALE_REJECTION') in txt and 'COMMIT_BUG_REPRO_PASS' not in txt
            ok=(passed and code==0) if variant=='fixed' else detected
            records.append({'variant':variant,'case':case,'expected':'PASS' if variant=='fixed' else 'DETECTED',
                            'result':'PASS' if ok else 'FAIL','exit_code':code,'log':str(work/(case+'.log')),
                            'staged_rtl_sha256':hashlib.sha256(staged.read_bytes()).hexdigest(),'commands':commands.copy()})
    summary={'simulator':args.simulator,'historical_fix':'6deb79903b80a01a8d03b97afe71a247c7319c60',
             'current_rtl_sha256':hashlib.sha256((ROOT/'rtl/axi/dsm_ip_axi_top.v').read_bytes()).hexdigest(),
             'status':'PASS' if all(r['result']=='PASS' for r in records) else 'FAIL','results':records}
    (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps({'status':summary['status'],'results':[{k:r[k] for k in ('variant','case','result','log')} for r in records]},indent=2))
    return 0 if summary['status']=='PASS' else 1

if __name__=='__main__': raise SystemExit(main())

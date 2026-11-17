#!/usr/bin/env python3
"""Run fresh Vivado experiments serially after the baseline Runtime route."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys
import time

root=Path(__file__).resolve().parents[2]
out=(root/sys.argv[1]).resolve()
if root/'runs' not in out.parents:raise ValueError('new output must be below runs')
out.mkdir(parents=True,exist_ok=False)
def win(p):return subprocess.check_output(['wslpath','-w',str(p.resolve())],text=True).strip()
files=['research/vcu118_arch/run_ppa_cubic_candidate.tcl','research/vcu118_arch/run_ppa_ef1_cdc_bound.tcl','research/vcu118_arch/cubic_midpoint_candidate_a.sv','research/vcu118_arch/cubic_midpoint_candidate_b.sv','research/vcu118_arch/sim_live_axis_gty.tcl','dv/verif/integration/vcu118_arch/tb_vcu118_live_axis_gty.sv']
manifest={'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'status':subprocess.check_output(['git','status','--porcelain'],cwd=root,text=True).splitlines(),'source_sha256':{f:hashlib.sha256((root/f).read_bytes()).hexdigest() for f in files}}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
driver=root/'runs/vcu118_ppa_research_01_driver.log'
while not re.search(r'^CASE runtime EXIT (-?\d+)$',driver.read_text(errors='replace'),re.M):time.sleep(30)
results={}
def launch(name,tcl,args):
 work=out/name;work.mkdir()
 cmd='@echo off\r\ncd /d "'+win(work)+'"\r\nset "PATH=D:\\AMDDesignTools\\2026.1\\Vivado\\bin;%PATH%"\r\ncall D:\\AMDDesignTools\\2026.1\\Vivado\\bin\\vivado.bat -mode batch -source "'+win(root/tcl)+'" -tclargs '+args+'\r\nexit /b %errorlevel%\r\n'
 script=work/'run.cmd';script.write_bytes(cmd.encode('ascii'))
 with (work/'console.log').open('wb') as log:
  result=subprocess.run(['cmd.exe','/d','/c',win(script)],cwd=work,stdout=log,stderr=subprocess.STDOUT)
 results[name]=result.returncode
 (out/'results.json').write_text(json.dumps(results,indent=2)+'\n')
 print(name,'EXIT',result.returncode,flush=True)
# Bound only the proved bundled-data path; do not silently waive other CDCs.
formal=root/'runs/mailbox_capture_formal_01/properties.txt'
preempt=root/'runs/ef1_cdc_candidate_preempt_01/result.json'
if preempt.exists() and json.loads(preempt.read_text()).get('exit_code')==0:
 results['ef1_cdc_bound']='COMPLETED_IN_PREEMPT_RUN'
 (out/'results.json').write_text(json.dumps(results,indent=2)+'\n')
elif formal.exists() and all(re.search(r'proven[^\n]*'+n,formal.read_text(errors='replace')) for n in ('a_cfg_mailbox_hold','a_capture_matches','a_sample_stable')):
 launch('ef1_cdc_bound','research/vcu118_arch/run_ppa_ef1_cdc_bound.tcl','ef1 "'+win(out/'ef1_cdc_bound_run')+'" a')
else:
 results['ef1_cdc_bound']='BLOCKED_PENDING_FULL_FORMAL'
 (out/'results.json').write_text(json.dumps(results,indent=2)+'\n')
for candidate in ('a','b'):
 launch('mash_'+candidate,'research/vcu118_arch/run_ppa_cubic_candidate.tcl','mash "'+win(out/('mash_'+candidate+'_run'))+'" '+candidate)

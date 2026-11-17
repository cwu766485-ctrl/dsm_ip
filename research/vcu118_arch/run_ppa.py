#!/usr/bin/env python3
"""Launch four isolated, non-overwriting Windows Vivado research runs from WSL."""
import argparse
from pathlib import Path
import subprocess
import json
import hashlib
import sys

ROOT=Path(__file__).resolve().parents[2]
def win(p):return subprocess.check_output(['wslpath','-w',str(p.resolve())],text=True).strip()
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--out',type=Path,required=True);ap.add_argument('--cases',nargs='+',default=['ef1','ef2','mash','runtime']);a=ap.parse_args()
 out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 source=ROOT/'research/vcu118_arch/run_ppa.tcl'
 (out/'manifest.json').write_text(json.dumps({'base_sha':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'cases':a.cases,'tcl_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'part':'xcvu9p-flga2104-2L-e','exceptions':'none added','io_budget_ns':0.2},indent=2)+'\n')
 statuses={}
 for case in a.cases:
  launch=out/(case+'.cmd')
  command='@echo off\r\ncall D:\\AMDDesignTools\\2026.1\\Vivado\\bin\\vivado.bat -mode batch -source "'+win(source)+'" -tclargs '+case+' "'+win(out/case)+'"\r\nexit /b %errorlevel%\r\n'
  launch.write_bytes(command.encode('ascii'))
  with (out/(case+'.console.log')).open('wb') as log:
   result=subprocess.run(['cmd.exe','/d','/c',win(launch)],cwd=out,stdout=log,stderr=subprocess.STDOUT)
  statuses[case]=result.returncode
  print('CASE',case,'EXIT',result.returncode,flush=True)
 (out/'exit_status.json').write_text(json.dumps(statuses,indent=2)+'\n')
 if any(statuses.values()):sys.exit(1)
if __name__=='__main__':main()

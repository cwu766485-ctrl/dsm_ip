#!/usr/bin/env python3
"""Run the canonical runtime UVM suite with Vivado XSim (Windows or WSL)."""
import argparse
import json
import os
import re
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[3]

def winpath(p):
    p=str(p)
    if os.name=='nt':return p
    return subprocess.check_output(['wslpath','-w',p],text=True).strip()

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--vectors',type=Path,required=True)
    ap.add_argument('--vivado',default='D:\\AMDDesignTools\\2026.1\\Vivado')
    ap.add_argument('--words',type=int,default=56)
    ap.add_argument('--beats',type=int,default=32)
    ap.add_argument('--seed',type=int,default=101)
    ap.add_argument('--xpm',action='store_true',help='Use the product XPM CDC FIFO rather than Generic FIFO')
    ap.add_argument('--legacy-suite',action='store_true',help='Run the six existing legal parallel-SKU UVM tests')
    ap.add_argument('--reuse',action='store_true',help='Reuse an already elaborated runtime snapshot')
    a=ap.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=a.reuse)
    def run(name,args):
        # A batch file avoids the nested PowerShell/cmd quoting boundary.
        script=out/(name+'.cmd')
        script.write_bytes(('@echo off\r\ncall '+a.vivado+'\\bin\\'+args+'\r\nexit /b %errorlevel%\r\n').encode())
        with (out/(name+'.log')).open('wb') as log:
            subprocess.run(['cmd.exe','/d','/c',winpath(script)],cwd=out,stdout=log,stderr=subprocess.STDOUT,check=True)
        if re.search(r'^(ERROR:|Error:|Fatal:|FATAL_ERROR:)', (out/(name+'.log')).read_text(errors='replace'), re.MULTILINE):
            raise RuntimeError('XSim reported an error in '+name)
    if not a.reuse:
        entries=Path(ROOT/'dv/uvm/sim/thermo5_sku_filelist.f').read_text().splitlines()
        includes=[s[8:] for s in entries if s.startswith('+incdir+')]
        entries=[s for s in entries if s.startswith('rtl/') or (a.legacy_suite and s.startswith('dv/'))]
        if not a.legacy_suite:entries+=['dv/uvm/agent/interfaces/thermo5_runtime_if.sv','dv/uvm/env/thermo5_runtime/thermo5_runtime_uvm_pkg.sv','dv/uvm/tb/thermo5_runtime_uvm_tb.sv']
        args='xvlog.bat -sv -L uvm -i "'+winpath(ROOT/'dv/uvm/tests/thermo5_runtime')+'" '
        args+=' -i "'+a.vivado+'\\data\\system_verilog\\uvm_1.2" '
        if a.legacy_suite:
            args+=' -d THERMO5_XSIM -d THERMO5_CENTERED_CUBIC -d "THERMO5_TIDSM_ORDER=2" -d "THERMO5_STEP=5120" '
            args+=' '.join('-i "'+winpath(ROOT/i)+'"' for i in includes)+' '
        args+=' '.join('"'+winpath(ROOT/s)+'"' for s in entries)
        if a.xpm:
            args+=' -d THERMO5_XPM_FIFO '+a.vivado+'\\data\\verilog\\src\\glbl.v '
            args+=' '.join(a.vivado+'\\data\\ip\\xpm\\'+n+'\\hdl\\'+n+'.sv' for n in ('xpm_cdc','xpm_memory','xpm_fifo'))
        run('compile',args)
        top='thermo5_sku_uvm_tb' if a.legacy_suite else 'thermo5_runtime_uvm_tb'
        run('elaborate','xelab.bat work.'+top+(' glbl' if a.xpm else '')+' -L uvm -s runtime -debug typical -timescale 1ns/1ps')
    plus={'VEC_DIR':winpath(a.vectors.resolve()).replace('\\','/'),'CAP_DIR':winpath(out).replace('\\','/'),
          'CORE_WORDS':a.words,'SOURCE_BEATS':a.beats,'UVM_TESTNAME':'thermo5_runtime_switch_test'}
    tests=['thermo5_runtime_switch_test']
    if a.legacy_suite:
        tests=['thermo5_sku_'+n+'_test' for n in ('bittrue','bubble_backpressure','fifo_boundary','fifo_empty','reset','reset_sweep')]
    for index,test in enumerate(tests):
        plus['UVM_TESTNAME']=test
        label='simulation' if not a.legacy_suite else test
        extra=' -testplusarg STRESS_PA_READY' if a.legacy_suite and index==0 else ''
        run(label,'xsim.bat runtime -runall -sv_seed '+str(a.seed)+' '+' '.join('-testplusarg "'+k+'='+str(v)+'"' for k,v in plus.items())+extra)
        text=(out/(label+'.log')).read_text(errors='replace')
        marker='SKU_PASS' if a.legacy_suite else 'RUNTIME_PRODUCT_PASS'
        if marker not in text or not re.search(r'UVM_ERROR\s*:\s*0',text) or not re.search(r'UVM_FATAL\s*:\s*0',text):
            raise RuntimeError('UVM did not pass; inspect '+str(out/(label+'.log')))
    (out/'run_manifest.json').write_text(json.dumps(vars(a),default=str,indent=2)+'\n')
    print(('LEGACY_SUITE_PASS ' if a.legacy_suite else 'RUNTIME_PRODUCT_PASS ')+str(out))

if __name__=='__main__':main()

#!/usr/bin/env python3
"""Run one compile-time Thermo5 DSM configuration against the PA Golden."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[3]

def winpath(path):
    value=str(path)
    if os.name=="nt": return value
    return subprocess.check_output(["wslpath","-w",value],text=True).strip()

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--arch",type=int,choices=(0,1,2),required=True)
    ap.add_argument("--out",type=Path,required=True)
    ap.add_argument("--vectors",type=Path,required=True)
    ap.add_argument("--words",type=int,default=56)
    ap.add_argument("--beats",type=int,default=32)
    ap.add_argument("--seed",type=int,default=610216)
    ap.add_argument("--xpm",action="store_true")
    ap.add_argument("--vivado",default="D:\\AMDDesignTools\\2026.1\\Vivado")
    args=ap.parse_args()
    out=args.out.resolve()
    out.mkdir(parents=True,exist_ok=False)
    if args.words != 56 or args.beats != 32:
        raise ValueError("the directed compile-time regression is fixed at 32 AXIS beats / 56 PA words")

    def run(name,command):
        script=out/(name+".cmd")
        script.write_bytes(("@echo off\r\ncall "+args.vivado+"\\bin\\"+command+"\r\nexit /b %errorlevel%\r\n").encode())
        with (out/(name+".log")).open("wb") as log:
            subprocess.run(["cmd.exe","/d","/c",winpath(script)],cwd=out,stdout=log,
                           stderr=subprocess.STDOUT,check=True)
        content=(out/(name+".log")).read_text(errors="replace")
        if re.search(r"^(ERROR:|Error:|Fatal:|FATAL_ERROR:)",content,re.M):
            raise RuntimeError("Vivado/XSim reported an error in "+name)
        return content

    entries=(ROOT/"dv/uvm/sim/thermo5_sku_filelist.f").read_text().splitlines()
    includes=[line[8:] for line in entries if line.startswith("+incdir+")]
    rtl=[line for line in entries if line.startswith("rtl/")]
    rtl.extend([
        "dv/uvm/agent/interfaces/thermo5_runtime_if.sv",
        "dv/uvm/env/thermo5_runtime/thermo5_runtime_uvm_pkg.sv",
        "dv/uvm/tb/thermo5_compiletime_uvm_tb.sv",
    ])
    # xvlog's -d consumes one macro token; a separate value after '=' is
    # interpreted as another source file by the bundled XSim parser. Use a
    # valueless architecture selector and map it to an integer in the TB.
    args_compile="xvlog.bat -sv -L uvm -d THERMO5_XSIM -d COMPILETIME_ARCH_"+str(args.arch)+" "
    args_compile+=' -i "'+winpath(ROOT/"dv/uvm/tests/thermo5_runtime")+'" '
    args_compile+=' -i "'+args.vivado+'\\data\\system_verilog\\uvm_1.2" '
    args_compile+=' '.join('-i "'+winpath(ROOT/item)+'"' for item in includes)+' '
    args_compile+=' '.join('"'+winpath(ROOT/item)+'"' for item in rtl)
    if args.xpm:
        args_compile+=' -d THERMO5_XPM_FIFO '+args.vivado+'\\data\\verilog\\src\\glbl.v '
        args_compile+=' '.join(args.vivado+'\\data\\ip\\xpm\\'+name+'\\hdl\\'+name+'.sv'
                               for name in ("xpm_cdc","xpm_memory","xpm_fifo"))
    run("compile",args_compile)
    run("elaborate","xelab.bat work.thermo5_compiletime_uvm_tb"+
        (" glbl" if args.xpm else "")+
        " -L uvm -s compiletime_arch"+str(args.arch)+" -debug typical -timescale 1ns/1ps")
    for vector in args.vectors.resolve().glob("*.mem"):
        shutil.copy2(vector,out/vector.name)
    sim="xsim.bat compiletime_arch"+str(args.arch)+" --runall --sv_seed "+str(args.seed)
    log=run("simulation",sim)
    if "COMPILE_TIME_PRODUCT_PASS" not in log or not re.search(r"UVM_ERROR\s*:\s*0",log) or \
       not re.search(r"UVM_FATAL\s*:\s*0",log):
        raise RuntimeError("Compile-time Golden regression did not pass; inspect "+str(out/"simulation.log"))
    manifest={"architecture":args.arch,"words":args.words,"source_beats":args.beats,
              "seed":args.seed,"xpm":args.xpm,"vectors":str(args.vectors.resolve()),
              "vivado":args.vivado}
    (out/"run_manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print("COMPILE_TIME_PRODUCT_PASS "+str(out))

if __name__=="__main__": main()

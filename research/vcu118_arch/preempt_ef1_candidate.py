#!/usr/bin/env python3
"""Temporarily suspend a specified ongoing Runtime Vivado process for EF1 routing."""
from pathlib import Path
import hashlib,json,subprocess,sys,os,re
root=Path(__file__).resolve().parents[2]
out=(root/sys.argv[1]).resolve();pid=int(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
if root/'runs' not in out.parents:raise ValueError('output must be under runs')
def win(p):return subprocess.check_output(['wslpath','-w',str(p.resolve())],text=True).strip()
(out/'pid').write_text(str(os.getpid())+'\n')
ps=out/'control.ps1'
ps.write_text(r'''param([string]$Action,[int]$Target)
$proc=Get-CimInstance Win32_Process -Filter "ProcessId=$Target"
if($null -eq $proc -or $proc.CommandLine -notlike '*run_ppa.tcl*runtime*'){throw 'Runtime process not found or identity mismatch'}
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class RuntimeControl {
 [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint access,bool inherit,uint id);
 [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr handle);
 [DllImport("ntdll.dll")] public static extern int NtSuspendProcess(IntPtr handle);
 [DllImport("ntdll.dll")] public static extern int NtResumeProcess(IntPtr handle);
 [DllImport("psapi.dll")] public static extern bool EmptyWorkingSet(IntPtr handle);
}
'@
$h=[RuntimeControl]::OpenProcess(0x1F0FFF,$false,$Target)
if($h -eq [IntPtr]::Zero){throw 'OpenProcess failed'}
try {
 if($Action -eq 'suspend'){$code=[RuntimeControl]::NtSuspendProcess($h);[void][RuntimeControl]::EmptyWorkingSet($h)}
 elseif($Action -eq 'resume'){$code=[RuntimeControl]::NtResumeProcess($h)} else {throw 'Unknown action'}
 if($code -ne 0){throw "Native control failed: $code"};Write-Output "RUNTIME_$Action PID=$Target"
} finally {[void][RuntimeControl]::CloseHandle($h)}
''')
# The caller starts an independent watchdog before the suspend marker.
while not (out/'watchdog_ready').exists():
 import time;time.sleep(1)
def control(action):
 return subprocess.run(['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',win(ps),action,str(pid)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,check=True).stdout
(out/'suspend.log').write_text(control('suspend'))
try:
 src=root/'research/vcu118_arch/reimplement_ef1_cdc_bound.tcl'
 candidate=root/'research/vcu118_arch/cubic_midpoint_candidate_a.sv'
 checkpoint=root/'../thermo5_vcu118_cubic_optimization/runs/optimized_ppa_ef1_01/ef1/synthesized.dcp'
 manifest={'checkpoint_sha256':hashlib.sha256(checkpoint.read_bytes()).hexdigest(),'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'target_pid':pid,'tcl_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'candidate_sha256':hashlib.sha256(candidate.read_bytes()).hexdigest()}
 (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 command='@echo off\r\ncd /d "'+win(out)+'"\r\nset "PATH=D:\\AMDDesignTools\\2026.1\\Vivado\\bin;%PATH%"\r\ncall D:\\AMDDesignTools\\2026.1\\Vivado\\bin\\vivado.bat -mode batch -source "'+win(src)+'" -tclargs ef1 "'+win(out/'implementation')+'" a\r\nexit /b %errorlevel%\r\n'
 launch=out/'run.cmd';launch.write_bytes(command.encode('ascii'))
 with (out/'console.log').open('wb') as log:result=subprocess.run(['cmd.exe','/d','/c',win(launch)],cwd=out,stdout=log,stderr=subprocess.STDOUT)
 text=(out/'console.log').read_text(errors='replace')
 complete=bool(re.search(r'^PPA_ROUTED_COMPLETE case=ef1 mode=0 candidate=a$',text,re.M))
 segmented=bool(re.search(r'^(?:ERROR|CRITICAL WARNING): \[Constraints 18-515\]',text,re.M))
 valid=result.returncode==0 and complete and not segmented
 (out/'result.json').write_text(json.dumps({'exit_code':result.returncode,'completion_marker':complete,'path_segmentation':segmented,'valid_run':valid},indent=2)+'\n')
finally:
 try:(out/'resume.log').write_text(control('resume'))
 finally:(out/'done').write_text('runtime resume attempted\n')

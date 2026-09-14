param([int]$Vectors = 128, [int]$Seed = 20260908, [string]$Python = "python", [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat")
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$settings = Join-Path (Split-Path -Parent (Split-Path -Parent $VivadoBat)) 'settings64.bat'
if (!(Test-Path $VivadoBat) -or !(Test-Path $settings)) { throw 'Vivado installation is unavailable' }
$work = Join-Path $repo 'verif\out_xsim_ti32_lp1_fs4_dsm'
New-Item -Force -ItemType Directory $work | Out-Null
& $Python (Join-Path $repo 'uvm_verif\refmodel\python\generate_ti32_lp1_fs4_vectors.py') --vectors $Vectors --seed $Seed --output (Join-Path $work 'ti32_lp1_fs4_vectors.csv')
if ($LASTEXITCODE -ne 0) { throw 'TI32 vector generation failed' }
$sources = @((Join-Path $repo 'rtl\tx_bandpass_if\ti32_lp1_fs4_dsm.sv'), (Join-Path $repo 'verif\block\bp_dsm\tb\tb_ti32_lp1_fs4_dsm.sv'))
Push-Location $work
try {
  Get-ChildItem -Force | Where-Object { $_.Name -ne 'ti32_lp1_fs4_vectors.csv' } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  $sourceArgs = ($sources | ForEach-Object { '"' + $_ + '"' }) -join ' '
  $batch = "call `"$settings`" >nul && cd /d `"$work`" && xvlog -sv $sourceArgs > console_xvlog.log 2>&1 && xelab tb_ti32_lp1_fs4_dsm -s sim_ti32_lp1 > console_xelab.log 2>&1 && xsim sim_ti32_lp1 -runall > console_xsim.log 2>&1"
  & cmd.exe /d /c $batch; $exitCode=$LASTEXITCODE
  if ($exitCode -ne 0) { Get-ChildItem -Filter '*.log' | ForEach-Object { Get-Content $_.FullName -Tail 100 }; throw "TI32 XSim failed: $exitCode" }
} finally { Pop-Location }
if (!(Select-String -Path "$work\console_xsim.log" -Pattern 'TI32_LP1_FS4_DSM_PASS' -Quiet)) { throw 'TI32 PASS marker missing' }
Write-Host "TI32 LP1 Fs/4 DSM XSim PASS: $work\console_xsim.log"

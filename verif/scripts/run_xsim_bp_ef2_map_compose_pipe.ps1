param([string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat")
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$settings = Join-Path (Split-Path -Parent (Split-Path -Parent $VivadoBat)) 'settings64.bat'
if (!(Test-Path $VivadoBat) -or !(Test-Path $settings)) { throw 'Vivado installation is unavailable' }
$work = Join-Path $repo 'verif\out_xsim_bp_dsm_map_compose_pipe'
New-Item -Force -ItemType Directory $work | Out-Null
$sources = @(
  'bp_ef2_phase_map1.sv', 'bp_ef2_map_region_select.sv',
  'bp_ef2_map_compose.sv', 'bp_ef2_phase_map4.sv',
  'bp_ef2_map_compose_pipe.sv' |
  ForEach-Object { Join-Path $repo "rtl\tx_bandpass_if\$_" }
)
$sources += Join-Path $repo 'verif\block\bp_dsm\tb\tb_bp_ef2_map_compose_pipe.sv'
Push-Location $work
try {
  Get-ChildItem -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  $args = ($sources | ForEach-Object { '"' + $_ + '"' }) -join ' '
  $cmd = Join-Path $env:TEMP ('map_pipe_' + [guid]::NewGuid().ToString() + '.cmd')
  Set-Content -Encoding ASCII $cmd ("@echo off`r`ncall `"$settings`" >nul`r`ncall xvlog -sv $args > console_xvlog.log 2>&1`r`nif errorlevel 1 exit /b 1`r`ncall xelab tb_bp_ef2_map_compose_pipe -s sim_map_pipe > console_xelab.log 2>&1`r`nif errorlevel 1 exit /b 1`r`ncall xsim sim_map_pipe -runall > console_xsim.log 2>&1")
  try { & cmd.exe /d /c $cmd; $exitCode=$LASTEXITCODE } finally { Remove-Item $cmd -Force -ErrorAction SilentlyContinue }
  if ($exitCode -ne 0) { Get-ChildItem -Filter '*.log' | ForEach-Object { Get-Content $_.FullName -Tail 100 }; throw "map compose pipe XSim failed: $exitCode" }
} finally { Pop-Location }
if (!(Select-String -Path "$work\console_xsim.log" -Pattern 'BP_EF2_MAP_COMPOSE_PIPE_PASS' -Quiet)) { Get-Content "$work\console_xsim.log" -Tail 100; throw 'PASS marker missing' }
Write-Host "BP EF2 map compose pipe XSim PASS: $work\console_xsim.log"

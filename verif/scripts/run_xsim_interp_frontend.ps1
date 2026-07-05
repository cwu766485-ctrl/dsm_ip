param(
  [switch]$SkipMatlabPrep
)

$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$vivadoSettings = "D:\Xilinx\Vivado\2024.1\settings64.bat"
if (-not (Test-Path $vivadoSettings)) {
  throw "Vivado settings not found at $vivadoSettings. Update run_xsim_interp_frontend.ps1."
}

$work = Join-Path $repo "verif\out_xsim_interp_frontend"
New-Item -ItemType Directory -Force -Path $work | Out-Null

if (-not $SkipMatlabPrep) {
  matlab -batch "cd('$($repo.Replace('\','/'))/matlab'); path_setup; prepare_interp_frontend_bittrue_vectors('n_input',128);"
  if ($LASTEXITCODE -ne 0) { throw "MATLAB vector preparation failed" }
}

Copy-Item (Join-Path $repo "matlab\out\interp_frontend\bittrue\interp_input_iq.csv") (Join-Path $work "interp_input_iq.csv") -Force

Set-Location $work
$filelist = Join-Path $work "filelist_p0_abs.f"
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "verif\scripts\filelist_p0_abs.ps1") -RepoRoot $repo -OutFile $filelist

function Invoke-VivadoCmd($cmd) {
  $log = $null
  if ($cmd -like "xvlog *") {
    $log = Join-Path (Get-Location) "xvlog.log"
  } elseif ($cmd -like "xelab *") {
    $log = Join-Path (Get-Location) "xelab.log"
  } elseif ($cmd -like "xsim *") {
    $log = Join-Path (Get-Location) "xsim.log"
  }
  if ($log) {
    Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue
  }

  $bat = "@echo off`r`n" +
         "call `"$vivadoSettings`" >nul`r`n" +
         "$cmd`r`n"
  $tmp = Join-Path $env:TEMP ("run_xsim_interp_" + [guid]::NewGuid().ToString() + ".cmd")
  Set-Content -Path $tmp -Value $bat -Encoding ASCII
  try {
    cmd.exe /c $tmp
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $cmd" }
    if ($log -and (Test-Path -LiteralPath $log)) {
      $errors = Select-String -LiteralPath $log -Pattern "ERROR:" -SimpleMatch
      if ($errors) {
        throw "Vivado reported errors while running: $cmd"
      }
    }
  } finally {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  }
}

Write-Host "[xsim] xvlog compile interp frontend"
$tb = Join-Path $repo "verif\tb\tb_interp_frontend.sv"
Invoke-VivadoCmd "xvlog -sv -f `"$filelist`" `"$tb`""

Write-Host "[xsim] xelab tb_interp_frontend"
Invoke-VivadoCmd "xelab -debug typical tb_interp_frontend -s sim_tb_interp_frontend"

Write-Host "[xsim] xsim tb_interp_frontend"
Invoke-VivadoCmd "xsim sim_tb_interp_frontend -runall"

Write-Host "[xsim] interp frontend done. Outputs in $work"

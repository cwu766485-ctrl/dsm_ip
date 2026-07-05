param(
  [switch]$SkipSummary
)

$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$vivadoSettings = "D:\Xilinx\Vivado\2024.1\settings64.bat"
if (-not (Test-Path $vivadoSettings)) {
  throw "Vivado settings not found at $vivadoSettings. Update run_xsim_p0_multibit.ps1."
}

$work = Join-Path $repo "verif\out_xsim_p0_multibit"
New-Item -ItemType Directory -Force -Path $work | Out-Null

$vecDir = Join-Path $repo "verif\vectors\p0"
Copy-Item (Join-Path $vecDir "rom_i.mem") (Join-Path $work "rom_i.mem") -Force
Copy-Item (Join-Path $vecDir "rom_q.mem") (Join-Path $work "rom_q.mem") -Force

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
  $tmp = Join-Path $env:TEMP ("run_xsim_p0_multibit_" + [guid]::NewGuid().ToString() + ".cmd")
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

Write-Host "[xsim] xvlog compile multibit"
$inc = Join-Path $repo "verif\tb"
$tb = Join-Path $repo "verif\tb\tb_p0_multibit_all.sv"
Invoke-VivadoCmd "xvlog -sv -i `"$inc`" -f `"$filelist`" `"$tb`""

Write-Host "[xsim] xelab tb_p0_multibit_all"
Invoke-VivadoCmd "xelab -debug typical tb_p0_multibit_all -s sim_tb_p0_multibit_all"

Write-Host "[xsim] xsim tb_p0_multibit_all"
Invoke-VivadoCmd "xsim sim_tb_p0_multibit_all -runall"

if (-not $SkipSummary) {
  Write-Host "[summary] write multibit regression summary"
  powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "verif\scripts\write_regression_summary.ps1") `
    -RunDir $work `
    -OutCsv (Join-Path $work "summary.csv")
}

Write-Host "[xsim] multibit done. Outputs in $work"

param(
  [switch]$SkipSummary
)

$ErrorActionPreference = "Stop"

# Run RTL sims for the P0 structures using Vivado XSim.
# Included tops:
#   - tb_p0_lp1
#   - tb_p0_lp2
#   - tb_p0_ef1
#   - tb_p0_ef2
#   - tb_p0_mash11_mb
#   - tb_p0_mash111_mb
#   - tb_p0_mash22_mb

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

$vivadoSettings = "D:\Xilinx\Vivado\2024.1\settings64.bat"
if (-not (Test-Path $vivadoSettings)) {
  throw "Vivado settings not found at $vivadoSettings. Update run_xsim_p0_all.ps1."
}

$work = Join-Path $repo "verif\out_xsim_p0"
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
  $tmp = Join-Path $env:TEMP ("run_xsim_" + [guid]::NewGuid().ToString() + ".cmd")
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

Write-Host "[xsim] xvlog compile"
$inc = Join-Path $repo "verif\tb"
Invoke-VivadoCmd "xvlog -sv -i `"$inc`" -f `"$filelist`" `"$repo\verif\tb\tb_p0_lp1.sv`" `"$repo\verif\tb\tb_p0_lp2.sv`" `"$repo\verif\tb\tb_p0_ef1.sv`" `"$repo\verif\tb\tb_p0_ef2.sv`" `"$repo\verif\tb\tb_p0_mash11_mb.sv`" `"$repo\verif\tb\tb_p0_mash111_mb.sv`" `"$repo\verif\tb\tb_p0_mash22_mb.sv`""

$tops = @(
  @{ top="tb_p0_lp1"; out="sim_bits_01_lp1.txt" },
  @{ top="tb_p0_lp2"; out="sim_bits_01_lp2.txt" },
  @{ top="tb_p0_ef1"; out="sim_bits_01_ef1.txt" },
  @{ top="tb_p0_ef2"; out="sim_bits_01_ef2.txt" },
  @{ top="tb_p0_mash11_mb"; out="sim_yout_signed_mash11_mb.txt" },
  @{ top="tb_p0_mash111_mb"; out="sim_yout_signed_mash111_mb.txt" },
  @{ top="tb_p0_mash22_mb"; out="sim_yout_signed_mash22_mb.txt" }
)

foreach ($t in $tops) {
  Write-Host "[xsim] xelab $($t.top)"
  Invoke-VivadoCmd "xelab -debug typical $($t.top) -s sim_$($t.top)"

  Write-Host "[xsim] xsim $($t.top)"
  Invoke-VivadoCmd "xsim sim_$($t.top) -runall"
}

if (-not $SkipSummary) {
  Write-Host "[summary] write P0 regression summary"
  powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "verif\scripts\write_regression_summary.ps1") `
    -RunDir $work `
    -OutCsv (Join-Path $work "summary.csv")
}

Write-Host "[xsim] done. Outputs in $work"

param(
  [switch]$SkipSummary,
  [string]$OutDir,
  [string]$VivadoSettings = "D:\Xilinx\Vivado\2024.1\settings64.bat"
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
if (-not (Test-Path -LiteralPath $VivadoSettings -PathType Leaf)) {
  throw "Vivado settings not found at $VivadoSettings. Pass -VivadoSettings to select the installation."
}

if ([string]::IsNullOrWhiteSpace($OutDir)) {
  $OutDir = Join-Path $repo ("runs\dsm\p0_multibit_xsim_{0}" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
} elseif (-not [System.IO.Path]::IsPathRooted($OutDir)) {
  $OutDir = Join-Path $repo $OutDir
}
$work = [System.IO.Path]::GetFullPath($OutDir)
New-Item -ItemType Directory -Force -Path $work | Out-Null

$vecDir = Join-Path $repo "dv\verif\vectors\p0"
Copy-Item -LiteralPath (Join-Path $vecDir "rom_i.mem") -Destination (Join-Path $work "rom_i.mem") -Force
Copy-Item -LiteralPath (Join-Path $vecDir "rom_q.mem") -Destination (Join-Path $work "rom_q.mem") -Force
$filelist = Join-Path $work "filelist_p0_abs.f"
& (Join-Path $PSScriptRoot "filelist_p0_abs.ps1") -RepoRoot $repo -OutFile $filelist

Push-Location $work
try {
  function Invoke-VivadoCmd([string]$Command, [string]$LogName) {
    $log = Join-Path (Get-Location) $LogName
    Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue
    $cmdFile = Join-Path $env:TEMP ("run_xsim_dsm_mb_" + [guid]::NewGuid().ToString() + ".cmd")
    $batch = "@echo off`r`ncall `"$VivadoSettings`" >nul`r`n$Command`r`n"
    Set-Content -LiteralPath $cmdFile -Value $batch -Encoding ASCII
    try {
      cmd.exe /c $cmdFile
      if ($LASTEXITCODE -ne 0) { throw "Command failed: $Command" }
      if (-not (Test-Path -LiteralPath $log)) { throw "Vivado did not create $LogName" }
      if (Select-String -LiteralPath $log -Pattern "ERROR:" -SimpleMatch -Quiet) {
        throw "Vivado reported an error while running: $Command"
      }
    } finally {
      Remove-Item -LiteralPath $cmdFile -Force -ErrorAction SilentlyContinue
    }
  }

  $tbRoot = Join-Path $repo "dv\verif\tb"
  $tb = Join-Path $tbRoot "tb_p0_multibit_all.sv"
  Invoke-VivadoCmd ("xvlog -sv -i `"$tbRoot`" -f `"$filelist`" `"$tb`"") "xvlog.log"
  Invoke-VivadoCmd "xelab -debug typical tb_p0_multibit_all -s sim_tb_p0_multibit_all" "xelab.log"
  Invoke-VivadoCmd "xsim sim_tb_p0_multibit_all -runall" "xsim.log"
  $summaryPath = Join-Path $work "summary_tb_p0_multibit_all.csv"
  if (-not (Test-Path -LiteralPath $summaryPath)) {
    throw "The multibit testbench did not write its summary."
  }
  $summary = @(Import-Csv -LiteralPath $summaryPath)
  if ($summary.Count -ne 1 -or [int]$summary[0].Pass -ne 1 -or [int]$summary[0].Samples -ne 65536) {
    throw "The multibit testbench summary is not a clean 65,536-sample pass."
  }
  $dumpFiles = @(
    "sim_yout_signed_lp1_multibit.txt", "sim_yout_signed_lp2_multibit.txt",
    "sim_yout_signed_ef1_multibit.txt", "sim_yout_signed_ef2_multibit.txt",
    "sim_yout_signed_mash11_multibit.txt", "sim_yout_signed_mash111_multibit.txt",
    "sim_yout_signed_mash22_multibit.txt"
  )
  foreach ($dump in $dumpFiles) {
    $dumpPath = Join-Path $work $dump
    if (-not (Test-Path -LiteralPath $dumpPath) -or (Get-Item -LiteralPath $dumpPath).Length -eq 0) {
      throw "Missing or empty multibit result dump: $dumpPath"
    }
  }
  if (-not $SkipSummary) {
    & (Join-Path $PSScriptRoot "write_regression_summary.ps1") -RunDir $work -OutCsv (Join-Path $work "summary.csv")
  }
} finally {
  Pop-Location
}

Write-Host "DSM multibit P0 XSim regression completed. Outputs: $work"

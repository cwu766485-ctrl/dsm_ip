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
  $OutDir = Join-Path $repo ("runs\dsm\p0_xsim_{0}" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
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
  function Invoke-VivadoCmd([string]$Command) {
    $logName = if ($Command -like "xvlog *") { "xvlog.log" }
      elseif ($Command -like "xelab *") { "xelab.log" }
      elseif ($Command -like "xsim *") { "xsim.log" }
      else { $null }
    $log = if ($logName) { Join-Path (Get-Location) $logName } else { $null }
    if ($log) { Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue }
    $cmdFile = Join-Path $env:TEMP ("run_xsim_dsm_" + [guid]::NewGuid().ToString() + ".cmd")
    $batch = "@echo off`r`ncall `"$VivadoSettings`" >nul`r`n$Command`r`n"
    Set-Content -LiteralPath $cmdFile -Value $batch -Encoding ASCII
    try {
      cmd.exe /c $cmdFile
      if ($LASTEXITCODE -ne 0) { throw "Command failed: $Command" }
      if ($log -and -not (Test-Path -LiteralPath $log)) {
        throw "Vivado command returned without producing its log: $Command"
      }
      if ($log -and (Select-String -LiteralPath $log -Pattern "ERROR:" -SimpleMatch -Quiet)) {
        throw "Vivado reported an error while running: $Command"
      }
      if ($log -and (Select-String -LiteralPath $log -Pattern "Fatal:" -SimpleMatch -Quiet)) {
        throw "Simulation reported a fatal failure while running: $Command"
      }
    } finally {
      Remove-Item -LiteralPath $cmdFile -Force -ErrorAction SilentlyContinue
    }
  }

  $tbRoot = Join-Path $repo "dv\verif\tb"
  $testbenches = @("tb_p0_lp1.sv", "tb_p0_lp2.sv", "tb_p0_ef1.sv", "tb_p0_ef2.sv",
    "tb_p0_mash11_mb.sv", "tb_p0_mash111_mb.sv", "tb_p0_mash22_mb.sv")
  $tbArgs = ($testbenches | ForEach-Object { '"' + (Join-Path $tbRoot $_) + '"' }) -join " "
  Invoke-VivadoCmd ("xvlog -sv -i `"$tbRoot`" -f `"$filelist`" $tbArgs")

  $tops = @(
    @{ top = "tb_p0_lp1"; out = "sim_bits_01_lp1.txt" },
    @{ top = "tb_p0_lp2"; out = "sim_bits_01_lp2.txt" },
    @{ top = "tb_p0_ef1"; out = "sim_bits_01_ef1.txt" },
    @{ top = "tb_p0_ef2"; out = "sim_bits_01_ef2.txt" },
    @{ top = "tb_p0_mash11_mb"; out = "sim_yout_signed_mash11_mb.txt" },
    @{ top = "tb_p0_mash111_mb"; out = "sim_yout_signed_mash111_mb.txt" },
    @{ top = "tb_p0_mash22_mb"; out = "sim_yout_signed_mash22_mb.txt" }
  )
  foreach ($test in $tops) {
    Remove-Item -LiteralPath (Join-Path $work $test.out) -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $work ("summary_{0}.csv" -f $test.top)) -Force -ErrorAction SilentlyContinue
    Invoke-VivadoCmd ("xelab -debug typical {0} -s sim_{0}" -f $test.top)
    Invoke-VivadoCmd ("xsim sim_{0} -runall" -f $test.top)
    if (-not (Test-Path -LiteralPath (Join-Path $work $test.out))) {
      throw "Testbench did not produce fresh output: $($test.top)"
    }
    $summaryPath = Join-Path $work ("summary_{0}.csv" -f $test.top)
    if (-not (Test-Path -LiteralPath $summaryPath)) {
      throw "Testbench did not produce fresh summary: $($test.top)"
    }
    $summary = @(Import-Csv -LiteralPath $summaryPath)
    if ($summary.Count -ne 1 -or [int]$summary[0].Pass -ne 1 -or
        [int]$summary[0].Samples -ne 65536 -or [int]$summary[0].Errors -ne 0) {
      throw "Testbench summary is not a clean 65,536-sample pass: $($test.top)"
    }
  }
  if (-not $SkipSummary) {
    & (Join-Path $PSScriptRoot "write_regression_summary.ps1") -RunDir $work -OutCsv (Join-Path $work "summary.csv")
  }
} finally {
  Pop-Location
}

Write-Host "DSM P0 XSim regression completed. Outputs: $work"

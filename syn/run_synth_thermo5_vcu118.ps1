param(
  [string]$Part = 'xcvu9p-flga2104-2L-e',
  [string]$VivadoBat = 'D:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat',
  [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (!(Test-Path -LiteralPath $VivadoBat)) {
  throw "Vivado is unavailable: $VivadoBat"
}
if ([string]::IsNullOrWhiteSpace($OutDir)) {
  $OutDir = Join-Path $repo "runs\thermo5_vcu118_synth_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
} else {
  $OutDir = [System.IO.Path]::GetFullPath($OutDir)
  if (Test-Path -LiteralPath $OutDir) {
    throw "Refusing to reuse existing output directory: $OutDir"
  }
}
New-Item -ItemType Directory -Path $OutDir | Out-Null
$OutDir = (Resolve-Path -LiteralPath $OutDir).Path
$tcl = Join-Path $PSScriptRoot 'run_synth_thermo5_vcu118.tcl'
$log = Join-Path $OutDir 'vivado.log'
$stderr = Join-Path $OutDir 'vivado.stderr.log'
$arguments = @('-mode', 'batch', '-source', $tcl, '-tclargs', $Part, $OutDir)
$process = Start-Process -FilePath $VivadoBat -ArgumentList $arguments -Wait -PassThru `
  -NoNewWindow -RedirectStandardOutput $log -RedirectStandardError $stderr
$vivadoExit = $process.ExitCode
if (Test-Path -LiteralPath $stderr) {
  Add-Content -LiteralPath $log -Value (Get-Content -LiteralPath $stderr)
  Remove-Item -LiteralPath $stderr
}
if ($vivadoExit -ne 0) {
  throw "Thermo5 VCU118 synthesis failed: exit=$vivadoExit; inspect $log"
}
if (!(Select-String -LiteralPath $log -Pattern 'THERMO5_VCU118_SYNTH_STATUS=PASS' -Quiet)) {
  throw "Thermo5 VCU118 synthesis PASS marker missing; inspect $log"
}
foreach ($artifact in @('synthesized.dcp', 'synth_utilization.rpt', 'synth_timing_summary.rpt')) {
  if (!(Test-Path -LiteralPath (Join-Path $OutDir $artifact))) {
    throw "Expected synthesis artifact is missing: $artifact"
  }
}
$gitExe = (Get-Command git.exe -ErrorAction SilentlyContinue).Source
if ([string]::IsNullOrWhiteSpace($gitExe) -and (Test-Path -LiteralPath 'D:\Git\cmd\git.exe')) {
  $gitExe = 'D:\Git\cmd\git.exe'
}
if ([string]::IsNullOrWhiteSpace($gitExe)) { throw 'Git for Windows was not found to record the smoke source SHA.' }
$gitShaFile = Join-Path $OutDir 'source_commit.txt'
$gitProcess = Start-Process -FilePath $gitExe -ArgumentList @('-C', $repo, 'rev-parse', 'HEAD') `
  -Wait -PassThru -NoNewWindow -RedirectStandardOutput $gitShaFile
$sourceCommit = (Get-Content -LiteralPath $gitShaFile -Raw).Trim()
if ($gitProcess.ExitCode -ne 0 -or $sourceCommit -notmatch '^[0-9a-f]{40}$') {
  throw 'Unable to record the smoke source commit SHA.'
}
@(
  "SOURCE_COMMIT=$sourceCommit"
  "VIVADO=$VivadoBat"
  "PART=$Part"
  'TOP=tid32_thermo5_axis_frontend_tx'
  'INTERP_TAPS=2'
  'DPD_MAX_TAPS=1'
  'FPGA_USE_XPM_FIFO=1'
  "OUTPUT=$OutDir"
) | Set-Content -LiteralPath (Join-Path $OutDir 'smoke_manifest.txt')
Write-Host "THERMO5_VCU118_SYNTH_PASS part=$Part top=tid32_thermo5_axis_frontend_tx output=$OutDir"

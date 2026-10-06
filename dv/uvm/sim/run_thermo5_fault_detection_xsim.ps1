param([string]$RunId = '')
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$settings = 'D:\Xilinx\Vivado\2024.1\settings64.bat'
$vectors = Join-Path $repo 'runs\uvm_thermo5_i2_d1\vectors'
if ($RunId -eq '') { $RunId = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ') }
$runRoot = Join-Path $repo "runs\thermo5_fault_detection_xsim_$RunId"
if (!(Test-Path -LiteralPath $settings)) { throw "Vivado settings unavailable: $settings" }
if (!(Test-Path -LiteralPath (Join-Path $vectors 'tid32_thermo5_frontend_pa3.mem'))) {
  throw "MATLAB vectors unavailable: $vectors"
}
if (Test-Path -LiteralPath $runRoot) { throw "Refusing to reuse run directory: $runRoot" }
New-Item -ItemType Directory -Path $runRoot | Out-Null

$relativeRtl = @(
  'rtl\axis\dsm_reset_sync.sv',
  'rtl\axis\dsm_frame_power_ctrl.sv',
  'rtl\axis\dsm_async_fifo.sv',
  'rtl\axis\dsm_xpm_async_fifo.sv',
  'rtl\axis\dsm_axis14_to_core8_cdc.sv',
  'rtl\frontend\dsm_frame_gain_vector.sv',
  'rtl\gt\gt_tx_user_bridge.sv',
  'rtl\gt\gt_tx_raw64_boundary.sv',
  'rtl\tx_bandpass_if\tid32_cartesian_fs4_gt_tx.sv',
  'rtl\tx_bandpass_if\tid32_thermo5_fs4_multipa_tx.sv',
  'rtl\tx_bandpass_if\tid32_thermo5_frontend_tx.sv',
  'rtl\tx_bandpass_if\tid32_thermo5_axis_frontend_tx.sv',
  'rtl\dpd\dpd_poly.v',
  'rtl\dpd\dpd_memory_poly.v',
  'rtl\dpd\dpd_vector16_memory_poly.sv',
  'rtl\dpd\dpd_vector_elastic_buffer.sv',
  'rtl\interp\dsm_interp_x2_polyphase_vector.sv'
)
$directedTb = Join-Path $repo 'dv\verif\subsystem\tx_frontend\tb\tb_thermo5_i2_d1_axis_bittrue.sv'
$fifoTb = Join-Path $PSScriptRoot 'thermo5_fault_stale_fifo_tb.sv'

function Quote-Arg([string]$Value) { return '"' + $Value + '"' }

function Invoke-XsimCase {
  param(
    [string]$CaseDir,
    [string[]]$Sources,
    [string]$Top,
    [string]$Seed,
    [switch]$Stress
  )
  New-Item -ItemType Directory -Force -Path $CaseDir | Out-Null
  if ($Top -eq 'tb_thermo5_i2_d1_axis_bittrue') {
    Copy-Item -Path (Join-Path $vectors '*.mem') -Destination $CaseDir -Force
  }
  $quotedSources = ($Sources | ForEach-Object { Quote-Arg $_ }) -join ' '
  $compile = "call `"$settings`" >nul && xvlog -sv $quotedSources > console_xvlog.log 2>&1 && xelab $Top -s sim_$Top > console_xelab.log 2>&1"
  $runArgs = "xsim sim_$Top -runall -sv_seed $Seed"
  if ($Stress) { $runArgs += ' -testplusarg STRESS_PA_READY' }
  $run = "call `"$settings`" >nul && $runArgs > console_xsim.log 2>&1"
  Set-Content -LiteralPath (Join-Path $CaseDir 'commands.txt') -Value @("cmd.exe /d /c $compile", "cmd.exe /d /c $run") -Encoding ASCII
  Push-Location $CaseDir
  try {
    cmd.exe /d /c $compile
    $compileExit = $LASTEXITCODE
    Set-Content -LiteralPath 'compile.exit' -Value $compileExit -Encoding ASCII
    if ($compileExit -ne 0) { throw "XSim compile/elaboration failed in $CaseDir" }
    cmd.exe /d /c $run
    $runExit = $LASTEXITCODE
    Set-Content -LiteralPath 'run.exit' -Value $runExit -Encoding ASCII
    if ($runExit -ne 0) { throw "XSim run command failed in $CaseDir (exit=$runExit)" }
  } finally { Pop-Location }
  return (Get-Content -Raw (Join-Path $CaseDir 'console_xsim.log'))
}

function Get-RtlSources([string]$CaseDir, [string]$MutantPath = '', [string]$MutantRelative = '') {
  $result = foreach ($relative in $relativeRtl) {
    if ($relative -eq $MutantRelative) { $MutantPath }
    else { Join-Path $repo $relative }
  }
  $result += $directedTb
  return ,$result
}

function Stage-Mutant([string]$CaseDir, [string]$RelativePath, [string]$Old, [string]$New) {
  $source = Join-Path $repo $RelativePath
  $dest = Join-Path $CaseDir (Join-Path 'rtl_copy' (Split-Path $RelativePath -Leaf))
  New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
  $content = [System.IO.File]::ReadAllText($source)
  if (!$content.Contains($Old)) { throw "Mutation anchor not found in canonical source: $RelativePath" }
  $mutated = $content.Replace($Old, $New)
  if ($mutated -eq $content) { throw "Mutation did not change source: $RelativePath" }
  [System.IO.File]::WriteAllText($dest, $mutated, [System.Text.UTF8Encoding]::new($false))
  return $dest
}

@(
  "run_id=$RunId",
  "simulator=Vivado XSim 2024.1",
  "root=$repo",
  "vectors=$vectors",
  'suite=directed four-plane bit-true test with seed 1 and STRESS_PA_READY; generic FIFO reset probe'
) | Set-Content -LiteralPath (Join-Path $runRoot 'manifest.txt') -Encoding ASCII

# Build and run the unmodified direct test once. Every datapath mutant below
# uses this exact testbench, seed, and PA-ready schedule as its clean control.
$baselineDir = Join-Path $runRoot 'baseline_bittrue'
$baselineLog = Invoke-XsimCase -CaseDir $baselineDir -Sources (Get-RtlSources $baselineDir) `
  -Top 'tb_thermo5_i2_d1_axis_bittrue' -Seed '1' -Stress
if ($baselineLog -notmatch 'THERMO5_I2_D1_AXIS_BITTRUE_PASS' -or
    $baselineLog -match '(?m)(Fatal:|ERROR:|FATAL_ERROR:)') {
  throw "Clean directed baseline failed: $baselineDir\console_xsim.log"
}

$mutants = @(
  [pscustomobject]@{
    Name='swap_plane'; Relative='rtl\tx_bandpass_if\tid32_thermo5_fs4_multipa_tx.sv'
    Old='.gt_data(pa_data[b])'; New='.gt_data(pa_data[3-b])'
    Expected='word=\d+ plane=\d+ got='; Description='Swap branch-to-PA-plane mapping.'
  },
  [pscustomobject]@{
    Name='drop_stall'; Relative='rtl\gt\gt_tx_user_bridge.sv'
    Old='end else if (in_ready) begin'; New='end else begin'
    Expected='valid dropped on output stall|plane\d+ changed on stall'; Description='Overwrite a held output while downstream ready is low.'
  },
  [pscustomobject]@{
    Name='late_gain'; Relative='rtl\frontend\dsm_frame_gain_vector.sv'
    Old='s0_gain <= in_frame_start ? in_frame_gain : active_gain;'; New='s0_gain <= active_gain;'
    Expected='word=\d+ plane=\d+ got='; Description='Use the previous active gain on the accepted frame-start word.'
  }
)

$resultRows = [System.Collections.Generic.List[string]]::new()
$resultRows.Add('mutant,compile,baseline,test_seed,first_failure,pass_marker_absent')
foreach ($mutant in $mutants) {
  $dir = Join-Path $runRoot $mutant.Name
  New-Item -ItemType Directory -Path $dir | Out-Null
  $staged = Stage-Mutant -CaseDir $dir -RelativePath $mutant.Relative -Old $mutant.Old -New $mutant.New
  @("fault=$($mutant.Description)", "source=$($mutant.Relative)", 'test=tb_thermo5_i2_d1_axis_bittrue', 'seed=1', 'plusarg=STRESS_PA_READY') |
    Set-Content -LiteralPath (Join-Path $dir 'mutant.txt') -Encoding ASCII
  $sources = Get-RtlSources -CaseDir $dir -MutantPath $staged -MutantRelative $mutant.Relative
  $log = Invoke-XsimCase -CaseDir $dir -Sources $sources -Top 'tb_thermo5_i2_d1_axis_bittrue' -Seed '1' -Stress
  if ($log -notmatch $mutant.Expected -or $log -match 'THERMO5_I2_D1_AXIS_BITTRUE_PASS') {
    throw "Mutant did not fail the intended checker before PASS: $($mutant.Name); see $dir\console_xsim.log"
  }
  $first = ($log -split "`r?`n" | Where-Object { $_ -match $mutant.Expected } | Select-Object -First 1)
  $first | Set-Content -LiteralPath (Join-Path $dir 'first_failure.txt') -Encoding UTF8
  $resultRows.Add("$($mutant.Name),PASS,PASS,tb_thermo5_i2_d1_axis_bittrue/1,`"$first`",true")
}

# This isolated directed probe is also run against clean and faulty generic
# FIFO copies, because the main full-chain test does not reassert midstream reset.
$fifoRelative = 'rtl\axis\dsm_async_fifo.sv'
$fifoSource = Join-Path $repo $fifoRelative
$fifoBase = Join-Path $runRoot 'baseline_fifo_reset'
$fifoLog = Invoke-XsimCase -CaseDir $fifoBase -Sources @($fifoSource, $fifoTb) `
  -Top 'thermo5_fault_stale_fifo_tb' -Seed '1'
if ($fifoLog -notmatch 'THERMO5_FAULT_STALE_FIFO_BASELINE_PASS' -or
    $fifoLog -match '(?m)(Fatal:|ERROR:|FATAL_ERROR:)') {
  throw "Clean generic FIFO reset probe failed: $fifoBase\console_xsim.log"
}
$staleDir = Join-Path $runRoot 'stale_fifo'
New-Item -ItemType Directory -Path $staleDir | Out-Null
$staleCopy = Join-Path $staleDir 'rtl_copy\dsm_async_fifo.sv'
New-Item -ItemType Directory -Force -Path (Split-Path $staleCopy -Parent) | Out-Null
$staleContent = [System.IO.File]::ReadAllText($fifoSource)
$staleContent = $staleContent.Replace('logic wr_full_q, rd_empty_q;',
  "logic wr_full_q, rd_empty_q;`r`n  logic reset_seen_q = 1'b0;")
$staleContent = $staleContent.Replace("rd_bin_q    <= '0;",
  "if (!reset_seen_q) begin`r`n        rd_bin_q <= '0;`r`n        reset_seen_q <= 1'b1;`r`n      end else begin`r`n        rd_bin_q <= rd_bin_q;`r`n      end")
if ($staleContent -eq [System.IO.File]::ReadAllText($fifoSource)) {
  throw 'Stale pointer mutation did not alter the isolated generic FIFO copy.'
}
[System.IO.File]::WriteAllText($staleCopy, $staleContent, [System.Text.UTF8Encoding]::new($false))
$staleLog = Invoke-XsimCase -CaseDir $staleDir -Sources @($staleCopy, $fifoTb) `
  -Top 'thermo5_fault_stale_fifo_tb' -Seed '1'
if ($staleLog -notmatch 'stale FIFO word visible after reset' -or
    $staleLog -match 'THERMO5_FAULT_STALE_FIFO_BASELINE_PASS') {
  throw "Stale FIFO mutant was not caught before PASS; see $staleDir\console_xsim.log"
}
$staleFirst = ($staleLog -split "`r?`n" | Where-Object { $_ -match 'stale FIFO word visible after reset' } | Select-Object -First 1)
$staleFirst | Set-Content -LiteralPath (Join-Path $staleDir 'first_failure.txt') -Encoding UTF8
$resultRows.Add("stale_fifo,PASS,PASS,thermo5_fault_stale_fifo_tb/1,`"$staleFirst`",true")

$resultRows | Set-Content -LiteralPath (Join-Path $runRoot 'summary.csv') -Encoding UTF8
"status=PASS`nmutants=4`nbaseline_datapath=PASS baseline_fifo_reset=PASS`noutput=$runRoot" |
  Set-Content -LiteralPath (Join-Path $runRoot 'summary.txt') -Encoding UTF8
Write-Host "THERMO5_FAULT_DETECTION_XSIM_PASS output=$runRoot"

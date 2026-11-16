param([switch]$StressPaReady,[switch]$XpmFifo,[switch]$ProbeInterp1EmptyBlocked,[switch]$AxilControl,[switch]$CenteredCubic,[switch]$AxilTrace,[ValidateSet(1,2)][int]$TidOrder=1,[ValidateSet(5120,7168)][int]$Step=7168,[int]$Seed=1,[int]$Words=56,[string]$VectorDir='',[string]$VivadoRoot='D:\AMDDesignTools\2026.1\Vivado',[string]$CenteredCubicRtlOverride='', [string]$RunLabel='')
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$impl=if($XpmFifo){'xpm'}else{'generic'}
$mode=if($AxilControl){'axil'}else{'parallel'}
$interp=if($CenteredCubic){'centered'}else{'causal'}
$work=Join-Path $repo "runs\uvm_thermo5_i2_d1\axis_xsim_${mode}_${impl}_${interp}_ef${TidOrder}_seed${Seed}_words$Words"
if($RunLabel -match '[^A-Za-z0-9_-]') { throw 'RunLabel may contain only letters, digits, underscore, and hyphen.' }
if($RunLabel) { $work += "_$RunLabel" }
if(Test-Path -LiteralPath $work) { throw "Refusing to overwrite existing XSim run directory: $work" }
$vectors=if($VectorDir -eq ''){Join-Path $repo 'runs\uvm_thermo5_i2_d1\vectors'}else{[System.IO.Path]::GetFullPath($VectorDir)}
if($Words -ne 56 -and $Words -ne 1008){throw 'Supported Words values are 56 and 1008.'}
if (!(Test-Path -LiteralPath (Join-Path $vectors 'tid32_thermo5_frontend_pa3.mem'))) {
  throw 'Run dv/uvm/sim/generate_thermo5_sku_vectors.ps1 first.'
}
New-Item -ItemType Directory -Force -Path $work | Out-Null
$settings=Join-Path $VivadoRoot 'settings64.bat'
if (!(Test-Path -LiteralPath $settings)) { throw 'Vivado settings unavailable.' }
function Invoke-VivadoBatch([string]$Name,[string]$Command) {
  $batch=Join-Path $work "$Name.cmd"
  $body="@echo off`r`ncd /d $work`r`nif errorlevel 1 exit /b %errorlevel%`r`ncall $settings >nul`r`nif errorlevel 1 exit /b %errorlevel%`r`n$Command`r`nexit /b %errorlevel%`r`n"
  [System.IO.File]::WriteAllText($batch,$body,[System.Text.Encoding]::ASCII)
  & $env:ComSpec /d /c $batch
}
function Wait-RunFile([string]$Path,[int]$Attempts=300) {
  for ($attempt=0; $attempt -lt $Attempts -and !(Test-Path -LiteralPath $Path); $attempt++) {
    Start-Sleep -Milliseconds 500
  }
  if (!(Test-Path -LiteralPath $Path)) { throw "Expected run output not found: $Path" }
}
function Wait-RunPattern([string]$Path,[string]$Pattern,[int]$Attempts=300) {
  for ($attempt=0; $attempt -lt $Attempts; $attempt++) {
    if ((Test-Path -LiteralPath $Path) -and (Select-String -LiteralPath $Path -Pattern $Pattern -Quiet)) { return }
    Start-Sleep -Milliseconds 500
  }
  throw "Expected pattern '$Pattern' not found in $Path"
}
$relative=@(
  'rtl/axis/dsm_reset_sync.sv','rtl/axis/dsm_frame_power_ctrl.sv',
  'rtl/axis/dsm_async_fifo.sv','rtl/axis/dsm_xpm_async_fifo.sv',
  'rtl/axis/dsm_axis14_to_core8_cdc.sv',
  'rtl/frontend/dsm_frame_gain_vector.sv',
  'rtl/gt/gt_tx_user_bridge.sv','rtl/gt/gt_tx_raw64_boundary.sv',
  'rtl/dpd/dpd_poly.v','rtl/dpd/dpd_memory_poly.v',
  'rtl/dpd/dpd_vector16_memory_poly.sv','rtl/dpd/dpd_vector_elastic_buffer.sv',
  'rtl/interp/dsm_interp_x2_centered_cubic_vector.sv',
  'rtl/interp/dsm_interp_x2_polyphase_vector.sv',
  'rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv',
  'rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv',
  'rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv',
  'rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv',
  'rtl/tx_bandpass_if/tid32_thermo5_axis_frontend_tx.sv',
  'dv/verif/subsystem/tx_frontend/tb/tb_thermo5_i2_d1_axis_bittrue.sv'
)
if($CenteredCubicRtlOverride) {
  if(!$CenteredCubic) { throw 'CenteredCubicRtlOverride requires -CenteredCubic.' }
  if(!(Test-Path -LiteralPath $CenteredCubicRtlOverride)) {
    throw "Centered-cubic RTL override not found: $CenteredCubicRtlOverride"
  }
  $relative = @($relative | Where-Object { $_ -ne 'rtl/interp/dsm_interp_x2_centered_cubic_vector.sv' })
  $rtlOverrideSource = @($CenteredCubicRtlOverride)
}
$vendor=@()
$rtlOverrideSource = if ($rtlOverrideSource) { $rtlOverrideSource } else { @() }
$define=''
if($CenteredCubic){$define+=' --define=THERMO5_CENTERED_CUBIC'}
if($TidOrder -eq 2){$define+=' --define=THERMO5_TIDSM_ORDER_2'}
if($Step -eq 5120){$define+=' --define=THERMO5_STEP_5120'}
if($Words -eq 1008){$define+=' -d THERMO5_LONG_1008'}
if($AxilControl){
  $define+=' -d THERMO5_AXIL_CONTROL'
  $relative=@($relative | Where-Object { $_ -ne 'dv/verif/subsystem/tx_frontend/tb/tb_thermo5_i2_d1_axis_bittrue.sv' })
  $relative+=@('rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv',
               'rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv',
               'dv/verif/subsystem/tx_frontend/tb/tb_thermo5_i2_d1_axis_bittrue.sv')
}
if($XpmFifo){
  $vendor=@(
    (Join-Path $VivadoRoot 'data\verilog\src\glbl.v'),
    (Join-Path $VivadoRoot 'data\ip\xpm\xpm_cdc\hdl\xpm_cdc.sv'),
    (Join-Path $VivadoRoot 'data\ip\xpm\xpm_memory\hdl\xpm_memory.sv'),
    (Join-Path $VivadoRoot 'data\ip\xpm\xpm_fifo\hdl\xpm_fifo.sv')
  )
  foreach($path in $vendor){if(!(Test-Path -LiteralPath $path)){throw "Missing vendor XPM model: $path"}}
  $define+=' --define=THERMO5_XPM_FIFO'
}
if($Words -eq 1008 -and $define -notmatch 'THERMO5_LONG_1008') {
  throw 'THERMO5_LONG_1008 macro was not retained in the 1008-word compile.'
}
if($CenteredCubic -and $define -notmatch 'THERMO5_CENTERED_CUBIC') {
  throw 'THERMO5_CENTERED_CUBIC macro was not retained in the compile.'
}
if($TidOrder -eq 2 -and $define -notmatch 'THERMO5_TIDSM_ORDER_2') {
  throw 'THERMO5_TIDSM_ORDER_2 macro was not retained in the compile.'
}
if($Step -eq 5120 -and $define -notmatch 'THERMO5_STEP_5120') {
  throw 'THERMO5_STEP_5120 macro was not retained in the compile.'
}
$configFile=Join-Path $work 'compile_configuration.txt'
@("Words=$Words","Seed=$Seed","VivadoRoot=$VivadoRoot","Define=$define","XpmFifo=$XpmFifo","CenteredCubic=$CenteredCubic","TidOrder=$TidOrder","Step=$Step") |
  Set-Content -LiteralPath $configFile -Encoding ASCII
$source=(($vendor + ($relative | ForEach-Object { Join-Path $repo $_ }) + $rtlOverrideSource) | ForEach-Object { '"'+$_+'"' }) -join ' '
Push-Location $work
try {
  Invoke-VivadoBatch 'run_xvlog' "call $VivadoRoot\bin\xvlog.bat -sv $define $source > console_xvlog.log 2>&1"
  Wait-RunFile (Join-Path $work 'console_xvlog.log')
  Wait-RunFile (Join-Path $work 'xvlog.pb')
  if (!(Select-String -LiteralPath (Join-Path $work 'console_xvlog.log') -Pattern 'ERROR:|FATAL:' -Quiet)) {
    if (!(Test-Path -LiteralPath (Join-Path $work 'xvlog.pb'))) { throw "xvlog database missing: $work\console_xvlog.log" }
  } else { throw "xvlog reported an error: $work\console_xvlog.log" }
  $tops=if($XpmFifo){'tb_thermo5_i2_d1_axis_bittrue glbl'}else{'tb_thermo5_i2_d1_axis_bittrue'}
  Invoke-VivadoBatch 'run_xelab' "call $VivadoRoot\bin\xelab.bat $tops -s sim_thermo5_i2_d1_axis > console_xelab.log 2>&1"
  Wait-RunFile (Join-Path $work 'console_xelab.log')
  $snapshot=Join-Path $work 'xsim.dir\sim_thermo5_i2_d1_axis\xsimk.exe'
  Wait-RunFile $snapshot
  if (!(Select-String -LiteralPath (Join-Path $work 'console_xelab.log') -Pattern 'Built simulation snapshot' -Quiet)) {
    throw "xelab did not complete a simulation snapshot: $work\console_xelab.log"
  }
  Copy-Item -Path (Join-Path $vectors '*.mem') -Destination $work
  $plusargs=@()
  if($StressPaReady){$plusargs+='-testplusarg STRESS_PA_READY'}
  if($ProbeInterp1EmptyBlocked){$plusargs+='-testplusarg INTERP1_GAP_STALL'}
  if($AxilTrace){$plusargs+='-testplusarg AXIL_TRACE'}
  $plusarg=$plusargs -join ' '
  $xsimLog=Join-Path $work 'xsim.log'
  $xsimConsole=Join-Path $work 'console_xsim.log'
  $xsimStdout=Join-Path $work 'xsim_launcher.stdout.log'
  $xsimStderr=Join-Path $work 'xsim_launcher.stderr.log'
  $xsimBatch=Join-Path $VivadoRoot 'bin\xsim.bat'
  $xsimCmdFile=Join-Path $work 'run_xsim.cmd'
  $xsimBody="@echo off`r`ncd /d `"$work`"`r`nif errorlevel 1 exit /b %errorlevel%`r`ncall `"$settings`" >nul`r`nif errorlevel 1 exit /b %errorlevel%`r`ncall `"$xsimBatch`" sim_thermo5_i2_d1_axis -runall -sv_seed $Seed $plusarg -log xsim.log`r`nexit /b %errorlevel%`r`n"
  [System.IO.File]::WriteAllText($xsimCmdFile,$xsimBody,[System.Text.Encoding]::ASCII)
  & $env:ComSpec /d /c $xsimCmdFile
  $xsimExitCode=$LASTEXITCODE
  if($null -eq $xsimExitCode -or "$xsimExitCode" -eq '') { $xsimExitCode=0 }
  @("CommandFile=$xsimCmdFile","ExitCode=$xsimExitCode") |
    Set-Content -LiteralPath $xsimStdout -Encoding ASCII
  if (!(Test-Path -LiteralPath $xsimStderr)) {
    New-Item -ItemType File -Path $xsimStderr -Force | Out-Null
  }
  Wait-RunFile $xsimLog
  $expectedPassMarker=if($AxilControl){'THERMO5_AXIL_CONFIG_BITTRUE_PASS'}else{'THERMO5_I2_D1_AXIS_BITTRUE_PASS'}
  Wait-RunPattern $xsimLog $expectedPassMarker
  if($xsimExitCode -ne 0) {
    throw "XSim exited with code $xsimExitCode; inspect $xsimLog, $xsimStdout, and $xsimStderr"
  }
  Copy-Item -LiteralPath $xsimLog -Destination $xsimConsole -Force
} finally { Pop-Location }
if($AxilControl){$passMarker='THERMO5_AXIL_CONFIG_BITTRUE_PASS'}else{$passMarker='THERMO5_I2_D1_AXIS_BITTRUE_PASS'}
if (!(Select-String -LiteralPath (Join-Path $work 'console_xsim.log') -Pattern $passMarker -Quiet)) {
  throw "Full-chain PASS marker missing: $work\console_xsim.log"
}
if (Select-String -LiteralPath (Join-Path $work 'console_xsim.log') -Pattern '(^|\s)(Error:|Fatal:|FATAL_ERROR:)' -Quiet) {
  throw "XSim reported an error despite the PASS marker: $work\console_xsim.log"
}
Write-Host "$passMarker log=$work\console_xsim.log"

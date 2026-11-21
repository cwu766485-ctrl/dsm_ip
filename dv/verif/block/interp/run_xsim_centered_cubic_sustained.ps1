param(
  [string]$VivadoRoot = 'D:\AMDDesignTools\2026.1\Vivado',
  [ValidateSet('sustained','differential')][string]$Testbench = 'sustained',
  [string]$ReferenceCommit = 'dfa34dbd4848499448f2ddb146ead9f324db8490'
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$bin = Join-Path $VivadoRoot 'bin'
$xvlog = Join-Path $bin 'xvlog.bat'
$xelab = Join-Path $bin 'xelab.bat'
$xsim = Join-Path $bin 'xsim.bat'
foreach ($tool in @($xvlog,$xelab,$xsim)) {
  if (!(Test-Path -LiteralPath $tool)) { throw "Vivado Simulator tool not found: $tool" }
}

$env:XILINX_VIVADO = $VivadoRoot
$env:PATH = "$bin;$([System.IO.Path]::Combine($VivadoRoot,'lib','win64.o'));$env:PATH"
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$work = Join-Path $repo "runs\centered_cubic_${Testbench}_xsim_$stamp"
New-Item -ItemType Directory -Path $work | Out-Null
$work = (Resolve-Path -LiteralPath $work).Path
$rtl = Join-Path $repo 'rtl\interp\dsm_interp_x2_centered_cubic_vector.sv'
$tb = if ($Testbench -eq 'sustained') {
  Join-Path $repo 'dv\verif\block\interp\tb\tb_centered_cubic_sustained.sv'
} else {
  Join-Path $repo 'dv\verif\block\interp\tb\tb_centered_cubic_pipeline_diff.sv'
}
$log = Join-Path $work 'runner.log'
$envLog = Join-Path $work 'environment.txt'
$manifestPath = Join-Path $work 'run_manifest.json'
$git = (Get-Command git.exe -ErrorAction Stop).Source
$head = (& $git -C $repo rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or !$head) { throw 'Could not record source HEAD before simulation.' }
$manifest = [ordered]@{
  source_head = $head
  testbench = $Testbench
  reference_commit = $ReferenceCommit
  vivado_root = $VivadoRoot
  vivado_version = 'Pending version probe'
  commands = [ordered]@{}
  status = 'PREPARED'
}
function Save-Manifest {
  $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
}
function Format-CmdArgument([string]$value) {
  if ($value -match '[\s&()]') { return '"' + $value.Replace('"','\"') + '"' }
  return $value
}
function Invoke-BatchTool([string]$tool, [string]$stage, [string[]]$arguments) {
  $cmdPath = Join-Path $work "$stage.cmd"
  $argsText = ($arguments | ForEach-Object { Format-CmdArgument $_ }) -join ' '
  $commandLine = 'call "{0}" {1}' -f $tool, $argsText
  @('@echo off', $commandLine, 'exit /b %errorlevel%') |
    Set-Content -LiteralPath $cmdPath -Encoding ASCII
  $manifest.commands[$stage] = $commandLine
  $manifest.status = "${stage}_RUNNING"
  Save-Manifest
  $commandLine | Tee-Object -FilePath $log -Append
  & cmd.exe /d /c $cmdPath 2>&1 | Tee-Object -FilePath $log -Append
  if ($LASTEXITCODE -ne 0) {
    $manifest.status = "${stage}_FAIL"
    Save-Manifest
    throw "$stage failed (exit=$LASTEXITCODE); see $log"
  }
  $manifest.status = "${stage}_PASS"
  Save-Manifest
}
Save-Manifest
@(
  "VivadoRoot=$VivadoRoot"
  "XILINX_VIVADO=$env:XILINX_VIVADO"
  "xvlog=$xvlog"
  "xelab=$xelab"
  "xsim=$xsim"
  "Testbench=$Testbench"
  "ReferenceCommit=$ReferenceCommit"
  "PowerShell=$($PSVersionTable.PSVersion)"
) | Set-Content -LiteralPath $envLog

foreach ($tool in @($xvlog,$xelab,$xsim)) {
  "`n### $tool -version" | Add-Content -LiteralPath $envLog
  $versionCmd = Join-Path $work 'tool_version.cmd'
  @('@echo off', ('call "{0}" -version' -f $tool), 'exit /b %errorlevel%') |
    Set-Content -LiteralPath $versionCmd -Encoding ASCII
  $versionOutput = & cmd.exe /d /c $versionCmd 2>&1
  $versionOutput | Add-Content -LiteralPath $envLog
  if ($LASTEXITCODE -ne 0) {
    $manifest.status = 'VERSION_PROBE_FAIL'
    Save-Manifest
    throw "Tool version probe failed: $tool (exit=$LASTEXITCODE)"
  }
  $manifest.vivado_version = (($versionOutput | Select-String -Pattern 'Vivado Simulator v' | Select-Object -First 1).Line)
  Save-Manifest
}

Push-Location $work
try {
  if ($Testbench -eq 'differential') {
    $reference = Join-Path $work 'dsm_interp_x2_centered_cubic_vector_ref.sv'
    $source = & $git -C $repo show "${ReferenceCommit}:rtl/interp/dsm_interp_x2_centered_cubic_vector.sv"
    if ($LASTEXITCODE -ne 0 -or !$source) { throw "Could not extract reference RTL from $ReferenceCommit" }
    $sourceText = ($source -join "`n").Replace(
      'module dsm_interp_x2_centered_cubic_vector #(',
      'module dsm_interp_x2_centered_cubic_vector_ref #(')
    if ($sourceText -notmatch 'module dsm_interp_x2_centered_cubic_vector_ref') {
      throw 'Reference RTL module rename failed.'
    }
    [System.IO.File]::WriteAllText($reference, $sourceText, [System.Text.UTF8Encoding]::new($false))
    $sources = @($reference,$rtl,$tb)
    $top = 'tb_centered_cubic_pipeline_diff'
    $passMarker = 'CENTERED_CUBIC_PIPELINE_DIFF_PASS'
  } else {
    $sources = @($rtl,$tb)
    $top = 'tb_centered_cubic_sustained'
    $passMarker = 'CENTERED_CUBIC_SUSTAINED_PASS'
  }

  Invoke-BatchTool $xvlog 'xvlog' (@('-sv','-log','xvlog.log') + $sources)
  Invoke-BatchTool $xelab 'xelab' @($top,'-s','sim_centered_cubic','-log','xelab.log')
  Invoke-BatchTool $xsim 'xsim' @('sim_centered_cubic','-runall','-log','xsim.log')
  if (!(Select-String -LiteralPath 'xsim.log' -Pattern $passMarker -Quiet)) {
    $manifest.status = 'FAIL_MARKER_MISSING'
    Save-Manifest
    throw "PASS marker '$passMarker' is missing; see $(Join-Path $work 'xsim.log')"
  }
  $manifest.status = 'PASS'
  $manifest.pass_marker = $passMarker
  Save-Manifest
} finally {
  Pop-Location
}

Write-Host "Centered-cubic $Testbench XSim PASS: $work\xsim.log"

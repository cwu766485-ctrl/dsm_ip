param(
  [string]$VivadoRoot = 'D:\AMDDesignTools\2026.1\Vivado',
  [ValidateSet('sustained','differential')][string]$Testbench = 'sustained',
  [string]$ReferenceCommit = 'dfa34dbd4848499448f2ddb146ead9f324db8490',
  [string]$SourceHead = '',
  [string]$ReferenceRTLPath = ''
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
$head = $SourceHead
if (!$head) {
  $gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue
  if ($gitCommand) {
    $head = (& $gitCommand.Source -C $repo rev-parse HEAD | Select-Object -First 1)
    if ($LASTEXITCODE -ne 0) { $head = '' }
  }
}
if (!$head) { throw 'Supply -SourceHead when git.exe is unavailable to Windows PowerShell.' }
$head = $head.Trim()
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
  $stdoutPath = Join-Path $work "$stage.stdout.log"
  $stderrPath = Join-Path $work "$stage.stderr.log"
  $manifest.commands[$stage] = $commandLine
  $manifest.status = "${stage}_RUNNING"
  Save-Manifest
  $commandLine | Tee-Object -FilePath $log -Append
  $process = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList @('/d','/c',('"{0}"' -f $cmdPath)) `
    -WorkingDirectory $work -Wait -PassThru -NoNewWindow `
    -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
  if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath | Tee-Object -FilePath $log -Append }
  if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath | Tee-Object -FilePath $log -Append }
  if ($process.ExitCode -ne 0) {
    $manifest.status = "${stage}_FAIL"
    Save-Manifest
    throw "$stage failed (exit=$($process.ExitCode)); see $log"
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
  $versionStdout = Join-Path $work 'tool_version.stdout.log'
  $versionStderr = Join-Path $work 'tool_version.stderr.log'
  $versionProcess = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList @('/d','/c',('"{0}"' -f $versionCmd)) `
    -WorkingDirectory $work -Wait -PassThru -NoNewWindow `
    -RedirectStandardOutput $versionStdout -RedirectStandardError $versionStderr
  $versionOutput = @()
  if (Test-Path -LiteralPath $versionStdout) { $versionOutput += Get-Content -LiteralPath $versionStdout }
  if (Test-Path -LiteralPath $versionStderr) { $versionOutput += Get-Content -LiteralPath $versionStderr }
  $versionOutput | Add-Content -LiteralPath $envLog
  if ($versionProcess.ExitCode -ne 0) {
    $manifest.status = 'VERSION_PROBE_FAIL'
    Save-Manifest
    throw "Tool version probe failed: $tool (exit=$($versionProcess.ExitCode))"
  }
  $manifest.vivado_version = (($versionOutput | Select-String -Pattern 'Vivado Simulator v' | Select-Object -First 1).Line)
  Save-Manifest
}

Push-Location $work
try {
  if ($Testbench -eq 'differential') {
    $reference = Join-Path $work 'dsm_interp_x2_centered_cubic_vector_ref.sv'
    if ($ReferenceRTLPath) {
      if (!(Test-Path -LiteralPath $ReferenceRTLPath -PathType Leaf)) { throw "Reference RTL not found: $ReferenceRTLPath" }
      $sourceText = [System.IO.File]::ReadAllText($ReferenceRTLPath)
    } else {
      $gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue
      if (!$gitCommand) { throw 'Supply -ReferenceRTLPath when git.exe is unavailable to Windows PowerShell.' }
      $source = & $gitCommand.Source -C $repo show "${ReferenceCommit}:rtl/interp/dsm_interp_x2_centered_cubic_vector.sv"
      if ($LASTEXITCODE -ne 0 -or !$source) { throw "Could not extract reference RTL from $ReferenceCommit" }
      $sourceText = ($source -join "`n")
    }
    $sourceText = $sourceText.Replace(
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

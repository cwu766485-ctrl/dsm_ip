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
  & $tool -version 2>&1 | Add-Content -LiteralPath $envLog
  if ($LASTEXITCODE -ne 0) { throw "Tool version probe failed: $tool (exit=$LASTEXITCODE)" }
}

Push-Location $work
try {
  if ($Testbench -eq 'differential') {
    $git = (Get-Command git.exe -ErrorAction Stop).Source
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

  "xvlog -sv -log xvlog.log $($sources -join ' ')" | Tee-Object -FilePath $log
  & $xvlog -sv -log xvlog.log @sources 2>&1 | Tee-Object -FilePath $log -Append
  if ($LASTEXITCODE -ne 0) { throw "xvlog failed (exit=$LASTEXITCODE); see $log" }

  "xelab $top -s sim_centered_cubic -log xelab.log" | Tee-Object -FilePath $log -Append
  & $xelab $top -s sim_centered_cubic -log xelab.log 2>&1 | Tee-Object -FilePath $log -Append
  if ($LASTEXITCODE -ne 0) { throw "xelab failed (exit=$LASTEXITCODE); see $log" }

  'xsim sim_centered_cubic -runall -log xsim.log' | Tee-Object -FilePath $log -Append
  & $xsim sim_centered_cubic -runall -log xsim.log 2>&1 | Tee-Object -FilePath $log -Append
  if ($LASTEXITCODE -ne 0) { throw "xsim failed (exit=$LASTEXITCODE); see $log" }
  if (!(Select-String -LiteralPath 'xsim.log' -Pattern $passMarker -Quiet)) {
    throw "PASS marker '$passMarker' is missing; see $(Join-Path $work 'xsim.log')"
  }
} finally {
  Pop-Location
}

Write-Host "Centered-cubic $Testbench XSim PASS: $work\xsim.log"

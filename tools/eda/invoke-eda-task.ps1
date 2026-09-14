param(
  [string]$Task = "",
  [switch]$List,
  [string]$OutputDirectory = "",
  [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat"
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$manifestPath = Join-Path $PSScriptRoot 'eda-tasks.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

if ($List) {
  $manifest.tasks | Select-Object id, runner, description | Format-Table -AutoSize
  exit 0
}

if ([string]::IsNullOrWhiteSpace($Task)) {
  throw 'Specify -Task <id>, or use -List to view the audited catalog.'
}

$entry = @($manifest.tasks | Where-Object { $_.id -eq $Task })
if ($entry.Count -ne 1) {
  throw "Unknown EDA task '$Task'. Run with -List to view the audited catalog."
}
$entry = $entry[0]
$scriptPath = [System.IO.Path]::GetFullPath((Join-Path $repo $entry.script))
if (!$scriptPath.StartsWith($repo + [System.IO.Path]::DirectorySeparatorChar) -or
    !(Test-Path -LiteralPath $scriptPath)) {
  throw "Invalid task script in catalog: $($entry.script)"
}

switch ($entry.runner) {
  'powershell' {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath
    if ($LASTEXITCODE -ne 0) { throw "EDA task '$Task' failed: exit=$LASTEXITCODE" }
  }
  'vivado-tcl' {
    if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
      throw "Task '$Task' requires -OutputDirectory outside the repository."
    }
    if (!(Test-Path -LiteralPath $VivadoBat)) { throw "Vivado executable not found: $VivadoBat" }
    $out = [System.IO.Path]::GetFullPath($OutputDirectory)
    if ($out.StartsWith($repo + [System.IO.Path]::DirectorySeparatorChar)) {
      throw 'Generated Vivado IP must be placed outside the repository.'
    }
    & $VivadoBat -mode batch -source $scriptPath -tclargs $out
    if ($LASTEXITCODE -ne 0) { throw "EDA task '$Task' failed: exit=$LASTEXITCODE" }
  }
  default { throw "Unsupported runner '$($entry.runner)' in EDA task catalog." }
}

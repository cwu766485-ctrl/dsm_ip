param(
  [Parameter(Mandatory = $true)]
  [string]$BridgeRoot,
  [switch]$MergeOnly,
  [switch]$SeedObserverDebug,
  [switch]$MemoryBankDebug,
  [switch]$WstrbDebug
)

$ErrorActionPreference = "Stop"
$BridgeRoot = (Resolve-Path -LiteralPath $BridgeRoot).Path
$statusFile = Join-Path $BridgeRoot "status.txt"
$commandFile = Join-Path $BridgeRoot "command.sh"
$activeFile = Join-Path $BridgeRoot "command.active.sh"

if (!(Test-Path -LiteralPath $statusFile)) {
  throw "Bridge is not running: $statusFile is missing. Start the Rocky bridge first."
}
if ((Test-Path -LiteralPath $commandFile) -or (Test-Path -LiteralPath $activeFile)) {
  throw "Bridge already has a pending or active command. Inspect $statusFile and result.log before submitting another task."
}

$linuxCommand = if ($MemoryBankDebug) { @'
#!/usr/bin/env bash
set -euo pipefail
cd "${DSM_IP_REPO_ROOT:?Set DSM_IP_REPO_ROOT to the Linux repository path.}"
make -C uvm_verif/sim clean
make -C uvm_verif/sim vcs-run \
  PYTHON=python3.12 COVERAGE=1 \
  UVM_TESTNAME=dsm_memory_bank_roundtrip_coverage_test \
  UVM_SEED=1 \
  RUN_TAG=dsm_memory_bank_roundtrip_coverage_test_seed1
'@ } elseif ($SeedObserverDebug) { @'
#!/usr/bin/env bash
set -euo pipefail
cd "${DSM_IP_REPO_ROOT:?Set DSM_IP_REPO_ROOT to the Linux repository path.}"
make -C uvm_verif/sim clean
make -C uvm_verif/sim vcs-run \
  PYTHON=python3.12 COVERAGE=1 \
  UVM_TESTNAME=dsm_seed_observer_datapath_coverage_test \
  UVM_SEED=1 \
  RUN_TAG=dsm_seed_observer_datapath_coverage_test_seed1
'@ } elseif ($WstrbDebug) { @'
#!/usr/bin/env bash
set -euo pipefail
cd "${DSM_IP_REPO_ROOT:?Set DSM_IP_REPO_ROOT to the Linux repository path.}"
make -C uvm_verif/sim clean
make -C uvm_verif/sim vcs-run \
  PYTHON=python3.12 COVERAGE=1 \
  UVM_TESTNAME=dsm_wstrb_semantics_coverage_test \
  UVM_SEED=1 \
  RUN_TAG=dsm_wstrb_semantics_coverage_test_seed1
'@ } elseif ($MergeOnly) { @'
#!/usr/bin/env bash
set -euo pipefail
cd "${DSM_IP_REPO_ROOT:?Set DSM_IP_REPO_ROOT to the Linux repository path.}"
bash uvm_verif/sim/run_ip_extended_coverage_linux.sh
'@ } else { @'
#!/usr/bin/env bash
set -euo pipefail
cd "${DSM_IP_REPO_ROOT:?Set DSM_IP_REPO_ROOT to the Linux repository path.}"
bash uvm_verif/sim/run_ip_extended_regression_linux.sh
bash uvm_verif/sim/run_ip_extended_coverage_linux.sh
'@ }

# The Rocky bridge executes this as Bash.  Set-Content emits CRLF on Windows,
# which makes Bash interpret the trailing CR as part of the script pathname.
[System.IO.File]::WriteAllText($commandFile, ($linuxCommand -replace "`r?`n", "`n"), [System.Text.Encoding]::ASCII)
if ($MemoryBankDebug) {
  Write-Host "Submitted DSM memory-DPD two-bank coverage debug run to $BridgeRoot"
} elseif ($SeedObserverDebug) {
  Write-Host "Submitted DSM seed/observer/datapath coverage debug run to $BridgeRoot"
} elseif ($WstrbDebug) {
  Write-Host "Submitted DSM AXI-Lite WSTRB coverage debug run to $BridgeRoot"
} elseif ($MergeOnly) {
  Write-Host "Submitted DSM DUT-only URG merge to $BridgeRoot"
} else {
  Write-Host "Submitted DSM 280-run regression and DUT-only URG merge to $BridgeRoot"
}
Write-Host "Wait for last_exit=0, then inspect result.log and uvm_verif/sim/out/vcs/ip_extended_regression.csv."
Get-Content -LiteralPath $statusFile

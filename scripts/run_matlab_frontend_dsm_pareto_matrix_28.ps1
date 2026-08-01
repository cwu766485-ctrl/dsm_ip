$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
matlab -batch "cd('$($repo.Replace('\','/'))/matlab'); path_setup; run_frontend_dsm_pareto_matrix_28"
if ($LASTEXITCODE -ne 0) { throw "28-point frontend/DSM MATLAB matrix failed" }

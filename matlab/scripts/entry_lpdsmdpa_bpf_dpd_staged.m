% entry_lpdsmdpa_bpf_dpd_staged
% Run the staged behavioral DPA/DPD experiment and write its summary.
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..'));
path_setup();
[DucUnitTest] = test_lpdsmdpa_bpf_duc(); %#ok<NASGU>
[Results, Summary, Artifacts] = run_lpdsmdpa_bpf_dpd_staged(); %#ok<ASGLU>
assert(height(Results) == 63);
assert(height(Summary) == 21);
assert(all(isfinite(Results.EVM_percent)));
assert(all(isfinite(Results.SNDR_dB)));
disp(Summary);

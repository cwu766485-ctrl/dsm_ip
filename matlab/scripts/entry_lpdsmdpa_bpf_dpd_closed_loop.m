% entry_lpdsmdpa_bpf_dpd_closed_loop
% Generate behavioral 1-bit DPA+BPF evidence and quantized DPD coefficients.
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..'));
path_setup();
[Results, Coefficients, Artifacts] = run_lpdsmdpa_bpf_dpd_closed_loop(); %#ok<ASGLU>
assert(height(Results) == 9);
assert(height(Coefficients) == 12);
assert(all(ismember(["No DPD"; "Q2.14 Memoryless DPD"; "Q2.14 Memory-Poly DPD"], ...
  unique(Results.Mode))));
assert(all(isfinite(Results.EVM_percent)));
assert(all(isfinite(Results.SNDR_dB)));
assert(all(Results.RFBitOneFraction > 0 & Results.RFBitOneFraction < 1));
assert(all(Results.DPDLimitCount >= 0));
assert(height(Artifacts.quality_gate) == 1);
assert(height(Artifacts.summary) == 3);
assert(all(Artifacts.summary.TotalDPDLimitCount >= 0));
assert(height(Artifacts.validation) == 2*numel(Artifacts.cfg.validation_seeds));
assert(Artifacts.quality_gate.ValidationEVMPassCount <= numel(Artifacts.cfg.validation_seeds));
assert(Artifacts.quality_gate.ValidationSNDRPassCount <= numel(Artifacts.cfg.validation_seeds));
assert(Artifacts.quality_gate.ValidationOutOfBandPassCount <= numel(Artifacts.cfg.validation_seeds));
disp(Artifacts.quality_gate);

function [Baseline, Candidate, Gate] = export_ads_dpd_candidate_pair(varargin)
% Export no-DPD and quality-gated Memory-Poly DPD PWL files for the ADS endpoint.
%
% The accepted coefficient test belongs to the behavioral endpoint. ADS runs
% created from these PWL files are a separate circuit-endpoint comparison and
% must not be treated as a hardware-calibrated release without that comparison.

  cfg.n_samples = 256;
  cfg.seed = 211;
  cfg.out_dir = '';
  cfg.use_cached_release = true;
  cfg = parse_kv(cfg, varargin{:});
  repo = fileparts(fileparts(fileparts(mfilename('fullpath'))));
  release_dir = fullfile(repo, 'matlab', 'out', 'dpd');
  if cfg.use_cached_release
    Gate = readtable(fullfile(release_dir, 'lpdsmdpa_bpf_dpd_quality_gate.csv'));
    coeff_table = readtable(fullfile(release_dir, 'lpdsmdpa_bpf_dpd_release_coefficients.csv'));
    coeff_q = complex(coeff_table.Q2_14_Real, coeff_table.Q2_14_Imag);
    taps = max(coeff_table.Tap) + 1;
    orders = unique(coeff_table.Order, 'stable').';
    drive_limit = 0.75;
  else
    [~, ~, Artifacts] = run_lpdsmdpa_bpf_dpd_closed_loop( ...
      'write_outputs', false, 'verbose', false);
    Gate = Artifacts.quality_gate;
    coeff_q = Artifacts.coeff_q;
    taps = Artifacts.cfg.memory_taps;
    orders = Artifacts.cfg.orders;
    drive_limit = Artifacts.cfg.dpd_drive_limit;
  end
  assert(Gate.Status == "ACCEPT", ...
    'Behavioral quality gate rejected the candidate; no ADS DPD PWL was exported.');
  assert(numel(coeff_q) == taps*numel(orders), ...
    'Released coefficient table does not match its declared tap/order structure.');

  Baseline = export_ads_low_power_dpa_stimulus( ...
    'n_samples', cfg.n_samples, 'seed', cfg.seed, 'out_dir', cfg.out_dir, ...
    'file_stem', 'rf_bit_no_dpd');
  Candidate = export_ads_low_power_dpa_stimulus( ...
    'n_samples', cfg.n_samples, 'seed', cfg.seed, 'out_dir', cfg.out_dir, ...
    'file_stem', 'rf_bit_memory_poly5_tap4', ...
    'dpd_coeff_q', coeff_q, 'dpd_taps', taps, ...
    'dpd_orders', orders, 'dpd_drive_limit', drive_limit);
end

function cfg = parse_kv(cfg, varargin)
  assert(mod(numel(varargin), 2) == 0, 'Use name/value pairs.');
  for k = 1:2:numel(varargin)
    name = char(varargin{k});
    assert(isfield(cfg, name), 'Unsupported option: %s', name);
    cfg.(name) = varargin{k+1};
  end
end

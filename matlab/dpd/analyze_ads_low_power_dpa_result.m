function R = analyze_ads_low_power_dpa_result(varargin)
% Analyze an ADS low-power DPA transient export.
%
% Required columns: time_s, vout_v, ivdd_a. The efficiency is a circuit-model
% trend until PDK, passive-network, and measurement correlation are available.

  cfg.result_file = '';
  cfg.vdd_v = 1.2;
  % The ADS v10 baseline observes the 100 ohm differential bridge load.
  % Convert to a physical 50 ohm single-ended measurement only after the
  % balun/matching network is explicitly modeled.
  cfg.load_ohm = 100;
  cfg.if_hz = 25e6;
  cfg.out_file = '';
  cfg = parse_kv(cfg, varargin{:});
  repo = fileparts(fileparts(fileparts(mfilename('fullpath'))));
  if isempty(cfg.result_file)
    cfg.result_file = fullfile(repo, 'ads', 'low_power_dpa', 'data', ...
      'ads_observation.csv');
  end
  assert(exist(cfg.result_file, 'file') == 2, ...
    'ADS result is missing: %s', cfg.result_file);

  T = readtable(cfg.result_file);
  required = {'time_s', 'vout_v', 'ivdd_a'};
  assert(all(ismember(required, T.Properties.VariableNames)), ...
    'ADS CSV must contain: %s', strjoin(required, ', '));
  t = T.time_s(:);
  vout = T.vout_v(:);
  ivdd = T.ivdd_a(:);
  assert(numel(t) >= 32 && all(diff(t) > 0), ...
    'ADS time_s must contain at least 32 strictly increasing samples.');

  pdc_w = cfg.vdd_v * mean(ivdd);
  pout_w = mean(vout.^2) / cfg.load_ohm;
  fs_hz = 1 / median(diff(t));
  [f_hz, power] = one_sided_power(vout, fs_hz, cfg.load_ohm);
  [~, k] = min(abs(f_hz-cfg.if_hz));
  R = table(numel(t), fs_hz, cfg.vdd_v, cfg.load_ohm, pdc_w, pout_w, ...
    10*log10(max(pout_w, realmin)/1e-3), pout_w/max(pdc_w, realmin), ...
    max(abs(vout)), max(abs(ivdd)), mean(vout), f_hz(k), power(k), ...
    'VariableNames', {'samples', 'sample_rate_hz', 'vdd_v', 'load_ohm', ...
    'pdc_w', 'pout_w', 'pout_dbm', 'efficiency_trend', 'vout_peak_v', ...
    'ivdd_peak_a', 'vout_dc_v', 'if_bin_hz', 'if_bin_power_w'});

  if isempty(cfg.out_file)
    cfg.out_file = fullfile(fileparts(cfg.result_file), ...
      'ads_low_power_dpa_summary.csv');
  end
  writetable(R, cfg.out_file);
  disp(R);
end

function [f_hz, power_w] = one_sided_power(v, fs_hz, load_ohm)
  n = numel(v);
  V = fft(v-mean(v)) / n;
  keep = 1:(floor(n/2)+1);
  power_w = abs(V(keep)).^2 / load_ohm;
  if numel(power_w) > 2, power_w(2:end-1) = 2*power_w(2:end-1); end
  f_hz = (keep-1).' * fs_hz / n;
end

function cfg = parse_kv(cfg, varargin)
  assert(mod(numel(varargin), 2) == 0, 'Use name/value pairs.');
  for k = 1:2:numel(varargin)
    name = char(varargin{k});
    assert(isfield(cfg, name), 'Unsupported option: %s', name);
    cfg.(name) = varargin{k+1};
  end
end

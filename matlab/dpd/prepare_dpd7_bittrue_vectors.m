function prepare_dpd7_bittrue_vectors(varargin)
% Generate deterministic Q1.15/Q2.14 C1/C3/C5/C7 vectors for dpd_poly.

  cfg.n_input = 256;
  cfg.seed = 43;
  cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'out', 'dpd', 'bittrue');
  cfg.input_w = 16;
  cfg.input_frac = 15;
  cfg.coeff_frac = 14;
  for n = 1:2:numel(varargin), cfg.(varargin{n}) = varargin{n+1}; end
  if ~exist(cfg.out_dir, 'dir'), mkdir(cfg.out_dir); end

  rng(cfg.seed);
  index = (0:cfg.n_input-1).';
  ii = randi([-22000, 22000], cfg.n_input, 1);
  qq = randi([-22000, 22000], cfg.n_input, 1);
  ii(1:11) = [0; 1; -1; 32767; -32768; 24000; -24000; 12345; -12345; 30000; -30000];
  qq(1:11) = [0; -1; 1; -32768; 32767; -24000; 24000; -12345; 12345; 30000; -30000];

  coeff = struct('c1_re', int32(16393), 'c1_im', int32(-5), ...
    'c3_re', int32(8047), 'c3_im', int32(-3676), ...
    'c5_re', int32(14905), 'c5_im', int32(-8624), ...
    'c7_re', int32(2048), 'c7_im', int32(-1024));
  [yo_i, yo_q, sat] = model7(ii, qq, coeff, cfg);

  writetable(table(index, int32(ii), int32(qq), ...
    'VariableNames', {'n','i_q1_15','q_q1_15'}), ...
    fullfile(cfg.out_dir, 'dpd7_input_iq.csv'));
  writetable(table(index, int32(yo_i), int32(yo_q), logical(sat), ...
    'VariableNames', {'n','i_q1_15','q_q1_15','saturated'}), ...
    fullfile(cfg.out_dir, 'dpd7_expected_iq.csv'));
  writetable(struct2table(coeff), fullfile(cfg.out_dir, 'dpd7_coefficients.csv'));
end

function [yo_i, yo_q, sat] = model7(ii, qq, coeff, cfg)
  yo_i = zeros(size(ii), 'int64'); yo_q = zeros(size(qq), 'int64');
  sat = false(size(ii));
  for n = 1:numel(ii)
    i = int64(ii(n)); q = int64(qq(n));
    r2 = bitsra(i*i + q*q, cfg.input_frac);
    r4 = bitsra(r2*r2, cfg.input_frac);
    r6 = bitsra(r4*r2, cfg.input_frac);
    gr = int64(coeff.c1_re) + bitsra(int64(coeff.c3_re)*r2, cfg.input_frac) + ...
      bitsra(int64(coeff.c5_re)*r4, cfg.input_frac) + ...
      bitsra(int64(coeff.c7_re)*r6, cfg.input_frac);
    gi = int64(coeff.c1_im) + bitsra(int64(coeff.c3_im)*r2, cfg.input_frac) + ...
      bitsra(int64(coeff.c5_im)*r4, cfg.input_frac) + ...
      bitsra(int64(coeff.c7_im)*r6, cfg.input_frac);
    raw_i = bitsra(i*gr - q*gi, cfg.coeff_frac);
    raw_q = bitsra(i*gi + q*gr, cfg.coeff_frac);
    [yo_i(n), sat_i] = saturate_int(raw_i, cfg.input_w);
    [yo_q(n), sat_q] = saturate_int(raw_q, cfg.input_w);
    sat(n) = sat_i || sat_q;
  end
end

function [value, saturated] = saturate_int(value, width)
  maximum = int64(2^(width-1)-1); minimum = -int64(2^(width-1));
  saturated = value > maximum || value < minimum;
  value = min(max(value, minimum), maximum);
end

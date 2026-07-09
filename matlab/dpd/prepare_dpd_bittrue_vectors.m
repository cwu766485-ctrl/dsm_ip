function prepare_dpd_bittrue_vectors(varargin)
% prepare_dpd_bittrue_vectors
% Generate deterministic Q1.15/Q2.14 vectors for dpd_poly RTL comparison.

  cfg.n_input = 256;
  cfg.seed = 19;
  cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
                         'out', 'dpd', 'bittrue');
  cfg.input_w = 16;
  cfg.input_frac = 15;
  cfg.coeff_w = 16;
  cfg.coeff_frac = 14;

  for n = 1:2:numel(varargin)
    cfg.(varargin{n}) = varargin{n + 1};
  end

  if ~exist(cfg.out_dir, 'dir')
    mkdir(cfg.out_dir);
  end

  rng(cfg.seed);
  n = (0:cfg.n_input-1).';
  i_rand = randi([-22000, 22000], cfg.n_input, 1);
  q_rand = randi([-22000, 22000], cfg.n_input, 1);
  i_edge = [0; 1; -1; 32767; -32768; 24000; -24000; 12345; -12345; 30000; -30000];
  q_edge = [0; -1; 1; -32768; 32767; -24000; 24000; -12345; 12345; 30000; -30000];
  i_q1_15 = i_rand;
  q_q1_15 = q_rand;
  i_q1_15(1:numel(i_edge)) = i_edge;
  q_q1_15(1:numel(q_edge)) = q_edge;

  coeff.c1_re = int32(16393);
  coeff.c1_im = int32(-5);
  coeff.c3_re = int32(8047);
  coeff.c3_im = int32(-3676);
  coeff.c5_re = int32(14905);
  coeff.c5_im = int32(-8624);

  [y_i, y_q, sat] = dpd_poly_int_model(i_q1_15, q_q1_15, coeff, cfg);

  input_tbl = table(n, int32(i_q1_15), int32(q_q1_15), ...
      'VariableNames', {'n','i_q1_15','q_q1_15'});
  expected_tbl = table(n, int32(y_i), int32(y_q), logical(sat), ...
      'VariableNames', {'n','i_q1_15','q_q1_15','saturated'});
  coeff_tbl = struct2table(coeff);

  writetable(input_tbl, fullfile(cfg.out_dir, 'dpd_input_iq.csv'));
  writetable(expected_tbl, fullfile(cfg.out_dir, 'dpd_expected_iq.csv'));
  writetable(coeff_tbl, fullfile(cfg.out_dir, 'dpd_coefficients.csv'));
end

function [yo_i, yo_q, sat] = dpd_poly_int_model(i_in, q_in, coeff, cfg)
  yo_i = zeros(size(i_in));
  yo_q = zeros(size(q_in));
  sat = false(size(i_in));

  for k = 1:numel(i_in)
    i = int64(i_in(k));
    q = int64(q_in(k));
    r2 = bitsra(i*i + q*q, cfg.input_frac);
    r4 = bitsra(r2*r2, cfg.input_frac);

    gr = int64(coeff.c1_re) + ...
         bitsra(int64(coeff.c3_re)*r2, cfg.input_frac) + ...
         bitsra(int64(coeff.c5_re)*r4, cfg.input_frac);
    gi = int64(coeff.c1_im) + ...
         bitsra(int64(coeff.c3_im)*r2, cfg.input_frac) + ...
         bitsra(int64(coeff.c5_im)*r4, cfg.input_frac);

    raw_i = bitsra(i*gr - q*gi, cfg.coeff_frac);
    raw_q = bitsra(i*gi + q*gr, cfg.coeff_frac);
    [yo_i(k), sat_i] = saturate_int(raw_i, cfg.input_w);
    [yo_q(k), sat_q] = saturate_int(raw_q, cfg.input_w);
    sat(k) = sat_i || sat_q;
  end
end

function [y, sat] = saturate_int(x, width)
  maxv = int64(2^(width-1) - 1);
  minv = int64(-2^(width-1));
  sat = (x > maxv) || (x < minv);
  y = min(max(int64(x), minv), maxv);
end

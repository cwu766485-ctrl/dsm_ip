function prepare_dpd_memory_poly_bittrue_vectors(varargin)
% Generate deterministic Q1.15/Q2.14 vectors for dpd_memory_poly RTL.

  cfg.n_input = 256;
  cfg.seed = 29;
  cfg.active_taps = 4;
  cfg.input_w = 16;
  cfg.input_frac = 15;
  cfg.coeff_frac = 14;
  cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
                         'out', 'dpd', 'bittrue');
  for n = 1:2:numel(varargin)
    cfg.(varargin{n}) = varargin{n + 1};
  end

  if ~exist(cfg.out_dir, 'dir'), mkdir(cfg.out_dir); end
  rng(cfg.seed);
  index = (0:cfg.n_input-1).';
  i_in = randi([-22000, 22000], cfg.n_input, 1);
  q_in = randi([-22000, 22000], cfg.n_input, 1);
  i_edge = [0; 1; -1; 32767; -32768; 24000; -24000; 30000; -30000];
  q_edge = [0; -1; 1; -32768; 32767; -24000; 24000; 30000; -30000];
  i_in(1:numel(i_edge)) = i_edge;
  q_in(1:numel(q_edge)) = q_edge;

  c1_re = int32([15000, 1200, -640, 256]);
  c1_im = int32([-120, 320, -192, 96]);
  c3_re = int32([4200, -800, 384, -128]);
  c3_im = int32([-900, 256, -160, 64]);
  c5_re = int32([1800, -320, 128, -48]);
  c5_im = int32([-400, 160, -64, 24]);

  [y_i, y_q, saturated] = memory_poly_model(i_in, q_in, c1_re, ...
      c1_im, c3_re, c3_im, c5_re, c5_im, cfg);

  writetable(table(index, int32(i_in), int32(q_in), ...
      'VariableNames', {'n','i_q1_15','q_q1_15'}), ...
      fullfile(cfg.out_dir, 'dpd_mp_input_iq.csv'));
  writetable(table(index, int32(y_i), int32(y_q), saturated, ...
      'VariableNames', {'n','i_q1_15','q_q1_15','saturated'}), ...
      fullfile(cfg.out_dir, 'dpd_mp_expected_iq.csv'));

  fid = fopen(fullfile(cfg.out_dir, 'dpd_mp_coefficients.csv'), 'w');
  assert(fid >= 0, 'Cannot create memory-polynomial coefficient file.');
  cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
  fprintf(fid, 'active_taps');
  for tap = 0:3
    for order = [1, 3, 5]
      fprintf(fid, ',c%d_re_t%d,c%d_im_t%d', order, tap, order, tap);
    end
  end
  fprintf(fid, '\n%d', cfg.active_taps);
  for tap = 1:4
    fprintf(fid, ',%d,%d,%d,%d,%d,%d', c1_re(tap), c1_im(tap), ...
        c3_re(tap), c3_im(tap), c5_re(tap), c5_im(tap));
  end
  fprintf(fid, '\n');
end

function [y_i, y_q, saturated] = memory_poly_model(i_in, q_in, ...
    c1_re, c1_im, c3_re, c3_im, c5_re, c5_im, cfg)
  history_i = zeros(4, 1, 'int64');
  history_q = zeros(4, 1, 'int64');
  y_i = zeros(size(i_in), 'int64');
  y_q = zeros(size(q_in), 'int64');
  saturated = false(size(i_in));
  for n = 1:numel(i_in)
    history_i(2:4) = history_i(1:3);
    history_q(2:4) = history_q(1:3);
    history_i(1) = int64(i_in(n));
    history_q(1) = int64(q_in(n));
    acc_i = int64(0);
    acc_q = int64(0);
    for tap = 1:cfg.active_taps
      ii = history_i(tap);
      qq = history_q(tap);
      r2 = bitsra(ii*ii + qq*qq, cfg.input_frac);
      r4 = bitsra(r2*r2, cfg.input_frac);
      gr = int64(c1_re(tap)) + bitsra(int64(c3_re(tap))*r2, cfg.input_frac) + ...
           bitsra(int64(c5_re(tap))*r4, cfg.input_frac);
      gi = int64(c1_im(tap)) + bitsra(int64(c3_im(tap))*r2, cfg.input_frac) + ...
           bitsra(int64(c5_im(tap))*r4, cfg.input_frac);
      acc_i = acc_i + bitsra(ii*gr - qq*gi, cfg.coeff_frac);
      acc_q = acc_q + bitsra(ii*gi + qq*gr, cfg.coeff_frac);
    end
    [y_i(n), sat_i] = saturate_int(acc_i, cfg.input_w);
    [y_q(n), sat_q] = saturate_int(acc_q, cfg.input_w);
    saturated(n) = sat_i || sat_q;
  end
end

function [y, saturated] = saturate_int(x, width)
  max_value = int64(2^(width-1) - 1);
  min_value = int64(-2^(width-1));
  saturated = (x > max_value) || (x < min_value);
  y = min(max(x, min_value), max_value);
end

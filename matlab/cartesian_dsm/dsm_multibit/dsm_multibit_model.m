function y = dsm_multibit_model(x, alg, nbits)
% Exploratory Cartesian multibit DSM model.
%
% Input x is signed fixed-point, normally Q1.15. Output y is signed integer
% quantizer code. For nbits=4, y is in approximately [-7, +7].

  if nargin < 3
    nbits = 4;
  end
  x = int64(x(:));
  alg = lower(string(alg));
  alg = erase(alg, "dsm");
  q = quantizer_cfg(nbits);

  switch alg
    case {"lp", "lp1"}
      y = model_lp1_mb(x, 16, false, q);
    case {"lp2", "lpdsm2"}
      y = model_lp2_mb(x, 16, false, q);
    case {"ef", "ef1"}
      y = model_ef1_mb(x, 16, false, q);
    case "ef2"
      y = model_ef2_mb(x, 16, false, q, int64(2), int64(-1), 0);
    case "mash11"
      y = model_mash11_mb(x, 16, false, q);
    case "mash111"
      y = model_mash111_mb(x, 16, false, q);
    case "mash22"
      y = model_mash22_mb(x, 16, false, q, int64(2), int64(-1), 0);
    otherwise
      error('Unsupported multibit DSM algorithm: %s', alg);
  end
end

function q = quantizer_cfg(nbits)
  if nbits < 2
    error('Multibit DSM requires nbits >= 2');
  end
  q.nbits = nbits;
  q.code_max = int64(2^(nbits - 1) - 1);
  q.fb_fullscale = int64(32767);
end

function [code, fb] = quantize_mb(v, q)
  code = int64(round(double(v) * double(q.code_max) / double(q.fb_fullscale)));
  code = min(max(code, -q.code_max), q.code_max);
  fb = int64(round(double(code) * double(q.fb_fullscale) / double(q.code_max)));
end

function y = model_lp1_mb(x, acc_w, saturate, q)
  v = int64(0);
  yreg = int64(0);
  y = zeros(numel(x), 1, 'int64');
  for n = 1:numel(x)
    y(n) = yreg;
    [code, fb] = quantize_mb(v, q);
    v = sat_or_wrap(v + x(n) - fb, acc_w, saturate);
    yreg = code;
  end
end

function y = model_lp2_mb(x, acc_w, saturate, q)
  v1 = int64(0); v2 = int64(0);
  yreg = int64(0);
  y = zeros(numel(x), 1, 'int64');
  for n = 1:numel(x)
    y(n) = yreg;
    [code, fb] = quantize_mb(v2, q);
    v1n = sat_or_wrap(v1 + x(n) - fb, acc_w, saturate);
    v2n = sat_or_wrap(v2 + v1n - fb, acc_w, saturate);
    v1 = v1n; v2 = v2n;
    yreg = code;
  end
end

function y = model_ef1_mb(x, acc_w, saturate, q)
  e1 = int64(0);
  yreg = int64(0);
  y = zeros(numel(x), 1, 'int64');
  for n = 1:numel(x)
    y(n) = yreg;
    yi = sat_or_wrap(x(n) + e1, acc_w, saturate);
    [code, fb] = quantize_mb(yi, q);
    e1 = yi - fb;
    yreg = code;
  end
end

function y = model_ef2_mb(x, acc_w, saturate, q, b1, b2, coeff_shift)
  e1 = int64(0); e2 = int64(0);
  yreg = int64(0);
  y = zeros(numel(x), 1, 'int64');
  for n = 1:numel(x)
    y(n) = yreg;
    yi = sat_or_wrap(x(n) + round_shift(b1 * e1, coeff_shift) + round_shift(b2 * e2, coeff_shift), acc_w, saturate);
    [code, fb] = quantize_mb(yi, q);
    e0 = yi - fb;
    e2 = e1; e1 = e0;
    yreg = code;
  end
end

function y = model_mash11_mb(x, acc_w, saturate, q)
  e1 = int64(0); e2 = int64(0);
  e1_reg = int64(0);
  y1_reg = int64(0); y2_prev = int64(0);
  yreg = int64(0);
  y = zeros(numel(x), 1, 'int64');
  for n = 1:numel(x)
    y(n) = yreg;
    y1 = sat_or_wrap(x(n) + e1, acc_w, saturate);
    [c1, fb1] = quantize_mb(y1, q);
    e1n = y1 - fb1;

    y2 = sat_or_wrap(e1_reg + e2, acc_w, saturate);
    [c2, fb2] = quantize_mb(y2, q);
    e2n = y2 - fb2;

    yreg = y1_reg + (c2 - y2_prev);
    y2_prev = c2;
    y1_reg = c1;
    e1_reg = e1n;
    e1 = e1n; e2 = e2n;
  end
end

function y = model_mash111_mb(x, acc_w, saturate, q)
  e1 = int64(0); e2 = int64(0); e3 = int64(0);
  e1_reg = int64(0); e2_reg = int64(0);
  y1_reg1 = int64(0); y1_reg2 = int64(0);
  y2_reg = int64(0);
  y2_prev = int64(0); y3_prev1 = int64(0); y3_prev2 = int64(0);
  yreg = int64(0);
  y = zeros(numel(x), 1, 'int64');
  for n = 1:numel(x)
    y(n) = yreg;
    y1 = sat_or_wrap(x(n) + e1, acc_w, saturate);
    [c1, fb1] = quantize_mb(y1, q);
    e1n = y1 - fb1;

    y2 = sat_or_wrap(e1_reg + e2, acc_w, saturate);
    [c2, fb2] = quantize_mb(y2, q);
    e2n = y2 - fb2;

    y3 = sat_or_wrap(e2_reg + e3, acc_w, saturate);
    [c3, fb3] = quantize_mb(y3, q);
    e3n = y3 - fb3;

    yreg = y1_reg2 + (y2_reg - y2_prev) + (c3 - 2 * y3_prev1 + y3_prev2);
    y2_prev = y2_reg;
    y3_prev2 = y3_prev1;
    y3_prev1 = c3;
    y1_reg2 = y1_reg1;
    y1_reg1 = c1;
    y2_reg = c2;
    e1_reg = e1n;
    e2_reg = e2n;
    e1 = e1n; e2 = e2n; e3 = e3n;
  end
end

function y = model_mash22_mb(x, acc_w, saturate, q, b1, b2, coeff_shift)
  e11 = int64(0); e12 = int64(0); e21 = int64(0); e22 = int64(0);
  e10_reg = int64(0);
  y1_reg = int64(0);
  y2_prev1 = int64(0); y2_prev2 = int64(0);
  yreg = int64(0);
  y = zeros(numel(x), 1, 'int64');
  for n = 1:numel(x)
    y(n) = yreg;
    y1 = sat_or_wrap(x(n) + round_shift(b1 * e11, coeff_shift) + round_shift(b2 * e12, coeff_shift), acc_w, saturate);
    [c1, fb1] = quantize_mb(y1, q);
    e10 = y1 - fb1;

    y2 = sat_or_wrap(e10_reg + round_shift(b1 * e21, coeff_shift) + round_shift(b2 * e22, coeff_shift), acc_w, saturate);
    [c2, fb2] = quantize_mb(y2, q);
    e20 = y2 - fb2;

    yreg = y1_reg + c2 - 2 * y2_prev1 + y2_prev2;
    e12 = e11; e11 = e10;
    e10_reg = e10;
    y1_reg = c1;
    e22 = e21; e21 = e20;
    y2_prev2 = y2_prev1;
    y2_prev1 = c2;
  end
end

function y = sat_or_wrap(v, width, saturate)
  vmax = int64(2)^(width-1) - 1;
  vmin = -int64(2)^(width-1);
  if saturate
    y = min(max(v, vmin), vmax);
  else
    y = wrap_tc(v, width);
  end
end

function y = wrap_tc(v, width)
  m = int64(2)^width;
  h = int64(2)^(width-1);
  y = mod(v + h, m) - h;
end

function y = round_shift(v, sh)
  if sh <= 0
    y = v;
  elseif v >= 0
    y = int64(floor(double(v + int64(2)^(sh-1)) / double(int64(2)^sh)));
  else
    y = int64(floor(double(v - int64(2)^(sh-1)) / double(int64(2)^sh)));
  end
end

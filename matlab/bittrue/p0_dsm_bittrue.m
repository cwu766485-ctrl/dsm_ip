function y = p0_dsm_bittrue(x, alg)
% Fixed-point P0 DSM model aligned to RTL registered-output dumps.

  x = int64(x(:));
  alg = lower(string(alg));

  switch alg
    case "lp1"
      y = model_lp1(x, 32, false);
    case "lp2"
      y = model_lp2(x, 40, true);
    case "ef1"
      y = model_ef1(x, 28, true);
    case "ef2"
      y = model_ef2(x, 28, true, int64(2), int64(-1), 0);
    case "mash11"
      y = model_mash11(x, 18, true);
    case "mash111"
      y = model_mash111(x, 18, true);
    case "mash22"
      y = model_mash22(x, 18, true, int64(2), int64(-1), 0);
    otherwise
      error('Unknown P0 DSM algorithm: %s', alg);
  end
end

function y = model_lp1(x, acc_w, saturate)
  qpos = int64(32767); qneg = -qpos;
  v = int64(0);
  yreg = int64(1);
  y = zeros(numel(x), 1, 'int64');
  for n = 1:numel(x)
    y(n) = yreg;
    y_next = tern(v >= 0, int64(1), int64(0));
    q = tern(v >= 0, qpos, qneg);
    v = sat_or_wrap(v + x(n) - q, acc_w, saturate);
    yreg = y_next;
  end
end

function y = model_lp2(x, acc_w, saturate)
  qpos = int64(32767); qneg = -qpos;
  v1 = int64(0); v2 = int64(0);
  yreg = int64(1);
  y = zeros(numel(x), 1, 'int64');
  for n = 1:numel(x)
    y(n) = yreg;
    y_next = tern(v2 >= 0, int64(1), int64(0));
    q = tern(v2 >= 0, qpos, qneg);
    v1n = sat_or_wrap(v1 + x(n) - q, acc_w, saturate);
    v2n = sat_or_wrap(v2 + v1n - q, acc_w, saturate);
    v1 = v1n; v2 = v2n;
    yreg = y_next;
  end
end

function y = model_ef1(x, acc_w, saturate)
  qpos = int64(32767); qneg = -qpos;
  e1 = int64(0);
  yreg = int64(1);
  y = zeros(numel(x), 1, 'int64');
  for n = 1:numel(x)
    y(n) = yreg;
    yi = sat_or_wrap(x(n) + e1, acc_w, saturate);
    q = tern(yi >= 0, qpos, qneg);
    e1 = yi - q;
    yreg = tern(yi >= 0, int64(1), int64(0));
  end
end

function y = model_ef2(x, acc_w, saturate, b1, b2, coeff_shift)
  qpos = int64(32767); qneg = -qpos;
  e1 = int64(0); e2 = int64(0);
  yreg = int64(1);
  y = zeros(numel(x), 1, 'int64');
  for n = 1:numel(x)
    y(n) = yreg;
    yi = sat_or_wrap(x(n) + round_shift(b1 * e1, coeff_shift) + round_shift(b2 * e2, coeff_shift), acc_w, saturate);
    q = tern(yi >= 0, qpos, qneg);
    e0 = yi - q;
    e2 = e1; e1 = e0;
    yreg = tern(yi >= 0, int64(1), int64(0));
  end
end

function y = model_mash11(x, acc_w, saturate)
  qpos = int64(32767); qneg = -qpos;
  e1 = int64(0); e2 = int64(0);
  y2_prev = int64(0);
  yreg = int64(1);
  y = zeros(numel(x), 1, 'int64');
  for n = 1:numel(x)
    y(n) = yreg;
    y1 = sat_or_wrap(x(n) + e1, acc_w, saturate);
    y1_pm = tern(y1 >= 0, int64(1), int64(-1));
    q1 = tern(y1 >= 0, qpos, qneg);
    e1n = y1 - q1;

    y2 = sat_or_wrap(e1n + e2, acc_w, saturate);
    y2_pm = tern(y2 >= 0, int64(1), int64(-1));
    q2 = tern(y2 >= 0, qpos, qneg);
    e2n = y2 - q2;

    yreg = y1_pm + (y2_pm - y2_prev);
    y2_prev = y2_pm;
    e1 = e1n; e2 = e2n;
  end
end

function y = model_mash111(x, acc_w, saturate)
  qpos = int64(32767); qneg = -qpos;
  e1 = int64(0); e2 = int64(0); e3 = int64(0);
  y2_prev = int64(0); y3_prev1 = int64(0); y3_prev2 = int64(0);
  yreg = int64(1);
  y = zeros(numel(x), 1, 'int64');
  for n = 1:numel(x)
    y(n) = yreg;
    y1 = sat_or_wrap(x(n) + e1, acc_w, saturate);
    y1_pm = tern(y1 >= 0, int64(1), int64(-1));
    q1 = tern(y1 >= 0, qpos, qneg);
    e1n = y1 - q1;

    y2 = sat_or_wrap(e1n + e2, acc_w, saturate);
    y2_pm = tern(y2 >= 0, int64(1), int64(-1));
    q2 = tern(y2 >= 0, qpos, qneg);
    e2n = y2 - q2;

    y3 = sat_or_wrap(e2n + e3, acc_w, saturate);
    y3_pm = tern(y3 >= 0, int64(1), int64(-1));
    q3 = tern(y3 >= 0, qpos, qneg);
    e3n = y3 - q3;

    yreg = y1_pm + (y2_pm - y2_prev) + (y3_pm - 2 * y3_prev1 + y3_prev2);
    y2_prev = y2_pm;
    y3_prev2 = y3_prev1;
    y3_prev1 = y3_pm;
    e1 = e1n; e2 = e2n; e3 = e3n;
  end
end

function y = model_mash22(x, acc_w, saturate, b1, b2, coeff_shift)
  qpos = int64(32767); qneg = -qpos;
  e11 = int64(0); e12 = int64(0); e21 = int64(0); e22 = int64(0);
  y2_prev1 = int64(0); y2_prev2 = int64(0);
  yreg = int64(1);
  y = zeros(numel(x), 1, 'int64');
  for n = 1:numel(x)
    y(n) = yreg;
    y1 = sat_or_wrap(x(n) + round_shift(b1 * e11, coeff_shift) + round_shift(b2 * e12, coeff_shift), acc_w, saturate);
    y1_pm = tern(y1 >= 0, int64(1), int64(-1));
    q1 = tern(y1 >= 0, qpos, qneg);
    e10 = y1 - q1;

    y2 = sat_or_wrap(e10 + round_shift(b1 * e21, coeff_shift) + round_shift(b2 * e22, coeff_shift), acc_w, saturate);
    y2_pm = tern(y2 >= 0, int64(1), int64(-1));
    q2 = tern(y2 >= 0, qpos, qneg);
    e20 = y2 - q2;

    yreg = y1_pm + y2_pm - 2 * y2_prev1 + y2_prev2;
    e12 = e11; e11 = e10;
    e22 = e21; e21 = e20;
    y2_prev2 = y2_prev1;
    y2_prev1 = y2_pm;
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
    return;
  end
  half = int64(2)^(sh-1);
  if v >= 0
    y = floor(double(v + half) / double(int64(2)^sh));
  else
    y = floor(double(v - half) / double(int64(2)^sh));
  end
  y = int64(y);
end

function y = tern(c, a, b)
  if c
    y = a;
  else
    y = b;
  end
end

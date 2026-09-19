function [y, core] = bp_ef4_fs4_model(x, varargin)
% BP_EF4_FS4_MODEL Fixed-point Fs/4 fourth-order BP EFDSM reference.
% The NTF is (1 + z^-2)^2. This is an experimental, one-bit candidate.

  p = inputParser;
  addParameter(p, 'acc_w', 28);
  addParameter(p, 'saturate', true);
  addParameter(p, 'c2_num', -2);
  addParameter(p, 'c4_num', -1);
  parse(p, varargin{:});
  acc_w = p.Results.acc_w;
  saturate = logical(p.Results.saturate);
  c2_num = int64(p.Results.c2_num);
  c4_num = int64(p.Results.c4_num);

  x = int64(x(:)); qpos = int64(32767); qneg = -qpos;
  e1 = int64(0); e2 = int64(0); e3 = int64(0); e4 = int64(0);
  yreg = int64(1); y = zeros(numel(x), 1, 'int64'); core = y;
  for n = 1:numel(x)
    y(n) = yreg;
    v = sat_or_wrap(x(n) + c2_num*e2 + c4_num*e4, acc_w, saturate);
    q = tern(v >= 0, qpos, qneg);
    e0 = sat_or_wrap(v - q, acc_w, false);
    e4 = e3; e3 = e2; e2 = e1; e1 = e0;
    yreg = tern(v >= 0, int64(1), int64(0)); core(n) = yreg;
  end
end

function y = sat_or_wrap(v, width, saturate)
  vmax = int64(2)^(width-1) - 1; vmin = -int64(2)^(width-1);
  if saturate, y = min(max(v, vmin), vmax);
  else, y = mod(v + int64(2)^(width-1), int64(2)^width) - int64(2)^(width-1);
  end
end
function y = tern(c, a, b), if c, y = a; else, y = b; end, end

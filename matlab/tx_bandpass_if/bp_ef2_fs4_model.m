function [y, core] = bp_ef2_fs4_model(x, varargin)
% BP_EF2_FS4_MODEL Fixed-point Fs/4 bandpass EFDSM reference.
%   X is a real Q1.15 IF sequence. The NTF is 1 + z^-2, with zeros at Fs/4.

  p = inputParser;
  addParameter(p, 'acc_w', 28);
  addParameter(p, 'saturate', true);
  parse(p, varargin{:});
  acc_w = p.Results.acc_w;
  saturate = logical(p.Results.saturate);

  x = int64(x(:));
  qpos = int64(32767);
  qneg = -qpos;
  e1 = int64(0);
  e2 = int64(0);
  yreg = int64(1);
  y = zeros(numel(x), 1, 'int64');
  core = zeros(numel(x), 1, 'int64');

  for n = 1:numel(x)
    y(n) = yreg;
    v = sat_or_wrap(x(n) - e2, acc_w, saturate);
    q = tern(v >= 0, qpos, qneg);
    e0 = sat_or_wrap(v - q, acc_w, false);
    e2 = e1;
    e1 = e0;
    yreg = tern(v >= 0, int64(1), int64(0));
    core(n) = yreg;
  end
end

function y = sat_or_wrap(v, width, saturate)
  vmax = int64(2)^(width-1) - 1;
  vmin = -int64(2)^(width-1);
  if saturate
    y = min(max(v, vmin), vmax);
  else
    y = mod(v + int64(2)^(width-1), int64(2)^width) - int64(2)^(width-1);
  end
end

function y = tern(c, a, b)
  if c
    y = a;
  else
    y = b;
  end
end

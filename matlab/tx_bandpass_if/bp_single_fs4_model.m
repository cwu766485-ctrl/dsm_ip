function y = bp_single_fs4_model(x, varargin)
% BP_SINGLE_FS4_MODEL Fixed-point resonator single-loop BPDSM reference.
%   The linearized NTF is 1 + z^-2, with zeros at +/- Fs/4.

  p = inputParser;
  addParameter(p, 'acc_w', 28);
  addParameter(p, 'saturate', true);
  parse(p, varargin{:});
  acc_w = p.Results.acc_w;
  saturate = logical(p.Results.saturate);

  x = int64(x(:));
  qpos = int64(32767);
  qneg = -qpos;
  s1 = int64(0);
  s2 = int64(0);
  yreg = int64(1);
  y = zeros(numel(x), 1, 'int64');

  for n = 1:numel(x)
    y(n) = yreg;
    q = tern(yreg ~= 0, qpos, qneg);
    s1n = sat_or_wrap(x(n) - q - s2, acc_w, saturate);
    s2n = s1;
    yreg = tern(-s2n >= 0, int64(1), int64(0));
    s1 = s1n;
    s2 = s2n;
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

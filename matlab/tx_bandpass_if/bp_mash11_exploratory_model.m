function y = bp_mash11_exploratory_model(x, varargin)
% BP_MASH11_EXPLORATORY_MODEL Initial multilevel BP MASH 1-1 exploration.
%   This is intentionally not a one-bit DPA output. It keeps the {-3,-1,+1,+3}
%   digital cancellation result so hard-limiting loss can be measured.

  p = inputParser;
  addParameter(p, 'interstage_scale', 16);
  parse(p, varargin{:});
  scale = int64(p.Results.interstage_scale);

  x = int64(x(:));
  qpos = int64(32767); qneg = -qpos;
  e1 = [int64(0), int64(0)];
  e2 = [int64(0), int64(0)];
  y1reg = int64(1); y2reg = int64(1);
  y2d1 = int64(1); y2d2 = int64(1);
  y = zeros(numel(x), 1, 'int64');
  for n = 1:numel(x)
    y(n) = pm1(y1reg) - (pm1(y2reg) + pm1(y2d2));
    v1 = x(n) - e1(2);
    q1 = tern(v1 >= 0, qpos, qneg);
    e1next = v1 - q1;
    y1next = tern(v1 >= 0, int64(1), int64(0));
    v2 = idivide(e1(1), scale, 'fix') - e2(2);
    q2 = tern(v2 >= 0, qpos, qneg);
    e2next = v2 - q2;
    y2next = tern(v2 >= 0, int64(1), int64(0));
    e1 = [e1next, e1(1)];
    e2 = [e2next, e2(1)];
    y2d2 = y2d1; y2d1 = y2reg;
    y1reg = y1next; y2reg = y2next;
  end
end

function y = pm1(bit)
  y = tern(bit ~= 0, int64(1), int64(-1));
end

function y = tern(c, a, b)
  if c, y = a; else, y = b; end
end

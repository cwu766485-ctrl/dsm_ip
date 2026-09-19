function [level, core] = bp_ef2_3level_fs4_model(x, varargin)
% BP_EF2_3LEVEL_FS4_MODEL Three-level Fs/4 bandpass error-feedback DSM.
% The error-feedback NTF is 1+z^-2.  LEVEL is {-1,0,+1}; it maps to two
% one-bit PA branches as {-1,-1}, {-1,+1}, {+1,+1}, respectively, followed
% by a fixed gain normalization.  This is a fixed-point feasibility model.

  p = inputParser;
  addParameter(p, 'acc_w', 28);
  addParameter(p, 'saturate', true);
  addParameter(p, 'threshold_num', 1);
  addParameter(p, 'threshold_den', 2);
  parse(p, varargin{:}); c = p.Results;
  if c.threshold_den <= 0 || c.threshold_num < 0
    error('threshold must be nonnegative with a positive denominator.');
  end

  x = int64(x(:)); fs = int64(32767);
  threshold = idivide(fs * int64(c.threshold_num), int64(c.threshold_den), 'fix');
  e1 = int64(0); e2 = int64(0); level = zeros(numel(x),1,'int64'); core = level;
  for n = 1:numel(x)
    v = sat_or_wrap(x(n) - e2, c.acc_w, logical(c.saturate));
    if v > threshold
      q = fs; level(n) = 1;
    elseif v < -threshold
      q = -fs; level(n) = -1;
    else
      q = int64(0); level(n) = 0;
    end
    e0 = sat_or_wrap(v-q, c.acc_w, false);
    e2 = e1; e1 = e0; core(n) = v;
  end
end

function y = sat_or_wrap(v, width, saturate)
  vmax = int64(2)^(width-1)-1; vmin = -int64(2)^(width-1);
  if saturate, y = min(max(v,vmin),vmax);
  else, y = mod(v+int64(2)^(width-1),int64(2)^width)-int64(2)^(width-1); end
end

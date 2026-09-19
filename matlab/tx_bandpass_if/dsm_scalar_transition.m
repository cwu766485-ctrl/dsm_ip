function [out, state] = dsm_scalar_transition(candidate, x, state, varargin)
% DSM_SCALAR_TRANSITION Frozen scalar fixed-point transition for temporal64.
% This is the source model for seven 256-QAM candidates. One invocation is
% one final-rate (14-GS/s) sample. The caller owns 64-step composition.

  p = inputParser;
  addParameter(p, 'acc_w', 28);
  addParameter(p, 'saturate', true);
  addParameter(p, 'threshold_num', 1);
  addParameter(p, 'threshold_den', 2);
  parse(p, varargin{:}); c = p.Results;
  x = int64(x);
  if nargin < 3 || isempty(state), state = reset_state(candidate); end

  switch lower(candidate)
    case 'bpdsm2'
      % The behavioral reference emits the registered decision, then updates
      % the resonator.  Preserve that observable sample phase for temporal64.
      emitted_y0 = state.y0;
      q = sign_code(emitted_y0);
      s1n = sat_or_wrap(x - q - state.s2, c.acc_w, c.saturate);
      s2n = state.s1;
      y0 = (-s2n >= 0);
      state.s1 = s1n; state.s2 = s2n; state.y0 = y0;
      out = onebit_output(emitted_y0);

    case 'bp_efdsm2'
      % Match bp_ef2_fs4_model: output is the pre-update decision register.
      emitted_y0 = state.y0;
      v = sat_or_wrap(x - state.e2, c.acc_w, c.saturate);
      y0 = (v >= 0);
      e0 = sat_or_wrap(v - sign_code(y0), c.acc_w, false);
      state.e2 = state.e1; state.e1 = e0; state.y0 = y0;
      out = onebit_output(emitted_y0);

    case 'bp_efdsm4'
      % Match bp_ef4_fs4_model: output is the pre-update decision register.
      emitted_y0 = state.y0;
      v = sat_or_wrap(x - 2*state.e2 - state.e4, c.acc_w, c.saturate);
      y0 = (v >= 0);
      e0 = sat_or_wrap(v - sign_code(y0), c.acc_w, false);
      state.e4 = state.e3; state.e3 = state.e2; state.e2 = state.e1;
      state.e1 = e0; state.y0 = y0;
      out = onebit_output(emitted_y0);

    case {'bp3l_efdsm2', 'bp3l_efdsm4'}
      if c.threshold_den <= 0 || c.threshold_num < 0
        error('threshold must be nonnegative with a positive denominator.');
      end
      th = idivide(int64(32767)*int64(c.threshold_num), int64(c.threshold_den), 'fix');
      if strcmpi(candidate, 'bp3l_efdsm2')
        v = sat_or_wrap(x - state.e2, c.acc_w, c.saturate);
      else
        v = sat_or_wrap(x - 2*state.e2 - state.e4, c.acc_w, c.saturate);
      end
      if v > th
        level = int64(1); q = int64(32767);
      elseif v < -th
        level = int64(-1); q = int64(-32767);
      else
        level = int64(0); q = int64(0);
      end
      e0 = sat_or_wrap(v - q, c.acc_w, false);
      if strcmpi(candidate, 'bp3l_efdsm4')
        state.e4 = state.e3; state.e3 = state.e2; state.e2 = state.e1;
      else
        state.e2 = state.e1;
      end
      state.e1 = e0; state.level = level;
      out = threelevel_output(level);

    case 'bp_mash11'
      % Matches bp_mash11_exploratory_model, not the unrelated low-pass RTL
      % MASH1-1 core. This model is frozen before any BP-MASH temporal RTL.
      out = struct('y0', state.y1reg, 'y1', state.y1reg, 'y2', state.y2reg, ...
        'level', int64(0), 'combined', pm1(state.y1reg) - (pm1(state.y2reg) + pm1(state.y2d2)));
      v1 = x - state.e1d2;
      y1next = (v1 >= 0); e1next = v1 - sign_code(y1next);
      v2 = idivide(state.e1d1, int64(16), 'fix') - state.e2d2;
      y2next = (v2 >= 0); e2next = v2 - sign_code(y2next);
      state.e1d2 = state.e1d1; state.e1d1 = e1next;
      state.e2d2 = state.e2d1; state.e2d1 = e2next;
      state.y2d2 = state.y2d1; state.y2d1 = state.y2reg;
      state.y1reg = y1next; state.y2reg = y2next;

    case 'crfb_smash2'
      [raw, state] = crfb_smash2_scalar_transition(x, state, ...
        'acc_w', c.acc_w, 'saturate', c.saturate);
      out = struct('y0', raw.y1, 'y1', raw.y1, 'y2', raw.y2, ...
        'level', int64(0), 'combined', raw.v1);

    otherwise
      error('Unsupported DSM candidate: %s', candidate);
  end
end

function state = reset_state(candidate)
  switch lower(candidate)
    case 'bpdsm2'
      state = struct('s1',int64(0),'s2',int64(0),'y0',true);
    case 'bp_efdsm2'
      state = struct('e1',int64(0),'e2',int64(0),'y0',true);
    case 'bp_efdsm4'
      state = struct('e1',int64(0),'e2',int64(0),'e3',int64(0),'e4',int64(0),'y0',true);
    case 'bp3l_efdsm2'
      state = struct('e1',int64(0),'e2',int64(0),'level',int64(0));
    case 'bp3l_efdsm4'
      state = struct('e1',int64(0),'e2',int64(0),'e3',int64(0),'e4',int64(0),'level',int64(0));
    case 'bp_mash11'
      state = struct('e1d1',int64(0),'e1d2',int64(0),'e2d1',int64(0),'e2d2',int64(0), ...
        'y1reg',true,'y2reg',true,'y2d1',true,'y2d2',true);
    case 'crfb_smash2'
      state = [];
    otherwise
      error('Unsupported DSM candidate: %s', candidate);
  end
end

function out = onebit_output(y0)
  out = struct('y0',logical(y0),'y1',logical(y0),'y2',false,'level',int64(0),'combined',pm1(y0));
end

function out = threelevel_output(level)
  % {-1,0,+1} -> {(-,-),(-,+),(+,+)} for two one-bit PA branches.
  if level < 0, y1 = false; y2 = false;
  elseif level > 0, y1 = true; y2 = true;
  else, y1 = false; y2 = true;
  end
  out = struct('y0',y1,'y1',y1,'y2',y2,'level',int64(level),'combined',int64(2)*int64(level));
end

function q = sign_code(bit)
  if bit, q = int64(32767); else, q = int64(-32767); end
end

function q = pm1(bit)
  if bit, q = int64(1); else, q = int64(-1); end
end

function y = sat_or_wrap(v, width, saturate)
  hi = int64(2)^(width-1)-1; lo = -int64(2)^(width-1);
  if saturate, y = min(max(int64(v),lo),hi);
  else, y = mod(int64(v)+int64(2)^(width-1),int64(2)^width)-int64(2)^(width-1); end
end

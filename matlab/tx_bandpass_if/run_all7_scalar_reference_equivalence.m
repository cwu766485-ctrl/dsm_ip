function results = run_all7_scalar_reference_equivalence(varargin)
% RUN_ALL7_SCALAR_REFERENCE_EQUIVALENCE
% Proves that each frozen scalar transition emits exactly the samples used by
% its 256-QAM behavioral reference.  This check is intentionally separate
% from temporal64 composition: it locks observable sample phase before RTL.

  p = inputParser;
  addParameter(p, 'samples', 16384);
  addParameter(p, 'seed', 20260915);
  parse(p, varargin{:}); c = p.Results;
  rng(c.seed);
  x = int64(randi([-16384 16383], c.samples, 1));
  candidates = {'bpdsm2','bp_efdsm2','bp_efdsm4','bp3l_efdsm2', ...
    'bp3l_efdsm4','bp_mash11','crfb_smash2'};
  results = repmat(struct('candidate','','samples',0,'mismatches',0), numel(candidates), 1);

  for k = 1:numel(candidates)
    candidate = candidates{k};
    actual = scalar_trace(candidate, x);
    expected = reference_trace(candidate, x);
    mismatches = nnz(actual.y1 ~= expected.y1) + nnz(actual.y2 ~= expected.y2) + ...
      nnz(actual.level ~= expected.level) + nnz(actual.combined ~= expected.combined);
    results(k) = struct('candidate',candidate,'samples',numel(x),'mismatches',mismatches);
    disp(results(k));
    if mismatches ~= 0
      error('Scalar behavioral-reference equivalence failed for %s.', candidate);
    end
  end
end

function trace = scalar_trace(candidate, x)
  trace = struct('y1',false(numel(x),1),'y2',false(numel(x),1), ...
    'level',zeros(numel(x),1,'int64'),'combined',zeros(numel(x),1,'int64'));
  st = [];
  for n = 1:numel(x)
    [out,st] = dsm_scalar_transition(candidate,x(n),st);
    trace.y1(n)=out.y1; trace.y2(n)=out.y2;
    trace.level(n)=out.level; trace.combined(n)=out.combined;
  end
end

function trace = reference_trace(candidate, x)
  n = numel(x);
  trace = struct('y1',false(n,1),'y2',false(n,1), ...
    'level',zeros(n,1,'int64'),'combined',zeros(n,1,'int64'));
  switch candidate
    case 'bpdsm2'
      y = bp_single_fs4_model(x);
      trace.y1 = y ~= 0; trace.combined = pm1(trace.y1);
    case 'bp_efdsm2'
      y = bp_ef2_fs4_model(x);
      trace.y1 = y ~= 0; trace.combined = pm1(trace.y1);
    case 'bp_efdsm4'
      y = bp_ef4_fs4_model(x);
      trace.y1 = y ~= 0; trace.combined = pm1(trace.y1);
    case 'bp3l_efdsm2'
      trace.level = bp_ef2_3level_fs4_model(x);
      [trace.y1,trace.y2] = branches(trace.level);
      trace.combined = int64(2)*trace.level;
    case 'bp3l_efdsm4'
      trace.level = bp_ef4_3level_fs4_model(x);
      [trace.y1,trace.y2] = branches(trace.level);
      trace.combined = int64(2)*trace.level;
    case 'bp_mash11'
      trace = mash_stage_reference(x);
    case 'crfb_smash2'
      r = crfb_smash2_fs4_model(x);
      trace.y1 = r.y1; trace.y2 = r.y2; trace.combined = r.v1;
    otherwise
      error('Unsupported DSM candidate: %s', candidate);
  end
end

function trace = mash_stage_reference(x)
  % Independent expansion of bp_mash11_exploratory_model's observable
  % stage registers and digital-cancellation stream.
  n = numel(x);
  trace = struct('y1',false(n,1),'y2',false(n,1), ...
    'level',zeros(n,1,'int64'),'combined',zeros(n,1,'int64'));
  e1d1=int64(0); e1d2=int64(0); e2d1=int64(0); e2d2=int64(0);
  y1reg=true; y2reg=true; y2d1=true; y2d2=true;
  for k = 1:n
    trace.y1(k)=y1reg; trace.y2(k)=y2reg;
    trace.combined(k)=pm1(y1reg)-(pm1(y2reg)+pm1(y2d2));
    v1=x(k)-e1d2; y1next=(v1>=0); e1next=v1-sign_code(y1next);
    v2=idivide(e1d1,int64(16),'fix')-e2d2;
    y2next=(v2>=0); e2next=v2-sign_code(y2next);
    e1d2=e1d1; e1d1=e1next; e2d2=e2d1; e2d1=e2next;
    y2d2=y2d1; y2d1=y2reg; y1reg=y1next; y2reg=y2next;
  end
  if any(trace.combined ~= bp_mash11_exploratory_model(x))
    error('MASH stage reference diverges from bp_mash11_exploratory_model.');
  end
end

function [y1,y2] = branches(level)
  y1 = level > 0;
  y2 = level >= 0;
end

function y = pm1(bit)
  y = int64(2)*int64(bit)-int64(1);
end

function q = sign_code(bit)
  if bit, q = int64(32767); else, q = int64(-32767); end
end

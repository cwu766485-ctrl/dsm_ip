function results = run_all7_temporal64_contract(varargin)
% RUN_ALL7_TEMPORAL64_CONTRACT Check exact word composition for all seven DSMs.
% It does not claim RTL or 218.75-MHz timing. It freezes lane order, emitted
% PA streams and state handoff for the following implementation stages.
  p = inputParser; addParameter(p,'words',256); addParameter(p,'seed',20260915);
  parse(p,varargin{:}); c=p.Results; rng(c.seed);
  candidates = {'bpdsm2','bp_efdsm2','bp_efdsm4','bp3l_efdsm2','bp3l_efdsm4','bp_mash11','crfb_smash2'};
  x = int64(randi([-16384 16383], 64*c.words, 1));
  results = repmat(struct('candidate','','samples',0,'stream_mismatches',0,'final_state_equal',false), numel(candidates), 1);
  for k = 1:numel(candidates)
    candidate = candidates{k};
    [serial, serial_state] = run_serial(candidate, x);
    [packed, packed_state] = run_packed64(candidate, x);
    mismatch = nnz(serial.y0 ~= packed.y0) + nnz(serial.y1 ~= packed.y1) + ...
      nnz(serial.y2 ~= packed.y2) + nnz(serial.level ~= packed.level) + nnz(serial.combined ~= packed.combined);
    state_equal = isequaln(serial_state, packed_state);
    results(k) = struct('candidate',candidate,'samples',numel(x), ...
      'stream_mismatches',mismatch,'final_state_equal',state_equal);
    disp(results(k));
    if mismatch ~= 0 || ~state_equal
      error('temporal64 contract failed for %s.', candidate);
    end
  end
end

function [trace, state] = run_serial(candidate, x)
  state=[]; trace=empty_trace(numel(x));
  for n=1:numel(x), [out,state]=dsm_scalar_transition(candidate,x(n),state); trace=put(trace,n,out); end
end

function [trace, state] = run_packed64(candidate, x)
  state=[]; trace=empty_trace(numel(x));
  for word=1:(numel(x)/64)
    base=(word-1)*64;
    for lane=1:64
      [out,state]=dsm_scalar_transition(candidate,x(base+lane),state);
      trace=put(trace,base+lane,out);
    end
  end
end

function trace=empty_trace(n)
  trace=struct('y0',false(n,1),'y1',false(n,1),'y2',false(n,1), ...
    'level',zeros(n,1,'int64'),'combined',zeros(n,1,'int64'));
end
function trace=put(trace,n,out)
  trace.y0(n)=out.y0; trace.y1(n)=out.y1; trace.y2(n)=out.y2;
  trace.level(n)=out.level; trace.combined(n)=out.combined;
end

function [pa_words, state] = tid_thermo5_pipelined_step(i_poly, q_poly, state, w, step)
%TID_THERMO5_PIPELINED_STEP Four-branch, five-level Cartesian TID word.
% Four symmetric first-order L-channel TIDSM branches use offsets
% {+3,+1,-1,-3}*step.  Equal-amplitude combining produces the normalized
% thermometric levels {-1,-0.5,0,+0.5,+1}.  This is a multilevel extension
% of the timing-friendly first-order TID architecture, not a BP/EFDSM loop.

if nargin < 4, w=16; end
if nargin < 5, step=4096; end
assert(numel(i_poly)==numel(q_poly),'I/Q vectors must have equal length.');
if isempty(state), state.branch=cell(4,1); end
offsets=int64([3 1 -1 -3])*int64(step);
limit_hi=int64(2)^(w-1)-1; limit_lo=-int64(2)^(w-1);
pa_words=false(2*numel(i_poly),4);
for b=1:4
  ib=min(max(int64(i_poly(:))+offsets(b),limit_lo),limit_hi);
  qb=min(max(int64(q_poly(:))+offsets(b),limit_lo),limit_hi);
  [pa_words(:,b),state.branch{b}]=tid_pipelined_first_order_step(ib,qb,state.branch{b},w);
end
end

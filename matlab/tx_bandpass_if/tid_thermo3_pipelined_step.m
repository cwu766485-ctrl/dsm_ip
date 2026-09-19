function [pa_p_word, pa_m_word, state] = tid_thermo3_pipelined_step(i_poly, q_poly, state, w, threshold)
%TID_THERMO3_PIPELINED_STEP Two-branch, three-level Cartesian TID word step.
%
% Two L-channel first-order pipelined TIDSMs use symmetric input thresholds.
% Equal-weight 1-bit PA combining produces the thermometer levels {-1,0,+1}
% after normalization. Each branch retains the proven first-order TID state
% transformation; this function is the fixed-point source of truth for the
% RTL wrapper and does not model a higher-order BP-EFDSM recurrence.

if nargin < 4, w = 16; end
if nargin < 5, threshold = 8192; end
assert(numel(i_poly) == numel(q_poly), 'I/Q vectors must have equal length.');
if isempty(state)
    state.p = [];
    state.m = [];
end

limit_hi = int64(2)^(w-1)-1;
limit_lo = -int64(2)^(w-1);
delta = int64(threshold);
ip = min(max(int64(i_poly(:))+delta, limit_lo), limit_hi);
qp = min(max(int64(q_poly(:))+delta, limit_lo), limit_hi);
im = min(max(int64(i_poly(:))-delta, limit_lo), limit_hi);
qm = min(max(int64(q_poly(:))-delta, limit_lo), limit_hi);
[pa_p_word, state.p] = tid_pipelined_first_order_step(ip, qp, state.p, w);
[pa_m_word, state.m] = tid_pipelined_first_order_step(im, qm, state.m, w);
end

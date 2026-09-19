function [stage1_word, stage2_word, state] = tid_mash11_pipelined_step(i_poly, q_poly, state, w)
%TID_MASH11_PIPELINED_STEP One word of the two-stage Cartesian TID-MASH oracle.
% The two stages are first-order L-channel TIDSMs.  Stage 2 is driven by the
% delayed, saturated x-q1 residual.  stage1_word is delayed to align its
% physical PA branch with the stage-2 output word.

if nargin < 4, w = 16; end
l = numel(i_poly);
delay_words = l + 1; % L=32 -> scalar-equivalent 33-word delay.
if isempty(state)
    state.s1 = [];
    state.s2 = [];
    state.i_delay = zeros(l, delay_words, 'int64');
    state.q_delay = zeros(l, delay_words, 'int64');
    state.s1_delay = false(2*l, delay_words);
    state.delay_valid = false;
    state.output_word_index = 0;
end

[raw1, state.s1] = tid_pipelined_first_order_step(i_poly, q_poly, state.s1, w);
if state.delay_valid
    [q1_i, q1_q] = local_decode(raw1, l);
    ri = local_sat16(state.i_delay(:,end) - q1_i, w);
    rq = local_sat16(state.q_delay(:,end) - q1_q, w);
else
    ri = zeros(l,1,'int64');
    rq = zeros(l,1,'int64');
end
[stage2_word, state.s2] = tid_pipelined_first_order_step(ri, rq, state.s2, w);
stage1_word = state.s1_delay(:,end);
% The nested registered raw-word boundaries contribute one deterministic
% transition token when the L+1-word alignment delay first fills.  It is
% observable at the PA boundary and therefore belongs to the bit-true reset
% contract rather than being discarded by the scoreboard.
if state.output_word_index == delay_words
    stage1_word = false(2*l,1);
    stage2_word = local_reset_word(l);
end
state.i_delay = [int64(i_poly(:)), state.i_delay(:,1:end-1)];
state.q_delay = [int64(q_poly(:)), state.q_delay(:,1:end-1)];
state.s1_delay = [raw1, state.s1_delay(:,1:end-1)];
state.delay_valid = true;
state.output_word_index = state.output_word_index + 1;
end

function y=local_reset_word(l)
y=false(2*l,1);
for k=1:l
    if mod(k-1,2)==0, y(2*k)=true; else, y(2*k-1)=true; end
end
end

function [qi,qj] = local_decode(raw,l)
qi=zeros(l,1,'int64'); qj=zeros(l,1,'int64');
for k=1:l
    if mod(k-1,2)==0
        ib=raw(2*k-1); qb=~raw(2*k);
    else
        ib=~raw(2*k-1); qb=raw(2*k);
    end
    qi(k)=local_pm(ib); qj(k)=local_pm(qb);
end
end

function y=local_pm(b)
if b, y=int64(32767); else, y=int64(-32767); end
end

function y=local_sat16(x,w)
hi=int64(2)^(w-1)-1; lo=-int64(2)^(w-1);
y=min(max(int64(x),lo),hi);
end

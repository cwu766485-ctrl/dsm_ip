function [raw_word, state] = tid_pipelined_first_order_step(i_poly, q_poly, state, w)
%TID_PIPELINED_FIRST_ORDER_STEP One L-channel Cartesian pipelined-TIDSM tick.
%
% Implements the registered pre-summation, feedback, quantization and MGS
% word ordering in Firmansyah thesis equations 3.30, 3.32 and 3.34.  i_poly
% and q_poly are signed Cartesian samples.  The EFM itself uses their W-bit
% unsigned offset-binary representation (signed value + 2^(W-1)).  The output
% is a 2L-element logical vector with element 1 matching SystemVerilog
% gt_data[0].

if nargin < 4
    w = 16;
end
l = numel(i_poly);
assert(l >= 2 && mod(l, 2) == 0, 'L must be even and at least two.');
assert(numel(q_poly) == l, 'I and Q polyphase vectors must have equal length.');

if isempty(state)
    state.a_i = zeros(l, l, 'int64');
    state.a_q = zeros(l, l, 'int64');
    state.v_i = zeros(l, 1, 'int64');
    state.v_q = zeros(l, 1, 'int64');
end

assert(isequal(size(state.a_i), [l, l]) && isequal(size(state.a_q), [l, l]), ...
    'State pre-summation dimensions do not match L.');
assert(numel(state.v_i) == l && numel(state.v_q) == l, ...
    'State feedback dimensions do not match L.');

% Quantizer values are taken from the registered feedback stage before this
% tick, exactly as in the RTL.  A negative W+1-bit value has MSB=1.  The
% pipelined TIDSM output is the adjacent-MSB differential (XOR) specified by
% equation 3.34; using the raw MSBs here would model a different modulator.
msb_i = state.v_i < 0;
msb_q = state.v_q < 0;
y_i = msb_i;
y_q = msb_q;
for k = 2:l
    y_i(k) = xor(msb_i(k), msb_i(k-1));
    y_q(k) = xor(msb_q(k), msb_q(k-1));
end
raw_word = false(2*l, 1);
for k = 1:l
    if mod(k - 1, 2) == 0
        raw_word(2*k-1) = y_i(k);
        raw_word(2*k)   = ~y_q(k);
    else
        raw_word(2*k-1) = ~y_i(k);
        raw_word(2*k)   = y_q(k);
    end
end

next_a_i = zeros(l, l, 'int64');
next_a_q = zeros(l, l, 'int64');
next_a_i(:,1) = local_wrap_signed(local_signed_to_efm_input(i_poly(:), w), w + 1);
next_a_q(:,1) = local_wrap_signed(local_signed_to_efm_input(q_poly(:), w), w + 1);
for q = 2:l
    % All off-diagonal entries are delay registers.  Only the diagonal is
    % an adder, so evaluate the whole delayed column at once and overwrite
    % its one diagonal entry.  This is algebraically identical to Eqs. 3.30.
    next_a_i(:,q) = state.a_i(:,q-1);
    next_a_q(:,q) = state.a_q(:,q-1);
    next_a_i(q,q) = local_wrap_signed(state.a_i(q-1,q-1) + state.a_i(q,q-1), w + 1);
    next_a_q(q,q) = local_wrap_signed(state.a_q(q-1,q-1) + state.a_q(q,q-1), w + 1);
end

feedback_i = local_unsigned_lsb(state.v_i(l), w);
feedback_q = local_unsigned_lsb(state.v_q(l), w);
next_v_i = zeros(l, 1, 'int64');
next_v_q = zeros(l, 1, 'int64');
for p = 1:l
    next_v_i(p) = local_wrap_signed(state.a_i(p,l) + feedback_i, w + 1);
    next_v_q(p) = local_wrap_signed(state.a_q(p,l) + feedback_q, w + 1);
end

state.a_i = next_a_i;
state.a_q = next_a_q;
state.v_i = next_v_i;
state.v_q = next_v_q;
end

function value = local_wrap_signed(value, bits)
modulus = int64(2)^bits;
half = int64(2)^(bits - 1);
value = mod(value + half, modulus) - half;
end

function value = local_unsigned_lsb(value, bits)
modulus = int64(2)^bits;
value = mod(value, modulus);
end

function value = local_signed_to_efm_input(value, bits)
% The two's-complement MSB toggle is an exact modulo-2^W addition of 2^(W-1).
modulus = int64(2)^bits;
value = mod(int64(value) + int64(2)^(bits-1), modulus);
end

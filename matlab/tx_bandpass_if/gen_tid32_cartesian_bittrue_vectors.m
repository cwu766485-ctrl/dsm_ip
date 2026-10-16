function gen_tid32_cartesian_bittrue_vectors(output_dir, vectors, seed)
%GEN_TID32_CARTESIAN_BITTRUE_VECTORS Generate raw single-branch TID vectors.
if nargin < 1, output_dir = pwd; end
if nargin < 2, vectors = 128; end
if nargin < 3, seed = 20260915; end
assert(vectors >= 2, 'At least two vectors are required.');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

rng(seed);
lanes = 32;
w = 16;
i_words = int64(randi([-12000, 12000], lanes, vectors));
q_words = int64(randi([-12000, 12000], lanes, vectors));
starts = false(2 * lanes, vectors);
state = [];
for word = 1:vectors
    [starts(:, word), state] = tid_pipelined_first_order_step( ...
        i_words(:, word), q_words(:, word), state, w);
end
[tail, ~] = tid_pipelined_first_order_step(zeros(lanes, 1, 'int64'), ...
    zeros(lanes, 1, 'int64'), state, w);

local_write_samples(fullfile(output_dir, 'tid32_i.mem'), i_words(:));
local_write_samples(fullfile(output_dir, 'tid32_q.mem'), q_words(:));
local_write_words(fullfile(output_dir, 'tid32_gt.mem'), ...
    [starts(:, 2:end), tail]);
end

function local_write_samples(filename, samples)
fid = fopen(filename, 'w');
assert(fid >= 0, 'Cannot create sample-vector file.');
for k = 1:numel(samples)
    fprintf(fid, '%04X\n', uint16(mod(samples(k), int64(65536))));
end
fclose(fid);
end

function local_write_words(filename, words)
fid = fopen(filename, 'w');
assert(fid >= 0, 'Cannot create word-vector file.');
for word = 1:size(words, 2)
    value = uint64(0);
    for bit = 1:size(words, 1)
        if words(bit, word)
            value = bitor(value, bitshift(uint64(1), bit - 1));
        end
    end
    fprintf(fid, '%016X\n', value);
end
fclose(fid);
end

function gen_tid32_thermo5_bittrue_vectors(output_dir, vectors, seed, step)
%GEN_TID32_THERMO5_BITTRUE_VECTORS Write continuous four-PA TID vectors.
if nargin < 1, output_dir = pwd; end
if nargin < 2, vectors = 128; end
if nargin < 3, seed = 20260917; end
if nargin < 4, step = 6144; end
assert(vectors >= 2, 'At least two vectors are required.');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end
rng(seed); lanes = 32; w = 16;
i_words = int64(randi([-12000, 12000], lanes, vectors));
q_words = int64(randi([-12000, 12000], lanes, vectors));
starts = false(2*lanes, vectors, 4); state = [];
for word = 1:vectors
    [pa_words, state] = tid_thermo5_pipelined_step( ...
        i_words(:,word), q_words(:,word), state, w, step);
    % Do not rely on MATLAB's implicit 2-D-to-3-D assignment here: it can
    % reshape a 64x4 PA matrix while writing a 64x1x4 slice.  Explicit branch
    % indexing preserves every raw code plane and its word order.
    for branch = 1:4
        starts(:,word,branch) = pa_words(:,branch);
    end
end
[tail, ~] = tid_thermo5_pipelined_step(zeros(lanes,1,'int64'), ...
    zeros(lanes,1,'int64'), state, w, step);
local_write_samples(fullfile(output_dir, 'tid32_thermo5_i.mem'), i_words(:));
local_write_samples(fullfile(output_dir, 'tid32_thermo5_q.mem'), q_words(:));
for branch = 1:4
    local_write_words(fullfile(output_dir, sprintf('tid32_thermo5_pa%0d.mem', branch-1)), ...
        [starts(:,2:end,branch), tail(:,branch)]);
end
end

function local_write_samples(filename, samples)
fid = fopen(filename, 'w'); assert(fid >= 0, 'Cannot create sample-vector file.');
for k = 1:numel(samples), fprintf(fid, '%04X\n', uint16(mod(samples(k), int64(65536)))); end
fclose(fid);
end

function local_write_words(filename, words)
fid = fopen(filename, 'w'); assert(fid >= 0, 'Cannot create word-vector file.');
for word = 1:size(words,2)
    value = uint64(0);
    for bit = 1:size(words,1)
        if words(bit,word), value = bitor(value, bitshift(uint64(1), bit-1)); end
    end
    fprintf(fid, '%016X\n', value);
end
fclose(fid);
end

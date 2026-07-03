function T = blockwise_candidate_match(capture_file, candidate_file, block_len)
% blockwise_candidate_match
% Match a recovered 0/1 capture against a candidate reference block-by-block.

repo = fullfile(fileparts(mfilename('fullpath')), '..', '..');
if nargin < 1 || isempty(capture_file)
    capture_file = fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', ...
        'DSM000_recovered_bits_01.txt');
end
if nargin < 2 || isempty(candidate_file)
    candidate_file = resolve_reference_bits_file(repo, 'sim_rf_bits_01.txt');
end
if nargin < 3 || isempty(block_len)
    block_len = 2048;
end

cap = read_01_lines(capture_file);
ref = read_01_lines(candidate_file);
n_blocks = floor(numel(cap) / block_len);

rows = repmat(struct( ...
    'block_idx', 0, ...
    'cap_offset', 0, ...
    'match_rate', 0, ...
    'invert', false, ...
    'start_idx', 0), n_blocks, 1);

for b = 1:n_blocks
    off = (b-1) * block_len;
    seg = cap(off+1:off+block_len);
    [start_idx, match_rate, invert] = best_cyclic_match(seg, ref);
    rows(b) = struct( ...
        'block_idx', b-1, ...
        'cap_offset', off, ...
        'match_rate', match_rate, ...
        'invert', invert, ...
        'start_idx', start_idx);
end

T = struct2table(rows);
disp(T);

candidate_tag = erase(string(candidate_file), string(repo));
candidate_tag = regexprep(candidate_tag, '^[\\/]+', '');
candidate_tag = regexprep(candidate_tag, '[\\/:]+', '_');
candidate_tag = regexprep(candidate_tag, '[^A-Za-z0-9_.-]+', '_');
out_csv = fullfile(repo, sprintf('blockwise_candidate_match_%s.csv', candidate_tag));
writetable(T, out_csv);
fprintf('Saved blockwise matches to %s\n', out_csv);
end

function bits = read_01_lines(file)
fid = fopen(file, 'r');
assert(fid >= 0, 'Cannot open %s', file);
c = onCleanup(@() fclose(fid));

bits = false(0, 1);
while true
    t = fgetl(fid);
    if ~ischar(t)
        break;
    end
    s = strtrim(t);
    if isempty(s)
        continue;
    end
    parts = split(s);
    x = str2double(parts{1});
    if ~isnan(x)
        bits(end+1, 1) = x ~= 0; %#ok<AGROW>
    end
end
end

function [start_idx, match_rate, invert] = best_cyclic_match(cap_bits, ref_bits)
ref_pm = 2*double(ref_bits(:)) - 1;
cap_pm = 2*double(cap_bits(:)) - 1;

score_n = cyclic_corr(ref_pm, cap_pm);
score_i = cyclic_corr(ref_pm, -cap_pm);

[peak_n, idx_n] = max(score_n);
[peak_i, idx_i] = max(score_i);

if peak_i > peak_n
    invert = true;
    peak = peak_i;
    start_idx = idx_i;
else
    invert = false;
    peak = peak_n;
    start_idx = idx_n;
end

match_rate = (peak / numel(cap_pm) + 1) / 2;
end

function score = cyclic_corr(ref_pm, cap_pm)
n_ref = numel(ref_pm);
n_cap = numel(cap_pm);
ref_ext = [ref_pm; ref_pm(1:n_cap-1)];
score = conv(ref_ext, flipud(cap_pm), 'valid');
score = score(1:n_ref);
end

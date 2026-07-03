function T = compare_recovered_bits_candidates(capture_file)
% compare_recovered_bits_candidates
% Rank candidate simulated bitstreams against a recovered 0/1 capture.

repo = fullfile(fileparts(mfilename('fullpath')), '..', '..');
if nargin < 1 || isempty(capture_file)
    capture_file = fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', ...
        'DSM000_recovered_bits_01.txt');
end

cap_bits = read_01_lines(capture_file);
cands = candidate_specs(repo);

rows = repmat(struct( ...
    'label', "", ...
    'path', "", ...
    'match_rate', 0, ...
    'invert', false, ...
    'start_idx', 0, ...
    'longest_exact_run', 0, ...
    'best512', 0, ...
    'best2048', 0, ...
    'candidate_len', 0), 0, 1);

for k = 1:numel(cands)
    bits = cands(k).reader(cands(k).path, cands(k).arg);
    if isempty(bits)
        continue;
    end

    [start_idx, match_rate, invert] = best_cyclic_match(cap_bits, bits);
    [longest_exact_run, ~, ~] = longest_aligned_run(cap_bits, bits, start_idx, invert);
    best512 = best_window_match(cap_bits, bits, start_idx, invert, 512);
    best2048 = best_window_match(cap_bits, bits, start_idx, invert, 2048);

    rows(end+1, 1) = struct( ... %#ok<AGROW>
        'label', string(cands(k).label), ...
        'path', string(cands(k).path), ...
        'match_rate', match_rate, ...
        'invert', invert, ...
        'start_idx', start_idx, ...
        'longest_exact_run', longest_exact_run, ...
        'best512', best512, ...
        'best2048', best2048, ...
        'candidate_len', numel(bits));
end

T = struct2table(rows);
T = sortrows(T, {'best2048', 'best512', 'match_rate', 'longest_exact_run'}, ...
    {'descend', 'descend', 'descend', 'descend'});

disp(T(:, {'label', 'match_rate', 'best512', 'best2048', 'longest_exact_run', 'invert', 'start_idx'}));

out_csv = fullfile(repo, 'compare_recovered_bits_candidates.csv');
writetable(T, out_csv);
fprintf('Saved ranking to %s\n', out_csv);
end

function cands = candidate_specs(repo)
xsim = fullfile(repo, 'fpga', 'vivado', 'cartesian_dsm', 'cartesian_dsm.sim', ...
    'sim_1', 'behav', 'xsim');
data_dir = fullfile(repo, 'data', 'board_validation', 'cartesian_dsm');

cands = [ ...
    mk(resolve_reference_bits_file(repo, 'sim_rf_bits_01.txt', false),      'sim_rf_bits_01',       @read_01_lines, []), ...
    mk(resolve_reference_bits_file(repo, 'sim_rf_bits_01_dsm2.txt', false), 'sim_rf_bits_01_dsm2',  @read_01_lines, []), ...
    mk(resolve_reference_bits_file(repo, 'sim_rf_bits_01_ef1.txt', false),  'sim_rf_bits_01_ef1',   @read_01_lines, []), ...
    mk(fullfile(xsim, 'sim_rf_bits_01_ef2.txt'),        'sim_rf_bits_01_ef2',   @read_01_lines, []), ...
    mk(fullfile(xsim, 'sim_rf_bits_01_ef4.txt'),        'sim_rf_bits_01_ef4',   @read_01_lines, []), ...
    mk(fullfile(xsim, 'sim_bits_01.txt'),               'sim_bits_01:I',        @read_column_01, 1), ...
    mk(fullfile(xsim, 'sim_bits_01.txt'),               'sim_bits_01:Q',        @read_column_01, 2), ...
    mk(fullfile(xsim, 'sim_bits_01_dsm2.txt'),          'sim_bits_01_dsm2:I',   @read_column_01, 1), ...
    mk(fullfile(xsim, 'sim_bits_01_dsm2.txt'),          'sim_bits_01_dsm2:Q',   @read_column_01, 2), ...
    mk(fullfile(xsim, 'sim_bits_01_ef1.txt'),           'sim_bits_01_ef1:I',    @read_column_01, 1), ...
    mk(fullfile(xsim, 'sim_bits_01_ef1.txt'),           'sim_bits_01_ef1:Q',    @read_column_01, 2), ...
    mk(fullfile(xsim, 'sim_bits_01_ef2.txt'),           'sim_bits_01_ef2:I',    @read_column_01, 1), ...
    mk(fullfile(xsim, 'sim_bits_01_ef2.txt'),           'sim_bits_01_ef2:Q',    @read_column_01, 2), ...
    mk(fullfile(xsim, 'sim_bits_01_ef4.txt'),           'sim_bits_01_ef4:I',    @read_column_01, 1), ...
    mk(fullfile(xsim, 'sim_bits_01_ef4.txt'),           'sim_bits_01_ef4:Q',    @read_column_01, 2), ...
    mk(fullfile(data_dir, 'dsm_bitstream.coe'),         'dsm_bitstream.coe',    @read_coe_bits, []), ...
    mk(fullfile(data_dir, 'yI_1bit_01.csv'),            'yI_1bit_01.csv',       @read_01_lines, []), ...
    mk(fullfile(data_dir, 'yQ_1bit_01.csv'),            'yQ_1bit_01.csv',       @read_01_lines, []) ...
];

cands = cands(arrayfun(@(c) isfile(c.path), cands));
end

function s = mk(path, label, reader, arg)
s = struct('path', path, 'label', label, 'reader', reader, 'arg', arg);
end

function bits = read_01_lines(file, ~)
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

function bits = read_column_01(file, col)
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
    if numel(parts) < col
        continue;
    end
    x = str2double(parts{col});
    if ~isnan(x)
        bits(end+1, 1) = x ~= 0; %#ok<AGROW>
    end
end
end

function bits = read_coe_bits(file, ~)
txt = fileread(file);
txt = regexprep(txt, 'MEMORY_INITIALIZATION_RADIX\s*=\s*\d+\s*;', '');
txt = regexprep(txt, 'MEMORY_INITIALIZATION_VECTOR\s*=', '');
txt = strrep(txt, ';', ' ');
parts = regexp(txt, '[,\s]+', 'split');
parts = parts(~cellfun('isempty', parts));
bits = false(numel(parts), 1);
for k = 1:numel(parts)
    bits(k) = str2double(parts{k}) ~= 0;
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

function [best_run, best_cap_idx, best_ref_idx] = longest_aligned_run(cap_bits, ref_bits, start_idx, invert)
n_cap = numel(cap_bits);
n_ref = numel(ref_bits);

best_run = 0;
best_cap_idx = 1;
best_ref_idx = start_idx;
cur_run = 0;
cur_cap_idx = 1;

for k = 1:n_cap
    ref_idx = mod(start_idx + k - 2, n_ref) + 1;
    ref_bit = ref_bits(ref_idx);
    if invert
        ref_bit = ~ref_bit;
    end

    if cap_bits(k) == ref_bit
        if cur_run == 0
            cur_cap_idx = k;
        end
        cur_run = cur_run + 1;
        if cur_run > best_run
            best_run = cur_run;
            best_cap_idx = cur_cap_idx;
            best_ref_idx = mod(start_idx + cur_cap_idx - 2, n_ref) + 1;
        end
    else
        cur_run = 0;
    end
end
end

function best_rate = best_window_match(cap_bits, ref_bits, start_idx, invert, win)
n_cap = numel(cap_bits);
n_ref = numel(ref_bits);
if n_cap < win
    best_rate = NaN;
    return;
end

eq = false(n_cap, 1);
for k = 1:n_cap
    ref_idx = mod(start_idx + k - 2, n_ref) + 1;
    ref_bit = ref_bits(ref_idx);
    if invert
        ref_bit = ~ref_bit;
    end
    eq(k) = cap_bits(k) == ref_bit;
end

w = ones(win, 1);
hits = conv(double(eq), w, 'valid');
best_rate = max(hits) / win;
end

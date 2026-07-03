function out = recover_scope_rf_bits(capture_name)
% recover_scope_rf_bits
% Recover 0/1 bitstreams from oscilloscope-exported Wfm.csv captures and
% compare them against the legacy RTL rf_bit reference.

repo = fullfile(fileparts(mfilename('fullpath')), '..', '..');
ref_file = resolve_reference_bits_file(repo, 'sim_rf_bits_01.txt');
ref_bits = read_ref_bits(ref_file);

caps = [ ...
    struct( ...
        'name', 'DSM000', ...
        'wfm_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'DSM000.Wfm.csv'), ...
        'spb_nom', 100, ...
        'out_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'DSM000_recovered_bits_01.txt')), ...
    struct( ...
        'name', 'RefCurve_scope_aux', ...
        'wfm_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'RefCurve_scope_aux.Wfm.csv'), ...
        'spb_nom', 200, ...
        'out_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'RefCurve_scope_aux_recovered_bits_01.txt')) ...
];

if nargin >= 1 && ~isempty(capture_name)
    keep = false(size(caps));
    for k = 1:numel(caps)
        keep(k) = strcmpi(caps(k).name, capture_name);
    end
    caps = caps(keep);
    assert(~isempty(caps), 'Unknown capture_name: %s', capture_name);
end

results = cell(numel(caps), 1);
for k = 1:numel(caps)
    raw = read_numeric_lines(caps(k).wfm_file);
    res = analyze_capture(raw, ref_bits, caps(k));
    write_bits_01(caps(k).out_file, res.bits);

    fprintf('%s\n', repmat('=', 1, 78));
    fprintf('Capture: %s\n', caps(k).name);
    fprintf('  samples            : %d\n', numel(raw));
    fprintf('  recovered bits     : %d\n', numel(res.bits));
    fprintf('  samples/bit        : %.3f\n', res.spb);
    fprintf('  phase              : %.3f\n', res.phase);
    fprintf('  polarity inverted  : %d\n', res.invert);
    fprintf('  best rf start idx  : %d (1-based)\n', res.start_idx);
    fprintf('  match rate         : %.6f\n', res.match_rate);
    fprintf('  longest exact run  : %d bits\n', res.longest_exact_run);
    fprintf('  exact-run start    : capture[%d] -> rf_bits[%d]\n', ...
        res.longest_cap_idx, res.longest_rf_idx);
    fprintf('  exact 64-bit anchor: %d\n', res.anchor64_found);
    fprintf('  output file        : %s\n', caps(k).out_file);

    results{k} = res;
end

out = results;
end

function res = analyze_capture(raw, ref_bits, cap)
ref_pm = 2*double(ref_bits(:)) - 1;
ref_str = bits_to_char(ref_bits);

spb_grid = cap.spb_nom;
best.match_rate = -inf;
best.bits = [];

for spb = spb_grid
    phase_grid = 0:1:max(0, floor(spb)-1);
    for phase = phase_grid
        bits = recover_bits(raw, spb, phase, 5);
        if numel(bits) < 256
            continue;
        end

        [start_idx, match_rate, invert] = best_cyclic_match(bits, ref_pm);
        [longest_exact_run, longest_cap_idx, longest_rf_idx] = ...
            longest_aligned_run(bits, ref_bits_from_pm(ref_pm), start_idx, invert);
        anchor64_found = has_exact_anchor(bits, ref_str, invert, 64);

        cand = struct( ...
            'name', cap.name, ...
            'spb', spb, ...
            'phase', phase, ...
            'invert', invert, ...
            'start_idx', start_idx, ...
            'match_rate', match_rate, ...
            'longest_exact_run', longest_exact_run, ...
            'longest_cap_idx', longest_cap_idx, ...
            'longest_rf_idx', longest_rf_idx, ...
            'anchor64_found', anchor64_found, ...
            'bits', bits);

        if is_better(cand, best)
            best = cand;
        end
    end
end

res = best;
end

function tf = is_better(cand, best)
if cand.match_rate > best.match_rate + 1e-12
    tf = true;
elseif abs(cand.match_rate - best.match_rate) <= 1e-12
    tf = cand.anchor64_found > best.anchor64_found;
else
    tf = false;
end
end

function [start_idx, match_rate, invert] = best_cyclic_match(bits, ref_pm)
bits_pm = 2*double(bits(:)) - 1;
score_n = cyclic_corr(ref_pm, bits_pm);
score_i = cyclic_corr(ref_pm, -bits_pm);

[peak_n, idx_n] = max(score_n);
[peak_i, idx_i] = max(score_i);

if peak_i > peak_n
    invert = true;
    peak = peak_i;
    idx = idx_i;
else
    invert = false;
    peak = peak_n;
    idx = idx_n;
end

match_rate = (peak / numel(bits_pm) + 1) / 2;
start_idx = idx;
end

function [best_run, best_cap_idx, best_rf_idx] = longest_aligned_run(bits, ref_bits, start_idx, invert)
n_bits = numel(bits);
n_ref = numel(ref_bits);
cur_run = 0;
cur_cap_idx = 1;
best_run = 0;
best_cap_idx = 1;
best_rf_idx = start_idx;

for k = 1:n_bits
    ref_idx = mod(start_idx + k - 2, n_ref) + 1;
    ref_bit = ref_bits(ref_idx);
    if invert
        ref_bit = ~ref_bit;
    end

    if bits(k) == ref_bit
        if cur_run == 0
            cur_cap_idx = k;
        end
        cur_run = cur_run + 1;
        if cur_run > best_run
            best_run = cur_run;
            best_cap_idx = cur_cap_idx;
            best_rf_idx = mod(start_idx + cur_cap_idx - 2, n_ref) + 1;
        end
    else
        cur_run = 0;
    end
end
end

function ref_bits = ref_bits_from_pm(ref_pm)
ref_bits = ref_pm > 0;
end

function score = cyclic_corr(ref_pm, bits_pm)
n_ref = numel(ref_pm);
n_bits = numel(bits_pm);
ref_ext = [ref_pm; ref_pm(1:n_bits-1)];
score = conv(ref_ext, flipud(bits_pm), 'valid');
score = score(1:n_ref);
end

function tf = has_exact_anchor(bits, ref_str, invert, win)
if numel(bits) < win
    tf = false;
    return;
end

bits_char = bits_to_char(bits);
sig = bits_char(1:win);
if invert
    sig = invert_char(sig);
end
tf = ~isempty(strfind([ref_str ref_str(1:win-1)], sig)); %#ok<STREMP>
end

function bits = recover_bits(raw, spb, phase, half_win)
centers = (phase + 1):spb:numel(raw);
n = numel(centers);
bits = false(n, 1);
for k = 1:n
    c = round(centers(k));
    i0 = max(1, c-half_win);
    i1 = min(numel(raw), c+half_win);
    bits(k) = mean(raw(i0:i1)) >= 0;
end
end

function raw = read_numeric_lines(file)
fid = fopen(file, 'r');
assert(fid >= 0, 'Cannot open %s', file);
c = onCleanup(@() fclose(fid));

raw = zeros(0, 1);
while true
    t = fgetl(fid);
    if ~ischar(t)
        break;
    end
    x = str2double(strtrim(t));
    if ~isnan(x)
        raw(end+1, 1) = x; %#ok<AGROW>
    end
end
end

function bits = read_ref_bits(file)
fid = fopen(file, 'r');
assert(fid >= 0, 'Cannot open %s', file);
c = onCleanup(@() fclose(fid));

bits = zeros(0, 1, 'logical');
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
    bits(end+1, 1) = str2double(parts{1}) ~= 0; %#ok<AGROW>
end
end

function write_bits_01(file, bits)
fid = fopen(file, 'w');
assert(fid >= 0, 'Cannot open %s for write', file);
c = onCleanup(@() fclose(fid));
fprintf(fid, '%d\n', bits);
end

function s = bits_to_char(bits)
s = char(bits(:).' + '0');
end

function s = invert_char(s)
s(s == '0') = 'x';
s(s == '1') = '0';
s(s == 'x') = '1';
end

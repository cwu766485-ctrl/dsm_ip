function out = recover_scope_rf_bits_edges(capture_name)
% recover_scope_rf_bits_edges
% Recover 0/1 bitstreams from scope waveforms using edge timing and
% run-length reconstruction instead of fixed-phase center sampling.

repo = fullfile(fileparts(mfilename('fullpath')), '..', '..');
ref_file = fullfile(repo, 'fpga', 'vivado', 'cartesian_dsm', ...
    'cartesian_dsm.sim', 'sim_1', 'behav', 'xsim', 'sim_rf_bits_01.txt');
ref_bits = read_ref_bits(ref_file);

caps = [ ...
    struct( ...
        'name', 'DSM000', ...
        'wfm_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'DSM000.Wfm.csv'), ...
        'spb_nom', 100, ...
        'smooth_win', 5, ...
        'hyst_frac', 0.18, ...
        'out_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'DSM000_edge_recovered_bits_01.txt')), ...
    struct( ...
        'name', 'RefCurve_scope_aux', ...
        'wfm_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'RefCurve_scope_aux.Wfm.csv'), ...
        'spb_nom', 200, ...
        'smooth_win', 9, ...
        'hyst_frac', 0.18, ...
        'out_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'RefCurve_scope_aux_edge_recovered_bits_01.txt')) ...
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
    fprintf('Edge-recovery capture: %s\n', caps(k).name);
    fprintf('  samples            : %d\n', numel(raw));
    fprintf('  edge count         : %d\n', numel(res.edge_times));
    fprintf('  recovered bits     : %d\n', numel(res.bits));
    fprintf('  est samples/bit    : %.6f\n', res.spb);
    fprintf('  period resid rms   : %.6f samples\n', res.period_rms);
    fprintf('  smooth win         : %d\n', caps(k).smooth_win);
    fprintf('  hysteresis frac    : %.3f\n', caps(k).hyst_frac);
    fprintf('  invert             : %d\n', res.invert);
    fprintf('  best rf start idx  : %d (1-based)\n', res.start_idx);
    fprintf('  match rate         : %.6f\n', res.match_rate);
    fprintf('  longest exact run  : %d bits\n', res.longest_exact_run);
    fprintf('  exact-run start    : capture[%d] -> rf_bits[%d]\n', ...
        res.longest_cap_idx, res.longest_rf_idx);
    fprintf('  output file        : %s\n', caps(k).out_file);

    results{k} = res;
end

out = results;
end

function res = analyze_capture(raw, ref_bits, cap)
smooth = movmean(raw(:), cap.smooth_win);
[lev_lo, lev_hi] = estimate_levels(smooth);
mid = 0.5 * (lev_lo + lev_hi);
h = cap.hyst_frac * 0.5 * (lev_hi - lev_lo);
th_lo = mid - h;
th_hi = mid + h;

[state, edge_times] = schmitt_edges(smooth, raw, mid, th_lo, th_hi);
edge_times = prune_close_edges(edge_times, 0.35 * cap.spb_nom);
assert(numel(edge_times) >= 8, 'Too few edges after cleanup for %s', cap.name);

[spb, period_rms] = estimate_bit_period(edge_times, cap.spb_nom);
[bits, state_after] = runs_to_bits(state, edge_times, spb); %#ok<ASGLU>
assert(numel(bits) >= 256, 'Recovered too few bits for %s', cap.name);

[start_idx, match_rate, invert] = best_cyclic_match(bits, ref_bits);
ref_eff = ref_bits;
if invert
    ref_eff = ~ref_eff;
end
 [longest_exact_run, longest_cap_idx, longest_rf_idx] = ...
    longest_aligned_run(bits, ref_eff, start_idx);

res = struct();
res.level_lo = lev_lo;
res.level_hi = lev_hi;
res.mid = mid;
res.th_lo = th_lo;
res.th_hi = th_hi;
res.spb = spb;
res.period_rms = period_rms;
res.edge_times = edge_times;
res.bits = bits;
res.start_idx = start_idx;
res.match_rate = match_rate;
res.invert = invert;
res.longest_exact_run = longest_exact_run;
res.longest_cap_idx = longest_cap_idx;
res.longest_rf_idx = longest_rf_idx;
end

function [lo, hi] = estimate_levels(raw)
raw = sort(raw(:));
n = numel(raw);
m = max(16, round(0.08 * n));
lo = median(raw(1:m));
hi = median(raw(end-m+1:end));
end

function [state, edge_times] = schmitt_edges(smooth, raw, mid, th_lo, th_hi)
n = numel(smooth);
state = false(n, 1);
st = smooth(1) >= mid;
state(1) = st;
edge_times = zeros(0, 1);

for i = 2:n
    if ~st
        if smooth(i) >= th_hi
            st = true;
            edge_times(end+1, 1) = interpolate_cross(raw, i, mid); %#ok<AGROW>
        end
    else
        if smooth(i) <= th_lo
            st = false;
            edge_times(end+1, 1) = interpolate_cross(raw, i, mid); %#ok<AGROW>
        end
    end
    state(i) = st;
end
end

function t = interpolate_cross(raw, i, level)
i0 = max(1, i-1);
i1 = i;
y0 = raw(i0);
y1 = raw(i1);
if y1 == y0
    frac = 0;
else
    frac = (level - y0) / (y1 - y0);
end
frac = min(max(frac, 0), 1);
t = (i0 - 1) + frac + 1;
end

function edge_times = prune_close_edges(edge_times, min_gap)
if isempty(edge_times)
    return;
end
keep = true(size(edge_times));
i = 2;
while i <= numel(edge_times)
    if (edge_times(i) - edge_times(i-1)) < min_gap
        keep(i) = false;
    end
    i = i + 1;
end
edge_times = edge_times(keep);
end

function [spb, rms_err] = estimate_bit_period(edge_times, spb_nom)
d = diff(edge_times);
grid1 = (spb_nom - 1.5):0.02:(spb_nom + 1.5);
[best1, best_cost1] = search_period_grid(d, grid1);
grid2 = (best1 - 0.05):0.001:(best1 + 0.05);
[spb, best_cost2] = search_period_grid(d, grid2); %#ok<ASGLU>
k = max(1, round(d / spb));
err = d - k * spb;
rms_err = sqrt(mean(err.^2));
end

function [best_spb, best_cost] = search_period_grid(d, grid)
best_cost = inf;
best_spb = grid(1);
for spb = grid
    k = max(1, round(d / spb));
    err = d - k * spb;
    cost = mean(abs(err)) + 2.0 * mean(abs(err) > 0.22 * spb) * spb;
    if cost < best_cost
        best_cost = cost;
        best_spb = spb;
    end
end
end

function [bits, states_after] = runs_to_bits(state, edge_times, spb)
n_edges = numel(edge_times);
states_after = false(n_edges-1, 1);
bits = false(0, 1);

for i = 1:(n_edges-1)
    idx = min(numel(state), max(1, floor(edge_times(i)) + 1));
    st = state(idx);
    dt = edge_times(i+1) - edge_times(i);
    run_len = max(1, round(dt / spb));
    states_after(i) = st;
    bits = [bits; repmat(st, run_len, 1)]; %#ok<AGROW>
end
end

function [start_idx, match_rate, invert] = best_cyclic_match(bits, ref_bits)
ref_pm = 2*double(ref_bits(:)) - 1;
bits_pm = 2*double(bits(:)) - 1;

score_n = cyclic_corr(ref_pm, bits_pm);
score_i = cyclic_corr(ref_pm, -bits_pm);

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

match_rate = (peak / numel(bits_pm) + 1) / 2;
end

function score = cyclic_corr(ref_pm, bits_pm)
n_ref = numel(ref_pm);
n_bits = numel(bits_pm);
ref_ext = [ref_pm; ref_pm(1:n_bits-1)];
score = conv(ref_ext, flipud(bits_pm), 'valid');
score = score(1:n_ref);
end

function [best_run, best_cap_idx, best_rf_idx] = longest_aligned_run(bits, ref_bits, start_idx)
n_bits = numel(bits);
n_ref = numel(ref_bits);
cur_run = 0;
cur_cap_idx = 1;
best_run = 0;
best_cap_idx = 1;
best_rf_idx = start_idx;

for k = 1:n_bits
    ref_idx = mod(start_idx + k - 2, n_ref) + 1;
    if bits(k) == ref_bits(ref_idx)
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

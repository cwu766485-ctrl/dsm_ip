function compare_scope_spectrum_to_rtl_bandpass()
% compare_scope_spectrum_to_rtl_bandpass
% Offline bandpass-filtered spectrum comparison for display/performance
% validation. This is intended to mimic the paper-style "capture with DSO,
% apply offline filtering, then compare spectrum" workflow. It is not a
% bit-true proof.

repo = fullfile(fileparts(mfilename('fullpath')), '..', '..');
ref_file = resolve_reference_bits_file(repo, 'sim_rf_bits_01.txt');
ref_bits = read_01_lines(ref_file);

caps = [ ...
    struct( ...
        'name', 'DSM000', ...
        'wfm_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'DSM000.Wfm.csv'), ...
        'bits_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'DSM000_recovered_bits_01.txt'), ...
        'dt', 100e-12, ...
        'spb', 100, ...
        'ref_start', 50871, ...
        'invert', false), ...
    struct( ...
        'name', 'RefCurve', ...
        'wfm_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'RefCurve_scope_aux.Wfm.csv'), ...
        'bits_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'RefCurve_scope_aux_recovered_bits_01.txt'), ...
        'dt', 50e-12, ...
        'spb', 200, ...
        'ref_start', 18932, ...
        'invert', true) ...
];

% Display-oriented RF band around the Fs/4 carrier (~25 MHz).
bp = struct( ...
    'pass_lo_mhz', 5, ...
    'pass_hi_mhz', 45, ...
    'trans_mhz', 10, ...
    'plot_max_mhz', 100, ...
    'smooth_win_mhz', 1.5);

rows = {};
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 760]);
tlo = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

for k = 1:numel(caps)
    raw = read_numeric_lines(caps(k).wfm_file);
    bits = read_01_lines(caps(k).bits_file);
    n_bits = numel(bits);

    y_rec = bits_to_analog(bits, raw, caps(k).spb);
    ref_seg = cyclic_take(ref_bits, caps(k).ref_start, n_bits);
    if caps(k).invert
        ref_seg = ~ref_seg;
    end
    y_ref = bits_to_analog(ref_seg, raw, caps(k).spb);

    raw_bp = apply_cosine_bandpass(raw, caps(k).dt, bp.pass_lo_mhz, bp.pass_hi_mhz, bp.trans_mhz);
    rec_bp = apply_cosine_bandpass(y_rec, caps(k).dt, bp.pass_lo_mhz, bp.pass_hi_mhz, bp.trans_mhz);
    ref_bp = apply_cosine_bandpass(y_ref, caps(k).dt, bp.pass_lo_mhz, bp.pass_hi_mhz, bp.trans_mhz);

    [f_mhz, p_raw] = simple_psd(raw_bp, caps(k).dt);
    [~, p_ref] = simple_psd(ref_bp, caps(k).dt);
    [~, p_rec] = simple_psd(rec_bp, caps(k).dt);

    keep = f_mhz <= min(bp.plot_max_mhz, f_mhz(end));
    f_plot = f_mhz(keep);
    raw_db = to_db(p_raw(keep));
    rec_db = to_db(p_rec(keep));
    ref_db = to_db(p_ref(keep));

    raw_db = raw_db - max(raw_db);
    rec_db = rec_db - max(rec_db);
    ref_db = ref_db - max(ref_db);

    raw_db_s = smooth_spectrum_db(raw_db, f_plot, bp.smooth_win_mhz);
    rec_db_s = smooth_spectrum_db(rec_db, f_plot, bp.smooth_win_mhz);
    ref_db_s = smooth_spectrum_db(ref_db, f_plot, bp.smooth_win_mhz);

    corr_ref = simple_corr(raw_db_s, ref_db_s);
    corr_rec = simple_corr(raw_db_s, rec_db_s);
    rmse_ref = sqrt(mean((raw_db_s - ref_db_s).^2));
    rmse_rec = sqrt(mean((raw_db_s - rec_db_s).^2));
    peak_raw = dominant_peak(f_plot, raw_db_s);
    peak_ref = dominant_peak(f_plot, ref_db_s);
    peak_rec = dominant_peak(f_plot, rec_db_s);

    rows(end+1, :) = {caps(k).name, 'scope_vs_recovered', corr_rec, rmse_rec, peak_raw, peak_rec, ...
        bp.pass_lo_mhz, bp.pass_hi_mhz, bp.trans_mhz}; %#ok<AGROW>
    rows(end+1, :) = {caps(k).name, 'scope_vs_rtl', corr_ref, rmse_ref, peak_raw, peak_ref, ...
        bp.pass_lo_mhz, bp.pass_hi_mhz, bp.trans_mhz}; %#ok<AGROW>

    nexttile(tlo);
    plot(f_plot, raw_db, 'LineWidth', 0.25, 'Color', [0.72 0.82 0.95]);
    hold on;
    plot(f_plot, ref_db, '--', 'LineWidth', 0.25, 'Color', [0.78 0.93 0.78]);
    plot(f_plot, raw_db_s, 'LineWidth', 2.0, 'Color', [0.05 0.35 0.80]);
    plot(f_plot, ref_db_s, '--', 'LineWidth', 2.0, 'Color', [0.10 0.60 0.20]);
    grid on;
    xlabel('Frequency (MHz)');
    ylabel('PSD (dB, normalized)');
    title(sprintf('%s: bandpass-filtered scope vs RTL', caps(k).name), 'Interpreter', 'none');
    legend({'scope filtered raw', 'RTL filtered raw', 'scope filtered env', 'RTL filtered env'}, ...
        'Location', 'best');
    xlim([0 bp.plot_max_mhz]);
end

sgtitle(tlo, sprintf('Bandpass-Filtered Scope vs RTL Spectrum for Display (%g-%g MHz pass, %g MHz transition)', ...
    bp.pass_lo_mhz, bp.pass_hi_mhz, bp.trans_mhz));
exportgraphics(fig, fullfile(repo, 'scope_vs_rtl_spectrum_bandpass.png'), 'Resolution', 160);
close(fig);

T = cell2table(rows, 'VariableNames', ...
    {'capture', 'comparison', 'log_psd_corr', 'log_psd_rmse_db', 'scope_peak_mhz', ...
     'model_peak_mhz', 'pass_lo_mhz', 'pass_hi_mhz', 'transition_mhz'});
writetable(T, fullfile(repo, 'scope_vs_rtl_spectrum_bandpass_metrics.csv'));
disp(T);
end

function y = apply_cosine_bandpass(x, dt, pass_lo_mhz, pass_hi_mhz, trans_mhz)
x = x(:);
n = numel(x);
fs = 1 / dt;
X = fftshift(fft(x));
f_hz = ((0:n-1).' - floor(n/2)) * (fs / n);
f_mhz = abs(f_hz) / 1e6;
g = raised_cosine_band(f_mhz, pass_lo_mhz, pass_hi_mhz, trans_mhz);
Y = X .* g;
y = real(ifft(ifftshift(Y)));
end

function g = raised_cosine_band(f_mhz, pass_lo_mhz, pass_hi_mhz, trans_mhz)
stop_lo = max(0, pass_lo_mhz - trans_mhz);
stop_hi = pass_hi_mhz + trans_mhz;
g = zeros(size(f_mhz));

mid = (f_mhz >= pass_lo_mhz) & (f_mhz <= pass_hi_mhz);
g(mid) = 1;

lo = (f_mhz >= stop_lo) & (f_mhz < pass_lo_mhz);
if any(lo)
    t = (f_mhz(lo) - stop_lo) / max(pass_lo_mhz - stop_lo, eps);
    g(lo) = 0.5 - 0.5 * cos(pi * t);
end

hi = (f_mhz > pass_hi_mhz) & (f_mhz <= stop_hi);
if any(hi)
    t = (f_mhz(hi) - pass_hi_mhz) / max(stop_hi - pass_hi_mhz, eps);
    g(hi) = 0.5 + 0.5 * cos(pi * t);
end
end

function y = bits_to_analog(bits, raw, spb)
raw_hi = mean(raw(raw >= quantile_local(raw, 0.9)));
raw_lo = mean(raw(raw <= quantile_local(raw, 0.1)));
pm = 2 * double(bits(:)) - 1;
y = repelem(pm, spb, 1);
y = (raw_hi - raw_lo) / 2 * y + (raw_hi + raw_lo) / 2;
target_len = floor(numel(raw) / spb) * spb;
y = y(1:min(target_len, numel(y)));
if numel(y) < target_len
    y(end+1:target_len, 1) = y(end);
end
end

function [f_mhz, p] = simple_psd(x, dt)
x = x(:);
x = x - mean(x);
n = numel(x);
w = hann_local(n);
xw = x .* w;
X = fft(xw);
P2 = abs(X).^2 / max(1, sum(w.^2));
n1 = floor(n / 2) + 1;
p = P2(1:n1);
f = (0:n1-1).' / (n * dt);
f_mhz = f / 1e6;
end

function peak_mhz = dominant_peak(f_mhz, p_db)
mask = f_mhz > 1;
if ~any(mask)
    peak_mhz = NaN;
    return;
end
[~, idx] = max(p_db(mask));
ff = f_mhz(mask);
peak_mhz = ff(idx);
end

function y = to_db(x)
y = 10 * log10(max(x, 1e-30));
end

function q = quantile_local(x, alpha)
x = sort(x(:));
n = numel(x);
idx = max(1, min(n, round(alpha * (n - 1) + 1)));
q = x(idx);
end

function w = hann_local(n)
if n == 1
    w = 1;
else
    k = (0:n-1).';
    w = 0.5 - 0.5 * cos(2 * pi * k / (n - 1));
end
end

function bits = cyclic_take(bits_ref, start_idx, len)
idx = mod(start_idx - 1 + (0:len-1), numel(bits_ref)) + 1;
bits = bits_ref(idx(:));
end

function r = simple_corr(x, y)
x = x(:) - mean(x);
y = y(:) - mean(y);
den = sqrt(sum(x.^2) * sum(y.^2));
if den == 0
    r = NaN;
else
    r = sum(x .* y) / den;
end
end

function y = smooth_spectrum_db(x, f_mhz, win_mhz)
x = x(:);
f_mhz = f_mhz(:);
if numel(x) <= 2
    y = x;
    return;
end
df = median(diff(f_mhz));
half_span = max(1, round(0.5 * win_mhz / max(df, eps)));
kernel = ones(2 * half_span + 1, 1);
kernel = kernel / sum(kernel);
y = conv(x, kernel, 'same');
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

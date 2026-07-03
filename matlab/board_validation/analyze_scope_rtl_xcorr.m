function analyze_scope_rtl_xcorr()
% analyze_scope_rtl_xcorr
% Cross-correlate measured scope captures against RTL-derived ideal RF
% waveforms to explain the current mismatch in a report-friendly way.
%
% The analysis is intentionally focused on:
%   1) global cross-correlation peak and lag
%   2) frame-wise residual lag stability after removing the global lag
%   3) whether the frame lag behaves like monotonic drift or local jitter

repo = fullfile(fileparts(mfilename('fullpath')), '..', '..');
ref_file = fullfile(repo, 'fpga', 'vivado', 'cartesian_dsm', ...
    'cartesian_dsm.sim', 'sim_1', 'behav', 'xsim', 'sim_rf_bits_01.txt');
ref_bits = read_01_lines(ref_file);

caps = [ ...
    struct( ...
        'name', 'DSM000', ...
        'wfm_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'DSM000.Wfm.csv'), ...
        'spb', 100, ...
        'dt', 100e-12, ...
        'ref_start', 50871, ...
        'invert', false), ...
    struct( ...
        'name', 'RefCurve', ...
        'wfm_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'RefCurve_scope_aux.Wfm.csv'), ...
        'spb', 200, ...
        'dt', 50e-12, ...
        'ref_start', 18932, ...
        'invert', true) ...
];

cfg = struct();
cfg.bp_lo_mhz = 5;
cfg.bp_hi_mhz = 45;
cfg.bp_trans_mhz = 10;
cfg.full_max_lag_ui = 2.5;
cfg.frame_bits = 128;
cfg.frame_max_lag_ui = 0.40;
cfg.min_frame_corr = 0.45;

summary_rows = cell(0, 15);
md_lines = {
    '# Scope-vs-RTL Cross-Correlation Report'
    ''
    'This report summarizes whole-record and frame-wise cross-correlation results'
    'between the scope capture and the RTL-derived ideal RF waveform.'
    ''
};

for k = 1:numel(caps)
    raw = read_numeric_lines(caps(k).wfm_file);
    n_bits = floor(numel(raw) / caps(k).spb);
    raw = raw(1:n_bits * caps(k).spb);

    ref_seg = cyclic_take(ref_bits, caps(k).ref_start, n_bits);
    if caps(k).invert
        ref_seg = ~ref_seg;
    end
    ideal = bits_to_analog(ref_seg, raw, caps(k).spb);

    raw_bp = apply_cosine_bandpass(raw, caps(k).dt, ...
        cfg.bp_lo_mhz, cfg.bp_hi_mhz, cfg.bp_trans_mhz);
    ideal_bp = apply_cosine_bandpass(ideal, caps(k).dt, ...
        cfg.bp_lo_mhz, cfg.bp_hi_mhz, cfg.bp_trans_mhz);

    full_max_lag = round(cfg.full_max_lag_ui * caps(k).spb);
    [full_raw_peak, full_raw_lag, full_raw_curve, full_raw_lags] = ...
        peak_xcorr(raw, ideal, full_max_lag);
    [full_bp_peak, full_bp_lag, full_bp_curve, full_bp_lags] = ...
        peak_xcorr(raw_bp, ideal_bp, full_max_lag);

    ideal_bp_g = shift_signal_same_length(ideal_bp, full_bp_lag);
    [Tf, frame_stats] = framewise_xcorr(raw_bp, ideal_bp_g, caps(k).spb, ...
        cfg.frame_bits, round(cfg.frame_max_lag_ui * caps(k).spb), ...
        cfg.min_frame_corr);

    out_csv = fullfile(repo, sprintf('scope_rtl_xcorr_frames_%s.csv', lower(caps(k).name)));
    writetable(Tf, out_csv);

    out_png = fullfile(repo, sprintf('scope_rtl_xcorr_%s.png', lower(caps(k).name)));
    make_plot(caps(k), full_raw_curve, full_raw_lags, full_bp_curve, full_bp_lags, ...
        Tf, frame_stats, out_png);

    summary_rows(end+1, :) = { ...
        caps(k).name, ...
        n_bits, ...
        full_raw_peak, ...
        full_raw_lag, ...
        full_raw_lag / caps(k).spb, ...
        full_bp_peak, ...
        full_bp_lag, ...
        full_bp_lag / caps(k).spb, ...
        frame_stats.n_valid, ...
        frame_stats.corr_median, ...
        frame_stats.corr_min, ...
        frame_stats.lag_mean, ...
        frame_stats.lag_std, ...
        frame_stats.drift_ppm, ...
        frame_stats.residual_span ...
    };

    md_lines{end+1} = sprintf('## %s', caps(k).name); %#ok<AGROW>
    md_lines{end+1} = ''; %#ok<AGROW>
    md_lines{end+1} = sprintf('- Whole-record raw xcorr peak: `%.4f` at lag `%d` samples (`%.3f UI`).', ...
        full_raw_peak, full_raw_lag, full_raw_lag / caps(k).spb); %#ok<AGROW>
    md_lines{end+1} = sprintf('- Whole-record bandpass xcorr peak: `%.4f` at lag `%d` samples (`%.3f UI`).', ...
        full_bp_peak, full_bp_lag, full_bp_lag / caps(k).spb); %#ok<AGROW>
    md_lines{end+1} = sprintf('- Frame count used: `%d` frames of `%d` bits.', ...
        frame_stats.n_valid, cfg.frame_bits); %#ok<AGROW>
    md_lines{end+1} = sprintf('- Frame peak-correlation median/min: `%.4f` / `%.4f`.', ...
        frame_stats.corr_median, frame_stats.corr_min); %#ok<AGROW>
    md_lines{end+1} = sprintf('- Residual lag mean/std/span after global alignment: `%.2f` / `%.2f` / `%d` samples.', ...
        frame_stats.lag_mean, frame_stats.lag_std, frame_stats.residual_span); %#ok<AGROW>
    md_lines{end+1} = sprintf('- Fitted lag slope: `%.3f` samples per 1000 bits (`%.1f ppm`).', ...
        frame_stats.drift_samples_per_kbit, frame_stats.drift_ppm); %#ok<AGROW>
    md_lines{end+1} = sprintf('- Plot: `%s`', out_png); %#ok<AGROW>
    md_lines{end+1} = sprintf('- Frame table: `%s`', out_csv); %#ok<AGROW>
    md_lines{end+1} = ''; %#ok<AGROW>

    fprintf('%s\n', repmat('=', 1, 78));
    fprintf('Capture: %s\n', caps(k).name);
    fprintf('  whole raw xcorr peak : %.6f at lag %d samples (%.3f UI)\n', ...
        full_raw_peak, full_raw_lag, full_raw_lag / caps(k).spb);
    fprintf('  whole bp  xcorr peak : %.6f at lag %d samples (%.3f UI)\n', ...
        full_bp_peak, full_bp_lag, full_bp_lag / caps(k).spb);
    fprintf('  frame count used     : %d\n', frame_stats.n_valid);
    fprintf('  frame corr median    : %.6f\n', frame_stats.corr_median);
    fprintf('  frame lag mean/std   : %.3f / %.3f samples\n', ...
        frame_stats.lag_mean, frame_stats.lag_std);
    fprintf('  drift slope          : %.6f samples/1000 bits (%.3f ppm)\n', ...
        frame_stats.drift_samples_per_kbit, frame_stats.drift_ppm);
    fprintf('  residual lag span    : %d samples\n', frame_stats.residual_span);
    fprintf('  plot                 : %s\n', out_png);
    fprintf('  frame csv            : %s\n', out_csv);
end

Ts = cell2table(summary_rows, 'VariableNames', ...
    {'capture', 'n_bits', 'full_raw_peak_corr', 'full_raw_lag_samp', ...
     'full_raw_lag_ui', 'full_bp_peak_corr', 'full_bp_lag_samp', ...
     'full_bp_lag_ui', 'n_valid_frames', 'frame_corr_median', ...
     'frame_corr_min', 'frame_lag_mean_samp', 'frame_lag_std_samp', ...
     'drift_ppm', 'residual_lag_span_samp'});
writetable(Ts, fullfile(repo, 'scope_rtl_xcorr_summary.csv'));

write_text_lines(fullfile(repo, 'docs', 'scope_rtl_xcorr_report_2026-04-02.md'), md_lines);
disp(Ts);
end

function [peak_corr, peak_lag, c, lags] = peak_xcorr(y, x, maxLag)
y = normalize_real(y);
x = normalize_real(x);
[c, lags] = xcorr(y, x, maxLag, 'coeff');
[peak_corr, im] = max(c);
peak_lag = lags(im);
end

function [T, S] = framewise_xcorr(y, x, spb, frame_bits, maxLag, minCorr)
y = y(:);
x = x(:);
frame_len = frame_bits * spb;
n_frames = floor(min(numel(y), numel(x)) / frame_len);
rows = repmat(struct( ...
    'frame_idx', 0, ...
    'bit_start', 0, ...
    'bit_center', 0, ...
    'peak_corr', 0, ...
    'best_lag_samp', 0, ...
    'best_lag_ui', 0, ...
    'accepted', false), n_frames, 1);

for i = 1:n_frames
    s0 = (i-1) * frame_len + 1;
    s1 = s0 + frame_len - 1;
    y_seg = y(s0:s1);
    x_seg = x(s0:s1);
    [pk, lag] = peak_xcorr(y_seg, x_seg, maxLag);
    rows(i).frame_idx = i - 1;
    rows(i).bit_start = (i-1) * frame_bits;
    rows(i).bit_center = rows(i).bit_start + frame_bits / 2;
    rows(i).peak_corr = pk;
    rows(i).best_lag_samp = lag;
    rows(i).best_lag_ui = lag / spb;
    rows(i).accepted = pk >= minCorr;
end

T = struct2table(rows);
Tk = T(T.accepted, :);
if isempty(Tk)
    S = empty_stats();
    return;
end

bit_center = double(Tk.bit_center);
lag_samp = double(Tk.best_lag_samp);
peak_corr = double(Tk.peak_corr);
p = polyfit(bit_center, lag_samp, 1);
drift_samp_per_bit = p(1);

S = struct();
S.n_valid = height(Tk);
S.corr_median = median(peak_corr);
S.corr_min = min(peak_corr);
S.lag_mean = mean(lag_samp);
S.lag_std = std(lag_samp);
S.lag_min = min(lag_samp);
S.lag_max = max(lag_samp);
S.residual_span = S.lag_max - S.lag_min;
S.drift_samples_per_kbit = drift_samp_per_bit * 1000;
S.drift_ppm = drift_samp_per_bit / max(spb, eps) * 1e6;
end

function S = empty_stats()
S = struct();
S.n_valid = 0;
S.corr_median = NaN;
S.corr_min = NaN;
S.lag_mean = NaN;
S.lag_std = NaN;
S.lag_min = NaN;
S.lag_max = NaN;
S.residual_span = NaN;
S.drift_samples_per_kbit = NaN;
S.drift_ppm = NaN;
end

function make_plot(cap, full_raw_curve, full_raw_lags, full_bp_curve, full_bp_lags, T, S, out_png)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [120 120 1200 900]);
tlo = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile(tlo);
plot(full_raw_lags, full_raw_curve, 'LineWidth', 1.2, 'Color', [0.20 0.50 0.90]);
hold on;
plot(full_bp_lags, full_bp_curve, 'LineWidth', 1.6, 'Color', [0.90 0.40 0.10]);
grid on;
xlabel('Lag (samples)');
ylabel('Normalized xcorr');
title(sprintf('%s: whole-record cross-correlation', cap.name), 'Interpreter', 'none');
legend({'raw', 'bandpass 5-45 MHz'}, 'Location', 'best');

nexttile(tlo);
yyaxis left;
plot(T.bit_center, T.best_lag_samp, '-o', 'LineWidth', 1.0, 'MarkerSize', 3, ...
    'Color', [0.10 0.45 0.80]);
ylabel('Best Lag (samples)');
yyaxis right;
plot(T.bit_center, T.peak_corr, '-s', 'LineWidth', 1.0, 'MarkerSize', 3, ...
    'Color', [0.85 0.35 0.10]);
ylabel('Peak Corr');
grid on;
xlabel('Bit Index (frame center)');
title(sprintf('%s: frame-wise residual lag and xcorr peak', cap.name), 'Interpreter', 'none');

nexttile(tlo);
histogram(T.best_lag_samp(T.accepted), 'BinMethod', 'integers', ...
    'FaceColor', [0.10 0.45 0.80], 'EdgeColor', 'none');
grid on;
xlabel('Residual Lag (samples)');
ylabel('Frame Count');
title(sprintf('%s: accepted frames = %d | median corr = %.4f | drift = %.1f ppm', ...
    cap.name, S.n_valid, S.corr_median, S.drift_ppm), 'Interpreter', 'none');

exportgraphics(fig, out_png, 'Resolution', 180);
close(fig);
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

function y = shift_signal_same_length(x, lag)
x = x(:);
n = numel(x);
y = zeros(size(x));
if lag > 0
    y(1+lag:end) = x(1:end-lag);
    y(1:lag) = x(1);
elseif lag < 0
    d = -lag;
    y(1:end-d) = x(1+d:end);
    y(end-d+1:end) = x(end);
else
    y = x;
end
if numel(y) ~= n
    y = y(1:n);
end
end

function y = normalize_real(x)
x = x(:);
x = x - mean(x);
den = sqrt(sum(x.^2) + eps);
y = x / den;
end

function q = quantile_local(x, alpha)
x = sort(x(:));
n = numel(x);
idx = max(1, min(n, round(alpha * (n - 1) + 1)));
q = x(idx);
end

function bits = cyclic_take(bits_ref, start_idx, len)
idx = mod(start_idx - 1 + (0:len-1), numel(bits_ref)) + 1;
bits = bits_ref(idx(:));
end

function bits = read_01_lines(file)
fid = fopen(file, 'r');
assert(fid >= 0, 'Cannot open %s', file);
c = onCleanup(@() fclose(fid)); %#ok<NASGU>
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

function raw = read_numeric_lines(file)
fid = fopen(file, 'r');
assert(fid >= 0, 'Cannot open %s', file);
c = onCleanup(@() fclose(fid)); %#ok<NASGU>
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

function write_text_lines(file, lines)
fid = fopen(file, 'w');
assert(fid >= 0, 'Cannot open %s for write', file);
c = onCleanup(@() fclose(fid)); %#ok<NASGU>
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines{i});
end
end

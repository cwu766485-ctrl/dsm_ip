function paper_style_scope_vs_rtl_compare()
% paper_style_scope_vs_rtl_compare
% Compare scope-captured analog waveforms against RTL-derived ideal RF
% waveforms using a paper-style offline DSP flow:
%   1) scope capture / ideal RF waveform
%   2) offline digital downconversion at Fs/4 carrier
%   3) low-pass reconstruction of complex baseband
%   4) baseband waveform / spectrum comparison
%
% This produces communication-performance-style evidence rather than
% bit-true evidence.

repo = fullfile(fileparts(mfilename('fullpath')), '..', '..');
ref_file = resolve_reference_bits_file(repo, 'sim_rf_bits_01.txt');
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
cfg.bb_pass_mhz = 1.2;
cfg.bb_trans_mhz = 0.8;
cfg.bb_plot_mhz = 5.0;
cfg.rf_plot_mhz = 100.0;
cfg.rf_smooth_win_mhz = 1.5;
cfg.bb_smooth_win_mhz = 0.12;
cfg.fs_out_hz = 10e6;
cfg.wave_plot_len = 300;
cfg.ch_bw_hz = 810e3;
cfg.adj_offset_hz = 810e3;

rows = {};
fig_rf = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 760]);
tlo_rf = tiledlayout(fig_rf, numel(caps), 1, 'TileSpacing', 'compact', 'Padding', 'compact');
fig_bb = figure('Visible', 'off', 'Color', 'w', 'Position', [120 120 1200 820]);
tlo_bb = tiledlayout(fig_bb, numel(caps), 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for k = 1:numel(caps)
    raw = read_numeric_lines(caps(k).wfm_file);
    n_bits = floor(numel(raw) / caps(k).spb);
    raw = raw(1:n_bits * caps(k).spb);

    ref_seg = cyclic_take(ref_bits, caps(k).ref_start, n_bits);
    if caps(k).invert
        ref_seg = ~ref_seg;
    end
    y_ref = bits_to_analog(ref_seg, raw, caps(k).spb);

    Fs_scope = 1 / caps(k).dt;
    fc_hz = Fs_scope / caps(k).spb / 4;

    % RF bandpass display around the Fs/4 carrier.
    raw_rf = apply_cosine_bandpass(raw, caps(k).dt, 5, 45, 10);
    ref_rf = apply_cosine_bandpass(y_ref, caps(k).dt, 5, 45, 10);
    [f_rf, p_raw_rf] = simple_psd(raw_rf, caps(k).dt);
    [~, p_ref_rf] = simple_psd(ref_rf, caps(k).dt);
    keep_rf = f_rf <= min(cfg.rf_plot_mhz, f_rf(end));
    f_rf = f_rf(keep_rf);
    raw_rf_db = norm_db(p_raw_rf(keep_rf));
    ref_rf_db = norm_db(p_ref_rf(keep_rf));
    raw_rf_db_s = smooth_spectrum_db(raw_rf_db, f_rf, cfg.rf_smooth_win_mhz);
    ref_rf_db_s = smooth_spectrum_db(ref_rf_db, f_rf, cfg.rf_smooth_win_mhz);

    % Offline DSP to complex baseband.
    [raw_bb, fs_bb] = offline_ddc_to_baseband(raw, caps(k).dt, fc_hz, ...
        cfg.bb_pass_mhz * 1e6, cfg.bb_trans_mhz * 1e6, cfg.fs_out_hz);
    [ref_bb, ~] = offline_ddc_to_baseband(y_ref, caps(k).dt, fc_hz, ...
        cfg.bb_pass_mhz * 1e6, cfg.bb_trans_mhz * 1e6, cfg.fs_out_hz);

    al = align_complex_ls(raw_bb, ref_bb);
    y_al = al.y_aligned;
    x_al = al.x_aligned;
    wave_corr = complex_corr(y_al, x_al);
    evm_like = sqrt(mean(abs(y_al - x_al).^2) / (mean(abs(x_al).^2) + eps)) * 100;

    [f_bb, p_raw_bb] = centered_psd(raw_bb, fs_bb);
    [~, p_ref_bb] = centered_psd(ref_bb, fs_bb);
    keep_bb = abs(f_bb) <= cfg.bb_plot_mhz * 1e6;
    f_bb_plot = f_bb(keep_bb) / 1e6;
    raw_bb_db = norm_db(p_raw_bb(keep_bb));
    ref_bb_db = norm_db(p_ref_bb(keep_bb));
    raw_bb_db_s = smooth_spectrum_db(raw_bb_db, f_bb_plot, cfg.bb_smooth_win_mhz);
    ref_bb_db_s = smooth_spectrum_db(ref_bb_db, f_bb_plot, cfg.bb_smooth_win_mhz);
    bb_psd_corr = simple_corr(raw_bb_db_s, ref_bb_db_s);
    bb_psd_rmse = sqrt(mean((raw_bb_db_s - ref_bb_db_s).^2));
    ac_raw = calc_aclr_from_centered_psd(raw_bb, fs_bb, cfg.ch_bw_hz, cfg.adj_offset_hz);
    ac_ref = calc_aclr_from_centered_psd(ref_bb, fs_bb, cfg.ch_bw_hz, cfg.adj_offset_hz);

    [~, raw_pk_idx] = max(raw_bb_db_s);
    [~, ref_pk_idx] = max(ref_bb_db_s);
    peak_raw_bb_khz = f_bb_plot(raw_pk_idx) * 1e3;
    peak_ref_bb_khz = f_bb_plot(ref_pk_idx) * 1e3;

    rows(end+1, :) = {caps(k).name, wave_corr, evm_like, bb_psd_corr, bb_psd_rmse, ...
        peak_raw_bb_khz, peak_ref_bb_khz, ac_raw.ACPR_L_dBc, ac_raw.ACPR_R_dBc, ...
        mean([ac_raw.ACPR_L_dBc, ac_raw.ACPR_R_dBc]), ...
        ac_ref.ACPR_L_dBc, ac_ref.ACPR_R_dBc, mean([ac_ref.ACPR_L_dBc, ac_ref.ACPR_R_dBc]), ...
        fs_bb / 1e6, fc_hz / 1e6}; %#ok<AGROW>

    nexttile(tlo_rf);
    plot(f_rf, raw_rf_db, 'LineWidth', 0.25, 'Color', [0.72 0.82 0.95]);
    hold on;
    plot(f_rf, ref_rf_db, '--', 'LineWidth', 0.25, 'Color', [0.78 0.93 0.78]);
    plot(f_rf, raw_rf_db_s, 'LineWidth', 2.0, 'Color', [0.05 0.35 0.80]);
    plot(f_rf, ref_rf_db_s, '--', 'LineWidth', 2.0, 'Color', [0.10 0.60 0.20]);
    grid on;
    xlabel('Frequency (MHz)');
    ylabel('PSD (dB, normalized)');
    title(sprintf('%s: bandpass-filtered RF spectrum', caps(k).name), 'Interpreter', 'none');
    legend({'scope raw', 'RTL raw', 'scope envelope', 'RTL envelope'}, 'Location', 'best');
    xlim([0 cfg.rf_plot_mhz]);

    nexttile(tlo_bb);
    plot(f_bb_plot, raw_bb_db, 'LineWidth', 0.25, 'Color', [0.72 0.82 0.95]);
    hold on;
    plot(f_bb_plot, ref_bb_db, '--', 'LineWidth', 0.25, 'Color', [0.78 0.93 0.78]);
    plot(f_bb_plot, raw_bb_db_s, 'LineWidth', 2.0, 'Color', [0.05 0.35 0.80]);
    plot(f_bb_plot, ref_bb_db_s, '--', 'LineWidth', 2.0, 'Color', [0.10 0.60 0.20]);
    grid on;
    xlabel('Baseband Frequency (MHz)');
    ylabel('PSD (dB, normalized)');
    title(sprintf('%s: offline-DSP baseband spectrum', caps(k).name), 'Interpreter', 'none');
    legend({'scope raw', 'RTL raw', 'scope envelope', 'RTL envelope'}, 'Location', 'best');
    xlim([-cfg.bb_plot_mhz cfg.bb_plot_mhz]);

    nexttile(tlo_bb);
    Lw = min(cfg.wave_plot_len, numel(y_al));
    n = 0:Lw-1;
    plot(n, real(y_al(1:Lw)), 'LineWidth', 1.2, 'Color', [0.05 0.35 0.80]);
    hold on;
    plot(n, real(x_al(1:Lw)), '--', 'LineWidth', 1.2, 'Color', [0.10 0.60 0.20]);
    plot(n, imag(y_al(1:Lw)), 'LineWidth', 1.0, 'Color', [0.20 0.50 0.95]);
    plot(n, imag(x_al(1:Lw)), '--', 'LineWidth', 1.0, 'Color', [0.35 0.75 0.35]);
    grid on;
    xlabel('Baseband Sample Index');
    ylabel('Amplitude');
    title(sprintf('%s: aligned baseband waveform | corr=%.4f | EVM-like=%.2f%%', ...
        caps(k).name, wave_corr, evm_like), 'Interpreter', 'none');
    legend({'scope I', 'RTL I', 'scope Q', 'RTL Q'}, 'Location', 'best');
end

sgtitle(tlo_rf, 'Paper-Style Scope vs RTL Comparison: RF Bandpass Spectrum');
exportgraphics(fig_rf, fullfile(repo, 'paper_style_scope_vs_rtl_rf.png'), 'Resolution', 160);
close(fig_rf);

sgtitle(tlo_bb, 'Paper-Style Scope vs RTL Comparison: Offline-DSP Baseband');
exportgraphics(fig_bb, fullfile(repo, 'paper_style_scope_vs_rtl_baseband.png'), 'Resolution', 160);
close(fig_bb);

T = cell2table(rows, 'VariableNames', ...
    {'capture', 'bb_wave_corr', 'bb_evm_like_percent', 'bb_psd_corr', ...
     'bb_psd_rmse_db', 'bb_peak_scope_khz', 'bb_peak_rtl_khz', ...
     'scope_aclr_l_dbc', 'scope_aclr_r_dbc', 'scope_aclr_avg_dbc', ...
     'rtl_aclr_l_dbc', 'rtl_aclr_r_dbc', 'rtl_aclr_avg_dbc', ...
     'bb_fs_mhz', 'rf_fc_mhz'});
writetable(T, fullfile(repo, 'paper_style_scope_vs_rtl_metrics.csv'));
disp(T);
end

function [y_bb_dec, fs_out] = offline_ddc_to_baseband(x, dt, fc_hz, lp_pass_hz, lp_trans_hz, fs_out_target)
x = x(:) - mean(x(:));
n = numel(x);
fs = 1 / dt;
t = (0:n-1).' * dt;
x_mix = x .* exp(-1j * 2 * pi * fc_hz * t);
x_lp = apply_complex_lowpass(x_mix, dt, lp_pass_hz, lp_trans_hz);
decim = max(1, round(fs / fs_out_target));
y_bb_dec = x_lp(1:decim:end);
fs_out = fs / decim;
end

function y = apply_complex_lowpass(x, dt, pass_hz, trans_hz)
x = x(:);
n = numel(x);
fs = 1 / dt;
X = fftshift(fft(x));
f_hz = ((0:n-1).' - floor(n/2)) * (fs / n);
g = raised_cosine_lowpass(abs(f_hz), pass_hz, trans_hz);
Y = X .* g;
y = ifft(ifftshift(Y));
end

function g = raised_cosine_lowpass(f_abs_hz, pass_hz, trans_hz)
stop_hz = pass_hz + trans_hz;
g = zeros(size(f_abs_hz));
mid = f_abs_hz <= pass_hz;
g(mid) = 1;
tr = (f_abs_hz > pass_hz) & (f_abs_hz <= stop_hz);
if any(tr)
    t = (f_abs_hz(tr) - pass_hz) / max(stop_hz - pass_hz, eps);
    g(tr) = 0.5 + 0.5 * cos(pi * t);
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

function al = align_complex_ls(y, x)
y = y(:);
x = x(:);
L = min(numel(x), numel(y));
x = x(1:L);
y = y(1:L);
maxLag = min(2000, floor(L/4));
[c, lags] = xcorr(y, x, maxLag, 'coeff');
[~, im] = max(abs(c));
lag = lags(im);
if lag > 0
    y2 = y(1+lag:end);
    x2 = x(1:end-lag);
elseif lag < 0
    y2 = y(1:end+lag);
    x2 = x(1-lag:end);
else
    y2 = y;
    x2 = x;
end
L2 = min(numel(x2), numel(y2));
x2 = x2(1:L2);
y2 = y2(1:L2);
g = (y2' * x2) / (y2' * y2 + eps);
al = struct();
al.x_aligned = x2;
al.y_aligned = g * y2;
al.lag = lag;
al.gain = g;
end

function [f_hz, p] = centered_psd(x, fs)
x = x(:) - mean(x(:));
n = numel(x);
w = hann_local(n);
X = fftshift(fft(x .* w));
p = abs(X).^2 / max(1, sum(w.^2));
f_hz = ((0:n-1).' - floor(n/2)) * (fs / n);
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

function y = norm_db(x)
y = 10 * log10(max(x, 1e-30));
y = y - max(y);
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

function r = complex_corr(x, y)
x = x(:) - mean(x);
y = y(:) - mean(y);
den = sqrt(sum(abs(x).^2) * sum(abs(y).^2));
if den == 0
    r = NaN;
else
    r = abs(sum(conj(x) .* y) / den);
end
end

function m = calc_aclr_from_centered_psd(y, Fs, BWch, adjOffset)
y = y(:);
N = numel(y);
winLen = 2^floor(log2(min(4096, N)));
winLen = max(winLen, 256);
winLen = min(winLen, N);
overlap = floor(winLen / 2);
nfft = max(8192, 4 * winLen);
window = hamming(winLen);
[Pxx, f] = pwelch(y, window, overlap, nfft, Fs, 'centered');
df = mean(diff(f));
Pch = band_power(Pxx, f, -BWch/2, +BWch/2, df);
PadL = band_power(Pxx, f, -adjOffset-BWch/2, -adjOffset+BWch/2, df);
PadR = band_power(Pxx, f, +adjOffset-BWch/2, +adjOffset+BWch/2, df);
m = struct();
m.ACPR_L_dBc = 10 * log10((PadL + eps) / (Pch + eps));
m.ACPR_R_dBc = 10 * log10((PadR + eps) / (Pch + eps));
end

function P = band_power(Pxx, f, f1, f2, df)
idx = (f >= f1) & (f <= f2);
P = sum(Pxx(idx)) * df;
end

function y = smooth_spectrum_db(x, f_axis, win_axis)
x = x(:);
f_axis = f_axis(:);
if numel(x) <= 2
    y = x;
    return;
end
df = median(diff(f_axis));
half_span = max(1, round(0.5 * win_axis / max(abs(df), eps)));
kernel = ones(2 * half_span + 1, 1);
kernel = kernel / sum(kernel);
y = conv(x, kernel, 'same');
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

function compute_recovered_bits_evm_sndr()
% compute_recovered_bits_evm_sndr
% Treat recovered 0/1 files as digital RF bitstreams, perform offline
% DDC/LPF/decimation, and compare against the best-matched RTL RF segment.
%
% These are recovered-bitstream-vs-RTL-segment metrics. They are useful for
% judging whether the recovered 0/1 sequence is good enough for
% communication-domain reconstruction, but they are not strict
% transmitter-only metrics.

repo = fullfile(fileparts(mfilename('fullpath')), '..', '..');
ref_file = fullfile(repo, 'fpga', 'vivado', 'cartesian_dsm', ...
    'cartesian_dsm.sim', 'sim_1', 'behav', 'xsim', 'sim_rf_bits_01.txt');
ref_bits = read_01_lines(ref_file);

caps = [ ...
    struct( ...
        'name', 'DSM000', ...
        'bits_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'DSM000_recovered_bits_01.txt'), ...
        'ref_start', 50871, ...
        'invert', false), ...
    struct( ...
        'name', 'RefCurve', ...
        'bits_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'RefCurve_scope_aux_recovered_bits_01.txt'), ...
        'ref_start', 18932, ...
        'invert', true) ...
];

cfg = struct();
cfg.fs_rf_hz = 100e6;
cfg.fc_hz = 25e6;
cfg.bb_pass_hz = 1.2e6;
cfg.bb_trans_hz = 0.8e6;
cfg.fs_out_hz = 10e6;
cfg.bb_plot_mhz = 5.0;
cfg.bb_smooth_win_mhz = 0.12;
cfg.wave_plot_len = 300;

rows = {};
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 820]);
tlo = tiledlayout(fig, numel(caps), 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for k = 1:numel(caps)
    bits = read_01_lines(caps(k).bits_file);
    n_bits = numel(bits);
    ref_seg = cyclic_take(ref_bits, caps(k).ref_start, n_bits);
    if caps(k).invert
        ref_seg = ~ref_seg;
    end

    y_rf = 2 * double(bits(:)) - 1;
    x_rf = 2 * double(ref_seg(:)) - 1;

    [y_bb, fs_bb] = rf_bits_to_baseband(y_rf, cfg.fs_rf_hz, cfg.fc_hz, ...
        cfg.bb_pass_hz, cfg.bb_trans_hz, cfg.fs_out_hz);
    [x_bb, ~] = rf_bits_to_baseband(x_rf, cfg.fs_rf_hz, cfg.fc_hz, ...
        cfg.bb_pass_hz, cfg.bb_trans_hz, cfg.fs_out_hz);

    al = align_complex_ls(y_bb, x_bb);
    y_al = al.y_aligned;
    x_al = al.x_aligned;
    e = y_al - x_al;
    Ps = mean(abs(x_al).^2);
    Pe = mean(abs(e).^2);
    evm_pct = sqrt((Pe + eps) / (Ps + eps)) * 100;
    sndr_db = 10 * log10((Ps + eps) / (Pe + eps));
    wave_corr = complex_corr(y_al, x_al);

    [f_bb, p_y] = centered_psd(y_bb, fs_bb);
    [~, p_x] = centered_psd(x_bb, fs_bb);
    keep = abs(f_bb) <= cfg.bb_plot_mhz * 1e6;
    f_plot = f_bb(keep) / 1e6;
    y_db = norm_db(p_y(keep));
    x_db = norm_db(p_x(keep));
    y_db_s = smooth_spectrum_db(y_db, f_plot, cfg.bb_smooth_win_mhz);
    x_db_s = smooth_spectrum_db(x_db, f_plot, cfg.bb_smooth_win_mhz);
    bb_psd_corr = simple_corr(y_db_s, x_db_s);
    bb_psd_rmse = sqrt(mean((y_db_s - x_db_s).^2));

    [~, iy] = max(y_db_s);
    [~, ix] = max(x_db_s);
    peak_y_khz = f_plot(iy) * 1e3;
    peak_x_khz = f_plot(ix) * 1e3;

    rows(end+1, :) = {caps(k).name, evm_pct, sndr_db, wave_corr, bb_psd_corr, ...
        bb_psd_rmse, peak_y_khz, peak_x_khz, fs_bb / 1e6, al.lag}; %#ok<AGROW>

    nexttile(tlo);
    plot(f_plot, y_db, 'LineWidth', 0.25, 'Color', [0.72 0.82 0.95]);
    hold on;
    plot(f_plot, x_db, '--', 'LineWidth', 0.25, 'Color', [0.78 0.93 0.78]);
    plot(f_plot, y_db_s, 'LineWidth', 2.0, 'Color', [0.05 0.35 0.80]);
    plot(f_plot, x_db_s, '--', 'LineWidth', 2.0, 'Color', [0.10 0.60 0.20]);
    grid on;
    xlabel('Baseband Frequency (MHz)');
    ylabel('PSD (dB, normalized)');
    title(sprintf('%s: recovered-bitstream baseband spectrum', caps(k).name), 'Interpreter', 'none');
    legend({'recovered raw', 'RTL raw', 'recovered env', 'RTL env'}, 'Location', 'best');
    xlim([-cfg.bb_plot_mhz cfg.bb_plot_mhz]);

    nexttile(tlo);
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
    title(sprintf('%s: EVM=%.2f%% | SNDR=%.2f dB | corr=%.4f', ...
        caps(k).name, evm_pct, sndr_db, wave_corr), 'Interpreter', 'none');
    legend({'recovered I', 'RTL I', 'recovered Q', 'RTL Q'}, 'Location', 'best');
end

sgtitle(tlo, 'Recovered-Bitstream Offline Reconstruction vs RTL Segment');
exportgraphics(fig, fullfile(repo, 'recovered_bits_evm_sndr.png'), 'Resolution', 160);
close(fig);

T = cell2table(rows, 'VariableNames', ...
    {'capture', 'evm_percent', 'sndr_db', 'bb_wave_corr', 'bb_psd_corr', ...
     'bb_psd_rmse_db', 'bb_peak_scope_khz', 'bb_peak_rtl_khz', 'bb_fs_mhz', 'align_lag'});
writetable(T, fullfile(repo, 'recovered_bits_evm_sndr.csv'));
disp(T);
end

function [y_bb_dec, fs_out] = rf_bits_to_baseband(x_rf, fs_rf_hz, fc_hz, lp_pass_hz, lp_trans_hz, fs_out_target)
x_rf = x_rf(:) - mean(x_rf(:));
n = numel(x_rf);
t = (0:n-1).' / fs_rf_hz;
x_mix = x_rf .* exp(-1j * 2 * pi * fc_hz * t);
x_lp = apply_complex_lowpass(x_mix, fs_rf_hz, lp_pass_hz, lp_trans_hz);
decim = max(1, round(fs_rf_hz / fs_out_target));
y_bb_dec = x_lp(1:decim:end);
fs_out = fs_rf_hz / decim;
end

function y = apply_complex_lowpass(x, fs_hz, pass_hz, trans_hz)
x = x(:);
n = numel(x);
X = fftshift(fft(x));
f_hz = ((0:n-1).' - floor(n/2)) * (fs_hz / n);
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

function y = norm_db(x)
y = 10 * log10(max(x, 1e-30));
y = y - max(y);
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

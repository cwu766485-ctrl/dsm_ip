function compare_scope_spectrum_to_rtl()
% compare_scope_spectrum_to_rtl
% Compare spectra of scope-exported analog waveforms against spectra of
% ideal piecewise-constant waveforms synthesized from recovered bits and
% from the RTL rf_bit reference.

repo = fullfile(fileparts(mfilename('fullpath')), '..', '..');
ref_file = fullfile(repo, 'fpga', 'vivado', 'cartesian_dsm', ...
    'cartesian_dsm.sim', 'sim_1', 'behav', 'xsim', 'sim_rf_bits_01.txt');
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

rows = {};
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 780]);
tlo = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
fig_s = figure('Visible', 'off', 'Color', 'w', 'Position', [120 120 1200 780]);
tlo_s = tiledlayout(fig_s, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

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

    [f_mhz, p_raw] = simple_psd(raw, caps(k).dt);
    [~, p_rec] = simple_psd(y_rec, caps(k).dt);
    [~, p_ref] = simple_psd(y_ref, caps(k).dt);

    max_f_mhz = min(500, f_mhz(end));
    keep = f_mhz <= max_f_mhz;
    f_plot = f_mhz(keep);
    raw_db = to_db(p_raw(keep));
    rec_db = to_db(p_rec(keep));
    ref_db = to_db(p_ref(keep));

    raw_db = raw_db - max(raw_db);
    rec_db = rec_db - max(rec_db);
    ref_db = ref_db - max(ref_db);
    raw_db_s = smooth_spectrum_db(raw_db, f_plot, 4.0);
    rec_db_s = smooth_spectrum_db(rec_db, f_plot, 4.0);
    ref_db_s = smooth_spectrum_db(ref_db, f_plot, 4.0);

    peak_raw = dominant_peak(f_plot, raw_db);
    peak_rec = dominant_peak(f_plot, rec_db);
    peak_ref = dominant_peak(f_plot, ref_db);

    corr_rec = simple_corr(raw_db, rec_db);
    corr_ref = simple_corr(raw_db, ref_db);
    rmse_rec = sqrt(mean((raw_db - rec_db).^2));
    rmse_ref = sqrt(mean((raw_db - ref_db).^2));

    rows(end+1, :) = {caps(k).name, 'scope_vs_recovered', corr_rec, rmse_rec, peak_raw, peak_rec}; %#ok<AGROW>
    rows(end+1, :) = {caps(k).name, 'scope_vs_rtl', corr_ref, rmse_ref, peak_raw, peak_ref}; %#ok<AGROW>

    nexttile(tlo);
    plot(f_plot, raw_db, 'LineWidth', 1.0, 'Color', [0.05 0.35 0.80]);
    hold on;
    plot(f_plot, rec_db, '--', 'LineWidth', 1.0, 'Color', [0.85 0.20 0.10]);
    grid on;
    xlabel('Frequency (MHz)');
    ylabel('PSD (dB, normalized)');
    title(sprintf('%s: scope vs recovered | corr=%.4f', caps(k).name, corr_rec), 'Interpreter', 'none');
    legend({'scope raw', 'recovered ideal'}, 'Location', 'best');

    nexttile(tlo);
    plot(f_plot, raw_db, 'LineWidth', 1.0, 'Color', [0.05 0.35 0.80]);
    hold on;
    plot(f_plot, ref_db, '--', 'LineWidth', 1.0, 'Color', [0.10 0.60 0.20]);
    grid on;
    xlabel('Frequency (MHz)');
    ylabel('PSD (dB, normalized)');
    title(sprintf('%s: scope vs RTL | corr=%.4f', caps(k).name, corr_ref), 'Interpreter', 'none');
    legend({'scope raw', 'RTL ideal'}, 'Location', 'best');

    nexttile(tlo_s);
    plot(f_plot, raw_db, 'LineWidth', 0.25, 'Color', [0.68 0.80 0.95]);
    hold on;
    plot(f_plot, rec_db, '--', 'LineWidth', 0.25, 'Color', [0.98 0.77 0.72]);
    plot(f_plot, raw_db_s, 'LineWidth', 1.8, 'Color', [0.05 0.35 0.80]);
    plot(f_plot, rec_db_s, '--', 'LineWidth', 1.8, 'Color', [0.85 0.20 0.10]);
    grid on;
    xlabel('Frequency (MHz)');
    ylabel('PSD (dB, normalized)');
    title(sprintf('%s: scope vs recovered | raw corr=%.4f', caps(k).name, corr_rec), 'Interpreter', 'none');
    legend({'scope raw', 'recovered raw', 'scope envelope', 'recovered envelope'}, 'Location', 'best');

    nexttile(tlo_s);
    plot(f_plot, raw_db, 'LineWidth', 0.25, 'Color', [0.68 0.80 0.95]);
    hold on;
    plot(f_plot, ref_db, '--', 'LineWidth', 0.25, 'Color', [0.75 0.92 0.75]);
    plot(f_plot, raw_db_s, 'LineWidth', 1.8, 'Color', [0.05 0.35 0.80]);
    plot(f_plot, ref_db_s, '--', 'LineWidth', 1.8, 'Color', [0.10 0.60 0.20]);
    grid on;
    xlabel('Frequency (MHz)');
    ylabel('PSD (dB, normalized)');
    title(sprintf('%s: scope vs RTL | raw corr=%.4f', caps(k).name, corr_ref), 'Interpreter', 'none');
    legend({'scope raw', 'RTL raw', 'scope envelope', 'RTL envelope'}, 'Location', 'best');

end

sgtitle(tlo, 'Scope Waveform Spectrum vs Ideal Bitstream-Derived Spectrum');
exportgraphics(fig, fullfile(repo, 'scope_vs_rtl_spectrum.png'), 'Resolution', 160);
close(fig);
sgtitle(tlo_s, 'Scope Waveform Spectrum vs Ideal Bitstream-Derived Spectrum (Smoothed Envelope for Display)');
exportgraphics(fig_s, fullfile(repo, 'scope_vs_rtl_spectrum_smoothed.png'), 'Resolution', 160);
close(fig_s);

T = cell2table(rows, 'VariableNames', ...
    {'capture', 'comparison', 'log_psd_corr', 'log_psd_rmse_db', 'scope_peak_mhz', 'model_peak_mhz'});
writetable(T, fullfile(repo, 'scope_vs_rtl_spectrum_metrics.csv'));
disp(T);
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

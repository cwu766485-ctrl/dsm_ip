function plot_first_1000_samples()
% plot_first_1000_samples
% Plot the first 1000 samples of the two oscilloscope waveform exports,
% using the exported sample interval for the time axis.

n_plot = 1000;
repo = fullfile(fileparts(mfilename('fullpath')), '..', '..');

files = {
    fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'DSM000.Wfm.csv'), ...
    fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'RefCurve_scope_aux.Wfm.csv')
};
meta_files = {
    fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'DSM000.csv'), ...
    fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'RefCurve_scope_aux.csv')
};
labels = {
    'DSM000.Wfm.csv', ...
    'RefCurve_scope_aux.Wfm.csv'
};

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 700]);
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

for k = 1:numel(files)
    y = read_numeric_lines(files{k}, n_plot);
    dt = read_sample_interval(meta_files{k});
    x = (0:numel(y)-1).' * dt * 1e9;

    nexttile;
    plot(x, y, 'LineWidth', 1.0, 'Color', [0.05 0.35 0.80]);
    grid on;
    xlim([x(1) x(end)]);
    xlabel('Time (ns)');
    ylabel('Voltage (V)');
    title(sprintf('%s: first %d samples, dt = %.3f ps', ...
        labels{k}, numel(y), dt * 1e12), 'Interpreter', 'none');
end

sgtitle('Oscilloscope Waveform Exports: First 1000 Samples');

out_png = fullfile(repo, 'first_1000_samples_dsm000_refcurve.png');
exportgraphics(fig, out_png, 'Resolution', 150);
close(fig);

fprintf('Wrote %s\n', out_png);
end

function y = read_numeric_lines(file, max_count)
fid = fopen(file, 'r');
assert(fid >= 0, 'Cannot open %s', file);
c = onCleanup(@() fclose(fid));

y = zeros(max_count, 1);
n = 0;
while n < max_count
    t = fgetl(fid);
    if ~ischar(t)
        break;
    end
    x = str2double(strtrim(t));
    if ~isnan(x)
        n = n + 1;
        y(n) = x;
    end
end
y = y(1:n);
end

function dt = read_sample_interval(file)
fid = fopen(file, 'r');
assert(fid >= 0, 'Cannot open %s', file);
c = onCleanup(@() fclose(fid));

dt = NaN;
while true
    t = fgetl(fid);
    if ~ischar(t)
        break;
    end
    if startsWith(t, 'SignalResolution:')
        parts = split(t, ':');
        dt = str2double(parts{2});
        break;
    end
    if startsWith(t, 'Resolution:')
        parts = split(t, ':');
        dt = str2double(parts{2});
    end
end

assert(~isnan(dt) && dt > 0, 'Could not parse sample interval from %s', file);
end

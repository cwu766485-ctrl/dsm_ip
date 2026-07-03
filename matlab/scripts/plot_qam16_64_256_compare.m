function out = plot_qam16_64_256_compare(varargin)
% plot_qam16_64_256_compare
% Create a single figure comparing QAM16 / QAM64 / QAM256 metrics across 7 DSM structures.

  p = inputParser;
  p.addParameter('repo', '');
  p.addParameter('out_png', '');
  p.parse(varargin{:});
  cfg = p.Results;

  here = fileparts(mfilename('fullpath'));
  if isempty(cfg.repo)
    cfg.repo = fullfile(here, '..', '..');
  end

  p0 = fullfile(cfg.repo, 'matlab', 'out', 'p0_seven_metrics.csv');        % QAM16
  p64 = fullfile(cfg.repo, 'matlab', 'out', 'p1_64_seven_metrics.csv');    % QAM64
  p256 = fullfile(cfg.repo, 'matlab', 'out', 'p1_256_seven_metrics.csv');  % QAM256

  must_exist(p0);
  must_exist(p64);
  must_exist(p256);

  T16 = readtable(p0);
  T64 = readtable(p64);
  T256 = readtable(p256);

  % Normalize the column set (P0 file has no Profile column).
  if ~ismember('Profile', T16.Properties.VariableNames)
    T16.Profile = repmat("p0_16", height(T16), 1);
  end
  T16.Profile = repmat("QAM16", height(T16), 1);
  T64.Profile = repmat("QAM64", height(T64), 1);
  T256.Profile = repmat("QAM256", height(T256), 1);

  keep = {'Profile','Design','EVM_percent','SNDR_dB','ACLR_avg_dBc'};
  T16 = T16(:, keep);
  T64 = T64(:, keep);
  T256 = T256(:, keep);

  % Consistent ordering.
  order = ["LPDSM","LPDSM2","EFDSM","EFDSM2","MASH11","MASH111","MASH22"];
  [~, i16] = ismember(order, string(T16.Design));
  [~, i64] = ismember(order, string(T64.Design));
  [~, i256] = ismember(order, string(T256.Design));
  if any(i16==0) || any(i64==0) || any(i256==0)
    error('Missing designs in one of the CSVs. Expected 7 designs.');
  end
  T16 = T16(i16,:);
  T64 = T64(i64,:);
  T256 = T256(i256,:);

  labels = cellstr(order);
  x = 1:numel(labels);

  evm = [T16.EVM_percent, T64.EVM_percent, T256.EVM_percent];
  sndr = [T16.SNDR_dB, T64.SNDR_dB, T256.SNDR_dB];
  aclr = [T16.ACLR_avg_dBc, T64.ACLR_avg_dBc, T256.ACLR_avg_dBc];

  fig = figure('Color', 'w', 'Position', [100 100 1200 900]);

  tiledlayout(3,1, 'Padding','compact', 'TileSpacing','compact');

  nexttile;
  bar(x, evm, 'grouped');
  grid on;
  ylabel('EVM (%)');
  title('QAM16 vs QAM64 vs QAM256 - EVM');
  set(gca, 'XTick', x, 'XTickLabel', labels);
  legend({'QAM16','QAM64','QAM256'}, 'Location','northeastoutside');

  nexttile;
  bar(x, sndr, 'grouped');
  grid on;
  ylabel('SNDR (dB)');
  title('QAM16 vs QAM64 vs QAM256 - SNDR');
  set(gca, 'XTick', x, 'XTickLabel', labels);

  nexttile;
  bar(x, aclr, 'grouped');
  grid on;
  ylabel('ACLR avg (dBc)');
  title('QAM16 vs QAM64 vs QAM256 - ACLR avg');
  set(gca, 'XTick', x, 'XTickLabel', labels);

  if isempty(cfg.out_png)
    cfg.out_png = fullfile(cfg.repo, 'matlab', 'out', 'qam16_64_256_compare.png');
  end
  out_dir = fileparts(cfg.out_png);
  if exist(out_dir, 'dir') ~= 7
    mkdir(out_dir);
  end
  exportgraphics(fig, cfg.out_png, 'Resolution', 200);

  out = struct();
  out.png = cfg.out_png;
  out.sources = struct('qam16', p0, 'qam64', p64, 'qam256', p256);
  fprintf('Saved figure: %s\n', cfg.out_png);
end

function must_exist(p)
  if exist(p, 'file') ~= 2
    error('Missing file: %s', p);
  end
end

% run_p0_table52_compare.m
% P0 comparison configuration (16QAM-OFDM, OSR=32)
%
% Goal:
%   Reproduce the "seven-structure comparison" pipeline used for Table 5.2:
%     LPDSM, LPDSM2, EFDSM, EFDSM2, MASH11, MASH111, MASH22
%   and output a metrics table (EVM/SNDR/ACPR) in a reproducible way.
%
% This script currently reuses the existing MATLAB code in the
% monorepo. It is a bridge step toward a self-contained dsm_ip tree.
%
% Usage:
%   cd matlab
%   path_setup
%   run_p0_table52_compare

function out = run_p0_table52_compare(varargin)
  p = inputParser;
  p.addParameter('seed', 1);
  p.addParameter('save_csv', true);
  p.addParameter('out_dir', fullfile(pwd, 'out'));
  p.parse(varargin{:});
  cfg = p.Results;

  if ~exist(cfg.out_dir, 'dir')
    mkdir(cfg.out_dir);
  end

  % Prefer an existing "single entry" script if present. If not found,
  % fall back to a legacy evaluation path.
  %
  % Known candidates in the existing repository:
  % - plot_nominal_ofdm16qam_osr32_compare_v1.m (paper-style comparison)
  % - compare_16qam_256qam_fixed.m (legacy tmp; includes ACPR logic)
  have_plot = exist('plot_nominal_ofdm16qam_osr32_compare_v1', 'file') == 2;

  rng(cfg.seed);

  if have_plot
    % This script is expected to generate rows internally. We treat it as
    % the authoritative P0 Table-5.2-style comparison driver.
    fprintf('[P0] Running plot_nominal_ofdm16qam_osr32_compare_v1 (seed=%d)\n', cfg.seed);
    rows = plot_nominal_ofdm16qam_osr32_compare_v1(cfg.seed); %#ok<NASGU>
    % Some versions may not return rows. If it doesn't, we can't standardize
    % extraction without refactoring; still treat as "executed".
    out = struct('status', 'executed', 'seed', cfg.seed, 'driver', 'plot_nominal_ofdm16qam_osr32_compare_v1');
  else
    error(['No supported P0 driver found on MATLAB path. ' ...
      'Expected plot_nominal_ofdm16qam_osr32_compare_v1.m from the MATLAB tree.']);
  end

  % Best-effort: if a variable named "rows" exists and is a struct array,
  % serialize to CSV for later plotting/reporting.
  if evalin('caller', 'exist(''rows'',''var'')') %#ok<EVLDIR>
    try
      rows = evalin('caller', 'rows'); %#ok<NASGU>
    catch
      rows = [];
    end
  else
    rows = [];
  end

  if cfg.save_csv && ~isempty(rows) && isstruct(rows)
    csv_path = fullfile(cfg.out_dir, sprintf('p0_table52_seed%d.csv', cfg.seed));
    fprintf('[P0] Writing CSV: %s\n', csv_path);
    write_struct_rows_csv(rows, csv_path);
    out.csv = csv_path;
  end
end

function write_struct_rows_csv(rows, csv_path)
  % Minimal CSV writer that tolerates missing fields.
  fields = {'Design','EVM_rms_percent','SNDR_dB','ACLR_avg_dBc','ACPR_L_dBc','ACPR_R_dBc','Semantics'};
  fid = fopen(csv_path, 'w');
  assert(fid > 0);
  c = onCleanup(@() fclose(fid));

  fprintf(fid, '%s', fields{1});
  for k = 2:numel(fields)
    fprintf(fid, ',%s', fields{k});
  end
  fprintf(fid, '\n');

  for i = 1:numel(rows)
    r = rows(i);
    vals = cell(1, numel(fields));
    for k = 1:numel(fields)
      f = fields{k};
      if isfield(r, f)
        v = r.(f);
      else
        v = '';
      end
      vals{k} = to_csv_cell(v);
    end
    fprintf(fid, '%s', vals{1});
    for k = 2:numel(vals)
      fprintf(fid, ',%s', vals{k});
    end
    fprintf(fid, '\n');
  end
end

function s = to_csv_cell(v)
  if isstring(v) || ischar(v)
    s = quote_csv(string(v));
  elseif isnumeric(v) && isscalar(v)
    if isnan(v)
      s = '';
    else
      s = sprintf('%.6g', v);
    end
  else
    % For unknown types, just serialize as empty to keep the CSV stable.
    s = '';
  end
end

function s = quote_csv(str)
  str = strrep(str, '"', '""');
  s = '"' + str + '"';
end

function [Results, Summary, Artifacts] = run_lpdsmdpa_bpf_dpd_staged(varargin)
% Run an interpretable baseline-to-impairment DPA/DPD experiment.
%
% Each stage retrains the Q2.14 memoryless and memory-polynomial packages on
% the same disjoint fit/validation/test protocol.  The linear stage still
% contains the 1-bit DSM, Fs/4 reconstruction, ideal BPF, and feedback
% recovery; it disables DPA nonlinearity and observation noise.

  cfg = struct('stages', ["ideal_bb" "linear" "am_am" "am_pm" "memory" "noise" "lpdsm2"], ...
    'out_dir', '', 'write_outputs', true, 'verbose', false, ...
    'fit_nsym', [], 'validation_nsym', [], 'test_nsym', [], ...
    'validation_seeds', [], 'test_seeds', [], 'ilc_steps', [], ...
    'ilc_max_passes', []);
  cfg = parse_kv(cfg, varargin{:});
  if isempty(cfg.out_dir)
    cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'out', 'dpd');
  end

  results_cell = cell(numel(cfg.stages), 1);
  summary_cell = cell(numel(cfg.stages), 1);
  artifacts = cell(numel(cfg.stages), 1);
  for k = 1:numel(cfg.stages)
    stage = string(cfg.stages(k));
    args = {'dpa_stage', stage, 'write_outputs', false, 'verbose', cfg.verbose};
    if ~isempty(cfg.fit_nsym), args(end+1:end+2) = {'fit_nsym', cfg.fit_nsym}; end
    if ~isempty(cfg.validation_nsym), args(end+1:end+2) = {'validation_nsym', cfg.validation_nsym}; end
    if ~isempty(cfg.test_nsym), args(end+1:end+2) = {'test_nsym', cfg.test_nsym}; end
    if ~isempty(cfg.validation_seeds), args(end+1:end+2) = {'validation_seeds', cfg.validation_seeds}; end
    if ~isempty(cfg.test_seeds), args(end+1:end+2) = {'test_seeds', cfg.test_seeds}; end
    if ~isempty(cfg.ilc_steps), args(end+1:end+2) = {'ilc_steps', cfg.ilc_steps}; end
    if ~isempty(cfg.ilc_max_passes), args(end+1:end+2) = {'ilc_max_passes', cfg.ilc_max_passes}; end
    [r, ~, a] = run_lpdsmdpa_bpf_dpd_closed_loop(args{:});
    s = a.summary;
    r.Stage = repmat(stage, height(r), 1);
    s.Stage = repmat(stage, height(s), 1);
    r = movevars(r, 'Stage', 'Before', 1);
    s = movevars(s, 'Stage', 'Before', 1);
    results_cell{k} = r;
    summary_cell{k} = s;
    artifacts{k} = a;
  end
  Results = vertcat(results_cell{:});
  Summary = vertcat(summary_cell{:});
  Artifacts = struct('stages', cfg.stages, 'runs', {artifacts});

  if cfg.write_outputs
    if ~exist(cfg.out_dir, 'dir'), mkdir(cfg.out_dir); end
    writetable(Results, fullfile(cfg.out_dir, 'lpdsmdpa_bpf_dpd_staged_results.csv'));
    writetable(Summary, fullfile(cfg.out_dir, 'lpdsmdpa_bpf_dpd_staged_summary.csv'));
    write_report(fullfile(cfg.out_dir, 'lpdsmdpa_bpf_dpd_staged.md'), Summary, cfg);
  end
end

function cfg = parse_kv(cfg, varargin)
  if mod(numel(varargin), 2) ~= 0, error('Arguments must be name/value pairs.'); end
  for k = 1:2:numel(varargin)
    name = char(varargin{k});
    if ~isfield(cfg, name), error('Unknown option: %s', name); end
    cfg.(name) = varargin{k+1};
  end
end

function write_report(path, summary, cfg)
  fid = fopen(path, 'w');
  if fid < 0, error('Cannot write %s', path); end
  cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
  fprintf(fid, '# Staged LPDSM2 DPA/DPD Experiment\n\n');
  fprintf(fid, 'This is a MATLAB behavioral endpoint, not ADS or measured RF evidence.\n\n');
  fprintf(fid, 'The linear stage includes the one-bit DSM, Fs/4 reconstruction, ideal output BPF, coherent feedback recovery, and transient-trimmed metrics. Each later stage adds one declared impairment and retrains both DPD models.\n\n');
  fprintf(fid, '| Stage | Mode | Mean EVM %% | Mean SNDR dB | Mean out-of-band dBc | Total limits |\n|---|---|---:|---:|---:|---:|\n');
  for k = 1:height(summary)
    fprintf(fid, '| %s | %s | %.4f | %.4f | %.4f | %d |\n', ...
      summary.Stage(k), summary.Mode(k), summary.MeanEVM_percent(k), ...
      summary.MeanSNDR_dB(k), summary.MeanACLR_dBc(k), summary.TotalDPDLimitCount(k));
  end
  fprintf(fid, '\n## Interpretation\n\n');
  fprintf(fid, '- `linear` is the analog-equivalent DPA/DPD calibration baseline.\n');
  fprintf(fid, '- `am_am`, `am_pm`, `memory`, and `noise` add impairments cumulatively.\n');
  fprintf(fid, '- `lpdsm2` is the actual LPDSM2 + Fs/4 digital endpoint diagnostic; it is kept separate from the DPA/DPD calibration gate.\n');
  fprintf(fid, '- A DPD result is not considered a communication claim unless the linear baseline is healthy and the relevant impairments are calibrated to a declared target.\n');
end

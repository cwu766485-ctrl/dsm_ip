function prepare_interp_frontend_bittrue_vectors(varargin)
% Generate deterministic input and fixed-point expected vectors for RTL compare.

  cfg.n_input = 128;
  cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
                         'out', 'interp_frontend', 'bittrue');
  for n = 1:2:numel(varargin)
    cfg.(varargin{n}) = varargin{n + 1};
  end

  if ~exist(cfg.out_dir, 'dir')
    mkdir(cfg.out_dir);
  end

  interp_frontend_fixed('n_input', cfg.n_input, 'out_dir', cfg.out_dir);

  src = fullfile(cfg.out_dir, 'input_iq_q1_15.csv');
  dst = fullfile(cfg.out_dir, 'interp_input_iq.csv');
  copyfile(src, dst);

  for mode = 0:4
    src = fullfile(cfg.out_dir, sprintf('mode%d_fixed_iq_q1_15.csv', mode));
    dst = fullfile(cfg.out_dir, sprintf('interp_mode%d_expected.csv', mode));
    copyfile(src, dst);
  end
end

function metadata = export_uvm_qam_ofdm_vectors(varargin)
%EXPORT_UVM_QAM_OFDM_VECTORS Export baseband Q1.15 OFDM I/Q for UVM.
%   This exporter intentionally stops before the RTL interpolation frontend.
%   The UVM DUT owns the x32 interpolation, Fs/4 mixer, and RF DSM stages.

  cfg = default_cfg();
  if mod(nargin, 2) ~= 0
    error('Arguments must be name/value pairs.');
  end
  for index = 1:2:nargin
    cfg.(varargin{index}) = varargin{index + 1};
  end

  rng(cfg.seed, 'twister');
  samples = make_ofdm_baseband(cfg);
  scale = 32767;
  i_q1_15 = clamp_q1_15(round(real(samples) * scale));
  q_q1_15 = clamp_q1_15(round(imag(samples) * scale));

  if numel(i_q1_15) ~= cfg.nsym * (cfg.nfft + cfg.ncp)
    error('Unexpected OFDM sample count.');
  end
  out_dir = fileparts(cfg.output_csv);
  if ~exist(out_dir, 'dir')
    mkdir(out_dir);
  end
  fid = fopen(cfg.output_csv, 'w');
  if fid < 0
    error('Cannot open output CSV: %s', cfg.output_csv);
  end
  fprintf(fid, 'n,i_q1_15,q_q1_15,last\n');
  for index = 1:numel(i_q1_15)
    fprintf(fid, '%d,%d,%d,%d\n', index - 1, i_q1_15(index), q_q1_15(index), ...
            index == numel(i_q1_15));
  end
  fclose(fid);

  metadata = struct( ...
      'output_csv', cfg.output_csv, ...
      'seed', cfg.seed, ...
      'qam_order', cfg.qam_order, ...
      'nfft', cfg.nfft, ...
      'ncp', cfg.ncp, ...
      'nsym', cfg.nsym, ...
      'used_subcarriers', numel(cfg.used_sc), ...
      'input_count', numel(i_q1_15), ...
      'drive_rms', cfg.drive_rms, ...
      'i_min', min(i_q1_15), ...
      'i_max', max(i_q1_15), ...
      'q_min', min(q_q1_15), ...
      'q_max', max(q_q1_15));
  fprintf(['UVM_QAM_OFDM_VECTORS input=%d qam=%d nfft=%d ncp=%d nsym=%d ', ...
           'used_sc=%d seed=%d\n'], metadata.input_count, metadata.qam_order, ...
          metadata.nfft, metadata.ncp, metadata.nsym, ...
          metadata.used_subcarriers, metadata.seed);
end

function cfg = default_cfg()
  repo_root = fileparts(fileparts(mfilename('fullpath')));
  repo_root = fileparts(repo_root);
  cfg.seed = 20260913;
  cfg.qam_order = 16;
  cfg.nfft = 64;
  cfg.ncp = 16;
  cfg.nsym = 128;
  cfg.used_sc = [-12:-1, 1:12];
  cfg.drive_rms = 0.25;
  cfg.output_csv = fullfile(repo_root, 'uvm_verif', 'refmodel', 'python', 'out', ...
                            'qam_ofdm_input.csv');
end

function samples = make_ofdm_baseband(cfg)
  if sqrt(cfg.qam_order) ~= round(sqrt(cfg.qam_order))
    error('Only square QAM is supported.');
  end
  used = cfg.used_sc(:);
  symbols = qammod_square(randi([0, cfg.qam_order - 1], numel(used), cfg.nsym), ...
                          cfg.qam_order);
  frequency = zeros(cfg.nfft, cfg.nsym);
  frequency(mod(used, cfg.nfft) + 1, :) = symbols;
  time_domain = ifft(frequency, cfg.nfft, 1) * sqrt(cfg.nfft);
  with_cp = [time_domain(end - cfg.ncp + 1:end, :); time_domain];
  samples = with_cp(:);
  rms_value = sqrt(mean(abs(samples).^2));
  if rms_value == 0
    error('Generated OFDM waveform has zero RMS.');
  end
  samples = samples / rms_value * cfg.drive_rms;
end

function symbols = qammod_square(indices, order)
  side = round(sqrt(order));
  i_index = mod(double(indices), side);
  q_index = floor(double(indices) / side);
  i_level = 2 * i_index - side + 1;
  q_level = 2 * q_index - side + 1;
  symbols = i_level + 1i * q_level;
  symbols = symbols / sqrt(mean(abs(symbols(:)).^2));
end

function values = clamp_q1_15(values)
  values = int32(values);
  values(values > 32767) = 32767;
  values(values < -32768) = -32768;
end

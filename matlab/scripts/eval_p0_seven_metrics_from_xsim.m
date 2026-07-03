% eval_p0_seven_metrics_from_xsim.m
% Evaluate seven required structures from xsim dumps:
%   LPDSM, LPDSM2, EFDSM, EFDSM2, MASH11, MASH111, MASH22
%
% Output:
%   matlab/out/p0_seven_metrics.csv
%   matlab/out/p0_seven_metrics.md

function T = eval_p0_seven_metrics_from_xsim(varargin)
  p = inputParser;
  p.addParameter('xsim_dir', '');
  p.addParameter('coe_i', '');
  p.addParameter('coe_q', '');
  p.addParameter('out_csv', '');
  p.addParameter('multibit_scale_mode', 'reference_fixed');
  p.parse(varargin{:});
  cfg = p.Results;

  here = fileparts(mfilename('fullpath')); % .../matlab/scripts
  repo = fullfile(here, '..', '..'); % repo root

  if isempty(cfg.xsim_dir)
    cfg.xsim_dir = fullfile(repo, 'verif', 'out_xsim_p0');
  end
  if isempty(cfg.coe_i)
    cfg.coe_i = fullfile(repo, 'verif', 'vectors', 'p0', 'rom_i.mem');
  end
  if isempty(cfg.coe_q)
    cfg.coe_q = fullfile(repo, 'verif', 'vectors', 'p0', 'rom_q.mem');
  end
  if isempty(cfg.out_csv)
    cfg.out_csv = fullfile(repo, 'matlab', 'out', 'p0_seven_metrics.csv');
  end

  must_exist_dir(cfg.xsim_dir);
  must_exist_file(cfg.coe_i);
  must_exist_file(cfg.coe_q);

  out_dir = fileparts(cfg.out_csv);
  if exist(out_dir, 'dir') ~= 7
    mkdir(out_dir);
  end

  % Normalize names (legacy and new TB naming compatibility).
  map_if_exists(fullfile(cfg.xsim_dir, 'sim_bits_01_lp1.txt'), fullfile(cfg.xsim_dir, 'sim_bits_01.txt'));
  map_if_exists(fullfile(cfg.xsim_dir, 'sim_bits_01_lp2.txt'), fullfile(cfg.xsim_dir, 'sim_bits_01_dsm2.txt'));

  I_rom = read_iq_vector_local(cfg.coe_i);
  Q_rom = read_iq_vector_local(cfg.coe_q);
  x_ref = double(I_rom(:)) / double(2^15 - 1) + 1j * double(Q_rom(:)) / double(2^15 - 1);

  % P0 reference meta
  meta.active_bins = [-26:-1 1:26];
  meta.bw_margin_sc = 1;
  meta.OSR = 32;
  meta.Fs_dsm = 100e6;
  meta.Fs_bb = meta.Fs_dsm / meta.OSR;
  meta.Delta_f = meta.Fs_bb / 64;

  BWch = (max(abs(meta.active_bins)) + meta.bw_margin_sc) * meta.Delta_f * 2;
  adjOffset = BWch;

  designs = { ...
    'LPDSM',   'bb_sign1bit',      'sim_bits_01.txt'; ...
    'LPDSM2',  'bb_sign1bit',      'sim_bits_01_dsm2.txt'; ...
    'EFDSM',   'bb_sign1bit',      'sim_bits_01_ef1.txt'; ...
    'EFDSM2',  'bb_sign1bit',      'sim_bits_01_ef2.txt'; ...
    'MASH11',  'bb_multibit_yout', 'sim_yout_signed_mash11_mb.txt'; ...
    'MASH111', 'bb_multibit_yout', 'sim_yout_signed_mash111_mb.txt'; ...
    'MASH22',  'bb_multibit_yout', 'sim_yout_signed_mash22_mb.txt' ...
  };

  rows = repmat(struct( ...
    'Design', "", ...
    'MetricDomain', "", ...
    'NativeScale', NaN, ...
    'N_bits', 0, ...
    'N_rec', 0, ...
    'EVM_percent', NaN, ...
    'SNDR_dB', NaN, ...
    'ACLR_L_dBc', NaN, ...
    'ACLR_R_dBc', NaN, ...
    'ACLR_avg_dBc', NaN), size(designs,1), 1);

  for k = 1:size(designs,1)
    name = string(designs{k,1});
    domain = string(designs{k,2});
    fp = fullfile(cfg.xsim_dir, designs{k,3});
    must_exist_file(fp);

    [y_bb, scale_used] = read_native_bb_dump_local(fp, domain, char(name), cfg.multibit_scale_mode);
    [y_bb, x_ref_now] = align_dump_to_input_local(y_bb, x_ref);

    recCfg = struct( ...
      'OSR', meta.OSR, ...
      'Fs_dsm', meta.Fs_dsm, ...
      'Fs_bb', meta.Fs_bb, ...
      'BWch', BWch, ...
      'StopAtt', 80, ...
      'UseFastFir', false, ...
      'ZeroPhase', false);

    [y_rec, x_ref_bb] = lp_reconstruct_and_decimate(y_bb, x_ref_now, recCfg);
    al = lp_align_and_ls_gain(y_rec, x_ref_bb);
    [y_al, x_al] = lp_discard_settle_pair(al.y_aligned, al.x_aligned, 64);
    m = lp_calc_sndr_evm(y_al, x_al);

    psdCfg = default_psd_cfg_local(numel(y_bb));
    ac = lp_calc_acpr_aclr_from_psd(y_bb, meta.Fs_dsm, BWch, adjOffset, psdCfg);

    rows(k).Design = name;
    rows(k).MetricDomain = domain;
    rows(k).NativeScale = scale_used;
    rows(k).N_bits = numel(y_bb);
    rows(k).N_rec = numel(y_al);
    rows(k).EVM_percent = m.EVM_rms_percent;
    rows(k).SNDR_dB = m.SNDR_dB;
    rows(k).ACLR_L_dBc = ac.ACPR_L_dBc;
    rows(k).ACLR_R_dBc = ac.ACPR_R_dBc;
    rows(k).ACLR_avg_dBc = mean([ac.ACPR_L_dBc, ac.ACPR_R_dBc], 'omitnan');
  end

  T = struct2table(rows);
  writetable(T, cfg.out_csv);
  md_path = strrep(cfg.out_csv, '.csv', '.md');
  write_markdown_table_local(T, md_path);

  disp(T);
  fprintf('Saved CSV: %s\n', cfg.out_csv);
  fprintf('Saved MD : %s\n', md_path);
end

function [y_bb, scale_used] = read_native_bb_dump_local(fp, metric_domain, design_name, scale_mode)
  M = readmatrix(fp, 'FileType', 'text');
  if isempty(M) || size(M,2) < 2 || all(isnan(M(:)))
    fid = fopen(fp, 'r');
    if fid < 0
      error('Cannot open %s', fp);
    end
    c = textscan(fid, '%f %f', 'Delimiter', {' ', sprintf('\t'), ','}, 'MultipleDelimsAsOne', true);
    fclose(fid);
    M = [c{1}, c{2}];
  end
  M = round(M(:,1:2));

  switch lower(char(metric_domain))
    case 'bb_sign1bit'
      yi = 2 * M(:,1) - 1;
      yq = 2 * M(:,2) - 1;
      y_bb = yi + 1j * yq;
      scale_used = 1;
    case 'bb_multibit_yout'
      yi = double(M(:,1));
      yq = double(M(:,2));
      switch lower(string(scale_mode))
        case "reference_fixed"
          switch upper(string(design_name))
            case "MASH11"
              scale_used = 3;
            case "MASH111"
              scale_used = 7;
            case "MASH22"
              scale_used = 5;
            otherwise
              scale_used = max(1, max(abs([yi; yq])));
          end
        otherwise
          scale_used = max(1, max(abs([yi; yq])));
      end
      y_bb = (yi + 1j * yq) / scale_used;
    otherwise
      error('Unsupported metric domain: %s', metric_domain);
  end
end

function [y_aligned, x_aligned] = align_dump_to_input_local(y_bb, x_ref)
  y_bb = y_bb(:);
  x_ref = x_ref(:);
  if numel(y_bb) > 1 && numel(x_ref) > 1
    y_bb = y_bb(2:end);
    x_ref = x_ref(1:end-1);
  end
  N = min(numel(y_bb), numel(x_ref));
  y_aligned = y_bb(1:N);
  x_aligned = x_ref(1:N);
end

function psdCfg = default_psd_cfg_local(N)
  psdCfg.winLen = 2^floor(log2(min(4096, N)));
  psdCfg.winLen = max(psdCfg.winLen, 256);
  psdCfg.winLen = min(psdCfg.winLen, N);
  psdCfg.overlap = floor(psdCfg.winLen/2);
  psdCfg.nfft = max(8192, 4*psdCfg.winLen);
  psdCfg.window = hamming(psdCfg.winLen);
end

function write_markdown_table_local(T, md_path)
  fid = fopen(md_path, 'w');
  if fid < 0
    warning('Cannot open markdown output: %s', md_path);
    return;
  end
  c = onCleanup(@() fclose(fid));
  fprintf(fid, '| Design | Domain | EVM(%%) | SNDR(dB) | ACLR_avg(dBc) |\n');
  fprintf(fid, '|---|---|---:|---:|---:|\n');
  for i = 1:height(T)
    fprintf(fid, '| %s | %s | %.4f | %.4f | %.4f |\n', ...
      T.Design(i), T.MetricDomain(i), T.EVM_percent(i), T.SNDR_dB(i), T.ACLR_avg_dBc(i));
  end
end

function must_exist_file(p)
  if exist(p, 'file') ~= 2
    error('Missing file: %s', p);
  end
end

function must_exist_dir(p)
  if exist(p, 'dir') ~= 7
    error('Missing dir: %s', p);
  end
end

function map_if_exists(src, dst)
  if exist(src, 'file') == 2
    copyfile(src, dst);
  end
end

function v = read_iq_vector_local(path)
  [~,~,ext] = fileparts(path);
  switch lower(ext)
    case '.coe'
      v = lp_read_coe_int16_hex(path);
    case '.mem'
      txt = strtrim(string(readlines(path)));
      txt(txt == "") = [];
      u = uint16(hex2dec(txt));
      v = typecast(u, 'int16');
      v = double(v(:));
    otherwise
      error('Unsupported I/Q vector extension: %s', ext);
  end
end

function T = compare_multibit_rtl_xsim(varargin)
%COMPARE_MULTIBIT_RTL_XSIM Compare exploratory multibit RTL dumps to MATLAB.
%
% This compares the seven multibit DSM exploration modes sample-for-sample.
% Default nbits is 4, matching rtl/ip/dsm_ip_core MB_Q_BITS default.

  p = inputParser;
  p.addParameter('xsim_dir', '');
  p.addParameter('vec_dir', '');
  p.addParameter('out_csv', '');
  p.addParameter('nbits', 4);
  p.parse(varargin{:});
  cfg = p.Results;

  here = fileparts(mfilename('fullpath'));
  repo = fullfile(here, '..', '..', '..');
  if isempty(cfg.xsim_dir)
    cfg.xsim_dir = fullfile(repo, 'verif', 'out_xsim_p0_multibit');
  end
  if isempty(cfg.vec_dir)
    cfg.vec_dir = fullfile(repo, 'verif', 'vectors', 'p0');
  end
  if isempty(cfg.out_csv)
    cfg.out_csv = fullfile(repo, 'matlab', 'out', 'dsm_multibit', 'multibit_rtl_bittrue_compare.csv');
  end

  i_vec = read_mem_i16(fullfile(cfg.vec_dir, 'rom_i.mem'));
  q_vec = read_mem_i16(fullfile(cfg.vec_dir, 'rom_q.mem'));

  specs = { ...
    'LPDSM multibit',   'lp1',     'sim_yout_signed_lp1_multibit.txt'; ...
    'LPDSM2 multibit',  'lp2',     'sim_yout_signed_lp2_multibit.txt'; ...
    'EFDSM multibit',   'ef1',     'sim_yout_signed_ef1_multibit.txt'; ...
    'EFDSM2 multibit',  'ef2',     'sim_yout_signed_ef2_multibit.txt'; ...
    'MASH11 multibit',  'mash11',  'sim_yout_signed_mash11_multibit.txt'; ...
    'MASH111 multibit', 'mash111', 'sim_yout_signed_mash111_multibit.txt'; ...
    'MASH22 multibit',  'mash22',  'sim_yout_signed_mash22_multibit.txt' ...
  };

  rows = repmat(struct('Design',"",'NBits',0,'Samples',0,'Mismatches',0, ...
                       'Pass',false,'FirstMismatch',0), size(specs,1), 1);
  for k = 1:size(specs,1)
    design = string(specs{k,1});
    alg = char(specs{k,2});
    dump_file = fullfile(cfg.xsim_dir, specs{k,3});
    rtl = read_pair_dump(dump_file);

    model_i = dsm_multibit_model(i_vec, alg, cfg.nbits);
    model_q = dsm_multibit_model(q_vec, alg, cfg.nbits);
    model = [model_i(:), model_q(:)];

    n = min(size(rtl,1), size(model,1));
    neq = any(rtl(1:n,:) ~= model(1:n,:), 2);
    mismatches = sum(neq) + abs(size(rtl,1) - size(model,1));
    first = find(neq, 1, 'first');
    if isempty(first)
      first = 0;
    end

    rows(k).Design = design;
    rows(k).NBits = cfg.nbits;
    rows(k).Samples = n;
    rows(k).Mismatches = mismatches;
    rows(k).Pass = (mismatches == 0);
    rows(k).FirstMismatch = first;
  end

  T = struct2table(rows);
  out_dir = fileparts(cfg.out_csv);
  if exist(out_dir, 'dir') ~= 7
    mkdir(out_dir);
  end
  writetable(T, cfg.out_csv);
  disp(T);
  fprintf('Saved multibit bit-true compare CSV: %s\n', cfg.out_csv);

  if any(~T.Pass)
    error('Multibit RTL/MATLAB bit-true comparison failed.');
  end
end

function v = read_mem_i16(path)
  lines = strtrim(string(readlines(path)));
  lines(lines == "") = [];
  u = hex2dec(lines);
  u(u >= 32768) = u(u >= 32768) - 65536;
  v = int64(u(:));
end

function m = read_pair_dump(path)
  if exist(path, 'file') ~= 2
    error('Missing RTL dump: %s', path);
  end
  m = readmatrix(path, 'FileType', 'text');
  if isempty(m) || size(m,2) < 2 || all(isnan(m(:)))
    fid = fopen(path, 'r');
    if fid < 0
      error('Cannot open %s', path);
    end
    c = textscan(fid, '%f %f', 'Delimiter', {' ', sprintf('\t'), ','}, 'MultipleDelimsAsOne', true);
    fclose(fid);
    m = [c{1}, c{2}];
  end
  m = int64(round(m(:,1:2)));
end

function T = p0_compare_rtl_xsim(varargin)
% Compare P0 MATLAB fixed-point models against XSim dumps sample-for-sample.

  p = inputParser;
  p.addParameter('xsim_dir', '');
  p.addParameter('vec_dir', '');
  p.addParameter('out_csv', '');
  p.parse(varargin{:});
  cfg = p.Results;

  here = fileparts(mfilename('fullpath'));
  repo = fullfile(here, '..', '..');
  if isempty(cfg.xsim_dir)
    cfg.xsim_dir = fullfile(repo, 'verif', 'out_xsim_p0');
  end
  if isempty(cfg.vec_dir)
    cfg.vec_dir = fullfile(repo, 'verif', 'vectors', 'p0');
  end
  if isempty(cfg.out_csv)
    cfg.out_csv = fullfile(repo, 'matlab', 'out', 'p0_bittrue_compare.csv');
  end

  i_vec = p0_read_mem_i16(fullfile(cfg.vec_dir, 'rom_i.mem'));
  q_vec = p0_read_mem_i16(fullfile(cfg.vec_dir, 'rom_q.mem'));

  specs = { ...
    'LPDSM',   'lp1',     'bits', 'sim_bits_01_lp1.txt'; ...
    'LPDSM2',  'lp2',     'bits', 'sim_bits_01_lp2.txt'; ...
    'EFDSM',   'ef1',     'bits', 'sim_bits_01_ef1.txt'; ...
    'EFDSM2',  'ef2',     'bits', 'sim_bits_01_ef2.txt'; ...
    'MASH11',  'mash11',  'yout', 'sim_yout_signed_mash11_mb.txt'; ...
    'MASH111', 'mash111', 'yout', 'sim_yout_signed_mash111_mb.txt'; ...
    'MASH22',  'mash22',  'yout', 'sim_yout_signed_mash22_mb.txt' ...
  };

  rows = repmat(struct('Design',"",'Domain',"",'Samples',0,'Mismatches',0,'Pass',false,'FirstMismatch',0), size(specs,1), 1);
  for k = 1:size(specs,1)
    design = string(specs{k,1});
    alg = char(specs{k,2});
    domain = string(specs{k,3});
    dump_file = fullfile(cfg.xsim_dir, specs{k,4});
    rtl = p0_read_pair_dump(dump_file);

    model_i = p0_dsm_bittrue(i_vec, alg);
    model_q = p0_dsm_bittrue(q_vec, alg);
    model = [model_i(:), model_q(:)];

    n = min(size(rtl,1), size(model,1));
    neq = any(rtl(1:n,:) ~= model(1:n,:), 2);
    mismatches = sum(neq);
    first = find(neq, 1, 'first');
    if isempty(first)
      first = 0;
    end

    rows(k).Design = design;
    rows(k).Domain = domain;
    rows(k).Samples = n;
    rows(k).Mismatches = mismatches + abs(size(rtl,1) - size(model,1));
    rows(k).Pass = (rows(k).Mismatches == 0);
    rows(k).FirstMismatch = first;
  end

  T = struct2table(rows);
  out_dir = fileparts(cfg.out_csv);
  if exist(out_dir, 'dir') ~= 7
    mkdir(out_dir);
  end
  writetable(T, cfg.out_csv);
  disp(T);
  fprintf('Saved bit-true compare CSV: %s\n', cfg.out_csv);

  if any(~T.Pass)
    error('P0 bit-true comparison failed.');
  end
end

function v = p0_read_mem_i16(path)
  lines = strtrim(string(readlines(path)));
  lines(lines == "") = [];
  u = hex2dec(lines);
  u(u >= 32768) = u(u >= 32768) - 65536;
  v = int64(u(:));
end

function m = p0_read_pair_dump(path)
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

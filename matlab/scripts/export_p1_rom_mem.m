function out = export_p1_rom_mem(varargin)
% export_p1_rom_mem
% Generate industrial-profile ROM vectors for P1.
%
% Profiles:
%   - p1_64  : 64QAM,  Nfft=512, Ncp=36, SCS=30k, OSR=32
%   - p1_256 : 256QAM, Nfft=512, Ncp=36, SCS=30k, OSR=32

  p = inputParser;
  p.addParameter('profile', 'p1_64');
  p.addParameter('DEPTH', 65536);
  p.addParameter('Nsym', 400);
  p.addParameter('seed', 7);
  p.parse(varargin{:});
  cfg = p.Results;

  profile = lower(string(cfg.profile));
  switch profile
    case "p1_64"
      M = 64;
    case "p1_256"
      M = 256;
    otherwise
      error('Unsupported profile: %s', profile);
  end

  Nfft = 512;
  Ncp = 36;
  Delta_f = 30e3;
  OSR = 32;
  W = 16;
  clip_val = 0.999;
  headroom = 0.95;
  active_bins = [-166:-1, 1:166]; % ~10MHz occupied at 30kHz SCS

  rng(cfg.seed);

  % 1) OFDM-QAM generation
  k = log2(M);
  Nused = numel(active_bins);
  Nb = cfg.Nsym * Nused * k;
  bits = randi([0 1], Nb, 1);
  qam_data = qammod_local_gray(bits, M);
  qam_data = reshape(qam_data, Nused, cfg.Nsym);

  used_sc = map_active_bins_to_fft(active_bins, Nfft);
  Xk = zeros(Nfft, cfg.Nsym);
  Xk(used_sc, :) = qam_data;
  ofdm_td = ifft(Xk, Nfft, 1);
  ofdm_cp = [ofdm_td(end-Ncp+1:end, :); ofdm_td];
  x_bb = ofdm_cp(:);
  x_bb = x_bb / rms(x_bb);

  % 2) Interpolate to DSM rate
  x_os = resample_or_fir_up(x_bb, OSR);
  x_os = x_os / rms(x_os);

  max_iq = max(abs([real(x_os); imag(x_os)]));
  A_auto = headroom * clip_val / max_iq;
  A = min(A_auto, 0.35);
  x_os = A * x_os;

  % 3) Quantize and fit ROM depth
  scale = 2^(W-1) - 1;
  I = max(min(real(x_os), clip_val), -clip_val);
  Q = max(min(imag(x_os), clip_val), -clip_val);
  I_q = int16(round(I * scale));
  Q_q = int16(round(Q * scale));

  I_rom = fit_to_depth_truncate(I_q, cfg.DEPTH);
  Q_rom = fit_to_depth_truncate(Q_q, cfg.DEPTH);

  % 4) Export
  repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
  vec_dir = fullfile(repo_root, 'verif', 'vectors', char(profile));
  if exist(vec_dir, 'dir') ~= 7
    mkdir(vec_dir);
  end

  memI = fullfile(vec_dir, 'rom_i.mem');
  memQ = fullfile(vec_dir, 'rom_q.mem');
  write_memh_int16(I_rom, memI);
  write_memh_int16(Q_rom, memQ);

  meta = struct();
  meta.profile = char(profile);
  meta.M = M;
  meta.Nfft = Nfft;
  meta.Ncp = Ncp;
  meta.Nsym = cfg.Nsym;
  meta.Delta_f = Delta_f;
  meta.Fs_bb = Nfft * Delta_f;
  meta.OSR = OSR;
  meta.Fs_dsm = meta.Fs_bb * OSR;
  meta.active_bins = active_bins;
  meta.bw_margin_sc = 1;
  meta.W = W;
  meta.ROM_DEPTH = cfg.DEPTH;
  meta.seed = cfg.seed;
  meta.A = A;
  meta.I_rom = I_rom;
  meta.Q_rom = Q_rom;
  meta.input_ref = double(I_rom(:)) / double(2^15 - 1) + 1j * double(Q_rom(:)) / double(2^15 - 1);

  metaFile = fullfile(vec_dir, 'profile_meta.mat');
  save(metaFile, 'meta');

  out = struct('memI', memI, 'memQ', memQ, 'metaFile', metaFile, 'profile', char(profile));
  fprintf('[P1] profile=%s, M=%d, vectors=%s\n', char(profile), M, vec_dir);
end

function used_sc = map_active_bins_to_fft(active_bins, Nfft)
  used_sc = zeros(1, numel(active_bins));
  for ii = 1:numel(active_bins)
    b = active_bins(ii);
    if b == 0
      used_sc(ii) = 1;
    elseif b > 0
      used_sc(ii) = b + 1;
    else
      used_sc(ii) = Nfft + b + 1;
    end
  end
end

function x_os = resample_or_fir_up(x_bb, OSR)
  use_resample = (exist('resample', 'file') == 2);
  if use_resample
    try
      x_os = resample(x_bb, OSR, 1);
      return;
    catch
      % fall through
    end
  end

  x_up = upsample(x_bb, OSR);
  Nfir = 256;
  fc = 0.45 / OSR;
  h = fir1(Nfir, fc);
  x_os = filter(h, 1, x_up);
  gd = floor(Nfir/2);
  x_os = x_os(gd+1:end);
end

function y = fit_to_depth_truncate(x, depth)
  x = x(:);
  if numel(x) >= depth
    y = x(1:depth);
  else
    y = [x; zeros(depth - numel(x), 1, 'like', x)];
  end
end

function write_memh_int16(v, path)
  fid = fopen(path, 'w');
  assert(fid > 0);
  c = onCleanup(@() fclose(fid));
  v = int16(v(:));
  for k = 1:numel(v)
    fprintf(fid, '%04X\n', typecast(v(k), 'uint16'));
  end
end

function s = qammod_local_gray(bits, M)
  k = log2(M);
  if mod(numel(bits), k) ~= 0
    error('bits length must be multiple of log2(M)');
  end
  L = sqrt(M);
  if abs(L - round(L)) > eps
    error('Only square QAM supported');
  end
  L = round(L);
  k2 = k / 2;

  b = reshape(bits(:), k, []).';
  bi = b(:,1:k2);
  bq = b(:,k2+1:k);
  idxI = gray_to_bin(bi);
  idxQ = gray_to_bin(bq);

  levels = -(L-1):2:(L-1);
  xi = levels(idxI+1);
  xq = levels(idxQ+1);

  sc = sqrt((2/3)*(M-1));
  s = (xi + 1i*xq) / sc;
end

function idx = gray_to_bin(b)
  k = size(b,2);
  bin = zeros(size(b));
  bin(:,1) = b(:,1);
  for bitIdx = 2:k
    bin(:,bitIdx) = xor(bin(:,bitIdx-1), b(:,bitIdx));
  end
  idx = zeros(size(b,1),1);
  for bitIdx = 1:k
    idx = idx + bin(:,bitIdx) * 2^(k-bitIdx);
  end
end

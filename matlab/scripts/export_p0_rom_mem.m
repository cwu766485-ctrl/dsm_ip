% export_p0_rom_mem.m
% Generate P0 (16QAM-OFDM, Fs_dsm=100 MHz, OSR=32, depth=65536) ROM vectors and export:
%   - .coe (Vivado ROM init)
%   - .mem (hex per line) for $readmemh simulation (rom_reader USE_FILE_ROM)
%
% Output directory:
%   verif/vectors/p0/
%
% Usage:
%   cd matlab
%   path_setup
%   export_p0_rom_mem

function out = export_p0_rom_mem(varargin)
  p = inputParser;
  p.addParameter('OSR', 32);
  p.addParameter('DEPTH', 65536);
  p.addParameter('enable_edge_taper', false);
  p.parse(varargin{:});
  cfg = p.Results;

  % scripts/ -> matlab/ ->  -> repo root
  repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
  vec_dir = fullfile(repo_root, 'verif', 'vectors', 'p0');
  if exist(vec_dir, 'dir') ~= 7
    mkdir(vec_dir);
  end

  [coeI, coeQ, metaFile] = stage1_ofdm_qam_to_coe_lp_dsm_input_v3(cfg.OSR, cfg.DEPTH, cfg.enable_edge_taper);

  I_rom = lp_read_coe_int16_hex(coeI);
  Q_rom = lp_read_coe_int16_hex(coeQ);

  memI = fullfile(vec_dir, 'rom_i.mem');
  memQ = fullfile(vec_dir, 'rom_q.mem');
  write_memh_int16(I_rom, memI);
  write_memh_int16(Q_rom, memQ);

  out = struct();
  out.coeI = coeI;
  out.coeQ = coeQ;
  out.metaFile = metaFile;
  out.memI = memI;
  out.memQ = memQ;
  out.vec_dir = vec_dir;

  fprintf('[P0] Wrote memh: %s\n', memI);
  fprintf('[P0] Wrote memh: %s\n', memQ);
end

function write_memh_int16(v, path)
  fid = fopen(path, 'w');
  assert(fid > 0);
  c = onCleanup(@() fclose(fid));
  v = int16(v(:));
  for k = 1:numel(v)
    % Two's complement 16-bit, 4 hex digits.
    fprintf(fid, '%04X\n', typecast(v(k), 'uint16'));
  end
end

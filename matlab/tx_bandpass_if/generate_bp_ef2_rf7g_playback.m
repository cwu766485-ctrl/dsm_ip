function meta = generate_bp_ef2_rf7g_playback(output_file, varargin)
%GENERATE_BP_EF2_RF7G_PLAYBACK Create raw 32-bit GT playback words.
%   The generated file contains one hexadecimal 32-bit word per line. Bit 0
%   is the earliest one-bit BP-EFDSM2 sample and must be serialized first.

  p = inputParser;
  addParameter(p, 'num_words', 4096);
  addParameter(p, 'user_clk_hz', 218.75e6);
  addParameter(p, 'amplitude_q15', 8192);
  addParameter(p, 'phase_rad', 0);
  addParameter(p, 'acc_w', 28);
  parse(p, varargin{:});
  c = p.Results;

  validateattributes(c.num_words, {'numeric'}, {'scalar', 'integer', 'positive'});
  validateattributes(c.user_clk_hz, {'numeric'}, {'scalar', 'positive'});
  validateattributes(c.amplitude_q15, {'numeric'}, {'scalar', 'integer', '>=', 0, '<=', 32767});
  if nargin < 1 || isempty(output_file)
    error('output_file is required');
  end

  word_w = 32;
  fs_hz = word_w * c.user_clk_hz;
  n = (0:(c.num_words * word_w - 1)).';
  % A real Fs/4 IF carrier: +A, 0, -A, 0.  The BP EFDSM then shapes noise
  % about the intended 1.75-GHz center for this 7-GS/s playback mode.
  x = int64(round(c.amplitude_q15 * cos((pi/2) * n + c.phase_rad)));
  [~, core] = bp_ef2_fs4_model(x, 'acc_w', c.acc_w, 'saturate', true);

  fid = fopen(output_file, 'w');
  if fid < 0
    error('Cannot open %s for writing', output_file);
  end
  cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
  for word_idx = 0:(c.num_words - 1)
    bits = core(word_idx*word_w + (1:word_w)) ~= 0;
    word = uint32(0);
    for bit_idx = 0:(word_w - 1)
      if bits(bit_idx + 1)
        word = bitor(word, bitshift(uint32(1), bit_idx));
      end
    end
    fprintf(fid, '%08X\n', word);
  end

  meta = struct('word_width', word_w, 'num_words', c.num_words, ...
    'user_clk_hz', c.user_clk_hz, 'sample_rate_hz', fs_hz, ...
    'center_hz', fs_hz/4, 'amplitude_q15', c.amplitude_q15, ...
    'serialization', 'LSB first');
end

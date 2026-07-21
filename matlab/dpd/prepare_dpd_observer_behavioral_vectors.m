function metadata = prepare_dpd_observer_behavioral_vectors(varargin)
% Export a deterministic behavioral-PA feedback window for dpd_observer XSim.

  cfg.seed = 307;
  cfg.samples = 64;
  cfg.delay = 3;
  cfg.invalid_index = 17;
  cfg.input_frac = 15;
  cfg.gain_frac = 14;
  cfg.temperature_c = 42.5;
  cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'out', 'dpd', 'observer');
  for index = 1:2:numel(varargin)
    cfg.(varargin{index}) = varargin{index+1};
  end
  if ~exist(cfg.out_dir, 'dir'), mkdir(cfg.out_dir); end

  rng(cfg.seed, 'twister');
  count = cfg.samples + cfg.delay;
  raw = 0.36 * (randn(count, 1) + 1j * randn(count, 1));
  raw = filter([0.55, 0.30-0.08j, 0.10+0.04j], 1, raw);
  raw = 0.62 * raw / max(abs(raw) + eps);
  ref = quantize_complex(raw, cfg.input_frac);

  pa_in = double(ref.i(1:cfg.samples)) / 2^cfg.input_frac + ...
    1j * double(ref.q(1:cfg.samples)) / 2^cfg.input_frac;
  observed = memory_pa(pa_in);
  observed = soft_saturate(observed, 0.92, 3.0);
  observed = filter([0.92+0.00j, 0.10-0.035j, -0.025+0.018j], 1, observed);
  obs = quantize_complex(observed, cfg.input_frac);

  ref_complex = double(ref.i(1:cfg.samples)) + 1j * double(ref.q(1:cfg.samples));
  obs_complex = double(obs.i) + 1j * double(obs.q);
  gain = (obs_complex' * ref_complex) / (obs_complex' * obs_complex + eps);
  gain_re = clamp_i16(round(real(gain) * 2^cfg.gain_frac));
  gain_im = clamp_i16(round(imag(gain) * 2^cfg.gain_frac));

  aligned_i = bitsra(obs.i * int64(gain_re) - obs.q * int64(gain_im), ...
    cfg.gain_frac);
  aligned_q = bitsra(obs.i * int64(gain_im) + obs.q * int64(gain_re), ...
    cfg.gain_frac);
  invalid = false(cfg.samples, 1);
  invalid(cfg.invalid_index) = true;
  errors = abs(aligned_i - ref.i(1:cfg.samples)) + ...
    abs(aligned_q - ref.q(1:cfg.samples));
  expected_error = sum(errors(~invalid));
  expected_pairs = cfg.samples - sum(invalid);
  expected_drops = sum(invalid);
  aligned_i_q = clamp_i16(aligned_i);
  aligned_q_q = clamp_i16(aligned_q);
  valid = ~invalid;
  ref_i_valid = ref.i(1:cfg.samples);
  ref_q_valid = ref.q(1:cfg.samples);
  ref_i_valid = ref_i_valid(valid);
  ref_q_valid = ref_q_valid(valid);
  obs_i_valid = aligned_i_q(valid);
  obs_q_valid = aligned_q_q(valid);
  ref_mag = abs_s16(ref_i_valid) + abs_s16(ref_q_valid);
  obs_mag = abs_s16(obs_i_valid) + abs_s16(obs_q_valid);
  expected_ref_mag = sum(ref_mag);
  expected_obs_mag = sum(obs_mag);
  expected_peak = max(obs_mag);
  expected_clip = sum(abs_s16(obs_i_valid) >= 31130 | ...
    abs_s16(obs_q_valid) >= 31130);
  expected_saturation = sum(aligned_i(valid) > 32767 | ...
    aligned_i(valid) < -32768 | aligned_q(valid) > 32767 | ...
    aligned_q(valid) < -32768);
  expected_slew = sum(abs(diff(obs_i_valid)) + abs(diff(obs_q_valid)));
  [expected_bin0, expected_bin1, expected_bin2, expected_adj] = ...
    complex_spectral_proxies(obs_i_valid, obs_q_valid);
  temperature_q8_8 = round(cfg.temperature_c * 256);

  ref_index = (0:count-1).';
  writetable(table(ref_index, ref.i, ref.q, ...
    'VariableNames', {'n','ref_i_q1_15','ref_q_q1_15'}), ...
    fullfile(cfg.out_dir, 'dpd_observer_ref.csv'));
  obs_index = (0:cfg.samples-1).';
  writetable(table(obs_index, obs.i, obs.q, invalid, ...
    'VariableNames', {'n','obs_i_q1_15','obs_q_q1_15','invalid'}), ...
    fullfile(cfg.out_dir, 'dpd_observer_feedback.csv'));
  metadata = table(cfg.delay, gain_re, gain_im, expected_pairs, ...
    expected_drops, expected_error, cfg.samples, temperature_q8_8, ...
    expected_ref_mag, expected_obs_mag, expected_peak, expected_clip, ...
    expected_saturation, expected_slew, expected_bin0, expected_bin1, ...
    expected_bin2, expected_adj, ...
    'VariableNames', {'delay','gain_re_q2_14','gain_im_q2_14', ...
    'expected_pairs','expected_drops','expected_error_l1','feedback_samples', ...
    'temperature_q8_8','expected_ref_mag','expected_obs_mag','expected_peak', ...
    'expected_clip','expected_saturation','expected_slew','expected_spec_bin0', ...
    'expected_spec_bin1','expected_spec_bin2','expected_spec_adj'});
  writetable(metadata, fullfile(cfg.out_dir, 'dpd_observer_metadata.csv'));
end

function y = memory_pa(x)
  c1 = [1.0+0.00j; 0.04-0.015j; -0.012+0.008j];
  c3 = [-0.52+0.24j; -0.09+0.04j; 0.025-0.012j];
  c5 = [0.18-0.16j; 0.035-0.018j; -0.010+0.006j];
  y = zeros(size(x));
  for tap = 1:numel(c1)
    delayed = [zeros(tap-1, 1); x(1:end-tap+1)];
    r2 = abs(delayed).^2;
    y = y + c1(tap).*delayed + c3(tap).*delayed.*r2 + ...
      c5(tap).*delayed.*r2.^2;
  end
end

function y = soft_saturate(x, level, order)
  magnitude = abs(x);
  scale = 1 ./ ((1 + (magnitude / level).^(2*order)).^(1/(2*order)));
  y = x .* scale;
end

function q = quantize_complex(x, frac)
  q.i = clamp_i16(round(real(x(:)) * 2^frac));
  q.q = clamp_i16(round(imag(x(:)) * 2^frac));
end

function value = clamp_i16(value)
  value = int64(min(max(value, -32768), 32767));
end

function value = abs_s16(value)
  value = abs(int64(value));
  value(value == 32768) = 32767;
end

function [bin0, bin1, bin2, adj] = complex_spectral_proxies(i, q)
  i = int64(i(:));
  q = int64(q(:));
  phase = mod((0:numel(i)-1).', 4);
  bin0 = abs(sum(i)) + abs(sum(q));
  bin1_i = sum(i(phase == 0)) + sum(q(phase == 1)) - ...
    sum(i(phase == 2)) - sum(q(phase == 3));
  bin1_q = sum(q(phase == 0)) - sum(i(phase == 1)) - ...
    sum(q(phase == 2)) + sum(i(phase == 3));
  bin1 = abs(bin1_i) + abs(bin1_q);
  alternating = int64(1 - 2 * mod(phase, 2));
  bin2 = abs(sum(i .* alternating)) + abs(sum(q .* alternating));
  adj = min(bin0 + bin2, int64(2^32 - 1));
end

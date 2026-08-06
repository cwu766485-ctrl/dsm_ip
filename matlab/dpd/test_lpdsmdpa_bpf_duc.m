function Results = test_lpdsmdpa_bpf_duc()
% Verify the Fs/4 merge and sparse I/Q recovery with a coherent BB tone.
%
% This is a MATLAB behavioral unit test for the DUC/recovery convention. It
% does not exercise LPDSM2 quantization or claim circuit-level RF evidence.

  nbb = 1024;
  osr = 32;
  fs_bb = 3.125e6;
  fs = fs_bb * osr;
  fc = fs / 4;
  tone_bin = 31;
  n = (0:nbb-1).';
  x = 0.25 * exp(1j * 2*pi*tone_bin*n/nbb);
  hi = bandlimited_interpolate(x, osr);
  nh = (0:numel(hi)-1).';
  rf = real(hi .* exp(-1j * 2*pi*fc/fs*nh));
  rf = fft_bandpass(rf, fs, fc, 2.0e6);

  phase = mod(nh, 4);
  i_sparse = zeros(size(rf));
  q_sparse = zeros(size(rf));
  i_sparse(phase == 0) = rf(phase == 0);
  i_sparse(phase == 2) = -rf(phase == 2);
  q_sparse(phase == 1) = rf(phase == 1);
  q_sparse(phase == 3) = -rf(phase == 3);
  baseband = 4 * (fft_lowpass(i_sparse, fs, 2.0e6) + ...
    1j * fft_lowpass(q_sparse, fs, 2.0e6));
  recovered = baseband(1:osr:end);
  recovered = recovered(1:numel(x));
  [y, ref] = align_gain_delay(recovered, x, 4);
  evm = 100 * sqrt(mean(abs(y-ref).^2) / (mean(abs(ref).^2) + eps));

  Results = table(string("coherent_tone"), evm, string("PASS"), ...
    'VariableNames', {'Case', 'EVM_percent', 'Status'});
  assert(evm < 1e-8, 'Fs/4 DUC/recovery unit test failed: EVM=%.6g%%', evm);
end

function y = bandlimited_interpolate(x, factor)
  n = numel(x);
  X = fftshift(fft(x(:)));
  Y = zeros(n * factor, 1);
  first = floor((numel(Y) - n) / 2) + 1;
  Y(first:first+n-1) = X;
  y = ifft(ifftshift(Y)) * factor;
end

function y = fft_bandpass(x, fs, fc, bw)
  f = fft_frequency(numel(x), fs);
  y = real(ifft(fft(x(:)) .* ...
    ((abs(f-fc) <= bw/2) | (abs(f+fc) <= bw/2))));
end

function y = fft_lowpass(x, fs, bw)
  f = fft_frequency(numel(x), fs);
  y = ifft(fft(x(:)) .* (abs(f) <= bw/2));
end

function f = fft_frequency(n, fs)
  k = (0:n-1).';
  k(k >= ceil(n/2)) = k(k >= ceil(n/2)) - n;
  f = k * fs / n;
end

function [best_y, best_x] = align_gain_delay(y, x, max_delay)
  best_error = inf;
  best_y = [];
  best_x = [];
  for delay = -max_delay:max_delay
    if delay >= 0
      yy = y(1+delay:end); xx = x(1:numel(yy));
    else
      xx = x(1-delay:end); yy = y(1:numel(xx));
    end
    gain = (yy' * xx) / (yy' * yy + eps);
    yy = yy * gain;
    error = mean(abs(yy-xx).^2);
    if error < best_error
      best_error = error;
      best_y = yy;
      best_x = xx;
    end
  end
end

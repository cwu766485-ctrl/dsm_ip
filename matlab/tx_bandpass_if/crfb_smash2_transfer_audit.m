function report = crfb_smash2_transfer_audit(varargin)
% CRFB_SMASH2_TRANSFER_AUDIT Audit the two-stage SMASH equations in Xu 2025.
%
% This is a linear transfer-function audit, not a quantized RTL golden model.
% For stage i, the paper specifies
%   STF_i(z) = 1
%   NTF_i(z) = (1 + (g_i-2)z^-1 + z^-2) / (1 + (a_i+g_i-1)z^-1).
% A two-stage overall output has NTF = -NTF_1*NTF_2 and the physical PA
% combiner code is v1 = y1-y2 in {-2,0,+2}.  This function makes the
% zero/pole/stability contract executable before any fixed-point realization.

  p = inputParser;
  addParameter(p, 'fs_hz', 14e9);
  addParameter(p, 'fc_hz', [3.5e9 3.5e9]);
  addParameter(p, 'g', []);
  addParameter(p, 'a', [-1 -1]);
  addParameter(p, 'nfft', 65536);
  parse(p, varargin{:}); c = p.Results;

  a = double(c.a(:).');
  if isempty(c.g)
    fc = double(c.fc_hz(:).');
    g = 2 - 2*cos(2*pi*fc/double(c.fs_hz));
  else
    g = double(c.g(:).');
  end
  if numel(g) ~= 2 || numel(a) ~= 2
    error('This audit requires exactly two g_i and two a_i values.');
  end

  n1 = [1, g(1)-2, 1]; d1 = [1, a(1)+g(1)-1];
  n2 = [1, g(2)-2, 1]; d2 = [1, a(2)+g(2)-1];
  n = -conv(n1,n2); d = conv(d1,d2);
  z = roots(n); poles = roots(d);
  stable = all(abs(poles) < (1 - 1e-12));

  w = 2*pi*(0:floor(c.nfft/2))/c.nfft;
  h = polyval(fliplr(n), exp(-1j*w)) ./ polyval(fliplr(d), exp(-1j*w));
  [~, ix] = min(abs(w - 2*pi*double(c.fc_hz(1))/double(c.fs_hz)));
  notch_db = 20*log10(abs(h(ix)) + eps);
  dc_db = 20*log10(abs(h(1)) + eps);
  nyq_db = 20*log10(abs(h(end)) + eps);

  report = struct();
  report.STF_numerator = 1;
  report.STF_denominator = 1;
  report.NTF_numerator_zinv = n;
  report.NTF_denominator_zinv = d;
  report.g = g;
  report.a = a;
  report.zeros = z;
  report.poles = poles;
  report.stable = stable;
  report.fs_hz = c.fs_hz;
  report.fc_hz = c.fc_hz;
  report.notch_db_at_fc = notch_db;
  report.dc_db = dc_db;
  report.nyquist_db = nyq_db;
  report.pa_code_set = [-2 0 2];

  fprintf('CRFB-SMASH2 transfer audit: stable=%d, g=[%.9g %.9g], a=[%.9g %.9g]\n', ...
    stable, g(1), g(2), a(1), a(2));
  fprintf('  NTF(z^-1) numerator:'); fprintf(' %.9g', n); fprintf('\n');
  fprintf('  NTF(z^-1) denominator:'); fprintf(' %.9g', d); fprintf('\n');
  fprintf('  |NTF(Fc)|=%.2f dB, DC=%.2f dB, Nyquist=%.2f dB\n', notch_db, dc_db, nyq_db);
  if ~stable
    error('Unstable CRFB pole configuration.');
  end
end

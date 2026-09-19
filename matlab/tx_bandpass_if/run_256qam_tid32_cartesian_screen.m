function result = run_256qam_tid32_cartesian_screen(varargin)
%RUN_256QAM_TID32_CARTESIAN_SCREEN Score the new L=32 Cartesian TIDSM.
%
% The I/Q TIDSM rate is 7 GS/s.  The deterministic Fs/4 serializer expands
% it to a 14-GS/s real stream at 3.5 GHz.  OSR is reported in both equivalent
% forms: 14 GS/s/(2*occupied bandwidth) and 7 GS/s/(occupied bandwidth).

cfg.fs_iq_hz = 7e9;
cfg.fs_out_hz = 14e9;
cfg.fc_hz = 3.5e9;
cfg.bandwidth_hz = 19.65e6;
cfg.nfft = 4096;
cfg.ncp = 512;
cfg.nsym = 8;
cfg.drive = 0.35;
cfg.seed = 20260915;
cfg.max_lag = 4096;
cfg.implementation = "tid32";
for k = 1:2:numel(varargin)
    cfg.(varargin{k}) = varargin{k+1};
end

[x, actual_bw] = local_make_ofdm(cfg);
[y_i, y_q, y_rf] = local_modulate(x, cfg);
[evm, sndr] = local_score_iq(y_i, y_q, x, actual_bw, cfg);
aclr = local_score_aclr(y_rf, actual_bw, cfg);

result = table(actual_bw, cfg.fs_out_hz/(2*actual_bw), cfg.fs_iq_hz/actual_bw, ...
    evm, sndr, aclr, evm <= 3.5 && sndr >= 29.12, ...
    'VariableNames', {'OccupiedBW_Hz','OSR_real_if','OSR_iq_equivalent', ...
    'EVM_percent','SNDR_dB','ACLR_dBc','Pass256QAM'});
disp(result);
end

function [x, bw] = local_make_ofdm(c)
rng(c.seed);
df = c.fs_iq_hz / c.nfft;
nused = max(2, 2*floor(c.bandwidth_hz/(2*df)));
nused = min(nused, c.nfft/4);
bw = nused * df;
X = zeros(c.nfft, c.nsym);
idx = randi([0 255], nused, c.nsym);
q = complex(2*mod(idx,16)-15, 2*floor(idx/16)-15);
q = q / sqrt(mean(abs(q).^2, 'all'));
bins = [c.nfft/2-nused/2+1:c.nfft/2, c.nfft/2+2:c.nfft/2+1+nused/2];
X(bins,:) = q;
s = ifft(ifftshift(X,1), c.nfft, 1);
x = [s(end-c.ncp+1:end,:); s];
x = x(:);
x = c.drive * x / max(abs(x));
assert(mod(numel(x),32) == 0, 'Input length must be a multiple of 32.');
end

function [y_i, y_q, y_rf] = local_modulate(x, c)
n = numel(x);
xi = int64(round(real(x) * 32767));
xq = int64(round(imag(x) * 32767));
y_i = zeros(n,1);
y_q = zeros(n,1);
y_rf = zeros(2*n,1);
if c.implementation == "tid32"
    state = [];
    word = 0;
    for first = 1:32:n
        word = word + 1;
        [raw, state] = tid_pipelined_first_order_step(xi(first:first+31), ...
            xq(first:first+31), state, 16);
        [y_i(first:first+31), y_q(first:first+31), y_rf(2*first-1:2*(first+31))] = ...
            local_unpack_raw(raw);
    end
    assert(word == n/32, 'Unexpected word count.');
elseif c.implementation == "scalar_efm"
    v_i = int64(0); v_q = int64(0);
    for sample = 1:n
        [i_bit, v_i] = local_efm_bit(xi(sample), v_i);
        [q_bit, v_q] = local_efm_bit(xq(sample), v_q);
        y_i(sample) = 2*double(i_bit)-1;
        y_q(sample) = 2*double(q_bit)-1;
        y_rf(2*sample-1) = 2*double(i_bit)-1;
        y_rf(2*sample) = -(2*double(q_bit)-1);
    end
else
    error('Unsupported implementation: %s', c.implementation);
end
end

function [y_i, y_q, y_rf] = local_unpack_raw(raw)
l = numel(raw)/2;
y_i = zeros(l,1); y_q = zeros(l,1); y_rf = zeros(2*l,1);
for lane = 1:l
    i_bit = 2*double(raw(2*lane-1))-1;
    q_bit = 2*double(raw(2*lane))-1;
    if mod(lane-1,2) == 0
        y_i(lane) = i_bit; y_q(lane) = -q_bit;
    else
        y_i(lane) = -i_bit; y_q(lane) = q_bit;
    end
    y_rf(2*lane-1) = i_bit;
    y_rf(2*lane) = q_bit;
end
end

function [bit, v] = local_efm_bit(x, v)
u = mod(int64(x) + int64(32768), int64(65536));
v = mod(u + mod(v, int64(65536)), int64(131072));
bit = v >= 65536;
end

function [evm, sndr] = local_score_iq(y_i, y_q, x, bw, c)
n = numel(y_i);
f = ((0:n-1).'-floor(n/2)) * c.fs_iq_hz / n;
lp = abs(f) <= 0.75*bw;
z = ifft(ifftshift(fftshift(fft(y_i)).*lp)) + 1j * ...
    ifft(ifftshift(fftshift(fft(y_q)).*lp));
trim = min(c.nfft, floor(n/8));
z = z(trim+1:end-trim);
ref = x(trim+1:end-trim);
best = inf;
for lag = -c.max_lag:c.max_lag
    if lag >= 0
        zz = z(1+lag:end);
        rr = ref(1:numel(zz));
    else
        rr = ref(1-lag:end);
        zz = z(1:numel(rr));
    end
    gain = (zz' * rr) / (zz' * zz + eps);
    err = mean(abs(zz*gain - rr).^2);
    if err < best
        best = err;
        best_z = zz * gain;
        best_r = rr;
    end
end
pe = mean(abs(best_z-best_r).^2);
ps = mean(abs(best_r).^2);
evm = 100*sqrt(pe/(ps+eps));
sndr = 10*log10(ps/(pe+eps));
end

function aclr = local_score_aclr(y, bw, c)
n = numel(y);
f = ((0:n-1).'-floor(n/2)) * c.fs_out_hz / n;
p = abs(fftshift(fft(y))).^2;
main = abs(f-c.fc_hz) <= bw/2;
adj_l = abs(f-(c.fc_hz-1.5*bw)) <= bw/2;
adj_h = abs(f-(c.fc_hz+1.5*bw)) <= bw/2;
aclr = 10*log10((mean([sum(p(adj_l)), sum(p(adj_h))])+eps)/(sum(p(main))+eps));
end

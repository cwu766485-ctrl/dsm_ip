function T = run_dpd_memory_tinyml_dataset(varargin)
% Build candidate-level memory-DPD labels for leave-one-PA-profile ML tests.

  cfg = default_cfg();
  cfg = parse_kv(cfg, varargin{:});
  [~, ~, ~, trained] = run_dpd_memory_poly_training_comparison( ...
    'write_outputs', false, 'verbose', false);
  packages = make_packages(trained.memoryless.coeff_q, ...
    trained.memory_poly.coeff_q, cfg.package_count);
  profiles = build_profiles(cfg.profile_set);
  waveforms = build_waveforms();
  if cfg.write_outputs
    if ~exist(cfg.out_dir, 'dir'), mkdir(cfg.out_dir); end
    trace_path = fullfile(cfg.out_dir, [cfg.output_tag 'dpd_memory_tinyml_complex_feedback_v2.csv']);
    trace_fd = fopen(trace_path, 'w');
    if trace_fd < 0, error('Cannot create complex-feedback trace CSV.'); end
    fprintf(trace_fd, 'trace_id,n,ref_i_q1_15,ref_q_q1_15,obs_i_q1_15,obs_q_q1_15,gain_re_q2_14,gain_im_q2_14\n');
    fclose(trace_fd);
  end
  total = numel(profiles) * numel(waveforms) * numel(cfg.seeds) * cfg.package_count;
  rows = repmat(empty_row(), total, 1);
  row_index = 0;
  trace_id = 0;
  trace_manifest = repmat(struct('trace_id', NaN, 'condition_id', string(""), ...
    'monitor_schema', string(""), 'sample_count', NaN), total/cfg.package_count, 1);

  for profile_index = 1:numel(profiles)
    profile = profiles(profile_index);
    for waveform_index = 1:numel(waveforms)
      waveform = waveforms(waveform_index);
      local = configure_waveform(cfg, waveform);
      for seed = cfg.seeds(:).'
        ref = make_source(local, seed);
        rng(seed + profile_index*1000 + waveform_index*10000, 'twister');
        unit_noise = (randn(size(ref)) + 1j*randn(size(ref))) / sqrt(2);
        no_dpd = add_noise(behavioral_pa(ref, profile, local), unit_noise, ...
          profile.observation_snr_dB);
        monitor = monitor_features(ref, no_dpd, local);
        condition_id = sprintf('%s_%s_seed%d', profile.id, waveform.id, seed);
        trace_id = trace_id + 1;
        trace_manifest(trace_id).trace_id = trace_id;
        trace_manifest(trace_id).condition_id = string(condition_id);
        trace_manifest(trace_id).monitor_schema = "aligned_complex_pa_monitor_v2";
        trace_manifest(trace_id).sample_count = monitor.sample_count;
        if cfg.write_outputs
          append_complex_feedback_trace(trace_path, trace_id, ref, no_dpd, ...
            monitor.gain_re_q2_14, monitor.gain_im_q2_14, local);
        end

        for package = 0:cfg.package_count-1
          [dpd_out, sat_count] = dpd_fixed(ref, packages(package+1, :).', local);
          [pa_input, drive_count] = limit_drive(dpd_out, local.dpd_drive_limit);
          observed = add_noise(behavioral_pa(pa_input, profile, local), ...
            unit_noise, profile.observation_snr_dB);
          metrics = evaluate_metrics(ref, observed, local);
          peak = max(abs(dpd_out));
          safe = metrics.EVM_percent <= cfg.safety_evm_limit_pct && ...
            metrics.ACLR_avg_dBc <= cfg.safety_aclr_limit_dBc && ...
            sat_count == 0 && drive_count == 0 && peak <= cfg.safety_peak_limit;
          cost = round(metrics.EVM_percent * cfg.cost_evm_weight + ...
            max(metrics.ACLR_avg_dBc - cfg.cost_aclr_target_dBc, 0) * ...
            cfg.cost_aclr_weight + (sat_count + drive_count) * cfg.unsafe_cost);

          row_index = row_index + 1;
          row = empty_row();
          row.condition_id = string(condition_id);
          row.profile_id = profile.id;
          row.waveform_id = waveform.id;
          row.simulation_seed = seed;
          row.qam = waveform.qam;
          row.bandwidth_mhz = waveform.bandwidth_mhz;
          row.backoff = waveform.backoff;
          row.monitor_schema = "aligned_complex_pa_monitor_v2";
          row.monitor_trace_id = trace_id;
          row.monitor_gain_re_q2_14 = monitor.gain_re_q2_14;
          row.monitor_gain_im_q2_14 = monitor.gain_im_q2_14;
          row.monitor_sample_count = monitor.sample_count;
          row.temperature_q8_8 = round(profile.temperature_c * 256);
          row.input_power = monitor.input_power;
          row.output_power = monitor.output_power;
          row.peak = monitor.peak;
          row.avg_mag = monitor.avg_mag;
          row.evm_proxy = monitor.evm_proxy;
          row.acpr_proxy = monitor.acpr_proxy;
          row.spec_bin0 = monitor.spec_bin0;
          row.spec_bin1 = monitor.spec_bin1;
          row.spec_bin2 = monitor.spec_bin2;
          row.spec_adj = monitor.spec_adj;
          row.clip = monitor.clip;
          row.saturation = monitor.saturation;
          row.observation_error_l1 = monitor.observation_error_l1;
          row.seed_package = package;
          row.cost = cost;
          row.evm_pct = metrics.EVM_percent;
          row.aclr_dBc = metrics.ACLR_avg_dBc;
          row.dpd_peak = peak;
          row.dpd_saturation = sat_count;
          row.drive_limited = drive_count;
          row.safe = safe;
          row.candidate_count = 14;
          rows(row_index) = row;
        end
      end
    end
  end

  T = struct2table(rows);
  if cfg.write_outputs
    writetable(T, fullfile(cfg.out_dir, [cfg.output_tag 'dpd_memory_tinyml_dataset.csv']));
    TraceManifest = struct2table(trace_manifest); %#ok<NASGU>
    writetable(TraceManifest, fullfile(cfg.out_dir, ...
      [cfg.output_tag 'dpd_memory_tinyml_complex_feedback_manifest_v2.csv']));
    if cfg.export_package_header
      export_package_header(cfg.package_header_path, packages, cfg.profile_set);
    end
    save(fullfile(cfg.out_dir, [cfg.output_tag 'dpd_memory_tinyml_dataset.mat']), ...
      'T', 'cfg', 'profiles', 'waveforms', 'packages', 'TraceManifest');
  end
  if cfg.verbose
    fprintf('Memory TinyML dataset: %d candidate rows, %d conditions\n', ...
      height(T), height(T)/cfg.package_count);
  end
end

function cfg = default_cfg()
  root = fileparts(fileparts(mfilename('fullpath')));
  cfg.out_dir = fullfile(root, 'out', 'dpd');
  cfg.profile_set = 'training';
  cfg.output_tag = '';
  cfg.package_header_path = fullfile(root, 'fpga', 'zu15eg', ...
    'baremetal', 'src', 'dpd_tinyml_packages_v2.h');
  cfg.export_package_header = true;
  cfg.seeds = [41, 53, 67];
  cfg.nsym = 4;
  cfg.package_count = 6;
  cfg.input_w = 16;
  cfg.input_frac = 15;
  cfg.coeff_frac = 14;
  cfg.dpd_drive_limit = 0.92;
  cfg.safety_evm_limit_pct = 10.0;
  cfg.safety_aclr_limit_dBc = -20.0;
  cfg.safety_peak_limit = 0.92;
  cfg.cost_evm_weight = 10000;
  cfg.cost_aclr_target_dBc = -32.5;
  cfg.cost_aclr_weight = 5000;
  cfg.unsafe_cost = 1e9;
  cfg.write_outputs = true;
  cfg.verbose = true;
end

function profiles = build_profiles(profile_set)
  if strcmp(profile_set, 'training')
    profiles = [ ...
    profile('baseline', 1.00, 0.92, 3, 43, 1800, 1.8, 0.45, 25), ...
    profile('gain_mid_low', 0.91, 0.92, 3, 43, 1800, 1.8, 0.45, 25), ...
    profile('gain_low', 0.82, 0.92, 3, 43, 1800, 1.8, 0.45, 25), ...
    profile('gain_high', 1.08, 0.92, 3, 43, 1800, 1.8, 0.45, 25), ...
    profile('sat_mid', 1.00, 0.82, 3, 43, 1800, 1.8, 0.45, 25), ...
    profile('sat_early', 1.00, 0.72, 3, 43, 1800, 1.8, 0.45, 25), ...
    profile('memory_short', 1.00, 0.92, 1, 43, 1800, 1.8, 0.45, 25), ...
    profile('noise_mid', 1.00, 0.92, 3, 36, 1800, 1.8, 0.45, 25), ...
    profile('noise_high', 1.00, 0.92, 3, 28, 1800, 1.8, 0.45, 25), ...
    profile('thermal_mild', 1.00, 0.92, 3, 43, 4000, 3.5, 0.90, 55), ...
    profile('thermal_drift', 1.00, 0.92, 3, 43, 8000, 6.0, 1.50, 85), ...
    profile('combined_stress', 0.82, 0.72, 3, 28, 8000, 6.0, 1.50, 85)];
  elseif strcmp(profile_set, 'blind')
    % These profiles are held out from fitting, threshold selection, and model choice.
    profiles = [ ...
      profile('blind_gain_memory', 0.96, 0.86, 2, 39, 5200, 4.4, 1.10, 65), ...
      profile('blind_compression_noise', 1.13, 0.77, 3, 32, 3500, 2.9, 0.80, 40), ...
      profile('blind_thermal_memory', 0.88, 0.80, 2, 35, 10500, 7.2, 1.80, 72)];
  elseif strcmp(profile_set, 'development')
    % Development-only profiles may be used for fitting and model selection.
    % Keep the three blind_* profiles permanently excluded from this set.
    profiles = [ ...
      profile('dev_gain_comp_memory', 1.04, 0.84, 2, 37, 2400, 2.5, 0.65, 33), ...
      profile('dev_low_gain_noisy', 0.87, 0.88, 1, 31, 5600, 4.9, 0.75, 48), ...
      profile('dev_deep_memory_cool', 0.98, 0.90, 3, 45, 6500, 5.1, 1.25, 15), ...
      profile('dev_hot_softsat', 0.93, 0.76, 3, 34, 7200, 5.8, 1.35, 68), ...
      profile('dev_high_gain_thermal', 1.11, 0.89, 2, 41, 9000, 6.6, 1.55, 78), ...
      profile('dev_low_sat_quiet', 1.02, 0.74, 1, 46, 1500, 1.2, 0.35, 30), ...
      profile('dev_combined_noise', 0.85, 0.79, 3, 29, 11000, 7.6, 1.90, 82), ...
      profile('dev_mid_gain_memory', 1.06, 0.83, 2, 38, 4500, 3.7, 0.95, 58)];
  else
    error('Unknown profile_set: %s', profile_set);
  end
end

function value = profile(id, gain, sat, taps, snr, gain_drift, phase, ripple, temp)
  value = struct('id', string(id), 'gain_scale', gain, 'sat_level', sat, ...
    'memory_taps', taps, 'observation_snr_dB', snr, ...
    'gain_drift_ppm', gain_drift, 'phase_drift_deg', phase, ...
    'phase_ripple_deg', ripple, 'temperature_c', temp);
end

function waveforms = build_waveforms()
  index = 0;
  for qam = [16, 64]
    for bandwidth = [20, 40]
      for backoff = [0.58, 0.70]
        index = index + 1;
        waveforms(index) = struct('id', string(sprintf('qam%d_bw%d_bo%03d', ...
          qam, bandwidth, round(backoff*100))), 'qam', qam, ...
          'bandwidth_mhz', bandwidth, 'backoff', backoff); %#ok<AGROW>
      end
    end
  end
end

function cfg = configure_waveform(cfg, waveform)
  cfg.qam = waveform.qam;
  cfg.bandwidth_mhz = waveform.bandwidth_mhz;
  cfg.input_backoff = waveform.backoff;
  cfg.nfft = 256;
  cfg.ncp = 32;
  cfg.nused = 48;
  cfg.fs_hz = 100e6;
  if waveform.bandwidth_mhz == 40
    cfg.nfft = 512;
    cfg.ncp = 64;
    cfg.nused = 96;
    cfg.fs_hz = 200e6;
  end
  cfg.channel_bw_hz = 1.10 * cfg.fs_hz * cfg.nused / cfg.nfft;
  cfg.adjacent_offset_hz = 1.20 * cfg.channel_bw_hz;
end

function packages = make_packages(memoryless, memory_poly, count)
  baseline = complex(zeros(12, 1));
  baseline(1:3) = memoryless(:);
  target = memory_poly(:);
  packages = complex(zeros(count, 12));
  for index = 1:count
    alpha = 5 * (index - 1);
    candidate = round(baseline + alpha * (target - baseline));
    packages(index, :) = complex( ...
      min(max(real(candidate), -32768), 32767), ...
      min(max(imag(candidate), -32768), 32767));
  end
end

function x = make_source(cfg, seed)
  rng(seed, 'twister');
  used = [(cfg.nfft/2-cfg.nused/2+1):(cfg.nfft/2), ...
          (cfg.nfft/2+2):(cfg.nfft/2+1+cfg.nused/2)];
  bins = zeros(cfg.nfft, cfg.nsym);
  indices = randi([0 cfg.qam-1], numel(used), cfg.nsym);
  side = sqrt(cfg.qam);
  symbols = complex(2*mod(indices, side)-(side-1), ...
    2*floor(indices/side)-(side-1));
  symbols = symbols / sqrt(mean(abs(symbols(:)).^2));
  bins(used, :) = symbols;
  td = ifft(ifftshift(bins, 1), cfg.nfft, 1);
  x = [td(end-cfg.ncp+1:end, :); td];
  x = x(:);
  x = cfg.input_backoff * x / max(abs(x)+eps);
  q = quantize(x, cfg.input_frac);
  x = double(q.i)/2^cfg.input_frac + 1j*double(q.q)/2^cfg.input_frac;
end

function y = behavioral_pa(x, p, cfg)
  c1 = [1.0+0.00j; 0.04-0.015j; -0.012+0.008j] * p.gain_scale;
  c3 = [-0.52+0.24j; -0.09+0.04j; 0.025-0.012j];
  c5 = [0.18-0.16j; 0.035-0.018j; -0.010+0.006j];
  taps = min(p.memory_taps, numel(c1));
  y = zeros(size(x));
  for tap = 1:taps
    delayed = [zeros(tap-1,1); x(1:end-tap+1)];
    r2 = abs(delayed).^2;
    y = y + c1(tap).*delayed + c3(tap).*delayed.*r2 + c5(tap).*delayed.*r2.^2;
  end
  magnitude = abs(y);
  y = y ./ ((1+(magnitude/p.sat_level).^6).^(1/6));
  y = filter([0.92+0j, 0.10-0.035j, -0.025+0.018j], 1, y);
  n = (0:numel(y)-1).';
  time = n/max(numel(y)-1,1);
  gain = 1 + p.gain_drift_ppm*1e-6*(2*time-1);
  phase = deg2rad(p.phase_drift_deg*(2*time-1) + ...
    p.phase_ripple_deg*sin(2*pi*3*time));
  y = y .* gain .* exp(1j*phase);
end

function y = add_noise(clean, unit, snr)
  y = clean + sqrt(mean(abs(clean).^2)/10^(snr/10)) * unit;
end

function [y, sat_count] = dpd_fixed(x, coeff, cfg)
  q = quantize(x, cfg.input_frac);
  acc_i = zeros(numel(x),1,'int64');
  acc_q = zeros(numel(x),1,'int64');
  for tap = 1:4
    delay = tap-1;
    ii = [zeros(delay,1,'int64'); q.i(1:end-delay)];
    qq = [zeros(delay,1,'int64'); q.q(1:end-delay)];
    base = delay*3;
    r2 = bitsra(ii.*ii+qq.*qq,cfg.input_frac);
    r4 = bitsra(r2.*r2,cfg.input_frac);
    gr = int64(real(coeff(base+1))) + bitsra(int64(real(coeff(base+2))).*r2,cfg.input_frac) + bitsra(int64(real(coeff(base+3))).*r4,cfg.input_frac);
    gi = int64(imag(coeff(base+1))) + bitsra(int64(imag(coeff(base+2))).*r2,cfg.input_frac) + bitsra(int64(imag(coeff(base+3))).*r4,cfg.input_frac);
    acc_i = acc_i + bitsra(ii.*gr-qq.*gi,cfg.coeff_frac);
    acc_q = acc_q + bitsra(ii.*gi+qq.*gr,cfg.coeff_frac);
  end
  sat = acc_i > 32767 | acc_i < -32768 | acc_q > 32767 | acc_q < -32768;
  yi = min(max(acc_i,-32768),32767);
  yq = min(max(acc_q,-32768),32767);
  sat_count = sum(sat);
  y = double(yi)/2^cfg.input_frac + 1j*double(yq)/2^cfg.input_frac;
end

function q = quantize(x, frac)
  q.i = int64(min(max(round(real(x(:))*2^frac),-32768),32767));
  q.q = int64(min(max(round(imag(x(:))*2^frac),-32768),32767));
end

function [y,count] = limit_drive(x, limit)
  select = abs(x)>limit;
  y=x; y(select)=x(select).*limit./abs(x(select)); count=sum(select);
end

function m = evaluate_metrics(ref,y,cfg)
  [ya,xa]=align(y,ref,16); e=ya-xa; ps=mean(abs(xa).^2); pe=mean(abs(e).^2);
  m.EVM_percent=100*sqrt((pe+eps)/(ps+eps));
  a=aclr(ya,cfg.fs_hz,cfg.channel_bw_hz,cfg.adjacent_offset_hz);
  m.ACLR_avg_dBc=mean(a);
end

function [by,bx]=align(y,x,max_delay)
  best=inf; by=[]; bx=[];
  for d=-max_delay:max_delay
    if d>=0, yy=y(1+d:end); xx=x(1:min(numel(x),numel(yy))); yy=yy(1:numel(xx));
    else, xx=x(1-d:end); yy=y(1:min(numel(y),numel(xx))); xx=xx(1:numel(yy)); end
    yy=yy*((yy'*xx)/(yy'*yy+eps)); value=mean(abs(yy-xx).^2);
    if value<best, best=value; by=yy; bx=xx; end
  end
end

function values=aclr(y,fs,bw,offset)
  nfft=2048; n=min(1024,numel(y)); w=0.5-0.5*cos(2*pi*(0:n-1)'/max(n-1,1));
  spectrum=abs(fftshift(fft(y(1:n).*w,nfft))).^2;
  f=((0:nfft-1)'-nfft/2)/nfft*fs; main=abs(f)<=bw/2;
  left=f>=-offset-bw/2 & f<=-offset+bw/2; right=f>=offset-bw/2 & f<=offset+bw/2;
  p=sum(spectrum(main))+eps; values=[10*log10((sum(spectrum(left))+eps)/p),10*log10((sum(spectrum(right))+eps)/p)];
end

function m = monitor_features(ref, observed, cfg)
  rq = quantize(ref, cfg.input_frac);
  oq = quantize(observed, cfg.input_frac);
  ref_complex = double(rq.i) + 1j * double(rq.q);
  obs_complex = double(oq.i) + 1j * double(oq.q);
  gain = (obs_complex' * ref_complex) / (obs_complex' * obs_complex + eps);
  gain_re = clamp_i16(round(real(gain) * 2^cfg.coeff_frac));
  gain_im = clamp_i16(round(imag(gain) * 2^cfg.coeff_frac));

  aligned_i_wide = bitsra(oq.i * gain_re - oq.q * gain_im, cfg.coeff_frac);
  aligned_q_wide = bitsra(oq.i * gain_im + oq.q * gain_re, cfg.coeff_frac);
  aligned_i = clamp_i16(aligned_i_wide);
  aligned_q = clamp_i16(aligned_q_wide);
  ref_mag = abs_s16(rq.i) + abs_s16(rq.q);
  obs_mag = abs_s16(aligned_i) + abs_s16(aligned_q);
  error_l1 = sum(abs(aligned_i_wide - rq.i) + abs(aligned_q_wide - rq.q));

  m.gain_re_q2_14 = double(gain_re);
  m.gain_im_q2_14 = double(gain_im);
  m.sample_count = numel(aligned_i);
  m.input_power = u32_wrap(sum(ref_mag));
  m.output_power = u32_wrap(sum(obs_mag));
  m.peak = double(max(obs_mag));
  m.avg_mag = floor(m.output_power / max(m.sample_count, 1));
  m.evm_proxy = u32_wrap(error_l1);
  m.observation_error_l1 = double(error_l1);
  m.acpr_proxy = u32_wrap(sum(abs(diff(aligned_i)) + abs(diff(aligned_q))));
  [m.spec_bin0, m.spec_bin1, m.spec_bin2, m.spec_adj] = ...
    complex_spectral_proxies_v2(aligned_i, aligned_q);
  m.clip = sum(abs_s16(aligned_i) >= 31130 | abs_s16(aligned_q) >= 31130);
  m.saturation = sum(aligned_i_wide > 32767 | aligned_i_wide < -32768 | ...
    aligned_q_wide > 32767 | aligned_q_wide < -32768);
end

function row=empty_row()
  row=struct('condition_id',string(""),'profile_id',string(""),'waveform_id',string(""),'simulation_seed',NaN,'qam',NaN,'bandwidth_mhz',NaN,'backoff',NaN,'monitor_schema',string(""),'monitor_trace_id',NaN,'monitor_gain_re_q2_14',NaN,'monitor_gain_im_q2_14',NaN,'monitor_sample_count',NaN,'temperature_q8_8',NaN,'input_power',NaN,'output_power',NaN,'peak',NaN,'avg_mag',NaN,'evm_proxy',NaN,'acpr_proxy',NaN,'spec_bin0',NaN,'spec_bin1',NaN,'spec_bin2',NaN,'spec_adj',NaN,'clip',NaN,'saturation',NaN,'observation_error_l1',NaN,'seed_package',NaN,'cost',NaN,'evm_pct',NaN,'aclr_dBc',NaN,'dpd_peak',NaN,'dpd_saturation',NaN,'drive_limited',NaN,'safe',false,'candidate_count',NaN);
end

function append_complex_feedback_trace(path, trace_id, ref, observed, gain_re, gain_im, cfg)
  rq = quantize(ref, cfg.input_frac);
  oq = quantize(observed, cfg.input_frac);
  count = numel(rq.i);
  values = [repmat(trace_id, count, 1), (0:count-1).', rq.i, rq.q, ...
    oq.i, oq.q, repmat(gain_re, count, 1), repmat(gain_im, count, 1)];
  writematrix(values, path, 'WriteMode', 'append');
end

function export_package_header(path, packages, profile_set)
  [folder, ~, ~] = fileparts(path);
  if ~exist(folder, 'dir'), mkdir(folder); end
  fd = fopen(path, 'w');
  if fd < 0, error('Cannot create TinyML package header.'); end
  fprintf(fd, '#ifndef DPD_TINYML_PACKAGES_V2_H\n');
  fprintf(fd, '#define DPD_TINYML_PACKAGES_V2_H\n\n');
  fprintf(fd, '#include "xil_types.h"\n\n');
  fprintf(fd, '/* Generated by run_dpd_memory_tinyml_dataset.m; do not edit. */\n');
  fprintf(fd, '/* Package table is trained against profile set: %s. */\n', profile_set);
  fprintf(fd, '#define DPD_TINYML_PACKAGE_TABLE_V2_AVAILABLE 1U\n');
  fprintf(fd, '#define DPD_TINYML_PACKAGE_TABLE_V2_COUNT %dU\n', size(packages, 1));
  fprintf(fd, '#define DPD_TINYML_PACKAGE_TABLE_V2_TAPS 4U\n');
  fprintf(fd, '#define DPD_TINYML_PACKAGE_TABLE_V2_ORDERS 3U\n\n');
  fprintf(fd, 'static const u32 dsm_dpd_tinyml_mp_packages[DPD_TINYML_PACKAGE_TABLE_V2_COUNT][12] = {\n');
  for package = 1:size(packages, 1)
    fprintf(fd, '    {');
    for coefficient = 1:12
      value = packages(package, coefficient);
      real_word = uint16(mod(round(real(value)), 65536));
      imag_word = uint16(mod(round(imag(value)), 65536));
      word = bitor(bitshift(uint32(imag_word), 16), uint32(real_word));
      if coefficient > 1, fprintf(fd, ', '); end
      fprintf(fd, '0x%08XU', word);
    end
    if package < size(packages, 1)
      fprintf(fd, '},\n');
    else
      fprintf(fd, '}\n');
    end
  end
  fprintf(fd, '};\n\n#endif /* DPD_TINYML_PACKAGES_V2_H */\n');
  fclose(fd);
end

function value = clamp_i16(value)
  value = int64(min(max(value, -32768), 32767));
end

function value = abs_s16(value)
  value = abs(int64(value));
  value(value == 32768) = 32767;
end

function value = u32_wrap(value)
  value = double(mod(int64(value), int64(4294967296)));
end

function [bin0, bin1, bin2, adj] = complex_spectral_proxies_v2(i, q)
  i = int64(i(:));
  q = int64(q(:));
  phase = mod((0:numel(i)-1).', 4);
  bin0_i = signed32_wrap(sum(i));
  bin0_q = signed32_wrap(sum(q));
  bin1_i = signed32_wrap(sum(i(phase == 0)) + sum(q(phase == 1)) - ...
    sum(i(phase == 2)) - sum(q(phase == 3)));
  bin1_q = signed32_wrap(sum(q(phase == 0)) - sum(i(phase == 1)) - ...
    sum(q(phase == 2)) + sum(i(phase == 3)));
  alternating = int64(1 - 2 * mod(phase, 2));
  bin2_i = signed32_wrap(sum(i .* alternating));
  bin2_q = signed32_wrap(sum(q .* alternating));
  bin0 = double(abs_s32(bin0_i) + abs_s32(bin0_q));
  bin1 = double(abs_s32(bin1_i) + abs_s32(bin1_q));
  bin2 = double(abs_s32(bin2_i) + abs_s32(bin2_q));
  bin0 = min(bin0, 2^32-1);
  bin1 = min(bin1, 2^32-1);
  bin2 = min(bin2, 2^32-1);
  adj = min(bin0 + bin2, 2^32-1);
end

function value = signed32_wrap(value)
  value = int64(mod(value + int64(2147483648), int64(4294967296)) - ...
    int64(2147483648));
end

function value = abs_s32(value)
  if value == -int64(2147483648)
    value = int64(2147483647);
  else
    value = abs(value);
  end
end

function cfg=parse_kv(cfg,varargin)
  if mod(numel(varargin),2)~=0,error('Arguments must be key/value pairs.');end
  for k=1:2:numel(varargin),if ~isfield(cfg,varargin{k}),error('Unknown option: %s',varargin{k});end;cfg.(varargin{k})=varargin{k+1};end
end

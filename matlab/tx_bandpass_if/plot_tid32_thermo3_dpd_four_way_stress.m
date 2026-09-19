function Files = plot_tid32_thermo3_dpd_four_way_stress(varargin)
%PLOT_TID32_THERMO3_DPD_FOUR_WAY_STRESS Fair diagnostic DPD comparison.
% Compare no DPD, memoryless polynomial, LUT and four-tap memory polynomial
% under one intentionally strong, parameterized switching-DPA profile.
% This is an algorithm/model comparison: only the four-tap memory-polynomial
% path is currently connected to the vector16 thermo3 RTL frontend.  The
% other candidates reproduce their public DPD arithmetic at behavioral level
% and must not be treated as RTL/FPGA deployment evidence.

cfg.out_dir=fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'out','tid32_thermo3_dpd_four_way_stress');
cfg.bandwidth_hz=17.09e6;
cfg.fit_nsym=6; cfg.val_nsym=5; cfg.test_nsym=6;
for k=1:2:numel(varargin), cfg.(varargin{k})=varargin{k+1}; end
if ~exist(cfg.out_dir,'dir'), mkdir(cfg.out_dir); end

% Synthetic stress only: it deliberately exaggerates AM-AM, AM-PM, branch
% mismatch and memory so that candidate differences are visible.  It is not
% an ADS or measured PA model and is exported with every result.
common={ ...
  'bandwidth_hz',cfg.bandwidth_hz, ...
  'fit_nsym',cfg.fit_nsym,'val_nsym',cfg.val_nsym,'test_nsym',cfg.test_nsym, ...
  'write_outputs',false, ...
  'pa_profile',"synthetic_dpa_memory_stress_v1", ...
  'drive',0.40, ...
  'pa_p_gain',1.065,'pa_m_gain',0.935, ...
  'pa_p_fir',[0.84 0.20 -0.07],'pa_m_fir',[0.80 0.23 -0.08], ...
  'pa_p_thermal_alpha',0.965,'pa_m_thermal_alpha',0.945, ...
  'pa_p_amam',0.34,'pa_m_amam',0.30, ...
  'pa_p_switch_asym',0.055,'pa_m_switch_asym',-0.045, ...
  'pa_p_ampm_rad',0.32,'pa_m_ampm_rad',-0.27, ...
  'bpf_q',80,'bpf_insertion_loss_db',1.0};

[R0,~,D0]=run_tid32_thermo3_frontend_pa_dpd(common{:},'enable_dpd_training',false);
[Rm,~,Dm]=run_tid32_thermo3_frontend_pa_dpd(common{:},'enable_dpd_training',true, ...
    'dpd_candidate_kind',"memoryless_poly",'dpd_active_taps',1);
[Rl,~,Dl]=run_tid32_thermo3_frontend_pa_dpd(common{:},'enable_dpd_training',true, ...
    'dpd_candidate_kind',"lut",'dpd_active_taps',4);
[R4,~,D4]=run_tid32_thermo3_frontend_pa_dpd(common{:},'enable_dpd_training',true, ...
    'dpd_candidate_kind',"memory_poly",'dpd_active_taps',4);

labels=["No DPD / identity";"Memoryless poly (1/3/5)";"LUT DPD (16-bin)";"4-tap memory-poly (1/3/5)"];
endpoint={D0.endpoints.identity_untrained; ...
          Dm.endpoints.diagnostic_candidate_memoryless_poly; ...
          Dl.endpoints.diagnostic_candidate_lut; ...
          D4.endpoints.diagnostic_candidate_memory_poly};
Results=[R0(1,:);Rm(2,:);Rl(2,:);R4(2,:)];
Results.Mode=labels;
Results.CandidateOnly=repmat(true,height(Results),1); Results.CandidateOnly(1)=false;

ref=endpoint{1}.reference(:); fs=14e9; fc=3.5e9;
guard_rf=8*8*64; first=guard_rf+1; last=guard_rf+8*numel(ref);
f=local_freq(8*numel(ref),fs)/1e9;
pa_in=zeros(numel(f),4); pa_out=pa_in; bpf_out=pa_in;
for k=1:4
  pa_in(:,k)=local_psd(endpoint{k}.rf_pa_input(first:last));
  pa_out(:,k)=local_psd(endpoint{k}.rf_pre_bpf(first:last));
  bpf_out(:,k)=local_psd(endpoint{k}.rf(first:last));
end

colors=lines(4);
fig=figure('Visible','off','Color','w','Position',[80 80 1420 930]);
tiledlayout(3,2,'Padding','compact','TileSpacing','compact');
nexttile; local_plot_four(f,pa_in,colors,labels); xlim([3.0 4.0]); ylim([-105 5]);
title('PA input: combined thermometric switching waveform');
nexttile; local_plot_four(f,pa_out,colors,labels); xlim([3.0 4.0]); ylim([-105 5]);
title('PA output: before BPF'); legend(labels,'Location','southwest','FontSize',8);
nexttile; local_plot_four(f,bpf_out,colors,labels); xlim([3.0 4.0]); ylim([-105 5]);
title('BPF output: 3.5-GHz RF band');
nexttile; local_plot_four(f,bpf_out,colors,labels); xlim([3.40 3.60]); ylim([-90 5]);
title('BPF output: in-band / adjacent detail');
nexttile; bar(categorical(labels),[Results.EVM_percent Results.SNDR_dB]); grid on;
ylabel('Value'); legend('EVM (%)','SNDR (dB)','Location','best'); xtickangle(18); title('Held-out OFDM metrics');
nexttile; bar(categorical(labels),[Results.PA_ACLR_dBc Results.Filtered_ACLR_dBc]); grid on;
ylabel('dBc'); legend('PA-side ACLR','BPF-side ACLR','Location','best'); xtickangle(18); title('Model-only ACLR');
sgtitle(sprintf('Thermo3 14-GS/s chain, %.6f MHz, synthetic memory-stress profile',cfg.bandwidth_hz/1e6));
Files.png=fullfile(cfg.out_dir,'tid32_thermo3_dpd_four_way_stress.png');
Files.pdf=fullfile(cfg.out_dir,'tid32_thermo3_dpd_four_way_stress.pdf');
Files.metrics_csv=fullfile(cfg.out_dir,'tid32_thermo3_dpd_four_way_stress_metrics.csv');
Files.psd_csv=fullfile(cfg.out_dir,'tid32_thermo3_dpd_four_way_stress_psd.csv');
Files.profile_csv=fullfile(cfg.out_dir,'tid32_thermo3_dpd_four_way_stress_profile.csv');
exportgraphics(fig,Files.png,'Resolution',180); exportgraphics(fig,Files.pdf,'ContentType','vector'); close(fig);
writetable(Results,Files.metrics_csv);
writetable(table(f,pa_in(:,1),pa_in(:,2),pa_in(:,3),pa_in(:,4),pa_out(:,1),pa_out(:,2),pa_out(:,3),pa_out(:,4), ...
    bpf_out(:,1),bpf_out(:,2),bpf_out(:,3),bpf_out(:,4), ...
    'VariableNames',{'Frequency_GHz','PAInput_Identity_dB','PAInput_Poly_dB','PAInput_LUT_dB','PAInput_MemoryPoly_dB', ...
    'PAOutput_Identity_dB','PAOutput_Poly_dB','PAOutput_LUT_dB','PAOutput_MemoryPoly_dB', ...
    'BPFOutput_Identity_dB','BPFOutput_Poly_dB','BPFOutput_LUT_dB','BPFOutput_MemoryPoly_dB'}),Files.psd_csv);
writetable(D4.pa_profile,Files.profile_csv);
end

function local_plot_four(f,p,c,labels)
hold on; for k=1:4, plot(f,p(:,k),'Color',c(k,:),'LineWidth',0.8); end; grid on;
xlabel('Frequency (GHz)'); ylabel('Normalized PSD (dB)');
end
function f=local_freq(n,fs), k=(0:n-1).'; k(k>=ceil(n/2))=k(k>=ceil(n/2))-n; f=k*fs/n; end
function p=local_psd(x), a=fftshift(fft(x(:))); p=20*log10(abs(a)/(max(abs(a))+eps)+eps); end

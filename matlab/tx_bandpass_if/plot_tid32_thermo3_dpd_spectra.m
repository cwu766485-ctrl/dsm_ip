function Files = plot_tid32_thermo3_dpd_spectra(varargin)
%PLOT_TID32_THERMO3_DPD_SPECTRA Auditable spectrum/EVM comparison.
% The diagnostic DPD candidate may be rejected for deployment.  This plot
% compares it transparently against identity deployment and an ideal linear
% upconversion reference; it does not claim a behavioral PA is hardware.

cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))),'out','tid32_thermo3_dpd_figures');
cfg.bandwidth_hz = 17.09e6;
for k=1:2:numel(varargin), cfg.(varargin{k})=varargin{k+1}; end
if ~exist(cfg.out_dir,'dir'), mkdir(cfg.out_dir); end

[R,~,D] = run_tid32_thermo3_frontend_pa_dpd( ...
    'bandwidth_hz',cfg.bandwidth_hz,'enable_dpd_training',true, ...
    'fit_nsym',12,'val_nsym',10,'test_nsym',12,'write_outputs',false);
id = D.endpoints.identity;
cand = D.endpoints.diagnostic_candidate_q214_memory_poly;
fs=14e9; fc=3.5e9; ref=id.reference(:); n=(0:8*numel(ref)-1).';
ideal=real(interpft(ref,8*numel(ref)).*exp(1j*2*pi*fc/fs*n));
% local_endpoint_ofdm retains 512 ingress-sample guards in RF but returns
% only the useful reference frame.  Crop both PA endpoints to that frame.
guard_rf=8*8*64; first=guard_rf+1; last=guard_rf+numel(ideal);
rf_id=id.rf(first:last); rf_cand=cand.rf(first:last);

f=local_freq(numel(rf_id),fs)/1e9;
[pid,pid_norm]=local_psd(rf_id,fs); [pc,pc_norm]=local_psd(rf_cand,fs); [pideal,pideal_norm]=local_psd(ideal,fs);
fig=figure('Visible','off','Color','w','Position',[100 100 1200 760]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
nexttile; plot(f,pideal,'k--','LineWidth',1.1); hold on; plot(f,pid,'b'); plot(f,pc,'r');
xlim([3.0 4.0]); ylim([-110 5]); grid on; xlabel('Frequency (GHz)'); ylabel('Normalized PSD (dB)');
legend('Ideal linear reference','Identity DPD','Diagnostic memory-DPD','Location','southwest');
title('3.5-GHz RF-band spectrum');
nexttile; plot(f,pid,'b'); hold on; plot(f,pc,'r'); xlim([3.35 3.65]); ylim([-90 5]); grid on;
xlabel('Frequency (GHz)'); ylabel('Normalized PSD (dB)'); title('In-band and adjacent-noise detail'); legend('Identity','Diagnostic candidate');
nexttile; bar(categorical(R.Mode),[R.EVM_percent R.SNDR_dB]); grid on; ylabel('Value'); legend('EVM (%)','SNDR (dB)','Location','best'); title('Held-out OFDM metrics');
nexttile; bar(categorical(R.Mode),[R.PA_ACLR_dBc R.Filtered_ACLR_dBc]); grid on; ylabel('dBc'); legend('PA-side ACLR','BPF-side ACLR','Location','best'); title('Model-only ACLR');
sgtitle(sprintf('TID32 thermo3, %.6f MHz, candidate deployment=%d',cfg.bandwidth_hz/1e6,any(R.HeldOutDeploymentAccepted)));
Files.png=fullfile(cfg.out_dir,'tid32_thermo3_dpd_spectrum_comparison.png');
Files.pdf=fullfile(cfg.out_dir,'tid32_thermo3_dpd_spectrum_comparison.pdf');
exportgraphics(fig,Files.png,'Resolution',180); exportgraphics(fig,Files.pdf,'ContentType','vector'); close(fig);
writetable(R,fullfile(cfg.out_dir,'tid32_thermo3_dpd_spectrum_metrics.csv'));
local_write_psd(fullfile(cfg.out_dir,'tid32_thermo3_dpd_spectrum_psd.csv'),f,pid,pc,pideal);
end

function f=local_freq(n,fs), k=(0:n-1).'; k(k>=ceil(n/2))=k(k>=ceil(n/2))-n; f=k*fs/n; end
function [p,pnorm]=local_psd(x,~), p=20*log10(abs(fftshift(fft(x(:))))/max(abs(fft(x(:))))+eps); pnorm=p; end
function local_write_psd(name,f,a,b,c), writetable(table(f,a,b,c,'VariableNames',{'Frequency_GHz','Identity_dB','Candidate_dB','Ideal_dB'}),name); end

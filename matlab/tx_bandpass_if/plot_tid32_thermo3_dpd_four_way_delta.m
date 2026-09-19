function Files = plot_tid32_thermo3_dpd_four_way_delta(varargin)
%PLOT_TID32_THERMO3_DPD_FOUR_WAY_DELTA Make DPD spectral deltas readable.
% Read the reproducible four-way stress result rather than rerunning it.
% PSD is smoothed only for display.  A negative delta means lower normalized
% emission than identity at that frequency; ACLR/EVM/SNDR remain the scored
% quantities from the unsmoothed waveform.

root=fullfile(fileparts(fileparts(mfilename('fullpath'))),'out','tid32_thermo3_dpd_four_way_stress');
cfg.in_dir=root; cfg.out_dir=root; cfg.smooth_bins=65;
for k=1:2:numel(varargin), cfg.(varargin{k})=varargin{k+1}; end
if ~exist(cfg.out_dir,'dir'), mkdir(cfg.out_dir); end
psd=readtable(fullfile(cfg.in_dir,'tid32_thermo3_dpd_four_way_stress_psd.csv'));
metric=readtable(fullfile(cfg.in_dir,'tid32_thermo3_dpd_four_way_stress_metrics.csv'));
f=psd.Frequency_GHz;
names=["No DPD / identity","Memoryless poly (1/3/5)","LUT DPD (16-bin)","4-tap memory-poly (1/3/5)"];
cols={'BPFOutput_Identity_dB','BPFOutput_Poly_dB','BPFOutput_LUT_dB','BPFOutput_MemoryPoly_dB'};
p=zeros(height(psd),4); for k=1:4, p(:,k)=movmean(psd.(cols{k}),cfg.smooth_bins); end
delta=p-p(:,1);
colors=[0.000 0.447 0.741; 0.850 0.325 0.098; 0.929 0.694 0.125; 0.494 0.184 0.556];

fig=figure('Visible','off','Color','w','Position',[60 40 1660 930]);
tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
nexttile; local_lines(f,p,colors,names); xlim([3.40 3.60]); ylim([-80 2]);
title('BPF: all four absolute spectra (smoothed for display)'); legend(names,'Location','southwest','FontSize',8);
% Do not put three small effects and the failed LUT on the same axis: it
% makes the potentially useful curves invisible.  Each panel answers one
% precise question: did this DPD lower the BPF-side emission vs no DPD?
for k=2:4
    nexttile; plot(f,delta(:,k),'Color',colors(k,:),'LineWidth',1.05); yline(0,'k:'); grid on;
    xlim([3.40 3.60]); xlabel('Frequency (GHz)'); ylabel('\DeltaPSD vs identity (dB)');
    if k==4, ylim([-10 10]); else, ylim([-3 3]); end
    title(sprintf('%s: below 0 dB is better',names(k)));
end
nexttile; bar(categorical(metric.Mode),[metric.EVM_percent metric.SNDR_dB]); grid on; ylabel('Value');
legend('EVM (%)','SNDR (dB)','Location','best'); xtickangle(18); title('Held-out 256-QAM: purple is best only for EVM/SNDR');
nexttile; bar(categorical(metric.Mode),[metric.PA_ACLR_dBc metric.Filtered_ACLR_dBc]); grid on; ylabel('dBc');
legend('PA-side ACLR','BPF-side ACLR','Location','best'); xtickangle(18); title('Integrated ACLR: more negative is better');
sgtitle('Four-way DPD stress comparison: separate deltas expose small effects; held-out gates decide deployment');
Files.png=fullfile(cfg.out_dir,'tid32_thermo3_dpd_four_way_delta.png');
Files.pdf=fullfile(cfg.out_dir,'tid32_thermo3_dpd_four_way_delta.pdf');
exportgraphics(fig,Files.png,'Resolution',180); exportgraphics(fig,Files.pdf,'ContentType','vector'); close(fig);
end

function local_lines(f,p,c,n)
hold on; for k=1:4, plot(f,p(:,k),'Color',c(k,:),'LineWidth',0.9); end; grid on;
xlabel('Frequency (GHz)'); ylabel('Normalized PSD (dB)');
end

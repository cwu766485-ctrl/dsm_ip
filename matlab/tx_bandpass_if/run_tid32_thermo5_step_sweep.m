function Summary = run_tid32_thermo5_step_sweep(varargin)
%RUN_TID32_THERMO5_STEP_SWEEP Screen five-level TID offset settings.
% A five-level result is admissible only when its exact four-branch temporal
% output has zero scalar mismatch and the same OFDM gate is met.  This is a
% behavioral screen, not evidence for a four-serializer FPGA implementation.

cfg.bandwidths_hz=[20e6 40e6 80e6 100e6 160e6];
cfg.steps=[0 1024 2048 3072 4096 5120 6144 8192];
cfg.seeds=[101 307 503]; cfg.nsym=8;
cfg.input_normalization="peak"; cfg.rms_drive=0.13;
% The legacy I/Q shortcut bypasses the raw Fs/4 modulation boundary.  New
% feasibility results must use the actual raw-word DDC receiver.
cfg.receiver_mode="fs4_ddc";
cfg.out_dir=fullfile(fileparts(fileparts(mfilename('fullpath'))),'out','tid32_thermo5_step_sweep');
for k=1:2:numel(varargin), cfg.(varargin{k})=varargin{k+1}; end
if ~exist(cfg.out_dir,'dir'), mkdir(cfg.out_dir); end
rows=table();
for bw=reshape(cfg.bandwidths_hz,1,[])
  for step=reshape(cfg.steps,1,[])
    for seed=reshape(cfg.seeds,1,[])
      r=run_256qam_tid32_ofdm_demod('implementation',"tid32_thermo5", ...
        'bandwidth_hz',bw,'thermo5_step',step,'seed',seed,'nsym',cfg.nsym, ...
        'input_normalization',cfg.input_normalization,'rms_drive',cfg.rms_drive, ...
        'receiver_mode',cfg.receiver_mode);
      r.RequestedBW_Hz=repmat(bw,height(r),1); r.Thermo5Step=repmat(step,height(r),1);
      r.Seed=repmat(seed,height(r),1); rows=[rows;r]; %#ok<AGROW>
    end
  end
end
Summary=rows;
writetable(Summary,fullfile(cfg.out_dir,'tid32_thermo5_step_sweep.csv'));
end

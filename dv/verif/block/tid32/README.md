# TID32 Cartesian Modulator Block

`tb/tb_tid32_cartesian_fs4_gt_tx_bittrue.sv` isolates the single TID32
Cartesian Fs/4 modulator and its ready/valid raw-word boundary. It checks
ordered 64-bit output words against MATLAB-generated vectors. Four-branch
thermometer composition is tested as the four-plane TID/Fs4 backend subsystem
under `dv/verif/subsystem/tx_backend/`.

Run the test with
`dv/verif/block/tid32/run_xsim_tid32_cartesian_fs4_gt_tx.ps1`.

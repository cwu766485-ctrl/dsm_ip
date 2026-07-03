# Scripts

This folder contains convenience wrappers for MATLAB profile export/evaluation.

The wrappers assume MATLAB is installed at:

```text
D:\MATLAB\R2025a\bin\matlab.exe
```

Edit `MATLAB_EXE` in the `.cmd` file if your MATLAB installation is elsewhere.

Most users can run MATLAB directly instead:

```matlab
cd matlab
path_setup
entry_p0_eval_seven
```

For sample-for-sample RTL/MATLAB bit-true checking after XSim:

```powershell
.\scripts\run_matlab_p0_bittrue_check.cmd
```

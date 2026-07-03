# GitHub Release Checklist

Use this checklist before publishing the repository.

## Required

- [ ] Confirm no private credentials, server addresses, passwords, personal
      account data, or license files are present.
- [ ] Confirm all documentation intended for GitHub is in English.
- [ ] Confirm `.gitignore` excludes Vivado/XSim logs, caches, and temporary
      build directories.
- [ ] Confirm `README.md`, `LICENSE`, `CONTRIBUTING.md`, `SECURITY.md`, and
      `AGENTS.md` are present.
- [ ] Run repository hygiene checks locally.
- [ ] Run RTL regression or clearly document why it was not run.
- [ ] Run MATLAB/RTL bit-true check or clearly document why it was not run.
- [ ] Confirm generated evidence files are intentional.

## Large and Third-Party Files

Local workspaces may contain waveform captures, MAT files, PDFs, board files,
and RFSoC collateral. Before publishing, confirm:

- [ ] RFSoC PDFs, schematics, BOMs, and board files are not tracked unless
      redistribution rights are explicitly confirmed;
- [ ] large evidence data should remain in Git, move to Git LFS, or move to
      GitHub Releases;
- [ ] no vendor license restrictions are violated.

If redistribution is unclear, remove the file from the public repository and
keep only a README describing the expected private/local source.

## Suggested Pre-Push Commands

```powershell
rg -n -i "password|passwd|secret|token|api_key|license server|private key" .
rg -n "[\p{Han}]" . -g "!syn/reports/**"
git ls-files fpga/hardware
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1
.\scripts\run_matlab_p0_bittrue_check.cmd
```

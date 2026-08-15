#!/usr/bin/env bash
# Probe the Linux EDA environment without claiming that a formal proof ran.
set -euo pipefail

# The shared bridge starts a non-interactive shell, so ~/.bashrc is not loaded.
# Re-enter once as an interactive shell to pick up VC_FORMAL_HOME and PATH.
if [[ "${DSM_FORMAL_INTERACTIVE_ENV:-0}" != "1" ]]; then
  export DSM_FORMAL_INTERACTIVE_ENV=1
  exec bash -ic "$(printf '%q ' "$0" "$@")"
fi

printf 'FORMAL_TOOL_CHECK_BEGIN\n'
printf 'PWD=%s\n' "$PWD"
vcs_path="$(command -v vcs || true)"
printf 'VCS=%s\n' "$vcs_path"
if [[ -n "$vcs_path" ]]; then
  printf 'VCS_REALPATH=%s\n' "$(readlink -f "$vcs_path" 2>/dev/null || printf '%s' "$vcs_path")"
fi

found=0
for tool in vcf vc_formal jaspergold qverify sby yosys formality; do
  if path="$(command -v "$tool" 2>/dev/null)"; then
    printf 'FORMAL_TOOL=%s PATH=%s\n' "$tool" "$path"
    found=1
  else
    printf 'FORMAL_TOOL=%s NOT_FOUND\n' "$tool"
  fi
done

if [[ "$found" -eq 0 ]]; then
  printf 'FORMAL_DISCOVERY_BEGIN\n'
  # Search only known EDA roots and the installed VCS neighborhood.  A full
  # filesystem crawl is deliberately avoided because shared EDA filesystems
  # can be large and slow.
  declare -a roots=(/opt /eda /tools /apps /usr/local /home/ray)
  if [[ -n "$vcs_path" ]]; then
    vcs_real="$(readlink -f "$vcs_path" 2>/dev/null || printf '%s' "$vcs_path")"
    roots+=("$(dirname "$vcs_real")/..")
  fi
  for root in "${roots[@]}"; do
    [[ -d "$root" ]] || continue
    while IFS= read -r candidate; do
      printf 'FORMAL_CANDIDATE=%s\n' "$candidate"
    done < <(find "$root" -maxdepth 6 -type f \
      \( -name vcf -o -name vc_formal -o -name jaspergold -o -name qverify \
         -o -name sby -o -name yosys -o -name formality \) -print 2>/dev/null)
  done
  for init in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" /etc/profile /etc/bash.bashrc; do
    [[ -r "$init" ]] || continue
    if grep -Ein 'vcf|vc[_ -]?formal|jasper|formality|synopsys' "$init" >/dev/null 2>&1; then
      printf 'FORMAL_INIT_REFERENCE=%s\n' "$init"
      grep -Ein 'vcf|vc[_ -]?formal|jasper|formality|synopsys' "$init" || true
    fi
  done
  if command -v module >/dev/null 2>&1; then
    printf 'FORMAL_MODULE_AVAIL_BEGIN\n'
    module avail 2>&1 | grep -Ei 'formal|jasper|synopsys|vcf' || true
    printf 'FORMAL_MODULE_AVAIL_END\n'
  fi
  printf 'FORMAL_DISCOVERY_END\n'
  printf 'FORMAL_TOOL_CHECK_RESULT=NO_SUPPORTED_FORMAL_ENGINE\n'
  exit 2
fi

printf 'FORMAL_TOOL_CHECK_RESULT=TOOL_AVAILABLE\n'

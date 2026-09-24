#!/usr/bin/env bash
# Invoke the site-provided VCS login-shell alias from a Make recipe.
set -euo pipefail

args=("$@")
if [[ ${#args[@]} -gt 0 && "${args[0]}" == "-full64" ]]; then
  args=("${args[@]:1}")
fi
exec bash -lic 'exec vcs "$@"' dsm_vcs "${args[@]}"

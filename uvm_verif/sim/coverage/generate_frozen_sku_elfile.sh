#!/usr/bin/env bash
set -euo pipefail

# Generate a minimal, checksum-correct URG exclusion file from the current VDB
# template. Do not edit the output by hand: URG exclusion entries are bound to
# a module checksum and elaborated instance context.

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <urg-full-exclusions.line> <output.elfile>" >&2
  exit 2
fi

template=$1
output=$2

if [[ ! -f "$template" ]]; then
  echo "ERROR: missing URG full-exclusions template: $template" >&2
  exit 2
fi

# Keep source exclusions tied to the elaborated module instance. The frozen
# x32 interpolation implementation contains two symmetric FIR specializations:
#
# * CIC-equivalent: NTAPS=29, INTERP=8, COEFF_SET=2. It can access only
#   coeff_cic(0..14); coeff_comp() and the mirrored CIC table half are dead.
# * Compensation: NTAPS=63, INTERP=1, COEFF_SET=3. It can access only
#   coeff_comp(0..31); coeff_cic() and the mirrored compensation half are dead.
#
# Active observer and memory-DPD logic deliberately remains enabled. Do not add
# a new exclusion without a waiver row and an instance-scoped reachability proof.
awk '
  function uncomment(s) { sub(/^\/\/[[:space:]]?/, "", s); return s }
  function source_line(s, a) {
    split(s, a, "LineNumber: ")
    if (length(a) < 2) return -1
    split(a[2], a, "\"")
    return a[1] + 0
  }
  function clear_section(   i) {
    for (i = 1; i <= section_n; i++) {
      delete raw[i]
      delete selected[i]
    }
    section_n = 0
    section_selected = 0
    module = ""
    instance = ""
    line = -1
  }
  function flush_section(   i,item) {
    if (section_selected) {
      for (i = 1; i <= section_n; i++) {
        item = uncomment(raw[i])
        if (item ~ /^Block / && !selected[i])
          print raw[i]
        else
          print item
      }
    }
    clear_section()
  }
  function add_raw(s) { raw[++section_n] = s }
  function classify(item,   keep) {
    keep = 0
    if (module ~ /dsm_ip_axi_top/ &&
        item == "Block 10 \"3693570962\" \"abs_rf = {1\047b0, {(RF_W - 1) {1\047b1}}};\"") {
      keep = 1; fsku001++
    }
    if (module ~ /dsm_interp_fir_fixed/ &&
        instance ~ /g_mode4\.g_i0_cic_equiv\.u_cic_[iq]$/ &&
        ((line >= 60 && line <= 74) || (line >= 82 && line <= 145) || line == 155)) {
      keep = 1; cic++
    }
    if (module ~ /dsm_interp_fir_fixed/ &&
        instance ~ /g_mode4\.u_comp_[iq]$/ &&
        ((line >= 45 && line <= 74) || (line >= 114 && line <= 145) || line == 153)) {
      keep = 1; comp++
    }
    return keep
  }

  /^\/\/ CHECKSUM:/ {
    flush_section()
    add_raw($0)
    next
  }
  section_n == 0 { next }
  {
    item = uncomment($0)
    add_raw($0)
    if (item ~ /^ANNOTATION: "ModuleName:/) module = item
    else if (item ~ /^INSTANCE:/) {
      instance = item
      sub(/^INSTANCE: /, "", instance)
    } else if (item ~ /^ANNOTATION: "FileName:/) {
      line = source_line(item)
    } else if (item ~ /^Block /) {
      selected[section_n] = classify(item)
      if (selected[section_n]) section_selected = 1
    }
  }
  END {
    flush_section()
    if (fsku001 != 1 || cic != 160 || comp != 126) {
      printf("ERROR: unexpected approved-bin count FSKU-001=%d cic=%d comp=%d\\n", fsku001, cic, comp) > "/dev/stderr"
      exit 2
    }
  }
' "$template" > "$output"

echo "Generated $output with 287 instance-scoped frozen-SKU line exclusions"

# Read-only helper: print GT Wizard configuration keys accepted by the local
# Vivado installation. It does not create a project or generated IP artifact.
create_project -in_memory -part xczu15eg-ffvb1156-2-i
create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip -module_name ti64_raw_gt_probe
report_property -all [get_ips ti64_raw_gt_probe]

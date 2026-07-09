set repo_root $::env(DSM_REPO_ROOT)
set xsa_path $::env(DSM_XSA)
set workspace_path $::env(DSM_VITIS_WS)

set platform_name dsm_zu15eg_platform
set app_name dsm_dpd_baremetal_smoke
set src_dir [file join $repo_root fpga zu15eg baremetal src]

puts "Workspace: $workspace_path"
puts "XSA:       $xsa_path"
puts "Sources:   $src_dir"

file mkdir $workspace_path
setws $workspace_path

if {[catch {
    platform active $platform_name
}]} {
    puts "Creating platform $platform_name"
    platform create -name $platform_name -hw $xsa_path -proc psu_cortexa53_0 -os standalone
    domain create -name standalone_domain -proc psu_cortexa53_0 -os standalone
    platform generate
} else {
    puts "Reusing platform $platform_name"
    if {[catch {
        domain active standalone_domain
    }]} {
        domain create -name standalone_domain -proc psu_cortexa53_0 -os standalone
        platform generate
    }
}

if {[catch {
    app active $app_name
}]} {
    puts "Creating app $app_name"
    app create -name $app_name -platform $platform_name -domain standalone_domain -template {Empty Application}
} else {
    puts "Reusing app $app_name"
}

importsources -name $app_name -path $src_dir -soft-link
app build -name $app_name

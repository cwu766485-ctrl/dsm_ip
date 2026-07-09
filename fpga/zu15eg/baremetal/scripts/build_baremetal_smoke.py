import os
import shutil
import vitis


repo_root = os.environ["DSM_REPO_ROOT"]
xsa_path = os.environ["DSM_XSA"]
workspace_path = os.environ["DSM_VITIS_WS"]

platform_name = "dsm_zu15eg_platform"
domain_name = "standalone_a53_0"
app_name = "dsm_dpd_baremetal_smoke"
src_dir = os.path.join(repo_root, "fpga", "zu15eg", "baremetal", "src")

print(f"Workspace: {workspace_path}")
print(f"XSA:       {xsa_path}")
print(f"Sources:   {src_dir}")

if os.path.isdir(workspace_path):
    shutil.rmtree(workspace_path)
os.makedirs(workspace_path, exist_ok=True)

client = vitis.create_client()
client.set_workspace(workspace_path)

try:
    platform = client.create_platform_component(
        name=platform_name,
        hw_design=xsa_path,
        domain_name=domain_name,
        cpu="psu_cortexa53_0",
        os="standalone",
    )
    platform.build()

    platform_xpfm = client.find_platform_in_repos(platform_name)
    app = client.create_app_component(
        name=app_name,
        platform=platform_xpfm,
        domain=domain_name,
    )
    app.import_files(
        from_loc=src_dir,
        files=["dsm_dpd_baremetal_smoke.c", "dpd_coeffs.h"],
        dest_dir_in_cmp="src",
    )
    app.build()
finally:
    vitis.dispose()

# The 2024.1 Vitis Python launcher can keep the Java process alive after a
# successful build on Windows. Exit explicitly so the wrapper can finish.
os._exit(0)

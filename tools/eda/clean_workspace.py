"""Remove reproducible EDA intermediates, preserving tracked and private inputs.

Run without --apply to preview. The complete runs/ tree and waveform, DCP, CSV,
log, journal, and report files are retained. No symlink or Windows junction is
traversed or removed.
"""
import argparse
import fnmatch
import os
from pathlib import Path
import stat
import subprocess


ROOT = Path(__file__).resolve().parents[2]
PROTECTED = (
    ".git", ".agents", ".codex", ".aws", ".vscode", ".idea",
    "runs", "ip",
    "fpga/hardware", "fpga/rfsoc4x2", "fpga/data/coe", "docs/papers",
    "data/board_validation", "fpga/zu15eg/local_hw", "fpga/zu15eg/captures",
)
SCAN_ROOTS = {
    ".github", ".Xil", ".gen", ".srcs", "config", "dv", "matlab", "rtl",
    "scripts", "syn", "tmp", "tools", "vcst_rtdb", "vcst_rtdb.bak",
    "dsm_ip_formal_harness_learn_dir", "thermo5_axil_cfg_coverage_harness_learn_dir",
}
PRIVATE_NAMES = {"pdk", "tsmc28", "tsmc40", "secrets"}
DIR_PATTERNS = (
    "*.vdb", "*_learn_dir", "*.daidir", "csrc", "*_csrc",
    "vcst_rtdb*", "tmp_dir_*_vcs", "xsim.dir", "xsim.covdb", ".Xil",
    "alib-*", "cksum_dir", "__pycache__", ".pytest_cache", ".mypy_cache",
    ".ruff_cache", ".vivado_tmp_*", ".slang",
)
PRESERVE_EVIDENCE = (
    "*.vcd", "*.fsdb", "*.vpd", "*.fst", "*.ghw", "*.wlf", "*.wdb",
    "*.dcp", "*.csv", "*.log", "*.log.*", "*.jou", "*.rpt",
)
ROOT_FILES = (
    "*.pvl", "*.syn", "*.mr", "*.svf", "*.pb", "*.str",
    ".vc_env_*.txt", ".fsm.sch.verilog.xml", "fullexclude.*",
    "fullexclude_module.*", "novas.conf", "novas.rc", "ucli.key",
    "tight_setup_hold_pins.txt",
)


def matches(name, patterns):
    folded_name = name.casefold()
    return any(fnmatch.fnmatchcase(folded_name, pattern.casefold()) for pattern in patterns)


def linked(path):
    # WSL-created special files can be Windows reparse points without being
    # recognized as ordinary symlinks by pathlib.
    info = path.lstat()
    return bool(getattr(info, "st_file_attributes", 0) & 0x400) or stat.S_ISLNK(info.st_mode)


def tracked_paths():
    result = subprocess.run(
        ["git", "ls-files", "-z", "--cached"], cwd=ROOT,
        check=True, stdout=subprocess.PIPE,
    )
    return {os.fsdecode(p) for p in result.stdout.split(b"\0") if p}


def candidates(tracked):
    protected = {p.casefold() for p in PROTECTED}
    for base, dirs, files in os.walk(ROOT, followlinks=False):
        parent = Path(base)
        for name in list(dirs):
            path = parent / name
            rel = path.relative_to(ROOT).as_posix()
            if (parent == ROOT and name not in SCAN_ROOTS
                    or linked(path) or rel.casefold() in protected
                    or name.casefold() in PRIVATE_NAMES):
                dirs.remove(name)
        in_cache = any(matches(part, DIR_PATTERNS) for part in parent.relative_to(ROOT).parts)
        for name in files:
            path = parent / name
            rel = path.relative_to(ROOT).as_posix()
            if rel in tracked or linked(path):
                continue
            if matches(name, PRESERVE_EVIDENCE):
                continue
            if (in_cache or name in {"simv", "ucli.key"}
                    or matches(name, ("*_simv", "*.pyc", "*.pyo"))
                    or (parent == ROOT and matches(name, ROOT_FILES))):
                yield path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="delete previewed intermediates")
    args = parser.parse_args()
    tracked = tracked_paths()  # Fail closed if Git is unavailable.
    paths = list(candidates(tracked))
    total = sum(p.stat().st_size for p in paths)
    groups = {}
    for path in paths:
        rel = path.relative_to(ROOT)
        groups[rel.parts[0]] = groups.get(rel.parts[0], 0) + path.stat().st_size
    for name, size in sorted(groups.items()):
        print(f"{name}: {size / 1024**2:.2f} MiB")
    print(f"{'Deleting' if args.apply else 'Preview'}: {len(paths)} files, {total / 1024**3:.3f} GiB")
    if args.apply:
        for path in paths:
            # Validate the final absolute path immediately before every deletion.
            path.resolve().relative_to(ROOT.resolve())
            if linked(path) or any(linked(p) for p in path.parents if p != ROOT):
                raise RuntimeError(f"Refusing linked path: {path}")
            path.unlink()
        # Remove only emptied cache ancestors of the deleted files.
        ancestors = {p for file in paths for p in file.parents
                     if p != ROOT and ROOT in p.parents}
        for path in sorted(ancestors, key=lambda p: len(p.parts), reverse=True):
            if any(matches(part, DIR_PATTERNS) for part in path.relative_to(ROOT).parts):
                try:
                    path.rmdir()
                except OSError:
                    pass
        print("Cleanup complete; tracked files and run evidence retained.")


if __name__ == "__main__":
    main()

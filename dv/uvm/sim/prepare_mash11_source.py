#!/usr/bin/env python3
"""Export the unchanged legacy MASH 1-1 sources from the recorded git base."""

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


SOURCE_REV = "8d260dacbece071bc3f53546fd2b2ee3d08c64cb"
SOURCE_FILES = (
    "rtl/dsm/singlebit/dsm_core_mash11.sv",
    "rtl/tx_bandpass_if/mash11_multipa_tx.sv",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--source-rev", default=SOURCE_REV)
    args = parser.parse_args()
    repo = args.repo.resolve()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "-C", str(repo), "cat-file", "-e",
                    f"{args.source_rev}^{{commit}}"], check=True)
    records = {}
    for source in SOURCE_FILES:
        payload = subprocess.run(
            ["git", "-C", str(repo), "show", f"{args.source_rev}:{source}"],
            check=True, stdout=subprocess.PIPE).stdout
        destination = output / Path(source).name
        destination.write_bytes(payload)
        records[source] = {
            "exported_path": str(destination),
            "sha256": hashlib.sha256(payload).hexdigest(),
        }
    manifest = {"source_revision": args.source_rev, "files": records,
                "note": "Byte-for-byte source export; RTL not modified by this DV run."}
    (output / "source_manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"MASH11_SOURCE_EXPORT=PASS revision={args.source_rev}")
    for source, record in records.items():
        print(f"{source} sha256={record['sha256']}")


if __name__ == "__main__":
    main()

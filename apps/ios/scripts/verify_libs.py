#!/usr/bin/env python3
"""
Library integrity verification for POPOPX iOS builds.

Checks:
1. Both ghc and non-ghc popopx-chat libraries contain matching config strings
2. No stale server addresses remain in any library
3. Platform tags are correct (IOS for device, IOSSIMULATOR for simulator)
4. Object counts match expected values

Usage:
    python3 verify_libs.py                  # check all directories
    python3 verify_libs.py sim              # check simulator only
    python3 verify_libs.py --ci             # CI mode: exit 1 on any failure
"""

import os
import re
import struct
import subprocess
import sys

SCRIPT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Libraries")

EXPECTED_NTF_SERVERS = [
    "ntfsgp.popopxchat.com",
    "ntfeur.popopchat.com",
    "ntfamr.popopxchat.xyz",
]

STALE_SERVERS = [
    "ntf3.simplex.im",
    "ntf4.simplex.im",
    "ntf1.simplex.im",
    "ntf2.simplex.im",
]

EXPECTED_OBJECT_COUNTS = {
    "libHSpopopx-chat": {"ghc": 3433, "plain": 227},
}

DIRS = {
    "ios": {"expected_platform": "ios", "label": "iOS device"},
    "sim": {"expected_platform": "iossim", "label": "iOS simulator"},
    "mac": {"expected_platform": "mac", "label": "macOS"},
}


def run_strings(path):
    result = subprocess.run(["strings", path], capture_output=True)
    return result.stdout.decode("utf-8", errors="replace")


def check_stale_strings(path, label):
    content = run_strings(path)
    errors = []
    for stale in STALE_SERVERS:
        stale_uri = f"ntf://.*{re.escape(stale)}"
        if re.search(stale_uri, content):
            errors.append(f"  STALE: '{stale}' found in active NTF URI in {label}")
    return errors


def check_expected_strings(path, label):
    content = run_strings(path)
    missing = []
    for server in EXPECTED_NTF_SERVERS:
        if server not in content:
            missing.append(f"  MISSING: '{server}' not in {label}")
    return missing


def check_platform_tags(path, expected_platform):
    errors = []
    try:
        with open(path, "rb") as f:
            f.read(8)
            ios_count = iossim_count = mac_count = 0
            total_objects = 0

            while True:
                hdr = f.read(60)
                if len(hdr) < 60:
                    break
                size = int(hdr[48:58].decode("ascii").strip())
                data_start = f.tell()
                padded_size = size + (size % 2)

                name_len = 0
                name_field = hdr[0:16].decode("ascii", errors="replace").rstrip()
                if name_field.startswith("#1/"):
                    name_len = int(name_field[3:])

                obj_start = data_start + name_len
                f.seek(obj_start)

                if f.read(4) == b"\xcf\xfa\xed\xfe":
                    total_objects += 1
                    f.seek(obj_start + 16)
                    ncmds = struct.unpack("<I", f.read(4))[0]
                    f.seek(obj_start + 20)
                    sizeofcmds = struct.unpack("<I", f.read(4))[0]
                    f.seek(obj_start + 32)
                    lc_data = f.read(sizeofcmds)

                    pos = 0
                    for _ in range(ncmds):
                        cmd = struct.unpack_from("<I", lc_data, pos)[0]
                        cmdsize = struct.unpack_from("<I", lc_data, pos + 4)[0]
                        if cmd == 0x25:
                            ios_count += 1
                            break
                        elif cmd == 0x32:
                            platform = struct.unpack_from("<I", lc_data, pos + 8)[0]
                            if platform == 7:
                                iossim_count += 1
                            elif platform == 2:
                                ios_count += 1
                            elif platform == 1:
                                mac_count += 1
                            break
                        elif cmd == 0x1F:
                            mac_count += 1
                            break
                        pos += cmdsize

                f.seek(data_start + padded_size)

        if expected_platform == "ios" and iossim_count > 0:
            errors.append(
                f"  PLATFORM: {iossim_count} objects tagged IOSSIMULATOR in iOS device lib"
            )
        elif expected_platform == "iossim" and ios_count > 0:
            errors.append(
                f"  PLATFORM: {ios_count} objects tagged IOS in simulator lib"
            )

        return errors, total_objects, ios_count, iossim_count, mac_count
    except Exception as e:
        return [f"  ERROR: {e}"], 0, 0, 0, 0


def check_consistency(ghc_path, plain_path):
    errors = []
    ghc_content = run_strings(ghc_path)
    plain_content = run_strings(plain_path)

    for pattern in ["ntf://", "popopxchat.com", "popopchat.com"]:
        ghc_count = ghc_content.count(pattern)
        plain_count = plain_content.count(pattern)
        if ghc_count != plain_count:
            errors.append(
                f"  CONSISTENCY: '{pattern}' count mismatch: ghc={ghc_count} plain={plain_count}"
            )
    return errors


def find_popopx_libs(directory):
    ghc = None
    plain = None
    for f in os.listdir(directory):
        if f.startswith("libHSpopopx-chat") and f.endswith(".a"):
            if "-ghc" in f:
                ghc = os.path.join(directory, f)
            else:
                plain = os.path.join(directory, f)
    return ghc, plain


def verify_directory(dirname, info, ci_mode):
    dirpath = os.path.join(SCRIPT_DIR, dirname)
    if not os.path.isdir(dirpath):
        print(f"[SKIP] {dirname}/ not found")
        return []

    print(f"\n{'='*60}")
    print(f"Checking {info['label']} ({dirname}/)")
    print(f"{'='*60}")

    all_errors = []
    ghc_path, plain_path = find_popopx_libs(dirpath)

    if not ghc_path or not plain_path:
        msg = f"  Missing libraries: ghc={ghc_path is not None} plain={plain_path is not None}"
        print(msg)
        all_errors.append(msg)
        return all_errors

    for path, label in [(ghc_path, "ghc"), (plain_path, "plain")]:
        basename = os.path.basename(path)
        print(f"\n  [{label}] {basename}")

        stale = check_stale_strings(path, basename)
        if stale:
            all_errors.extend(stale)
            for e in stale:
                print(e)
        else:
            print("    No stale servers found ✓")

        missing = check_expected_strings(path, basename)
        if missing:
            all_errors.extend(missing)
            for e in missing:
                print(e)
        else:
            print("    All expected NTF servers present ✓")

        plat_errors, total, ios, iossim, mac = check_platform_tags(
            path, info["expected_platform"]
        )
        print(f"    Objects: {total} (ios={ios} iossim={iossim} mac={mac})")
        if plat_errors:
            all_errors.extend(plat_errors)
            for e in plat_errors:
                print(e)
        else:
            print("    Platform tags correct ✓")

    if ghc_path and plain_path:
        print(f"\n  [consistency] ghc vs plain")
        cons_errors = check_consistency(ghc_path, plain_path)
        if cons_errors:
            all_errors.extend(cons_errors)
            for e in cons_errors:
                print(e)
        else:
            print("    GHC and plain libraries consistent ✓")

    return all_errors


def main():
    ci_mode = "--ci" in sys.argv
    targets = [a for a in sys.argv[1:] if a != "--ci"]

    if targets:
        dirs_to_check = {k: v for k, v in DIRS.items() if k in targets}
    else:
        dirs_to_check = DIRS

    total_errors = []
    for dirname, info in dirs_to_check.items():
        errors = verify_directory(dirname, info, ci_mode)
        total_errors.extend(errors)

    print(f"\n{'='*60}")
    if total_errors:
        print(f"FAILED: {len(total_errors)} error(s) found")
        for e in total_errors:
            print(e)
        sys.exit(1 if ci_mode else 0)
    else:
        print("PASSED: All library checks passed ✓")
        sys.exit(0)


if __name__ == "__main__":
    main()

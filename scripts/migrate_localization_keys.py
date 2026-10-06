#!/usr/bin/env python3
"""
Migrate localization keys from POPOPX to POPOPX.

This script:
1. Scans all .strings files to find keys containing "POPOPX"
2. Creates a mapping of old keys -> new keys (POPOPX -> POPOPX)
3. Updates all 18 locale files
4. Updates all Swift NSLocalizedString calls

Usage:
    python3 scripts/migrate_localization_keys.py [--dry-run]

WARNING: This is a large-scale change. Test thoroughly before committing.
"""

import os
import re
import sys
import json
from pathlib import Path
from collections import defaultdict

# Configuration
IOS_DIR = Path(__file__).parent.parent / "apps" / "ios"
LOCALES_DIR = IOS_DIR  # .lproj directories are directly under apps/ios/
SWIFT_DIRS = [
    IOS_DIR / "Shared",
    IOS_DIR / "POPOPXSwitch",
]

# Pattern to match localization keys with "POPOPX"
POPOPX_KEY_PATTERN = re.compile(r'"([^"]*POPOPX[^"]*)"\s*=\s*"([^"]*)"')

def find_all_strings_files():
    """Find all .strings files in all locale directories."""
    strings_files = []
    for locale_dir in LOCALES_DIR.iterdir():
        if locale_dir.is_dir() and locale_dir.name.endswith(".lproj"):
            for strings_file in locale_dir.glob("*.strings"):
                strings_files.append(strings_file)
    return strings_files

def extract_popopx_keys(strings_file):
    """Extract all keys containing 'POPOPX' from a .strings file."""
    keys = {}
    with open(strings_file, 'r', encoding='utf-8') as f:
        content = f.read()
        for match in POPOPX_KEY_PATTERN.finditer(content):
            old_key = match.group(1)
            value = match.group(2)
            # Generate new key by replacing POPOPX with POPOPX
            new_key = old_key.replace("POPOPX", "POPOPX")
            keys[old_key] = {
                'new_key': new_key,
                'value': value,
                'file': strings_file
            }
    return keys

def build_key_mapping():
    """Build a complete mapping of old keys -> new keys from all locale files."""
    all_keys = {}
    strings_files = find_all_strings_files()

    print(f"Scanning {len(strings_files)} .strings files...")

    for strings_file in strings_files:
        keys = extract_popopx_keys(strings_file)
        for old_key, info in keys.items():
            if old_key not in all_keys:
                all_keys[old_key] = info

    print(f"Found {len(all_keys)} unique keys containing 'POPOPX'")
    return all_keys

def update_strings_files(key_mapping, dry_run=False):
    """Update all .strings files with new key names."""
    strings_files = find_all_strings_files()
    updated_count = 0

    for strings_file in strings_files:
        with open(strings_file, 'r', encoding='utf-8') as f:
            content = f.read()

        original_content = content

        # Replace keys in format: "old_key" = "value";
        for old_key, info in key_mapping.items():
            new_key = info['new_key']
            # Match the full line: "old_key" = "value";
            pattern = re.compile(rf'"{re.escape(old_key)}"\s*=\s*"([^"]*)";')
            content = pattern.sub(rf'"{new_key}" = "\1";', content)

        if content != original_content:
            updated_count += 1
            if not dry_run:
                with open(strings_file, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"Updated: {strings_file.relative_to(IOS_DIR)}")
            else:
                print(f"[DRY RUN] Would update: {strings_file.relative_to(IOS_DIR)}")

    return updated_count

def update_swift_files(key_mapping, dry_run=False):
    """Update all Swift files to use new key names in NSLocalizedString calls."""
    swift_files = []
    for swift_dir in SWIFT_DIRS:
        swift_files.extend(swift_dir.rglob("*.swift"))

    updated_count = 0
    total_replacements = 0

    # Pattern to match NSLocalizedString("key", comment: "...")
    nslocalized_pattern = re.compile(r'NSLocalizedString\(\s*"([^"]+)"\s*,\s*comment:\s*"([^"]*)"\s*\)')

    for swift_file in swift_files:
        with open(swift_file, 'r', encoding='utf-8') as f:
            content = f.read()

        original_content = content
        file_replacements = 0

        # Find all NSLocalizedString calls
        def replace_key(match):
            nonlocal file_replacements
            old_key = match.group(1)
            comment = match.group(2)

            if old_key in key_mapping:
                new_key = key_mapping[old_key]['new_key']
                file_replacements += 1
                return f'NSLocalizedString("{new_key}", comment: "{comment}")'
            return match.group(0)

        content = nslocalized_pattern.sub(replace_key, content)

        if content != original_content:
            updated_count += 1
            total_replacements += file_replacements
            if not dry_run:
                with open(swift_file, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"Updated {file_replacements} keys in: {swift_file.relative_to(IOS_DIR)}")
            else:
                print(f"[DRY RUN] Would update {file_replacements} keys in: {swift_file.relative_to(IOS_DIR)}")

    return updated_count, total_replacements

def export_mapping(key_mapping, output_file):
    """Export the key mapping to a JSON file for reference."""
    mapping_dict = {
        old_key: {
            'new_key': info['new_key'],
            'value': info['value']
        }
        for old_key, info in key_mapping.items()
    }

    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(mapping_dict, f, indent=2, ensure_ascii=False)

    print(f"Exported key mapping to: {output_file}")

def main():
    dry_run = '--dry-run' in sys.argv

    if dry_run:
        print("=== DRY RUN MODE ===\n")

    print("Building key mapping...")
    key_mapping = build_key_mapping()

    if not key_mapping:
        print("No keys found containing 'POPOPX'. Nothing to migrate.")
        return

    # Export mapping for reference
    mapping_file = Path(__file__).parent / "localization_key_mapping.json"
    export_mapping(key_mapping, mapping_file)

    print(f"\nMigrating {len(key_mapping)} keys across all locale files...")
    strings_updated = update_strings_files(key_mapping, dry_run)
    print(f"{'Would update' if dry_run else 'Updated'} {strings_updated} .strings files")

    print(f"\nUpdating Swift files...")
    swift_updated, total_replacements = update_swift_files(key_mapping, dry_run)
    print(f"{'Would update' if dry_run else 'Updated'} {swift_updated} Swift files with {total_replacements} total replacements")

    if dry_run:
        print("\n=== DRY RUN COMPLETE ===")
        print("Run without --dry-run to apply changes")
    else:
        print("\n=== MIGRATION COMPLETE ===")
        print(f"Migrated {len(key_mapping)} keys")
        print(f"Updated {strings_updated} .strings files")
        print(f"Updated {swift_updated} Swift files")
        print("\nNext steps:")
        print("1. Build the project to verify no compilation errors")
        print("2. Test the app to verify all localized strings display correctly")
        print("3. Commit the changes")

if __name__ == '__main__':
    main()

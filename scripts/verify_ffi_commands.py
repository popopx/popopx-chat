#!/usr/bin/env python3
"""
FFI Command Format Verification Tool

Compares iOS Swift command strings with Haskell command parsers
to identify format mismatches that could cause FFI failures.
"""

import re
import sys
from pathlib import Path
from dataclasses import dataclass
from typing import List, Dict, Tuple

@dataclass
class Command:
    name: str
    swift_pattern: str
    haskell_pattern: str
    file: str
    line: int
    match_status: str  # "✅", "⚠️", "❌"

def extract_swift_commands(file_path: Path) -> List[Tuple[str, str, int]]:
    """Extract command strings from Swift ChatCommand enum"""
    commands = []
    content = file_path.read_text()
    lines = content.split('\n')
    
    # Pattern: case .commandName(...): return "/_command args"
    pattern = r'case\s+(?:let\s+)?\.(\w+)[^:]*:\s*return\s+"([^"]+)"'
    
    for i, line in enumerate(lines, 1):
        matches = re.finditer(pattern, line)
        for match in matches:
            cmd_name = match.group(1)
            cmd_string = match.group(2)
            commands.append((cmd_name, cmd_string, i))
    
    return commands

def extract_haskell_commands(file_path: Path) -> List[Tuple[str, str, int]]:
    """Extract command parsers from Haskell chatCommandP"""
    commands = []
    content = file_path.read_text()
    lines = content.split('\n')
    
    # Pattern: "/_command " *> (CommandName <$> ...)
    pattern = r'"(/_[^"]+)"\s*\*>\s*\((\w+)'
    
    for i, line in enumerate(lines, 1):
        matches = re.finditer(pattern, line)
        for match in matches:
            cmd_pattern = match.group(1)
            cmd_name = match.group(2)
            commands.append((cmd_name, cmd_pattern, i))
    
    return commands

def normalize_command(cmd: str) -> str:
    """Normalize command string for comparison"""
    # Remove variable interpolations
    cmd = re.sub(r'\\\([^)]+\)', '{VAR}', cmd)
    cmd = re.sub(r'\{[^}]+\}', '{VAR}', cmd)
    # Remove extra spaces
    cmd = re.sub(r'\s+', ' ', cmd)
    return cmd.strip()

def compare_commands(swift_cmds: List, haskell_cmds: List) -> List[Command]:
    """Compare Swift and Haskell command formats"""
    results = []
    
    # Create lookup by command name
    haskell_lookup = {name: (pattern, line) for name, pattern, line in haskell_cmds}
    
    for swift_name, swift_pattern, swift_line in swift_cmds:
        if swift_name in haskell_lookup:
            haskell_pattern, haskell_line = haskell_lookup[swift_name]
            
            # Normalize and compare
            swift_norm = normalize_command(swift_pattern)
            haskell_norm = normalize_command(haskell_pattern)
            
            if swift_norm == haskell_norm:
                status = "✅"
            elif swift_pattern.split()[0] == haskell_pattern.split()[0]:
                status = "⚠️"  # Same command prefix but different format
            else:
                status = "❌"  # Completely different
            
            results.append(Command(
                name=swift_name,
                swift_pattern=swift_pattern,
                haskell_pattern=haskell_pattern,
                file=f"Swift:L{swift_line} / Haskell:L{haskell_line}",
                line=swift_line,
                match_status=status
            ))
        else:
            results.append(Command(
                name=swift_name,
                swift_pattern=swift_pattern,
                haskell_pattern="NOT FOUND",
                file=f"Swift:L{swift_line}",
                line=swift_line,
                match_status="❌"
            ))
    
    return results

def generate_report(commands: List[Command], output_file: Path):
    """Generate verification report"""
    import datetime
    lines = []
    lines.append("# FFI Command Format Verification Report\n")
    lines.append(f"Generated: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    # Summary
    total = len(commands)
    match = sum(1 for c in commands if c.match_status == "✅")
    warn = sum(1 for c in commands if c.match_status == "⚠️")
    fail = sum(1 for c in commands if c.match_status == "❌")
    
    lines.append("## Summary\n")
    lines.append(f"- Total commands: {total}")
    lines.append(f"- ✅ Match: {match}")
    lines.append(f"- ⚠️ Warning: {warn}")
    lines.append(f"- ❌ Fail: {fail}\n")
    
    # Failed commands (priority)
    if fail > 0:
        lines.append("## ❌ Failed Commands (CRITICAL)\n")
        for cmd in commands:
            if cmd.match_status == "❌":
                lines.append(f"### {cmd.name}")
                lines.append(f"**Location**: {cmd.file}")
                lines.append(f"**Swift**: `{cmd.swift_pattern}`")
                lines.append(f"**Haskell**: `{cmd.haskell_pattern}`")
                lines.append("")
    
    # Warning commands
    if warn > 0:
        lines.append("## ⚠️ Warning Commands (REVIEW)\n")
        for cmd in commands:
            if cmd.match_status == "⚠️":
                lines.append(f"### {cmd.name}")
                lines.append(f"**Location**: {cmd.file}")
                lines.append(f"**Swift**: `{cmd.swift_pattern}`")
                lines.append(f"**Haskell**: `{cmd.haskell_pattern}`")
                lines.append("")
    
    # All commands table
    lines.append("## All Commands\n")
    lines.append("| Status | Command | Swift Pattern | Haskell Pattern |")
    lines.append("|--------|---------|---------------|-----------------|")
    for cmd in sorted(commands, key=lambda c: c.name):
        swift_short = cmd.swift_pattern[:50] + "..." if len(cmd.swift_pattern) > 50 else cmd.swift_pattern
        haskell_short = cmd.haskell_pattern[:50] + "..." if len(cmd.haskell_pattern) > 50 else cmd.haskell_pattern
        lines.append(f"| {cmd.match_status} | {cmd.name} | `{swift_short}` | `{haskell_short}` |")
    
    output_file.write_text('\n'.join(lines))
    print(f"Report generated: {output_file}")

def main():
    # Find project root (go up from scripts/ directory)
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    
    # Locate files
    swift_file = project_root / "apps/ios/Shared/Model/AppAPITypes.swift"
    haskell_file = project_root / "src/Popopx/Chat/Library/Commands.hs"
    
    if not swift_file.exists():
        print(f"Error: Swift file not found: {swift_file}")
        sys.exit(1)
    
    if not haskell_file.exists():
        print(f"Error: Haskell file not found: {haskell_file}")
        sys.exit(1)
    
    print("Extracting Swift commands...")
    swift_commands = extract_swift_commands(swift_file)
    print(f"  Found {len(swift_commands)} commands")
    
    print("Extracting Haskell commands...")
    haskell_commands = extract_haskell_commands(haskell_file)
    print(f"  Found {len(haskell_commands)} commands")
    
    print("Comparing commands...")
    results = compare_commands(swift_commands, haskell_commands)
    
    print("Generating report...")
    output_file = project_root / "FFI_COMMAND_VERIFICATION_REPORT.md"
    generate_report(results, output_file)
    
    # Print summary
    match = sum(1 for c in results if c.match_status == "✅")
    warn = sum(1 for c in results if c.match_status == "⚠️")
    fail = sum(1 for c in results if c.match_status == "❌")
    
    print(f"\nSummary:")
    print(f"  ✅ Match: {match}")
    print(f"  ⚠️  Warning: {warn}")
    print(f"  ❌ Fail: {fail}")
    
    if fail > 0:
        print(f"\n⚠️  CRITICAL: {fail} commands have mismatched formats!")
        print(f"   See {output_file} for details")
        sys.exit(1)
    else:
        print(f"\n✅ All commands verified successfully")
        sys.exit(0)

if __name__ == "__main__":
    main()

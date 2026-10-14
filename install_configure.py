#!/usr/bin/env python3
"""Interactively merge qb-buku aliases/keybindings into a qutebrowser config.py
without duplicating entries that are already present.

Usage: install_configure.py <config.py path> <keybinding prefix>
"""
import re
import sys

BOLD_YELLOW = "\033[1;33m"
RESET = "\033[0m"
DIM = "\033[2m"

ALIAS_ORDER = ["buku-add", "buku-delete", "buku-update", "buku-browse"]
ALIAS_DEFAULTS = {name: f"spawn --userscript {name}" for name in ALIAS_ORDER}

ENTRY_RE = re.compile(r"^(\s*)['\"]([\w-]+)['\"]\s*:\s*['\"]([^'\"]*)['\"]\s*,?\s*$")
BLOCK_START_RE = re.compile(r"c\.aliases\.update\(\s*\{\s*$")
BLOCK_END_RE = re.compile(r"^\s*\}\s*\)\s*$")
BIND_RE = re.compile(
    r"^(\s*)config\.bind\(\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]([^'\"]*)['\"]\s*(?:,[^)]*)?\)\s*$"
)


def confirm(msg, default=False):
    suffix = "Y/n" if default else "y/n"
    answer = input(f"{msg} [{suffix}]: ").strip().lower()
    if not answer:
        return default
    return answer.startswith("y")


def find_alias_blocks(lines):
    blocks = []
    start = None
    for i, line in enumerate(lines):
        if start is None:
            if BLOCK_START_RE.search(line):
                start = i
        else:
            if BLOCK_END_RE.match(line):
                blocks.append((start, i))
                start = None
    return blocks


def collect_alias_occurrences(lines, blocks):
    """key -> list of (line_idx, value)"""
    occurrences = {}
    for start, end in blocks:
        for i in range(start + 1, end):
            m = ENTRY_RE.match(lines[i])
            if m and m.group(2) in ALIAS_DEFAULTS:
                occurrences.setdefault(m.group(2), []).append((i, m.group(3)))
    return occurrences


def print_block_highlighted(lines, start, end, highlight_idx):
    print()
    for i in range(start, end + 1):
        if i == highlight_idx:
            print(f"  {BOLD_YELLOW}>>> {lines[i]}{RESET}")
        else:
            print(f"  {DIM}    {lines[i]}{RESET}")
    print()


def block_containing(blocks, line_idx):
    for start, end in blocks:
        if start <= line_idx <= end:
            return start, end
    return line_idx, line_idx


def process_aliases(lines):
    blocks = find_alias_blocks(lines)
    occurrences = collect_alias_occurrences(lines, blocks)

    missing = []
    for key in ALIAS_ORDER:
        default_value = ALIAS_DEFAULTS[key]
        occs = occurrences.get(key, [])
        if not occs:
            missing.append(key)
            continue
        for line_idx, value in occs:
            if value == default_value:
                continue
            start, end = block_containing(blocks, line_idx)
            print(f"Found existing alias '{key}' that differs from the qb-buku default:")
            print_block_highlighted(lines, start, end, line_idx)
            if confirm(
                f"Overwrite '{key}' with the default ('{default_value}')?", default=False
            ):
                indent = re.match(r"^(\s*)", lines[line_idx]).group(1)
                lines[line_idx] = f"{indent}'{key}': '{default_value}',"
            else:
                print(f"-> Leaving '{key}' untouched.")
    return missing


def collect_binding_occurrences(lines):
    """key -> list of (line_idx, value)"""
    occurrences = {}
    for i, line in enumerate(lines):
        m = BIND_RE.match(line)
        if m:
            occurrences.setdefault(m.group(2), []).append((i, m.group(3)))
    return occurrences


def process_bindings(lines, bindings):
    occurrences = collect_binding_occurrences(lines)

    missing = []
    for key, default_value in bindings:
        occs = occurrences.get(key, [])
        if not occs:
            missing.append((key, default_value))
            continue
        for line_idx, value in occs:
            if value == default_value:
                continue
            start = max(0, line_idx - 1)
            end = min(len(lines) - 1, line_idx + 1)
            print(f"Found existing binding '{key}' that differs from the qb-buku default:")
            print_block_highlighted(lines, start, end, line_idx)
            if confirm(
                f"Overwrite binding '{key}' with the default ('{default_value}')?",
                default=False,
            ):
                lines[line_idx] = f"config.bind('{key}', '{default_value}')"
            else:
                print(f"-> Leaving binding '{key}' untouched.")
    return missing


def main():
    config_file, prefix = sys.argv[1], sys.argv[2]
    bindings = [
        (f"{prefix}m", "spawn --userscript buku-add"),
        (f"{prefix}M", "spawn --userscript buku-delete"),
        (f"{prefix}b", "spawn --userscript buku-browse"),
        (f"{prefix}B", "spawn --userscript buku-browse -t"),
    ]

    try:
        with open(config_file, "r") as f:
            lines = f.read().splitlines()
        existed = True
    except FileNotFoundError:
        lines = ["config.load_autoconfig()"]
        existed = False

    missing_aliases = process_aliases(lines)
    missing_bindings = process_bindings(lines, bindings)

    if missing_aliases:
        lines.append("")
        lines.append("# qb-buku aliases")
        lines.append("c.aliases.update({")
        for key in missing_aliases:
            lines.append(f"    '{key}': '{ALIAS_DEFAULTS[key]}',")
        lines.append("})")
        print(f"-> Appending missing alias(es): {', '.join(missing_aliases)}")

    if missing_bindings:
        lines.append("")
        lines.append("# qb-buku keybindings")
        for key, value in missing_bindings:
            lines.append(f"config.bind('{key}', '{value}')")
        print(f"-> Appending missing binding(s): {', '.join(k for k, _ in missing_bindings)}")

    if not existed:
        import os

        os.makedirs(os.path.dirname(config_file) or ".", exist_ok=True)
        print(f"-> Creating '{config_file}'...")
    else:
        print(f"-> Updating '{config_file}'...")

    with open(config_file, "w") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()

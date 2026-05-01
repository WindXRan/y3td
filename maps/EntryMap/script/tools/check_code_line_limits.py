#!/usr/bin/env python3
"""Check project-owned code files against basic size and nesting limits."""

from __future__ import annotations

import argparse
from pathlib import Path


DEFAULT_MAX_LINES = 400
DEFAULT_MAX_NESTING = 4
DEFAULT_MAX_LINE_LENGTH = 240
CODE_EXTENSIONS = {".lua", ".py", ".bat", ".ps1", ".sh"}
NESTING_EXTENSIONS = {".lua", ".py"}
LUA_OPENERS = {"do", "function", "if", "for", "repeat", "while"}
LUA_MIDDLES = {"else", "elseif"}
LUA_CLOSERS = {"end", "until"}
DEFAULT_EXCLUDED_PARTS = {
    ".git",
    ".pytest_cache",
    ".y3maker",
    "script/docs",
    "script/data/tables",
    "script/y3",
    "script/y3-helper",
}


def has_excluded_part(path: Path, root: Path, excluded_parts: set[str]) -> bool:
    rel = path.relative_to(root).as_posix()
    parts = set(path.relative_to(root).parts)
    for excluded in excluded_parts:
        # Direct match against relative path.
        if rel == excluded or rel.startswith(f"{excluded}/"):
            return True
        # Allow "script/xxx" style exclusions when root is already "script".
        if excluded.startswith("script/"):
            short_excluded = excluded[len("script/") :]
            if rel == short_excluded or rel.startswith(f"{short_excluded}/"):
                return True
        # Fallback part-based exclusion.
        if excluded in parts:
            return True
    return False


def iter_code_files(root: Path, excluded_parts: set[str]):
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() not in CODE_EXTENSIONS:
            continue
        if has_excluded_part(path, root, excluded_parts):
            continue
        yield path


def count_lines(path: Path) -> int:
    with path.open("r", encoding="utf-8", errors="ignore") as file:
        return sum(1 for _ in file)


def max_line_length(path: Path) -> int:
    max_len = 0
    with path.open("r", encoding="utf-8", errors="ignore") as file:
        for raw_line in file:
            line_len = len(raw_line.rstrip("\r\n"))
            if line_len > max_len:
                max_len = line_len
    return max_len


def lua_nesting(path: Path) -> int:
    depth = 0
    max_depth = 0
    with path.open("r", encoding="utf-8", errors="ignore") as file:
        for raw_line in file:
            line = raw_line.split("--", 1)[0].strip()
            if not line:
                continue
            first = line.replace("(", " ").split()[0] if line.split() else ""
            if first in LUA_CLOSERS or first in LUA_MIDDLES:
                depth = max(0, depth - 1)
            if first in LUA_OPENERS or first in LUA_MIDDLES:
                depth += 1
                max_depth = max(max_depth, depth)
    return max_depth


def python_nesting(path: Path) -> int:
    max_depth = 0
    stack = []
    with path.open("r", encoding="utf-8", errors="ignore") as file:
        for raw_line in file:
            stripped = raw_line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            indent = len(raw_line) - len(raw_line.lstrip(" "))
            while stack and indent <= stack[-1]:
                stack.pop()
            if stripped.endswith(":"):
                stack.append(indent)
                max_depth = max(max_depth, len(stack))
    return max_depth


def nesting_depth(path: Path) -> int:
    if path.suffix.lower() == ".lua":
        return lua_nesting(path)
    if path.suffix.lower() == ".py":
        return python_nesting(path)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="Project root to scan.")
    parser.add_argument("--max-lines", type=int, default=DEFAULT_MAX_LINES)
    parser.add_argument("--max-nesting", type=int, default=DEFAULT_MAX_NESTING)
    parser.add_argument(
        "--max-line-length",
        type=int,
        default=DEFAULT_MAX_LINE_LENGTH,
        help="Maximum allowed single-line length.",
    )
    parser.add_argument(
        "--include-y3-lib",
        action="store_true",
        help="Also scan bundled Y3 libraries and helper metadata.",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve()
    excluded_parts = set(DEFAULT_EXCLUDED_PARTS)
    if args.include_y3_lib:
        excluded_parts.discard("script/y3")
        excluded_parts.discard("script/y3-helper")

    line_violations = []
    nesting_violations = []
    line_length_violations = []
    for path in iter_code_files(root, excluded_parts):
        line_count = count_lines(path)
        if line_count > args.max_lines:
            line_violations.append((line_count, path.relative_to(root).as_posix()))
        single_line_max_len = max_line_length(path)
        if single_line_max_len > args.max_line_length:
            line_length_violations.append(
                (single_line_max_len, path.relative_to(root).as_posix())
            )
        if path.suffix.lower() in NESTING_EXTENSIONS:
            depth = nesting_depth(path)
            if depth > args.max_nesting:
                nesting_violations.append((depth, path.relative_to(root).as_posix()))

    if line_violations:
        print(f"Files over {args.max_lines} lines:")
        for line_count, rel_path in sorted(line_violations, reverse=True):
            print(f"{line_count:5d}  {rel_path}")
    if nesting_violations:
        print(f"Files over {args.max_nesting} nesting levels:")
        for depth, rel_path in sorted(nesting_violations, reverse=True):
            print(f"{depth:5d}  {rel_path}")
    if line_length_violations:
        print(f"Files over {args.max_line_length} single-line length:")
        for max_len, rel_path in sorted(line_length_violations, reverse=True):
            print(f"{max_len:5d}  {rel_path}")
    if line_violations or nesting_violations or line_length_violations:
        return 1

    print(
        f"All scanned code files are <= {args.max_lines} lines "
        f"and <= {args.max_nesting} nesting levels, "
        f"and <= {args.max_line_length} single-line length."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


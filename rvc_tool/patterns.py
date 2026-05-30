"""
patterns.py - Collect a pattern's source files from the testcase tree.
======================================================================

Ported from ``create_list.csh`` + the source-reading part of
``gen_pattern_description_no_comp.pl``. Given one or more base directories that
contain pattern folders, build an index ``folder_name -> folder_path`` and, for
any pattern, return its source files in the canonical order:

    1. program source : .s / .asm / .c / .S   (only the first kind found)
    2. stimulus        : *.v
    3. assertion       : *.sv

plus any shared ``common/`` files. File contents are read (optionally
truncated) so they can be embedded into the HTML detail view and the Excel
report.
"""
from __future__ import annotations

import os
from typing import Dict, List, Optional

# Extension -> logical kind shown in the UI.
_PROG_EXTS = (".s", ".asm", ".c", ".S")
KIND_BY_EXT = {
    ".s": "asm", ".asm": "asm", ".c": "c", ".S": "asm",
    ".v": "stimulus", ".sv": "assertion",
    ".h": "header", ".inc": "include", ".ld": "linker",
}

# Cap a single file so one huge log-like source cannot blow up the data file.
DEFAULT_MAX_BYTES = 200_000


def build_index(base_dirs: List[str], progress=None) -> Dict[str, str]:
    """
    Walk the base directories once and map each pattern folder name to its path.

    A "pattern folder" is any directory that directly contains at least one
    program/stimulus/assertion source file. The first match wins, so list the
    most authoritative testcase tree first.
    """
    def log(msg):
        if progress:
            progress(msg)

    index: Dict[str, str] = {}
    wanted = set(_PROG_EXTS) | {".v", ".sv"}
    for base in base_dirs:
        if not os.path.isdir(base):
            log("[PAT] skip (not a dir): {}".format(base))
            continue
        for root, _dirs, files in os.walk(base):
            if any(os.path.splitext(f)[1] in wanted for f in files):
                name = os.path.basename(root)
                index.setdefault(name, root)
    log("[PAT] indexed {} pattern folder(s)".format(len(index)))
    return index


def _read(path: str, max_bytes: int) -> str:
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            data = fh.read(max_bytes + 1)
    except OSError as e:
        return "<<could not read: {}>>".format(e)
    if len(data) > max_bytes:
        data = data[:max_bytes] + "\n... [truncated]"
    return data


def _ordered_files(folder: str) -> List[str]:
    """Return file names in canonical order (program, then .v, then .sv)."""
    try:
        names = sorted(os.listdir(folder))
    except OSError:
        return []
    prog: List[str] = []
    for ext in _PROG_EXTS:  # only the first program kind present, like create_list.csh
        prog = [n for n in names if n.endswith(ext)]
        if prog:
            break
    v_files = [n for n in names if n.endswith(".v")]
    sv_files = [n for n in names if n.endswith(".sv")]
    ordered = prog + v_files + sv_files
    # De-dup while preserving order.
    seen = set()
    out = []
    for n in ordered:
        if n not in seen and os.path.isfile(os.path.join(folder, n)):
            seen.add(n)
            out.append(n)
    return out


def collect_pattern_files(
    name: str,
    index: Dict[str, str],
    max_bytes: int = DEFAULT_MAX_BYTES,
    include_content: bool = True,
) -> List[dict]:
    """
    Return ``[{"file", "path", "ext", "kind", "content"}]`` for one pattern.
    Empty list if the pattern folder is not found.
    """
    folder = index.get(name)
    if not folder:
        return []
    out = []
    for fname in _ordered_files(folder):
        path = os.path.join(folder, fname)
        ext = os.path.splitext(fname)[1]
        entry = {
            "file": fname,
            "path": path,
            "ext": ext,
            "kind": KIND_BY_EXT.get(ext, "other"),
        }
        if include_content:
            entry["content"] = _read(path, max_bytes)
        out.append(entry)
    return out


def collect_common_files(
    base_dirs: List[str],
    max_bytes: int = DEFAULT_MAX_BYTES,
    include_content: bool = True,
) -> List[dict]:
    """Collect shared ``common*/`` source files (headers, libs, includes)."""
    out: List[dict] = []
    seen = set()
    keep_ext = {".v", ".sv", ".h", ".inc", ".ld", ".c", ".s", ".S", ".asm"}
    for base in base_dirs:
        if not os.path.isdir(base):
            continue
        for root, _dirs, files in os.walk(base):
            if "common" not in os.path.basename(root).lower():
                continue
            for fname in sorted(files):
                ext = os.path.splitext(fname)[1]
                if ext not in keep_ext:
                    continue
                path = os.path.join(root, fname)
                if path in seen:
                    continue
                seen.add(path)
                entry = {
                    "file": fname,
                    "path": path,
                    "ext": ext,
                    "kind": KIND_BY_EXT.get(ext, "other"),
                }
                if include_content:
                    entry["content"] = _read(path, max_bytes)
                out.append(entry)
    return out

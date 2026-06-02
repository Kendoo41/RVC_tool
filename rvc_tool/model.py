"""
model.py - Join the four data sources into one unified view.
============================================================

Everything keys off the bare pattern name. This module merges:

  * list-file membership + per-pattern sim options  (listfile.py)
  * priority + checkpoints from the VIL              (vil.py)
  * PASS / FAIL / NA / MISSING status                (master_report.py)
  * source files + content                           (patterns.py)

into :class:`Pattern` objects and :class:`ListGroup` groupings that the HTML
and Excel reporters consume.
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Dict, List, Optional

from . import listfile as lf
from . import master_report as mr
from . import patterns as pat
from . import vil as vilmod

# Sort weight so high-priority / failing patterns float to the top.
PRIORITY_ORDER = {"S": 0, "A": 1, "B": 2, "": 3}
STATUS_ORDER = {"FAIL": 0, "NA": 1, "MISSING": 2, "PASS": 3}


@dataclass
class Pattern:
    name: str
    priority: str = ""
    status: str = mr.MISSING
    lists: List[str] = field(default_factory=list)        # list-file labels it appears in
    options: str = ""                                     # sim options from the list file
    checkpoints: List[dict] = field(default_factory=list)  # from VIL usages
    files: List[dict] = field(default_factory=list)        # from pattern source tree
    rpt: str = ""                                          # winning report file
    rpt_dir: str = ""
    hierarchy: str = ""                                    # full list-file token (HBUS_TOP/.../name)
    run_line: str = ""                                     # full logical line (hierarchy + options) for re-running
    in_vil: bool = False                                   # appears in at least one VIL workbook

    @property
    def has_detail(self) -> bool:
        return bool(self.checkpoints or self.files)

    @property
    def in_list(self) -> bool:
        return bool(self.lists)

    @property
    def in_list_view(self) -> bool:
        # The list viewpoint = patterns that are in a list file OR have a report
        # result. VIL-only items (planned but never listed/run) are excluded so
        # they don't inflate the list-view scoreboard; they live in the VIL view.
        return self.in_list or self.status != mr.MISSING

    def sort_key(self):
        return (
            STATUS_ORDER.get(self.status, 9),
            PRIORITY_ORDER.get(self.priority, 9),
            self.name.lower(),
        )


@dataclass
class ListGroup:
    label: str
    path: str
    patterns: List[Pattern] = field(default_factory=list)

    def counts(self) -> Dict[str, int]:
        c = {"PASS": 0, "FAIL": 0, "NA": 0, "MISSING": 0}
        for p in self.patterns:
            c[p.status] = c.get(p.status, 0) + 1
        return c


@dataclass
class VilGroup:
    """A priority bucket of the VIL viewpoint (S / A / B / no-priority)."""
    priority: str
    patterns: List[Pattern] = field(default_factory=list)


@dataclass
class Dataset:
    groups: List[ListGroup]
    patterns: Dict[str, Pattern]    # name -> Pattern (the canonical objects)
    report_dirs: List[str] = field(default_factory=list)
    unlisted: List[Pattern] = field(default_factory=list)
    vil_groups: List[VilGroup] = field(default_factory=list)  # VIL viewpoint, by priority

    def totals(self) -> Dict[str, int]:
        """Status totals over the LIST viewpoint (patterns in a list or report)."""
        c = {"PASS": 0, "FAIL": 0, "NA": 0, "MISSING": 0, "TOTAL": 0}
        for p in self.patterns.values():
            if not p.in_list_view:
                continue  # VIL-only items belong to the VIL view, not here
            c[p.status] = c.get(p.status, 0) + 1
            c["TOTAL"] += 1
        return c

    def vil_totals(self) -> Dict[str, int]:
        """Coverage + status totals over the VIL viewpoint (every planned item)."""
        c = {"TOTAL": 0, "LISTED": 0, "NOT_LISTED": 0,
             "PASS": 0, "FAIL": 0, "NA": 0, "MISSING": 0}
        for p in self.patterns.values():
            if not p.in_vil:
                continue
            c["TOTAL"] += 1
            c["LISTED" if p.in_list else "NOT_LISTED"] += 1
            c[p.status] = c.get(p.status, 0) + 1
        return c


def build_dataset(
    list_files: List[str],
    vil_info: Optional[Dict[str, dict]] = None,
    reports: Optional[Dict[str, dict]] = None,
    pattern_index: Optional[Dict[str, str]] = None,
    report_dirs: Optional[List[str]] = None,
    include_unlisted: bool = True,
    max_file_bytes: int = pat.DEFAULT_MAX_BYTES,
    include_content: bool = True,
    progress=None,
) -> Dataset:
    """Merge all sources into a :class:`Dataset`."""
    def log(msg):
        if progress:
            progress(msg)

    vil_info = vil_info or {}
    reports = reports or {}
    pattern_index = pattern_index or {}

    patterns: Dict[str, Pattern] = {}

    def get(name: str) -> Pattern:
        p = patterns.get(name)
        if p is None:
            p = Pattern(name=name)
            # priority + checkpoints from VIL
            v = vil_info.get(name)
            if v:
                p.in_vil = True
                p.priority = v.get("priority", "") or ""
                p.checkpoints = list(v.get("usages", []))
            # status from report
            r = reports.get(name)
            if r:
                p.status = r.get("status", mr.MISSING)
                p.rpt = r.get("rpt", "")
                p.rpt_dir = r.get("rpt_dir", "")
            # source files
            if pattern_index:
                p.files = pat.collect_pattern_files(
                    name, pattern_index,
                    max_bytes=max_file_bytes, include_content=include_content,
                )
            patterns[name] = p
        return p

    groups: List[ListGroup] = []
    claimed = set()
    for path in list_files:
        label = os.path.basename(path)
        entries = lf.parse_listfile(path)
        group = ListGroup(label=label, path=path)
        seen = set()
        for e in entries:
            if not e.is_pattern or e.name in seen:
                continue
            seen.add(e.name)
            claimed.add(e.name)
            p = get(e.name)
            if label not in p.lists:
                p.lists.append(label)
            if e.options and not p.options:
                p.options = e.options
            if not p.hierarchy and e.hierarchy:
                p.hierarchy = e.hierarchy
            if not p.run_line and e.logical:
                p.run_line = e.logical
            group.patterns.append(p)
        group.patterns.sort(key=lambda x: x.sort_key())
        groups.append(group)
        log("[MODEL] list {}: {} pattern(s)".format(label, len(group.patterns)))

    # VIL viewpoint: materialise EVERY planned VIL item, even those that are in
    # no list file and have no report line. Without this they would silently
    # vanish - exactly the coverage gap the VIL view exists to surface.
    for name in vil_info:
        get(name)  # creates (with in_vil=True) if not already seen via a list/report

    # Unlisted: tests present in the report but not in any list file.
    unlisted: List[Pattern] = []
    if include_unlisted:
        for name in reports:
            if name not in claimed:
                unlisted.append(get(name))
        unlisted.sort(key=lambda x: x.sort_key())

    # Group the VIL viewpoint by priority (S / A / B / none).
    vil_groups: List[VilGroup] = []
    for bucket in ("S", "A", "B", ""):
        members = [p for p in patterns.values() if p.in_vil and (p.priority or "") == bucket]
        if members:
            members.sort(key=lambda x: x.sort_key())
            vil_groups.append(VilGroup(priority=bucket, patterns=members))

    return Dataset(
        groups=groups,
        patterns=patterns,
        report_dirs=report_dirs or [],
        unlisted=unlisted,
        vil_groups=vil_groups,
    )


# ---------------------------------------------------------------------------
# Priority item lists (S_item.list / A_item.list / B_item.list) from the VIL.
# ---------------------------------------------------------------------------
def priority_item_lists(vil_info: Dict[str, dict]) -> Dict[str, List[str]]:
    """Group pattern names by VIL priority -> {"S": [...], "A": [...], "B": [...]}."""
    out: Dict[str, List[str]] = {"S": [], "A": [], "B": []}
    for name, info in vil_info.items():
        prio = (info.get("priority") or "").upper()
        if prio in out:
            out[prio].append(name)
    for k in out:
        out[k].sort(key=str.lower)
    return out

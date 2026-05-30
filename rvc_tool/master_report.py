"""
master_report.py - Parse simulation result reports (.rpt).
==========================================================

Ported from ``watchdog_2.sh``. Each ``.rpt`` file contains result lines like::

    [OK]   (12:01:33) some/path/testcase_name --fsimopts ...
    [NG]   (12:05:10) some/path/another_test  --fsimopts ...
    [N/A]  (12:06:01) some/path/compile_fail  --fsimopts ...

Mapping:

    [OK]  -> PASS
    [NG]  -> FAIL
    [N/A] -> NA       (ran but failed at compile)
    (absent from every report) -> MISSING ("-", not run yet)

The bare test name is the last ``/`` component of the path, with trailing
``--options`` stripped. When the same test appears in several reports the
**newest** ``.rpt`` (by mtime) wins, exactly like the original watchdog.
"""
from __future__ import annotations

import glob
import os
import re
from typing import Dict, List

PASS, FAIL, NA, MISSING = "PASS", "FAIL", "NA", "MISSING"

# [OK] / [NG] / [N/A] possibly indented, then "(HH:MM:SS)" then the path.
_LINE_RE = re.compile(
    r"^\s*\[(?P<tag>OK|NG|N/A)\]\s*"
    r"(?:\([0-9:]*\)\s*)?"
    r"(?P<rest>\S.*?)\s*$"
)
_TAG_STATUS = {"OK": PASS, "NG": FAIL, "N/A": NA}


def _test_name(rest: str) -> str:
    """'some/path/name --fsimopts ...' -> 'name'."""
    # Drop options: everything from the first ' --' (or ' -opt').
    cut = re.split(r"\s+-{1,2}\w", rest, maxsplit=1)[0].strip()
    if not cut:
        cut = rest.strip()
    token = cut.split()[0] if cut.split() else cut
    return token.rstrip("/").split("/")[-1]


def parse_reports(report_dirs: List[str], progress=None) -> Dict[str, dict]:
    """
    Scan ``*.rpt`` files in each directory and return::

        {test_name: {"status", "rpt", "rpt_dir", "mtime"}}

    Newest report wins on duplicate test names.
    """
    def log(msg):
        if progress:
            progress(msg)

    # Collect (mtime, path) for every .rpt, oldest first so newer overwrites.
    rpts: List[tuple] = []
    for d in report_dirs:
        if not os.path.isdir(d):
            log("[RPT] skip (not a dir): {}".format(d))
            continue
        for p in glob.glob(os.path.join(d, "*.rpt")):
            try:
                rpts.append((os.path.getmtime(p), p))
            except OSError:
                continue
    rpts.sort(key=lambda x: x[0])  # oldest -> newest

    result: Dict[str, dict] = {}
    nfiles = 0
    for mtime, path in rpts:
        nfiles += 1
        rpt_dir = os.path.basename(os.path.dirname(path))
        rpt_base = os.path.basename(path)
        try:
            fh = open(path, "r", encoding="utf-8", errors="replace")
        except OSError:
            continue
        with fh:
            for line in fh:
                m = _LINE_RE.match(line)
                if not m:
                    continue
                status = _TAG_STATUS.get(m.group("tag"))
                if status is None:
                    continue
                name = _test_name(m.group("rest"))
                if not name:
                    continue
                # newer file processed later -> overwrites older entry
                result[name] = {
                    "status": status,
                    "rpt": rpt_base,
                    "rpt_dir": rpt_dir,
                    "mtime": mtime,
                }

    log("[RPT] {} test result(s) from {} report file(s)".format(len(result), nfiles))
    return result


def status_map(reports: Dict[str, dict]) -> Dict[str, str]:
    """Flatten parsed reports to ``{test_name: status}``."""
    return {k: v["status"] for k, v in reports.items()}

"""
config.py - Load / merge tool configuration.
============================================

Configuration is a small JSON file (stdlib only - no PyYAML needed). All keys
are optional; CLI flags override file values. See ``examples/rvc.example.json``.
"""
from __future__ import annotations

import json
import os
from typing import Any, Dict, List

DEFAULTS: Dict[str, Any] = {
    # data sources
    "report_dirs": [],        # dirs holding *.rpt master-report files
    "list_files": [],         # sim/item .list files to group by
    "vil_dir": "",            # dir of *.xlsx VILs (or use vil_files)
    "vil_files": [],          # explicit VIL files (overrides vil_dir if set)
    "pattern_dirs": [],       # testcase trees holding pattern source folders
    # output
    "output_dir": "rvc_out",
    "html_name": "report.html",
    "excel_name": "rvc_review.xlsx",
    "title": "RVC Verification Dashboard",
    # behaviour
    "include_content": True,   # embed source content into the data file / excel
    "include_unlisted": True,  # show report tests not present in any list
    "max_file_bytes": 200000,  # per-source-file cap
}


def load_config(path: str = None) -> Dict[str, Any]:
    """Return DEFAULTS merged with the JSON file at ``path`` (if given)."""
    cfg = dict(DEFAULTS)
    if path:
        if not os.path.isfile(path):
            raise FileNotFoundError("config not found: {}".format(path))
        with open(path, "r", encoding="utf-8") as fh:
            user = json.load(fh)
        for k, v in user.items():
            cfg[k] = v
    return cfg


def merge_overrides(cfg: Dict[str, Any], **overrides) -> Dict[str, Any]:
    """Apply non-None CLI overrides on top of ``cfg`` (returns a new dict)."""
    out = dict(cfg)
    for k, v in overrides.items():
        if v is None:
            continue
        if isinstance(v, (list, tuple)) and len(v) == 0:
            continue
        out[k] = v
    return out


def vil_files(cfg: Dict[str, Any]) -> List[str]:
    """Resolve the list of VIL files from config (vil_files or vil_dir/*.xls*)."""
    if cfg.get("vil_files"):
        return list(cfg["vil_files"])
    d = cfg.get("vil_dir")
    if d and os.path.isdir(d):
        import glob
        files = sorted(glob.glob(os.path.join(d, "*.xls*")))
        return [f for f in files if not os.path.basename(f).startswith("~$")]
    return []

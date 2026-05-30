"""
listfile.py - Parse and update simulation list files.
=====================================================

A *list file* is what gets dropped into the simulator. It mixes three kinds of
lines:

    --no-clean                                  <- global option (starts with -/--)
    --fsimopts -define FAST_SIM                 <- global option
    # set default option                        <- plain comment
    #=========== PE0INST ===========            <- plain comment
    HBUS_TOP/.../Single/cpuss_addr_spi0 --fsimopts ...   <- ACTIVE pattern line
    #INT_TOP/INT_intif_reg_init_cx_debug --fsimopts ...  <- user-commented pattern
    #PSS HBUS_TOP/.../cpuss_addr_c0ram --fsimopts ...     <- pattern WE commented (status PSS)

The bare *pattern name* is the last ``/`` component of the first whitespace
token (``cpuss_addr_spi0``). That bare name is the universal join key against the
master report, the VIL and the pattern source directory.

This module replaces ``05_filter_pa_ng_pattern.csh``. The old script needed the
caller to pass the top module (``HBUS_TOP``) so it knew where each pattern line
started. Here we detect pattern lines automatically:

  * skip blank lines,
  * skip option lines (first token starts with ``-``),
  * skip plain comments,
  * everything else whose first token looks like a pattern path is a pattern.

So ``rvc filter <listfile>`` needs no module argument.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Dict, List, Optional

# Status tags written at the start of a commented pattern line. Keep them short
# and fixed-width so the file stays aligned and round-trips cleanly.
STATUS_TAG = {
    "PASS": "PSS",
    "FAIL": "NG",
    "NA": "NA",
    "MISSING": "MIS",
    "SKIP": "SKP",
}
TAG_STATUS = {v: k for k, v in STATUS_TAG.items()}

# Marker that begins a line we previously commented out: ``#PSS `` / ``#NG  `` ...
_MARKER_RE = re.compile(r"^(#+)\s*(PSS|NG|NA|MIS|SKP)\s+(?P<body>\S.*?)\s*$")
# A plausible pattern token: starts with alnum/underscore, may contain / . -
_NAME_TOKEN_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_./\-]*$")

# Line kinds
BLANK = "blank"
COMMENT = "comment"
OPTION = "option"
PATTERN = "pattern"


@dataclass
class ListEntry:
    """One physical line of a list file, classified."""

    lineno: int
    raw: str  # original line WITHOUT trailing newline
    kind: str  # BLANK | COMMENT | OPTION | PATTERN
    commented: bool = False
    status_tag: Optional[str] = None  # canonical status if line carries our marker
    hierarchy: str = ""  # full first token, e.g. HBUS_TOP/.../name
    name: str = ""  # bare pattern name, e.g. name
    options: str = ""  # everything after the first token (sim options)
    logical: str = ""  # uncommented logical content (hierarchy + options)

    @property
    def is_pattern(self) -> bool:
        return self.kind == PATTERN


def _bare_name(token: str) -> str:
    """Strip hierarchy: HBUS_TOP/A/B/name -> name."""
    return token.rstrip("/").split("/")[-1]


def classify_line(raw: str, lineno: int = 0) -> ListEntry:
    """Classify a single raw list-file line (newline already stripped)."""
    s = raw.strip()

    if s == "":
        return ListEntry(lineno, raw, BLANK)

    # 1) A line we previously commented out: "#PSS <pattern> <opts>"
    m = _MARKER_RE.match(raw)
    if m:
        body = m.group("body")
        tok = body.split()[0]
        if _NAME_TOKEN_RE.match(tok):
            opts = body[len(tok):].strip()
            return ListEntry(
                lineno, raw, PATTERN,
                commented=True,
                status_tag=TAG_STATUS.get(m.group(2)),
                hierarchy=tok, name=_bare_name(tok), options=opts,
                logical=body,
            )

    # 2) Other comment lines
    if s.startswith("#"):
        inner = s.lstrip("#").strip()
        if inner == "":
            return ListEntry(lineno, raw, COMMENT)
        tok = inner.split()[0]
        # A commented-out pattern only if the token carries a hierarchy ("/")
        # and is not itself an option. This keeps "# set default option" a
        # plain comment while "#INT_TOP/foo --opts" is a (user) commented pattern.
        if "/" in tok and not tok.startswith("-") and _NAME_TOKEN_RE.match(tok):
            opts = inner[len(tok):].strip()
            return ListEntry(
                lineno, raw, PATTERN,
                commented=True, status_tag=None,
                hierarchy=tok, name=_bare_name(tok), options=opts,
                logical=inner,
            )
        return ListEntry(lineno, raw, COMMENT)

    # 3) Active option line (-fcc, --no_compile, --fsimopts ...)
    if s.startswith("-"):
        return ListEntry(lineno, raw, OPTION)

    # 4) Active pattern line
    tok = s.split()[0]
    if not _NAME_TOKEN_RE.match(tok):
        # Unknown / weird line - treat as comment so we never touch it.
        return ListEntry(lineno, raw, COMMENT)
    opts = s[len(tok):].strip()
    return ListEntry(
        lineno, raw, PATTERN,
        commented=False, status_tag=None,
        hierarchy=tok, name=_bare_name(tok), options=opts,
        logical=s,
    )


def parse_listfile(path: str) -> List[ListEntry]:
    """Parse a list file into classified entries."""
    entries: List[ListEntry] = []
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for i, line in enumerate(fh, start=1):
            entries.append(classify_line(line.rstrip("\n"), i))
    return entries


def pattern_names(entries: List[ListEntry], include_commented: bool = True) -> List[str]:
    """Ordered, de-duplicated bare pattern names found in a list file."""
    seen = set()
    out = []
    for e in entries:
        if not e.is_pattern:
            continue
        if e.commented and not include_commented:
            continue
        if e.name not in seen:
            seen.add(e.name)
            out.append(e.name)
    return out


def _format_commented(status: str, logical: str) -> str:
    """Render a commented pattern line: '#PSS <logical>'."""
    tag = STATUS_TAG.get(status, "SKP")
    return "#{:<3} {}".format(tag, logical)


@dataclass
class UpdateResult:
    commented: Dict[str, int] = field(default_factory=dict)  # status -> count newly commented
    reactivated: int = 0  # lines uncommented (status no longer in comment set)
    unchanged: int = 0
    untouched_user_comments: int = 0
    new_lines: List[str] = field(default_factory=list)

    def summary(self) -> str:
        parts = []
        for st in ("PASS", "FAIL", "NA", "MISSING"):
            n = self.commented.get(st, 0)
            if n:
                parts.append("{}={}".format(STATUS_TAG.get(st, st), n))
        head = "commented[" + " ".join(parts) + "]" if parts else "commented[0]"
        return "{} reactivated={} unchanged={}".format(head, self.reactivated, self.unchanged)


def update_listfile(
    path: str,
    status_map: Dict[str, str],
    comment_statuses=("PASS", "FAIL", "NA"),
    restore: bool = False,
    write: bool = True,
) -> UpdateResult:
    """
    Comment / un-comment pattern lines according to their status.

    * ``status_map``    : bare pattern name -> status (PASS/FAIL/NA/MISSING).
    * ``comment_statuses``: statuses whose patterns get commented out (so a
      re-run skips them). Default mirrors ``05_filter``: comment everything
      already attempted (PASS+FAIL+NA), leaving only not-yet-run patterns
      active.
    * ``restore``       : ignore status; un-comment every line WE commented
      (lines carrying our #PSS/#NG/#NA marker) and leave plain user comments.
    * ``write``         : when False, only compute the result (dry run).

    Returns an :class:`UpdateResult`. Lines the user commented by hand (plain
    ``#pattern`` without our marker) are never modified.
    """
    comment_set = set(comment_statuses)
    res = UpdateResult()
    entries = parse_listfile(path)
    out_lines: List[str] = []

    for e in entries:
        new_line = e.raw

        if e.is_pattern:
            status = status_map.get(e.name)

            if restore:
                # Only touch lines WE commented (status_tag set).
                if e.commented and e.status_tag is not None:
                    new_line = e.logical
                    res.reactivated += 1
                else:
                    res.unchanged += 1
            elif e.commented and e.status_tag is None:
                # User-commented by hand - respect it.
                res.untouched_user_comments += 1
            elif status is None:
                # No status info (e.g. not in report). Leave as-is.
                res.unchanged += 1
            elif status in comment_set:
                desired = _format_commented(status, e.logical)
                if desired == e.raw:
                    res.unchanged += 1
                else:
                    new_line = desired
                    res.commented[status] = res.commented.get(status, 0) + 1
            else:
                # Keep active: un-comment if we had commented it.
                if e.commented and e.status_tag is not None:
                    new_line = e.logical
                    res.reactivated += 1
                else:
                    res.unchanged += 1

        out_lines.append(new_line)

    res.new_lines = out_lines

    if write:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write("\n".join(out_lines))
            fh.write("\n")

    return res

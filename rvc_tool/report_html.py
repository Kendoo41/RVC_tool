"""
report_html.py - Build the interactive dashboard.
=================================================

Extends the original ``check_result`` (watchdog) dashboard:

  * keeps the dark theme, scoreboard, per-list sections, filters and search,
  * adds a **Priority** column (S/A/B from the VIL),
  * makes every row clickable -> a slide-in **detail drawer** that shows the
    VIL checkpoints and the pattern's source files.

Per the chosen packaging, the page itself stays light: the table rows are
rendered server-side, while the heavy per-pattern detail lives in a companion
``<output>_data.js`` (loaded as ``window.__RVC_DATA__`` so it works straight
off a file:// double-click) and an equivalent ``<output>_data.json`` for AI /
programmatic use. The drawer reads from whichever is available.
"""
from __future__ import annotations

import datetime
import html
import json
import os
from typing import Dict, List

from .model import Dataset, Pattern

_STATUS_DISP = {"PASS": "PASS", "FAIL": "FAIL", "NA": "N/A", "MISSING": "&mdash;"}
_STATUS_BADGE = {"PASS": "badge-pass", "FAIL": "badge-fail", "NA": "badge-na", "MISSING": "badge-miss"}


def _esc(s) -> str:
    return html.escape(str(s if s is not None else ""), quote=True)


def _safe_id(s: str) -> str:
    return "".join(ch if ch.isalnum() else "_" for ch in s)


def _detail_payload(p: Pattern, include_content: bool) -> dict:
    files = []
    for f in p.files:
        item = {"file": f.get("file", ""), "kind": f.get("kind", ""), "ext": f.get("ext", "")}
        if include_content:
            item["content"] = f.get("content", "")
        files.append(item)
    return {
        "priority": p.priority,
        "status": p.status,
        "lists": p.lists,
        "options": p.options,
        "rpt": p.rpt,
        "rpt_dir": p.rpt_dir,
        "checkpoints": [
            {
                "main": c.get("main", ""),
                "middle": c.get("middle", ""),
                "detailed": c.get("detailed", ""),
                "confirmation": c.get("confirmation", ""),
                "file_name": c.get("file_name", ""),
                "sheet": c.get("sheet", ""),
                "row": c.get("row", ""),
            }
            for c in p.checkpoints
        ],
        "files": files,
    }


def build_data(ds: Dataset, include_content: bool = True) -> Dict[str, dict]:
    """The full ``{name: detail}`` payload for the companion data file."""
    return {name: _detail_payload(p, include_content) for name, p in ds.patterns.items()}


def _prio_badge(prio: str) -> str:
    if prio in ("S", "A", "B"):
        return '<span class="prio prio-{p}">{p}</span>'.format(p=prio)
    return '<span class="prio prio-none">&middot;</span>'


def _row(p: Pattern) -> str:
    badge = _STATUS_BADGE.get(p.status, "badge-miss")
    disp = _STATUS_DISP.get(p.status, "&mdash;")
    src = ""
    if p.rpt:
        src = '<span class="src-tag" title="{}/{}">{}</span>'.format(
            _esc(p.rpt_dir), _esc(p.rpt), _esc(p.rpt))
    detail_cls = " has-detail" if p.has_detail else ""
    cp = len(p.checkpoints)
    nf = len(p.files)
    detail_hint = ""
    if p.has_detail:
        detail_hint = '<span class="dhint">{}cp&middot;{}f</span>'.format(cp, nf)
    return (
        '<tr class="prow{dc}" data-name="{name}" data-status="{status}" data-prio="{prio}">'
        '<td class="test-label">{name}{hint}</td>'
        '<td class="prio-cell">{pb}</td>'
        '<td><span class="badge {badge}">{disp}</span>{src}</td>'
        "</tr>"
    ).format(
        dc=detail_cls, name=_esc(p.name), status=p.status, prio=p.priority or "",
        hint=detail_hint, pb=_prio_badge(p.priority), badge=badge, disp=disp, src=src,
    )


def _section(label: str, patterns: List[Pattern], is_list: bool, list_id: str) -> str:
    pass_ = sum(1 for p in patterns if p.status == "PASS")
    fail = sum(1 for p in patterns if p.status == "FAIL")
    na = sum(1 for p in patterns if p.status == "NA")
    miss = sum(1 for p in patterns if p.status == "MISSING")
    total = len(patterns)
    if total == 0:
        return ""
    counted = pass_ + fail + na or 1
    wp, wf, wn = int(pass_ * 100 / counted), int(fail * 100 / counted), int(na * 100 / counted)

    hdr = "file-header"
    if fail > 0:
        hdr += " has-fail"
    if miss > 0:
        hdr += " has-missing"
    if fail == 0 and miss == 0:
        hdr += " all-pass"

    safe = _safe_id(list_id)
    list_tag = '<span class="list-badge">LIST</span>' if is_list else ""
    miss_stat = '<span class="stat s-miss">&#63; {}</span>'.format(miss) if miss else ""

    rows = "\n".join(_row(p) for p in patterns)
    return """<section class="file-block" data-list-id="{safe}">
  <div class="{hdr}">
    <div class="file-title">
      <span class="file-icon">&#9654;</span>
      {list_tag}
      <span class="list-name">{label}</span>
    </div>
    <div class="file-meta">
      <span class="stat s-pass">&#10003; {pass_}</span>
      <span class="stat s-fail">&#10007; {fail}</span>
      <span class="stat s-na">&#9644; {na}</span>
      {miss_stat}
    </div>
  </div>
  <div class="health-bar">
    <div class="hb-pass" style="width:{wp}%"></div>
    <div class="hb-fail" style="width:{wf}%"></div>
    <div class="hb-na"   style="width:{wn}%"></div>
  </div>
  <table class="result-table">
    <thead><tr><th>Test Name</th><th>Prio</th><th>Result</th></tr></thead>
    <tbody>
{rows}
    </tbody></table></section>""".format(
        safe=safe, hdr=hdr, list_tag=list_tag, label=_esc(label),
        pass_=pass_, fail=fail, na=na, miss_stat=miss_stat,
        wp=wp, wf=wf, wn=wn, rows=rows,
    )


def generate(
    ds: Dataset,
    out_html: str,
    title: str = "RVC Verification Dashboard",
    include_content: bool = True,
    show_unlisted: bool = True,
) -> Dict[str, str]:
    """
    Write ``out_html`` plus its companion data files and return the paths
    written: ``{"html", "js", "json"}``.
    """
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    out_dir = os.path.dirname(os.path.abspath(out_html))
    base = os.path.splitext(os.path.basename(out_html))[0]
    data_js = base + "_data.js"
    data_json = base + "_data.json"

    totals = ds.totals()
    tt = totals["TOTAL"] or 1
    ow_p = int(totals["PASS"] * 100 / tt)
    ow_f = int(totals["FAIL"] * 100 / tt)
    ow_n = int(totals["NA"] * 100 / tt)

    dir_badges = " ".join(
        "<span class='dir-badge'>{}</span>".format(_esc(os.path.basename(d)))
        for d in ds.report_dirs
    )

    # List-visibility checkboxes
    cb_items = []
    for g in ds.groups:
        safe = _safe_id(g.label)
        cb_items.append(
            '<label class="cb-item" title="{lbl}">'
            '<input type="checkbox" class="list-toggle" data-target="{safe}" checked>'
            '<span class="cb-name">{lbl}</span></label>'.format(lbl=_esc(g.label), safe=safe)
        )
    if show_unlisted and ds.unlisted:
        cb_items.append(
            '<label class="cb-item" title="Unlisted Tests">'
            '<input type="checkbox" class="list-toggle" data-target="__unlisted__" checked>'
            '<span class="cb-name">Unlisted Tests</span></label>'
        )
    cb_html = "\n".join(cb_items)

    sections = [_section(g.label, g.patterns, True, g.label) for g in ds.groups]
    if show_unlisted and ds.unlisted:
        sections.append(_section("Unlisted Tests", ds.unlisted, False, "__unlisted__"))
    sections_html = "\n".join(s for s in sections if s)

    n_lists = len(ds.groups)
    page = _PAGE_TEMPLATE.format(
        title=_esc(title),
        css=_CSS,
        dir_badges=dir_badges,
        ts=_esc(ts),
        total=totals["TOTAL"], npass=totals["PASS"], nfail=totals["FAIL"], nna=totals["NA"],
        nmiss=totals["MISSING"],
        ow_p=ow_p, ow_f=ow_f, ow_n=ow_n,
        n_lists=n_lists,
        cb_items=cb_html,
        sections=sections_html,
        data_js=_esc(data_js),
        data_json=_esc(data_json),
        script=_SCRIPT,
    )

    with open(out_html, "w", encoding="utf-8") as fh:
        fh.write(page)

    payload = build_data(ds, include_content=include_content)
    json_text = json.dumps(payload, ensure_ascii=False, indent=0)
    with open(os.path.join(out_dir, data_json), "w", encoding="utf-8") as fh:
        fh.write(json_text)
    with open(os.path.join(out_dir, data_js), "w", encoding="utf-8") as fh:
        fh.write("window.__RVC_DATA__ = ")
        fh.write(json_text)
        fh.write(";\n")

    return {
        "html": os.path.abspath(out_html),
        "js": os.path.join(out_dir, data_js),
        "json": os.path.join(out_dir, data_json),
    }


# ===========================================================================
# Static assets
# ===========================================================================
_CSS = """
@import url('https://fonts.googleapis.com/css2?family=Share+Tech+Mono&family=Rajdhani:wght@400;600;700&display=swap');
:root{--bg:#0d0f14;--surface:#141720;--border:#1e2535;
  --pass:#00e676;--fail:#ff1744;--na:#546e7a;--miss:#f59e0b;
  --accent:#00b0ff;--text:#cdd6f4;--muted:#4a5568;--header-bg:#10131a;
  --prio-s:#ff4081;--prio-a:#ffb300;--prio-b:#26c6da;}
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
body{background:var(--bg);color:var(--text);font-family:'Rajdhani',sans-serif;font-size:15px;min-height:100vh}
body::before{content:'';position:fixed;inset:0;pointer-events:none;z-index:1;
  background:repeating-linear-gradient(0deg,transparent,transparent 2px,rgba(0,0,0,.07) 2px,rgba(0,0,0,.07) 4px)}
header{background:var(--header-bg);border-bottom:2px solid var(--accent);
  padding:16px 28px;display:flex;align-items:center;justify-content:space-between;
  position:sticky;top:0;z-index:100;flex-wrap:wrap;gap:8px}
.logo-main{font-family:'Share Tech Mono',monospace;font-size:1.3rem;color:var(--accent);
  letter-spacing:2px;text-transform:uppercase}
.logo-sub{font-size:.75rem;color:var(--muted);letter-spacing:1px;margin-left:10px}
.header-right{display:flex;align-items:center;gap:10px;flex-wrap:wrap}
.last-update{font-size:.75rem;color:var(--muted);font-family:'Share Tech Mono',monospace}
.dir-badge{background:rgba(0,176,255,.1);border:1px solid rgba(0,176,255,.25);
  color:var(--accent);font-size:.68rem;padding:2px 8px;border-radius:3px;font-family:'Share Tech Mono',monospace}
.global-bar{display:flex;height:5px;background:var(--border)}
.gb-pass{background:var(--pass)}.gb-fail{background:var(--fail)}.gb-na{background:var(--na)}
.scoreboard{display:grid;grid-template-columns:repeat(auto-fit,minmax(120px,1fr));
  gap:1px;background:var(--border);border-bottom:1px solid var(--border)}
.score-card{background:var(--surface);padding:16px 18px;text-align:center}
.score-num{font-family:'Share Tech Mono',monospace;font-size:2.2rem;line-height:1}
.score-label{font-size:.7rem;letter-spacing:2px;text-transform:uppercase;color:var(--muted);margin-top:4px}
.sc-pass .score-num{color:var(--pass)}.sc-fail .score-num{color:var(--fail)}
.sc-na .score-num{color:var(--na)}.sc-miss .score-num{color:var(--miss)}.sc-total .score-num{color:var(--accent)}
main{padding:24px 28px;max-width:1100px;margin:0 auto;position:relative;z-index:2}
.section-heading{font-family:'Share Tech Mono',monospace;font-size:.67rem;letter-spacing:3px;
  text-transform:uppercase;color:var(--muted);margin-bottom:12px;border-left:3px solid var(--accent);padding-left:10px}
.file-block{background:var(--surface);border:1px solid var(--border);border-radius:4px;
  margin-bottom:14px;overflow:hidden;transition:border-color .2s}
.file-block:hover{border-color:var(--accent)}
.file-block.list-hidden{display:none}
.file-header{padding:12px 16px;display:flex;align-items:center;justify-content:space-between;
  flex-wrap:wrap;gap:8px;background:rgba(255,255,255,.02);cursor:pointer;border-bottom:1px solid var(--border);user-select:none}
.file-header.has-fail{border-left:3px solid var(--fail)}
.file-header.has-missing:not(.has-fail){border-left:3px solid var(--miss)}
.file-header.all-pass{border-left:3px solid var(--pass)}
.file-title{display:flex;align-items:center;gap:8px}
.file-icon{color:var(--accent);font-size:.78rem;transition:transform .2s;display:inline-block}
.file-block.collapsed .file-icon{transform:rotate(-90deg)}
.list-name{font-size:.95rem;font-weight:700;color:var(--accent);font-family:'Share Tech Mono',monospace}
.list-badge{background:rgba(0,176,255,.12);border:1px solid rgba(0,176,255,.3);color:var(--accent);
  font-size:.62rem;padding:1px 6px;border-radius:2px;font-family:'Share Tech Mono',monospace;letter-spacing:1px}
.file-meta{display:flex;align-items:center;gap:10px;flex-wrap:wrap}
.stat{font-family:'Share Tech Mono',monospace;font-size:.82rem;font-weight:700}
.s-pass{color:var(--pass)}.s-fail{color:var(--fail)}.s-na{color:var(--na)}.s-miss{color:var(--miss)}
.health-bar{display:flex;height:3px}
.hb-pass{background:var(--pass)}.hb-fail{background:var(--fail)}.hb-na{background:var(--na)}
.result-table{width:100%;border-collapse:collapse;font-family:'Share Tech Mono',monospace;font-size:.8rem}
.result-table th{text-align:left;padding:7px 16px;background:rgba(255,255,255,.03);color:var(--muted);
  font-size:.66rem;letter-spacing:2px;text-transform:uppercase;border-bottom:1px solid var(--border)}
.result-table td{padding:6px 16px;border-bottom:1px solid rgba(30,37,53,.8)}
.result-table tr:last-child td{border-bottom:none}
.result-table tr.prow{cursor:default}
.result-table tr.prow.has-detail{cursor:pointer}
.result-table tr.prow.has-detail:hover td{background:rgba(0,176,255,.06)}
.result-table tr:hover td{background:rgba(255,255,255,.025)}
.test-label{color:var(--text)}
.dhint{color:var(--muted);font-size:.62rem;margin-left:8px;opacity:.6}
.prio-cell{width:48px;text-align:center}
.prio{display:inline-block;width:20px;height:20px;line-height:20px;text-align:center;border-radius:3px;
  font-size:.7rem;font-weight:700;font-family:'Share Tech Mono',monospace}
.prio-s{background:rgba(255,64,129,.15);color:var(--prio-s);border:1px solid rgba(255,64,129,.4)}
.prio-a{background:rgba(255,179,0,.15);color:var(--prio-a);border:1px solid rgba(255,179,0,.4)}
.prio-b{background:rgba(38,198,218,.15);color:var(--prio-b);border:1px solid rgba(38,198,218,.4)}
.prio-none{color:var(--muted);opacity:.4}
.badge{display:inline-block;padding:2px 9px;border-radius:2px;font-size:.7rem;font-weight:700;letter-spacing:1.5px}
.badge-pass{background:rgba(0,230,118,.12);color:var(--pass);border:1px solid rgba(0,230,118,.3)}
.badge-fail{background:rgba(255,23,68,.12);color:var(--fail);border:1px solid rgba(255,23,68,.3)}
.badge-na{background:rgba(84,110,122,.15);color:var(--na);border:1px solid rgba(84,110,122,.3)}
.badge-miss{background:rgba(245,158,11,.1);color:var(--miss);border:1px solid rgba(245,158,11,.3)}
.src-tag{font-size:.63rem;color:var(--muted);margin-left:7px;cursor:help;border-bottom:1px dotted var(--muted);opacity:.7}
.file-block.collapsed .result-table,.file-block.collapsed .health-bar{display:none}
footer{text-align:center;padding:18px;font-size:.7rem;color:var(--muted);font-family:'Share Tech Mono',monospace;
  border-top:1px solid var(--border);margin-top:24px}
/* list panel + toolbar */
.list-panel,.filter-toolbar{background:var(--surface);border:1px solid var(--border);border-radius:4px;margin-bottom:16px}
.list-panel-header{display:flex;align-items:center;justify-content:space-between;padding:9px 14px;
  border-bottom:1px solid var(--border);cursor:pointer;user-select:none;background:rgba(0,176,255,.04)}
.list-panel-title{font-family:'Share Tech Mono',monospace;font-size:.7rem;letter-spacing:2px;text-transform:uppercase;color:var(--accent)}
.panel-actions{display:flex;gap:8px}
.pact-btn{font-family:'Share Tech Mono',monospace;font-size:.65rem;letter-spacing:1px;padding:2px 9px;
  border:1px solid var(--border);border-radius:2px;background:transparent;color:var(--muted);cursor:pointer}
.pact-btn:hover{border-color:var(--accent);color:var(--accent)}
.list-panel-body{display:flex;flex-wrap:wrap;gap:6px 10px;padding:10px 14px}
.cb-item{display:flex;align-items:center;gap:6px;cursor:pointer;font-family:'Share Tech Mono',monospace;
  font-size:.72rem;color:var(--text);padding:3px 8px;border-radius:2px;border:1px solid transparent;white-space:nowrap}
.cb-item:hover{border-color:var(--border)}
.cb-item input[type=checkbox]{accent-color:var(--accent);width:13px;height:13px;cursor:pointer;flex-shrink:0}
.cb-item input[type=checkbox]:not(:checked) ~ .cb-name{color:var(--muted);text-decoration:line-through}
.filter-toolbar{display:flex;flex-wrap:wrap;align-items:center;gap:16px;padding:12px 16px}
.filter-label{font-family:'Share Tech Mono',monospace;font-size:.65rem;letter-spacing:2px;text-transform:uppercase;color:var(--muted);margin-right:6px}
.filter-group{display:flex;align-items:center;gap:6px;flex-wrap:wrap}
.fbtn{font-family:'Share Tech Mono',monospace;font-size:.72rem;font-weight:700;letter-spacing:1px;padding:3px 12px;
  border-radius:2px;cursor:pointer;border:1px solid var(--border);background:transparent;color:var(--muted)}
.fbtn:hover{border-color:var(--accent);color:var(--accent)}
.fbtn.active{background:rgba(0,176,255,.15);border-color:var(--accent);color:var(--accent)}
.fbtn.pass.active{background:rgba(0,230,118,.12);border-color:var(--pass);color:var(--pass)}
.fbtn.fail.active{background:rgba(255,23,68,.12);border-color:var(--fail);color:var(--fail)}
.fbtn.na.active{background:rgba(84,110,122,.15);border-color:var(--na);color:var(--na)}
.fbtn.miss.active{background:rgba(245,158,11,.1);border-color:var(--miss);color:var(--miss)}
.search-wrap{display:flex;align-items:center;background:var(--bg);border:1px solid var(--border);border-radius:2px;padding:2px 8px}
.search-wrap:focus-within{border-color:var(--accent)}
.search-icon{color:var(--muted);font-size:.8rem;margin-right:6px}
.name-search{background:transparent;border:none;outline:none;color:var(--text);font-family:'Share Tech Mono',monospace;font-size:.8rem;width:200px;padding:2px 0}
.name-search::placeholder{color:var(--muted)}
.clear-btn{display:none;background:transparent;border:none;color:var(--muted);cursor:pointer;font-size:.7rem;padding:0 2px;margin-left:4px}
.clear-btn:hover{color:var(--fail)}
.match-count{font-family:'Share Tech Mono',monospace;font-size:.72rem;color:var(--accent);letter-spacing:1px}
/* drawer */
.overlay{position:fixed;inset:0;background:rgba(0,0,0,.55);opacity:0;pointer-events:none;transition:opacity .2s;z-index:500}
.overlay.open{opacity:1;pointer-events:auto}
.drawer{position:fixed;top:0;right:0;height:100vh;width:min(760px,94vw);background:var(--surface);
  border-left:2px solid var(--accent);transform:translateX(100%);transition:transform .25s ease;z-index:600;
  display:flex;flex-direction:column;box-shadow:-8px 0 30px rgba(0,0,0,.5)}
.drawer.open{transform:translateX(0)}
.drawer-head{padding:16px 20px;border-bottom:1px solid var(--border);display:flex;align-items:flex-start;justify-content:space-between;gap:12px}
.drawer-title{font-family:'Share Tech Mono',monospace;font-size:1.05rem;color:var(--accent);word-break:break-all}
.drawer-sub{margin-top:6px;display:flex;gap:8px;flex-wrap:wrap;align-items:center}
.drawer-close{background:transparent;border:1px solid var(--border);color:var(--muted);cursor:pointer;
  font-size:1rem;border-radius:3px;width:30px;height:30px;flex-shrink:0}
.drawer-close:hover{border-color:var(--fail);color:var(--fail)}
.drawer-body{padding:16px 20px;overflow-y:auto;flex:1}
.dsec-title{font-family:'Share Tech Mono',monospace;font-size:.68rem;letter-spacing:2px;text-transform:uppercase;
  color:var(--muted);margin:18px 0 8px;border-left:3px solid var(--accent);padding-left:8px}
.dsec-title:first-child{margin-top:0}
.cp-table{width:100%;border-collapse:collapse;font-size:.78rem;margin-bottom:6px}
.cp-table th{text-align:left;padding:5px 8px;background:rgba(255,255,255,.03);color:var(--muted);
  font-family:'Share Tech Mono',monospace;font-size:.62rem;letter-spacing:1px;text-transform:uppercase;border-bottom:1px solid var(--border)}
.cp-table td{padding:5px 8px;border-bottom:1px solid rgba(30,37,53,.8);vertical-align:top}
.cp-src{color:var(--muted);font-size:.66rem;font-family:'Share Tech Mono',monospace;white-space:nowrap}
.file-acc{border:1px solid var(--border);border-radius:3px;margin-bottom:8px;overflow:hidden}
.file-acc>summary{cursor:pointer;padding:8px 12px;background:rgba(255,255,255,.03);font-family:'Share Tech Mono',monospace;
  font-size:.78rem;color:var(--text);list-style:none;display:flex;align-items:center;gap:8px}
.file-acc>summary::-webkit-details-marker{display:none}
.file-acc>summary:hover{color:var(--accent)}
.file-kind{font-size:.6rem;padding:1px 6px;border-radius:2px;border:1px solid var(--border);color:var(--muted);letter-spacing:1px;text-transform:uppercase}
.file-pre{margin:0;padding:12px;overflow-x:auto;background:var(--bg);color:#b9c4d6;font-family:'Share Tech Mono',monospace;
  font-size:.74rem;line-height:1.45;white-space:pre;max-height:60vh}
.empty-note{color:var(--muted);font-size:.8rem;font-style:italic}
.meta-pill{font-family:'Share Tech Mono',monospace;font-size:.66rem;padding:2px 8px;border-radius:2px;
  border:1px solid var(--border);color:var(--muted)}
"""

_PAGE_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>{title}</title>
<style>{css}</style>
</head>
<body>
<header>
  <div>
    <span class="logo-main">&#9632; RVC DASHBOARD</span>
    <span class="logo-sub">Pattern &middot; Checkpoint &middot; Result</span>
  </div>
  <div class="header-right">
    {dir_badges}
    <span class="last-update">Generated: {ts}</span>
  </div>
</header>
<div class="global-bar">
  <div class="gb-pass" style="width:{ow_p}%"></div>
  <div class="gb-fail" style="width:{ow_f}%"></div>
  <div class="gb-na"   style="width:{ow_n}%"></div>
</div>
<div class="scoreboard">
  <div class="score-card sc-total"><div class="score-num">{total}</div><div class="score-label">Total</div></div>
  <div class="score-card sc-pass"><div class="score-num">{npass}</div><div class="score-label">Pass</div></div>
  <div class="score-card sc-fail"><div class="score-num">{nfail}</div><div class="score-label">Fail</div></div>
  <div class="score-card sc-na"><div class="score-num">{nna}</div><div class="score-label">N/A</div></div>
  <div class="score-card sc-miss"><div class="score-num">{nmiss}</div><div class="score-label">Not run</div></div>
</div>
<main>
  <p class="section-heading">{n_lists} list(s) &bull; click a row to inspect checkpoints &amp; source</p>
  <div class="list-panel" id="listPanel">
    <div class="list-panel-header" id="listPanelToggle">
      <span class="list-panel-title">&#9634; List visibility</span>
      <div class="panel-actions" onclick="event.stopPropagation()">
        <button class="pact-btn" id="btnAll">Check all</button>
        <button class="pact-btn" id="btnNone">Uncheck all</button>
      </div>
    </div>
    <div class="list-panel-body" id="listPanelBody">
      {cb_items}
    </div>
  </div>
  <div class="filter-toolbar">
    <div class="filter-group">
      <span class="filter-label">Result</span>
      <button class="fbtn active" data-f="ALL">ALL</button>
      <button class="fbtn pass" data-f="PASS">PASS</button>
      <button class="fbtn fail" data-f="FAIL">FAIL</button>
      <button class="fbtn na" data-f="NA">N/A</button>
      <button class="fbtn miss" data-f="MISSING">&mdash;</button>
    </div>
    <div class="filter-group">
      <span class="filter-label">Prio</span>
      <button class="fbtn" data-p="S">S</button>
      <button class="fbtn" data-p="A">A</button>
      <button class="fbtn" data-p="B">B</button>
    </div>
    <div class="filter-group">
      <span class="filter-label">Name</span>
      <div class="search-wrap">
        <span class="search-icon">&#128269;</span>
        <input id="nameSearch" class="name-search" type="text" placeholder="filter test name" autocomplete="off" spellcheck="false">
        <button class="clear-btn" id="clearSearch" title="clear">&#10005;</button>
      </div>
    </div>
    <div class="filter-group"><span class="match-count" id="matchCount"></span></div>
  </div>
{sections}
</main>
<footer>RVC tool &bull; data: {data_js} / {data_json}</footer>

<div class="overlay" id="overlay"></div>
<aside class="drawer" id="drawer">
  <div class="drawer-head">
    <div>
      <div class="drawer-title" id="drawerTitle">-</div>
      <div class="drawer-sub" id="drawerSub"></div>
    </div>
    <button class="drawer-close" id="drawerClose">&#10005;</button>
  </div>
  <div class="drawer-body" id="drawerBody"></div>
</aside>

<script src="{data_js}"></script>
<script>{script}</script>
</body>
</html>
"""

_SCRIPT = r"""
// ---- collapse/expand sections ----
document.querySelectorAll('.file-header').forEach(h =>
  h.addEventListener('click', () => h.closest('.file-block').classList.toggle('collapsed')));

// ---- list visibility ----
document.querySelectorAll('.list-toggle').forEach(cb => {
  cb.addEventListener('change', () => {
    const block = document.querySelector('.file-block[data-list-id="' + cb.dataset.target + '"]');
    if (block) block.classList.toggle('list-hidden', !cb.checked);
  });
});
document.getElementById('btnAll').addEventListener('click', () =>
  document.querySelectorAll('.list-toggle').forEach(cb => { cb.checked = true; cb.dispatchEvent(new Event('change')); }));
document.getElementById('btnNone').addEventListener('click', () =>
  document.querySelectorAll('.list-toggle').forEach(cb => { cb.checked = false; cb.dispatchEvent(new Event('change')); }));
document.getElementById('listPanelToggle').addEventListener('click', () => {
  const b = document.getElementById('listPanelBody');
  b.style.display = b.style.display === 'none' ? '' : 'none';
});

// ---- filters ----
let resultFilters = new Set();
let prioFilters = new Set();
let searchText = '';
function applyFilters() {
  const showAllRes = resultFilters.size === 0;
  const showAllPrio = prioFilters.size === 0;
  document.querySelectorAll('.file-block').forEach(block => {
    let visible = 0;
    block.querySelectorAll('tbody tr').forEach(row => {
      const name = (row.querySelector('.test-label')?.textContent || '').toLowerCase();
      const st = row.dataset.status || 'MISSING';
      const pr = row.dataset.prio || '';
      const okRes = showAllRes || resultFilters.has(st);
      const okPrio = showAllPrio || prioFilters.has(pr);
      const okSearch = name.includes(searchText);
      if (okRes && okPrio && okSearch) { row.style.display = ''; visible++; }
      else row.style.display = 'none';
    });
    const tbl = block.querySelector('.result-table');
    if (tbl) tbl.style.display = visible === 0 ? 'none' : '';
  });
  updateCount();
}
function updateCount() {
  let total = 0, vis = 0;
  document.querySelectorAll('tbody tr').forEach(r => { total++; if (r.style.display !== 'none') vis++; });
  const el = document.getElementById('matchCount');
  if (el) el.textContent = (resultFilters.size || prioFilters.size || searchText) ? (vis + ' / ' + total + ' shown') : '';
}
document.querySelectorAll('.fbtn[data-f]').forEach(btn => btn.addEventListener('click', () => {
  const f = btn.dataset.f;
  const toolbar = btn.closest('.filter-toolbar');
  if (f === 'ALL') {
    resultFilters.clear();
    toolbar.querySelectorAll('.fbtn[data-f]').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
  } else {
    if (resultFilters.has(f)) { resultFilters.delete(f); btn.classList.remove('active'); }
    else { resultFilters.add(f); btn.classList.add('active'); }
    const allBtn = toolbar.querySelector('.fbtn[data-f="ALL"]');
    allBtn.classList.toggle('active', resultFilters.size === 0);
  }
  applyFilters();
}));
document.querySelectorAll('.fbtn[data-p]').forEach(btn => btn.addEventListener('click', () => {
  const p = btn.dataset.p;
  if (prioFilters.has(p)) { prioFilters.delete(p); btn.classList.remove('active'); }
  else { prioFilters.add(p); btn.classList.add('active'); }
  applyFilters();
}));
const input = document.getElementById('nameSearch');
const clearBtn = document.getElementById('clearSearch');
input.addEventListener('input', () => {
  searchText = input.value.toLowerCase();
  clearBtn.style.display = searchText ? 'flex' : 'none';
  applyFilters();
});
clearBtn.addEventListener('click', () => { input.value = ''; searchText = ''; clearBtn.style.display = 'none'; applyFilters(); });

// ---- detail drawer ----
const overlay = document.getElementById('overlay');
const drawer = document.getElementById('drawer');
const dTitle = document.getElementById('drawerTitle');
const dSub = document.getElementById('drawerSub');
const dBody = document.getElementById('drawerBody');

const STATUS_DISP = {PASS:'PASS', FAIL:'FAIL', NA:'N/A', MISSING:'Not run'};
const STATUS_BADGE = {PASS:'badge-pass', FAIL:'badge-fail', NA:'badge-na', MISSING:'badge-miss'};

let DATA = window.__RVC_DATA__ || null;
async function ensureData() {
  if (DATA) return DATA;
  // fallback when opened via http(s): lazy-fetch the JSON companion.
  try {
    const r = await fetch(DATA_JSON_URL);
    DATA = await r.json();
  } catch (e) { DATA = {}; }
  return DATA;
}
const DATA_JSON_URL = (document.querySelector('footer')?.textContent.match(/([\w.-]+_data\.json)/) || [,'report_data.json'])[1];

function el(tag, cls, txt) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (txt != null) e.textContent = txt;   // textContent => safe against HTML in source
  return e;
}
function pill(txt) { return el('span', 'meta-pill', txt); }

function renderDrawer(name, d) {
  dTitle.textContent = name;
  dSub.innerHTML = '';
  const badge = el('span', 'badge ' + (STATUS_BADGE[d.status] || 'badge-miss'), STATUS_DISP[d.status] || '-');
  dSub.appendChild(badge);
  if (d.priority) dSub.appendChild(el('span', 'prio prio-' + d.priority.toLowerCase(), d.priority));
  if (d.lists && d.lists.length) dSub.appendChild(pill('lists: ' + d.lists.join(', ')));
  if (d.rpt) dSub.appendChild(pill('rpt: ' + d.rpt));

  dBody.innerHTML = '';
  if (d.options) {
    dBody.appendChild(el('div', 'dsec-title', 'Sim options'));
    const pre = el('pre', 'file-pre'); pre.textContent = d.options; dBody.appendChild(pre);
  }

  // checkpoints
  dBody.appendChild(el('div', 'dsec-title', 'Checkpoints (' + (d.checkpoints ? d.checkpoints.length : 0) + ')'));
  if (d.checkpoints && d.checkpoints.length) {
    const t = el('table', 'cp-table');
    const thead = el('thead');
    const htr = el('tr');
    ['#','Main','Middle','Detailed','Confirmation','VIL'].forEach(h => htr.appendChild(el('th', null, h)));
    thead.appendChild(htr); t.appendChild(thead);
    const tb = el('tbody');
    d.checkpoints.forEach((c, i) => {
      const tr = el('tr');
      tr.appendChild(el('td', null, String(i + 1)));
      tr.appendChild(el('td', null, c.main || ''));
      tr.appendChild(el('td', null, c.middle || ''));
      tr.appendChild(el('td', null, c.detailed || ''));
      tr.appendChild(el('td', null, c.confirmation || ''));
      const src = el('td', 'cp-src', (c.file_name || '') + (c.sheet ? (' / ' + c.sheet + ':' + c.row) : ''));
      tr.appendChild(src);
      tb.appendChild(tr);
    });
    t.appendChild(tb); dBody.appendChild(t);
  } else {
    dBody.appendChild(el('div', 'empty-note', 'No checkpoint found in the VIL for this pattern.'));
  }

  // source files
  dBody.appendChild(el('div', 'dsec-title', 'Source files (' + (d.files ? d.files.length : 0) + ')'));
  if (d.files && d.files.length) {
    d.files.forEach(f => {
      const det = el('details', 'file-acc');
      const sum = el('summary');
      sum.appendChild(el('span', 'file-kind', f.kind || 'src'));
      sum.appendChild(el('span', null, f.file));
      det.appendChild(sum);
      const pre = el('pre', 'file-pre');
      pre.textContent = (f.content != null ? f.content : '(content not embedded)');
      det.appendChild(pre);
      dBody.appendChild(det);
    });
  } else {
    dBody.appendChild(el('div', 'empty-note', 'No source file collected (pattern directory not scanned or not found).'));
  }
}

function openDrawer(name) {
  ensureData().then(data => {
    const d = data[name];
    if (!d) { return; }
    renderDrawer(name, d);
    overlay.classList.add('open');
    drawer.classList.add('open');
  });
}
function closeDrawer() { overlay.classList.remove('open'); drawer.classList.remove('open'); }

document.querySelectorAll('tr.prow.has-detail').forEach(row =>
  row.addEventListener('click', () => openDrawer(row.dataset.name)));
document.getElementById('drawerClose').addEventListener('click', closeDrawer);
overlay.addEventListener('click', closeDrawer);
document.addEventListener('keydown', e => { if (e.key === 'Escape') closeDrawer(); });
"""

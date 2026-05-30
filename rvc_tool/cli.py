"""
cli.py - Command line entry point for the RVC tool.
===================================================

Subcommands
-----------
  build     Scan VIL + master report + pattern sources -> HTML dashboard + Excel.
  filter    Comment / un-comment a sim list file by PASS/FAIL/NA status
            (the improved 05_filter; no module argument required).
  itemlist  Generate S_item.list / A_item.list / B_item.list from VIL priority.
  serve     Serve the output directory over http (so the drawer can fetch JSON).

Run ``rvc <subcommand> -h`` for details.
"""
from __future__ import annotations

import argparse
import os
import sys
from typing import List

from . import config as cfgmod
from . import listfile as lf
from . import master_report as mr
from . import model as modelmod
from . import patterns as patmod
from . import report_excel, report_html
from . import vil as vilmod


def _log(msg):
    print(msg, file=sys.stderr)


def _split_csv(val):
    if not val:
        return None
    return [x.strip() for x in val.split(",") if x.strip()]


# ---------------------------------------------------------------------------
# build
# ---------------------------------------------------------------------------
def cmd_build(args) -> int:
    cfg = cfgmod.load_config(args.config) if args.config else dict(cfgmod.DEFAULTS)
    cfg = cfgmod.merge_overrides(
        cfg,
        report_dirs=_split_csv(args.report_dir),
        list_files=_split_csv(args.list_file),
        vil_dir=args.vil_dir,
        pattern_dirs=_split_csv(args.pattern_dir),
        output_dir=args.output_dir,
        include_content=(False if args.no_content else None),
    )

    if not cfg["list_files"]:
        _log("[ERR] no list_files configured - nothing to group. Use --list-file or a config.")
        return 2

    # --fast = "skip compile, run straight": drop BOTH heavy scans and build a
    # sim-status-only dashboard as quickly as possible. --no-vil / --no-patterns
    # skip them individually.
    skip_vil = args.no_vil or args.fast
    skip_patterns = args.no_patterns or args.fast

    # Expensive scans (VIL + pattern source tree) run once; in --watch mode only
    # the master report is re-parsed when a .rpt file changes.
    if skip_vil:
        _log("[SKIP] VIL scan (--no-vil/--fast) -> no priority/checkpoints")
        vil_info = {}
    else:
        vfiles = cfgmod.vil_files(cfg)
        vil_info = vilmod.scan_vils(files=vfiles, progress=_log) if vfiles else {}
    pattern_index = {}
    if skip_patterns:
        _log("[SKIP] pattern source scan (--no-patterns/--fast) -> no source in drawer")
    elif cfg["pattern_dirs"]:
        pattern_index = patmod.build_index(cfg["pattern_dirs"], progress=_log)

    out_dir = cfg["output_dir"]
    os.makedirs(out_dir, exist_ok=True)
    html_path = os.path.join(out_dir, cfg["html_name"])
    xlsx_path = os.path.join(out_dir, cfg["excel_name"])

    def rebuild():
        reports = mr.parse_reports(cfg["report_dirs"], progress=_log) if cfg["report_dirs"] else {}
        ds = modelmod.build_dataset(
            list_files=cfg["list_files"],
            vil_info=vil_info,
            reports=reports,
            pattern_index=pattern_index,
            report_dirs=cfg["report_dirs"],
            include_unlisted=cfg["include_unlisted"],
            max_file_bytes=cfg["max_file_bytes"],
            include_content=cfg["include_content"],
            progress=_log,
        )
        written = report_html.generate(
            ds, html_path, title=cfg["title"],
            include_content=cfg["include_content"],
            show_unlisted=cfg["include_unlisted"],
        )
        report_excel.generate(ds, xlsx_path)
        t = ds.totals()
        _log("[OK] dashboard : {}".format(written["html"]))
        _log("[OK] data file : {}".format(written["js"]))
        _log("[OK] excel     : {}".format(xlsx_path))
        _log("[OK] totals    : total={TOTAL} pass={PASS} fail={FAIL} na={NA} not-run={MISSING}".format(**t))
        return written

    written = rebuild()

    if args.watch:
        import time
        interval = max(1, args.watch_interval)
        _log("[watch] polling every {}s for .rpt changes (Ctrl-C to stop)".format(interval))

        def snapshot():
            import glob
            sig = []
            for d in cfg["report_dirs"]:
                for p in sorted(glob.glob(os.path.join(d, "*.rpt"))):
                    try:
                        sig.append((p, os.path.getmtime(p)))
                    except OSError:
                        pass
            return tuple(sig)

        last = snapshot()
        try:
            while True:
                time.sleep(interval)
                cur = snapshot()
                if cur != last:
                    _log("[watch] change detected - regenerating...")
                    rebuild()
                    last = cur
        except KeyboardInterrupt:
            _log("\n[watch] stopped")

    print(written["html"])
    return 0


# ---------------------------------------------------------------------------
# filter
# ---------------------------------------------------------------------------
def cmd_filter(args) -> int:
    cfg = cfgmod.load_config(args.config) if args.config else dict(cfgmod.DEFAULTS)
    cfg = cfgmod.merge_overrides(cfg, report_dirs=_split_csv(args.report_dir))

    if not args.restore and not cfg["report_dirs"]:
        _log("[ERR] need --report-dir (or config report_dirs) to know each pattern's status.")
        return 2

    status = {}
    if not args.restore:
        reports = mr.parse_reports(cfg["report_dirs"], progress=_log)
        status = mr.status_map(reports)

    comment_statuses = _split_csv(args.comment)
    if comment_statuses:
        comment_statuses = [s.upper() for s in comment_statuses]
    elif args.keep:
        keep = {s.upper() for s in _split_csv(args.keep)}
        comment_statuses = [s for s in ("PASS", "FAIL", "NA", "MISSING") if s not in keep]
    else:
        comment_statuses = ["PASS", "FAIL", "NA"]   # mirror original 05_filter

    rc = 0
    for path in args.listfile:
        if not os.path.isfile(path):
            _log("[ERR] not a file: {}".format(path))
            rc = 1
            continue
        res = lf.update_listfile(
            path, status,
            comment_statuses=comment_statuses,
            restore=args.restore,
            write=not args.dry_run,
        )
        tag = "(dry-run) " if args.dry_run else ""
        _log("[{}] {}{}".format(os.path.basename(path), tag, res.summary()))
    return rc


# ---------------------------------------------------------------------------
# itemlist
# ---------------------------------------------------------------------------
def cmd_itemlist(args) -> int:
    cfg = cfgmod.load_config(args.config) if args.config else dict(cfgmod.DEFAULTS)
    cfg = cfgmod.merge_overrides(cfg, vil_dir=args.vil_dir, output_dir=args.output_dir)
    vfiles = cfgmod.vil_files(cfg)
    if not vfiles:
        _log("[ERR] no VIL files (set --vil-dir or config vil_dir/vil_files).")
        return 2
    vil_info = vilmod.scan_vils(files=vfiles, progress=_log)
    lists = modelmod.priority_item_lists(vil_info)
    out_dir = cfg["output_dir"]
    os.makedirs(out_dir, exist_ok=True)
    for prio, names in lists.items():
        path = os.path.join(out_dir, "{}_item.list".format(prio))
        with open(path, "w", encoding="utf-8") as fh:
            fh.write("\n".join(names))
            if names:
                fh.write("\n")
        _log("[OK] {} ({} patterns)".format(path, len(names)))
    return 0


# ---------------------------------------------------------------------------
# serve
# ---------------------------------------------------------------------------
def cmd_serve(args) -> int:
    import http.server
    import json as _json
    import socketserver
    import subprocess
    import time

    directory = os.path.abspath(args.dir)
    exec_enabled = bool(args.exec)
    frun_cmd = args.frun
    run_cwd = os.path.abspath(args.run_cwd) if args.run_cwd else os.getcwd()
    token = args.token
    host = args.host
    # Secure default: --exec only listens on loopback unless a host is given.
    if exec_enabled and host == "":
        host = "127.0.0.1"

    # Build the run whitelist from the data file: name -> exact list line. The
    # client only ever sends a pattern *name*; the line that gets executed comes
    # from here, never from the request -> no command injection via the browser.
    run_index = {}
    runs_dir = os.path.join(directory, ".rvc_runs")
    if exec_enabled:
        data_path = os.path.join(directory, "report_data.json")
        try:
            with open(data_path, "r", encoding="utf-8") as fh:
                _data = _json.load(fh)
            for nm, d in _data.items():
                run_index[nm] = d.get("run_line") or d.get("hierarchy") or nm
            _log("[serve] --exec ON: {} runnable pattern(s) via '{}' (cwd={})".format(
                len(run_index), frun_cmd, run_cwd))
        except Exception as e:  # noqa: BLE001 - report and disable, don't crash
            _log("[serve] --exec: cannot read {} ({}); running disabled.".format(data_path, e))
            run_index = {}
        os.makedirs(runs_dir, exist_ok=True)

    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *a, **kw):
            super().__init__(*a, directory=directory, **kw)

        def log_message(self, *a):  # keep the console quiet
            pass

        def _reply(self, code, obj):
            body = _json.dumps(obj).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if self.path.split("?")[0] == "/rvc/status":
                self._reply(200, {"exec": exec_enabled,
                                  "token_required": bool(token),
                                  "count": len(run_index)})
                return
            return super().do_GET()

        def do_POST(self):
            if self.path.split("?")[0] != "/rvc/run":
                self._reply(404, {"ok": False, "error": "unknown endpoint"})
                return
            if not exec_enabled:
                self._reply(403, {"ok": False, "error": "exec disabled (start with --exec)"})
                return
            if token and self.headers.get("X-RVC-Token") != token:
                self._reply(403, {"ok": False, "error": "bad or missing token"})
                return
            try:
                length = int(self.headers.get("Content-Length", 0))
                payload = _json.loads(self.rfile.read(length) or b"{}")
            except Exception:  # noqa: BLE001
                self._reply(400, {"ok": False, "error": "bad request body"})
                return
            name = payload.get("name", "")
            if name not in run_index:  # whitelist: only patterns from the dataset
                self._reply(404, {"ok": False, "error": "unknown pattern: {}".format(name)})
                return
            run_line = run_index[name]
            ts = time.strftime("%Y%m%d_%H%M%S")
            safe = "".join(c if c.isalnum() else "_" for c in name)[:80]
            list_path = os.path.join(runs_dir, "{}_{}.list".format(safe, ts))
            log_path = os.path.join(runs_dir, "{}_{}.log".format(safe, ts))
            try:
                with open(list_path, "w", encoding="utf-8") as fh:
                    fh.write(run_line + "\n")
                logf = open(log_path, "w", encoding="utf-8")
                # list args + no shell -> the browser cannot inject a command
                proc = subprocess.Popen(
                    [frun_cmd, list_path], cwd=run_cwd,
                    stdout=logf, stderr=subprocess.STDOUT,
                )
            except FileNotFoundError:
                self._reply(500, {"ok": False, "error": "command not found: {}".format(frun_cmd)})
                return
            except Exception as e:  # noqa: BLE001
                self._reply(500, {"ok": False, "error": str(e)})
                return
            _log("[serve] RUN {} -> {} {} (pid {})".format(name, frun_cmd, list_path, proc.pid))
            self._reply(200, {"ok": True, "name": name, "pid": proc.pid,
                              "cmd": "{} {}".format(frun_cmd, list_path),
                              "list": list_path, "log": log_path})

    class _Server(socketserver.ThreadingTCPServer):
        allow_reuse_address = True
        daemon_threads = True

    with _Server((host, args.port), Handler) as httpd:
        shown = host or "localhost"
        _log("[serve] http://{}:{}/{}  (Ctrl-C to stop)".format(shown, args.port, args.open or ""))
        if exec_enabled and host not in ("127.0.0.1", "localhost"):
            _log("[serve] !! --exec is exposed on {}: anyone who can reach this port can launch "
                 "'{}'. Protect it with --token.".format(host, frun_cmd))
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            _log("\n[serve] stopped")
    return 0


# ---------------------------------------------------------------------------
def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="rvc", description="Renesas Verification Companion - unify VIL, master report, patterns and list files.")
    sub = p.add_subparsers(dest="command")

    b = sub.add_parser("build", help="build HTML dashboard + Excel review")
    b.add_argument("-c", "--config")
    b.add_argument("--report-dir", help="comma-separated master-report dirs")
    b.add_argument("--list-file", help="comma-separated .list files")
    b.add_argument("--vil-dir")
    b.add_argument("--pattern-dir", help="comma-separated testcase trees")
    b.add_argument("--output-dir")
    b.add_argument("--no-content", action="store_true", help="do not embed source content")
    b.add_argument("--no-vil", action="store_true", help="skip VIL scan (no priority/checkpoints)")
    b.add_argument("--no-patterns", action="store_true", help="skip pattern source scan (no source in drawer)")
    b.add_argument("--fast", action="store_true", help="sim-status only: skip BOTH VIL and pattern scans (like skip-compile)")
    b.add_argument("--watch", action="store_true", help="keep running; rebuild when a .rpt changes")
    b.add_argument("--watch-interval", type=int, default=3, help="watch poll seconds (default 3)")
    b.set_defaults(func=cmd_build)

    f = sub.add_parser("filter", help="comment/un-comment a .list by status (improved 05_filter)")
    f.add_argument("listfile", nargs="+")
    f.add_argument("-c", "--config")
    f.add_argument("--report-dir", help="comma-separated master-report dirs")
    f.add_argument("--comment", help="statuses to comment out (default PASS,FAIL,NA)")
    f.add_argument("--keep", help="statuses to keep active (comments the rest)")
    f.add_argument("--restore", action="store_true", help="un-comment everything WE commented")
    f.add_argument("--dry-run", action="store_true")
    f.set_defaults(func=cmd_filter)

    it = sub.add_parser("itemlist", help="generate S/A/B_item.list from VIL priority")
    it.add_argument("-c", "--config")
    it.add_argument("--vil-dir")
    it.add_argument("--output-dir")
    it.set_defaults(func=cmd_itemlist)

    s = sub.add_parser("serve", help="serve a directory over http (drawer JSON fetch)")
    s.add_argument("dir", nargs="?", default="rvc_out")
    s.add_argument("--port", type=int, default=8000)
    s.add_argument("--open", default="report.html")
    s.add_argument("--host", default="", help="bind address (default all; --exec forces 127.0.0.1 unless set)")
    s.add_argument("--exec", action="store_true", help="enable POST /rvc/run so the dashboard Run button can launch the run command (off by default)")
    s.add_argument("--frun", default="frun", help="run command used by --exec (default: frun)")
    s.add_argument("--run-cwd", default="", help="working directory for the run command (default: current dir)")
    s.add_argument("--token", default="", help="require header X-RVC-Token on /rvc/run")
    s.set_defaults(func=cmd_serve)

    return p


def main(argv: List[str] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if not getattr(args, "command", None):
        parser.print_help()
        return 1
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())

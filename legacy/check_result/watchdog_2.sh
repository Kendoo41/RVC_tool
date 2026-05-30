#!/usr/bin/env bash
# =============================================================================
# watchdog.sh  Multi-directory .rpt monitor with .list grouping
#
# .rpt result line format (after "Execution Results" section header):
#   [OK]   (HH:MM:SS) some/path/testcase_name --options...
#   [NG]   (HH:MM:SS) some/path/testcase_name --options...
#   [N/A]  (HH:MM:SS) some/path/testcase_name --options...
#
# .list file: one test name per line, # = comment.
#
#  USAGE
#   chmod +x watchdog.sh
#   ./watchdog.sh                          # foreground  (Ctrl-C to stop)
#   ./watchdog.sh --daemon                 # detach (PID /tmp/watchdog_report.pid)
#   kill $(cat /tmp/watchdog_report.pid)   # stop daemon
# =============================================================================

# NO set -e  (arithmetic and grep-no-match both exit 1; handled with || true)
set -uo pipefail

# =============================================================================
#  CONFIGURE HERE
# =============================================================================
REPORT_DIRS=(
    "/svhome/rhflash/data/r7f7025h0/2_sim/01_collect_sim_result/99_MASTER_REPORT/v001/u2b20ez_rtl_item_report_v001_004_rtl"
    "/svhome/rhflash/data/r7f7025h0/2_sim/01_collect_sim_result/99_MASTER_REPORT/v001/u2b20ez_rtl_item_report_v001_003_rtl"
    "/svhome/rhflash/data/r7f7025h0/2_sim/01_collect_sim_result/99_MASTER_REPORT/v001/u2b20ez_rtl_item_report_v001_002_rtl"
    "/svhome/rhflash/data/r7f7025h0/2_sim/01_collect_sim_result/99_MASTER_REPORT/v001/u2b20ez_rtl_item_report_v001_001_rtl"
    # "./MASTER_REPORT_v2"
)

LIST_FILES=(
    # "/common/work/khoidao/hbus_safety_testcase_rtl.list"
    # "/common/work/khoidao/ether_pwrctrl0_testcase_rtl.list"
    # "/common/work/khoidao/HBSS_testcase_rtl.list"
    "/common/work/khoidao/S_item.list"
    "/common/work/khoidao/A_item.list"
    "/common/work/khoidao/B_item.list"
    # "./def.list"
)

# =============================================================================
OUTPUT_HTML="${OUTPUT_HTML:-./summary_report.html}"
POLL_INTERVAL="${POLL_INTERVAL:-2}"
SHOW_UNLISTED="${SHOW_UNLISTED:-1}"
PID_FILE="/tmp/watchdog_report.pid"
LOG_FILE="/tmp/watchdog_report.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

#  daemon mode
if [[ "${1:-}" == "--daemon" ]]; then
    exec nohup "$0" </dev/null >>"$LOG_FILE" 2>&1 &
    echo $! >"$PID_FILE"
    log "Daemon started (PID $!). Log: $LOG_FILE"
    exit 0
fi

echo $$ >"$PID_FILE"
log "Watchdog started (PID $$)"
for d in "${REPORT_DIRS[@]}"; do log "  REPORT_DIR  : $d"; done
for l in "${LIST_FILES[@]}";  do log "  LIST_FILE   : $l"; done
log "  OUTPUT_HTML : $OUTPUT_HTML"
log "  POLL_INTERVAL: ${POLL_INTERVAL}s  (F5 to refresh browser)"

cleanup() { log "Watchdog stopped."; rm -f "$PID_FILE"; exit 0; }
trap cleanup SIGTERM SIGINT

# =============================================================================
# generate_html  everything done in awk/grep, no bash loops over test data
# =============================================================================
generate_html() {
    local ts; ts=$(date '+%Y-%m-%d %H:%M:%S')
    log "Generating HTML report..."

    #  1. Collect .rpt files sorted oldestnewest
    local all_rpt=""
    local nrpt=0
    for d in "${REPORT_DIRS[@]}"; do
        [[ -d "$d" ]] || continue
        local found; found=$(find "$d" -maxdepth 1 -name '*.rpt' -printf '%T@ %p\n' 2>/dev/null \
                             | sort -n | awk '{print $2}')
        [[ -n "$found" ]] && all_rpt="${all_rpt}${found}"$'\n'
        local c; c=$(find "$d" -maxdepth 1 -name '*.rpt' 2>/dev/null | wc -l)
        nrpt=$(( nrpt + c ))
    done

    #  2. Build dedup map: STATUS TAB TESTNAME TAB RPTBASE TAB RPTDIR
    local map_tmp; map_tmp=$(mktemp /tmp/wd_map.XXXXXX)

    if [[ -n "$all_rpt" ]]; then
        echo "$all_rpt" \
        | xargs grep -H '^[[:space:]]*\[OK\]\|^[[:space:]]*\[NG\]\|^[[:space:]]*\[N/A\]' \
              2>/dev/null \
        | awk '
        {
            colon = index($0, ":")
            if (colon == 0) next
            filepath = substr($0, 1, colon-1)
            line     = substr($0, colon+1)
            n = split(filepath, parts, "/")
            rptbase = parts[n]
            rptdir  = (n >= 2) ? parts[n-1] : "."

            if      (line ~ /^[[:space:]]*\[OK\]/)   st = "PASS"
            else if (line ~ /^[[:space:]]*\[NG\]/)   st = "FAIL"
            else if (line ~ /^[[:space:]]*\[N\/A\]/) st = "NA"
            else next

            sub(/^[[:space:]]*\[[^\]]*\][[:space:]]*/,  "", line)
            sub(/^[[:space:]]*\([0-9:]*\)[[:space:]]*/,  "", line)
            sub(/ --.*$/, "", line)
            sub(/[[:space:]]+$/, "", line)
            n2 = split(line, p2, "/")
            tname = p2[n2]
            if (tname == "") next

            status[tname] = st
            winner[tname] = rptbase
            srcdir[tname] = rptdir
        }
        END {
            for (t in status)
                printf "%s\t%s\t%s\t%s\n", status[t], t, winner[t], srcdir[t]
        }
        ' > "$map_tmp" || true
    fi

    local total_all; total_all=$(wc -l < "$map_tmp")
    log "  Parsed ${total_all} unique test(s) from ${nrpt} .rpt file(s)"

    #  3. Load .list files  list_tmp files
    local nlists=0
    local -a lf_label=() lf_tmp=()

    for lf in "${LIST_FILES[@]}"; do
        if [[ ! -f "$lf" ]]; then
            log "  WARNING: list not found: $lf  skipping"; continue
        fi
        local lt; lt=$(mktemp /tmp/wd_list.XXXXXX)
        sed 's/#.*//' "$lf" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
            | grep -v '^$' > "$lt" || true
        local cnt; cnt=$(wc -l < "$lt")
        lf_label[$nlists]=$(basename "$lf")
        lf_tmp[$nlists]="$lt"
        log "  LIST ${lf_label[$nlists]}: ${cnt} test name(s)"
        nlists=$(( nlists + 1 ))
    done

    #  4. Build claimed set across all lists (for unlisted section)
    local claimed_tmp; claimed_tmp=$(mktemp /tmp/wd_claimed.XXXXXX)
    for (( i=0; i<nlists; i++ )); do
        cat "${lf_tmp[$i]}" >> "$claimed_tmp"
    done

    # awk program: join list against map, emit HTML section
    # NOTE: section gets data-list-id attribute for checkbox toggling
    local awk_section
    awk_section=$(mktemp /tmp/wd_awk.XXXXXX)
    cat > "$awk_section" << 'AWKSECTION'
FNR == NR {
    split($0, f, "\t")
    st = f[1]; tname = f[2]; rptbase = f[3]; rdir = f[4]
    map_st[tname]   = st
    map_src[tname]  = rptbase
    map_dir[tname]  = rdir
    next
}
{
    tname = $0
    if (tname == "") next

    if (tname in map_st) {
        st = map_st[tname]
        src = map_src[tname]
        sdir = map_dir[tname]
    } else {
        st = "MISSING"; src = ""; sdir = ""
    }

    if      (st == "PASS")    { badge="badge-pass"; disp="PASS"; pass++ }
    else if (st == "FAIL")    { badge="badge-fail"; disp="FAIL"; fail++ }
    else if (st == "NA")      { badge="badge-na";   disp="N/A";  na++   }
    else                      { badge="badge-miss"; disp="&mdash;"; miss++ }

    src_tip = ""
    if (src != "") src_tip = "<span class=\"src-tag\" title=\"" sdir "/" src "\">" src "</span>"

    rows = rows "<tr><td class=\"test-label\">" tname "</td>" \
                "<td><span class=\"badge " badge "\">" disp "</span>" src_tip "</td></tr>\n"
}
END {
    total = pass + fail + na + miss
    if (total == 0) exit

    counted = pass + fail + na
    wp = (counted > 0) ? int(pass * 100 / counted) : 0
    wf = (counted > 0) ? int(fail * 100 / counted) : 0
    wn = (counted > 0) ? int(na   * 100 / counted) : 0

    hdr = "file-header"
    if (fail > 0)  hdr = hdr " has-fail"
    if (miss > 0)  hdr = hdr " has-missing"
    if (fail == 0 && miss == 0) hdr = hdr " all-pass"

    list_tag = (is_list == "1") ? "<span class=\"list-badge\">LIST</span>" : ""
    miss_stat = (miss > 0) ? "<span class=\"stat s-miss\">&#63; " miss "</span>" : ""

    # safe_id: replace non-alphanumeric with underscore for use as HTML id
    safe = list_id
    gsub(/[^a-zA-Z0-9]/, "_", safe)

    print "<section class=\"file-block\" data-list-id=\"" safe "\">"
    print "  <div class=\"" hdr "\">"
    print "    <div class=\"file-title\">"
    print "      <span class=\"file-icon\">&#9654;</span>"
    if (list_tag != "") print "      " list_tag
    print "      <span class=\"list-name\">" label "</span>"
    print "    </div>"
    print "    <div class=\"file-meta\">"
    print "      <span class=\"stat s-pass\">&#10003; " pass "</span>"
    print "      <span class=\"stat s-fail\">&#10007; " fail "</span>"
    print "      <span class=\"stat s-na\">&#9644; " na "</span>"
    if (miss_stat != "") print "      " miss_stat
    print "    </div>"
    print "  </div>"
    print "  <div class=\"health-bar\">"
    print "    <div class=\"hb-pass\" style=\"width:" wp "%\"></div>"
    print "    <div class=\"hb-fail\" style=\"width:" wf "%\"></div>"
    print "    <div class=\"hb-na\"   style=\"width:" wn "%\"></div>"
    print "  </div>"
    print "  <table class=\"result-table\">"
    print "    <thead><tr><th>Test Name</th><th>Result</th></tr></thead>"
    print "    <tbody>"
    printf "%s", rows
    print "    </tbody></table></section>"
}
AWKSECTION

    # awk program for unlisted section
    local awk_unlisted
    awk_unlisted=$(mktemp /tmp/wd_awk2.XXXXXX)
    cat > "$awk_unlisted" << 'AWKUNLISTED'
FNR == NR { claimed[$0] = 1; next }
{
    split($0, f, "\t")
    st = f[1]; tname = f[2]; rptbase = f[3]; rdir = f[4]
    if (tname in claimed) next

    if      (st == "PASS") { badge="badge-pass"; disp="PASS"; pass++ }
    else if (st == "FAIL") { badge="badge-fail"; disp="FAIL"; fail++ }
    else if (st == "NA")   { badge="badge-na";   disp="N/A";  na++   }

    src_tip = "<span class=\"src-tag\" title=\"" rdir "/" rptbase "\">" rptbase "</span>"
    rows = rows "<tr><td class=\"test-label\">" tname "</td>" \
                "<td><span class=\"badge " badge "\">" disp "</span>" src_tip "</td></tr>\n"
}
END {
    total = pass + fail + na
    if (total == 0) exit
    counted = total
    wp = int(pass * 100 / counted)
    wf = int(fail * 100 / counted)
    wn = int(na   * 100 / counted)
    hdr = "file-header" (fail > 0 ? " has-fail" : " all-pass")
    print "<section class=\"file-block\" data-list-id=\"__unlisted__\">"
    print "  <div class=\"" hdr "\">"
    print "    <div class=\"file-title\"><span class=\"file-icon\">&#9654;</span>"
    print "      <span class=\"list-name\">Unlisted Tests</span></div>"
    print "    <div class=\"file-meta\">"
    print "      <span class=\"stat s-pass\">&#10003; " pass "</span>"
    print "      <span class=\"stat s-fail\">&#10007; " fail "</span>"
    print "      <span class=\"stat s-na\">&#9644; " na "</span>"
    print "    </div>"
    print "  </div>"
    print "  <div class=\"health-bar\">"
    print "    <div class=\"hb-pass\" style=\"width:" wp "%\"></div>"
    print "    <div class=\"hb-fail\" style=\"width:" wf "%\"></div>"
    print "    <div class=\"hb-na\"   style=\"width:" wn "%\"></div>"
    print "  </div>"
    print "  <table class=\"result-table\">"
    print "    <thead><tr><th>Test Name</th><th>Result</th></tr></thead>"
    print "    <tbody>"
    printf "%s", rows
    print "    </tbody></table></section>"
}
AWKUNLISTED

    #  5. Compute global totals from map
    local total_pass total_fail total_na
    read -r total_pass total_fail total_na < <(
        awk -F'\t' '
        { if($1=="PASS") p++; else if($1=="FAIL") f++; else if($1=="NA") n++ }
        END { print (p+0), (f+0), (n+0) }
        ' "$map_tmp"
    )

    local ow_p=0 ow_f=0 ow_n=0
    if [[ $total_all -gt 0 ]]; then
        ow_p=$(( total_pass * 100 / total_all ))
        ow_f=$(( total_fail * 100 / total_all ))
        ow_n=$(( total_na   * 100 / total_all ))
    fi

    #  6. Build dir badges
    local dir_badges=""
    for d in "${REPORT_DIRS[@]}"; do
        [[ -d "$d" ]] && dir_badges="${dir_badges}<span class='dir-badge'>$(basename "$d")</span> "
    done

    # ----------------------------------------------------------------
    #  7. Build the list-checkbox panel HTML (injected into the page)
    #     One checkbox per list label, all checked by default.
    # ----------------------------------------------------------------
    local cb_items=""
    for (( i=0; i<nlists; i++ )); do
        local safe_id="${lf_label[$i]//[^a-zA-Z0-9]/_}"
        cb_items="${cb_items}
        <label class=\"cb-item\" title=\"${lf_label[$i]}\">
          <input type=\"checkbox\" class=\"list-toggle\" data-target=\"${safe_id}\" checked>
          <span class=\"cb-name\">${lf_label[$i]}</span>
        </label>"
    done
    # Unlisted toggle (only when show_unlisted is on)
    local cb_unlisted=""
    if [[ "$SHOW_UNLISTED" == "1" ]]; then
        cb_unlisted='<label class="cb-item" title="Unlisted Tests">
          <input type="checkbox" class="list-toggle" data-target="__unlisted__" checked>
          <span class="cb-name">Unlisted Tests</span>
        </label>'
    fi

    #  8. Write HTML atomically
    local tmp_html; tmp_html="${OUTPUT_HTML}.tmp.$$"

    cat > "$tmp_html" << HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>MASTER_REPORT  Test Summary</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=Share+Tech+Mono&family=Rajdhani:wght@400;600;700&display=swap');
:root{
  --bg:#0d0f14;--surface:#141720;--border:#1e2535;
  --pass:#00e676;--fail:#ff1744;--na:#546e7a;--miss:#f59e0b;
  --accent:#00b0ff;--text:#cdd6f4;--muted:#4a5568;--header-bg:#10131a;
}
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
body{background:var(--bg);color:var(--text);font-family:'Rajdhani',sans-serif;font-size:15px;min-height:100vh}
body::before{content:'';position:fixed;inset:0;pointer-events:none;z-index:999;
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
  color:var(--accent);font-size:.68rem;padding:2px 8px;border-radius:3px;
  font-family:'Share Tech Mono',monospace}
.global-bar{display:flex;height:5px;background:var(--border)}
.gb-pass{background:var(--pass)}.gb-fail{background:var(--fail)}.gb-na{background:var(--na)}
.scoreboard{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));
  gap:1px;background:var(--border);border-bottom:1px solid var(--border)}
.score-card{background:var(--surface);padding:16px 18px;text-align:center}
.score-num{font-family:'Share Tech Mono',monospace;font-size:2.4rem;line-height:1}
.score-label{font-size:.7rem;letter-spacing:2px;text-transform:uppercase;color:var(--muted);margin-top:4px}
.sc-pass .score-num{color:var(--pass);text-shadow:0 0 20px rgba(0,230,118,.35)}
.sc-fail .score-num{color:var(--fail);text-shadow:0 0 20px rgba(255,23,68,.35)}
.sc-na   .score-num{color:var(--na)}
.sc-total .score-num{color:var(--accent)}
main{padding:24px 28px;max-width:1100px;margin:0 auto}
.section-heading{font-family:'Share Tech Mono',monospace;font-size:.67rem;letter-spacing:3px;
  text-transform:uppercase;color:var(--muted);margin-bottom:12px;
  border-left:3px solid var(--accent);padding-left:10px}
.file-block{background:var(--surface);border:1px solid var(--border);border-radius:4px;
  margin-bottom:14px;overflow:hidden;transition:border-color .2s}
.file-block:hover{border-color:var(--accent)}
.file-block.list-hidden{display:none}
.file-header{padding:12px 16px;display:flex;align-items:center;justify-content:space-between;
  flex-wrap:wrap;gap:8px;background:rgba(255,255,255,.02);cursor:pointer;
  border-bottom:1px solid var(--border);user-select:none}
.file-header.has-fail{border-left:3px solid var(--fail)}
.file-header.has-missing:not(.has-fail){border-left:3px solid var(--miss)}
.file-header.all-pass{border-left:3px solid var(--pass)}
.file-title{display:flex;align-items:center;gap:8px}
.file-icon{color:var(--accent);font-size:.78rem;transition:transform .2s;display:inline-block}
.file-block.collapsed .file-icon{transform:rotate(-90deg)}
.list-name{font-size:.95rem;font-weight:700;color:var(--accent);font-family:'Share Tech Mono',monospace}
.list-badge{background:rgba(0,176,255,.12);border:1px solid rgba(0,176,255,.3);
  color:var(--accent);font-size:.62rem;padding:1px 6px;border-radius:2px;
  font-family:'Share Tech Mono',monospace;letter-spacing:1px}
.file-meta{display:flex;align-items:center;gap:10px;flex-wrap:wrap}
.stat{font-family:'Share Tech Mono',monospace;font-size:.82rem;font-weight:700}
.s-pass{color:var(--pass)}.s-fail{color:var(--fail)}.s-na{color:var(--na)}.s-miss{color:var(--miss)}
.health-bar{display:flex;height:3px}
.hb-pass{background:var(--pass)}.hb-fail{background:var(--fail)}.hb-na{background:var(--na)}
.result-table{width:100%;border-collapse:collapse;font-family:'Share Tech Mono',monospace;font-size:.8rem}
.result-table th{text-align:left;padding:7px 16px;background:rgba(255,255,255,.03);
  color:var(--muted);font-size:.66rem;letter-spacing:2px;text-transform:uppercase;
  border-bottom:1px solid var(--border)}
.result-table td{padding:6px 16px;border-bottom:1px solid rgba(30,37,53,.8)}
.result-table tr:last-child td{border-bottom:none}
.result-table tr:hover td{background:rgba(255,255,255,.025)}
.test-label{color:var(--text)}
.badge{display:inline-block;padding:2px 9px;border-radius:2px;font-size:.7rem;font-weight:700;letter-spacing:1.5px}
.badge-pass{background:rgba(0,230,118,.12);color:var(--pass);border:1px solid rgba(0,230,118,.3)}
.badge-fail{background:rgba(255,23,68,.12);color:var(--fail);border:1px solid rgba(255,23,68,.3)}
.badge-na{background:rgba(84,110,122,.15);color:var(--na);border:1px solid rgba(84,110,122,.3)}
.badge-miss{background:rgba(245,158,11,.1);color:var(--miss);border:1px solid rgba(245,158,11,.3)}
.src-tag{font-size:.63rem;color:var(--muted);margin-left:7px;cursor:help;
  border-bottom:1px dotted var(--muted);opacity:.7}
.src-tag:hover{color:var(--accent);opacity:1}
.file-block.collapsed .result-table,.file-block.collapsed .health-bar{display:none}
footer{text-align:center;padding:18px;font-size:.7rem;color:var(--muted);
  font-family:'Share Tech Mono',monospace;border-top:1px solid var(--border);margin-top:24px}

/*  List-visibility checkbox panel  */
.list-panel{
  background:var(--surface);border:1px solid var(--border);border-radius:4px;
  margin-bottom:16px;overflow:hidden}
.list-panel-header{
  display:flex;align-items:center;justify-content:space-between;
  padding:9px 14px;border-bottom:1px solid var(--border);cursor:pointer;
  user-select:none;background:rgba(0,176,255,.04)}
.list-panel-title{
  font-family:'Share Tech Mono',monospace;font-size:.7rem;letter-spacing:2px;
  text-transform:uppercase;color:var(--accent)}
.panel-actions{display:flex;gap:8px}
.pact-btn{
  font-family:'Share Tech Mono',monospace;font-size:.65rem;letter-spacing:1px;
  padding:2px 9px;border:1px solid var(--border);border-radius:2px;
  background:transparent;color:var(--muted);cursor:pointer;transition:all .15s}
.pact-btn:hover{border-color:var(--accent);color:var(--accent)}
.list-panel-body{
  display:flex;flex-wrap:wrap;gap:6px 10px;
  padding:10px 14px}
.cb-item{
  display:flex;align-items:center;gap:6px;cursor:pointer;
  font-family:'Share Tech Mono',monospace;font-size:.72rem;
  color:var(--text);padding:3px 8px;border-radius:2px;
  border:1px solid transparent;transition:border-color .15s;
  white-space:nowrap}
.cb-item:hover{border-color:var(--border)}
.cb-item input[type=checkbox]{
  accent-color:var(--accent);width:13px;height:13px;cursor:pointer;flex-shrink:0}
.cb-item input[type=checkbox]:not(:checked) ~ .cb-name{
  color:var(--muted);text-decoration:line-through}
.cb-name{transition:color .15s}
</style>
</head>
<body>
<header>
  <div>
    <span class="logo-main">&#9632; MASTER_REPORT</span>
    <span class="logo-sub">Test Summary Dashboard</span>
  </div>
  <div class="header-right">
    ${dir_badges}
    <span class="last-update">Updated: ${ts} &nbsp;|&nbsp; F5 to refresh</span>
  </div>
</header>
<div class="global-bar">
  <div class="gb-pass" style="width:${ow_p}%"></div>
  <div class="gb-fail" style="width:${ow_f}%"></div>
  <div class="gb-na"   style="width:${ow_n}%"></div>
</div>
<div class="scoreboard">
  <div class="score-card sc-total"><div class="score-num">${total_all}</div><div class="score-label">Total (dedup)</div></div>
  <div class="score-card sc-pass"><div class="score-num">${total_pass}</div><div class="score-label">Pass</div></div>
  <div class="score-card sc-fail"><div class="score-num">${total_fail}</div><div class="score-label">Fail</div></div>
  <div class="score-card sc-na"><div class="score-num">${total_na}</div><div class="score-label">N/A</div></div>
</div>
<main>
  <p class="section-heading">${nrpt} rpt file(s) &bull; ${nlists} list(s) &bull; newest rpt wins on duplicates</p>

  <!--  List visibility panel  -->
  <div class="list-panel" id="listPanel">
    <div class="list-panel-header" id="listPanelToggle">
      <span class="list-panel-title">&#9634; List visibility</span>
      <div class="panel-actions" onclick="event.stopPropagation()">
        <button class="pact-btn" id="btnAll">Check all</button>
        <button class="pact-btn" id="btnNone">Uncheck all</button>
      </div>
    </div>
    <div class="list-panel-body" id="listPanelBody">
      ${cb_items}
      ${cb_unlisted}
    </div>
  </div>
HTML

    # Stream each list section
    local i=0
    while [[ $i -lt $nlists ]]; do
        local safe_id="${lf_label[$i]//[^a-zA-Z0-9]/_}"
        awk -v label="${lf_label[$i]}" -v is_list="1" -v list_id="${lf_label[$i]}" \
            -f "$awk_section" \
            "$map_tmp" "${lf_tmp[$i]}" >> "$tmp_html" || true
        i=$(( i + 1 ))
    done

    # Unlisted section
    if [[ "$SHOW_UNLISTED" == "1" && $nlists -gt 0 ]]; then
        awk -f "$awk_unlisted" "$claimed_tmp" "$map_tmp" >> "$tmp_html" || true
    elif [[ $nlists -eq 0 ]]; then
        : > "$claimed_tmp"
        awk -f "$awk_unlisted" "$claimed_tmp" "$map_tmp" >> "$tmp_html" || true
    fi

    cat >> "$tmp_html" << 'HTMLFOOT'
</main>
<footer>MASTER_REPORT watchdog &bull; F5 to refresh</footer>
<script>
//  collapse/expand sections 
document.querySelectorAll('.file-header').forEach(h =>
  h.addEventListener('click', () => h.closest('.file-block').classList.toggle('collapsed'))
);

//  List-visibility checkboxes 
document.querySelectorAll('.list-toggle').forEach(cb => {
  cb.addEventListener('change', () => {
    const target = cb.dataset.target;
    const block = document.querySelector(`.file-block[data-list-id="${target}"]`);
    if (block) block.classList.toggle('list-hidden', !cb.checked);
  });
});

// Check-all / Uncheck-all buttons
document.getElementById('btnAll').addEventListener('click', () => {
  document.querySelectorAll('.list-toggle').forEach(cb => {
    cb.checked = true;
    cb.dispatchEvent(new Event('change'));
  });
});
document.getElementById('btnNone').addEventListener('click', () => {
  document.querySelectorAll('.list-toggle').forEach(cb => {
    cb.checked = false;
    cb.dispatchEvent(new Event('change'));
  });
});

//  Collapse/expand the panel itself 
document.getElementById('listPanelToggle').addEventListener('click', () => {
  const body = document.getElementById('listPanelBody');
  body.style.display = body.style.display === 'none' ? '' : 'none';
});

//  filter state 
// activeFilters is a Set of keys; empty Set = show ALL
let activeFilters = new Set();
let searchText    = '';

function applyFilters() {
  const showAll = activeFilters.size === 0;
  document.querySelectorAll('.file-block').forEach(block => {
    if (block.classList.contains('list-hidden')) return;
    let visibleCount = 0;
    block.querySelectorAll('tbody tr').forEach(row => {
      const name   = row.querySelector('.test-label')?.textContent.toLowerCase() ?? '';
      const badge  = row.querySelector('.badge')?.textContent.trim() ?? '';
      const badgeKey = badge === 'PASS' ? 'PASS'
                     : badge === 'FAIL' ? 'FAIL'
                     : badge === 'N/A'  ? 'NA'
                     : 'MISS';
      const matchFilter = showAll || activeFilters.has(badgeKey);
      const matchSearch = name.includes(searchText);
      if (matchFilter && matchSearch) { row.style.display = ''; visibleCount++; }
      else row.style.display = 'none';
    });
    const tableWrap = block.querySelector('.result-table');
    if (tableWrap) tableWrap.style.display = visibleCount === 0 ? 'none' : '';
  });
}

//  toolbar injection 
document.addEventListener('DOMContentLoaded', () => {
  const main = document.querySelector('main');
  if (!main) return;

  const toolbar = document.createElement('div');
  toolbar.className = 'filter-toolbar';
  toolbar.innerHTML = `
    <div class="filter-group">
      <span class="filter-label">RESULT</span>
      <button class="fbtn active" data-f="ALL">ALL</button>
      <button class="fbtn pass"   data-f="PASS">PASS</button>
      <button class="fbtn fail"   data-f="FAIL">FAIL</button>
      <button class="fbtn na"     data-f="NA">N/A</button>
      <button class="fbtn miss"   data-f="MISS">&mdash;</button>
    </div>
    <div class="filter-group">
      <span class="filter-label">TEST NAME</span>
      <div class="search-wrap">
        <span class="search-icon">&#128269;</span>
        <input id="nameSearch" class="name-search" type="text" placeholder="filter test name" autocomplete="off" spellcheck="false">
        <button class="clear-btn" id="clearSearch" title="clear">&#10005;</button>
      </div>
    </div>
    <div class="filter-group">
      <span class="match-count" id="matchCount"></span>
    </div>
  `;
  // Insert after the list panel
  const listPanel = document.getElementById('listPanel');
  if (listPanel && listPanel.nextSibling) {
    main.insertBefore(toolbar, listPanel.nextSibling);
  } else {
    main.insertBefore(toolbar, main.firstChild);
  }

  toolbar.querySelectorAll('.fbtn').forEach(btn => {
    btn.addEventListener('click', () => {
      const f = btn.dataset.f;
      if (f === 'ALL') {
        // ALL clears all selections  show everything
        activeFilters.clear();
        toolbar.querySelectorAll('.fbtn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
      } else {
        // Toggle this filter key
        if (activeFilters.has(f)) {
          activeFilters.delete(f);
          btn.classList.remove('active');
        } else {
          activeFilters.add(f);
          btn.classList.add('active');
        }
        // ALL button is active only when nothing else is selected
        const allBtn = toolbar.querySelector('.fbtn[data-f="ALL"]');
        if (activeFilters.size === 0) {
          allBtn.classList.add('active');
        } else {
          allBtn.classList.remove('active');
        }
      }
      applyFilters();
      updateMatchCount();
    });
  });

  const input = document.getElementById('nameSearch');
  const clearBtn = document.getElementById('clearSearch');

  input.addEventListener('input', () => {
    searchText = input.value.toLowerCase();
    clearBtn.style.display = searchText ? 'flex' : 'none';
    applyFilters();
    updateMatchCount();
  });

  clearBtn.addEventListener('click', () => {
    input.value = '';
    searchText = '';
    clearBtn.style.display = 'none';
    applyFilters();
    updateMatchCount();
  });

  function updateMatchCount() {
    let total = 0, visible = 0;
    document.querySelectorAll('tbody tr').forEach(r => {
      total++;
      if (r.style.display !== 'none') visible++;
    });
    const el = document.getElementById('matchCount');
    if (el) el.textContent = (activeFilters.size > 0 || searchText)
      ? `${visible} / ${total} shown` : '';
  }
});
</script>
<style>
.filter-toolbar{
  display:flex; flex-wrap:wrap; align-items:center; gap:16px;
  background:var(--surface); border:1px solid var(--border); border-radius:4px;
  padding:12px 16px; margin-bottom:16px;
}
.filter-label{
  font-family:'Share Tech Mono',monospace; font-size:.65rem; letter-spacing:2px;
  text-transform:uppercase; color:var(--muted); margin-right:6px;
}
.filter-group{ display:flex; align-items:center; gap:6px; flex-wrap:wrap; }
.fbtn{
  font-family:'Share Tech Mono',monospace; font-size:.72rem; font-weight:700;
  letter-spacing:1px; padding:3px 12px; border-radius:2px; cursor:pointer;
  border:1px solid var(--border); background:transparent; color:var(--muted);
  transition:all .15s;
}
.fbtn:hover{ border-color:var(--accent); color:var(--accent); }
.fbtn.active{ background:rgba(0,176,255,.15); border-color:var(--accent); color:var(--accent); }
.fbtn.pass.active{ background:rgba(0,230,118,.12); border-color:var(--pass); color:var(--pass); }
.fbtn.fail.active{ background:rgba(255,23,68,.12);  border-color:var(--fail); color:var(--fail); }
.fbtn.na.active  { background:rgba(84,110,122,.15); border-color:var(--na);   color:var(--na);   }
.fbtn.miss.active{ background:rgba(245,158,11,.1);  border-color:var(--miss); color:var(--miss); }
.search-wrap{
  display:flex; align-items:center; gap:0;
  background:var(--bg); border:1px solid var(--border); border-radius:2px;
  padding:2px 8px; transition:border-color .15s;
}
.search-wrap:focus-within{ border-color:var(--accent); }
.search-icon{ color:var(--muted); font-size:.8rem; margin-right:6px; }
.name-search{
  background:transparent; border:none; outline:none;
  color:var(--text); font-family:'Share Tech Mono',monospace; font-size:.8rem;
  width:220px; padding:2px 0;
}
.name-search::placeholder{ color:var(--muted); }
.clear-btn{
  display:none; align-items:center; justify-content:center;
  background:transparent; border:none; color:var(--muted); cursor:pointer;
  font-size:.7rem; padding:0 2px; margin-left:4px;
}
.clear-btn:hover{ color:var(--fail); }
.match-count{
  font-family:'Share Tech Mono',monospace; font-size:.72rem;
  color:var(--accent); letter-spacing:1px;
}
</style>
</body>
</html>
HTMLFOOT

    mv "$tmp_html" "$OUTPUT_HTML"

    rm -f "$map_tmp" "$awk_section" "$awk_unlisted" "$claimed_tmp"
    for (( i=0; i<nlists; i++ )); do rm -f "${lf_tmp[$i]}"; done

    log "HTML written  $OUTPUT_HTML  (pass=${total_pass} fail=${total_fail} na=${total_na} total=${total_all})"
}

# =============================================================================
# snapshot  mtime fingerprint of all monitored files
# =============================================================================
snapshot() {
    for d in "${REPORT_DIRS[@]}"; do
        [[ -d "$d" ]] && find "$d" -maxdepth 1 -name '*.rpt' -printf '%p %T@\n' 2>/dev/null || true
    done
    for lf in "${LIST_FILES[@]}"; do
        [[ -f "$lf" ]] && find "$lf" -printf '%p %T@\n' 2>/dev/null || true
    done
}

# =============================================================================
# Main
# =============================================================================
for d in "${REPORT_DIRS[@]}"; do
    [[ -d "$d" ]] || { log "Creating $d ..."; mkdir -p "$d"; }
done

generate_html
last_snap=$(snapshot | sort)
log "Entering watch loop (Ctrl-C or kill \$\$ to stop)..."

while true; do
    sleep "$POLL_INTERVAL"
    cur_snap=$(snapshot | sort)
    if [[ "$cur_snap" != "$last_snap" ]]; then
        log "Change detected  regenerating..."
        generate_html
        last_snap="$cur_snap"
    fi
done


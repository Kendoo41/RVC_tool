# Legacy scripts (original tools)

These are the **original** scripts this project was built from, kept for
reference and lineage. The unified `rvc` tool reimplements their logic in one
place; you normally use `rvc`, not these.

| Folder | Original script | Author | Replaced by |
|--------|-----------------|--------|-------------|
| `pattern_summary/` | `magic.py` | KhoiDao | `rvc_tool/vil.py` (+ `rvc itemlist`) |
| `check_result/` | `watchdog_2.sh` | KhoiDao | `rvc_tool/master_report.py` + `report_html.py` (`rvc build [--watch]`) |
| `pattern_description/` | `gen_pattern_description_no_comp.pl/.sh`, `create_list.csh`, `pattern_diff.sh` | thuythanhnguyen | `rvc_tool/patterns.py` (source collection) |
| `update_listfile/` | `05_filter_pa_ng_pattern.csh` | KhoiDao | `rvc_tool/listfile.py` (`rvc filter`) |

## Why keep them?

* **`gen_pattern_description_no_comp.pl`** still produces the *formal* Renesas
  "Module Pattern Description" workbook (Cover sheet, revision history, the exact
  corporate template). The `rvc` tool's Excel is for **AI / review**, not that
  formal document, so the Perl generator remains useful as-is.
* **`watchdog_2.sh`** documents the exact `.rpt` result-line format
  (`[OK]`/`[NG]`/`[N/A]`) that `rvc_tool/master_report.py` parses.
* **`magic.py`** documents the VIL header-detection heuristic that
  `rvc_tool/vil.py` keeps unchanged.

The proprietary sample data that came with these scripts (VIL workbooks,
project `.list` files, master reports) is intentionally **not** committed.

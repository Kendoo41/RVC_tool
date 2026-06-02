# RVC tool — Renesas Verification Companion

Gộp **4 đối tượng** mà một Verifier MCU phải xử lý lặp đi lặp lại — *list file*,
*Verification Item List (VIL)*, *patterns*, và *master report* — thành **một
dashboard HTML**, **một file Excel để AI review**, và **một bộ lọc list file
thông minh hơn**.

Tất cả nối với nhau bằng **tên pattern trần** (thành phần cuối sau dấu `/`).
Ví dụ `HBUS_TOP/sub/cpuss_addr_spi0` → `cpuss_addr_spi0`, là khóa chung khớp
giữa list file, VIL, thư mục pattern và dòng `.rpt` trong master report.

```
   list file ─┐
   VIL ────────┤            ┌─► report.html  (dashboard, click pattern → checkpoint + source)
   master rpt ─┼─► rvc ─────┼─► report_data.js / .json  (chi tiết, lazy-load)
   patterns ──┘            └─► rvc_review.xlsx  (2 sheet: By Checkpoint + By Pattern, cho AI)
```

---

## Tool này thay thế những gì

| Script gốc của bạn | Việc nó làm | Trong `rvc` |
|---|---|---|
| `magic.py` | VIL → priority + checkpoint | `rvc build`, `rvc itemlist` |
| `watchdog_2.sh` (check_result) | master report → status + HTML | `rvc build [--watch]` |
| `gen_pattern_description*.pl` | pattern → nội dung file nguồn | thu thập source trong `rvc build` |
| `05_filter_pa_ng_pattern.csh` | comment/uncomment list theo status | `rvc filter` |

Các script gốc được giữ trong [`legacy/`](legacy/) để tham chiếu.

---

## Cài đặt

Chỉ cần Python ≥ 3.7 và `openpyxl`.

```bash
pip install openpyxl          # phụ thuộc duy nhất
# (tuỳ chọn) cài lệnh `rvc`:
pip install -e .
```

Nếu không cài, chạy trực tiếp bằng `python -m rvc_tool ...` (tương đương `rvc ...`).

---

## Chạy thử ngay (demo, không cần data thật)

```bash
python examples/make_demo.py                       # sinh data giả lập
python -m rvc_tool build -c examples/rvc.example.json
# → mở rvc_out/report.html
```

---

## Cấu hình (`rvc.json`)

Tạo file JSON trỏ tới data thật của bạn (xem `examples/rvc.example.json`):

```json
{
  "report_dirs": [
    "/svhome/.../99_MASTER_REPORT/v001/..._004_rtl",
    "/svhome/.../99_MASTER_REPORT/v001/..._003_rtl"
  ],
  "list_files": [
    "/common/work/khoidao/S_item.list",
    "/common/work/khoidao/A_item.list",
    "/common/work/khoidao/B_item.list"
  ],
  "vil_dir":      "/shsv/.../1_VIL",
  "pattern_dirs": ["/shsv/.../testcase/HBUS_TOP"],
  "output_dir":   "rvc_out"
}
```

| Khóa | Ý nghĩa |
|---|---|
| `report_dirs` | Các thư mục chứa `*.rpt` (master report). `.rpt` mới nhất thắng khi trùng. |
| `list_files` | Các `.list` để gom nhóm (mỗi list = 1 section trên dashboard). |
| `vil_dir` / `vil_files` | Thư mục (hoặc danh sách) file VIL `*.xlsx`. |
| `pattern_dirs` | Các cây testcase chứa folder pattern (để lấy nội dung file nguồn). |
| `include_content` | `true` = nhúng source vào data file/Excel. |
| `include_unlisted` | `true` = hiện cả test có trong report nhưng không nằm trong list nào. |
| `max_file_bytes` | Giới hạn dung lượng mỗi file nguồn (mặc định 200 KB). |

Mọi khóa đều ghi đè được bằng cờ dòng lệnh (`--report-dir`, `--list-file`, …).

---

## Lệnh

### `rvc build` — sinh dashboard + Excel
```bash
rvc build -c rvc.json
rvc build -c rvc.json --watch          # live: tự rebuild khi .rpt đổi (như watchdog cũ)
rvc build -c rvc.json --no-content     # không nhúng source (file nhẹ hơn)
```
Kết quả trong `output_dir`: `report.html`, `report_data.js`, `report_data.json`,
`rvc_review.xlsx`.

> VIL và cây pattern chỉ quét **một lần**; ở chế độ `--watch` chỉ master report
> được đọc lại khi có `.rpt` thay đổi → rất nhanh.

#### Chạy nhanh "chỉ xem kết quả sim" (như *skip compile, run thẳng*)

Đọc VIL (`.xlsx`) và quét cây pattern là phần **chậm nhất**. Khi chỉ cần xem
PASS/FAIL/NA của master report, bỏ qua chúng:

```bash
rvc build -c rvc.json --fast           # bỏ CẢ VIL lẫn pattern → dashboard status-only
rvc build -c rvc.json --no-vil         # bỏ VIL (mất cột Priority + checkpoint)
rvc build -c rvc.json --no-patterns    # bỏ quét source (drawer không có file nguồn)
```

| Cờ | Bỏ qua | Mất gì trên dashboard |
|---|---|---|
| `--no-vil` | quét VIL `.xlsx` | cột **Priority** + bảng **checkpoint** |
| `--no-patterns` | quét cây testcase | **nội dung file nguồn** trong drawer |
| `--fast` | cả hai | chỉ còn **status sim** (Pass/Fail/N/A/Not-run) + scoreboard |

> Muốn lặp nhiều lần mà vẫn có đủ chi tiết? Dùng `--watch`: VIL + pattern quét
> **một lần** lúc khởi động, sau đó mỗi lần `.rpt` đổi chỉ master report được
> đọc lại. `--fast` hợp với kiểm tra **một phát cho nhanh**; `--watch` hợp với
> **theo dõi liên tục** một phiên dài.

### `rvc filter` — cập nhật list file theo status (thay `05_filter`)
```bash
# Mặc định: comment các pattern đã PASS/FAIL/NA, chỉ chừa pattern chưa chạy
rvc filter hbus_QOS_testcase_rtl.list -c rvc.json

# Chỉ chừa active các pattern FAIL (để chạy lại fail)
rvc filter my.list --report-dir /.../MASTER_REPORT --keep FAIL

# Chỉ comment PASS (giữ FAIL + N/A + chưa chạy)
rvc filter my.list --report-dir /.../MASTER_REPORT --comment PASS

rvc filter my.list --restore           # bỏ comment mọi dòng do tool đánh dấu
rvc filter my.list ... --dry-run        # xem trước, không ghi
```
**Cải tiến so với `05_filter`:**
* **Không cần** truyền `HBUS_TOP` — tự nhận dòng pattern (bỏ dòng option `-fcc`,
  `--no_compile`, …, bỏ comment, bỏ hierarchy, lấy tên pattern cuối).
* Comment bằng `#PSS`/`#NG `/`#NA ` và **khôi phục lại y hệt** bản gốc.
* **Không đụng** vào dòng bạn tự comment tay (chỉ quản marker của tool).

### `rvc itemlist` — sinh `S/A/B_item.list` từ priority VIL
```bash
rvc itemlist --vil-dir /shsv/.../1_VIL --output-dir lists/
```

### `rvc serve` — mở dashboard qua http (để drawer fetch JSON khi cần)
```bash
rvc serve rvc_out --port 8000          # http://localhost:8000/report.html
```

#### `rvc serve --exec` — bấm pattern để chạy lại trên Linux

Bật một endpoint cho phép **nút ▶ Run** trong drawer chạy `frun` cho đúng
pattern bạn bấm — khép kín với `--watch` (chạy → sinh `.rpt` → dashboard tự
đổi status).

```bash
# Chạy TRÊN máy Linux có frun. Mặc định --exec chỉ nghe 127.0.0.1.
rvc serve rvc_out --exec --frun frun --run-cwd /common/work/khoidao/RVC_tool
# rồi mở http://localhost:8000/report.html, click pattern → ▶ Run
```

Cách hoạt động: bấm pattern → trình duyệt gọi `POST /rvc/run` → server ghi một
**list 1 dòng tạm** (đúng dòng của pattern đó, lấy từ `report_data.json`) vào
`<serve_dir>/.rvc_runs/` rồi chạy `frun <list_đó>` **bất đồng bộ** (log ra
`.rvc_runs/*.log`). Vì `frun` thường submit job LSF, nút có hộp **xác nhận**
trước khi chạy.

| Cờ | Ý nghĩa |
|---|---|
| `--exec` | bật `/rvc/run` (mặc định **tắt** → dashboard chỉ xem). |
| `--frun` | tên lệnh chạy (mặc định `frun`). |
| `--run-cwd` | thư mục làm việc khi chạy lệnh (mặc định thư mục hiện tại). |
| `--host` | địa chỉ bind (mặc định loopback khi `--exec`). |
| `--token` | bắt buộc header `X-RVC-Token` cho `/rvc/run`. |

**An toàn theo thiết kế:**
* Client chỉ gửi **tên pattern**; dòng lệnh thật lấy từ **whitelist** trong
  `report_data.json` — tên lạ bị từ chối (không inject được).
* Chạy bằng **list-args, không `shell=True`**.
* `--exec` **tắt mặc định**; mở `file://` trang không hề dò server → **không
  chạy được gì**, nút Run ẩn.
* Chỉ nghe **127.0.0.1** trừ khi bạn tự đặt `--host`; nếu mở ra mạng, tool
  **cảnh báo** và bạn nên kèm `--token`.

> ⚠️ Đây là endpoint chạy lệnh trên login node dùng chung. Chỉ bật `--exec`
> trên máy/cổng bạn kiểm soát; ra mạng thì luôn dùng `--token`.

---

## Dashboard HTML

Kế thừa giao diện dark của `check_result`, thêm:

### Hai viewpoint (2 tab)

Dashboard có **2 tab** vì có hai câu hỏi khác nhau:

| Tab | Gốc là | Trả lời câu hỏi |
|---|---|---|
| **List View** | list file + master report | *"Những gì đã đưa vào list chạy ra sao?"* (Pass/Fail/N/A/Not-run) |
| **VIL View** | **Verification Item List** | *"Mọi item trong kế hoạch đã được list để chạy chưa?"* |

> **Vì sao cần VIL View:** List View chỉ thấy pattern đã nằm trong list/report —
> một VIL item **chưa được list** sẽ vô hình. VIL View liệt kê **mọi** item của
> VIL (nhóm theo priority S/A/B), thêm cột **In list?**: item nào chưa có trong
> list nào sẽ bị đánh dấu **✗ NOT LISTED** — đó chính là *coverage gap* (đã lên
> kế hoạch nhưng chưa đưa vào chạy). Scoreboard VIL View hiện **VIL items /
> In list / Not listed** + Pass/Fail/Not-run, lọc nhanh theo **Not listed**.
> Tab được nhớ qua `localStorage` như các trạng thái xem khác.

* **Cột Priority** (S/A/B từ VIL) + scoreboard (Total / Pass / Fail / N/A / Not-run).
* **Click vào pattern** → mở **drawer** bên phải hiển thị:
  * bảng **checkpoint** (Main / Middle / Detailed / Confirmation + nguồn VIL),
  * **nội dung file nguồn** (.s/.asm/.c → .v → .sv), mỗi file một khối gập/mở.
* Lọc theo **Result**, **Priority**, **tên**; ẩn/hiện từng list; gập/mở section.
* **Nhớ trạng thái xem**: list nào đang ẩn + ô tìm kiếm + filter Result/Priority
  được lưu trong `localStorage` của trình duyệt. Tắt vài list rồi **build lại để
  cập nhật status** (hoặc reload trang) thì view vẫn giữ nguyên; bấm **Reset** để
  xoá và hiện lại toàn bộ. (Lưu theo đường dẫn trang nên nhiều dashboard không
  đè nhau; vài trình duyệt chặn `localStorage` trên `file://` thì tự bỏ qua,
  không lỗi.)

> **Đóng gói:** trang `report.html` cố ý **nhẹ** (chỉ bảng). Chi tiết nặng nằm
> trong `report_data.js` (nạp như `window.__RVC_DATA__`, chạy được khi **mở
> trực tiếp file://**) và `report_data.json` (cho AI/khi serve qua http). Để
> drawer hoạt động, giữ `report.html` cùng thư mục với `report_data.js`.

---

## Excel cho AI review (`rvc_review.xlsx`)

* **Summary** — tổng theo status, theo priority, theo từng list, **+ VIL coverage**
  (VIL items / In a list / NOT listed) cho cùng góc nhìn với VIL View.
* **By Checkpoint** — *mỗi dòng = 1 checkpoint* (pattern, priority, status, Main/
  Middle/Detailed/Confirmation, nguồn VIL, file nguồn) + 2 cột trống
  **`Reflected? (AI)`** và **`Evidence / Notes (AI)`** để AI điền khi đối chiếu
  checkpoint ↔ pattern.
* **By Pattern** — *mỗi dòng = 1 pattern* (gộp checkpoint, file nguồn, sim
  options, nội dung source cắt ngắn).

---

## Định dạng dữ liệu mà tool hiểu

* **list file**: dòng option bắt đầu bằng `-`/`--`; comment bắt đầu bằng `#`;
  còn lại là pattern `MODULE/.../name [options]`.
* **VIL** `.xlsx`: hàng header chứa đồng thời *"Main item"*, *"Name of test
  pattern"*, *"Confirmation"*; data bắt đầu 2 hàng dưới (heuristic của `magic.py`).
* **master report** `.rpt`: `[OK]`→PASS, `[NG]`→FAIL, `[N/A]`→NA, vắng mặt→
  *Not run* (`—`). Tên test = thành phần cuối của path, đã bỏ ` --options`.
* **patterns**: folder trùng tên pattern, chứa `.s/.asm/.c/.S` + `.v` + `.sv`.

---

## Test

```bash
python tests/test_rvc.py        # hoặc: python -m pytest tests/
```

---

## Ghi chú

* Tool chạy trên máy EDA (Linux) có sẵn đường dẫn thật; container/CI chỉ cần
  `openpyxl`.
* Hyperlink trong Excel cũ (Linux→Windows UNC) không cần nữa — dashboard HTML
  thay thế việc điều hướng đó.

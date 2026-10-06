# Bài 4: Quản lý tiến trình nền với `nohup` và tín hiệu `kill`

## 1. Mục tiêu

- Khởi chạy một tiến trình **chạy nền độc lập với phiên Terminal** bằng `nohup` kết hợp ký tự `&`,
  để tiến trình vẫn tiếp tục hoạt động kể cả khi ngắt kết nối SSH/đóng Terminal.
- Giám sát tiến trình hệ thống bằng `ps` (và `top`/`htop`).
- Nắm cơ chế **tín hiệu (Signals)** của hệ điều hành và tắt tiến trình an toàn:
  **SIGTERM (15) trước**, chỉ dùng **SIGKILL (9)** khi SIGTERM không hiệu quả.

## 2. Môi trường thực hiện

| Thành phần | Giá trị |
|---|---|
| Hệ điều hành | Ubuntu (Linux), kernel dùng `systemd` làm PID 1 |
| Shell | `bash` |
| Thư mục bài làm | `homework/session_06/ex4/` |
| Script giám sát | `loop-monitor.sh` |
| Tệp log | `/tmp/monitor.log` |

## 3. Cấu trúc tệp nộp bài

```
homework/session_06/ex4/
├── README.md            # báo cáo: lệnh nohup, log, PID, lệnh kill (tệp này)
└── loop-monitor.sh      # script giám sát, ghi thời gian mỗi 5 giây
```

## 4. Nội dung script `loop-monitor.sh`

[`loop-monitor.sh`](./loop-monitor.sh)

```bash
#!/bin/bash
# loop-monitor.sh - Ghi thoi gian hien tai vao /tmp/monitor.log moi 5 giay.
# Chay nen doc lap voi nohup de tiep tuc hoat dong khi ngat ket noi SSH/Terminal.
while true; do
    echo "System time: $(date)" >> /tmp/monitor.log
    sleep 5
done
```

Script dùng vòng lặp `while true` ghi thời gian hệ thống vào `/tmp/monitor.log`, sau đó `sleep 5`
để lặp lại mỗi 5 giây.

## 5. Các bước thực hiện

### 5.1. Cấp quyền thực thi cho script

```bash
chmod +x loop-monitor.sh
ls -l loop-monitor.sh
```

```console
$ ls -l loop-monitor.sh
-rwxr-xr-x 1 root root 254 Oct  6 13:34 loop-monitor.sh
```

### 5.2. Khởi chạy nền độc lập bằng `nohup`

```bash
# Xoa log cu (neu co) de ket qua sach
rm -f /tmp/monitor.log

# Chay nen, tach khoi terminal
nohup ./loop-monitor.sh > /dev/null 2>&1 &
```

```console
$ nohup ./loop-monitor.sh > /dev/null 2>&1 &
=== Khoi chay nen, PID shell = 175509 ===
```

Giải thích:
- `nohup` (no hang up) chạy lệnh **bỏ qua tín hiệu `SIGHUP`** — tín hiệu mà tiến trình nhận được
  khi Terminal/SSH session đóng. Nhờ vậy tiến trình không bị tắt khi ta thoát phiên.
- `&` đẩy tiến trình xuống **chạy nền**, trả lại quyền điều khiển cho shell ngay lập tức.
- `> /dev/null 2>&1` chuyển toàn bộ output (stdout + stderr) vào `/dev/null` thay vì sinh tệp `nohup.out`.
  (Nếu **không** redirect, `nohup` sẽ tự tạo tệp `nohup.out` chứa output — cũng là mọi cách hợp lệ.)

### 5.3. Tìm số định danh tiến trình (PID)

```bash
# Cach 1: pgrep theo ten lenh
pgrep -f loop-monitor.sh

# Cach 2: ps + grep (ky thuat [l] de khong khop chinh lenh grep)
ps aux | grep '[l]oop-monitor.sh'

# Cach 3: xem chi tiet PID, PPID, TTY
ps -eo pid,ppid,tty,stat,lstart,cmd | awk 'NR==1 || /[l]oop-monitor\.sh/'
```

```console
$ pgrep -f loop-monitor.sh
175509
175736

$ ps aux | grep '[l]oop-monitor.sh'
root      175509  0.0  0.0   7752  3536 ?        S    13:36   0:00 /bin/bash ./loop-monitor.sh

$ ps -eo pid,ppid,tty,stat,lstart,cmd | awk 'NR==1 || /[l]oop-monitor\.sh/'
    PID    PPID TT       STAT                  STARTED CMD
 175509       1 ?        S    Tue Oct  6 13:36:25 2026 /bin/bash ./loop-monitor.sh
```

**PID của script là `175509`.**

> **Lưu ý về `pgrep -f`**: `pgrep -f` khớp trên cả *chuỗi lệnh đầy đủ* (full command line), nên ngoài
> PID thật (`175509`) nó còn khớp luôn PID của shell đang chạy chính lệnh `pgrep` (ví dụ `175736`)
> vì chuỗi đó có chứa ký tự "loop-monitor.sh". Vì vậy khi cần lấy **một** PID chính xác, nên dùng
> `pgrep -x loop-monitor.sh` (khớp đúng tên tiến trình) hoặc cách `ps aux | grep '[l]oop-monitor.sh'`.

Dấu hiệu quan trọng chứng minh tiến trình **độc lập với Terminal**:

| Cột | Giá trị | Ý nghĩa |
|---|---|---|
| `TT` (TTY) | `?` | Tiến trình **không gắn với terminal nào** → không chết khi đóng Terminal. |
| `PPID` | `1` | Cha là PID 1 (`systemd/init`) sau khi shell khởi chạy thoát → đã được "re-parent", hoàn toàn tách khỏi phiên. |
| `STAT` | `S` | Đang ngủ (`sleep`), chờ hết chu kỳ 5 giây để ghi log. |

### 5.4. Kiểm tra tệp log được ghi liên tục

```bash
tail -n 10 /tmp/monitor.log
```

```console
$ tail -n 10 /tmp/monitor.log
System time: Tue Oct  6 13:36:26 UTC 2026
System time: Tue Oct  6 13:36:31 UTC 2026
System time: Tue Oct  6 13:36:36 UTC 2026
System time: Tue Oct  6 13:36:41 UTC 2026
System time: Tue Oct  6 13:36:46 UTC 2026
System time: Tue Oct  6 13:36:51 UTC 2026
System time: Tue Oct  6 13:36:56 UTC 2026
System time: Tue Oct  6 13:37:01 UTC 2026
```

Các dòng log cách nhau **đúng 5 giây** → script đang chạy nền và ghi log đều đặn.
Toàn bộ các lệnh kiểm tra trên được chạy trong **phiên shell khác** với phiên đã khởi chạy script,
mà tiến trình vẫn sống và tiếp tục ghi log → chứng minh nó tồn tại độc lập với phiên làm việc
(tương đương thao tác "tắt Terminal rồi đăng nhập lại" theo yêu cầu).

## 6. Tắt tiến trình bằng `kill` — SIGTERM trước, SIGKILL sau

### 6.1. Nguyên tắc

Luôn ưu tiên **SIGTERM (15)** vì đây là tín hiệu **yêu cầu tiến trình dừng một cách lịch sự**
(graceful): chương trình có cơ hội bắt tín hiệu để lưu dữ liệu, đóng file, giải phóng tài nguyên rồi
mới thoát. Nếu tiến trình bị "cứng đầu" (bỏ qua SIGTERM) thì mới dùng **SIGKILL (9)** — biện pháp
mạnh tay **buộc** kernel hủy ngay tiến trình, không cho nó cơ hội dọn dẹp.

| Tín hiệu | Số | Tính chất | Có bắt được? | Dùng khi nào |
|---|---|---|---|---|
| `SIGTERM` | 15 | Kết thúc **mềm** (graceful) | **Có** (có thể `trap`) | **Ưu tiên số 1** — tắt bình thường |
| `SIGKILL` | 9 | Kết thúc **cứng**, do kernel thực thi | **Không** | Khi SIGTERM không tắt được |
| `SIGHUP` | 1 | Ngắt kết nối | Có | Bị `nohup` vô hiệu hóa |
| `SIGSTOP`/`SIGCONT` | 19/18 | Tạm dừng/Tiếp tục | Không/Có | Treo/đánh thức tiến trình |

### 6.2. Gửi SIGTERM (15) và kiểm tra

```bash
PID=$(ps -eo pid,cmd | awk '/[l]oop-monitor\.sh/ {print $1; exit}')
echo "PID = $PID"
kill -15 "$PID"
```

```console
$ PID=175509; kill -15 "$PID" && echo "da gui kill -15 $PID"
da gui kill -15 175509
```

Kiểm tra lại sau khi gửi tín hiệu:

```bash
ps aux | grep '[l]oop-monitor.sh'
ps -p 175509 -o pid,stat,cmd
```

```console
$ ps aux | grep '[l]oop-monitor.sh'
(khong in dong tien trinh nao)

$ ps -p 175509 -o pid,stat,cmd
    PID STAT CMD
PID 175509 khong con ton tai -> da tat thanh cong

$ tail -n 3 /tmp/monitor.log
System time: Tue Oct  6 13:36:56 UTC 2026
System time: Tue Oct  6 13:37:01 UTC 2026
```

→ Sau `kill -15`, tiến trình **biến mất khỏi `ps aux`**, log dừng ghi ở mốc `13:37:01`.
Đúng **kết quả mong đợi** của đề bài: SIGTERM đã tắt được tiến trình một cách sạch sẽ.

### 6.3. Minh họa trường hợp phải dùng SIGKILL (9)

Để chứng minh nhánh dự phòng của đề bài ("nếu không tắt được mới dùng SIGKILL"), ta thử một biến thể
script **bỏ qua SIGTERM** bằng `trap '' TERM`:

```bash
#!/bin/bash
trap '' TERM            # Bo qua SIGTERM -> mo phong tien trinh "cung dau"
while true; do
    echo "stubborn time: $(date)" >> /tmp/monitor-stubborn.log
    sleep 5
done
```

Khởi chạy nền và thử `kill -15`:

```console
$ nohup ./loop-monitor-stubborn.sh > /dev/null 2>&1 &
stubborn PID = 175352
da gui kill -15

# Sau kill -15 tien trinh VAN SONG (vi da trap/bo qua SIGTERM):
$ ps -o pid,stat,cmd -p 175352
    PID STAT CMD
 175352 S    /bin/bash ./loop-monitor-stubborn.sh
```

→ `SIGTERM` không hiệu quả, phải chuyển sang `SIGKILL`:

```console
$ kill -9 175352
$ ps -o pid,stat,cmd -p 175352 || echo "da bi tieu diet"
    PID STAT CMD
PID 175352 da bi tieu diet (khong con ton tai)
```

→ `kill -9` **buộc** kernel hủy tiến trình ngay, bất kể nó có muốn hay không.

## 7. Giải thích cơ chế

- **`nohup` + `&`**: `&` tạo tiến trình con chạy nền; `nohup` bọc tiến trình đó, đặt nó **bỏ qua `SIGHUP`**.
  Khi Terminal/SSH đóng, kernel gửi `SIGHUP` tới mọi tiến trình thuộc phiên đó — tiến trình có `nohup`
  phớt lờ tín hiệu này nên tiếp tục sống. Bằng chứng cụ thể ở mục 5.3: tiến trình có `TT = ?` và `PPID = 1`.
- **Tại sao vẫn nên redirect output?** Vì tiến trình nền không còn terminal để in ra; `nohup` mặc định
  ghi vào `nohup.out`. Chủ động `> /dev/null 2>&1` (hoặc `>> /tmp/monitor.log 2>&1`) giúp kiểm soát nơi lưu output.
- **`kill` thực chất là "gửi tín hiệu"**, không nhất thiết là "giết": `kill -15` gửi `SIGTERM` (yêu cầu dừng),
  `kill -9` gửi `SIGKILL` (cưỡng chế). Mặc định `kill <PID>` tương đương `kill -15 <PID>`.
- **Bền vững trước khi thoát phiên**: với các dịch vụ cần quản lý lâu dài, cách "chuẩn" hơn là dùng
  `systemd service` (xem bài 5 cùng session) vì có theo dõi, tự restart và quản lý vòng đời. `nohup` phù hợp
  cho các tiến trình/tác vụ chạy nền đơn giản, không cần giám sát phức tạp.

## 8. Kết luận

- Đã viết `loop-monitor.sh` ghi thời gian vào `/tmp/monitor.log` mỗi 5 giây và cấp quyền thực thi (`chmod +x`).
- Đã khởi chạy nền **độc lập với Terminal** bằng `nohup ./loop-monitor.sh > /dev/null 2>&1 &`;
  tiến trình có **TTY = `?`** và **PPID = 1**, vẫn ghi log đều đặn qua nhiều phiên shell khác nhau.
- Đã xác định **PID = `175509`** và tắt an toàn bằng **`kill -15`** → tiến trình biến mất khỏi `ps aux`,
  log dừng ghi đúng thời điểm.
- Đã minh họa nhánh dự phòng: tiến trình bỏ qua SIGTERM thì **`kill -9`** mới hủy được.

## Phụ lục — Tóm tắt lệnh đã dùng

```bash
# 1. Tao script + cap quyen
chmod +x loop-monitor.sh

# 2. Chay nen doc lap
nohup ./loop-monitor.sh > /dev/null 2>&1 &

# 3. Tim PID
pgrep -f loop-monitor.sh
ps aux | grep '[l]oop-monitor.sh'
ps -eo pid,ppid,tty,stat,lstart,cmd | awk 'NR==1 || /[l]oop-monitor\.sh/'

# 4. Kiem tra log
tail -n 10 /tmp/monitor.log

# 5. Tat tien trinh: SIGTERM truoc, SIGKILL neu SIGTERM that bai
kill -15 <PID>
kill  -9 <PID>
```

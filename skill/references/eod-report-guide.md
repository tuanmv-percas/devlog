# EOD Report — Hướng dẫn tạo đầu việc cuối ngày

Mô tả cách sinh bảng "đầu việc trong ngày" từ git commit, để dán vào tracker (Notion / bảng theo dõi tiến độ). Chạy vào cuối mỗi ngày, trên commit của (các) dự án đang làm. Được `SKILL.md` (Step 5) dùng làm nguồn quy tắc gom nhóm.

## Format output

Mỗi đầu việc là 1 dòng, các cột phân tách bằng **Tab**:

```
<STT>	<Mô tả đầu việc>	<Dự án>	<Ngày bắt đầu>	<Ngày kết thúc>	<Tiến độ %>
```

Ví dụ:

```
1	Collect: split thành grid-dive + buffer-twin	Gecko Jam	11/8	11/8	100%
2	Printer: logic emit tile + generator-colored EmitColors + occlusion model	Mahjong	11/8	11/8	100%
```

| Cột | Ý nghĩa | Giá trị mặc định |
|---|---|---|
| STT | Số thứ tự dòng, đánh liên tục từ 1 cho cả bảng (không reset theo project) | — |
| Mô tả đầu việc | Gộp từ 1 hoặc nhiều commit liên quan, viết theo dạng `<Hệ thống>: <việc đã làm>` | — |
| Dự án | Tên dự án đang làm (suy ra từ repo / branch — xem bước 2) | — |
| Ngày bắt đầu | Ngày commit đầu tiên của nhóm | Ngày hôm nay |
| Ngày kết thúc | Ngày commit cuối của nhóm | Ngày hôm nay |
| Tiến độ % | Việc đã merge/hoàn tất = 100%; đang dở = ước lượng | 100% |

Định dạng ngày: `d/m` (vd `12/8`).

## Quy trình

### 1. Lấy commit trong ngày

Commit đã được `SKILL.md` Step 1 thu thập sẵn (cùng nguồn dữ liệu). Nếu chạy độc lập, lấy trong repo của dự án:

```bash
git log --since="$(date +%Y-%m-%d) 00:00" --until="tomorrow 00:00" \
  --pretty=format:"%h|%ad|%s" --date=format:"%d/%m %H:%M" --all
```

Muốn xem 1 ngày cụ thể, thay `--since`/`--until` bằng mốc ngày mong muốn (vd `--since="2026-08-11 00:00" --until="2026-08-13 00:00"`).

### 2. Xác định Dự án

Lấy tên dự án từ repo (tên thư mục / remote) hoặc từ theme của branch. Nếu một repo phục vụ nhiều dự án theo branch/theme, map như sau (thêm dòng khi có dự án mới):

| Branch / theme | Dự án |
|---|---|
| `theme/mahjong` | Mahjong |
| `theme/gecko*` | Gecko Jam |

Nếu một ngày có commit thuộc nhiều dự án, tách thành nhiều dòng theo đúng dự án.

### 3. Gom commit thành đầu việc

Nguyên tắc: **1 đầu việc = 1 tính năng/hệ thống**, không phải 1 commit. Gộp các commit cùng chạm một hệ thống lại.

- Gom theo prefix của commit message (`WoodObstacle:`, `ConcreteTile:`, `Printer:`, `Level editor:`...).
- Commit phụ trợ (add config, add icon, scaffold SFX, haptics, VFX) gộp vào đầu việc chính của cùng hệ thống, hoặc gom chung thành 1 dòng "feedback/polish" nếu trải nhiều hệ thống.
- Mục tiêu: khoảng **5–8 đầu việc/ngày**. Quá nhiều dòng lẻ → gom thêm; một hệ thống lớn → có thể tách 2 dòng (logic vs visual).
- **Loại bỏ** commit không phải việc trong ngày: fix cũ đã summarize hôm trước, rename/dọn file, merge.

### 4. Xuất bảng

Xuất cả 2 dạng:
- **Bảng Markdown** để review nhanh.
- **Dòng phẳng tách Tab** để dán thẳng vào tracker.

## Ví dụ hoàn chỉnh (12/8, dự án Mahjong)

```
1	WoodObstacle: unlock sau N adjacent taps (4-way) + count theo cell position + thêm config	Mahjong	12/8	12/8	100%
2	ConcreteTile: obstacle ice-like (break sau N feeds) + damage-state animation + break VFX	Mahjong	12/8	12/8	100%
3	Hidden obstacle: logic + prefab + reveal-on-unblock visual	Mahjong	12/8	12/8	100%
4	Obstacles feedback: scaffold SFX (Printer/Hidden/ConcreteTile/Wood) + Curtain SFX + haptics	Mahjong	12/8	12/8	100%
5	LevelIntro: cascade Printer và ConcreteTile cùng tiles	Mahjong	12/8	12/8	100%
6	Level editor: Auto Save + one occupant/cell + count Printer emits trong tile total	Mahjong	12/8	12/8	100%
7	Feature icon: icon obstacles mới + Printer + icon editor	Mahjong	12/8	12/8	100%
```

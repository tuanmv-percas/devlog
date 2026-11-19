---
name: devlog
description: >-
  Generate an end-of-day devlog and task list from a day's git commits, across one or
  more project repos, write the devlog into a central devlog repo (identified by a
  devlog.config.json marker or the DEVLOG_REPO env var), and finally print an EOD
  "đầu việc trong ngày" task list to paste into the tracker (Notion). Use this whenever
  the user wants to write a devlog, summarize today's commits, generate a changelog for
  the day, produce an end-of-day / EOD report, or build the "đầu việc cuối ngày" task
  list — including phrases like "viết devlog", "devlog hôm nay", "tổng hợp commit trong
  ngày", "log việc hôm nay", "đầu việc cuối ngày", or "EOD report". Trigger even when the
  user only gives a date or says "log today's work", as long as the intent is turning git
  commits into a devlog or a day's task summary.
---

# Devlog Writer

When invoked, generate a devlog from the configured author's commits (default `vahtyah`) made on a given day, for one or more project repos, write the result into a central devlog repo, and finally print an EOD task list to copy into the tracker.

This skill operates on the **folders added to the current session**: one of them is the central devlog repo (the sink), the rest are source project repos. Nothing is hard-coded, so the same skill works across machines and any number of projects.

Arguments (parsed from what the user says — a bare date, a project name, both, or neither):

- `<date>` — target day in `YYYY-MM-DD`. If omitted, default to today (local timezone).
- `<project>` — optional project name (matches an added folder / git repo). If omitted, run in batch mode for every source project.

Example: `2026-08-17 liquid-loop-sort-2` or just `2026-08-17`.

---

## Step 0 — Resolve the devlog repo (sink) and target projects

### 0a. Find the devlog repo (output sink)

The devlog repo is identified by a marker file, not a hard-coded path, so it stays portable across machines. Resolve in this order:

1. Among the session's added folders, find the one whose git root contains a `devlog.config.json` marker at its top level. Verify the marker sits at a real git root:

   ```bash
   test "$(git -C "<folder>" rev-parse --show-toplevel)" = "<folder>" && test -f "<folder>/devlog.config.json"
   ```

2. If none found, fall back to the `DEVLOG_REPO` environment variable:

   ```bash
   DEVLOG_REPO="${DEVLOG_REPO:-}"
   ```

3. If still unset, use the repo this skill lives in. The skill is installed as a symlink into the devlog repo's `skill/` folder (see `install.sh`), so resolving the skill's base directory physically and going one level up gives the repo:

   ```bash
   CANDIDATE="$(cd "<skill base directory>" && pwd -P)/.."
   CANDIDATE="$(cd "$CANDIDATE" && pwd -P)"
   test -f "$CANDIDATE/devlog.config.json" && DEVLOG_REPO="$CANDIDATE"
   ```

4. If still unresolved, stop and print: `No devlog repo found (run install.sh in the devlog repo, add it to the session, or set DEVLOG_REPO).`

Call the resolved path `DEVLOG_REPO`. `devlog.config.json` also doubles as config (output layout, per-project section mappings).

### 0b. Determine the source projects

- Every added folder that is a git root **except** `DEVLOG_REPO` is a source project.
- If a `<project>` argument was given, restrict to the single added folder whose name matches it; if no match, stop and print: `Project <project> not found among added folders.`
- If no `<project>` was given, process all source projects (batch mode).

For each source project resolve a stable name from its git root (machine-independent):

```bash
PROJECT_PATH="<added folder>"
PROJECT=$(basename "$(git -C "$PROJECT_PATH" rev-parse --show-toplevel)")
```

### 0c. Sync the devlog repo before writing

```bash
git -C "$DEVLOG_REPO" pull --ff-only
```

Then run Steps 1–3 once per source project to build each project's devlog block. Step 4 writes all blocks into a single day file.

---

## Step 1 — Collect the day's commits (only the configured author)

Only commits by the target author are included — by default `vahtyah`. Read the author from `devlog.config.json` (key `author`) if present; otherwise use `vahtyah`:

```bash
AUTHOR="vahtyah"   # override with the "author" value from devlog.config.json if set
```

All git commands in this step run against the current source project via `git -C "$PROJECT_PATH"` and filter by `--author="$AUTHOR"`. `--author` matches the author name or email as a regex, so `vahtyah` catches the git handle in either field.

First, list the author's commits on the target day:

```bash
git -C "$PROJECT_PATH" log --author="$AUTHOR" --no-merges \
  --after="YYYY-MM-DD 00:00:00" --before="YYYY-MM-DD 23:59:59" \
  --pretty=format:"%h %an %s"
```

If the list is empty, print `No commits by $AUTHOR found for YYYY-MM-DD in <project>.` and skip this project (in batch mode continue to the next).

Then collect the diff. Because the repo may be shared and other authors' commits can be interleaved on the same branch, do **not** use a single `FIRST^..LAST` range — that would pull in other people's changes. Instead take each of the author's commits and aggregate their individual diffs:

```bash
HASHES=$(git -C "$PROJECT_PATH" log --author="$AUTHOR" --no-merges \
  --after="YYYY-MM-DD 00:00:00" --before="YYYY-MM-DD 23:59:59" \
  --reverse --pretty=format:"%H")

for H in $HASHES; do
  git -C "$PROJECT_PATH" show --stat "$H"
  git -C "$PROJECT_PATH" show "$H"
done
```

- `--no-merges` drops merge commits — they are not real work, and `git show` on a merge is empty by default anyway.
- Per-commit `show` guarantees only the author's own changes are captured, even when the repo has many committers.
- If a file is touched across several of the author's commits, merge its bullets into a single entry in Step 2 rather than repeating the filename per commit.

---

## Step 2 — Classify and group files

Classify each file:

| Tag | Meaning |
|---|---|
| `[NEW]` | New file — has `+++` only, no `---` |
| `[DEL]` | Deleted file — has `---` only, no `+++` |
| `[RENAMED]` | Has `rename from` / `rename to` in diff header |
| `[MOD]` | Everything else |

Group files into sections by path. First apply the project's own mapping from `devlog.config.json` (key `sectionMappings`) if present; otherwise use the known mapping below:

| Path contains | Section name |
|---|---|
| `Services/Lives` or `/Lives/` | Lives System |
| `Services/BattlePass` or `/BattlePass/` | Battle Pass |
| `Services/` (other) | Services |
| `Storage/` | Storage / Data |
| `UI/` | UI Layer |
| `Prefabs/` | Prefab Updates |
| `ScriptableObjects/` or `Config/` | Config / ScriptableObjects |
| `Tests/` or `Editor/` | Tests |
| `*.asmdef` | Assembly Definitions |
| `.claude/` or `settings` | Config / Environment |
| Everything else | see generic fallback |

Generic fallback (for any path not matched above, and for projects with no known mapping): group by the **top-level folder** of the path (e.g. `src/audio/Mixer.cs` → section `src/audio`). Files at the repo root go under `Root`. This keeps the skill usable on any project without per-project setup.

Number sections sequentially starting from `1.`

---

## Step 3 — Output format

Wrap the entire devlog in a single fenced code block (triple backtick, no language tag).
This gives the user a one-click copy button in VS Code and keeps the text pasteable into Word without Markdown rendering.

Inside the code block, use plain text only — no `##`, no `**`, no backticks.

````
```
1. Lives System

ILivesStorage.cs — [NEW]
- Defined interface ILivesStorage with properties IsInitialized, IsMigrated
- Declared Save() contract so the service never touches Nakama directly

LivesService.cs — [MOD]
- Replaced constructor dependency from LivesManager to injected ILivesStorage
- Removed legacy method GetLivesLegacy()

----------------------------------------------------------------------

2. Storage / Data

LivesData.cs — [NEW]
- New persistence model for lives state
- Implements ISerializable with fields livesCount, lastRecoveryTime
```
````

Rules:
- The outermost fence is triple backtick with no language tag
- Section heading: number + name, e.g. `1. Lives System`
- File line: `LivesService.cs — [MOD]`
- Bullets start with `- `
- Blank line between files
- Separator between sections: 70 dashes

---

## Step 4 — Write into the devlog repo and sync

Write a single Markdown file per day, placed **directly at the root of the devlog repo** — no per-project subfolder. The filename is the target day in day-month-year order:

```
$DEVLOG_REPO/<DD-MM-YYYY>.md      e.g. 24-01-2026.md
```

- `<DD-MM-YYYY>` is the target day reformatted from the `YYYY-MM-DD` argument. Use `-` as the separator, not `/` — a `/` is a path separator and cannot appear in a filename.
- If the file already exists (re-run for the same day), overwrite it with the freshly generated content.
- **Batch mode (multiple projects):** all projects share this one day file. Concatenate each project's devlog block into it, and precede each block with a project heading so they stay distinguishable:

  ```
  # <project>

  ```<devlog block from Step 3>```
  ```

  For a single project you may omit the heading. Build the full content in memory first, then write the file once.

### Confirm before committing

Once the day file is written to disk, do **not** commit automatically. Show the user three options and wait for their choice — this is a stop point:

1. **Commit + push** — stage, commit, push, then generate the link (below) and continue to Step 5.
2. **Cancel + discard** — revert the generated file so nothing is left behind, then **stop and wait for input**.
3. **Cancel** — leave the file on disk as generated but do not commit/push, then **stop and wait for input**.

Only option 1 continues the workflow. If the user picks option 2 or 3, halt here — do not push, do not run Step 5 — and wait for their next instruction.

**Option 1 — Commit + push:**

```bash
git -C "$DEVLOG_REPO" add "<DD-MM-YYYY>.md"
git -C "$DEVLOG_REPO" commit -m "devlog: <DD-MM-YYYY>"
git -C "$DEVLOG_REPO" push
```

**Option 2 — Cancel + discard** (remove what was just generated):

```bash
# newly created file (untracked): delete it
rm -f "$DEVLOG_REPO/<DD-MM-YYYY>.md"
# if it overwrote a previously committed file, restore that version instead:
git -C "$DEVLOG_REPO" checkout -- "<DD-MM-YYYY>.md"
```

Then stop and wait.

**Option 3 — Cancel:** touch nothing, stop and wait.

### Generate the link (only after Commit + push)

Build the file's web URL, then wrap it in a spreadsheet `HYPERLINK` formula so it pastes straight into a tracker cell as a clickable "Devlog" link. Print it inside a fenced code block so it has a one-click copy button:

```bash
REMOTE=$(git -C "$DEVLOG_REPO" remote get-url origin)
BRANCH=$(git -C "$DEVLOG_REPO" rev-parse --abbrev-ref HEAD)
# normalize SSH (git@host:owner/repo.git) or HTTPS (https://host/owner/repo.git) -> https://host/owner/repo
WEB=$(echo "$REMOTE" | sed -E 's#^git@([^:]+):#https://\1/#; s#\.git$##')
URL="$WEB/blob/$BRANCH/<DD-MM-YYYY>.md"
echo "=HYPERLINK(\"$URL\", \"Devlog\")"
```

Output exactly this form (the copy target), e.g. for `17-08-2026.md` on GitHub `main`:

```
=HYPERLINK("https://github.com/tuanmv-percas/devlog/blob/main/17-08-2026.md", "Devlog")
```

- `/blob/<branch>/` is GitHub; use `/-/blob/<branch>/` for GitLab, `/src/<branch>/` for Bitbucket.
- Produce this link only when the user chose Commit + push.

---

## Step 5 — Generate the EOD task list (final, for copy)

After the devlog files are written, produce a task list ("đầu việc trong ngày") from the same commits, printed in chat at the very end so it can be copied straight into the tracker (Notion). This is **not** written to a file — it is the last thing shown.

Reuse the commits already collected in Step 1. Group and format them following the rules in `references/eod-report-guide.md` (read it for the grouping heuristics, the branch/theme project mapping, and a full worked example):

- **1 đầu việc = 1 hệ thống/tính năng**, not 1 commit. Gộp các commit cùng chạm một hệ thống (theo prefix message: `Printer:`, `WoodObstacle:`, `Level editor:`...). Aim for ~5–8 đầu việc per project per day.
- Loại bỏ commit không phải việc trong ngày: merge, rename/dọn file, fix cũ đã summarize hôm trước.
- Mô tả viết tiếng Việt dạng `<Hệ thống>: <việc đã làm>`.
- Trong batch mode, mỗi project ra nhóm dòng riêng; cột Dự án = tên project (Step 0b). Nếu một repo phục vụ nhiều dự án theo branch/theme, tách dòng theo mapping trong `references/eod-report-guide.md`.

Columns are Tab-separated, dates in `d/m`:

```
<STT>	<Mô tả đầu việc>	<Dự án>	<Ngày bắt đầu>	<Ngày kết thúc>	<Tiến độ %>
```

- STT = số thứ tự dòng, bắt đầu từ 1 và đánh liên tục cho toàn bộ bảng. Trong batch mode không đánh lại từ 1 ở mỗi project — một dãy duy nhất chạy qua hết mọi project, và cả bảng Markdown lẫn khối Tab đều có cột này.
- Ngày bắt đầu / kết thúc = commit đầu / cuối của nhóm (mặc định là ngày target).
- Tiến độ = 100% nếu đã merge/hoàn tất, ngược lại ước lượng.

Output two forms, in this order:

1. A Markdown table for quick review.
2. A flat, Tab-separated block (the copy target) — wrapped in a fenced code block so it has a one-click copy button and pastes cleanly into the tracker.

In batch mode (multiple projects), both forms are **single combined outputs** covering every project — not one per project. Rows are grouped/ordered by project (the `Dự án` column tells them apart), so the user copies one block and gets the whole day across all projects. This matches Step 4, where all projects also go into the one day file.

---

## Content rules

- Each bullet = one concrete change. Never use: "refactored", "improved", "cleaned up", "updated".
- Correct: `Replaced LivesManager component with LivesSystemManager`
- Wrong: `Refactored the lives system`
- `.asmdef` files: one bullet — `Added/Updated assembly definition for [assembly name]`
- `settings.local.json` / `.claude`: group under "Config / Environment", bullet describing which key changed
- Deleted files: add a bullet explaining why if clear from the diff
- Renamed files: `[RENAMED from OldName.cs]` after the filename
- Language: **English** throughout (the devlog files). The EOD task list in Step 5 is written in Vietnamese.

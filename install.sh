#!/usr/bin/env bash
# Cài skill "devlog" cho Claude Code bằng symlink tới thư mục skill/ của repo này (git pull là skill cập nhật),
# và ghi vào settings.json: env.DEVLOG_REPO + permissions.additionalDirectories trỏ tới repo này.
#
#   ./install.sh                  # cài cho ~/.claude (hoặc $CLAUDE_CONFIG_DIR)
#   ./install.sh --no-settings    # chỉ tạo symlink, không đụng settings.json
#   ./install.sh --uninstall      # gỡ symlink (settings.json giữ nguyên)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
NAME="devlog"
SRC="$REPO/skill"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DIR="$CONFIG_DIR/skills"
DEST="$DIR/$NAME"
SETTINGS="$CONFIG_DIR/settings.json"
MODE="install"
WRITE_SETTINGS=1

while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) MODE="uninstall"; shift ;;
    --no-settings) WRITE_SETTINGS=0; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "Tham số lạ: $1" >&2; exit 1 ;;
  esac
done

if [ "$MODE" = "uninstall" ]; then
  if [ -L "$DEST" ]; then rm "$DEST"; echo "Đã gỡ $DEST"; else echo "Không có symlink $DEST"; fi
  exit 0
fi

mkdir -p "$DIR"
if [ -L "$DEST" ]; then
  if [ "$(readlink "$DEST")" = "$SRC" ]; then
    echo "Đã cài sẵn: $DEST -> $SRC"
  else
    echo "$DEST đang trỏ tới $(readlink "$DEST"); đổi sang $SRC"
    rm "$DEST"
    ln -s "$SRC" "$DEST"
  fi
elif [ -e "$DEST" ]; then
  echo "$DEST đã tồn tại và không phải symlink, không ghi đè. Xoá hoặc đổi tên nó rồi chạy lại." >&2
  exit 1
else
  ln -s "$SRC" "$DEST"
  echo "Đã cài: $DEST -> $SRC"
fi

if [ "$WRITE_SETTINGS" = 1 ]; then
  python3 - "$SETTINGS" "$REPO" <<'PY'
import json, os, sys
path, repo = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    with open(path) as f:
        text = f.read().strip()
        data = json.loads(text) if text else {}
data.setdefault("env", {})["DEVLOG_REPO"] = repo
dirs = data.setdefault("permissions", {}).setdefault("additionalDirectories", [])
if repo not in dirs:
    dirs.append(repo)
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"Đã ghi DEVLOG_REPO và additionalDirectories = {repo} vào {path}")
PY
fi

echo "Mở phiên Claude Code mới để nạp skill và settings."

# devlog

Devlog theo ngày (`DD-MM-YYYY.md`) và skill `devlog` của Claude Code sinh ra chúng.

- `skill/` — skill `devlog` (`SKILL.md` + `references/`)
- `devlog.config.json` — marker nhận diện repo này + cấu hình (`author`, `sectionMappings`)
- `install.sh` — cài skill cho máy hiện tại

## Cài trên máy mới

```bash
git clone https://github.com/tuanmv-percas/devlog.git ~/Projects/devlog
~/Projects/devlog/install.sh
```

Script tạo symlink `~/.claude/skills/devlog -> <repo>/skill` và ghi vào `~/.claude/settings.json`:

- `env.DEVLOG_REPO` = đường dẫn repo
- `permissions.additionalDirectories` thêm đường dẫn repo, để skill ghi/commit/push devlog mà không cần thêm repo vào session

Sau đó mở phiên mới ở project cần viết devlog và gọi `/devlog`. Skill được link nên `git pull` repo này là skill cập nhật luôn.

Tuỳ chọn: `--no-settings` (chỉ tạo symlink), `--uninstall` (gỡ symlink). Nếu dùng thư mục cấu hình riêng: `CLAUDE_CONFIG_DIR=~/.claude-work ./install.sh`.

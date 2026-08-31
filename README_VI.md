# Mobile Reverse Skill — Tiếng Việt

**English · Tiếng Việt · [日本語](README_JA.md)**

Bộ skill portable cho phân tích ngược ứng dụng Android/iOS có ủy quyền,
dùng được với Codex và Claude Code. Nó bao phủ APK/AAB/DEX, JADX, apktool,
smali, JNI, ELF/ARM/ARM64, IPA/Mach-O, Swift/Objective-C, framework/dylib,
ARM64e, Ghidra, IDA Pro, radare2/rizin, Frida, ADB, LLDB, binary diff và
quy trình evidence/report.

## Bắt đầu nhanh

```bash
git clone https://github.com/salamander97/mobile-reverse-skill.git
cd mobile-reverse-skill
bash setup.sh
bash skills/scripts/refresh-tool-index.sh
```

Windows dùng `.\setup.ps1`. Installer cài từng skill vào
`~/.codex/skills` và `~/.claude/skills`, ưu tiên symlink trên macOS/Linux,
copy/junction fallback trên Windows. Không hard-code path và không tự cài
tool bên ngoài.

## Dùng với Codex và Claude Code

Sau khi chạy installer, các skill được cài toàn cục và có thể gọi từ mọi thư
mục làm việc:

- Codex: gọi `$mobile-reverse-router`; khi cần có thể gọi trực tiếp
  `$apk-reverse`, `$mobile-reverse`, `$ghidra-reverse`, `$ida-reverse`,
  `$radare2`, `$binary-diff`, `$case-review` hoặc `$docs-generator`.
- Claude Code: gọi `/mobile-reverse-router`; các lệnh chuyên biệt tương ứng là
  `/apk-reverse`, `/mobile-reverse`, `/ghidra-reverse`, `/ida-reverse`,
  `/radare2`, `/binary-diff`, `/case-review` và `/docs-generator`.

Ví dụ prompt: `Route my authorized mobile reverse-engineering task, verify the
case scope, check the local tool index, and choose the correct specialist.`
Skill umbrella cũng có thể được client tự chọn khi mô tả tác vụ phù hợp. Nếu
thư mục skill toàn cục được tạo sau khi client đã mở, hãy khởi động lại client.

## Kiến trúc và module

`task → routing.json → master-route → case-init/case-guard → specialist →
tool-index → evidence → report`.

Các module chính: `mobile-reverse-router` (umbrella), `mobile-reverse`, `apk-reverse`, `macos-reverse`,
`reverse-engineering`, `ghidra-reverse`, `ida-reverse`, `radare2`,
`binary-diff`, `case-review`, `docs-generator`, `diagram-generator`.

```bash
bash setup.sh check
bash setup.sh update
bash setup.sh uninstall
```

Trước mọi thao tác dynamic/device/target-facing, phải khởi tạo case với
ủy quyền và asset trong scope; file local dùng preset `offline-sample`.

## Gỡ lỗi và an toàn

Chạy lại tool index nếu tool bị báo thiếu. Nếu client không đọc symlink, dùng
`bash setup.sh --copy`. IDA Pro/JEB/Hopper là phần mềm thương mại, người dùng
tự cài và tự cấp phép. Chỉ phân tích ứng dụng, thiết bị và mục tiêu được phép;
không commit secrets, mẫu độc quyền hay dữ liệu live target.

Attribution upstream và license đầy đủ nằm trong [`NOTICE`](NOTICE) và
[`THIRD_PARTY_NOTICES/reverse-skill-LICENSE.txt`](THIRD_PARTY_NOTICES/reverse-skill-LICENSE.txt).
Xem [README tiếng Anh](README.md) để đọc tool matrix, usage và troubleshooting
đầy đủ hơn.

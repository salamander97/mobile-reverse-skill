# Mobile Reverse Skill — 日本語

**[English](README.md) · [Tiếng Việt](README_VI.md) · 日本語**

Codex と Claude Code で利用できる、認可済み Android/iOS アプリ解析向けの
portable skill pack です。APK/AAB/DEX、JADX、apktool、smali、JNI、ELF/ARM/
ARM64、IPA/Mach-O、Swift/Objective-C、framework/dylib、ARM64e、Ghidra、
IDA Pro、radare2/rizin、Frida、ADB、LLDB、binary diff、証拠レビューと
レポート作成を扱います。

## クイックスタート

```bash
git clone https://github.com/salamander97/mobile-reverse-skill.git
cd mobile-reverse-skill
bash setup.sh
bash skills/scripts/refresh-tool-index.sh
```

Windows では `.\setup.ps1` を使用します。Installer は各 skill を
`~/.codex/skills` と `~/.claude/skills` に配置します。macOS/Linux は
symlink を優先し、Windows は copy/junction に fallback します。外部
ツールの自動インストールや固定パスはありません。

## Codex と Claude Code での利用

Installer 実行後、skill はグローバルに配置され、任意の作業ディレクトリ
から利用できます。

- Codex: `$mobile-reverse-router` を呼び出します。必要に応じて
  `$apk-reverse`、`$mobile-reverse`、`$ghidra-reverse`、`$ida-reverse`、
  `$radare2`、`$binary-diff`、`$case-review`、`$docs-generator` を直接呼び出せます。
- Claude Code: `/mobile-reverse-router` を呼び出します。専門 skill は
  `/apk-reverse`、`/mobile-reverse`、`/ghidra-reverse`、`/ida-reverse`、
  `/radare2`、`/binary-diff`、`/case-review`、`/docs-generator` です。

最初に umbrella skill でルーティングし、case の範囲とローカルツールを
確認してから専門 skill に進んでください。グローバル skill ディレクトリを
client 起動後に作成した場合は、client を一度再起動してください。

## 構成と使い方

`task → routing.json → master-route → case-init/case-guard → specialist →
tool-index → evidence → report` の順で進みます。

主な module は `mobile-reverse-router`（umbrella）、`mobile-reverse`、`apk-reverse`、`macos-reverse`、
`reverse-engineering`、`ghidra-reverse`、`ida-reverse`、`radare2`、
`binary-diff`、`case-review`、`docs-generator`、`diagram-generator` です。

```bash
bash setup.sh check
bash setup.sh update
bash setup.sh uninstall
```

dynamic/device/target-facing 操作の前に、必ず認可済み asset を含む case
を初期化してください。ローカルファイルには `offline-sample` preset を
使用します。IDA Pro/JEB/Hopper は正規ライセンスで別途導入します。

詳細な tool matrix、usage、troubleshooting、安全方針は
[English README](README.md) を参照してください。upstream attribution と
license は [`NOTICE`](NOTICE) および
[`THIRD_PARTY_NOTICES/reverse-skill-LICENSE.txt`](THIRD_PARTY_NOTICES/reverse-skill-LICENSE.txt)
に保存しています。

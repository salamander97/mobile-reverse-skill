#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILLS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
OUT_MD="${1:-$SKILLS_ROOT/tool-index.md}"; OUT_JSON="${2:-$SKILLS_ROOT/tool-index.json}"
mkdir -p "$(dirname "$OUT_MD")" "$(dirname "$OUT_JSON")"
os="$(uname -s 2>/dev/null || echo unknown)"; case "$os" in Darwin) os=macOS;; Linux) os=Linux;; esac
entries=(
  'java|runtime|JADX/apktool/bundletool/Ghidra|java' 'python3|runtime|Case helpers|python3' 'node|runtime|Optional MCP bridges|node'
  'jadx|android|Java/Kotlin decompiler|jadx' 'apktool|android|APK resources and smali|apktool' 'bundletool|android|AAB inspection/splits|bundletool' 'dex2jar|android|DEX/JAR conversion|d2j-dex2jar' 'smali|android|DEX assembler|smali' 'baksmali|android|DEX disassembler|baksmali' 'adb|android|Authorized device bridge|adb' 'zipalign|android|APK alignment|zipalign' 'apksigner|android|APK signing|apksigner'
  'frida|runtime|Dynamic instrumentation|frida' 'frida-ps|runtime|Frida process listing|frida-ps' 'objection|runtime|Frida helper|objection'
  'ghidra|native|Ghidra GUI|ghidraRun' 'analyzeHeadless|native|Ghidra headless|analyzeHeadless' 'ida|native|IDA Pro|ida' 'r2|native|radare2 CLI|r2' 'rabin2|native|ELF/Mach-O metadata|rabin2' 'radiff2|native|Binary diff|radiff2' 'rizin|native|Rizin CLI|rizin' 'rz-bin|native|Rizin metadata|rz-bin'
  'lldb|apple|Native debugger|lldb' 'otool|apple|Mach-O load commands|otool' 'nm|apple|Symbols|nm' 'codesign|apple|Code signatures|codesign' 'swift-demangle|apple|Swift symbols|swift-demangle' 'dsymutil|apple|Debug symbols|dsymutil' 'class-dump|apple|Objective-C headers|class-dump' 'jtool2|apple|Mach-O inspection|jtool2'
  'dot|reporting|Graphviz|dot' 'plantuml|reporting|PlantUML|plantuml'
)
{
  echo '# Tool index'; echo; echo "- Generated: $(date '+%Y-%m-%d %H:%M:%S %z')"; echo "- Platform: $os"; echo '- Detection only: no tools are installed.'
  echo; echo '| Tool | Area | Purpose | Available | Path | Version |'; echo '|---|---|---|---|---|---|'
} > "$OUT_MD"
json_rows=()
for entry in "${entries[@]}"; do
  IFS='|' read -r name area purpose command <<< "$entry"
  if command -v "$command" >/dev/null 2>&1; then
    available=yes; path="$(command -v "$command")"; version="$($command --version 2>&1 | head -n 1 | tr '\n' ' ' || true)"
  else available=no; path='—'; version='—'; fi
  printf '| %s | %s | %s | %s | `%s` | `%s` |\n' "$name" "$area" "$purpose" "$available" "$path" "$version" >> "$OUT_MD"
  json_rows+=("$name|$area|$purpose|$available|$path|$version")
done
python3 - "$OUT_JSON" "$os" "${json_rows[@]}" <<'PY'
import json,sys
rows=[]
for raw in sys.argv[3:]:
    name,area,purpose,available,path,version=raw.split('|',5)
    rows.append({'name':name,'area':area,'purpose':purpose,'available':available=='yes','path':path,'version':version})
with open(sys.argv[1],'w',encoding='utf-8') as f: json.dump({'generated_on':__import__('datetime').datetime.now().astimezone().isoformat(),'platform':sys.argv[2],'tools':rows},f,ensure_ascii=False,indent=2); f.write('\n')
PY
echo "Wrote $OUT_MD and $OUT_JSON"

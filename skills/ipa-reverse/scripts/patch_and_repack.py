#!/usr/bin/env python3
"""
iOS IPA Binary Patcher
Usage:
  python3 patch_and_repack.py --binary <path> --offset <hex> --original <hex_bytes> --patch <hex_bytes>
  python3 patch_and_repack.py --binary <path> --patches patches.json

patches.json format:
[
  {"offset": "0x1b8f20", "original": "c1 ef 00 54", "patch": "1f 20 03 d5", "note": "VIP gate NOP"},
  {"offset": "0x1c0010", "original": "20 00 80 d2", "patch": "20 00 80 52 c0 03 5f d6", "note": "return true"}
]
"""
import argparse, json, sys, os, shutil

def hex_to_bytes(s):
    return bytes(int(x, 16) for x in s.strip().split())

def apply_patches(binary_path, patches, verify_only=False):
    results = []
    with open(binary_path, 'r+b' if not verify_only else 'rb') as f:
        for p in patches:
            offset = int(p['offset'], 16)
            original = hex_to_bytes(p['original'])
            patch = hex_to_bytes(p['patch'])
            note = p.get('note', '')

            f.seek(offset)
            current = f.read(len(original))

            if current == original:
                status = '✅ MATCH'
                if not verify_only:
                    f.seek(offset)
                    f.write(patch)
                    status = '✅ PATCHED'
            elif current == patch:
                status = '⚡ ALREADY PATCHED'
            else:
                status = f'❌ MISMATCH (got: {current.hex(" ")})'

            results.append({
                'offset': p['offset'],
                'note': note,
                'original': p['original'],
                'patch': p['patch'],
                'status': status
            })
            print(f"{status} | {p['offset']} | {note}")
    return results

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--binary', required=True)
    parser.add_argument('--offset', help='Single patch: hex offset')
    parser.add_argument('--original', help='Single patch: original bytes (space-separated hex)')
    parser.add_argument('--patch', help='Single patch: replacement bytes')
    parser.add_argument('--note', default='', help='Description of this patch')
    parser.add_argument('--patches', help='JSON file with multiple patches')
    parser.add_argument('--verify', action='store_true', help='Verify only, no write')
    args = parser.parse_args()

    if not os.path.exists(args.binary):
        print(f'ERROR: binary not found: {args.binary}')
        sys.exit(1)

    # Backup
    backup = args.binary + '.original'
    if not os.path.exists(backup):
        shutil.copy2(args.binary, backup)
        print(f'Backup: {backup}')

    # Build patch list
    if args.patches:
        with open(args.patches) as f:
            patches = json.load(f)
    elif args.offset and args.original and args.patch:
        patches = [{'offset': args.offset, 'original': args.original,
                    'patch': args.patch, 'note': args.note}]
    else:
        print('ERROR: provide --offset/--original/--patch OR --patches <file>')
        sys.exit(1)

    print(f'\n{"VERIFY" if args.verify else "PATCHING"}: {args.binary}')
    print(f'{"─"*60}')
    results = apply_patches(args.binary, patches, verify_only=args.verify)

    # Summary
    ok = sum(1 for r in results if '✅' in r['status'] or '⚡' in r['status'])
    fail = len(results) - ok
    print(f'{"─"*60}')
    print(f'Result: {ok}/{len(results)} patches {"verified" if args.verify else "applied"}'
          + (f', {fail} FAILED' if fail else ''))

    if fail > 0:
        print('\nFailed patches — wrong offset? Binary version mismatch?')
        sys.exit(1)

    # Write patch log
    log_path = args.binary + '.patch_log.json'
    with open(log_path, 'w') as f:
        json.dump(results, f, indent=2)
    print(f'Log: {log_path}')

if __name__ == '__main__':
    main()

"""Generator/resource regression. Only called on test_isolated.ps1's disposable fixture."""
import argparse, hashlib, json, os, shutil, subprocess, sys
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--project', required=True)
args = parser.parse_args()
fixture = Path(args.project).resolve()
assert fixture.parent.parent.name == 'verification' and fixture.name == 'project', 'isolated fixture required'
assert '_mcp_game_helper' not in (fixture/'project.godot').read_text()
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def snapshot(root):
    return {p.relative_to(root).as_posix():digest(p) for p in root.rglob('*') if p.is_file() and '.godot' not in p.parts}
checks = 0
def check(ok, label):
    global checks
    checks += 1
    if not ok: raise AssertionError(label)
manifest = json.loads((fixture/'tests/media_manifest.json').read_text())
for relative, expected in manifest.items():
    check(digest(fixture/relative) == expected['sha256'], f'pinned bytes {relative}')
    check((fixture/relative).stat().st_size == expected['bytes'], f'pinned size {relative}')
copy = fixture.parent/'generated-assets'
shutil.copytree(fixture,copy,ignore=shutil.ignore_patterns('.godot','*.translation'))
before = snapshot(copy)
def generate(*options):
    result = subprocess.run([sys.executable,str(copy/'tools/gen_assets.py'),*options],cwd=copy,
                            stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,timeout=600)
    print(result.stdout.strip(),flush=True)
    if result.returncode:
        print(result.stderr, file=sys.stderr)
        raise RuntimeError(f'generator exited {result.returncode}')
    check(not result.stderr.strip(), 'generator stderr empty')
# Check every project resource reference in scenes/scripts/resource and import metadata.
import re
for p in fixture.rglob('*'):
    if p.is_file() and p.suffix in ('.gd','.tscn','.tres','.godot','.import') and '.godot' not in p.parts and 'tests' not in p.relative_to(fixture).parts:
        for relative in re.findall(r'"res://([^"\n]+)"',p.read_text(encoding='utf-8')):
            if relative.startswith('.godot/') or '%' in relative or relative.endswith('/'): continue
            check((fixture/relative).exists(), f'resource reference {p.name}: {relative}')
uids = {}
for p in fixture.rglob('*'):
    if not p.is_file() or '.godot' in p.parts: continue
    if p.suffix == '.uid': uid=p.read_text().strip()
    elif p.suffix == '.import':
        found=re.search(r'^uid="([^"]+)"',p.read_text(),re.M)
        if not found: continue
        uid=found[1]
    else: continue
    check(uid not in uids, f'unique UID {uid}: {p} vs {uids.get(uid)}')
    uids[uid]=str(p)
generate()
check(snapshot(copy) == before, 'default full generation preserves every existing resource')
generate()
check(snapshot(copy) == before, 'repeat default generation is a byte-for-byte no-op')
# Remove three generated inputs in this private copy only and verify real SVG/NumPy restoration.
removed = ['assets/ui/icon_more.png','assets/ui/icon_share.png','assets/audio/click.wav']
for relative in removed: (copy/relative).unlink()
generate()
after = snapshot(copy)
for relative in removed: check(relative in after and (copy/relative).stat().st_size > 0, f'restores {relative}')
check(all(after[k] == v for k,v in before.items() if k not in removed), 'missing-only recovery preserves authored/UI dependencies')
generate('--overwrite-generated')
regenerated = snapshot(copy)
generate('--overwrite-generated')
check(snapshot(copy) == regenerated, 'explicit regeneration is deterministic')
for relative,expected in manifest.items(): check(digest(copy/relative) == expected['sha256'], f'regeneration leaves authored bytes {relative}')
check(not any(p.name.startswith('voice_') or p.name in ('music.wav','music_bright.wav') for p in (copy/'assets/audio').iterdir()), 'no retired audio is regenerated')
check((copy/'assets/ui/icon_more.png').is_file() and (copy/'assets/ui/icon_share.png').is_file(), 'More/Share outputs retained')
print('ASSETS_SUITE '+json.dumps({'checks':checks,'failed':0,'uids':len(uids)}))
print('ASSETS_SUITE_DONE')

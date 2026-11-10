"""Create portable native archives and a clean, engine-free source archive."""
from pathlib import Path
import shutil, zipfile, hashlib, json, os

root = Path(__file__).resolve().parents[1]
builds = root / 'builds'
for platform in ('Linux', 'Windows'):
    folder = builds / ('SHIFT-' + platform)
    for name in ('README.md', 'SOLUTION.txt', 'TESTING.md', 'RELEASE_NOTES.md', 'CREDITS.md'):
        shutil.copy2(root / name, folder / name)
    licenses = folder / 'Licenses'
    licenses.mkdir(exist_ok=True)
    for source in [* (root / 'assets/fonts').glob('LICENSE-*.txt'), root / 'assets/audio/MUSIC.txt', root / 'GODOT-LICENSE.txt', root / 'GODOT-COPYRIGHT.txt']:
        if source.exists(): shutil.copy2(source, licenses / source.name)
    if platform == 'Linux':
        (folder / 'SHIFT.x86_64').chmod(0o755)
        launcher = folder / 'Play.sh'
        launcher.write_text('#!/usr/bin/env bash\nset -e\ncd -- "$(dirname -- "$0")"\nexec ./SHIFT.x86_64 "$@"\n')
        launcher.chmod(0o755)
    archive = builds / ('SHIFT-' + platform + '-x86_64.zip')
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for file in sorted(folder.rglob('*')):
            if file.is_file() and file.suffix not in ('.png', '.log'):
                z.write(file, file.relative_to(builds))

with zipfile.ZipFile(builds / 'SHIFT-Source.zip', 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for directory, subdirs, filenames in os.walk(root, followlinks=False):
        subdirs[:] = [d for d in subdirs if d not in ('.godot','.git','builds','wine-prefix','__pycache__')]
        for filename in sorted(filenames):
            file = Path(directory) / filename
            rel = file.relative_to(root)
            if rel.parts[0] == 'tools' and (file.name.startswith('godot') or file.suffix == '.tpz'):
                continue
            if rel.as_posix() in ('assets/audio/music.mp3','assets/audio/music.mp3.import'):
                continue
            if file.name == 'Играть в SHIFT.sh':
                continue
            z.write(file, Path('SHIFT-Source') / rel)
checksums = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in builds.glob('*.zip')}
(builds / 'SHA256SUMS.txt').write_text(''.join(f'{value}  {name}\n' for name, value in sorted(checksums.items())))
print(json.dumps({p.name:p.stat().st_size for p in builds.glob('*.zip')}, indent=2))

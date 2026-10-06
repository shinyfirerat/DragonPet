#!/usr/bin/env python3
"""Stage a reviewed source allowlist, never the personal workspace or Git history."""
from pathlib import Path
import shutil, zipfile, re, struct, zlib, json, hashlib, plistlib
root=Path(__file__).resolve().parent.parent
version=plistlib.loads((root/'Info.plist').read_bytes())['CFBundleShortVersionString']
out=root/'dist'/'public-source'
if out.exists():shutil.rmtree(out)
out.mkdir(parents=True)
allowed=['Sources','Resources','Tests','scripts','docs','.github']
for name in allowed:
    for path in (root/name).rglob('*'):
        if path.is_symlink():raise SystemExit(f'Symlink is not allowed: {path.relative_to(root)}')
    shutil.copytree(root/name,out/name,ignore=shutil.ignore_patterns('__pycache__','*.tmp','token-history.json','motion-diagnostic.jsonl','.DS_Store'))
for name in ['README.md','LICENSE','THIRD_PARTY_NOTICES.md','Info.plist','build.sh','.gitignore']:
    shutil.copy2(root/name,out/name)
patterns=[rb'/Users/[A-Za-z0-9_.-]+/',rb'BEGIN\s+(?:RSA\s+|EC\s+|OPENSSH\s+)?PRIVATE\s+KEY',rb'sk-[A-Za-z0-9_-]{24,}',rb'AKIA[A-Z0-9]{16}',rb'xox[baprs]-[A-Za-z0-9-]{20,}']
metadata=[]
for path in out.rglob('*'):
    if not path.is_file():continue
    raw=path.read_bytes();payloads=[raw]
    if path.suffix=='.png':
        if not raw.startswith(b'\x89PNG\r\n\x1a\n'):raise SystemExit('Invalid PNG')
        offset=8
        while offset<len(raw):
            length=struct.unpack('>I',raw[offset:offset+4])[0];kind=raw[offset+4:offset+8];data=raw[offset+8:offset+8+length]
            if offset+12+length>len(raw):raise SystemExit('Truncated PNG')
            if kind in [b'tEXt',b'iTXt',b'zTXt',b'caBX']:
                metadata.append({'file':str(path.relative_to(out)),'chunk':kind.decode(),'bytes':length})
                if kind==b'zTXt':payloads.append(zlib.decompress(data.split(b'\0',1)[1][1:]))
                if kind==b'iTXt':
                    parts=data.split(b'\0',5)
                    if len(parts)==6:payloads.append(zlib.decompress(parts[5]) if parts[1]==b'\x01' else parts[5])
                if kind!=b'caBX' or str(path.relative_to(out))!='Resources/Skins/white-dragon/portrait.png':raise SystemExit(f'Unreviewed PNG metadata: {path.relative_to(out)}')
            offset+=12+length
    if path.suffix=='.wav' and (b'LIST' in raw or b'iXML' in raw):raise SystemExit(f'WAV metadata needs review: {path.relative_to(out)}')
    if any(re.search(pattern,payload) for pattern in patterns for payload in payloads):raise SystemExit(f'Private data pattern in {path.relative_to(out)}')
files=sorted(p for p in out.rglob('*') if p.is_file())
manifest=[{'path':str(p.relative_to(out)),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files]
(root/'dist'/'source-manifest.json').write_text(json.dumps(manifest,indent=2))
(root/'dist'/'metadata-review.json').write_text(json.dumps(metadata,indent=2))
with zipfile.ZipFile(root/'dist'/f'DragonPet-{version}-github-source.zip','w',zipfile.ZIP_DEFLATED) as archive:
    for path in files:archive.write(path,Path('DragonPet')/path.relative_to(out))
print(f'Created reviewed source snapshot: {len(files)} files; PNG provenance metadata retained. Pattern scan is not a complete privacy audit.')

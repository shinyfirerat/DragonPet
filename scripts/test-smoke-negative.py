#!/usr/bin/env python3
"""Mutation controls: wrong first-run defaults must fail the actual optimized app smoke."""
from pathlib import Path
import tempfile,subprocess,os,shutil,json
root=Path(__file__).resolve().parent.parent
for name,old,new in [('bubbles-on','var paused=true','var paused=false'),('quota-selected','var quotaSources=[QuotaSource]()','var quotaSources=[QuotaSource(id:"codex",name:"Codex",enabled:true)]')]:
    with tempfile.TemporaryDirectory(prefix='dragonpet-negative-') as directory:
        work=Path(directory)
        for folder in ['Sources','Resources','scripts']:shutil.copytree(root/folder,work/folder,ignore=shutil.ignore_patterns('__pycache__','*.tmp'))
        for file in ['build.sh','Info.plist']:shutil.copy2(root/file,work/file)
        config=work/'Sources/Configuration.swift';text=config.read_text();assert old in text;config.write_text(text.replace(old,new,1))
        subprocess.run(['./build.sh'],cwd=work,env=dict(os.environ,DRAGONPET_ARCH='native'),check=True,capture_output=True,text=True,timeout=120)
        result=subprocess.run([str(work/'dist/小龙娘桌宠.app/Contents/MacOS/DragonPet'),'--offline-smoke'],env=dict(os.environ,DRAGONPET_TEST_ROOT=str(work/'isolated-runtime')),capture_output=True,text=True,timeout=20)
        events=[json.loads(line) for line in result.stdout.splitlines() if line.startswith('{')]
        assert result.returncode==1 and any(e.get('result')=='failed' and e.get('configSource')=='fresh' for e in events),(name,result.returncode,result.stdout,result.stderr)
        print('PASS: negative control rejected '+name)

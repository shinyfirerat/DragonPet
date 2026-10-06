#!/usr/bin/env python3
"""Use file-backed app preferences and runtime paths, not cfprefsd/home assumptions."""
from pathlib import Path
import subprocess,tempfile,os,json
root=Path(__file__).resolve().parent.parent
exe=root/'dist'/'小龙娘桌宠.app'/'Contents'/'MacOS'/'DragonPet'
with tempfile.TemporaryDirectory(prefix='dragonpet-smoke-') as directory:
    env=dict(os.environ,DRAGONPET_TEST_ROOT=directory)
    for source in ['fresh','loaded']:
        result=subprocess.run([str(exe),'--offline-smoke'],env=env,capture_output=True,text=True,timeout=20,check=True)
        events=[json.loads(line) for line in result.stdout.splitlines() if line.startswith('{')]
        assert any(e.get('event')=='offline-smoke' and e.get('result')=='passed' and e.get('bubblesOff') is True and e.get('quotaSources')==0 and e.get('configSource')==source for e in events),result.stdout+result.stderr
    assert (Path(directory)/'preferences.plist').exists()
print('PASS: isolated file-backed preferences, first launch fresh, second loaded; bubbles off; no quota selection')

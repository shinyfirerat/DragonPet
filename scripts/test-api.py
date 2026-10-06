#!/usr/bin/env python3
from pathlib import Path
import tempfile,subprocess,time,os
root=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='dragonpet-api-') as directory:
    work=Path(directory);port=work/'port';exe=work/'api-check'
    subprocess.run(['swiftc','Sources/Preferences.swift','Sources/LocalLines.swift', 'Sources/TokenHistory.swift','Sources/Configuration.swift','Sources/Companion.swift','Sources/Usage.swift','Sources/APIClient.swift','Tests/Connections/main.swift','-framework','AppKit','-framework','Security','-o',str(exe)],cwd=root,check=True)
    server=subprocess.Popen(['python3','Tests/Connections/server.py',str(port)],cwd=root)
    try:
        for _ in range(100):
            if port.exists():break
            time.sleep(.02)
        subprocess.run([str(exe),port.read_text()],cwd=root,check=True,timeout=30,env=dict(os.environ,DRAGONPET_TEST_ROOT=str(work/'runtime')))
    finally:server.terminate();server.wait(timeout=5)

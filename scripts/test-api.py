#!/usr/bin/env python3
from pathlib import Path
import tempfile,subprocess,time,os,sys
root=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='dragonpet-api-') as directory:
    work=Path(directory);port=work/'port';exe=work/'api-check'
    subprocess.run(['swiftc','Sources/Preferences.swift','Sources/LocalLines.swift','Sources/TokenHistory.swift','Sources/Configuration.swift','Sources/Companion.swift','Sources/Usage.swift','Sources/APIClient.swift','Tests/Connections/main.swift','-framework','AppKit','-framework','Security','-o',str(exe)],cwd=root,check=True)
    server=subprocess.Popen([sys.executable,'Tests/Connections/server.py',str(port)],cwd=root,stderr=subprocess.PIPE,text=True)
    try:
        deadline=time.monotonic()+15
        value=None
        while time.monotonic()<deadline:
            if server.poll() is not None:raise RuntimeError('Mock server exited before ready: '+server.stderr.read())
            if port.exists():
                candidate=port.read_text().strip()
                if candidate.isdigit() and 0<int(candidate)<65536:value=candidate;break
            time.sleep(.05)
        if value is None:
            server.terminate()
            try:_,diagnostic=server.communicate(timeout=5)
            except subprocess.TimeoutExpired:server.kill();_,diagnostic=server.communicate(timeout=5)
            raise TimeoutError('Mock server did not publish its port within 15 seconds: '+diagnostic)
        subprocess.run([str(exe),value],cwd=root,check=True,timeout=30,env=dict(os.environ,DRAGONPET_TEST_ROOT=str(work/'runtime')))
    finally:
        if server.poll() is None:server.terminate()
        try:server.wait(timeout=5)
        except subprocess.TimeoutExpired:server.kill();server.wait(timeout=5)
        server.stderr.close()

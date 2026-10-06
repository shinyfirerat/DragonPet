#!/usr/bin/env python3
import json,time,pathlib
p=pathlib.Path(__file__).with_name("count.tmp")
n=int(p.read_text())+1 if p.exists() else 1
p.write_text(str(n))
time.sleep(.15)
print(json.dumps({"type":"final","text":"正文"+str(n)},ensure_ascii=False),flush=True)

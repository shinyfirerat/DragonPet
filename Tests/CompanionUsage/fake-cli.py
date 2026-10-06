#!/usr/bin/env python3
import json,sys,time,pathlib
if sys.argv[1]=='exec':
    assert sys.argv[-1]=='-' and 'test' not in sys.argv
    assert '随口说一句话' in sys.stdin.read()
    print(json.dumps({'type':'item.completed','item':{'type':'agent_message','text':'codex stub'}}),flush=True)
    print(json.dumps({'type':'turn.completed','usage':{'input_tokens':150,'cached_input_tokens':0,'output_tokens':15}}),flush=True)
else:
    path=pathlib.Path(sys.argv[sys.argv.index('--patch')+1]);text=path.read_text()
    assert path.parent.stat().st_mode & 0o777 == 0o700
    assert path.parent.parent.stat().st_mode & 0o777 == 0o700
    assert path.name.startswith('dragonpet-lean-') and path.stat().st_mode & 0o777 == 0o600
    def event(value):print(json.dumps(value),flush=True)
    def step(i,input,output):event({'type':'status','phase':'step_end','turn':1,'step':i,'usage':{'inputTokens':input,'cacheReadTokens':0,'outputTokens':output}})
    step(1,100,10);step(1,100,10)
    if 'partial-test' in text:
        time.sleep(5)
    else:
        step(2,50,5)
        event({'type':'turn.completed','usage':{'inputTokens':150,'cacheReadTokens':0,'outputTokens':15}})
        step(2,50,5)
        event({'type':'final','text':'测试正文'})

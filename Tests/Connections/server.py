#!/usr/bin/env python3
import http.server,json,sys
class Handler(http.server.BaseHTTPRequestHandler):
    count=0
    def log_message(self,*args):pass
    def do_POST(self):
        body=json.loads(self.rfile.read(int(self.headers.get('Content-Length','0'))))
        assert self.headers.get('Authorization')=='Bearer synthetic-test-only'
        assert body['model']=='test-model' and len(body['messages'])==2 and body['stream'] is False
        if self.path.startswith('/completion'): assert body.get('max_completion_tokens')==512 and 'max_tokens' not in body
        elif self.path.startswith('/no-limit'): assert 'max_tokens' not in body and 'max_completion_tokens' not in body
        else: assert body.get('max_tokens')==512
        if self.path.startswith('/redirect'):
            self.send_response(302);self.send_header('Location',f'http://127.0.0.1:{self.server.server_port}/forbidden/chat/completions');self.end_headers();return
        if self.path.startswith('/forbidden'):raise AssertionError('redirect was followed')
        status=401 if self.path.startswith('/unauthorized') else 429 if self.path.startswith('/limited') else 200
        self.send_response(status);self.send_header('Content-Type','application/json');self.end_headers()
        self.wfile.write(json.dumps({'choices':[{'message':{'content':'这是本机模拟回复。'}}]},ensure_ascii=False).encode())
server=http.server.HTTPServer(('127.0.0.1',0),Handler)
open(sys.argv[1],'w').write(str(server.server_port))
server.serve_forever()

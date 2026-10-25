#!/usr/bin/env python3
# MC demo gate: single-use launch tokens (previews must not consume) +
# 45-min sessions, proxying HTTP+WS to a local ttyd.
import json, os, secrets, time
from aiohttp import web, ClientSession, WSMsgType

TOKENS = '/tmp/mcdemo/tokens.json'   # {token: {created, used}}
SESS = '/tmp/mcdemo/sessions.json'   # {sid: expires}
TTYD = 'http://127.0.0.1:7700'
TOKEN_TTL = 12*3600
SESS_TTL = 45*60

def load(p):
    try: return json.load(open(p))
    except Exception: return {}
def save(p, d):
    json.dump(d, open(p, 'w'))

PAGE = '''<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Demo hbmc</title><style>
body{background:#00008b;color:#fff;font-family:system-ui,sans-serif;display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0}
div{text-align:center}h1{font-size:1.3rem}
button{font-size:1.2rem;padding:.8em 1.6em;background:#00a8a8;border:0;color:#000;font-weight:700;cursor:pointer}
p{color:#bbb}</style></head><body><div>
<h1>hbmc - Midnight Commander hecho con hbide</h1>
<p>Sesion interactiva de 45 minutos. El enlace es de un solo uso.</p>
<form method="post" action="/open?t=%s"><button type="submit">Abrir la demo</button></form>
</div></body></html>'''

def token_state(t):
    tk = load(TOKENS)
    rec = tk.get(t)
    if not rec: return 'invalid'
    if rec.get('used'): return 'used'
    if time.time() - rec['created'] > TOKEN_TTL: return 'expired'
    return 'ok'

async def launch(req):
    t = req.query.get('t', '')
    st = token_state(t)
    if st != 'ok':
        return web.Response(status=403, text='403 - invalid, already used or expired launch token\n')
    return web.Response(text=PAGE % t, content_type='html')

async def open_(req):
    t = req.query.get('t', '')
    st = token_state(t)
    if st != 'ok':
        return web.Response(status=403, text='403 - invalid, already used or expired launch token\n')
    tk = load(TOKENS); tk[t]['used'] = time.time(); save(TOKENS, tk)
    sid = secrets.token_urlsafe(18)
    ss = load(SESS); ss[sid] = time.time() + SESS_TTL; save(SESS, ss)
    raise web.HTTPFound('/m/%s/' % sid)

def sess_ok(sid):
    return load(SESS).get(sid, 0) > time.time()

async def proxy(req):
    sid = req.match_info['sid']
    if not sess_ok(sid):
        return web.Response(status=410, text='410 - demo session expired (45 min). Ask for a fresh link.\n')
    tail = req.match_info.get('tail', '')
    url = TTYD + '/' + tail
    if req.query_string: url += '?' + req.query_string
    if req.headers.get('Upgrade', '').lower() == 'websocket':
        ws_server = web.WebSocketResponse(protocols=('tty',))
        await ws_server.prepare(req)
        async with ClientSession() as cs:
            async with cs.ws_connect(url, protocols=('tty',)) as ws_client:
                async def c2s():
                    async for m in ws_server:
                        if m.type == WSMsgType.BINARY: await ws_client.send_bytes(m.data)
                        elif m.type == WSMsgType.TEXT: await ws_client.send_str(m.data)
                async def s2c():
                    async for m in ws_client:
                        if m.type == WSMsgType.BINARY: await ws_server.send_bytes(m.data)
                        elif m.type == WSMsgType.TEXT: await ws_server.send_str(m.data)
                import asyncio
                t1 = asyncio.create_task(c2s()); t2 = asyncio.create_task(s2c())
                done, pend = await asyncio.wait({t1, t2}, return_when=asyncio.FIRST_COMPLETED)
                for p in pend: p.cancel()
        return ws_server
    body = await req.read()
    hdrs = {k: v for k, v in req.headers.items() if k.lower() not in ('host', 'content-length', 'connection', 'upgrade')}
    async with ClientSession() as cs:
        async with cs.request(req.method, url, data=body if body else None, headers=hdrs) as r:
            data = await r.read()
            rh = {k: v for k, v in r.headers.items() if k.lower() not in ('content-length', 'transfer-encoding', 'connection', 'content-encoding')}
            return web.Response(status=r.status, body=data, headers=rh)


WRAPPER = '''<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<title>hbmc - demo</title><style>
html,body{height:100%;margin:0;background:#000;overflow:hidden}
body{display:flex;flex-direction:column}
#term{flex:1 1 auto;min-height:0;width:100%;border:0;display:block}
#aux{display:none;flex:0 0 auto;gap:6px;padding:6px;
background:#121212;justify-content:center;flex-wrap:nowrap;overflow-x:auto}
#aux button{font:600 15px/1 system-ui,sans-serif;padding:11px 13px;border-radius:8px;
border:1px solid #666;background:#2b2b8f;color:#fff;min-width:46px;touch-action:manipulation}
@media (pointer:coarse),(max-width:700px){
#aux{display:flex}
}
</style></head><body>
<iframe id="term" src="/s/__SID__/" allow="keyboard"></iframe>
<div id="aux">
<button data-k="\x1b">Esc</button>
<button data-k="\x09">Tab</button>
<button data-k="\x1b[D">&#8592;</button>
<button data-k="\x1b[B">&#8595;</button>
<button data-k="\x1b[A">&#8593;</button>
<button data-k="\x1b[C">&#8594;</button>
<button data-k="\r">Intro</button>
</div>
<script>
var fr = document.getElementById('term');
function sendKey(seq){
  var w = fr.contentWindow;
  if(w && w.term){ w.term.focus(); w.term.paste(seq); }
}
var btns = document.querySelectorAll('#aux button');
for(var i=0;i<btns.length;i++){
  (function(b){
    b.addEventListener('touchstart', function(e){ e.preventDefault(); sendKey(b.dataset.k); }, {passive:false});
    b.addEventListener('mousedown', function(e){ e.preventDefault(); sendKey(b.dataset.k); });
  })(btns[i]);
}
</script></body></html>'''

async def mobile_wrap(req):
    sid = req.match_info['sid']
    return web.Response(text=WRAPPER.replace('__SID__', sid), content_type='html')

app = web.Application()
app.router.add_get('/launch', launch)
app.router.add_post('/open', open_)
app.router.add_get('/m/{sid}/', mobile_wrap)
app.router.add_route('*', '/s/{sid}/{tail:.*}', proxy)
app.router.add_route('*', '/s/{sid}', proxy)
web.run_app(app, host='127.0.0.1', port=7800, print=None)

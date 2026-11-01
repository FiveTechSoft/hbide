#!/usr/bin/env python3
"""Bounded Linux foreign-root smoke with its own loader/libc; not a VM or installer."""
import argparse,hashlib,json,os,pathlib,shlex,subprocess,sys,time
ROOT=pathlib.Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',required=True,type=pathlib.Path);p.add_argument('--binary',required=True,type=pathlib.Path);p.add_argument('--receipt',required=True,type=pathlib.Path);p.add_argument('--output',required=True,type=pathlib.Path);a=p.parse_args()
 root=a.root.resolve();binary=a.binary.resolve();out=a.output.resolve();receipt=json.loads(a.receipt.read_text())
 if out.exists():p.error('output exists; refuses overwrite')
 if sha(binary)!=receipt['binary_sha256']:p.error('binary differs from receipt')
 for rel in ['app/hbide','proc','tmp','dev']:
  if not (root/rel).exists():p.error('root must already contain mount point '+rel)
 out.mkdir();args=['/usr/bin/bwrap','--unshare-user','--unshare-net','--uid','0','--gid','0','--die-with-parent','--ro-bind',str(root),'/', '--dev','/dev','--proc','/proc','--ro-bind',str(binary),'/app/hbide']
 wrapper=out/'hbide-wrapper';wrapper.write_text('#!/bin/sh\nexec '+' '.join(map(shlex.quote,args))+' --tmpfs /tmp --bind "$PWD" "$PWD" --chdir "$PWD" --setenv PATH /no-tools /app/hbide\n');wrapper.chmod(0o700)
 report=dict(scope=__doc__,receipt=receipt,root_os_release=(root/'etc/os-release').read_text(),root_library_sha256={s:sha(root/s) for s in ['lib/x86_64-linux-gnu/libc.so.6','lib/x86_64-linux-gnu/libm.so.6','lib/x86_64-linux-gnu/ld-linux-x86-64.so.2']},host_os_release=pathlib.Path('/etc/os-release').read_text(),runner_sha256=sha(pathlib.Path(__file__)),started=time.time(),tests={},ok=False)
 try:
  r=subprocess.run(args+['/lib64/ld-linux-x86-64.so.2','--list','/app/hbide'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=20);report['loader']={'exit':r.returncode,'output':r.stdout.decode()}
  if r.returncode:raise RuntimeError('foreign loader failed')
  for name,extra in [('test_about_build_pty.py',[]),('test_help_pty.py',[]),('test_designer_inspector_drag_anchor_pty.py',['--small'])]:
   test=ROOT/'tests'/name;env=dict(os.environ,HBIDE_BIN=str(wrapper),HBIDE_EXPECT_REV='unrecorded');log=out/(name+'.log');r=subprocess.run([sys.executable,'-u',str(test),*extra],cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120);log.write_bytes(r.stdout);bad=any(l.startswith((b'FAIL ',b'FAIL:',b'Traceback')) for l in r.stdout.splitlines());report['tests'][name]={'exit':r.returncode,'reported_failure':bad,'test_sha256':sha(test),'log':str(log)}
   if r.returncode or bad:raise RuntimeError('smoke failed '+name)
  report['ok']=sha(binary)==receipt['binary_sha256']
 except Exception as e:report['error']=str(e)
 report['finished']=time.time();(out/'results.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2));return int(not report['ok'])
if __name__=='__main__':raise SystemExit(main())

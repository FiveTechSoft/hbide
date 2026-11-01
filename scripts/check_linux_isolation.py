#!/usr/bin/env python3
"""Bounded same-host Linux minimal-root smoke, not a clean-machine installation.
Only the tested binary, system libraries and each test workdir are mounted.
The test driver stays outside; the application sees no checkout or compiler.
"""
import argparse,hashlib,json,os,pathlib,shutil,subprocess,sys,time
ROOT=pathlib.Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--candidate',required=True,type=pathlib.Path);p.add_argument('--output',required=True,type=pathlib.Path);a=p.parse_args();c=a.candidate.resolve();out=a.output.resolve()
 if out.exists():p.error('output exists; refuses overwrite')
 m=json.loads((c/'manifest.json').read_text());bwrap=shutil.which('bwrap')
 if sys.platform!='linux' or not bwrap:p.error('Linux and bwrap required')
 if not m.get('ok') or sha(c/'bin/hbide')!=m['binary_sha256']:p.error('candidate binary missing or changed')
 out.mkdir(parents=True);wrapper=out/'hbide-wrapper'
 # shlex quotes fixed executable paths; only PWD expands in the runtime wrapper.
 import shlex
 args=[bwrap,'--unshare-user','--unshare-net','--die-with-parent','--tmpfs','/','--ro-bind','/lib','/lib','--ro-bind','/lib64','/lib64','--dir','/app','--ro-bind',str(c/'bin/hbide'),'/app/hbide']
 wrapper.write_text('#!/bin/sh\nexec '+' '.join(map(shlex.quote,args))+' --bind "$PWD" "$PWD" --chdir "$PWD" --dev /dev --proc /proc --setenv PATH /no-tools /app/hbide\n');wrapper.chmod(0o700)
 report=dict(scope=__doc__,source=m['source'],binary_sha256=m['binary_sha256'],bwrap_sha256=sha(pathlib.Path(bwrap)),wrapper_sha256=sha(wrapper),started=time.time(),tests={},ok=False)
 try:
  for name in ['test_about_build_pty.py','test_help_pty.py','test_designer_inspector_drag_anchor_pty.py']:
   test=ROOT/'tests'/name;args=[sys.executable,'-u',str(test)]+(['--small'] if 'drag_anchor' in name else []);env=dict(os.environ,HBIDE_BIN=str(wrapper),HBIDE_EXPECT_REV=m['source'][:12]);log=out/(name+'.log')
   r=subprocess.run(args,cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120);log.write_bytes(r.stdout);bad=any(line.startswith((b'FAIL ',b'FAIL:',b'Traceback')) for line in r.stdout.splitlines());report['tests'][name]=dict(exit=r.returncode,reported_failure=bad,test_sha256=sha(test),log=str(log))
   if r.returncode or bad:raise RuntimeError('smoke failed '+name)
  report['ok']=sha(c/'bin/hbide')==m['binary_sha256']
 except Exception as e:report['error']=str(e)
 finally:
  report['finished']=time.time();(out/'results.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report,indent=2));return int(not report['ok'])
if __name__=='__main__':raise SystemExit(main())

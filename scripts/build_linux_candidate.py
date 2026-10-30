#!/usr/bin/env python3
"""Build a source-identified Linux candidate outside the checkout. Not a release."""
import argparse,hashlib,json,os,pathlib,shutil,subprocess,sys,tarfile,tempfile,time
ROOT=pathlib.Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def command(args,cwd,env=None,timeout=120):
 return subprocess.run(args,cwd=cwd,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True,type=pathlib.Path);p.add_argument('--strip-debug',action='store_true',help='retain unstripped binary, remove debug symbols in tested candidate');a=p.parse_args()
 if sys.platform!='linux':p.error('Linux only; this does not build or certify Windows')
 out=a.output.resolve()
 if out==ROOT or ROOT in out.parents:p.error('output must be outside checkout')
 if out.exists():p.error('output must not exist; refuses overwrite')
 status=command(['git','status','--porcelain'],ROOT).stdout.decode()
 if status:p.error('commit or remove changes first, including untracked files')
 compiler=shutil.which('hbmk2')
 if not compiler:p.error('hbmk2 must be on PATH')
 revision=command(['git','rev-parse','HEAD'],ROOT).stdout.decode().strip()
 out.mkdir(parents=True);src=out/'source';src.mkdir();binpath=out/'bin';binpath.mkdir()
 archive=out/'source.tar'
 with archive.open('wb') as f:subprocess.run(['git','archive','--format=tar',revision],cwd=ROOT,stdout=f,check=True)
 # Archive contains only trusted committed repo paths, not outside tar input.
 with tarfile.open(archive) as f:f.extractall(src,filter='data')
 # Never promote or test the inherited Windows EXE/prebuilt probes as a candidate.
 inherited=[]
 for rel in ['hbide.exe','tests/hbide','tests/test_designer']:
  f=src/rel
  if f.is_file():inherited.append({'path':rel,'sha256':sha(f)});f.unlink()
 env=dict(os.environ);env['HBIDE_BIN']=str(binpath/'hbide')
 manifest={'scope':'Linux source candidate, not a release. No Windows acceptance, portable installation or license clearance inferred.',
  'source':revision,'archive_sha256':sha(archive),'dirty':False,'started':time.time(),
  'compiler_path':compiler,'compiler_sha256':sha(pathlib.Path(compiler)),
  'compiler_version':command([compiler,'-version'],src).stdout.decode(errors='replace'),
  'removed_inherited_binaries':inherited,'tests':{},'build_exit':None}
 try:
  r=command([compiler,'hbide.hbp','-quiet','-o'+str(binpath/'hbide')],src,env)
  (out/'build.log').write_bytes(r.stdout);manifest['build_exit']=r.returncode
  if r.returncode:raise RuntimeError('build failed, see build.log')
  if a.strip_debug:
   strip=shutil.which('strip')
   if not strip:raise RuntimeError('strip required for --strip-debug')
   raw=out/'hbide.unstripped';shutil.copy2(binpath/'hbide',raw)
   manifest['unstripped_sha256']=sha(raw)
   manifest['strip_tool']={'path':strip,'sha256':sha(pathlib.Path(strip))}
   r=command([strip,'--strip-debug',str(binpath/'hbide')],src)
   (out/'strip.log').write_bytes(r.stdout)
   if r.returncode:raise RuntimeError('strip failed')
  manifest['binary_sha256']=sha(binpath/'hbide')
  deps=command(['ldd',str(binpath/'hbide')],src);(out/'dependencies.txt').write_bytes(deps.stdout)
  manifest['dependency_check_exit']=deps.returncode
  if deps.returncode or b'not found' in deps.stdout:raise RuntimeError('unresolved runtime dependency')
  # Runs from extracted sources, with HOME/recovery isolated by each harness.
  for name in ['test_help_mouse_pty.py','test_run_source_pty.py']:
   r=command([sys.executable,'-u',str(src/'tests'/name)],src,env)
   (out/(name+'.log')).write_bytes(r.stdout)
   failed=any(t in r.stdout for t in [b'FAIL ',b'FAIL:',b'Traceback',b'FAILED:'])
   manifest['tests'][name]={'exit':r.returncode,'reported_failure':failed,'test_sha256':sha(src/'tests'/name),'binary_sha256':sha(binpath/'hbide')}
   if r.returncode or failed:raise RuntimeError('smoke failed: '+name)
  if sha(binpath/'hbide')!=manifest['binary_sha256']:raise RuntimeError('candidate changed during smoke')
  if command(['git','rev-parse','HEAD'],ROOT).stdout.decode().strip()!=revision or command(['git','status','--porcelain'],ROOT).stdout:raise RuntimeError('checkout changed during candidate build')
  manifest['ok']=True
 except Exception as e:
  manifest['ok']=False;manifest['error']=str(e)
 finally:
  manifest['finished']=time.time();(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print(json.dumps({'ok':manifest['ok'],'source':revision,'binary_sha256':manifest.get('binary_sha256'),'manifest':str(out/'manifest.json')},indent=2))
 return 0 if manifest['ok'] else 1
if __name__=='__main__':raise SystemExit(main())

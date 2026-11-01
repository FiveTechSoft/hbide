#!/usr/bin/env python3
"""Compare two independent strip-debug rebuilds of an existing Linux candidate.
Bounded same-host/compiler comparison only. Does not clear release or install.
"""
import argparse,hashlib,json,os,pathlib,shutil,subprocess,sys,tarfile,time

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--candidate',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args()
 c=a.candidate.resolve();out=a.output.resolve()
 if out.exists():p.error('output exists; refuses overwrite')
 m=json.loads((c/'manifest.json').read_text());compiler=shutil.which('hbmk2');strip=shutil.which('strip')
 if sys.platform!='linux' or not compiler or not strip:p.error('Linux,hbmk2 and strip required')
 if not m.get('ok') or not m.get('strip_tool'):p.error('successful strip-debug candidate required')
 archive_name=m.get('archive_file','source.tar')
 if archive_name not in ('source.tar','source.tar.gz'):p.error('unsupported candidate archive filename')
 archive=c/archive_name
 if not archive.is_file():p.error('candidate archive missing')
 if sha(archive)!=m['archive_sha256'] or sha(c/'bin/hbide')!=m['binary_sha256']:p.error('candidate archive or binary changed')
 if sha(pathlib.Path(compiler))!=m['compiler_sha256'] or sha(pathlib.Path(strip))!=m['strip_tool']['sha256']:p.error('compiler or strip differs from candidate')
 out.mkdir(parents=True);report=dict(scope=__doc__,source=m['source'],candidate_sha256=m['binary_sha256'],archive_sha256=m['archive_sha256'],compiler_sha256=m['compiler_sha256'],strip_sha256=m['strip_tool']['sha256'],started=time.time(),builds=[],ok=False)
 try:
  for name in ['a','b']:
   src=out/name;src.mkdir()
   with tarfile.open(archive) as t:
    for member in t.getmembers():
     target=(src/member.name).resolve()
     if not target.is_relative_to(src):raise ValueError('archive traversal')
    t.extractall(src,filter='data')
   for rel in ['hbide.exe','tests/hbide','tests/test_designer']:
    f=src/rel
    if f.is_file():f.unlink()
   (src/'buildinfo.ch').write_text('#define HBIDE_BUILD_REV '+json.dumps(m['source'])+'\n')
   binary=out/(name+'-hbide');log=out/(name+'-build.log')
   with log.open('wb') as f:r=subprocess.run([compiler,'hbide.hbp','-quiet','-o'+str(binary)],cwd=src,stdout=f,stderr=subprocess.STDOUT,timeout=120)
   item=dict(name=name,build_exit=r.returncode,log=str(log));report['builds'].append(item)
   if r.returncode:raise RuntimeError('build failed '+name)
   r=subprocess.run([strip,'--strip-debug',str(binary)],capture_output=True,timeout=30)
   item.update(strip_exit=r.returncode,binary_sha256=sha(binary),binary=str(binary))
   if r.returncode:raise RuntimeError('strip failed '+name)
   item['matches_candidate']=binary.read_bytes()==(c/'bin/hbide').read_bytes()
  report['ok']=all(x['matches_candidate'] for x in report['builds'])
 except Exception as e:report['error']=str(e)
 finally:
  report['finished']=time.time();(out/'results.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report,indent=2));return int(not report['ok'])
if __name__=='__main__':raise SystemExit(main())

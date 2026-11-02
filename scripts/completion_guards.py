#!/usr/bin/env python3
"""Run identified tooling guards. Not product/PTY/visual/Windows acceptance."""
import argparse,hashlib,json,os,pathlib,subprocess,sys,tempfile,time,re
ROOT=pathlib.Path(__file__).resolve().parents[1]
CASES=['test_foreign_root_guard.py','test_linux_rebuild_guard.py','test_completion_guards.py','test_build_receipt.py','test_completion_inventory.py','test_distribution_notices.py','test_embed_help_docs.py','test_candidate_doc_preflight.py']
def reported_failure(text):
    # Only diagnostic line boundaries, not mentions in prose or nested labels.
    return any(re.match(r'^(?:FAIL(?: |:)|ERROR(?: |:)|FAILED \(|Traceback \(most recent call last\):$)',line)
               for line in text.splitlines())
def snapshot():
    def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True)
    files=git('ls-files').splitlines();h=hashlib.sha256()
    for path in files:
        h.update(path.encode()+b'\0');p=ROOT/path
        h.update(hashlib.sha256(p.read_bytes()).digest() if p.is_file() else b'missing')
    return dict(source=git('rev-parse','HEAD').strip(),tracked_changes=git('status','--porcelain','--untracked-files=no'),tracked_snapshot_sha256=h.hexdigest())
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=pathlib.Path);a=p.parse_args()
    out=a.output or pathlib.Path(tempfile.mkdtemp(prefix='hbide-guards-'));out.mkdir(parents=True,exist_ok=True)
    if (out/'results.json').exists():p.error('output already contains results; refuses overwrite')
    state=snapshot();report=dict(scope=__doc__,**state,started=time.time(),runner_sha256=hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),tests={})
    env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1');failed=False
    for name in CASES:
        test=ROOT/'tests'/name;before=hashlib.sha256(test.read_bytes()).hexdigest();started=time.time();log=out/(name+'.log')
        with log.open('w') as f:
            try:rc=subprocess.run([sys.executable,'-u',str(test)],cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=60).returncode
            except subprocess.TimeoutExpired:f.write('\nGUARD TIMEOUT\n');rc=124
        text=log.read_text();bad=reported_failure(text);changed=snapshot()!=state or hashlib.sha256(test.read_bytes()).hexdigest()!=before
        report['tests'][name]=dict(exit=rc,reported_failure=bad,source_or_test_changed=changed,test_sha256=before,log=str(log),seconds=round(time.time()-started,3));failed|=bool(rc or bad or changed)
        print(name,'PASS' if not(rc or bad or changed) else 'FAIL',flush=True)
        if rc==124:break
    report.update(ok=not failed,finished=time.time());(out/'results.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Results:',out/'results.json');return int(failed)
if __name__=='__main__':raise SystemExit(main())

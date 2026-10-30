"""Linux partial-write check for the compiled test_designer_write fixture."""
import json,pathlib,resource,signal,subprocess,sys,tempfile
exe=pathlib.Path(sys.argv[1]).resolve()
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-designer-partial-'))
for name in ('partial.json','partial.prg'):(work/name).write_text('ORIGINAL')
def limit():
    signal.signal(signal.SIGXFSZ,signal.SIG_IGN)
    resource.setrlimit(resource.RLIMIT_FSIZE,(64,64))
p=subprocess.run([str(exe),'partial'],cwd=work,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,preexec_fn=limit,timeout=10)
report={'exit':p.returncode,'stdout':p.stdout.decode(errors='replace'),'files':{f.name:f.read_text() for f in work.iterdir()}}
print(json.dumps(report,indent=2))
assert p.returncode==0 and report['files']=={'partial.json':'ORIGINAL','partial.prg':'ORIGINAL'}
assert 'PASS actual SaveJson/GeneratePrg partial writes' in report['stdout']

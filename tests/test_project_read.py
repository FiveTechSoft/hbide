"""Non-root Linux project read failure model, fresh build."""
import os,pathlib,shutil,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
assert os.geteuid()!=0,'permission fixture requires non-root'
with tempfile.TemporaryDirectory(prefix='hbide-project-read-') as tmp:
    work=pathlib.Path(tmp);denied=work/'denied.hbp';empty=work/'empty.hbp';exe=work/'probe'
    denied.write_bytes(b'PRECIOUS ORIGINAL HBP\n');empty.write_bytes(b'');denied.chmod(0)
    try:
        subprocess.run([shutil.which('hbmk2'),'tests/test_project_read.prg','project.prg','recovery.prg','-gtstd','-quiet','-o'+str(exe)],cwd=ROOT,check=True)
        subprocess.run([str(exe),str(denied),str(empty)],check=True)
    finally:
        denied.chmod(0o600)
        assert denied.read_bytes()==b'PRECIOUS ORIGINAL HBP\n'

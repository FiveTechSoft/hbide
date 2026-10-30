"""Build generated HRBs for generator-owned/case-insensitive local collisions."""
import pathlib,subprocess,tempfile,json,os
root=pathlib.Path(__file__).resolve().parents[2]
work=pathlib.Path(tempfile.mkdtemp(prefix='hbide-reserved-'))
lib=['hbwindow.prg','hbmenu.prg','hbbutton.prg','hbgetu.prg']
def run(args):
 p=subprocess.run(args,cwd=root,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=15)
 if p.returncode:raise RuntimeError(p.stdout.decode(errors='replace'))
 return p
run(['hbmk2','tests/probes/designer_reserved_names.prg','designer.prg','safeio.prg',*lib,'-gtstd','-quiet','-o'+str(work/'generator')])
rows=[]
for name in ['oDlg','ODLG','GetList','lOk','lDummy','aItems2','AITEMS2','Shared']:
 path=work/(name+'.prg');run([str(work/'generator'),str(path),name])
 run(['hbmk2',str(path),*lib,'-gh','-quiet','-o'+str(work/(name+'.hrb'))])
 rows.append({'name':name,'compile_exit':0})
print(json.dumps({'scope':'Linux generated HRB compilation, not execution or visual acceptance','cases':rows},indent=2))

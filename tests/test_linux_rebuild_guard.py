"""Rebuild verifier rejects stale/tampered inputs before creating output."""
import contextlib,hashlib,importlib.util,io,json,pathlib,sys,tempfile,unittest
from unittest.mock import patch
ROOT=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('rebuild',ROOT/'scripts/check_linux_rebuild.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
class RebuildGuard(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=pathlib.Path(self.tmp.name);self.c=self.root/'candidate';self.c.mkdir();(self.c/'bin').mkdir();(self.c/'bin/hbide').write_bytes(b'binary');(self.c/'source.tar').write_bytes(b'archive');self.compiler=self.root/'hbmk2';self.compiler.write_bytes(b'compiler');self.strip=self.root/'strip';self.strip.write_bytes(b'strip');self.out=self.root/'output';self.m=dict(ok=True,source='fixture',archive_sha256=sha(self.c/'source.tar'),binary_sha256=sha(self.c/'bin/hbide'),compiler_sha256=sha(self.compiler),strip_tool=dict(sha256=sha(self.strip)));self.save()
 def save(self):(self.c/'manifest.json').write_text(json.dumps(self.m))
 def rejected(self):
  with patch.object(sys,'argv',['rebuild','--candidate',str(self.c),'--output',str(self.out)]),patch.object(module.shutil,'which',side_effect=lambda x:str(self.compiler if x=='hbmk2' else self.strip)),patch.object(module.sys,'platform','linux'),patch.object(module.subprocess,'run') as run,contextlib.redirect_stderr(io.StringIO()),self.assertRaises(SystemExit):module.main()
  run.assert_not_called()
 def test_changed_archive_rejected(self):
  (self.c/'source.tar').write_bytes(b'changed');self.rejected();self.assertFalse(self.out.exists())
 def test_compressed_archive_tamper_rejected(self):
  (self.c/'source.tar.gz').write_bytes(b'compressed');self.m['archive_file']='source.tar.gz';self.m['archive_sha256']=sha(self.c/'source.tar.gz');self.save();(self.c/'source.tar.gz').write_bytes(b'changed');self.rejected();self.assertFalse(self.out.exists())
 def test_archive_path_escape_rejected(self):
  self.m['archive_file']='../source.tar';self.save();self.rejected();self.assertFalse(self.out.exists())
 def test_missing_named_archive_rejected(self):
  self.m['archive_file']='source.tar.gz';self.save();self.rejected();self.assertFalse(self.out.exists())
 def test_changed_binary_rejected(self):
  (self.c/'bin/hbide').write_bytes(b'changed');self.rejected();self.assertFalse(self.out.exists())
 def test_changed_compiler_rejected(self):
  self.compiler.write_bytes(b'changed');self.rejected();self.assertFalse(self.out.exists())
 def test_changed_strip_rejected(self):
  self.strip.write_bytes(b'changed');self.rejected();self.assertFalse(self.out.exists())
 def test_unsuccessful_candidate_rejected(self):
  self.m['ok']=False;self.save();self.rejected();self.assertFalse(self.out.exists())
 def test_existing_output_preserved(self):
  self.out.mkdir();marker=self.out/'keep';marker.write_bytes(b'keep');self.rejected();self.assertEqual(marker.read_bytes(),b'keep')
if __name__=='__main__':unittest.main()

"""Foreign-root preflight refuses changed inputs; no distro runtime acceptance."""
import contextlib,hashlib,importlib.util,io,json,pathlib,sys,tempfile,unittest
from unittest.mock import patch
ROOT=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('foreign',ROOT/'scripts/check_linux_foreign_root.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class ForeignGuard(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.r=pathlib.Path(self.tmp.name);self.root=self.r/'root';self.root.mkdir();self.binary=self.r/'bin';self.binary.write_bytes(b'binary');self.receipt=self.r/'receipt';self.data={'binary_sha256':m.sha(self.binary),'source':'fixture','tracked_changes':''};self.out=self.r/'out';self.save()
 def save(self):self.receipt.write_text(json.dumps(self.data))
 def rejected(self):
  with patch.object(sys,'argv',['foreign','--root',str(self.root),'--binary',str(self.binary),'--receipt',str(self.receipt),'--output',str(self.out)]),patch.object(m.subprocess,'run') as run,contextlib.redirect_stderr(io.StringIO()),self.assertRaises(SystemExit):m.main()
  run.assert_not_called()
 def test_changed_binary(self):self.binary.write_bytes(b'changed');self.rejected();self.assertFalse(self.out.exists())
 def test_dirty_receipt(self):self.data['tracked_changes']=' M main.prg';self.save();self.rejected();self.assertFalse(self.out.exists())
 def test_missing_source(self):self.data.pop('source');self.save();self.rejected();self.assertFalse(self.out.exists())
 def test_missing_mountpoint(self):self.rejected();self.assertFalse(self.out.exists())
 def test_existing_output(self):self.out.mkdir();(self.out/'keep').write_bytes(b'keep');self.rejected();self.assertEqual((self.out/'keep').read_bytes(),b'keep')
 def test_library_hash_change_detected(self):
  for rel in m.LIBRARIES:p=self.root/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b'library')
  old=m.library_state(self.root);(self.root/m.LIBRARIES[0]).write_bytes(b'changed');self.assertNotEqual(old,m.library_state(self.root))
if __name__=='__main__':unittest.main()

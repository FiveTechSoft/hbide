"""Receipt validation never silently relabels a stale binary as HEAD."""
import importlib.util,pathlib,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
s=importlib.util.spec_from_file_location('runner',ROOT/'scripts/completion_pty.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class Receipt(unittest.TestCase):
 def setUp(self):
  self.state={'source':'a'*40,'tracked_changes':'','tracked_snapshot_sha256':'b'*64,'untracked_inputs_sha256':'d'*64}
  self.receipt=dict(self.state,binary_sha256='c'*64)
 def test_exact_match(self):m.validate_receipt(self.receipt,self.state,'c'*64)
 def test_missing_fields(self):
  for k in self.receipt:
   r=dict(self.receipt);del r[k]
   with self.assertRaises(ValueError):m.validate_receipt(r,self.state,'c'*64)
 def test_changed_source_dirty_bytes_or_binary(self):
  for k in self.receipt:
   r=dict(self.receipt);r[k]='changed'
   with self.assertRaises(ValueError):m.validate_receipt(r,self.state,'c'*64)
if __name__=='__main__':unittest.main()

"""Guard-runner negative outcomes must stay failed, never synthesized green."""
import importlib.util,json,pathlib,subprocess,tempfile,unittest
from unittest.mock import patch
ROOT=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('guards',ROOT/'scripts/completion_guards.py')
guards=importlib.util.module_from_spec(spec);spec.loader.exec_module(guards)
class Guards(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=pathlib.Path(self.tmp.name);(self.root/'tests').mkdir()
        self.test=self.root/'tests/probe.py';self.test.write_text("print('fixture')\n")
        self.out=self.root/'out';self.state=dict(source='a'*40,tracked_changes='',tracked_snapshot_sha256='b'*64)
    def run_fixture(self,code=0,text='OK\n',changed=False,timeout=False):
        def fake_run(argv,**kw):
            kw['stdout'].write(text)
            if timeout:raise subprocess.TimeoutExpired(argv,60)
            if changed:self.test.write_text('changed source\n')
            return subprocess.CompletedProcess(argv,code)
        with patch.object(guards,'ROOT',self.root),patch.object(guards,'CASES',['probe.py']),patch.object(guards,'snapshot',return_value=self.state),patch.object(guards.subprocess,'run',side_effect=fake_run),patch.object(guards.sys,'argv',['guards','--output',str(self.out)]):
            rc=guards.main()
        return rc,json.loads((self.out/'results.json').read_text())
    def test_clean_zero_exit_passes(self):
        rc,r=self.run_fixture();self.assertEqual(rc,0);self.assertTrue(r['ok'])
    def test_nonzero_exit_fails(self):
        rc,r=self.run_fixture(code=7);self.assertEqual(rc,1);self.assertEqual(r['tests']['probe.py']['exit'],7)
    def test_printed_failure_with_zero_exit_fails(self):
        rc,r=self.run_fixture(text='FAILED (failures=1)\n');self.assertEqual(rc,1);self.assertTrue(r['tests']['probe.py']['reported_failure'])
    def test_plain_failure_and_error_boundaries_zero_exit_fail(self):
        for text in ['FAIL expected byte preservation\n','ERROR unexpected result\n','Traceback (most recent call last):\n','FAIL: failed check\n','ERROR: test_name\n']:
            with self.subTest(text=text):
                # Each runner fixture owns a separate output directory.
                self.out=self.root/('out-'+str(abs(hash(text))))
                rc,r=self.run_fixture(text=text)
                self.assertEqual(rc,1);self.assertTrue(r['tests']['probe.py']['reported_failure']);self.assertFalse(r['ok'])
    def test_prose_nested_labels_and_similar_words_not_failures(self):
        text='Expected FAIL in negative fixture\nprobe.py FAIL\nFAILURE example\nERRORS total zero\nTraceback documentation example\n'
        rc,r=self.run_fixture(text=text)
        self.assertEqual(rc,0);self.assertFalse(r['tests']['probe.py']['reported_failure']);self.assertTrue(r['ok'])
    def test_nested_negative_runner_is_not_a_failure_of_outer_runner(self):
        self.out=self.root/'inner'
        rc,inner=self.run_fixture(text='FAIL intentional negative fixture\n')
        self.assertEqual(rc,1)
        self.out=self.root/'outer'
        rc,outer=self.run_fixture(text='probe.py FAIL\nNested expected failure verified\n')
        self.assertEqual(rc,0);self.assertTrue(outer['ok'])
    def test_changed_test_with_zero_exit_fails(self):
        rc,r=self.run_fixture(changed=True);self.assertEqual(rc,1);self.assertTrue(r['tests']['probe.py']['source_or_test_changed'])
    def test_timeout_fails(self):
        rc,r=self.run_fixture(timeout=True);self.assertEqual(rc,1);self.assertEqual(r['tests']['probe.py']['exit'],124)
    def test_existing_results_not_overwritten(self):
        self.out.mkdir();p=self.out/'results.json';p.write_text('PRECIOUS')
        with patch.object(guards.sys,'argv',['guards','--output',str(self.out)]),self.assertRaises(SystemExit):guards.main()
        self.assertEqual(p.read_text(),'PRECIOUS')
if __name__=='__main__':unittest.main()

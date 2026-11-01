"""Invalid recovery fixtures must fail before booting an IDE or writing files."""
import pathlib, subprocess, sys, unittest
ROOT = pathlib.Path(__file__).resolve().parents[1]
class FixtureModes(unittest.TestCase):
    def test_incompatible_modes_rejected_before_launch(self):
        for script in ['test_recovery_deep_path.py', 'test_undo_journal_cleanup_pty.py', 'test_reload_journal_cleanup_pty.py']:
            for flags in [ ['--mixed-eol','--utf8-bom'], ['--tabs','--utf8-raw'], ['--mixed-eol','--crlf'], ['--tabs','--mixed-eol'] ]:
                with self.subTest(script=script, flags=flags):
                    r=subprocess.run([sys.executable,str(ROOT/'tests'/script),'/nonexistent/no-IDE',*flags],capture_output=True,text=True)
                    self.assertNotEqual(r.returncode,0)
                    self.assertTrue('fixture mode' in r.stderr.lower(),r.stderr)
                    self.assertNotIn('Traceback',r.stderr)
if __name__=='__main__': unittest.main()

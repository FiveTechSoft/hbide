"""Execute candidate preflight on an isolated committed repository, never real checkout."""
import importlib.util,json,os,pathlib,shutil,subprocess,tempfile,unittest
from unittest.mock import patch
ROOT=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('candidate',ROOT/'scripts/build_linux_candidate.py')
candidate=importlib.util.module_from_spec(spec);spec.loader.exec_module(candidate)
class CandidateDocs(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.base=pathlib.Path(self.tmp.name);self.root=self.base/'repo';self.root.mkdir()
        (self.root/'scripts').mkdir();shutil.copy2(ROOT/'scripts/embed_help_docs.py',self.root/'scripts/embed_help_docs.py')
        (self.root/'README.md').write_text('Frozen exact document\n')
        shutil.copy2(ROOT/'scripts/audit_distribution_notices.py',self.root/'scripts/audit_distribution_notices.py')
        (self.root/'hbide.hbp').write_text('main.prg\n')
        (self.root/'main.prg').write_text('// see LICENSE.txt\n#include \"inkey.ch\"\n')
        self.git('init','-q');self.git('config','user.email','test@invalid');self.git('config','user.name','Isolated test')
        self.git('add','.')
        subprocess.run([os.sys.executable,str(self.root/'scripts/embed_help_docs.py')],cwd=self.root,check=True,stdout=subprocess.PIPE)
        self.tools=self.base/'tools';self.tools.mkdir();self.marker=self.base/'build-called'
        fake=self.tools/'hbmk2';fake.write_text('#!/bin/sh\nif [ "$1" = "-version" ]; then echo isolated-compiler; exit 0; fi\nprintf called > "'+str(self.marker)+'"\nexit 19\n');fake.chmod(0o700)
        self.out=self.base/'candidate'
    def git(self,*args):return subprocess.run(['git',*args],cwd=self.root,check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    def run_builder(self):
        self.git('add','.');self.git('commit','-qm','isolated fixture')
        with patch.object(candidate,'ROOT',self.root),patch.dict(os.environ,PATH=str(self.tools)+':'+os.environ['PATH']),patch.object(os.sys,'argv',['candidate','--output',str(self.out)]):
            rc=candidate.main()
        return rc,json.loads((self.out/'manifest.json').read_text())
    def test_stale_export_never_invokes_build(self):
        (self.root/'README.md').write_text('Changed after embedding\n')
        rc,m=self.run_builder()
        self.assertEqual(rc,1);self.assertFalse(m['ok']);self.assertEqual(m['document_check']['exit'],1)
        self.assertIsNone(m['build_exit']);self.assertFalse(self.marker.exists())
        self.assertIn('export embedded documents stale',m['error'])
        self.assertFalse((self.out/'source/.git').exists())
        self.assertIn('Stale helpdocs.ch',(self.out/'document-check.log').read_text())
    def test_notice_audit_failure_prevents_compile(self):
        (self.root/'scripts/audit_distribution_notices.py').write_text('raise SystemExit(17)\n')
        rc,m=self.run_builder()
        self.assertEqual(rc,1);self.assertFalse(m['ok'])
        self.assertIsNone(m['build_exit']);self.assertFalse(self.marker.exists())
        self.assertEqual(m['error'],'export source notice inventory failed')
    def test_notice_revision_mismatch_prevents_compile(self):
        (self.root/'scripts/audit_distribution_notices.py').write_text('print(\'{"source":"wrong"}\')\n')
        rc,m=self.run_builder()
        self.assertEqual(rc,1);self.assertFalse(m['ok'])
        self.assertIsNone(m['build_exit']);self.assertFalse(self.marker.exists())
        self.assertEqual(m['error'],'source notice inventory revision mismatch')
    def test_current_export_reaches_build_after_document_gate(self):
        rc,m=self.run_builder()
        self.assertEqual(rc,1);self.assertFalse(m['ok']);self.assertEqual(m['document_check']['exit'],0)
        self.assertEqual(m['document_check']['count'],1);self.assertEqual(m['build_exit'],19)
        self.assertTrue(self.marker.exists());self.assertEqual(m['error'],'build failed, see build.log')
        notices=json.loads((self.out/'source-notices.json').read_text())
        self.assertEqual(notices['source'],m['source'])
        self.assertTrue(notices['release_review_required'])
        self.assertEqual(notices['missing_referenced_license'],['main.prg'])
        self.assertTrue(m['source_notice_inventory']['does_not_clear_redistribution'])
        self.assertEqual(m['release_status'],'not cleared; source notice review required')
        self.assertFalse((self.out/'source/.git').exists())
        self.assertIn('PASS: 1 complete documents',(self.out/'document-check.log').read_text())
if __name__=='__main__':unittest.main()

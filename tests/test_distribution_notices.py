"""Inventory/gate semantics, not legal clearance."""
import importlib.util,pathlib,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('audit',ROOT/'scripts/audit_distribution_notices.py')
audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)
class Notices(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=pathlib.Path(self.tmp.name)
        (self.root/'hbide.hbp').write_text('main.prg\n# skip.c\n')
        (self.root/'main.prg').write_text('// GNU General Public License\n// special exception\n// Copyright X\n// see LICENSE.txt\n#include "inkey.ch"\nreturn\n')
    def test_missing_referenced_license_blocks(self):
        d=audit.audit(self.root)
        self.assertEqual(d['missing_referenced_license'],['main.prg']);self.assertTrue(d['release_review_required'])
    def test_detected_notice_not_legal_clearance(self):
        (self.root/'LICENSE.txt').write_text('fixture only')
        d=audit.audit(self.root)
        self.assertFalse(d['release_review_required']);self.assertIn('Does not clear redistribution',d['scope'])
        self.assertEqual(d['root_notice_files'],['LICENSE.txt'])
    def test_unmarked_source_requires_review(self):
        (self.root/'main.prg').write_text('procedure Main()\nreturn\n')
        d=audit.audit(self.root)
        self.assertEqual(d['without_detected_gpl_header'],['main.prg']);self.assertTrue(d['release_review_required'])
    def test_body_literal_is_not_header_notice(self):
        (self.root/'main.prg').write_text('#include "inkey.ch"\n? "GNU General Public License"\n')
        self.assertTrue(audit.audit(self.root)['release_review_required'])
    def test_current_source_missing_license_not_silently_cleared(self):
        d=audit.audit()
        self.assertTrue(d['release_review_required']);self.assertTrue(d['missing_referenced_license'])
        self.assertEqual(len(d['sources']),len({r['path'] for r in d['sources']}))
if __name__=='__main__':unittest.main()

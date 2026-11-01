"""Exact offline catalogue checks for frozen exports without git."""
import importlib.util,json,pathlib,tempfile,unittest
from unittest.mock import patch
ROOT=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('embed',ROOT/'scripts/embed_help_docs.py')
embed=importlib.util.module_from_spec(spec);spec.loader.exec_module(embed)
class ExportDocs(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=pathlib.Path(self.tmp.name);(self.root/'docs').mkdir()
        (self.root/'README.md').write_text('Root exact café\n')
        (self.root/'docs/guide.md').write_text('Guide bytes\n')
        self.paths=self.root/'paths.json'
        self.patch=patch.object(embed,'ROOT',self.root);self.patch.start();self.addCleanup(self.patch.stop)
    def write(self,paths):self.paths.write_text(json.dumps(paths))
    def test_export_without_git_matches_tracked_catalogue(self):
        paths=['README.md','docs/guide.md'];self.write(list(reversed(paths)))
        with patch.object(embed.subprocess,'check_output',return_value='\n'.join(paths)+'\n'):
            expected=embed.generate()
        with patch.object(embed.subprocess,'check_output',side_effect=AssertionError('no git in export')):
            self.assertEqual(embed.generate(self.paths),expected)
    def test_document_edit_changes_catalogue(self):
        self.write(['README.md']);before=embed.generate(self.paths)
        (self.root/'README.md').write_text('Changed\n');self.assertNotEqual(embed.generate(self.paths),before)
    def test_invalid_paths_fail_closed(self):
        for paths in [[],{},[1],['README.md','README.md'],['../README.md'],['/README.md'],['missing.md'],['docs/../README.md'],['paths.json']]:
            with self.subTest(paths=paths):
                self.write(paths)
                with self.assertRaises(ValueError):embed.generate(self.paths)
    def test_symlink_escape_rejected(self):
        with tempfile.TemporaryDirectory() as outside:
            target=pathlib.Path(outside)/'private.md';target.write_text('outside')
            (self.root/'link.md').symlink_to(target);self.write(['link.md'])
            with self.assertRaises(ValueError):embed.generate(self.paths)
    def test_candidate_preflight_precedes_build(self):
        source=(ROOT/'scripts/build_linux_candidate.py').read_text()
        self.assertLess(source.index("'--paths-file'"),source.index("[compiler,'hbide.hbp'"))
        self.assertIn("if r.returncode:raise RuntimeError('export embedded documents stale",source)
if __name__=='__main__':unittest.main()

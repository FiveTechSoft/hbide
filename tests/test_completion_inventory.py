"""Source-inventory contract only; no native modal runtime certification."""
import importlib.util
import pathlib
import unittest

ROOT=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('audit_completion_surface',ROOT/'scripts/audit_completion_surface.py')
audit=importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)

class ModalInventory(unittest.TestCase):
    def setUp(self):
        self.rows=audit.modal_fields()
        self.source=(ROOT/'designer.prg').read_text().splitlines()
    def test_exact_current_surface_denominator(self):
        counts={name:sum(r['surface']==name for r in self.rows)
                for name in ['EditProperties','DlgProperties','SelectFileName']}
        self.assertEqual(counts,{'EditProperties':18,'DlgProperties':9,'SelectFileName':3})
        self.assertEqual(len({r['id'] for r in self.rows}),30)
    def test_source_identity_and_labels(self):
        for row in self.rows:
            with self.subTest(id=row['id']):
                self.assertIn('GET '+row['variable'],self.source[row['line']-1])
                self.assertTrue(row['label'])
                self.assertIn('Pending',row['acceptance'])
        self.assertEqual([r['label'] for r in self.rows if r['variable']=='nCol'],['Col:'])
    def test_repeated_variables_have_distinct_condition_paths(self):
        fields=[r for r in self.rows if r['surface']=='EditProperties' and r['variable']=='cVariable']
        self.assertEqual(len(fields),2)
        self.assertNotEqual(fields[0]['conditions'],fields[1]['conditions'])
        self.assertIn('DSN_GET',fields[0]['conditions'][-1])
        self.assertIn('DSN_RADIO',fields[1]['conditions'][-1])
    def test_nested_event_conditions_preserved(self):
        fields={r['variable']:r for r in self.rows if r['surface']=='EditProperties'}
        self.assertEqual(len(fields['cWhen']['conditions']),1)
        self.assertEqual(len(fields['cFocus']['conditions']),2)
        self.assertEqual(len(fields['cState']['conditions']),2)
        self.assertIn('!= DSN_SAY',fields['cState']['conditions'][0])
        self.assertIn('DSN_COMBOBOX',fields['cState']['conditions'][1])
    def test_buttons_and_pictures(self):
        self.assertEqual(sum(r['kind']=='button' for r in self.rows),6)
        self.assertEqual(sum(r['kind']=='checkbox' for r in self.rows),1)
        for row in self.rows:
            if row['variable']=='nRow':self.assertEqual(row['picture'],'999')
            if row['variable']=='cAction':self.assertEqual(row['picture'],'@S40')
    def test_generation_deterministic(self):
        self.assertEqual(self.rows,audit.modal_fields())

    def test_control_expansion(self):
        pairs=audit.modal_control_pairs(self.rows)
        self.assertEqual(len(pairs),79)
        self.assertEqual(len({r['id'] for r in pairs}),79)
        fields=lambda c:{r['variable'] for r in pairs if r['control']==c}
        self.assertNotIn('cWhen',fields('say'))
        self.assertNotIn('cFocus',fields('get'))
        self.assertNotIn('cState',fields('radiogroup'))
        self.assertIn('cState',fields('combobox'))
        self.assertEqual(fields('filename'),{'cFile','lDummy'})
    def test_unknown_condition_fails_closed(self):
        broken=dict(self.rows[0],conditions=['File( "unrelated" )'])
        with self.assertRaisesRegex(ValueError,'Unresolved modal condition'):
            audit.modal_control_pairs([broken])

    def test_ide_modal_non_get_inputs_and_multiline_kinds(self):
        rows=audit.ide_modal_fields()
        self.assertEqual(len(rows),26)
        self.assertEqual(len({r['id'] for r in rows}),26)
        fields={(r['surface'],r['variable']):r for r in rows}
        self.assertEqual(fields['CompilerFlags','lWarnings']['kind'],'checkbox')
        self.assertEqual(fields['CompilerFlags','cCompiler']['kind'],'radiogroup')
        self.assertEqual(fields['DisplayOpts','cSize']['kind'],'radiogroup')
        self.assertEqual(fields['ReplaceDialog','cFind']['kind'],'freeform_input')
        self.assertEqual(fields['ReplaceDialog','cReplace']['kind'],'freeform_input')
        self.assertEqual(sum(r['kind']=='freeform_input' for r in rows),4)
    def test_ide_modal_source_lines(self):
        lines=(ROOT/'hbide.prg').read_text().splitlines()
        for row in audit.ide_modal_fields():
            self.assertIn('HBIDE_DlgInput' if row['kind']=='freeform_input' else 'GET '+row['variable'],lines[row['line']-1])

if __name__=='__main__':unittest.main()

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
        self.assertEqual(len(rows),43)
        self.assertEqual(len({r['id'] for r in rows}),43)
        fields={(r['surface'],r['variable']):r for r in rows}
        self.assertEqual(fields['CompilerFlags','lWarnings']['kind'],'checkbox')
        self.assertEqual(fields['CompilerFlags','cCompiler']['kind'],'radiogroup')
        self.assertEqual(fields['DisplayOpts','cSize']['kind'],'radiogroup')
        self.assertEqual(fields['ReplaceDialog','cFind']['kind'],'freeform_input')
        self.assertEqual(fields['ReplaceDialog','cReplace']['kind'],'freeform_input')
        self.assertEqual(sum(r['kind']=='freeform_input' for r in rows),4)
    def test_file_and_help_modal_declarations(self):
        rows=audit.ide_modal_fields()
        for name,count in [('ProjectOpen',4),('OpenFile',4),('SaveAs',3),('HelpPick',3),('HelpIndex',3)]:
            with self.subTest(surface=name):
                fields=[r for r in rows if r['surface']==name]
                self.assertEqual(len(fields),count)
                self.assertEqual(sum(r['kind']=='pushbutton' for r in fields),2)
        for name in ['ProjectOpen','OpenFile','HelpPick']:
            self.assertEqual(sum(r['kind']=='listbox' for r in rows if r['surface']==name),1)

    def test_ide_modal_source_lines(self):
        lines=(ROOT/'hbide.prg').read_text().splitlines()
        for row in audit.ide_modal_fields():
            self.assertIn('HBIDE_DlgInput' if row['kind']=='freeform_input' else 'GET '+row['variable'],lines[row['line']-1])

class DebuggerInputInventory(unittest.TestCase):
    def test_calls_not_declarations(self):
        rows=audit.debugger_inputs()
        self.assertEqual(len(rows),27)
        self.assertEqual(len({r['id'] for r in rows}),27)
        self.assertEqual(sum(r['kind']=='inputbox' for r in rows),18)
        self.assertEqual(sum(r['kind']=='inline_input' for r in rows),6)
        self.assertEqual(sum(r['kind']=='input_constructor' for r in rows),3)
        for row in rows:
            line=(ROOT/row['source']).read_text().splitlines()[row['line']-1]
            self.assertFalse(line.startswith('FUNCTION '))
            self.assertIn(row['api']+'(',line)
    def test_readonly_and_expression_context_not_lost(self):
        rows=audit.debugger_inputs()
        readonly=[r for r in rows if r['mode']=='explicit_readonly']
        self.assertEqual(len(readonly),3)
        self.assertEqual({r['context'].split('(')[0].split()[-1] for r in readonly},
                         {'EditVar','Inspect','WatchpointInspect'})
        edit=next(r for r in rows if 'EditVar-inputbox-2' in r['id'])
        self.assertIn('__dbgExprValidBlock()',edit['call'])
        self.assertIn('ELSE',edit['preceding_source'])
        numeric=next(r for r in rows if 'SearchLine-inputbox' in r['id'])
        self.assertIn('"Line number", 1',numeric['call'])

class MouseRouteInventory(unittest.TestCase):
    def test_bounded_event_branch_counts_and_identity(self):
        rows=audit.mouse_routes()
        self.assertEqual(len(rows),27)
        self.assertEqual(len({r['id'] for r in rows}),27)
        for row in rows:
            line=(ROOT/row['source']).read_text().splitlines()[row['line']-1]
            self.assertEqual(row['condition'].split(';')[0].strip(),line.rstrip(';').strip())
            self.assertIn('Pending',row['acceptance'])
    def test_context_and_non_get_mouse_route(self):
        rows=audit.mouse_routes()
        nav=[r for r in rows if 'HBIDE_IsNavKey' in r['context']]
        self.assertEqual(len(nav),2)
        self.assertTrue(any('K_LDBLCLK' in r['condition'] and r['source']=='editor.prg' for r in rows))
        sync=[r for r in rows if 'DsnMouseRoute' in r['context']]
        self.assertEqual(len(sync),3)
        self.assertTrue(any('DSNK_MLUP' in r['condition'] for r in sync))

if __name__=='__main__':unittest.main()

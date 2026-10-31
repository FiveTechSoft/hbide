"""Source-inventory contract only; no native modal runtime certification."""
import importlib.util
import pathlib
import json
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

class RecentAcceptanceLinks(unittest.TestCase):
    def test_recent_navigation_suites_are_linked(self):
        data=json.loads((ROOT/'tests/completion_acceptance.json').read_text())
        linked=data['menus']['IDE-019']['tests']
        for name in ['test_nav_array_comment_pty.py','test_nav_pragma_macro_pty.py','test_nav_lexical.prg']:
            self.assertIn(name,linked)
            self.assertTrue((ROOT/'tests'/name).is_file())
    def test_recent_project_inventory_acceptance_linked(self):
        data=json.loads((ROOT/'tests/completion_acceptance.json').read_text())
        for key in ['IDE-020','IDE-021']:
            row=data['menus'][key]
            for name in ['test_project_bom_pty.py','test_project_eof_pty.py','test_project_cxx_source_pty.py']:
                self.assertIn(name,row['tests'])
                self.assertTrue((ROOT/'tests'/name).is_file())
            for phrase in ['parse copy','preserving exact original bytes','missing aliases stay visible','not all encodings or compiler modes']:
                self.assertIn(phrase,row['contract'])
    def test_array_bracket_comment_scope_linked(self):
        row=json.loads((ROOT/'tests/completion_acceptance.json').read_text())['menus']['IDE-019']
        self.assertIn('test_nav_array_bracket_comment_pty.py',row['tests'])
        self.assertIn('RETURN bracket literal stays masked',row['contract'])
        self.assertIn('not a full Harbour preprocessor',row['contract'])
    def test_gcc_color_and_fallback_scope_remains_explicit(self):
        data=json.loads((ROOT/'tests/completion_acceptance.json').read_text())
        contract=data['menus']['IDE-021']['contract']
        for phrase in ['raw output remains unchanged','absent/ambiguous/non-ASCII/cropped','not a semantic-correctness claim','Output viewer ANSI']:
            self.assertIn(phrase,contract)

class RemainingMenuLinks(unittest.TestCase):
    def test_designer_real_menu_workflow_is_bounded(self):
        data=json.loads((ROOT/'tests/completion_acceptance.json').read_text())
        row=data['menus']['IDE-036']
        self.assertEqual(row['expected_label'],'Designer...')
        self.assertIn('test_designer_pty.py',row['tests'])
        for text in ['Actual Options Designer menu','Linux25x80','not all controls/properties']:
            self.assertIn(text,row['contract'])
    def test_watchpoint_menu_link_does_not_claim_triggering(self):
        data=json.loads((ROOT/'tests/completion_acceptance.json').read_text())
        row=data['menus']['DBG-021']
        self.assertEqual(row['expected_label'],'Watchpoint...')
        self.assertIn('test_debug_watch_modal_pty.py',row['tests'])
        self.assertIn('Actual Point Watchpoint menu',row['contract'])
        self.assertIn('not all expressions/containers, change-trigger behavior',row['contract'])

class DispatchAcceptance(unittest.TestCase):
    def setUp(self):
        self.routes=audit.inventory()[1]
        self.specs=json.loads((ROOT/'tests/completion_acceptance.json').read_text())['dispatch_acceptance']
    def test_f5_exact_route_and_scope(self):
        rows=audit.link_dispatch_contracts(self.routes,self.specs)
        linked=[r for r in rows if r.get('acceptance_id')=='DSN-KEY-LIVEPRG-F5']
        self.assertEqual(len(linked),1)
        self.assertEqual(linked[0]['condition'],'case nKey == K_F5')
        self.assertEqual(linked[0]['source'],'designer.prg')
        self.assertIn('Not all controls',linked[0]['acceptance']['contract'])
        self.assertNotIn('acceptance',self.routes[0])
    def test_ctrl_g_delete_identity_route_linked(self):
        linked=[r for r in audit.link_dispatch_contracts(self.routes,self.specs) if 'acceptance' in r]
        self.assertEqual(len(linked),8)
        row=next(r for r in linked if r['acceptance_id']=='IDE-KEY-GOTOFUNCTION-CTRL-G')
        self.assertEqual(row['source'],'hbide.prg')
        self.assertIn('hb_keyExt( nKey ) != HB_KX_DEL',row['condition'])
        self.assertEqual(row['acceptance']['tests'],['test_nav_pty.py','test_bp_delete_policy.py'])
        self.assertIn('not all terminal extended-key encodings',row['acceptance']['contract'])
    def test_f2_f3_if_dispatch_routes_are_bound(self):
        linked={r['acceptance_id']:r for r in audit.link_dispatch_contracts(self.routes,self.specs) if 'acceptance_id' in r}
        for ident,key in [('IDE-KEY-SAVE-F2','K_F2'),('IDE-KEY-REPEAT-FIND-F3','K_F3')]:
            row=linked[ident]
            self.assertEqual(row['condition'],'if nKeyStd == '+key+' .and. ! ::oMenu:IsOpen()')
            self.assertEqual(row['source'],'hbide.prg')
            self.assertIn('not all',row['acceptance']['contract'])
        self.assertIn('not F5 key',linked['IDE-KEY-REPEAT-FIND-F3']['acceptance']['contract'])
    def test_case_and_if_source_conditions_preserved(self):
        self.assertTrue(any(r['condition'].startswith('case ') for r in self.routes))
        self.assertTrue(any(r['condition'].startswith('if ') for r in self.routes))
        for row in self.routes:
            lines=(ROOT/row['source']).read_text().splitlines()
            j=row['line']-1
            parts=[lines[j].strip()]
            while parts[-1].endswith(';'):
                parts[-1]=parts[-1][:-1].rstrip()
                j+=1
                parts.append(lines[j].strip())
            self.assertEqual(row['condition'],' '.join(parts))
    def test_find_f5_if_dispatch_is_bound(self):
        row=next(r for r in audit.link_dispatch_contracts(self.routes,self.specs) if r.get('acceptance_id')=='IDE-KEY-FIND-F5')
        self.assertEqual(row['condition'],'if nKeyStd == K_F5 .and. ! ::oMenu:IsOpen()')
        self.assertEqual(row['acceptance']['tests'],['test_find_f5_selection_pty.py'])
        self.assertIn('success/cancel/missing',row['acceptance']['contract'])
    def test_multiline_ctrl_f6_route_preserved_and_bound(self):
        row=next(r for r in audit.link_dispatch_contracts(self.routes,self.specs) if r.get('acceptance_id')=='IDE-KEY-NEXTDOC-CTRL-F6')
        self.assertIn('hb_keyExt( nKey ) == HB_KX_F6',row['condition'])
        self.assertTrue(row['condition'].endswith('HB_KF_CTRL ) != 0 )'))
        self.assertNotIn(';',row['condition'])
        self.assertEqual(row['acceptance']['tests'],['test_multidoc_pty.py'])
        self.assertIn('No Ctrl+Shift+F6 acceptance',row['acceptance']['contract'])
    def test_prevdoc_shift_dispatch_and_xterm_map_bound(self):
        row=next(r for r in audit.link_dispatch_contracts(self.routes,self.specs) if r.get('acceptance_id')=='IDE-KEY-PREVDOC-CTRL-SHIFT-F6')
        self.assertEqual(row['condition'],'if hb_bitAnd( hb_keyMod( nKey ), HB_KF_SHIFT ) != 0')
        self.assertEqual(row['acceptance']['tests'],['test_prevdoc_shortcut_pty.py'])
        source=(ROOT/'hbide.prg').read_text()
        self.assertIn('HB_GTI_ADDKEYMAP',source)
        self.assertIn('Chr(27)+"[17;6~"',source)
    def test_ctrl_f2_saveall_route_and_conflict_scope(self):
        row=next(r for r in audit.link_dispatch_contracts(self.routes,self.specs) if r.get('acceptance_id')=='IDE-KEY-SAVEALL-CTRL-F2')
        self.assertEqual(row['condition'],'case HBIDE_KeyIs( nKey, nKeyStd, HB_KX_F2, HB_KF_CTRL, K_CTRL_F2 )')
        self.assertIn('test_saveall_conflict_reload_pty.py',row['acceptance']['tests'])
        self.assertIn('reloaded separately',row['acceptance']['contract'])
    def test_missing_route_fails_closed(self):
        broken={k:dict(v,condition='case nKey == K_NONEXISTENT') for k,v in self.specs.items()}
        with self.assertRaisesRegex(ValueError,'exactly one route'):audit.link_dispatch_contracts(self.routes,broken)
    def test_ambiguous_route_fails_closed(self):
        row=next(r for r in self.routes if r['source']=='designer.prg' and r['condition']=='case nKey == K_F5')
        with self.assertRaisesRegex(ValueError,'exactly one route'):audit.link_dispatch_contracts(self.routes+[row],self.specs)
    def test_missing_test_fails_closed(self):
        broken={k:dict(v,tests=['nonexistent_acceptance_probe.py']) for k,v in self.specs.items()}
        with self.assertRaisesRegex(ValueError,'Missing dispatch test'):audit.link_dispatch_contracts(self.routes,broken)
    def test_duplicate_contract_fails_closed(self):
        broken=dict(self.specs,duplicate=next(iter(self.specs.values())))
        with self.assertRaisesRegex(ValueError,'Duplicate dispatch contract'):audit.link_dispatch_contracts(self.routes,broken)

if __name__=='__main__':unittest.main()

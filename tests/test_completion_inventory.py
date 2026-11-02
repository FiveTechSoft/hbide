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
    def test_start_current_output_contract_link(self):
        entry=json.loads((ROOT/'tests/completion_acceptance.json').read_text())['menus']['IDE-030']
        self.assertIn('test_missing_compiler_pty.py',entry['tests'])
        for phrase in ['same IDE session','exit0 without output','exit7 with output','Synthetic line3','not Cancel']:
            self.assertIn(phrase,entry['contract'])

    def test_compact_method_navigation_link(self):
        entry=json.loads((ROOT/'tests/completion_acceptance.json').read_text())['menus']['IDE-019']
        self.assertIn('test_nav_compact_method_pty.py',entry['tests'])
        self.assertIn('CLASS inside the parameter list',entry['contract'])
        self.assertIn('not full syntax coverage',entry['contract'])

    def test_sole_line_delete_and_cut_links(self):
        menus=json.loads((ROOT/'tests/completion_acceptance.json').read_text())['menus']
        for key in ['IDE-011','IDE-013']:
            self.assertIn('test_delete_only_line_pty.py',menus[key]['tests'])
            self.assertIn('test_delete_only_line.prg',menus[key]['tests'])
            self.assertIn('Empty buffer is a no-op',menus[key]['contract'])
            self.assertIn('test_delete_line_undo_boundary_pty.py',menus[key]['tests'])
            self.assertIn('separate Undo operation',menus[key]['contract'])
            self.assertIn('test_delete_only_line_bp_pty.py',menus[key]['tests'])
            self.assertIn('drops its breakpoint',menus[key]['contract'])

    def test_compiler_mouse_links_keep_untested_switches_separate(self):
        fields=json.loads((ROOT/'tests/completion_acceptance.json').read_text())['ide_modal_field_acceptance']
        self.assertIn('test_compiler_flags_mouse_edges_pty.py',fields['IDE-FIELD-CompilerFlags-cCompiler-1']['tests'])
        self.assertNotIn('test_compiler_flags_mouse_pty.py',fields['IDE-FIELD-CompilerFlags-lStrict-1']['tests'])
        self.assertNotIn('test_compiler_flags_mouse_pty.py',fields['IDE-FIELD-CompilerFlags-lAutoRun-1']['tests'])
        for var in ['lWarnings','lDebug','lIncremental','lOptimize']:
            self.assertIn('test_compiler_flags_mouse_pty.py',fields['IDE-FIELD-CompilerFlags-'+var+'-1']['tests'])

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
        self.assertEqual(len(rows),31)
        self.assertEqual(len({r['id'] for r in rows}),31)
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
    def test_ctrl_t_text_column_contract_linked(self):
        row=next(r for r in audit.link_dispatch_contracts(self.routes,self.specs) if r.get('acceptance_id')=='EDIT-KEY-DELETE-WORD-CTRL-T')
        self.assertEqual(row['condition'],'case nKeyStd == K_CTRL_T')
        self.assertEqual(row['acceptance']['tests'],['test_delete_word_columns.prg','test_delete_word_columns_pty.py'])
        self.assertIn('not four-cell gutter',row['acceptance']['contract'])
        self.assertIn('not all selection states',row['acceptance']['contract'])
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
        self.assertEqual(len(linked),18)
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
    def test_alt_diagnostic_routes_are_exact_and_bounded(self):
        linked={r['acceptance_id']:r for r in audit.link_dispatch_contracts(self.routes,self.specs) if 'acceptance_id' in r}
        for key,action in [('F8','NEXT'),('F7','PREVIOUS')]:
            row=linked['IDE-KEY-'+action+'-MESSAGE-ALT-'+key]
            self.assertEqual(row['source'],'hbide.prg')
            self.assertEqual(row['condition'],f'case HBIDE_KeyIs( nKey, nKeyStd, HB_KX_{key}, HB_KF_ALT, K_ALT_{key} )')
            self.assertIn('test_nav_pty.py',row['acceptance']['tests'])
            self.assertIn('parent menu-closed guard remains separate',row['acceptance']['contract'])
            self.assertIn('Not all diagnostic kinds/files',row['acceptance']['contract'])
        self.assertIn('test_message_selection_pty.py',linked['IDE-KEY-NEXT-MESSAGE-ALT-F8']['acceptance']['tests'])

    def test_alt_zero_windowlist_route_bounded(self):
        row=next(r for r in audit.link_dispatch_contracts(self.routes,self.specs) if r.get('acceptance_id')=='IDE-KEY-WINDOWLIST-ALT-0')
        self.assertEqual(row['source'],'hbide.prg')
        self.assertEqual(row['condition'],'case nKeyStd == K_ALT_0')
        self.assertEqual(row['acceptance']['tests'],['test_nav_pty.py','test_multidoc_pty.py'])
        self.assertIn('Parent menu-closed guard remains separate',row['acceptance']['contract'])
        self.assertIn('not all filter inputs/empty or huge lists',row['acceptance']['contract'])

    def test_f1_context_help_route_has_no_invented_menu_guard(self):
        row=next(r for r in audit.link_dispatch_contracts(self.routes,self.specs) if r.get('acceptance_id')=='IDE-KEY-CONTEXTHELP-F1')
        self.assertEqual(row['condition'],'if nKeyStd == K_F1')
        self.assertEqual(row['acceptance']['tests'],['test_help_pty.py'])
        self.assertIn('F1 intentionally handles open menus',row['acceptance']['contract'])
        self.assertIn('not all menu commands',row['acceptance']['contract'])

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


class InspectorInventory(unittest.TestCase):
    def setUp(self):
        self.rows=audit.inspector_fields()
        self.specs=json.loads((ROOT/'tests/completion_acceptance.json').read_text())['inspector_field_acceptance']
    def test_exact_guard_expansion(self):
        from collections import Counter
        self.assertEqual(Counter(r['control'] for r in self.rows),dict(say=3,get=6,button=9,checkbox=8,radiogroup=7,listbox=10,combobox=10,dialog=7))
        self.assertEqual(len({r['id'] for r in self.rows}),60)
        keys=lambda c:{r['key'] for r in self.rows if r['control']==c}
        self.assertNotIn('focus',keys('get'))
        self.assertNotIn('state',keys('radiogroup'))
        self.assertEqual(keys('say'),{'row','col','caption'})
        self.assertEqual(keys('dialog'),{'dlgname','dlgcaption','dlgwidth','dlgheight','dlgback','dlgtext','dlgfocus'})
    def test_source_lines_and_determinism(self):
        lines=(ROOT/'designer.prg').read_text().splitlines()
        for r in self.rows:
            self.assertIn('"'+r['key']+'"',lines[r['line']-1])
        self.assertEqual(self.rows,audit.inspector_fields())
    def test_bound_links_do_not_certify_execution(self):
        rows=audit.link_inspector_contracts(self.rows,self.specs)
        self.assertEqual(len(rows),60)
        for r in rows:
            self.assertEqual(r['key'],r['acceptance']['key'])
            self.assertIn('Link is not current runtime PASS',r['acceptance']['contract'])
            self.assertIn('No handler execution',r['acceptance']['contract'])
        self.assertEqual(next(r for r in rows if r['id']=='DSN-INSP-dialog-dlgfocus')['acceptance']['tests'],['test_designer_dialog_colors_pty.py'])
    def test_unknown_identity_rejected(self):
        with self.assertRaisesRegex(ValueError,'Unknown inspector acceptance'):
            audit.link_inspector_contracts(self.rows,{'DSN-INSP-get-focus':next(iter(self.specs.values()))})
    def test_wrong_kind_or_control_rejected(self):
        for key,value in [('kind','color'),('control','say'),('key','action')]:
            with self.subTest(key=key),self.assertRaisesRegex(ValueError,'Inspector acceptance mismatch'):
                audit.link_inspector_contracts(self.rows,{'DSN-INSP-get-row':dict(self.specs['DSN-INSP-get-row'],**{key:value})})
    def test_missing_test_rejected_and_unlinked_stays_pending(self):
        with self.assertRaisesRegex(ValueError,'Missing inspector test'):
            audit.link_inspector_contracts(self.rows,{'DSN-INSP-get-row':dict(self.specs['DSN-INSP-get-row'],tests=['missing-inspector.py'])})
        self.assertTrue(all(r['acceptance'] is None for r in audit.link_inspector_contracts(self.rows,{})))

    def test_runtime_links_separate_from_persistence(self):
        rows=audit.link_inspector_contracts(self.rows,self.specs)
        linked=[r for r in rows if r['acceptance'].get('runtime')]
        self.assertEqual(len(linked),21) # 20 event pairs plus ButtonAction.
        for r in linked:
            self.assertEqual(r['key'],r['acceptance']['runtime']['key'])
            self.assertIn('Link is not current runtime PASS',r['acceptance']['runtime']['contract'])
        self.assertIn('not veto before Action',self.specs['DSN-INSP-button-valid']['runtime']['contract'])
    def test_when_extended_contracts_keep_runtime_separate(self):
        for kind in ['get','radiogroup','checkbox','listbox','combobox','button']:
            entry=self.specs['DSN-INSP-'+kind+'-when']
            self.assertIn('No handler execution',entry['contract'])
            self.assertIn('test_designer_inline_when_reenable_runtime_pty.py',entry['runtime']['tests'])
            self.assertIn('not all30pairs',entry['runtime']['contract'])
            self.assertIn('No arbitrary reactivation',entry['runtime']['contract'])
        self.assertIn('not Action activation',self.specs['DSN-INSP-button-when']['runtime']['contract'])

    def test_runtime_wrong_identity_rejected(self):
        entry=self.specs['DSN-INSP-get-valid']
        with self.assertRaisesRegex(ValueError,'runtime identity mismatch'):
            audit.link_inspector_contracts(self.rows,{'DSN-INSP-get-valid':dict(entry,runtime=dict(entry['runtime'],control='button'))})
    def test_runtime_non_event_and_missing_test_rejected(self):
        runtime=self.specs['DSN-INSP-get-valid']['runtime']
        with self.assertRaisesRegex(ValueError,'Not an inspector runtime event'):
            audit.link_inspector_contracts(self.rows,{'DSN-INSP-get-row':dict(self.specs['DSN-INSP-get-row'],runtime=runtime)})
        entry=self.specs['DSN-INSP-get-valid']
        with self.assertRaisesRegex(ValueError,'Missing inspector runtime test'):
            audit.link_inspector_contracts(self.rows,{'DSN-INSP-get-valid':dict(entry,runtime=dict(runtime,tests=['missing-runtime.py']))})

class RecentBoundaryContracts(unittest.TestCase):
    def test_exact_editor_boundary_route_bindings(self):
        specs=json.loads((ROOT/'tests/completion_acceptance.json').read_text())
        _,routes=audit.inventory()
        linked=audit.link_dispatch_contracts(routes,specs['dispatch_acceptance'])
        ids=['EDIT-MOUSE-WORD-DOUBLECLICK','EDIT-MOUSE-POSITION-CLICK','EDIT-KEY-ENTER-BOUNDARY','EDIT-KEY-BACKSPACE-BOUNDARY','EDIT-KEY-DELETE-BOUNDARY']
        for ident in ids:
            row=next(r for r in linked if r.get('acceptance_id')==ident)
            self.assertEqual(row['source'],'editor.prg')
            self.assertEqual(row['context'],'METHOD EditKey(')
            self.assertIn('not current runtime PASS',row['acceptance']['contract'])
    def test_standard_stream_and_class_navigation_links(self):
        row=json.loads((ROOT/'tests/completion_acceptance.json').read_text())['menus']['IDE-019']
        for name in ['test_nav_raw_bom_pty.py','test_nav_declared_contexts.py','test_nav_end_class_contexts.py','test_nav_text_contexts.py']:
            self.assertIn(name,row['tests'])
        for text in ['at least four letters','exact ENDTEXT','not current runtime PASS']:
            self.assertIn(text,row['contract'])

class GestureContractLinks(unittest.TestCase):
    def setUp(self):
        self.rows=audit.mouse_routes()
        self.specs=json.loads((ROOT/'tests/completion_acceptance.json').read_text())['mouse_acceptance']
    def test_31_branches_with_30_links_not_exhaustive_gesture_acceptance(self):
        linked=audit.link_dispatch_contracts(self.rows,self.specs)
        self.assertEqual(len(linked),31)
        selected=[r for r in linked if isinstance(r['acceptance'],dict)]
        self.assertEqual(len(selected),30)
        self.assertEqual({r['condition'] for r in selected},{'if ( nKeyStd == K_LBUTTONDOWN .or. nKeyStd == K_LDBLCLK ) .and. ; ( MRow() < ::nTop .or. MRow() > ::nBottom .or. ; MCol() < ::nLeft .or. MCol() > ::nRight )','case nMouse == K_LBUTTONDOWN','if nMouse == K_LBUTTONDOWN .or. nMouse == K_LBUTTONUP .or. nMouse == K_LDBLCLK','case nKey == K_LBUTTONUP','case K_MWFORWARD','case K_MWBACKWARD','if nKeyStd == K_LBUTTONDOWN','case nKeyStd == K_LDBLCLK','case nKeyStd == K_LBUTTONDOWN','case nKey == K_LBUTTONDOWN','CASE nKey == K_LBUTTONDOWN .OR. nKey == K_LDBLCLK','IF nKey == K_LDBLCLK','case nCode == DSNK_MLDOWN','case nCode == DSNK_MLDBL','case nCode == DSNK_MLUP','IF LastKey() == K_LBUTTONDOWN','CASE K_LBUTTONDOWN','CASE K_LDBLCLK','CASE K_RBUTTONDOWN','CASE nKey == K_UP .OR. nKey == K_MWFORWARD','CASE nKey == K_DOWN .OR. nKey == K_MWBACKWARD','case nKeyStd == K_MWFORWARD','case nKeyStd == K_MWBACKWARD','elseif nKeyStd == K_MWFORWARD .or. nKeyStd == K_MWBACKWARD','CASE nKey == K_MWFORWARD','CASE nKey == K_MWBACKWARD','CASE nKey == K_LBUTTONDOWN','CASE nKey == K_LBUTTONDOWN .AND. MRow() >= nLinkRow .AND. MRow() < nLinkRow + Len( aLinks ) .AND. MCol() > nL .AND. MCol() < nR'})
        for row in selected:
            self.assertIn(row['context'],['METHOD EditKey( nKey ) CLASS HBSrcEdit','METHOD Activate() CLASS HbDesigner','FUNCTION HBIDEProjectDesktop( oProject, cHbmk2 )','FUNCTION HBHelpInput( h, aTopics, g, nKey )','FUNCTION HBIDEHelpOpen( cTitle, aTopics )','METHOD Activate() CLASS HBIde','METHOD PROCEDURE HandleEvent() CLASS HBDebugger','METHOD PROCEDURE CallStackProcessKey( nKey ) CLASS HBDebugger','METHOD PROCEDURE ShowModal() CLASS HBDbWindow','METHOD DsnMouseRoute( nKey, oWnd, oGet ) CLASS HbWindow','METHOD PROCEDURE ShowAppScreen() CLASS HBDebugger','static function HBIDE_IsNavKey( nKey )','static function HBIDE_DlgInput( nRow, nCol, nWidth, cInit, cColor, aButtons )'])
            self.assertIn('not current runtime PASS',row['acceptance']['contract'])
            self.assertIn('Event branch is not a unique feature',row['acceptance']['contract'])
        self.assertTrue(all(isinstance(r['acceptance'],str) for r in self.rows))
    def test_wrong_context_rejected(self):
        ident=next(iter(self.specs));spec=dict(self.specs[ident],context='METHOD Other(')
        with self.assertRaisesRegex(ValueError,'exactly one route'):
            audit.link_dispatch_contracts(self.rows,{ident:spec})
    def test_duplicate_and_missing_test_rejected(self):
        ident=next(iter(self.specs));spec=self.specs[ident]
        with self.assertRaisesRegex(ValueError,'Duplicate dispatch contract'):
            audit.link_dispatch_contracts(self.rows,{ident:spec,'duplicate':spec})
        with self.assertRaisesRegex(ValueError,'Missing dispatch test'):
            audit.link_dispatch_contracts(self.rows,{ident:dict(spec,tests=['missing-gesture.py'])})

if __name__=='__main__':unittest.main()

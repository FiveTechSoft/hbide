#!/usr/bin/env python3
"""Run fresh-source Linux PTY suites with source/binary identity and durable logs.
Not visual or Windows certification. Never mixes runs into one completion rate.
"""
import argparse, hashlib, json, os, pathlib, signal, shutil, subprocess, sys, tempfile, time
ROOT = pathlib.Path(__file__).resolve().parents[1]
# Generous ceilings include each harness's fixed waits, builds and nested suites.
CASES = {
    'saveas-overwrite-accept': ('test_saveas_overwrite_accept_pty.py', [], 30),
    'saveas-overwrite-cancel': ('test_saveas_overwrite_cancel_pty.py', ['--dirty'], 30),
    'saveall-conflict-reload': ('test_saveall_conflict_reload_pty.py', [], 30),
    'saveall-conflict-cancel': ('test_saveall_conflict_cancel_pty.py', [], 30),
    'saveas-failure-crash': ('test_saveas_failure_identity_pty.py', ['--crash'], 40),
    'saveas-failure-clean': ('test_saveas_failure_identity_pty.py', [], 30),
    'saveas-failure-dirty': ('test_saveas_failure_identity_pty.py', ['--dirty'], 30),
    'debug-auto-source-read': ('test_debug_auto_source_read_pty.py', [], 60),
    'debug-source-read': ('test_debug_source_read_pty.py', [], 30),
    'project-output-scroll': ('test_project_output_pty.py', [], 30),
    'debug-source-path': ('test_debug_path_cancel_pty.py', [], 30),
    'backup-f2': ('test_backup_pty.py', [], 30),
    'debug-source-partial': ('test_debug_module_failure_pty.py', ['source'], 30),
    'debug-compile-cleanup': ('test_debug_module_failure_pty.py', ['compile'], 30),
    'debug-module-failure': ('test_debug_module_failure_pty.py', [], 30),
    'debug-temp-failure': ('test_debug_temp_failure_pty.py', [], 30),
    'debug-script-lookup': ('test_debug_script_lookup_pty.py', [], 30),
    'start-open-document-collision': ('test_start_collision_pty.py', ['--other-document'], 30),
    'start-source-collision-relative': ('test_start_collision_pty.py', ['--relative'], 30),
    'start-source-collision': ('test_start_collision_pty.py', [], 30),
    'project-leading-source': ('test_project_leading_pty.py', [], 30),
    'debug-script-read': ('test_debug_script_read_pty.py', [], 30),
    'project-unreadable': ('test_open_unreadable_pty.py', ['--project'], 30),
    'start-target-space': ('test_recovery_unreadable_pty.py', ['--start-target-space'], 30),
    'recovery-invalid-target': ('test_recovery_unreadable_pty.py', ['--invalid-target'], 30),
    'recovery-invalid-flags': ('test_recovery_unreadable_pty.py', ['--invalid-flags'], 30),
    'recovery-compare-large': ('test_recovery_compare_pty.py', ['--large'], 30),
    'recovery-compare': ('test_recovery_compare_pty.py', [], 30),
    'reload-unreadable': ('test_reload_unreadable_pty.py', [], 30),
    'open-unreadable': ('test_open_unreadable_pty.py', [], 30),
    'recovery-target-space': ('test_recovery_unreadable_pty.py', ['--target-space'], 30),
    'recovery-unknown-codepage': ('test_recovery_unreadable_pty.py', ['--unknown-codepage'], 30),
    'recovery-malformed': ('test_recovery_unreadable_pty.py', ['--malformed-envelope'], 30),
    'recovery-unreadable': ('test_recovery_unreadable_pty.py', [], 30),
    'external-changes': ('test_external_changes_pty.py', [], 60),
    'close-routes': ('test_close_routes_pty.py', [], 120),
    'file-modal-long-list': ('test_file_modal_long_list_pty.py', [], 120),
    'file-modal-mouse': ('test_file_modal_mouse_pty.py', [], 120),
    'file-modal-buttons': ('test_file_modal_buttons_pty.py', [], 120),
    'about-build': ('test_about_build_pty.py', [], 120),
    'help-mouse': ('test_help_mouse_pty.py', [], 120),
    'help': ('test_help_pty.py', [], 120),
    'display-multidoc': ('test_display_multidoc_pty.py', [], 120),
    'compiler-autorun': ('test_compiler_autorun_pty.py', [], 120),
    'compiler-flags': ('test_compiler_flags_pty.py', [], 120),
    'run-arguments-modal': ('test_run_arguments_modal_pty.py', [], 120),
    'run-empty-args': ('test_run_empty_args_pty.py', [], 120),
    'script-screen': ('test_script_screen_pty.py', [], 120),
    'source-includes': ('test_source_includes_pty.py', [], 120),
    'script-errors': ('test_script_errors_pty.py', [], 120),
    'start-paths': ('test_start_paths_pty.py', [], 120),
    'run-source': ('test_run_source_pty.py', [], 120),
    'gui-roundtrip': ('test_gui_roundtrip_pty.py', [], 120),
    'combobox': ('test_combobox_pty.py', [], 120),
    'designer-clipboard-case': ('test_designer_clipboard_pty.py', ['--case-insensitive'], 120),
    'designer-clipboard-combo-runtime': ('test_designer_clipboard_combo_runtime_pty.py', [], 120),
    'designer-clipboard-get-runtime': ('test_designer_clipboard_get_runtime_pty.py', [], 120),
    'designer-clipboard-runtime': ('test_designer_clipboard_runtime_pty.py', [], 120),
    'designer-clipboard-popup-types': ('test_designer_clipboard_loaded_types_pty.py', ['--popup'], 120),
    'designer-clipboard-created-types': ('test_designer_clipboard_loaded_types_pty.py', ['--create'], 120),
    'designer-clipboard-loaded-types': ('test_designer_clipboard_loaded_types_pty.py', [], 120),
    'designer-clipboard': ('test_designer_clipboard_pty.py', [], 120),
    'designer': ('test_designer_pty.py', [], 120),
    'editor-mouse-utf8-terminal': ('test_editor_mouse_utf8_pty.py', ['--utf8-terminal'], 120),
    'editor-mouse-utf8': ('test_editor_mouse_utf8_pty.py', [], 120),
    'editor-mouse': ('test_editor_mouse_pty.py', [], 120),
    'edit-menu': ('test_edit_menu_pty.py', [], 120),
    'navigation': ('test_nav_pty.py', [], 180),
    'multidoc': ('test_multidoc_pty.py', [], 180),
    'project-desktop': ('test_project_desktop_pty.py', [], 180),
    'project-mouse': ('test_project_mouse_pty.py', [], 120),
    'project-messages': ('test_project_messages_pty.py', [], 180),
    'saveall-failure': ('test_saveall_fail_pty.py', [], 120),
    'saveas-recovery': ('test_saveas_refusal_recovery_pty.py', ['hbide'], 120),
    'breakpoint-delete': ('test_bp_delete_policy.py', ['hbide'], 120),
    'recovery-multi': ('test_recovery_multi.py', ['hbide'], 180),
    'recovery-retention': ('test_recovery_retention.py', ['hbide'], 180),
    'recovery-deep-path': ('test_recovery_deep_path.py', ['hbide'], 180),
    'recovery-utf8-host': ('test_recovery_deep_path.py', ['hbide', '--utf8-host'], 180),
    'recovery-utf8-raw': ('test_recovery_deep_path.py', ['hbide', '--utf8-raw'], 180),
    'recovery-codepage-refusal': ('test_recovery_deep_path.py', ['hbide', '--refuse-cp'], 180),
    'recovery-codepage': ('test_recovery_deep_path.py', ['hbide', '--utf8-bom', '--switch-cp'], 180),
    'recovery-utf8-bom': ('test_recovery_deep_path.py', ['hbide', '--utf8-bom'], 180),
    'recovery-tabs': ('test_recovery_deep_path.py', ['hbide', '--tabs'], 180),
    'recovery-mixed-eol': ('test_recovery_deep_path.py', ['hbide', '--mixed-eol'], 180),
    'recovery-crlf': ('test_recovery_deep_path.py', ['hbide', '--crlf'], 180),
    'recovery-route-guard': ('test_recovery_route_guard.py', [], 30),
    'debug-missing-source': ('test_debug_missing_source_pty.py', [], 60),
    'debug-restored-points': ('test_debug_restored_points_pty.py', [], 120),
    'debug-bp-modal': ('test_debug_bp_modal_pty.py', [], 120),
    'debug-color-set-modal': ('test_debug_color_set_modal_pty.py', [], 120),
    'debug-input-paths-modal': ('test_debug_input_paths_modal_pty.py', [], 120),
    'debug-watch-modal': ('test_debug_watch_modal_pty.py', [], 120),
    'debug-setter-failure': ('test_debug_setter_failure_pty.py', [], 120),
    'debug-getter-failure': ('test_debug_getter_failure_pty.py', [], 120),
    'debug-method-only-object': ('test_debug_method_only_object_pty.py', [], 120),
    'debug-long-object-member': ('test_debug_long_object_member_pty.py', [], 120),
    'debug-long-array-path': ('test_debug_long_hash_key_pty.py', ['--array-child'], 120),
    'debug-long-hash-key': ('test_debug_long_hash_key_pty.py', [], 120),
    'debug-object-empty-child': ('test_debug_object_empty_child_pty.py', [], 120),
    'debug-hash-navigation': ('test_debug_hash_navigation_pty.py', [], 120),
    'debug-array-navigation': ('test_debug_hash_navigation_pty.py', ['--array'], 120),
    'debug-object-type-change': ('test_debug_object_type_change_pty.py', [], 120),
    'debug-empty-structures': ('test_debug_empty_structures_pty.py', [], 120),
    'debug-readonly-depth': ('test_debug_readonly_depth_pty.py', [], 120),
    'debug-structured-depth': ('test_debug_structured_depth_pty.py', [], 120),
    'debug-structured-modal': ('test_debug_structured_modal_pty.py', [], 120),
    'debug-monitor-mouse-scroll': ('test_debug_monitor_mouse_scroll_pty.py', [], 120),
    'debug-stack-mouse': ('test_debug_stack_mouse_pty.py', [], 120),
    'debug-mouse': ('test_debug_mouse_pty.py', [], 120),
    'debug-value-modal': ('test_debug_value_modal_pty.py', [], 120),
    'debug-numeric-modal': ('test_debug_numeric_modal_pty.py', [], 120),
    'debug-commands': ('test_debug_commands_pty.py', [], 120),
    'debug-functions': ('test_debug_functions_pty.py', [], 180),
    'debug-functions-idle': ('test_debug_functions_pty.py', ['--idle-settle'], 120),
    'debug-session': ('test_debug_session_pty.py', [], 120),
    'debug-startup': ('test_debug_startup_pty.py', [], 120),
    'debug-monitor': ('test_debug_monitor_pty.py', [], 120),
    'debug-callstack': ('test_debug_callstack_pty.py', [], 120),
    'debug-codeblock': ('test_debug_codeblock_pty.py', [], 120),
    'debug-animate': ('test_debug_animate_pty.py', [], 120),
    # Pure parser import: Commands is a separate explicit case.
    'debug-exits': ('test_debug_exit_paths_pty.py', [], 180),
}
def source_snapshot():
    paths = subprocess.check_output(['git','ls-files','-z'], cwd=ROOT).decode().split('\0')
    h = hashlib.sha256()
    for rel in sorted(p for p in paths if p):
        path = ROOT / rel
        h.update(rel.encode() + b'\0')
        h.update(path.read_bytes() if path.is_file() else b'<missing>')
        h.update(b'\0')
    untracked = subprocess.check_output(['git','ls-files','--others','--exclude-standard','-z'], cwd=ROOT).decode().split('\0')
    extra = hashlib.sha256()
    for rel in sorted(p for p in untracked if p and pathlib.Path(p).suffix.lower() in ('.prg','.ch','.c','.h','.hbp','.hbc','.hbm','.py')):
        extra.update(rel.encode()+b'\0'+(ROOT/rel).read_bytes()+b'\0')
    return dict(untracked_inputs_sha256=extra.hexdigest(), source=subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip(),
                tracked_changes=subprocess.check_output(['git','status','--porcelain','--untracked-files=no'], cwd=ROOT, text=True),
                tracked_snapshot_sha256=h.hexdigest())

def validate_receipt(receipt, state, binary_hash):
    for key in ('source','tracked_changes','tracked_snapshot_sha256','untracked_inputs_sha256'):
        if receipt.get(key) != state[key]:
            raise ValueError('build receipt does not match current '+key+'; rebuild')
    if receipt.get('binary_sha256') != binary_hash:
        raise ValueError('build receipt does not match binary hash; rebuild')

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--case', action='append', choices=CASES)
    p.add_argument('--list', action='store_true')
    p.add_argument('--output', type=pathlib.Path)
    p.add_argument('--reuse-build', action='store_true', help='use an already verified current-source binary; default rebuilds')
    p.add_argument('--build-receipt', type=pathlib.Path, help='reuse receipt from a previous fresh run; default OUTPUT/build-identity.json')
    a = p.parse_args()
    if a.list:
        for name, (script, args, ceiling) in CASES.items():
            print(name, script, ' '.join(args), 'ceiling='+str(ceiling))
        return 0
    binary = ROOT / 'hbide'
    out = a.output or pathlib.Path(tempfile.mkdtemp(prefix='hbide-pty-'))
    out.mkdir(parents=True, exist_ok=True)
    # Local harnesses are now path-relative, but older ones still set their
    # own toolchain. Keep the caller's PATH authoritative.
    before_build = source_snapshot()
    receipt_path = a.build_receipt or out/'build-identity.json'
    if not a.reuse_build:
        compiler = shutil.which('hbmk2')
        if not compiler:
            p.error('hbmk2 must be on PATH for a fresh build')
        with (out/'build.log').open('w') as log:
            code = subprocess.run([compiler, 'hbide.hbp', '-quiet'], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT).returncode
        if code:
            p.error('fresh build failed: '+str(out/'build.log'))
    if not binary.is_file():
        p.error('hbide binary missing')
    state = source_snapshot()
    binary_hash = hashlib.sha256(binary.read_bytes()).hexdigest()
    if a.reuse_build:
        try:
            receipt = json.loads(receipt_path.read_text())
            validate_receipt(receipt, state, binary_hash)
        except (OSError, ValueError, KeyError) as e:
            p.error('unverified reuse: '+str(e))
    else:
        if state != before_build:
            p.error('source changed during build; no receipt issued')
        receipt = dict(**state, binary_sha256=binary_hash, built_at=time.time())
        receipt_path.write_text(json.dumps(receipt, indent=2)+'\n')
    source, dirty = state['source'], state['tracked_changes']
    identity = dict(**state, binary_sha256=binary_hash, build_receipt=str(receipt_path),
                    platform=sys.platform, build='reused_verified' if a.reuse_build else 'fresh', scope='Linux PTY only; not full visual/Windows acceptance')
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1', HBIDE_BIN=str(binary))
    identity['runner_sha256'] = hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest()
    failed = False
    for name in a.case or CASES:
        script, args, ceiling = CASES[name]
        argv = [sys.executable, '-u', str(ROOT/'tests'/script), *args]
        logpath = out / (name+'-'+str(time.time_ns())+'.log')
        start = time.time()
        with logpath.open('w') as log:
            proc = subprocess.Popen(argv, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
            try:
                code = proc.wait(timeout=ceiling)
            except subprocess.TimeoutExpired:
                # pty.fork starts its own session, so process-group kill alone
                # misses the child IDE. Snapshot descendants before killing.
                descendants = {proc.pid}
                for _ in range(8):
                    old = len(descendants)
                    for stat in pathlib.Path('/proc').glob('[0-9]*/stat'):
                        try:
                            data = stat.read_text().rsplit(')',1)[1].split()
                            if int(data[1]) in descendants:
                                descendants.add(int(stat.parent.name))
                        except (OSError, ValueError, IndexError):
                            pass
                    if len(descendants) == old:
                        break
                for pid in sorted(descendants, reverse=True):
                    try: os.kill(pid, signal.SIGKILL)
                    except ProcessLookupError: pass
                proc.wait(); code = 124
                log.write('\nRUNNER TIMEOUT: outcome unverified, not a product failure diagnosis\n')
        text = logpath.read_text(errors='replace')
        printed_fail = any(line.startswith(('FAIL ', 'FAIL:', 'FAILED:')) for line in text.splitlines())
        end_source = subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip()
        end_dirty = subprocess.check_output(['git','status','--porcelain','--untracked-files=no'], cwd=ROOT, text=True)
        changed = source_snapshot() != state or end_source != source or end_dirty != dirty or hashlib.sha256(binary.read_bytes()).hexdigest() != identity['binary_sha256']
        result = dict(**identity, case=name, command=argv, started=start, seconds=round(time.time()-start,2),
                      exit_code=code, printed_failure=printed_fail, source_or_binary_changed=changed,
                      test_sha256=hashlib.sha256((ROOT/'tests'/script).read_bytes()).hexdigest(), log=str(logpath))
        with (out/'results.jsonl').open('a') as ledger:
            ledger.write(json.dumps(result)+'\n')
        print(json.dumps(result), flush=True)
        failed |= code != 0 or printed_fail or changed
        if code == 124:
            print('Stop after timeout: inspect the harness and its child IDE before continuing.', file=sys.stderr)
            break
    print('Ledger:', out/'results.jsonl')
    return int(failed)
if __name__ == '__main__':
    sys.exit(main())

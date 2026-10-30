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
    'file-modal-buttons': ('test_file_modal_buttons_pty.py', [], 120),
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
    'designer': ('test_designer_pty.py', [], 120),
    'edit-menu': ('test_edit_menu_pty.py', [], 120),
    'navigation': ('test_nav_pty.py', [], 180),
    'multidoc': ('test_multidoc_pty.py', [], 180),
    'project-desktop': ('test_project_desktop_pty.py', [], 180),
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
    'debug-structured-modal': ('test_debug_structured_modal_pty.py', [], 120),
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
def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--case', action='append', choices=CASES)
    p.add_argument('--list', action='store_true')
    p.add_argument('--output', type=pathlib.Path)
    p.add_argument('--reuse-build', action='store_true', help='use an already verified current-source binary; default rebuilds')
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
    source = subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip()
    dirty = subprocess.check_output(['git','status','--porcelain','--untracked-files=no'], cwd=ROOT, text=True)
    identity = dict(source=source, tracked_changes=dirty, binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
                    platform=sys.platform, build='reused_explicitly' if a.reuse_build else 'fresh', scope='Linux PTY only; not full visual/Windows acceptance')
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
        changed = end_source != source or end_dirty != dirty or hashlib.sha256(binary.read_bytes()).hexdigest() != identity['binary_sha256']
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

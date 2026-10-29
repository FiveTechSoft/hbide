#!/usr/bin/env python3
"""Run fresh-source Linux PTY suites with source/binary identity and durable logs.
Not visual or Windows certification. Never mixes runs into one completion rate.
"""
import argparse, hashlib, json, os, pathlib, signal, shutil, subprocess, sys, tempfile, time
ROOT = pathlib.Path(__file__).resolve().parents[1]
# Generous ceilings include each harness's fixed waits, builds and nested suites.
CASES = {
    'designer': ('test_designer_pty.py', [], 120),
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
    'debug-commands': ('test_debug_commands_pty.py', [], 120),
    'debug-functions': ('test_debug_functions_pty.py', [], 180),
    'debug-session': ('test_debug_session_pty.py', [], 120),
    'debug-startup': ('test_debug_startup_pty.py', [], 120),
    'debug-monitor': ('test_debug_monitor_pty.py', [], 120),
    'debug-callstack': ('test_debug_callstack_pty.py', [], 120),
    'debug-codeblock': ('test_debug_codeblock_pty.py', [], 120),
    'debug-animate': ('test_debug_animate_pty.py', [], 120),
    # This harness imports/runs debug-commands before its own exit cases.
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

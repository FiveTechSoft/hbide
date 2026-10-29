#!/usr/bin/env python3
"""Build fresh Linux acceptance probes. Not a complete IDE certification.
Run from anywhere with hbmk2 on PATH. Results live outside the checkout.
"""
import hashlib, json, os, pathlib, shutil, subprocess, tempfile, time
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = pathlib.Path(tempfile.mkdtemp(prefix='hbide-completion-'))
HBMK = shutil.which('hbmk2')
if not HBMK:
    raise SystemExit('hbmk2 is required on PATH')

def run(name, args, cwd=ROOT, timeout=120):
    with (OUT / (name + '.log')).open('w') as log:
        try:
            p = subprocess.run(args, cwd=cwd, stdout=log, stderr=subprocess.STDOUT,
                               timeout=timeout)
            return p.returncode
        except subprocess.TimeoutExpired:
            log.write('\nTIMEOUT\n')
            return 124

cases = {
    'designer': ['tests/test_designer.prg', 'designer.prg', 'hbwindow.prg', 'hbmenu.prg', 'hbbutton.prg', 'hbgetu.prg'],
    'editor-repaint': ['tests/test_editor_repaint.prg', 'editor.prg', 'recovery.prg'],
    'find': ['tests/test_editor_find.prg', 'editor.prg', 'recovery.prg'],
    'eol': ['tests/test_editor_eol.prg', 'editor.prg', 'recovery.prg'],
    'utf8': ['tests/test_utf8_valid.prg', 'editor.prg', 'recovery.prg'],
    'atomic': ['tests/test_atomic.prg', 'editor.prg', 'recovery.prg'],
    'recovery': ['tests/test_recovery.prg', 'recovery.prg'],
    'project': ['tests/test_project.prg', 'project.prg'],
    'help': ['tests/test_help.prg', 'help.prg', 'hbwindow.prg', 'hbmenu.prg', 'hbbutton.prg', 'hbgetu.prg'],
}
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def source_state():
    return (subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
            subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=no'], cwd=ROOT, text=True))

initial_source, initial_changes = source_state()
report = {'source': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
          'dirty': bool(initial_changes), 'tracked_changes': initial_changes,
          'runner_sha256': digest(pathlib.Path(__file__)),
          'platform': os.uname().sysname, 'hbmk2': HBMK, 'started': time.time(),
          'scope': 'Linux model probes only. Not PTY, visual or Windows certification.', 'tests': {}}
for name, sources in cases.items():
    exe = OUT / name
    hashes = {path: digest(ROOT / path) for path in sources}
    started = time.time()
    build = run(name + '-build', [HBMK, *sources, '-gtstd', '-quiet', '-o' + str(exe)])
    rc = None if build else run(name, [str(exe)] + ([HBMK] if name == 'project' else []),
                                ROOT if name == 'help' else OUT)
    text = (OUT / (name + '.log')).read_text(errors='replace') if rc is not None else ''
    # Legacy atomic probe prints failures but does not set a failing exit code.
    semantic_failure = ('FAILURES PRESENT' in text or 'FAIL:' in text or 'FAILED: 1' in text)
    changed = source_state() != (initial_source, initial_changes) or any(digest(ROOT / path) != value for path, value in hashes.items())
    report['tests'][name] = {'build_exit': build, 'run_exit': rc, 'reported_failure': semantic_failure,
        'source_or_test_changed': changed, 'source_sha256': hashes,
        'binary_sha256': digest(exe) if exe.is_file() else None, 'started': started, 'seconds': time.time() - started}
report['finished'] = time.time()
(OUT / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
print('Logs:', OUT)
raise SystemExit(int(any(v['build_exit'] or v['run_exit'] or v['reported_failure'] or v['source_or_test_changed'] for v in report['tests'].values())))

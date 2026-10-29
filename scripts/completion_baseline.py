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
    'atomic': ['tests/test_atomic.prg', 'editor.prg', 'recovery.prg'],
    'recovery': ['tests/test_recovery.prg', 'recovery.prg'],
    'project': ['tests/test_project.prg', 'project.prg'],
    'help': ['tests/test_help.prg', 'help.prg', 'hbwindow.prg', 'hbmenu.prg', 'hbbutton.prg', 'hbgetu.prg'],
}
report = {'source': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
          'dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT)),
          'platform': os.uname().sysname, 'hbmk2': HBMK, 'started': time.time(),
          'scope': 'Linux model probes only. Not PTY, visual or Windows certification.', 'tests': {}}
for name, sources in cases.items():
    exe = OUT / name
    build = run(name + '-build', [HBMK, *sources, '-gtstd', '-quiet', '-o' + str(exe)])
    rc = None if build else run(name, [str(exe)] + ([HBMK] if name == 'project' else []),
                                ROOT if name == 'help' else OUT)
    report['tests'][name] = {'build_exit': build, 'run_exit': rc}
report['finished'] = time.time()
(OUT / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
print('Logs:', OUT)
raise SystemExit(int(any(v['build_exit'] or v['run_exit'] for v in report['tests'].values())))

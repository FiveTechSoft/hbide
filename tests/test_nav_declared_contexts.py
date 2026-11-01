"""Compiler-validated context variants of the actual IDE picker test."""
import json, os, pathlib, subprocess, tempfile
root = pathlib.Path(__file__).resolve().parents[1]
work = pathlib.Path(tempfile.mkdtemp(prefix='hbide-nav-declared-'))
compiler = os.environ.get('HBMK2', 'hbmk2')
cases = {
    'function': ('CLASS Demo\nMETHOD Ping()\nENDCLASS\nDECLARED METHOD FUNCTION Ping() CLASS Demo\nreturn 42\n', 2, 'DECLARED METHOD FUNCTION Ping() CLASS Demo'),
    'procedure': ('CLASS Demo\nMETHOD Ping()\nENDCLASS\nDECLARED METHOD PROCEDURE Ping() CLASS Demo\nreturn\n', 2, 'DECLARED METHOD PROCEDURE Ping() CLASS Demo'),
    'compact': ('CLASS Demo\nMETHOD Ping()\nENDCLASS\nDECLARED METHOD FUNCTION Ping()CLASS Demo\nreturn 42\n', 2, 'DECLARED METHOD FUNCTION Ping()CLASS Demo'),
    'continued': ('CLASS Demo\nMETHOD Ping()\nENDCLASS\nDECLARED METHOD FUNCTION ;\nPing() CLASS Demo\nreturn 42\n', 2, 'DECLARED METHOD FUNCTION ;'),
}

results = {}
for name, (body, count, decl) in cases.items():
    fixture = work / (name + '.prg')
    fixture.write_text('#include "hbclass.ch"\n' + body)
    build = subprocess.run([compiler, str(fixture), '-hblib', '-quiet', '-o'+str(work/name)], capture_output=True, text=True)
    r = {'compiler_exit': build.returncode, 'compiler_log': build.stdout+build.stderr, 'fixture': fixture.read_text()}
    if build.returncode == 0:
        env = dict(os.environ, HBIDE_NAV_FIXTURE=str(fixture), HBIDE_NAV_COUNT=str(count), HBIDE_NAV_DECL=decl)
        test = subprocess.run(['python3', str(root/'tests/test_nav_declared_method_pty.py')], env=env, capture_output=True, text=True)
        r.update(pty_exit=test.returncode, pty_log=test.stdout+test.stderr)
    results[name] = r
    print(name, r.get('pty_exit', 'compiler rejected'), flush=True)
(work/'results.json').write_text(json.dumps(results, indent=2)+'\n')
print('Results:', work/'results.json')
raise SystemExit(int(any(r['compiler_exit'] or r.get('pty_exit',1) for r in results.values())))

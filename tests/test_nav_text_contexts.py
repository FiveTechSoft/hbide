"""Compiler-valid standard std.ch TEXT forms through the real IDE picker.
No fixture runtime execution or output side effects. Not visual certification.
"""
import json, os, pathlib, subprocess, tempfile
root = pathlib.Path(__file__).resolve().parents[1]
work = pathlib.Path(tempfile.mkdtemp(prefix='hbide-text-contexts-'))
compiler = os.environ.get('HBMK2', 'hbmk2')
cases = {
    'file_literal': 'TEXT TO FILE "out.txt"',
    'printer': 'TEXT TO PRINTER',
    'printer_abbrev4': 'TEXT TO PRIN',
    'printer_abbrev5': 'TEXT TO PRINT',
    'printer_abbrev6': 'TEXT TO PRINTE',
    'printer_abbrev_continued': 'TEXT TO ;\nPRIN',
    'continued_text': 'TEXT ;\nTO FILE "out.txt"',
    'continued_to': 'TEXT TO ;\nFILE "out.txt"',
    'continued_printer': 'TEXT TO ;\nPRINTER',
    'continued_twice': 'TEXT ; // join\nTO ;\nFILE "out.txt"',
    'file_tab': 'TEXT\tTO\tFILE\t"out.txt"',
    'file_bare': 'TEXT TO FILE out.txt',
    'file_expression': 'TEXT TO FILE ("out" + ".txt")',
}
results = {}
for name, command in cases.items():
    fixture = work / (name + '.prg')
    fixture.write_text('procedure Main()\n' + command + '\nfunction Phantom()\n/* literal, not comment state\nENDTEXT\nreturn\nfunction Real()\nreturn 42\n')
    build = subprocess.run([compiler, str(fixture), '-hblib', '-quiet', '-o'+str(work/name)], capture_output=True, text=True)
    result = {'compiler_exit': build.returncode, 'compiler_log': build.stdout+build.stderr, 'fixture': fixture.read_text()}
    if build.returncode == 0:
        env = dict(os.environ, HBIDE_NAV_FIXTURE=str(fixture))
        test = subprocess.run(['python3', str(root/'tests/test_nav_text_file_pty.py')], env=env, capture_output=True, text=True)
        result.update(pty_exit=test.returncode, pty_log=test.stdout+test.stderr)
    results[name] = result
    print(name, result.get('pty_exit', 'compiler rejected'), flush=True)
(work/'results.json').write_text(json.dumps(results, indent=2)+'\n')
print('Results:', work/'results.json')
raise SystemExit(int(any(r['compiler_exit'] or r.get('pty_exit',1) for r in results.values())))

"""Linux exploratory harness. Usage: python check_cancel_owned.py PROBE_BINARY."""
import json, os, pathlib, subprocess, sys, tempfile, time
binary = pathlib.Path(sys.argv[1]).resolve()
fixture = pathlib.Path(__file__).with_name('build_cancel_flood.py').resolve()
root = pathlib.Path(tempfile.mkdtemp(prefix='hbide-cancel-flood-'))
env = dict(os.environ, HBIDE_PROBE_PID_DIR=str(root))
def run(path):
    start = time.monotonic()
    result = subprocess.run([str(binary), str(path)], env=env,
                            capture_output=True, text=True, timeout=8)
    return {'exit': result.returncode, 'seconds': round(time.monotonic()-start, 4),
            'stdout': result.stdout, 'stderr': result.stderr}
flood = run(fixture)
states = {}
for file in root.glob('*.pid'):
    pid = int(file.read_text())
    stat = pathlib.Path('/proc') / str(pid) / 'stat'
    states[file.name] = 'gone' if not stat.exists() else stat.read_text().rsplit(')', 1)[1].split()[0]
    file.unlink()
root.rmdir()
missing = run('/nonexistent/hbide-probe.py')
assert flood['exit'] == 0 and '262152' in flood['stdout'] and '262144' in flood['stdout'], flood
assert len(states) == 2 and all(value == 'gone' for value in states.values()), states
assert missing['exit'] == 1 and 'CANCELLED .F.' in missing['stdout'] and 'KILL         -1' in missing['stdout'], missing
print(json.dumps({'flood': flood, 'process_states': states, 'missing_script': missing,
                  'scope': 'Linux finite256KiB per pipe and missing script only; not production cancellation or missing launcher, detached, leader-exit, infinite flood, UI, Windows acceptance.'}, indent=2))

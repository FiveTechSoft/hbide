"""Linux-only terminal-output probe, not a Windows latency benchmark.
Usage: python3 tests/measure_editor_terminal.py /absolute/path/to/hbide 500
Each run uses fresh HOME/recovery dirs and TERM=xterm, PTY 40x120.
500 x characters form one burst in the default template. Four 150ms empty
reads define quiescence; this includes a fixed 600ms floor. Output bytes
are wire traffic after startup, not framebuffer repaints or token counts.
Always run functional tests first: a crash dialog can produce false savings.
"""
import os, pty, sys, struct, fcntl, termios, select, time, signal, shutil, tempfile

BIN = sys.argv[1]; N = int(sys.argv[2]) if len(sys.argv) > 2 else 500
home = tempfile.mkdtemp(prefix='hbide-perf-home-'); rec = tempfile.mkdtemp(prefix='hbide-perf-rec-')
env = dict(os.environ, HOME=home, HBIDE_RECOVERY_DIR=rec, TERM="xterm")
pid, fd = pty.fork()
if pid == 0:
    os.execve(BIN, [BIN], env)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', 40, 120, 0, 0))

def drain(secs):
    t0 = time.time()
    while time.time() - t0 < secs:
        r,_,_ = select.select([fd],[],[],0.1)
        if r:
            try: os.read(fd, 65536)
            except OSError: break

drain(2.5)
os.write(fd, b"x" * N)
t0 = time.time(); total = 0; quiet = 0
while True:
    r,_,_ = select.select([fd],[],[],0.15)
    if r:
        try: d = os.read(fd, 65536)
        except OSError: break
        if not d: break
        total += len(d); quiet = 0
    else:
        quiet += 1
        if quiet >= 4: break
    if time.time() - t0 > 30: break
elapsed = time.time() - t0
print("%s: %d chars, %.2fs to quiesce, %d output bytes (%.0f B/char)" % (os.path.basename(BIN), N, elapsed, total, total/N))
os.kill(pid, signal.SIGKILL); os.waitpid(pid, 0); os.close(fd)
shutil.rmtree(home, ignore_errors=True); shutil.rmtree(rec, ignore_errors=True)

# Live browser demo environment

This document records how the public mc browser demo is wired so the
setup (and its hard-won fixes) can be reproduced. It contains no
tokens, credentials or hostnames; those live only on the demo host.

## Components

- `ttyd` serves the terminal over websocket:
  `ttyd -W -i 127.0.0.1 -p 7700 /path/to/wrapper.sh`
- A small token gate (HTTP) issues single-use launch links and proxies
  to ttyd. A quick tunnel (e.g. cloudflared) exposes the gate.
- `wrapper.sh` (below) sandboxes each session and starts the demo
  binary.

## wrapper.sh

```bash
#!/bin/bash
# IMPORTANT: do NOT force a pty size here (no `stty rows N cols M`).
# ttyd already sizes the pty to the connected client, and mc adapts to
# the real size via CheckResize(). Forcing a size created a resize
# storm at every session start (wrapper stty -> app SetMode request ->
# xterm.js fit) whose late GT shadow repaint corrupted the rows above
# the keybar. See the dated 2026-10-25 entries in STATUS.md.
exec bwrap --clearenv --ro-bind /usr /usr --ro-bind /lib /lib \
  --ro-bind /lib64 /lib64 --ro-bind /bin /bin --dev /dev --tmpfs /tmp \
  --bind /path/to/demo-home /home/demo --chdir /home/demo \
  --setenv HOME /home/demo --setenv TERM xterm-256color \
  --unshare-all --die-with-parent \
  prlimit --cpu=600 --as=1073741824 --nproc=64 \
  timeout --foreground 2700 /home/demo/mc-bin /home/demo
```

## Rules that keep the demo healthy

- mc must NOT call `SetMode()` at startup. It used to force 40x120,
  which emits a terminal resize request and fights the terminal's own
  size. Removed 2026-10-25; `CheckResize()` handles real resizes.
- Swap the running binary atomically (`cp mc mc-bin.new && mv
  mc-bin.new mc-bin`); a plain `cp` over a binary in use fails with
  "text file busy". Running sessions keep the old inode safely, new
  sessions pick up the new build.
- Sessions are time-limited by `timeout` inside the wrapper and CPU/
  memory/process-capped by `prlimit`. The sandbox is read-only except
  the bind-mounted demo home.
- Demo home content is fixtures only (`muchos/` holds 120 small files
  to exercise scrolling). Test litter created by sessions lands on the
  host home and must be cleaned by hand.

## Mobile access (responsive, added 2026-10-25)

Launch links open a small wrapper page (`/m/<session>/`) that embeds the
ttyd session in a same-origin iframe and adds what ttyd's built-in page
lacks: a `viewport` meta tag and a touch aux-key bar (Esc, Tab, arrows,
Intro). The bar only appears on touch/narrow screens
(`pointer:coarse` or `max-width:700px`); desktop renders exactly as
before at full window height. Bar buttons send their sequences through
xterm.js `term.paste()` into the iframe's terminal, so navigation works
without an OS keyboard; taps inside the terminal reach mc as mouse
clicks (keybar, menus and dialogs stay tappable). mc adapts to the
small grid via `CheckResize()` - one more reason it must not force a
fixed size. Verified with device emulation: 390x844 portrait (46x52,
bar visible, aux arrows move the panel cursor), 844x390 landscape
(117x21, fully readable), desktop unchanged (bar hidden, 160x46).

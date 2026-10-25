# Rebuilding the live demo after losing the demo host

The demo stack is fully reconstructible from this repo plus public
binaries. No tokens, credentials or hostnames here - those are runtime
files on the demo host only. Tested once for real: the sandbox was
rebuilt on 2026-10-26 and the whole demo was back, verified end to
end, in under 10 minutes following these steps.

## Layout on the demo host

    /tmp/harbour/            harbour toolchain (sibling of hbide, per go.sh)
    /tmp/hbide-rc/           this repo, branch mc-demo
    /tmp/mcdemo/home/        demo home (fixtures + mc-bin)
    /tmp/mcdemo/wrapper.sh   per-session sandbox (see DEMO.md)
    /tmp/mcdemo/{tokens,sessions}.json   runtime state, start as {}

## Steps

1. Toolchain (once per host):
   - `git clone --depth 1 https://github.com/FiveTechSoft/harbour /tmp/harbour`
   - bison/flex without root: `apt-get download bison flex libfl-dev m4`,
     `dpkg -x *.deb /tmp/debs/root`, use `PATH=/tmp/debs/root/usr/bin:$PATH`
   - `cd /tmp/harbour && make -j2`  (~3 min on 2 cores; hbmk2 lands in
     `bin/linux/gcc/`)
2. Binary:
   - `git clone --depth 50 --branch mc-demo https://github.com/FiveTechSoft/hbide /tmp/hbide-rc`
   - `cd /tmp/hbide-rc/mc && HB_PLATFORM=linux HB_COMPILER=gcc \
      /tmp/harbour/bin/linux/gcc/hbmk2 mc.hbp` -> `mc` (2 681 896 bytes at
      the 2026-10-25 q7 sources; md5 varies with build metadata)
   - `cp mc /tmp/mcdemo/home/mc-bin`
3. Fixtures in /tmp/mcdemo/home: docs/, imagenes/, proyecto/ (one small
   file each), muchos/ (120 files fichero001..120.txt), archivo1..5.txt,
   datos.bin (32 KiB), LEEME.txt. Keep it clean: no test archives.
4. Public binaries (GitHub releases, no account):
   - ttyd: `tsl0922/ttyd` release asset `ttyd.x86_64`
   - cloudflared: `cloudflare/cloudflared` asset `cloudflared-linux-amd64`
   - `pip3 install aiohttp` for gate.py
5. Services (setsid so they survive the launcher):
   - `ttyd -W -i 127.0.0.1 -p 7700 /tmp/mcdemo/wrapper.sh`
   - `python3 /tmp/hbide-rc/mc/gate.py`  (127.0.0.1:7800)
   - `cloudflared tunnel --url http://127.0.0.1:7800 --no-autoupdate \
      --retries 20 --edge-ip-version 4` (quick tunnel; hostname from log)
6. Mint a user token into tokens.json (`{tok: {created, used:0}}`),
   verify `GET /launch?t=<tok>` = 200 publicly, open one session in a
   real browser and check the mc UI draws before calling it available.

## Operational notes

- Quick tunnels die server-side; observed lifetime ~25-40 min (pattern,
  not a guarantee). cloudflared self-heals transport flaps in seconds
  (same hostname); "Unauthorized: Tunnel not found" repeating in the log
  means expired - relaunch and take the new hostname. Never relaunch a
  tunnel that is self-healing: that invalidates the user's link for
  nothing. Check `ss -tn` for live sessions on :7700/:7800 before any
  restart.
- Swap mc-bin atomically (cp + mv), never over a running binary.
- The single-use token is consumed only by POST /open; GET /launch is
  a safe check. A 403 without token is correct gate behavior.

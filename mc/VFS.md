# VFS design for the MC demo

Goal (user request 2026-10-24): implement the Midnight Commander VFS options
(FTP, SFTP, shell link, extfs) on top of the demo, without credentials,
payments or private servers. This document is the architecture; each provider
lands only with its own tests against public test services or local
throwaway fixtures.

## Constraints

- Pure Harbour; external commands only for measured slowness or protocol
  tooling (same policy as the rest of the demo: /bin/sh + POSIX utilities).
- No stored credentials, no paid services, no user private servers.
- Test infrastructure per provider must be named before the provider is
  claimed "done"; limits stay in the README matrix until then.

## Architecture

Path routing. A panel path becomes a VFS path:

    [scheme://][user@host[:port]]/path        ftp://, sftp://, sh://
    /local/dir/archive.tar#utar/inner/path    extfs (archive-in-path)
    /plain/local/path                         local filesystem (today's code)

`MCVfsParse( cPath )` splits a path into { cScheme, cHost, cRest }. Local
paths keep the existing code untouched: the router returns the local
provider and everything behaves exactly as now.

Provider interface. One class per scheme, all producing and consuming the
existing panel entry shape `{ name, size, date, time, attr, isDir, marked }`
(mcpanel.prg Rescan) so sorting, filtering, marking and rendering are
unchanged:

    CLASS MCVfsProvider
       METHOD List( cDir )        // -> array of entries, same shape as Rescan builds
       METHOD Stat( cPath )       // -> one entry or nil
       METHOD Read( cPath, cDstLocal )   // remote/archive file -> local temp file
       METHOD Write( cSrcLocal, cPath )  // local temp file -> remote/archive
       METHOD Delete( cPath )     // file or empty dir
       METHOD Mkdir( cPath )
       METHOD Rename( cSrc, cDst )

Integration points (concrete):

- MCPanel:Rescan() (mcpanel.prg:128) asks the router for the provider of
  ::cPath and calls List() instead of Directory() when the scheme is not
  local. Panel modes (quickview/info/tree/panelize) that walk the local FS
  are disabled or degraded per provider, named in the matrix.
- FileCopy/FileMove/FileDelete route per item: same-scheme operations go to
  the provider (Rename/Delete); cross-scheme copy/move stream through a
  local temp file (Read -> FCopyText -> Write) reusing the existing
  verified-copy and failure-rollback machinery. Partial-failure semantics
  stay as documented in README: rollback of what the operation created.
- The viewer/editor open remote or archived files on a local temp copy and
  offer to write back on save (Write). Until write-back is implemented for
  a provider, its files open read-only and the matrix says so.

## Providers, in implementation order

1. extfs (local, no server): browse archives in place. `tar tf` / `unzip -l`
   for List, `tar xOf` / `unzip -p` for Read. Write landed 2026-10-24
   (mcarcwrite.prg): F5 add, F8 delete member and F7 mkdir member work
   inside ZIP and TAR panels. Nothing is edited in place: every change
   goes through a staging tree (ZIP merges via `zip -r` / `zip -d`; TAR
   is extracted, modified and repacked with compression by extension).
   The original TAR is backed up next to itself (.hbbak) and restored on
   any repack failure; temp names never collide with member names.
   Verified: byte-exact preservation of untouched members including
   dotfiles, add/delete/mkdir round-trips, a read-only archive fails with
   a message and stays byte-identical with no temp leftovers, symlink
   copies and archive->archive copies are refused. Fixtures: generated
   archives under /tmp, all throwaway. First provider because it needs
   no network and exercises the full routing layer.
2. FTP read-only, anonymous only: IMPLEMENTED (ftp://). List/RETR via
   curl; dates use the classic LIST format (recent entries carry no year;
   the current year is assumed). Test fixture: the public anonymous
   ftp.gnu.org. Write paths stay pending until a credential-free write
   target exists; no credentials means anonymous FTP only. stdin is closed
   on every curl call so an unexpected password prompt can never block
   the UI. Paths are percent-encoded per byte (MCCurlUrl): names with
   spaces, %, # or UTF-8 bytes work on both curl providers; verified
   against the fixture. A year-less LIST date assumes the current year and
   falls back to the previous one when that would land in the future.
3. SFTP (sftp://) and shell link (sh://, FISH-style): IMPLEMENTED
   read-only. The fixture decision landed 2026-10-24: a throwaway
   user-level sshd on 127.0.0.1:22227 with generated ephemeral keys,
   authorized by main, shut down after tests. sftp:// rides curl/libssh
   (the real SFTP protocol; auth from the user's default ssh keys and
   known_hosts, never command-line credentials). sh:// rides ssh exec
   channels (BatchMode, ConnectTimeout, per-call timeout): `ls -lA
   --time-style=long-iso` for List, `cat` for Read; it needs a GNU ls on
   the remote end. Directory copy-out materializes recursively using only
   List + Fetch (protocol-true, no shell assumptions for sftp/ftp); any
   link inside the subtree refuses the whole copy, fail-closed. Single
   remote entries that are links are refused on view/copy: links are
   shown but never followed, same policy as extfs. Write/delete/move are
   refused with a message.
4. u7z (landed): .7z and .deb (anything `7z l` reads), read-only. Listing
   parses `7z l -slt` property output (never the human table); blocks are
   separated by blank lines which hb_ATokens() drops, so the block
   boundary is the next `Path = ` line plus a final flush. p7zip 16.02
   double-encodes UTF-8 names under a UTF-8 locale, so every 7z call is
   pinned to LC_ALL=C LANG=C. Extract via `7z x -y` into the staging dir.
5. extfs beyond tar/zip/7z/deb (rpm, iso, ...): same pattern per tool;
   blocked in the sandbox - no rpm2cpio / isoinfo / xorriso available.

## Failure and safety semantics

- Listing failures surface as a panel message and keep the previous
  directory (never an empty panel mistaken for an empty remote dir).
- Timeouts and Ctrl-C/Break cancel the current VFS operation without
  corrupting the panel state.
- Temp files live in a per-session dir removed on exit; no remote content
  is written to user files except through an explicit copy destination.
- No provider stores credentials. If a service asks for any login, the
  provider reports it and stops; the README names the service used for
  tests and that it is anonymous.

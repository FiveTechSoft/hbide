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
   for List, `tar xOf` / `unzip -p` for Read. Write/Delete/Mkdir only where
   the tool supports it safely (zip: yes via `zip`/`zip -d`; tar: rewrite
   via temp archive). Fixtures: generated archives under /tmp, all
   throwaway. First provider because it needs no network and exercises the
   full routing layer.
2. FTP read-only, anonymous only: public anonymous services (for example a
   GNU mirror) as test fixtures; LIST/RETR via curl. Write paths stay
   pending until a credential-free write target exists; no credentials
   means anonymous FTP only.
3. SFTP and shell link (FISH): both ride on SSH exec channels. Blocked on
   test infrastructure: needs either a public credential-free SSH test
   service (none known) or a throwaway sshd inside the sandbox (user-level
   sshd on a high port with generated throwaway keys). Decision pending
   with main; until then these stay "pending" in the matrix with this note.
4. extfs beyond tar/zip (rpm, deb, iso, ...): same pattern per tool, added
   on demand.

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

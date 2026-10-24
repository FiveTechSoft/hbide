# hbmc - a Midnight Commander built with the hbide GUI classes

A functional two-panel file commander in pure Harbour, built on top of the
hbide GUI toolkit (windows, menus, dialogs, controls) with a Turbo Vision
look, as an exercise to drive hbide's GUI from real application code.

It is a separate demo: it lives in `mc/` and does not touch the hbide
editor or designer code.

## Build and run

```sh
hbmk2 mc.hbp        # produces ./mc
./mc [directory]
```

Sources: `mc.prg` (application, menus, dialogs, file operations),
`mcpanel.prg` (the file-panel control), `mcview.prg` (internal viewer and
editor, the editor reuses hbide's `HBEditor`), `mc.ch`, `mc.hbp`.

Application code is Harbour. No application-specific C was added. Performance has not yet been benchmarked.

## Status matrix (original Midnight Commander -> this demo)

Legend: **done** = implemented and verified on screen in this build.
**light** = implemented, only lightly exercised so far.
**pending** = not implemented.

### Panel modes and navigation
| MC feature | Status | Notes |
|---|---|---|
| File listing (full/short) | done | |
| Quick view (C-x q) | done | shows the *other* panel's current entry, per MC |
| Info panel (C-x i) | light | stat/links/disk-free of the other panel's entry |
| Tree mode (C-x t) | done | directory tree inside the panel, Enter chdirs |
| Panelize (C-x p) | light | runs a command, panels its output lines |
| Listing format dialog | light | |
| Sort order dialog | done | name/extension/size/mtime/atime/ctime/inode, reverse, case. atime/ctime/inode come from one batched `stat` call per rescan (local panels only; VFS providers do not carry them and compare equal, falling back to name). Verified with fixtures whose atime/ctime/inode orders differ from name order |
| Filter dialog | light | shell pattern filter |
| Rescan (C-r) | light | |
| Directory navigation, `..`, Enter, Tab switch | done | |
| Quick search | light | incremental name search in the active panel |
| Mouse: panel click, double-click, menubar, keybar, wheel | light | panel click and quit dialog checked; remaining gestures need a full pass |

### File operations
| MC feature | Status | Notes |
|---|---|---|
| View (F3) | done | internal viewer, text and hex modes, wrap, search |
| View file... / Filtered view | light | |
| Edit (F4) | done | hbide editor embedded; F2 save, verified on disk |
| Copy (F5) | done | dialog with target dir, verified on disk |
| Rename/Move (F6) | done | verified on disk |
| Mkdir (F7) | done | verified on disk |
| Delete (F8) | done | confirm dialog, verified on disk |
| Chmod (C-x c) | light | octal or symbolic mode |
| Chown (C-x o) | light | |
| Link / Symlink / Edit symlink (C-x l / C-x s) | light | hard, symbolic, relink |
| VFS: extfs archive browsing (Enter on .tar/.tar.gz/.zip) | light | browse, view and copy OUT with size/mtime preserved; verified on nested trees and names with spaces |
| VFS: extfs 7z/.deb browsing (u7z) | light | read-only provider via `7z l -slt`/`7z x`: browse, view and copy OUT of .7z and .deb members, writes refused with a message. Verified in-app: listing incl. unicode names, byte-exact copy-out (md5 matches direct 7z extraction), F8/F7/copy-in refusals, .deb listing (control/data members). Nested archives are NOT navigable: Enter on an archive member opens the raw viewer instead. p7zip 16.02 double-encodes UTF-8 names under a UTF-8 locale, so 7z runs pinned to LC_ALL=C |
| Unicode file names | light | app runs on the UTF-8 codepage (hb_cdpSelect) so raw filesystem bytes render untranslated; cell-based padding (hb_UPadR) keeps columns aligned; verified with ñ á é € names locally and over SFTP; no lossy CP conversion anywhere |
| VFS: extfs write (ZIP/TAR) | light | F5 local file/dir -> archive, F8 delete member, F7 mkdir member, all through a staging tree: ZIP merges via Info-ZIP, TAR is extracted and repacked with a .hbbak backup and rollback on failure (compression by extension). Verified: byte-exact preservation of untouched members including dotfiles, delete/mkdir/add round-trips, refused symlink copies, refused archive->archive copies, read-only archive fails with a message and leaves the original byte-identical with no temp leftovers |
| VFS: FTP / SFTP / shell link | light | read-only: browse, view and copy OUT (write/delete/move refused with a message). Menu items FTP/Shell/SFTP link plus `cd <url>`. SFTP via curl/libssh (real SFTP protocol), shell link (sh://) via ssh exec (FISH-style, needs GNU ls on the remote), FTP anonymous only via curl. Remote symlinks are shown but never followed; copying a remote directory out is refused entirely if its subtree contains links. Fixtures: throwaway loopback sshd with ephemeral keys (127.0.0.1:22227, authorized by main 2026-10-24, shut down after tests) and the public anonymous ftp.gnu.org. Names are percent-encoded per byte on the curl providers (spaces, %, # and UTF-8 names verified against the fixture; names render correctly since the app switched to the UTF-8 codepage, non-lossy). Year-less LIST dates assume the current year and fall back to the previous one when that would land in the future |
| Quick cd (M-c) | light | |
| Select / Unselect group (+, -), Invert (*) | done | only when the command line is empty, as in MC |
| Copy/move/delete of *tagged* groups | light | tagged sets follow the same dialogs |

### Command menu
| MC feature | Status | Notes |
|---|---|---|
| User menu (F2) | done | reads `~/.mc.menu` |
| Directory tree dialog | light | |
| Find file | light | name pattern under the panel directory |
| Swap panels (C-u) | light | |
| Panels on/off (C-o) | done | |
| Compare directories (C-x d) | done | marks newer/missing entries |
| Show directory sizes | light | |
| Command history (M-h) | done | menu list (M-h / Command menu) plus inline Ctrl+Up/Ctrl+Down recall in the command line; persisted across runs (30 entries) |
| Directory hotlist | light | |
| Edit extension file / Edit menu file | light | opens `~/.hbmc.ext` / `~/.mc.menu` in the editor |

### Options menu
| MC feature | Status | Notes |
|---|---|---|
| Configuration dialog | light | |
| Layout dialog | light | panels, menubar, keybar, command line |
| Panel options | light | |
| Confirmation dialog | done | confirm overwrite/delete/execute/quit; Cancel is the focused default, Tab+Enter confirms, Escape cancels; verified on disk (overwrite yes/no, tagged delete, symlink delete keeps target) |
| Appearance | light | color themes |
| Save setup | done | persists to `~/.hbmc.ini` |

### Command line and shell
| MC feature | Status | Notes |
|---|---|---|
| Command line with execution | done | output screen, "press any key" return; full editing: Left/Right/Home/End, Del/Backspace at the cursor, Ins toggles insert/overwrite (when the line is empty Ins stays the mark-file key), inline history recall with Ctrl+Up/Ctrl+Down, horizontal scrolling for long lines, visible cursor; stable two-row layout above the key bar: status row (active path + user + date/time) and prompt row - panel frames untouched; editing is bytewise like the original (non-ASCII input keeps the pre-existing limitation) |
| C-Enter inserts the current name | light | |

### Pending / divergences from the original
| MC feature | Status | Notes |
|---|---|---|
| SMB / "Network" VFS | pending | FTP, SFTP and shell link landed read-only (matrix above); SMB is untested because the test sandbox has no Samba tooling (no smbd/smbclient); an anonymous local share would need no credentials, so no secrets are required to test it |
| VFS: extfs rpm/iso | blocked | .deb landed via the u7z provider (matrix above); rpm/iso need rpm2cpio / isoinfo / xorriso, none installed in the test sandbox |
| "Learn keys" dialog | divergence | replaced by F1 help; no fake key-recorder |
| hbbutton.prg vendored as mc/mcbutton.prg | divergence | the shared ../hbbutton.prg (sibling lanes) uses raw CP437 glyph bytes that render as replacement chars under the UTF-8 codepage; mc builds against a vendored copy whose glyphs are built at runtime as UTF-8 bytes (hb_BChar). The shared file is untouched; if it changes upstream, re-vendor mcbutton.prg |
| Encoding selector (Alt-e) | light | panel display charset per panel, grounded in real mc's Alt-e: recodes the panel's displayed names from the chosen codepage into the app's UTF-8 system codepage, "No translation" cancels. Dialog offers UTF-8, CP437, CP850, CP852, CP866, CP1251, CP1252, ISO-8859-1 and ISO-8859-2. Display-only: all file operations use the raw filesystem bytes. The internal viewer (F3) recodes file content from the active panel's charset and shows it in the title bar. Saved as cpleft=/cpright= in ~/.hbmc.ini via Save setup. Verified live with CP850 fixtures: raw mojibake before, correct año/mañana after, per-panel independence (right panel untranslated), viewer recode, and restore after quit+restart |
| Advanced chown/chattr | blocked | chattr needs CAP_LINUX_IMMUTABLE: `chattr +i` and `chattr +a` both fail with EPERM in the test sandbox (ext4, no capability); lsattr reads work |
| Background copy/move queue | done | F5 copy and F6 move dialogs have a Background button (grounded in real mc: background button on the copy dialog, Background Jobs entry in the Command menu); jobs run chunked during idle time with a live Background Jobs dialog (Command menu) - C cancels the selected job, Esc closes; quitting with active jobs asks to cancel them first; one up-front overwrite confirmation covers the whole copy queue (background move never overwrites: entries whose destination exists are skipped up front, like the foreground move); temp+rename per file with the same safety rules as the foreground ops; moves try an atomic rename first (same filesystem) and fall back to copy+delete, removing each source only after its complete copy is in place; directory perms/mtimes are snapshotted at enqueue and re-applied after a move empties them; local-to-local only (a VFS source or target is refused and the copy/move dialog reopens so OK can run it in the foreground); verified: 40MB file + tree copied byte-exact (md5) with perms/mtimes preserved, cancel mid-copy erases the temp, decline-overwrite skips, quit-guard cancel erases temps; same-fs background move of a 4-item mix (dir tree, file, existing-name file, symlink) byte-exact with perms/mtimes preserved and the collision skipped; cross-device (/tmp -> /dev/shm tmpfs) 40MB background move byte-exact via the copy+delete path with the source removed only after completion, and cancel mid-move at 58% left the source byte-intact with the destination temp erased. Publication is ATOMIC no-clobber: files publish via hard link (ln), which fails EEXIST and can never replace a destination - no check-then-rename window on either the same-filesystem path or the cross-device temp publish; destination dirs are created with mkdir(2) itself, so EEXIST is atomic there too (verified at the shell level and in the race tests below). Error semantics: per-entry problems are recorded and the job then ends as 'error' - never 'done' - with the selected job's detail in the dialog's red area (3 lines of 180 characters; an explicit '...' tail marks truncation, and Enter on the selected job opens the full problem list in the scrollable internal viewer - no incident is silently truncated; every problem is ALSO appended to an uncapped per-job log file (hbmclog* in the temp dir, erased on clean quit) and Enter views the full log, so detail survives past the 4000-char inline cap - verified with a 200-error tree move (5692-byte log, 201 viewer lines, inline summary capped with the explicit '...' tail); the log writer checks its own open/write results and declares inline '[full error log unavailable...]' plus a viewer warning instead of ever claiming a complete log when the log itself fails; a partial log also carries a partway warning in the viewer. All four failure branches fault-injected live: log creation (unwritable TMPDIR), append-open (LD_PRELOAD EACCES), short write (LD_PRELOAD partial write - the log keeps the truncated line and the viewer warns), and read-back (chmod 000 on the log - inline summary plus warning). Read failures mid-copy: verified with an LD_PRELOAD read() shim failing with EIO after 100KB - the background job ends in error ('read failed'), the temp is erased, the destination keeps nothing and the source stays byte-intact (md5); the foreground copy reports 'Copy failed ... destination left unchanged'; verified: an unreadable file inside a moved tree (job error, the rest of the tree moved, unreadable source kept), a destination FILE racing in after enqueue (refused at entry, racer untouched, source kept), a destination DIR racing in after enqueue (refused, no merge into it, whole subtree kept), a destination racing in DURING a cross-device copy (temp erased, racer untouched, source kept), and a source that cannot be deleted after its copy completed (destination complete, source kept, reported distinctly as 'copied but source not removed'). Cancelling a partially moved tree does NOT roll back: entries already moved stay at the destination, the rest stay at the source, and the job's red detail line says so explicitly ("PARTIAL MOVE: N item(s) stay at destination; no rollback") - verified: 40 of 400 files moved at cancel, 0 duplicates, 400 total across both sides, no loss; the move can simply be retried for the remainder. Filesystems without hard-link support: ln failures are classified (destination-exists / cross-device / filesystem-cannot-hardlink / other) from the ln stderr. On a filesystem that cannot hard-link, background moves are REFUSED with a clear message ('destination filesystem cannot hard-link; background move refused (no overwrite-capable fallback)') both at entry (fast path) and at publish time after a cross-device copy ('... cannot hard-link; source kept'); a move NEVER falls back to an overwrite-capable publish. Verified with a PATH-injected fake ln returning EPERM (entry-path refusal and publish-path refusal after the copy, source kept, destination untouched) - no real no-hardlink mount is available in the test sandbox, so a real mount of that kind remains untested. Also verified under the atomic engine: a write failure mid-copy induced by a real OS file-size limit (ulimit -f, job error at 40%, temp erased, source intact; the error line currently names the temp file instead of the source name - known cosmetic gap), a delete-source failure (destination byte-complete, source kept, reported distinctly as 'copied but source not removed'), and a destination directory deleted mid-copy (source intact). Limits: real mc's stop/restart is not implemented (cancel only); the queue advances cooperatively and pauses while a modal dialog is open |
| Text GETs need Enter twice | known quirk | hbide plain `READ` semantics: first Enter leaves the GET, second activates the focused button - same as hbide's own dialogs. Pushbuttons fire on Enter when focused; confirm dialogs put Cancel first so a stray Enter/Escape never destroys data | Esc cancels any dialog (the app enables the READ exit key only while a dialog is active and keeps it off in the main loop): an Esc-closed dialog applies nothing - verified with Appearance (theme unchanged after Esc with a modified selection) and the charset dialog |
| ESC = meta prefix | note | ESC followed by a letter acts as Alt+letter, as in MC |

## Test fixtures

All file-operation tests run on throwaway trees under `/tmp/hbmc-test/`.
Never on user files.

## Safety and current platform limits

This revision is tested on Linux. Shell execution, chmod/chown, links and
information fields use `/bin/sh` and POSIX/GNU utilities. Windows support is
not validated. This is a demo, not a replacement for production MC yet.

Copy refuses the same file (including hard-link aliases), a directory inside
itself, a destination that is an existing directory, and source/destination
symbolic links. Recursive failures are reported.
Move refuses an existing target rather than replacing it. Cross-filesystem
moves copy first and remove the source only after a complete copy: directories
recurse and symlinks are recreated with their original target (a relative
target is converted to absolute against the source directory, so it still
points to the same entry from the new location). Tested across
ext4->tmpfs (/tmp->/dev/shm):

* Copy fails partway (unreadable file inside a tree): the source is left
  untouched and a destination directory created by the operation itself is
  removed again (rollback verified for both copy and move). A pre-existing
  destination keeps whatever partial content was written into it; the
  failure is reported with a per-item count.
* Copy succeeds but the source removal fails partway (read-only directory
  inside the tree): the destination holds a complete copy and the source may
  be left partially deleted; the failure is reported. Everything removed from
  the source exists at the destination in this scenario, but the operation
  is not atomic and the tree can be left split between both locations.

Metadata on copy/move: regular files keep their permission bits
(chmod --reference onto the temporary copy) and modification time
(touch --reference after placement). A directory created by the copy keeps
the source directory's permissions and mtime, applied after its contents
are in place so a read-only source dir cannot block its own copy; a
pre-existing destination directory keeps its own metadata. Ownership is
not preserved. Verified with a 751 directory carrying 2020/2021 mtimes
copied ext4->tmpfs. Recursive delete unlinks
symbolic links without traversing their target. Trees the app itself
created (extract wraps, rollback targets, session temp) are made
traversable before removal (chmod -R u+rwX): trees coming out of archives
or read-only sources can carry directories without owner permissions that
would otherwise strand partial trees on rollback, refusal cleanup and
session-temp cleanup. The prep is scoped to those app-owned trees only;
user-initiated deletes never change permissions, and a failed delete of a
user tree with unwritable directories is reported and can leave partial
content (the pre-existing behavior). chmod -R does not traverse symlinks,
verified against a tree whose links pointed at a sentinel with mode 400:
the sentinel's permissions and content were untouched. Verified end to end
with a refused archive dir extraction whose wrap carried a
permission-less dir holding outside-pointing links: the wrap is fully
removed and nothing persists outside the temp area.

Overwrite protection: a copy writes to a temporary file in the destination
directory and replaces the destination only after a complete, verified copy
(FRead() returns 0 on both EOF and error; FError() tells them apart). If the
final rename fails where rename does not replace existing files (Windows
rename semantics), the previous destination is moved aside to a unique name
and restored if the retry fails; if even the restore fails, its content is
preserved at the backup path named in the error message. Verified with
induced read errors (/proc/self/mem), a read-only destination directory, and
an LD_PRELOAD shim simulating rename failures: move-aside success, successful
restore and preserved-backup cases all exercised against the real binary.
Fully transactional multi-file semantics, metadata beyond permission
bits and mtime (ownership, ACLs, xattrs) and concurrent filesystem
changes are not covered.

Archive extraction safety (extfs, tar/tar.gz/zip): members whose paths
contain `..` or are absolute are hidden from listings and never extracted;
a leading `./` is normalized away. Link members are listed but never
followed: viewing or copying an individual link member is refused, and
copying a directory out of an archive is refused entirely when any member
of its subtree fails extraction, so a tree containing a symlink or
hardlink aimed outside the archive (including chains of links listed
before their children) cannot be copied out. Verified with generated
fixtures whose link chains pointed at a sentinel directory outside the
extraction area: GNU tar and unzip themselves refuse to write through the
link, the whole copy is refused with a message, and the sentinel stays
untouched; an innocent file inside the same tree still copies normally.
Member names with shell metacharacters are never passed to a shell
unquoted and are never executed. A truncated archive is refused. Passing
these fixtures does not prove that no escape path exists; read-only
access inside archives remains the current documented limit, not the
final closure of the objective.

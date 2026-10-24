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
| Sort order dialog | done | name/extension/size/mtime, reverse, case |
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
| VFS: extfs 7z/.deb browsing (u7z) | light | read-only provider via `7z l -slt`/`7z x`: browse, view and copy OUT of .7z and .deb members, writes refused with a message. Verified in-app: listing incl. unicode names, byte-exact copy-out (md5 matches direct 7z extraction), F8/F7/copy-in refusals. p7zip 16.02 double-encodes UTF-8 names under a UTF-8 locale, so 7z runs pinned to LC_ALL=C |
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
| Command history (M-h) | light | |
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
| Command line with execution | done | output screen, "press any key" return |
| C-Enter inserts the current name | light | |

### Pending / divergences from the original
| MC feature | Status | Notes |
|---|---|---|
| SMB / "Network" VFS | pending | FTP, SFTP and shell link landed read-only (matrix above); SMB has no credential-free fixture to test against |
| VFS: extfs rpm/iso | blocked | .deb landed via the u7z provider (matrix above); rpm/iso need rpm2cpio / isoinfo / xorriso, none installed in the test sandbox |
| "Learn keys" dialog | divergence | replaced by F1 help; no fake key-recorder |
| hbbutton.prg vendored as mc/mcbutton.prg | divergence | the shared ../hbbutton.prg (sibling lanes) uses raw CP437 glyph bytes that render as replacement chars under the UTF-8 codepage; mc builds against a vendored copy whose glyphs are built at runtime as UTF-8 bytes (hb_BChar). The shared file is untouched; if it changes upstream, re-vendor mcbutton.prg |
| Encoding selector | pending | the UTF-8 DEFAULT is resolved (app runs on the UTF-8 codepage, see Unicode row) - but a user-facing encoding CHOICE (view/list a file or panel under a different codepage) is a distinct feature and is not implemented |
| Advanced chown/chattr, atime/ctime/inode sort orders | pending | |
| Background copy/move queue | pending | operations are synchronous |
| Text GETs need Enter twice | known quirk | hbide plain `READ` semantics: first Enter leaves the GET, second activates the focused button - same as hbide's own dialogs. Pushbuttons fire on Enter when focused; confirm dialogs put Cancel first so a stray Enter/Escape never destroys data |
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

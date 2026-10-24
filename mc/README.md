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
| FTP / SFTP / SMB / shell-link VFS, "FTP link", "Network" | **pending** | awaiting the user's scope decision; deliberately absent from the menus so no item promises what it does not do |
| "Learn keys" dialog | divergence | replaced by F1 help; no fake key-recorder |
| Encoding selector | pending | terminal is UTF-8 |
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
symbolic links without traversing their target.

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

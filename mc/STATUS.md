# MC demo - honest status matrix (2026-10-24)

Branch `mc-demo`, folder `mc/`. Every row verified with real screenshots
against the live binary on xterm/UTF-8, unless marked otherwise.
"Light" = works partially; gaps listed. "Pending" = not implemented or not
verified. "Env-blocked" = needs infrastructure the demo must not use
(credentials, payments, private servers, extra packages).

## Verified working

- Two-panel file manager, navigation, selection, F-keys bar
- File menu (17 items) and Command menu (12 items)
- View file... (F3 dialog with prefilled name, cursor after the text)
- Filtered view (M-!) - viewer expands TAB to 8-column stops
- Internal viewer (text mode, scrolling)
- User menu (F2), Directory tree, History (M-h), Hotlist, Quick cd (M-c)
- Symlink: create (C-x s), edit guard + retarget, F8 delete
- Symlinks in the panel: shown as 'name -> target'; links to
  directories stay browsable (Enter follows the link); readlink proven
  with spaces, quotes, leading dashes, broken and relative targets
- Hard link (inode verified)
- Background jobs dialog
- Edit external file, Edit menu file
- Dialog buttons redone after user review: per-button "style" property
  (contract shared with the designer): STYLE "brackets" = authentic MC
  text buttons "[ Caption ]" on the dialog background (hotkey red,
  focused black-on-cyan with yellow hotkey; reference: mc
  lib/widget/button.c); any other style = hbide block button with solid
  shadow. Both verified live in one dialog. NOTE: the RTL style SETGET
  only accepts 0/2/8-char values, so "brackets" (8) passes but a STYLE
  clause value like "shadow" (6) raises PUSHBUTTON/1001 - relayed to the
  designer for their codegen. Per-GET COLOR honored again: body colors
  come from the spec (indices 0/1/2), hotkey from index 3 unfocused,
  derived bright-yellow-on-focus-bg focused (RTL single hotkey slot
  cannot be right in both states). Default button marked [< >] via
  GUISEND cargo := .T. and Enter made real MC semantics: Enter on any
  non-button control fires the default (verified: checkbox -> OK applied;
  focused Cancel still wins over the default)
- Dialog checkboxes in MC colors: unfocused black-on-gray with red
  hotkey, focused black-on-cyan with yellow hotkey (was: all captions
  cyan at once). Vendored ChkDisplay override in mcbutton.prg; RTL
  CheckBox untouched
- Turbo Vision cyan theme: directories now bright white on cyan (was
  gray-on-cyan, weak contrast)
- Move (F6): overwrite confirmation (decline keeps both files; accept
  replaces the destination; directories and VFS stay protected)
- DlgInput: prefilled GET opens with cursor after the text (End + walk back
  over the PadR'd padding)
- F10 Exit with confirmation dialog (decline stays in the app; accept
  exits cleanly to the shell)
- Long file names truncated with one separator cell kept before the Size
  column (long and brief formats)
- Mini status bar shows free disk space (Show free space)
- Backup files (~) hidden from panels unless Show backup files is on
- Select/Filter group: shell patterns on, plain substring match when off
- Sort order dialog: selection now applies (size sort verified live;
  per-panel sort state kept when the split changes). Note: the numeric
  GET round-trip is unreliable in the Commander's dialogs, so radio
  selection is read from the control buffer - scoped to mc/, NOT an
  hbide-wide defect (the designer's generated PRG applies it correctly)
- Listing format: Full, Brief, Long (ls -l style: perms, nlink, owner,
  group, size, mtime) and User defined (columns split by "|", fields
  name/ext/size/bsize/mtime/perm/nlink/owner/group/type/mark/space,
  "half" = half-width column) + user mini status option. atime/ctime
  render real local times (extra stat fetched lazily, only when the
  user format references %x/%z or the inode). Per-panel formats persist
  to ~/.hbmc.ini (save+load round-trip verified, restart restores them)
- Layout: horizontal / vertical panel split
- Configuration dialog: 6 working checkboxes (Show hidden files, Show
  mini-status, Compute totals, Show free space, Auto save setup, Shell
  patterns)
- Panel options: 3 working checkboxes (Mix all files, Show backup files,
  Mark moves down) - mark-moves-down off keeps the cursor on Insert
- Options persist to ~/.hbmc.ini: save+load round-trip verified; Auto save
  setup saves the current options on quit
- Appearance: theme change applies live - Turbo Vision cyan palette
  verified on screen and reverted to classic; radiogroup selection read
  fixed in code (same bug class as sort order)
- Confirmation dialog: 4 checkboxes (Delete, Overwrite, Execute, Exit),
  all exercised. Delete on -> "Delete 1 item(s)?" dialog; Delete off ->
  file removed without asking (verified with a sacrificial fixture).
  Execute on -> "Execute <name>?" dialog on Enter for executables;
  accepting runs the command and its output is shown
  (hello-from-mc). Overwrite verified in the Move block, Exit earlier.
- Executable files: Enter offers to run them (with confirmation when
  enabled) through the command line
- Learn keys: dialog lists F1..F10 with current bindings; relearn
  captures the next key press (F10 Quit relearned to F12: F12 opened
  Quit, F10 inert), binding saved to ~/.hbmc.ini (learnkey10=-41) and
  still active after an app restart; relearned back to F10 afterwards

## Light (partial)

- (none right now)

## Pending (not implemented / not verified)

- (none right now)

## Env-blocked (out of demo scope by design)

- SMB VFS (needs an SMB server + credentials)
- extfs helpers that need extra packages (rpm/iso tools)
- chattr/chown operations requiring other-owner privileges
- Any network VFS needing credentials or private servers

## Known limits

- Keystroke injection (XTEST) can lose characters mid-session; tests drive
  the app in short batches with a verifying screenshot after each step.
- Dialog GET width follows the variable length (PadR), not @S pictures.
- RadioButtn selection is read from the control's exported buffer state;
  the numeric GET round-trip is unreliable in hbide GET dialogs.

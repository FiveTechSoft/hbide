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
- Dialog buttons redone after user review: per-button "style" property.
  Runtime contract aligned with the designer's real codegen (their
  8044b9c/fcff867/f68ed65, relayed via main): codegen emits STYLE "[]"
  for brackets and omits the STYLE clause for shadow (RTL default "<>"
  3D block); "brackets" is kept as a legacy alias, and a STYLE value
  like "shadow" (6 chars) is never emitted because the RTL style SETGET
  only accepts 0/2/8-char values (PUSHBUTTON/1001 otherwise). Brackets
  = authentic MC text buttons "[ Caption ]" on the dialog background
  (hotkey red, focused black-on-cyan with yellow hotkey; reference: mc
  lib/widget/button.c); anything else = hbide block button with solid
  shadow. Both verified live in one dialog, including a scratch dialog
  written exactly like the designer's generated code (one STYLE "[]",
  one STYLE omitted) run through the Commander overrides. Mouse hit test
  matches the same contract as the designer's DsnBtnHitTest (vendored
  BtnHitTest in mcbutton.prg): brackets width = caption-without-& + 4
  (+2 for the [< >] default marker), height 1, closing bracket clickable;
  shadow width = caption + 2 clickable (3 painted with the shadow cell),
  height 2. Dialog layouts compute positions from those rendered widths
  (confirmation dialog [< Cancel >] / [ Quit ] verified with real air
  between buttons, full dialog crop). Per-GET COLOR honored again: body
  colors come from the spec (indices 0/1/2), hotkey from index 3
  unfocused, derived bright-yellow-on-focus-bg focused (RTL single
  hotkey slot cannot be right in both states). Default button marked
  [< >] via GUISEND cargo := .T. and Enter made real MC semantics:
  Enter on any non-button control fires the default (verified: checkbox
  -> OK applied; focused Cancel still wins over the default)
- Dialog checkboxes in MC colors: unfocused black-on-gray with red
  hotkey, focused black-on-cyan with yellow hotkey (was: all captions
  cyan at once). Vendored ChkDisplay override in mcbutton.prg; RTL
  CheckBox untouched
- Dialog radiogroups in MC colors: the selected row draws black-on-cyan
  with yellow hotkey, the other rows black-on-gray with red hotkeys
  (was: every row caption cyan at once). Vendored RadDisplay override in
  mcbutton.prg (RTL RadioButtn untouched); RTL marks every item focused
  when the group has focus, so the current row is taken from the
  selected item (lBuffer), which is how mc radiogroups read. Hotkey is
  painted by recoloring the existing caption letter in place (RTL
  DISPLAY keeps the "&" raw, which duplicated letters: "MMidnight");
  verified live with single colored hotkeys in Appearance, Listing
  format and Sort order. Verified live in Appearance, Listing format
  and Sort order (arrow keys move the highlight with the selection)
- Mouse inside dialogs verified live (xdotool at window-pixel coords):
  clicking a radio row selects it (Appearance -> Monochrome) and
  clicking a brackets button fires it, including the closing bracket
  (Print and Cancel both fired; Cancel left the theme untouched).
  BtnHitTest was instrumented to confirm the hit coords land on the
  control's own rect before the test was reverted
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
- Configuration dialog: 7 working checkboxes (Show hidden files, Show
  mini-status, Compute totals, Show free space, Auto save setup, Shell
  patterns, Mkdir autoname). Mkdir autoname verified live: with it on,
  F7 opens Make Directory prefilled with the name under the cursor
  (hbsubdir); with it off the GET opens empty
- Panel options: 6 working checkboxes (Mix all files, Show backup files,
  Mark moves down, Show hidden files, Lynx-like motion, File types
  highlight) - mark-moves-down off keeps the cursor on Insert.
  Lynx-like motion verified live both ways: Right enters the dir under
  the cursor, Left goes back to the parent. File types highlight
  verified live: executables render bright green (one stat pass per
  rescan, -L so a symlink takes its target's mode, broken links never
  shift the alignment); non-executables and symlinks unchanged
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

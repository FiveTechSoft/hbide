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
- Dialog buttons with solid Turbo Vision shadow
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
- Sort order dialog: radiogroup selection now applies (size sort verified
  live; per-panel sort state kept when the split changes)
- Layout: horizontal / vertical panel split
- Configuration dialog: 6 working checkboxes (Show hidden files, Show
  mini-status, Compute totals, Show free space, Auto save setup, Shell
  patterns)
- Panel options: 3 working checkboxes (Mix all files, Show backup files,
  Mark moves down) - mark-moves-down off keeps the cursor on Insert
- Options persist to ~/.hbmc.ini: save+load round-trip verified; Auto save
  setup saves the current options on quit

## Light (partial)

- Appearance dialog: radiogroup selection read fixed in code (same bug
  class as sort order); visual theme change not yet verified
- Confirmation dialog: 4 checkboxes (Delete, Overwrite, Execute, Exit);
  exit confirmation verified, the rest not yet exercised

## Pending (not implemented / not verified)

- Learn keys
- Listing mode custom formats

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

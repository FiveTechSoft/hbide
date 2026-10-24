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
- Hard link (inode verified)
- Background jobs dialog
- Edit external file, Edit menu file
- Dialog buttons with solid Turbo Vision shadow
- DlgInput: prefilled GET opens with cursor after the text (End + walk back
  over the PadR'd padding)

## Light (partial)

- Configuration dialog: 2 checkboxes of the ~10 mc has
- Panel options: 1 option of mc's set
- Symlink to a directory: listed as a plain dir; no '@' marker or target shown

## Pending (not implemented / not verified)

- Learn keys
- F10 Exit with confirmation dialog (code exists; final interactive test)
- Move: overwrite confirmation (Copy has the pattern; Move reuses it)
- Sort order dialog, Listing mode custom formats
- Layout / panel split options, Confirmation dialog options (subset exists)

## Env-blocked (out of demo scope by design)

- SMB VFS (needs an SMB server + credentials)
- extfs helpers that need extra packages (rpm/iso tools)
- chattr/chown operations requiring other-owner privileges
- Any network VFS needing credentials or private servers

## Known limits

- Keystroke injection (XTEST) can lose characters mid-session; tests drive
  the app in short batches with a verifying screenshot after each step.
- Dialog GET width follows the variable length (PadR), not @S pictures.

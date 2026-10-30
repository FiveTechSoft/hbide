#include "inkey.ch"
#include "setcurs.ch"
// hbide help topics: single source for Help>Contents and Help>Index.
// Each topic: { keyword list, title, body }

function HBIDEHelpTopics()

   local a := {}, aDoc

   AAdd( a, { "welcome hbide ide introduction", "Welcome to hbide", ;
      "hbide is a text-mode IDE for the Harbour language." + hb_eol() + hb_eol() + ;
      "It edits Harbour source with syntax colors, builds and runs it with hbmk2, " + ;
      "runs snippets in memory as scripts, and includes a visual dialog designer " + ;
      "(Options > Designer)." + hb_eol() + hb_eol() + ;
      "Menus open with the mouse or with Alt plus the highlighted letter " + ;
      "(for example Alt+F for File). The full list is in 'Keyboard shortcuts'." + hb_eol() + hb_eol() + ;
      "New here? Start with 'Quick start'. This manual covers every menu, projects, crash recovery, terminal setup and platform status." } )

   AAdd( a, { "quick start install build requirements first session hello clone", "Quick start", ;
      "What you need: a terminal on Linux, Windows, macOS or Android, and the hbmk2 build tool on PATH (or build harbour/core next to hbide; go.sh looks for ../harbour/bin/<platform>/<compiler>/hbmk2)." + hb_eol() + hb_eol() + ;
      "Build and start:" + hb_eol() + ;
      "git clone -b designer-robustness https://github.com/FiveTechSoft/hbide.git" + hb_eol() + ;
      "cd hbide" + hb_eol() + ;
      "hbmk2 hbide.hbp     (or ./go.sh, which also starts the IDE)" + hb_eol() + hb_eol() + ;
      "This produces ./hbide (hbide.exe on Windows)." + hb_eol() + hb_eol() + ;
      "First session:" + hb_eol() + ;
      "1. Type a few lines of code." + hb_eol() + ;
      "2. F2 saves; name the file (for example hello.prg). Every save keeps the previous disk version as .bak." + hb_eol() + ;
      "3. Run > Start builds with hbmk2 and runs the program only when the build succeeds; a failed build never runs a stale executable." + hb_eol() + ;
      "4. To debug: F9 on a line sets a breakpoint and Run > Debug stops there. F8 steps in, F10 steps over, F5 continues, Alt+X returns to the IDE." + hb_eol() + hb_eol() + ;
      "See 'The screen' for a map of the IDE and 'Using help' for this browser." } )

   AAdd( a, { "screen layout menu bar status bar ins ovr mark gutter diagram", "The screen", ;
      "Menu bar: Alt+letter opens a menu, arrows move, Enter runs the selected option, Esc closes." + hb_eol() + hb_eol() + ;
      " File Edit Project Window Run Options Help" + hb_eol() + ;
      "+----------- noname.prg -----------+" + hb_eol() + ;
      "| 1  function Main()               |" + hb_eol() + ;
      "| 2     ? 'Hello'   <- your code   |" + hb_eol() + ;
      "|                                  |" + hb_eol() + ;
      "+----------------------------------+" + hb_eol() + ;
      " INS  MARK          row: 2, col: 5" + hb_eol() + hb_eol() + ;
      "Status bar: INS or OVR (Ins toggles), MARK when a selection is anchored (F8), and the cursor position. A red mark in the gutter is a breakpoint (F9)." + hb_eol() + hb_eol() + ;
      "If the locale is not UTF-8 a 'Locale not UTF-8' notice appears on the right of the menu bar; see 'Terminal notes'." } )

   AAdd( a, { "file new open save as exit bak backup", "File menu", ;
      "New            Adds another independent document ('noname.prg') with a Harbour" + hb_eol() + ;
      "               starter template. Existing documents and unsaved changes stay open." + hb_eol() + hb_eol() + ;
      "Open...        Opens a .prg from the current directory or a typed file name." + hb_eol() + hb_eol() + ;
      "Save (F2)      Saves the buffer. On an unnamed buffer it asks for a name" + hb_eol() + ;
      "               (behaves as Save As). Before writing, the previous disk version" + hb_eol() + ;
      "               is kept as <file>.bak." + hb_eol() + hb_eol() + ;
      "Save As...     Saves the buffer under a new name and retitles the window." + hb_eol() + ;
      "               Asks before overwriting an existing file; its previous content" + hb_eol() + ;
      "               is still preserved as .bak." + hb_eol() + hb_eol() + ;
      "Exit           Leaves the IDE, asking about unsaved changes first." } )

   AAdd( a, { "edit undo redo copy paste delete duplicate line clipboard", "Edit menu", ;
      "Undo (Ctrl+Z) / Redo (Ctrl+U)   Text edit history (typing coalesces per line," + hb_eol() + ;
      "                                up to 300 operations)." + hb_eol() + hb_eol() + ;
      "Copy / Cut / Paste              Selection when marked; otherwise current line." + hb_eol() + hb_eol() + ;
      "Delete Line (Ctrl+Y)            Removes the current line." + hb_eol() + hb_eol() + ;
      "Duplicate Line                  Inserts a copy of the current line below." } )

   AAdd( a, { "find search replace goto repeat f3 f5", "Find, Replace, Goto Line", ;
      "Find... (F5)           Case-insensitive search from the cursor." + hb_eol() + ;
      "Repeat Last Find (F3)  Next match of the last search." + hb_eol() + ;
      "Replace...             Replaces every match in the buffer as ONE undoable" + hb_eol() + ;
      "                       operation (Ctrl+Z restores all of them)." + hb_eol() + ;
      "Goto Line...           Jumps to a line number." + hb_eol() + hb_eol() + ;
      "Search and replacement use free-form fields: leading and trailing blanks are kept." + hb_eol() + ;
      "An empty replacement deletes the matching text; an empty search is rejected." } )

   AAdd( a, { "keyboard shortcuts keys f1 f2 f3 f5 f8 f9 ctrl esc ins ovr word", "Keyboard shortcuts", ;
      "F1       Help            Ctrl+Z  Undo" + hb_eol() + ;
      "F2       Save            Ctrl+U  Redo" + hb_eol() + ;
      "F3       Find next       Ctrl+Y  Delete line" + hb_eol() + ;
      "F5       Find..." + hb_eol() + ;
      "F8       Mark selection  F9  Breakpoint" + hb_eol() + hb_eol() + ;
      "Esc closes dialogs; with a clean buffer it exits the IDE (with unsaved changes it asks first). Ins toggles insert/overwrite; the status bar shows INS or OVR." + hb_eol() + hb_eol() + ;
      "Ctrl+F6 / Ctrl+Shift+F6 switch to the next / previous document." + hb_eol() + hb_eol() + ;
      "Ctrl+Right / Alt+Left move by word. Ctrl+Left also jumps back on terminals that deliver extended key codes; otherwise it arrives as Undo." + hb_eol() + hb_eol() + ;
      "In dialogs: Tab/Shift+Tab moves between fields, Enter confirms, arrows move inside lists and radio groups, Space toggles check boxes." } )

   AAdd( a, { "run start script debug build hbmk2 compiler", "Run menu", ;
      "Start    Saves, then builds the current file with hbmk2 (must be on PATH)" + hb_eol() + ;
      "         using the flags from Options > Compiler Flags, and runs the" + hb_eol() + ;
      "         resulting program unless 'Run after build' is off." + hb_eol() + hb_eol() + ;
      "Script   Compiles the buffer in memory and runs it inside the IDE process." + hb_eol() + ;
      "         Runtime errors are shown in a dialog." + hb_eol() + hb_eol() + ;
      "Debug    Builds the current file with debug info and opens it in the" + hb_eol() + ;
      "         integrated Harbour debugger. Breakpoints set in the editor" + hb_eol() + ;
      "         with F9 (red gutter marks) are applied automatically." + hb_eol() + ;
      "         See the 'Debugger' topic." } )

   AAdd( a, { "debugger debug breakpoint watchpoint tracepoint step trace goto monitor", "Debugger", ;
      "Execution keys" + hb_eol() + ;
      "   F5 Go / stop at breakpoint   F7 Run to cursor   F8 Step into" + hb_eol() + ;
      "   F10 Trace over               Ctrl+F5 Next routine" + hb_eol() + ;
      "   Run > Animate steps automatically (Run > sPeed sets the pace)." + hb_eol() + ;
      "   F4 swaps to the application screen; File > Resume returns the view" + hb_eol() + ;
      "   to the execution point (it does NOT restart the program)." + hb_eol() + hb_eol() + ;
      "The first stop is on the wrapper's init procedure line, not on the" + hb_eol() + ;
      "first line of Main: press F5 or F7 to reach your code." + hb_eol() + hb_eol() + ;
      "Points" + hb_eol() + ;
      "   Breakpoints stop execution (F9 in the editor or in the debugger," + hb_eol() + ;
      "   Point menu, or 'BP <line>' in the Command window)." + hb_eol() + ;
      "   Watchpoints only display their value; they do not stop (upstream" + hb_eol() + ;
      "   Harbour semantics). Tracepoints stop when the value changes." + hb_eol() + hb_eol() + ;
      "Command window: ? <expr> evaluates, BP <n> toggles a breakpoint," + hb_eol() + ;
      "NUM ON/OFF toggles line numbers, ANIMATE starts animation." + hb_eol() + hb_eol() + ;
      "Windows: Tab / Shift+Tab cycle focus between the open windows" + hb_eol() + ;
      "(code, Monitor, Command...). Monitor menu shows variables by scope" + hb_eol() + ;
      "(Local, Static, Private, Public). 'Global' lists nothing: current" + hb_eol() + ;
      "Harbour does not implement GLOBAL variables (xHarbour-only legacy)." + hb_eol() + hb_eol() + ;
      "Options > Save/Restore Settings persists colors, tab width, monitor" + hb_eol() + ;
      "flags and breakpoints to init.cld and applies them back." + hb_eol() + hb_eol() + ;
      "Window > Move/Size/Zoom/Tile/Cascade manages debugger panels." + hb_eol() + ;
      "Not implemented: Iconize, Options Exchange Screens," + hb_eol() + ;
      "swap on Input, Menu Bar." } )

   AAdd( a, { "options compiler flags display designer strict warnings incremental optimize", "Options menu", ;
      "Compiler Flags...   Build options used by Run > Start:" + hb_eol() + ;
      "   Compiler       -comp= (gcc, msvc, bcc, clang)" + hb_eol() + ;
      "   Warnings       -w3 when on, -w0 when off" + hb_eol() + ;
      "   Debug info     -b (line info for the debugger)" + hb_eol() + ;
      "   Strict types   -es2 (warnings are fatal)" + hb_eol() + ;
      "   Incremental    -inc" + hb_eol() + ;
      "   Optimize code  -O2" + hb_eol() + ;
      "   Run after build  when off, Run > Start only builds" + hb_eol() + hb_eol() + ;
      "Display...          Console size for the IDE window." + hb_eol() + hb_eol() + ;
      "Designer...         Visual dialog designer: palette, object inspector," + hb_eol() + ;
      "                    JSON save/load and PRG code generation." } )

   AAdd( a, { "external changes disk watch reload overwrite deleted", "External file changes", ;
      "While you edit, the IDE watches the file on disk (about every 2 seconds)." + hb_eol() + hb_eol() + ;
      "- Buffer clean: the file is reloaded and you are told." + hb_eol() + ;
      "- Buffer dirty: you choose Reload or Keep mine." + hb_eol() + ;
      "- File deleted outside: the buffer is kept; saving asks before recreating." + hb_eol() + hb_eol() + ;
      "The watch compares date+time+size plus a content checksum, so even a" + hb_eol() + ;
      "same-size edit that keeps the file timestamp is caught. Coverage: the" + hb_eol() + ;
      "checksum applies to files up to 8 MB (measured cost ~13 ms per check);" + hb_eol() + ;
      "larger files compare date+time+size only and you are told when opening" + hb_eol() + ;
      "them. A reload keeps your cursor where it was." } )

   AAdd( a, { "window documents buffers ctrl+f6 switch multiple close next previous", "Multiple documents", ;
      "File > New and File > Open... add documents; Window > Next (Ctrl+F6) and Previous (Ctrl+Shift+F6) switch between them." + hb_eol() + hb_eol() + ;
      "Each document keeps its own text, name, dirty flag, undo/redo history, cursor, scroll, selection and breakpoints." + hb_eol() + hb_eol() + ;
      "Window > Close and File > Close ask only about the current document; Exit reviews all of them. Save As refuses to overwrite a path that is open in another document." } )

   AAdd( a, { "save atomic bak backup safety overwrite verified write", "Saving and safety", ;
      "Saves are atomic: a temporary file on the same volume replaces the original only after a verified write, and the previous version is kept as .bak." + hb_eol() + hb_eol() + ;
      "hbide watches the file on disk: if it changes externally you choose Reload or Keep mine; saving over external changes asks first; if the file was deleted you can recreate it or cancel. See 'External file changes'." + hb_eol() + hb_eol() + ;
      "Run > Start saves before building; a blocked save cancels the build instead of compiling stale disk content." } )

   AAdd( a, { "crash recovery journal unsaved restore killed autosave", "Crash recovery", ;
      "While a buffer has unsaved changes, hbide keeps a journal of its full text in ~/.hbide/recovery (override with HBIDE_RECOVERY_DIR), refreshed on the 2-second tick of the main loop and written atomically." + hb_eol() + hb_eol() + ;
      " editing (unsaved changes)" + hb_eol() + ;
      "         |  every 2 s while dirty" + hb_eol() + ;
      "         v" + hb_eol() + ;
      " journal in ~/.hbide/recovery" + hb_eol() + ;
      "         |  hbide killed or crashes" + hb_eol() + ;
      "         v" + hb_eol() + ;
      " next start: journal found" + hb_eol() + ;
      "+---------+---------+-------+" + hb_eol() + ;
      "| Recover | Discard | Later |" + hb_eol() + ;
      "+---------+---------+-------+" + hb_eol() + hb_eol() + ;
      "Recover: the text returns as an unsaved buffer. Discard: the journal is deleted. Later: the journal stays for the next start." + hb_eol() + hb_eol() + ;
      "What to expect: you get the content of the last 2-second tick, not of every keystroke. Unnamed buffers are recovered too. Each running instance keeps its own journal, so saving or discarding in one never deletes another instance's unsaved work. If the journal cannot be written, editing continues and hbide warns once per failure streak; recovery is never silently assumed. One journal per absolute path: aliases or symlinks to the same file produce separate journals." } )

   AAdd( a, { "about version harbour fivetech", "About hbide", ;
      "hbide - Harbour IDE" + hb_eol() + ;
      "FiveTechSoft - https://github.com/FiveTechSoft/hbide" + hb_eol() + hb_eol() + ;
      "Written in Harbour. Uses the Harbour compiler and hbmk2." + hb_eol() + ;
      "The same information is in Help > About..." } )

   AAdd( a, { "help links history contextual f1 back forward", "Using help", ;
      "F1 opens help for the selected menu or the editor. Related topics at the " + ;
      "bottom are live links: Tab/Shift+Tab selects one, Enter follows it, or " + ;
      "click its label." + hb_eol() + hb_eol() + ;
      "Backspace returns to the previous topic and scroll position. Alt+Right " + ;
      "moves forward again. Up/Down, PageUp/PageDown, Home and End scroll " + ;
      "the current topic. Esc closes help without changing your source." + hb_eol() + hb_eol() + ;
      "The Help menu still offers Contents and keyword Index. Topics describe " + ;
      "implemented behavior, including remaining limits, rather than promising " + ;
      "features that are not available." } )

   AAdd( a, { "compiler flags warnings strict debug optimize hbmk2 mingw", "Compiler flags", ;
      "Options > Compiler Flags controls Run > Start. Choose the compiler that " + ;
      "exists in your Harbour installation. Windows defaults to MinGW64; " + ;
      "Linux defaults to GCC." + hb_eol() + hb_eol() + ;
      "Warnings: -w3 when on, -w0 when off. Strict types: -es2 makes warnings " + ;
      "fatal. Debug info: -b. Incremental: -inc. Optimize code: -O2." + hb_eol() + hb_eol() + ;
      "Run after build off means build only. A failed build must never launch " + ;
      "a stale executable. Run > Debug compiles with debug information for the " + ;
      "integrated debugger separately." + hb_eol() + hb_eol() + ;
      "OK applies the choices. Cancel or Esc leaves the previous choices " + ;
      "unchanged. The Help button opens this topic and returns to the dialog." } )

   AAdd( a, { "project hbp sources build messages diagnostics desktop open close", "Projects", ;
      "Project > Open .hbp... reads a project file: members (sources, subprojects, configuration) are listed, and entries it cannot resolve (macros, wildcards, filters) are shown as such, never guessed." + hb_eol() + hb_eol() + ;
      "Project > Sources / Build... opens the project desktop: source list, build with hbmk2 and a Messages view with the parsed diagnostics (file(line) Error/Warning for Harbour, file:line:col: for GCC). Selecting a diagnostic opens the file at that line and column." + hb_eol() + hb_eol() + ;
      "A build reports success only from this build's exit code, never from an executable left by an earlier one. Project > Close project closes the project." } )

   AAdd( a, { "display settings rows columns console font", "Display settings", ;
      "Options > Display changes the console size used by the IDE. The " + ;
      "available presets are 25x80, 30x100 and 40x120." + ;
      hb_eol() + hb_eol() + ;
      "Choose a size that leaves source text and dialog controls readable. " + ;
      "Apply changes with OK; Cancel keeps the existing size. This changes " + ;
      "the console grid, not the size of your generated dialog model." } )

   AAdd( a, { "terminal utf-8 locale xterm alt meta size linux glyphs", "Terminal notes", ;
      "Use a UTF-8 locale (LANG=...UTF-8): borders, buttons and shadows are CP437 glyphs that only render correctly in UTF-8 mode. hbide shows a 'Locale not UTF-8' notice otherwise." + hb_eol() + hb_eol() + ;
      "Alt+letter needs the terminal to send a meta ESC prefix. In xterm, start it with -xrm 'XTerm*metaSendsEscape: true'." + hb_eol() + hb_eol() + ;
      "The IDE is tested at 25x80 and 40x120 (see 'Display settings')." } )

   AAdd( a, { "platform status limits windows linux roadmap known pending", "Platform status and limits", ;
      "Verified interactively and with automated tests on Linux." + hb_eol() + hb_eol() + ;
      "Windows: the IDE builds with GTWVT and a prebuilt hbide.exe is included, but it can lag behind the sources; validating the latest sources on Windows is still pending." + hb_eol() + hb_eol() + ;
      "Debugger Animate has known visual defects; F4 shows the program screen to recover the view. Exchange Screens and swap on Input are not implemented (see 'Debugger windows')." + hb_eol() + hb_eol() + ;
      "The full plan and per-area status live in docs/COMPLETION_ROADMAP.md in the repository." } )

   AAdd( a, { "designer palette inspector controls code generation json", "Dialog designer", ;
      "Options > Designer opens the visual dialog designer. Place labels, " + ;
      "inputs, checkboxes, radio groups, listboxes, selection-only ComboBox and buttons. Move and " + ;
      "resize controls with the mouse; use the inspector to edit properties." + ;
      hb_eol() + hb_eol() + ;
      "In the F2 palette, a duplicated letter cycles its matching options without executing; Enter runs the selected option and Esc cancels. A unique letter still runs immediately. The designer saves its model as JSON and generates Harbour PRG source. " + ;
      "The generated source can be opened in the editor after leaving the " + ;
      "designer. Preserve manually written source separately from generated " + ;
      "output. A live generated-code preview does not imply bidirectional " + ;
      "editing of arbitrary Harbour code." } )

   AAdd( a, { "debugger windows move size zoom tile cascade focus", "Debugger windows", ;
      "Window > Tile arranges visible source, Monitor, Watch, Calls and " + ;
      "Command panels without overlap. Window > Cascade overlaps them. " + ;
      "Tab and Shift+Tab cycle focus; clicking a visible panel brings it forward." + ;
      hb_eol() + hb_eol() + ;
      "F2 or Window > Zoom maximizes the focused panel. Invoke it again to " + ;
      "restore its previous rectangle. Window > Move and Size use arrow keys; " + ;
      "Enter accepts and Esc cancels. Menu and status rows remain outside " + ;
      "the desktop. Commands Window Tile, Cascade, Zoom, Move and Size " + ;
      "provide the same actions. Numeric Window Move row column and Window Size height width commands stay inside the desktop; malformed parameters leave geometry unchanged." + hb_eol() + hb_eol() + ;
      "Manual layouts remain through stepping. Save/Restore Settings can " + ;
      "store panel rectangles. Window > Iconize shrinks the focused panel; " + ;
      "invoke it again to restore its geometry and browser viewport. The legacy Exchange Screens, " + ;
      "swap on Input actions are not implemented. Menu Bar toggles the debugger bar; Alt+O temporarily opens Options while hidden, M makes the bar visible again, Esc hides a temporary menu. F10 remains Trace. Options MenuBar ON/OFF is saved in settings. Application " + ;
      "output during Animate can still damage the display; F4 shows the app screen." } )
   FOR EACH aDoc IN HBIDEHelpDocTopics()
      AAdd( a, aDoc )
   NEXT
return a

//-----------------------------------------------------------------------------------------//
// Tree-organized help browser: index on the left, reading pane on the right,
// TurboVision-style cyan panels and green shadowed buttons.
// Contents keeps every existing topic; browsing changes no application state.

// Section spec: every topic exactly once, in reading order.
FUNCTION HBIDEHelpSections()
   LOCAL aDoc, aSections := { { "1. Basics", { "Welcome to hbide", "Quick start", "The screen", ;
         "Keyboard shortcuts" } }, ;
       { "2. Editing and files", { "File menu", "Edit menu", ;
         "Find, Replace, Goto Line", "Multiple documents", "Saving and safety", ;
         "External file changes", "Crash recovery" } }, ;
       { "3. Build and run", { "Run menu", "Compiler flags", "Projects" } }, ;
       { "4. Advanced", { "Debugger", "Debugger windows", "Dialog designer", ;
         "Options menu", "Display settings" } }, ;
       { "5. Help and about", { "Using help", "Terminal notes", ;
         "Platform status and limits", "About hbide" } } }
   FOR EACH aDoc IN HBIDEHelpDocSections()
      AAdd( aSections, aDoc )
   NEXT
RETURN aSections

// Flat row list for the index pane: { "S", nSection, cTitle } or { "T", nTopic, cTitle }
FUNCTION HBIDEHelpTree( aTopics )
   LOCAL aRows := {}, aSec, cTitle, nTopic, nSec := 0
   FOR EACH aSec IN HBIDEHelpSections()
      nSec++
      AAdd( aRows, { "S", nSec, aSec[ 1 ] } )
      FOR EACH cTitle IN aSec[ 2 ]
         nTopic := AScan( aTopics, { | t | t[ 2 ] == cTitle } )
         IF nTopic > 0
            AAdd( aRows, { "T", nTopic, cTitle } )
         ENDIF
      NEXT
   NEXT
RETURN aRows

// Section overview shown in the reading pane when a header row is selected.
FUNCTION HBIDEHelpSectionText( nSection, aTopics )
   LOCAL aSec := HBIDEHelpSections()[ nSection ]
   LOCAL c := aSec[ 1 ] + hb_eol() + hb_eol(), cTitle, nTopic
   FOR EACH cTitle IN aSec[ 2 ]
      nTopic := AScan( aTopics, { | t | t[ 2 ] == cTitle } )
      IF nTopic > 0
         c += "- " + cTitle + ": " + HBHelpOneLine( hb_ATokens( StrTran( aTopics[ nTopic, 3 ], Chr(13), "" ), Chr(10) )[ 1 ] ) + hb_eol()
      ENDIF
   NEXT
   c += hb_eol() + "Enter opens the highlighted entry; Down moves to its topics."
RETURN c

// First line of a topic as a one-line summary: aligned columns collapse.
FUNCTION HBHelpOneLine( cLine )
   DO WHILE "  " $ cLine
      cLine := StrTran( cLine, "  ", " " )
   ENDDO
RETURN AllTrim( cLine )

// All matches of cQuery (already uppercased) over titles and wrapped bodies.
// Each match: { nTopic, nLine } with nLine over HBIDEHelpLines( body, nW ).
FUNCTION HBIDEHelpMatches( aTopics, nW, cQuery )
   LOCAL a := {}, nT, nL, aLines
   IF Empty( cQuery )
      RETURN a
   ENDIF
   FOR nT := 1 TO Len( aTopics )
      IF cQuery $ Upper( aTopics[ nT, 2 ] )
         AAdd( a, { nT, 1 } )
      ENDIF
      aLines := HBIDEHelpLines( aTopics[ nT, 3 ], nW )
      FOR nL := 1 TO Len( aLines )
         IF cQuery $ Upper( aLines[ nL ] )
            AAdd( a, { nT, nL } )
         ENDIF
      NEXT
   NEXT
RETURN a

// Full help as one Markdown document, in tree order. Returns .T. on success.
FUNCTION HBIDEHelpExport( aTopics, cFile )
   LOCAL c := "# hbide - Help" + hb_eol() + hb_eol(), aRow
   FOR EACH aRow IN HBIDEHelpTree( aTopics )
      IF aRow[ 1 ] == "S"
         c += "## " + aRow[ 3 ] + hb_eol() + hb_eol()
      ELSE
         c += "### " + aRow[ 3 ] + hb_eol() + hb_eol() + aTopics[ aRow[ 2 ], 3 ] + hb_eol() + hb_eol()
      ENDIF
   NEXT
RETURN hb_MemoWrit( cFile, c )

// Modal geometry, all coordinates absolute.
FUNCTION HBHelpGeo()
   LOCAL g := { "t" => 1, "l" => 0, "b" => MaxRow() - 1, "r" => MaxCol() }
   g[ "lbT" ] := g[ "t" ] + 3
   g[ "lbB" ] := g[ "b" ] - 5
   g[ "lbL" ] := g[ "l" ] + 1
   g[ "lbR" ] := g[ "l" ] + 29
   g[ "rbT" ] := g[ "t" ] + 3
   g[ "rbB" ] := g[ "b" ] - 5
   g[ "rbL" ] := g[ "l" ] + 31
   g[ "rbR" ] := g[ "r" ] - 1
   g[ "txtW" ] := g[ "rbR" ] - g[ "rbL" ] - 3
   g[ "txtH" ] := g[ "rbB" ] - g[ "rbT" ] - 2
   g[ "idxH" ] := g[ "lbB" ] - g[ "lbT" ] - 1
   g[ "msgRow" ] := g[ "b" ] - 3
   g[ "btnRow" ] := g[ "b" ] - 2
   g[ "btnCaps" ] := { "Search", "Next", "Export .md", "Close" }
RETURN g

FUNCTION HBHelpBtnCols( g )
   LOCAL aCols := {}, nX := g[ "l" ] + 4, cCap
   FOR EACH cCap IN g[ "btnCaps" ]
      AAdd( aCols, { nX, nX + Len( cCap ) + 5 } )
      nX += Len( cCap ) + 7
   NEXT
RETURN aCols

// TurboVision-style shadow: half-block cell right of the face (lower half)
// and a half-block strip below it (upper half), shifted one cell - the slim
// classic TV look, same as the dialog buttons. On non-UTF8 terminals (where
// gttrm cannot map the half blocks) solid dark cells are used instead.
FUNCTION HBHelpBtnShadow( nRow, nCol, nLen )
   LOCAL i
   IF HBBtnShadowUtf8()
      hb_DispOutAt( nRow, nCol + nLen, hb_UTF8ToStr( "▄" ), "N/BG" )
      FOR i = 1 TO nLen
         hb_DispOutAt( nRow + 1, nCol + i, hb_UTF8ToStr( "▀" ), "N/BG" )
      NEXT
   ELSE
      hb_DispOutAt( nRow, nCol + nLen, " ", "N/N" )
      FOR i = 1 TO nLen
         hb_DispOutAt( nRow + 1, nCol + i, " ", "N/N" )
      NEXT
   ENDIF
RETURN NIL

// Title and wrapped lines of the selected entry (section overview or topic).
FUNCTION HBHelpText( h, aTopics, nW )
   LOCAL aRow := h[ "rows" ][ h[ "row" ] ]
   IF aRow[ 1 ] == "S"
      RETURN { aRow[ 3 ], HBIDEHelpLines( HBIDEHelpSectionText( aRow[ 2 ], aTopics ), nW ) }
   ENDIF
RETURN { aTopics[ aRow[ 2 ], 2 ], HBIDEHelpLines( aTopics[ aRow[ 2 ], 3 ], nW ) }

// Row index of a topic inside the flat row list (0 if absent).
FUNCTION HBHelpRowOfTopic( h, nTopic )
   LOCAL n
   FOR n := 1 TO Len( h[ "rows" ] )
      IF h[ "rows" ][ n ][ 1 ] == "T" .AND. h[ "rows" ][ n ][ 2 ] == nTopic
         RETURN n
      ENDIF
   NEXT
RETURN 0

FUNCTION HBHelpJump( h, nMatch )
   LOCAL aM := h[ "matches" ][ nMatch ]
   LOCAL nRow := HBHelpRowOfTopic( h, aM[ 1 ] )
   IF nRow > 0
      h[ "row" ] := nRow
      h[ "top" ] := aM[ 2 ]
   ENDIF
   h[ "midx" ] := nMatch
   h[ "msg" ] := "Match " + hb_ntos( nMatch ) + "/" + hb_ntos( Len( h[ "matches" ] ) ) + ;
                 " for '" + h[ "query" ] + "'"
RETURN NIL

FUNCTION HBHelpNext( h, aTopics, g )
   IF Empty( h[ "query" ] )
      h[ "msg" ] := "No search yet: F7 or the Search button first."
   ELSE
      IF Empty( h[ "matches" ] )
         h[ "matches" ] := HBIDEHelpMatches( aTopics, g[ "txtW" ], Upper( h[ "query" ] ) )
      ENDIF
      IF Empty( h[ "matches" ] )
         h[ "msg" ] := "No match for '" + h[ "query" ] + "'."
      ELSE
         HBHelpJump( h, iif( h[ "midx" ] >= Len( h[ "matches" ] ), 1, h[ "midx" ] + 1 ) )
      ENDIF
   ENDIF
RETURN NIL

FUNCTION HBHelpSearchCommit( h, aTopics, g )
   h[ "mode" ] := ""
   IF Empty( h[ "query" ] )
      h[ "matches" ] := {}; h[ "midx" ] := 0
      h[ "msg" ] := "Empty search."
   ELSE
      h[ "matches" ] := HBIDEHelpMatches( aTopics, g[ "txtW" ], Upper( h[ "query" ] ) )
      IF Empty( h[ "matches" ] )
         h[ "midx" ] := 0
         h[ "msg" ] := "No match for '" + h[ "query" ] + "'."
      ELSE
         HBHelpJump( h, 1 )
      ENDIF
   ENDIF
RETURN NIL

FUNCTION HBHelpButton( h, aTopics, g, nBtn )
   DO CASE
   CASE nBtn == 1
      h[ "mode" ] := "search"
   CASE nBtn == 2
      HBHelpNext( h, aTopics, g )
   CASE nBtn == 3
      IF HBIDEHelpExport( aTopics, "hbide-help.md" )
         h[ "msg" ] := "Wrote hbide-help.md (" + hb_ntos( Len( h[ "rows" ] ) ) + " entries)."
      ELSE
         h[ "msg" ] := "Could not write hbide-help.md in this directory."
      ENDIF
   CASE nBtn == 4
      h[ "done" ] := .T.
   ENDCASE
RETURN NIL

FUNCTION HBHelpPaint( h, aTopics, g )
   LOCAL n, aRow, cLine, aTxt, nMaxTop, aCols, cCap
   DispBegin()
   hb_Scroll( g[ "t" ], g[ "l" ], g[ "b" ], g[ "r" ], , , "N/BG" )
   hb_DispBox( g[ "t" ], g[ "l" ], g[ "b" ], g[ "r" ], hb_UTF8ToStrBox( "┌─┐│┘─└│" ), "W+/BG" )
   hb_DispOutAt( g[ "t" ], g[ "l" ] + 2, " hbide - Help ", "W+/BG" )
   hb_DispOutAt( g[ "t" ] + 1, g[ "l" ] + 2, "Tab pane  F7 search  F3 next match  Esc close", "N/BG" )
   // keep index cursor visible (also after search jumps, which skip input)
   IF h[ "row" ] < h[ "itop" ]
      h[ "itop" ] := h[ "row" ]
   ELSEIF h[ "row" ] > h[ "itop" ] + g[ "idxH" ] - 1
      h[ "itop" ] := h[ "row" ] - g[ "idxH" ] + 1
   ENDIF
   h[ "itop" ] := Min( Max( 1, Len( h[ "rows" ] ) - g[ "idxH" ] + 1 ), Max( 1, h[ "itop" ] ) )
   // index pane
   hb_DispBox( g[ "lbT" ], g[ "lbL" ], g[ "lbB" ], g[ "lbR" ], hb_UTF8ToStrBox( "┌─┐│┘─└│" ), ;
               iif( h[ "pane" ] == "index", "W+/BG", "N/BG" ) )
   hb_DispOutAt( g[ "lbT" ], g[ "lbL" ] + 2, " Index ", iif( h[ "pane" ] == "index", "W+/BG", "N/BG" ) )
   FOR n := 1 TO g[ "idxH" ]
      IF h[ "itop" ] + n - 1 <= Len( h[ "rows" ] )
         aRow := h[ "rows" ][ h[ "itop" ] + n - 1 ]
         cLine := iif( aRow[ 1 ] == "S", aRow[ 3 ], "  " + aRow[ 3 ] )
         IF h[ "itop" ] + n - 1 == h[ "row" ]
            hb_DispOutAt( g[ "lbT" ] + n, g[ "lbL" ] + 1, PadR( cLine, g[ "lbR" ] - g[ "lbL" ] - 1 ), "N/W" )
         ELSE
            hb_DispOutAt( g[ "lbT" ] + n, g[ "lbL" ] + 1, PadR( cLine, g[ "lbR" ] - g[ "lbL" ] - 1 ), ;
                          iif( aRow[ 1 ] == "S", "W+/BG", "N/BG" ) )
         ENDIF
      ELSE
         hb_DispOutAt( g[ "lbT" ] + n, g[ "lbL" ] + 1, Space( g[ "lbR" ] - g[ "lbL" ] - 1 ), "N/BG" )
      ENDIF
   NEXT
   // reading pane
   aTxt := HBHelpText( h, aTopics, g[ "txtW" ] )
   nMaxTop := Max( 1, Len( aTxt[ 2 ] ) - g[ "txtH" ] + 1 )
   h[ "top" ] := Min( nMaxTop, Max( 1, h[ "top" ] ) )
   hb_DispBox( g[ "rbT" ], g[ "rbL" ], g[ "rbB" ], g[ "rbR" ], hb_UTF8ToStrBox( "┌─┐│┘─└│" ), ;
               iif( h[ "pane" ] == "text", "W+/BG", "N/BG" ) )
   hb_DispOutAt( g[ "rbT" ], g[ "rbL" ] + 2, " " + Left( aTxt[ 1 ], g[ "txtW" ] ) + " ", ;
                 iif( h[ "pane" ] == "text", "W+/BG", "N/BG" ) )
   FOR n := 1 TO g[ "txtH" ]
      cLine := iif( h[ "top" ] + n - 1 <= Len( aTxt[ 2 ] ), aTxt[ 2 ][ h[ "top" ] + n - 1 ], "" )
      hb_DispOutAt( g[ "rbT" ] + n, g[ "rbL" ] + 2, PadR( Left( cLine, g[ "txtW" ] ), g[ "txtW" ] ), "N/BG" )
   NEXT
   hb_DispOutAt( g[ "rbB" ], g[ "rbL" ] + 2, " " + hb_ntos( h[ "top" ] ) + "/" + hb_ntos( nMaxTop ) + " ", "N/BG" )
   // search / message line
   IF h[ "mode" ] == "search"
      hb_DispOutAt( g[ "msgRow" ], g[ "l" ] + 2, PadR( "Search: " + h[ "query" ] + "_", g[ "r" ] - 4 ), "Y+/BG" )
   ELSE
      hb_DispOutAt( g[ "msgRow" ], g[ "l" ] + 2, PadR( h[ "msg" ], g[ "r" ] - 4 ), "Y+/BG" )
   ENDIF
   // green shadowed buttons
   aCols := HBHelpBtnCols( g )
   FOR n := 1 TO Len( g[ "btnCaps" ] )
      cCap := "  " + g[ "btnCaps" ][ n ] + "  "
      HBHelpBtnShadow( g[ "btnRow" ], aCols[ n ][ 1 ], Len( cCap ) )
      hb_DispOutAt( g[ "btnRow" ], aCols[ n ][ 1 ], cCap, ;
                    iif( h[ "pane" ] == "buttons" .AND. h[ "btn" ] == n, "W+/G", "W/G" ) )
   NEXT
   DispEnd()
RETURN NIL

FUNCTION HBHelpInput( h, aTopics, g, nKey )
   LOCAL aCols, n
   IF h[ "mode" ] == "search"
      DO CASE
      CASE nKey == K_ESC
         h[ "mode" ] := ""
         h[ "msg" ] := "Search cancelled."
      CASE nKey == K_ENTER
         HBHelpSearchCommit( h, aTopics, g )
      CASE nKey == K_BS
         h[ "query" ] := Left( h[ "query" ], Max( 0, Len( h[ "query" ] ) - 1 ) )
      CASE nKey >= 32 .AND. nKey <= 126 .AND. Len( h[ "query" ] ) < 30
         h[ "query" ] += Chr( nKey )
      ENDCASE
      RETURN NIL
   ENDIF
   DO CASE
   CASE nKey == K_ESC
      h[ "done" ] := .T.
   CASE nKey == K_TAB
      h[ "pane" ] := iif( h[ "pane" ] == "index", "text", iif( h[ "pane" ] == "text", "buttons", "index" ) )
   CASE nKey == K_SH_TAB
      h[ "pane" ] := iif( h[ "pane" ] == "index", "buttons", iif( h[ "pane" ] == "text", "index", "text" ) )
   CASE nKey == K_F7
      h[ "mode" ] := "search"
   CASE nKey == K_F3
      HBHelpNext( h, aTopics, g )
   CASE nKey == K_MWFORWARD
      h[ "top" ]--
   CASE nKey == K_MWBACKWARD
      h[ "top" ]++
   CASE nKey == K_LBUTTONDOWN
      IF MRow() > g[ "lbT" ] .AND. MRow() <= g[ "lbT" ] + g[ "idxH" ] .AND. MCol() >= g[ "lbL" ] .AND. MCol() <= g[ "lbR" ]
         IF h[ "itop" ] + MRow() - g[ "lbT" ] - 1 + 1 <= Len( h[ "rows" ] )
            h[ "row" ] := Min( Len( h[ "rows" ] ), h[ "itop" ] + MRow() - g[ "lbT" ] )
            h[ "top" ] := 1
         ENDIF
         h[ "pane" ] := "index"
      ELSEIF MRow() > g[ "rbT" ] .AND. MRow() < g[ "rbB" ] .AND. MCol() >= g[ "rbL" ] .AND. MCol() <= g[ "rbR" ]
         h[ "pane" ] := "text"
      ELSEIF MRow() == g[ "btnRow" ]
         aCols := HBHelpBtnCols( g )
         FOR n := 1 TO Len( aCols )
            IF MCol() >= aCols[ n ][ 1 ] .AND. MCol() < aCols[ n ][ 2 ]
               h[ "pane" ] := "buttons"; h[ "btn" ] := n
               HBHelpButton( h, aTopics, g, n )
            ENDIF
         NEXT
      ENDIF
   CASE h[ "pane" ] == "index"
      DO CASE
      CASE nKey == K_UP    ; h[ "row" ]--
      CASE nKey == K_DOWN  ; h[ "row" ]++
      CASE nKey == K_HOME  ; h[ "row" ] := 1
      CASE nKey == K_END   ; h[ "row" ] := Len( h[ "rows" ] )
      CASE nKey == K_PGUP  ; h[ "row" ] -= g[ "idxH" ]
      CASE nKey == K_PGDN  ; h[ "row" ] += g[ "idxH" ]
      CASE nKey == K_ENTER .OR. nKey == K_RIGHT
         h[ "pane" ] := "text"
      ENDCASE
      h[ "row" ] := Min( Len( h[ "rows" ] ), Max( 1, h[ "row" ] ) )
      IF nKey == K_UP .OR. nKey == K_DOWN .OR. nKey == K_HOME .OR. nKey == K_END .OR. ;
         nKey == K_PGUP .OR. nKey == K_PGDN
         h[ "top" ] := 1
      ENDIF
   CASE h[ "pane" ] == "text"
      DO CASE
      CASE nKey == K_UP    ; h[ "top" ]--
      CASE nKey == K_DOWN  ; h[ "top" ]++
      CASE nKey == K_PGUP  ; h[ "top" ] -= g[ "txtH" ]
      CASE nKey == K_PGDN  ; h[ "top" ] += g[ "txtH" ]
      CASE nKey == K_HOME  ; h[ "top" ] := 1
      CASE nKey == K_END   ; h[ "top" ] := 99999
      CASE nKey == K_LEFT  ; h[ "row" ] := Max( 1, h[ "row" ] - 1 ) ; h[ "top" ] := 1
      CASE nKey == K_RIGHT ; h[ "row" ] := Min( Len( h[ "rows" ] ), h[ "row" ] + 1 ) ; h[ "top" ] := 1
      CASE nKey == K_ENTER ; h[ "pane" ] := "index"
      ENDCASE
   CASE h[ "pane" ] == "buttons"
      DO CASE
      CASE nKey == K_LEFT  ; h[ "btn" ] := iif( h[ "btn" ] > 1, h[ "btn" ] - 1, Len( g[ "btnCaps" ] ) )
      CASE nKey == K_RIGHT ; h[ "btn" ] := h[ "btn" ] % Len( g[ "btnCaps" ] ) + 1
      CASE nKey == K_ENTER ; HBHelpButton( h, aTopics, g, h[ "btn" ] )
      CASE nKey == K_UP    ; h[ "pane" ] := "index"
      ENDCASE
   ENDCASE
   // keep index cursor visible
   IF h[ "row" ] < h[ "itop" ]
      h[ "itop" ] := h[ "row" ]
   ELSEIF h[ "row" ] > h[ "itop" ] + g[ "idxH" ] - 1
      h[ "itop" ] := h[ "row" ] - g[ "idxH" ] + 1
   ENDIF
   h[ "itop" ] := Min( Max( 1, Len( h[ "rows" ] ) - g[ "idxH" ] + 1 ), Max( 1, h[ "itop" ] ) )
RETURN NIL

// The browser itself: tree index left, reading pane right, buttons below.
// nStartTopic is a 1-based index into aTopics (0 = start at the tree root).
FUNCTION HBIDEHelpBrowser( aTopics, nStartTopic )
   LOCAL g := HBHelpGeo()
   LOCAL h := { "rows" => HBIDEHelpTree( aTopics ), "row" => 1, "itop" => 1, ;
                "pane" => "index", "top" => 1, "btn" => 1, "query" => "", ;
                "matches" => {}, "midx" => 0, "msg" => "", "mode" => "", ;
                "done" => .F. }
   LOCAL cSaved := __dbgSaveScreen( 0, 0, MaxRow(), MaxCol() ), nRow
   LOCAL cOldCDP
   // UTF-8 host CP + display translation while the browser runs (same setup
   // as demos/foxpro.prg) so the half-block button shades render; the IDE
   // pins CP437 by default, which would show them as "?". Restored on exit.
   cOldCDP := hb_cdpSelect( "UTF8" )
   hb_SetDispCP( "EN", "UTF8", .T. )
   IF nStartTopic > 0
      nRow := HBHelpRowOfTopic( h, nStartTopic )
      IF nRow > 0
         h[ "row" ] := nRow
      ENDIF
   ENDIF
   DO WHILE ! h[ "done" ]
      HBHelpPaint( h, aTopics, g )
      HBHelpInput( h, aTopics, g, hb_keyStd( Inkey( 0, INKEY_ALL + HB_INKEY_EXT ) ) )
   ENDDO
   hb_cdpSelect( cOldCDP )
   hb_SetDispCP( "EN" )
   __dbgRestScreen( 0, 0, MaxRow(), MaxCol(), cSaved )
RETURN .T.

FUNCTION HBIDEHelpLines( cText, nWidth )
   LOCAL a := {}, cLine, aSource := hb_ATokens( StrTran( cText, Chr(13), "" ), Chr(10) )
   FOR EACH cLine IN aSource
      HBHelpWrapLine( a, cLine, nWidth )
   NEXT
   IF Empty( a )
      AAdd( a, "" )
   ENDIF
   RETURN a

// Wraps one source line at word boundaries. A line that is a table row (key
// column, 3+ spaces, description) wraps its description under the description
// column; any other line keeps its own indent. A word is cut only when it is
// longer than the room that is left.
STATIC PROCEDURE HBHelpWrapLine( a, cLine, nWidth )
   LOCAL nIndent, nHang, nGap, nRoom, cHead, cRest, nCut, n
   cLine := RTrim( cLine )
   IF Len( cLine ) <= nWidth
      AAdd( a, cLine )
      RETURN
   ENDIF
   nIndent := Min( Len( cLine ) - Len( LTrim( cLine ) ), Max( 0, nWidth - 14 ) )
   nHang := nIndent
   // table row: first run of 3+ spaces after the key text
   nGap := hb_At( "   ", cLine, nIndent + 1 )
   IF nGap > 0
      nHang := nGap - 1
      DO WHILE nHang < Len( cLine ) .AND. SubStr( cLine, nHang + 1, 1 ) == " "
         nHang++
      ENDDO
      IF nHang > nWidth - 14
         nHang := nIndent
      ELSE
         cHead := Left( cLine, nHang )
         cRest := SubStr( cLine, nHang + 1 )
         nRoom := nWidth - nHang
         DO WHILE .T.
            HBHelpCut( cRest, nRoom, @nCut )
            AAdd( a, RTrim( cHead + Left( cRest, nCut ) ) )
            cRest := LTrim( SubStr( cRest, nCut + 1 ) )
            IF Empty( cRest )
               EXIT
            ENDIF
            cHead := Space( nHang )
         ENDDO
         RETURN
      ENDIF
   ENDIF
   cHead := Left( cLine, nIndent )
   cRest := SubStr( cLine, nIndent + 1 )
   nRoom := nWidth - nIndent
   DO WHILE .T.
      HBHelpCut( cRest, nRoom, @nCut )
      AAdd( a, RTrim( cHead + Left( cRest, nCut ) ) )
      cRest := LTrim( SubStr( cRest, nCut + 1 ) )
      IF Empty( cRest )
         EXIT
      ENDIF
   ENDDO
   RETURN

// nCut: length of the piece of cText that fits nRoom, ending at a space when
// there is one, else a hard cut for a single over-long word.
STATIC PROCEDURE HBHelpCut( cText, nRoom, nCut )
   LOCAL n
   IF Len( cText ) <= nRoom
      nCut := Len( cText )
      RETURN
   ENDIF
   nCut := nRoom
   IF SubStr( cText, nRoom + 1, 1 ) == " "
      RETURN
   ENDIF
   FOR n := nRoom TO 1 STEP -1
      IF SubStr( cText, n, 1 ) == " "
         nCut := n
         EXIT
      ENDIF
   NEXT
   RETURN

FUNCTION HBIDEHelpContext( cMenu, cItem )
   LOCAL c := Upper( StrTran( AllTrim( cMenu ), "~" ) )
   LOCAL cCommand := Upper( StrTran( AllTrim( cItem ), "~" ) )
   DO CASE
   CASE "COMPILER" $ cCommand
      RETURN "Compiler flags"
   CASE "DISPLAY" $ cCommand
      RETURN "Display settings"
   CASE "DESIGNER" $ cCommand
      RETURN "Dialog designer"
   CASE "DEBUG" $ cCommand
      RETURN "Debugger"
   CASE "FIND" $ cCommand .OR. "REPLACE" $ cCommand .OR. "GOTO" $ cCommand
      RETURN "Find, Replace, Goto Line"
   CASE "FILE" $ c
      RETURN "File menu"
   CASE "EDIT" $ c
      RETURN "Edit menu"
   CASE "RUN" $ c
      RETURN "Run menu"
   CASE "OPTIONS" $ c
      RETURN "Options menu"
   CASE "PROJECT" $ c
      RETURN "Projects"
   CASE "WINDOW" $ c
      RETURN "Multiple documents"
   CASE "HELP" $ c
      RETURN "Using help"
   ENDCASE
   RETURN "Welcome to hbide"
FUNCTION HBIDEHelpLinks( cTitle, aTopics )
   LOCAL a := {}, aWanted := {}, c, n
   DO CASE
   CASE cTitle == "Welcome to hbide" .OR. cTitle == "Using help"
      aWanted := { "File menu", "Edit menu", "Run menu", "Dialog designer", "Keyboard shortcuts" }
   CASE cTitle == "Run menu"
      aWanted := { "Compiler flags", "Debugger", "File menu" }
   CASE cTitle == "Options menu"
      aWanted := { "Compiler flags", "Display settings", "Dialog designer" }
   CASE cTitle == "Debugger"
      aWanted := { "Debugger windows", "Run menu", "Keyboard shortcuts" }
   CASE cTitle == "Debugger windows"
      aWanted := { "Debugger", "Keyboard shortcuts" }
   CASE cTitle == "Compiler flags"
      aWanted := { "Run menu", "Options menu" }
   CASE cTitle == "Edit menu"
      aWanted := { "Find, Replace, Goto Line", "Keyboard shortcuts", "File menu" }
   CASE cTitle == "File menu"
      aWanted := { "External file changes", "Edit menu", "Run menu" }
   CASE cTitle == "Quick start"
      aWanted := { "The screen", "File menu", "Run menu", "Debugger" }
   CASE cTitle == "The screen"
      aWanted := { "Quick start", "Keyboard shortcuts", "Terminal notes" }
   CASE cTitle == "Multiple documents"
      aWanted := { "File menu", "Saving and safety", "Keyboard shortcuts" }
   CASE cTitle == "Saving and safety"
      aWanted := { "Crash recovery", "External file changes", "File menu" }
   CASE cTitle == "Crash recovery"
      aWanted := { "Saving and safety", "File menu" }
   CASE cTitle == "Projects"
      aWanted := { "Run menu", "Compiler flags" }
   CASE cTitle == "Terminal notes"
      aWanted := { "Display settings", "Platform status and limits" }
   CASE cTitle == "Platform status and limits"
      aWanted := { "Terminal notes", "About hbide", "Using help" }
   OTHERWISE
      aWanted := { "Welcome to hbide", "Keyboard shortcuts", "Using help" }
   ENDCASE
   FOR EACH c IN aWanted
      n := AScan( aTopics, {| t | t[ 2 ] == c } )
      IF n > 0 .AND. c != cTitle
         AAdd( a, n )
      ENDIF
   NEXT
   RETURN a

FUNCTION HBIDEHelpOpen( cTitle, aTopics )
   LOCAL nTopic := AScan( aTopics, {| t | t[ 2 ] == cTitle } )
   LOCAL nTop := 1, nLink := 1, nKey, n, nTarget, aLines, aLinks
   LOCAL aHistory := {}, aForward := {}, aState
   LOCAL nL := Max( 1, Int( ( MaxCol() - 75 ) / 2 ) )
   LOCAL nR := Min( MaxCol() - 1, nL + 75 ), nT := 2, nB := MaxRow() - 2
   LOCAL nW := nR - nL - 3, nBody, nLinkRow, nMaxTop
   LOCAL cSaved := __dbgSaveScreen( 0, 0, MaxRow(), MaxCol() )
   IF nTopic == 0
      RETURN .F.
   ENDIF
   DO WHILE .T.
      aLines := HBIDEHelpLines( aTopics[ nTopic, 3 ], nW )
      aLinks := HBIDEHelpLinks( aTopics[ nTopic, 2 ], aTopics )
      nB := Min( MaxRow() - 2, nT + Len( aLines ) + Len( aLinks ) + 5 )
      nBody := Max( 3, nB - nT - Len( aLinks ) - 5 )
      nMaxTop := Max( 1, Len( aLines ) - nBody + 1 )
      nTop := Min( nMaxTop, Max( 1, nTop ) )
      nLink := Min( Len( aLinks ), Max( 1, nLink ) )
      nLinkRow := nT + nBody + 3
      DispBegin()
      __dbgRestScreen( 0, 0, MaxRow(), MaxCol(), cSaved )
      hb_Shadow( nT, nL, nB, nR )
      hb_Scroll( nT, nL, nB, nR,,, "N/W" )
      hb_DispBox( nT, nL, nB, nR, hb_UTF8ToStrBox( "┌─┐│┘─└│" ), "N/W" )
      hb_DispOutAt( nT, nL + 2, " " + Left( aTopics[ nTopic, 2 ], nW - 2 ) + " ", "W+/B" )
      hb_DispOutAt( nT + 1, nL + 2, PadR( "F1 Contents  Backspace Back  Alt+Right Forward", nW ), "N/BG" )
      FOR n := 1 TO nBody
         hb_DispOutAt( nT + 1 + n, nL + 2, PadR( iif( nTop + n - 1 <= Len( aLines ), aLines[ Min( nTop + n - 1, Len( aLines ) ) ], "" ), nW ), "N/W" )
      NEXT
      hb_DispOutAt( nLinkRow - 1, nL + 2, PadR( "Related topics (Tab / Enter or click)", nW ), "N/BG" )
      FOR n := 1 TO Len( aLinks )
         hb_DispOutAt( nLinkRow + n - 1, nL + 2, PadR( "> " + aTopics[ aLinks[ n ], 2 ], nW ), iif( n == nLink, "W+/B", "B/W" ) )
      NEXT
      hb_DispOutAt( nB - 1, nL + 2, PadR( "Up/Down PgUp/PgDn scroll  Esc close  " + hb_ntos( nTop ) + "/" + hb_ntos( nMaxTop ), nW ), "N/BG" )
      DispEnd()
      nKey := hb_keyStd( Inkey( 0, INKEY_ALL + HB_INKEY_EXT ) )
      nTarget := 0
      DO CASE
      CASE nKey == K_ESC
         EXIT
      CASE nKey == K_F1
         nTarget := AScan( aTopics, {| t | t[ 2 ] == "Using help" } )
      CASE nKey == K_BS .AND. ! Empty( aHistory )
         AAdd( aForward, { nTopic, nTop, nLink } )
         aState := ATail( aHistory ); ASize( aHistory, Len( aHistory ) - 1 )
         nTopic := aState[ 1 ]; nTop := aState[ 2 ]; nLink := aState[ 3 ]
      CASE hb_keyStd( nKey ) == K_ALT_RIGHT .AND. ! Empty( aForward )
         AAdd( aHistory, { nTopic, nTop, nLink } )
         aState := ATail( aForward ); ASize( aForward, Len( aForward ) - 1 )
         nTopic := aState[ 1 ]; nTop := aState[ 2 ]; nLink := aState[ 3 ]
      CASE nKey == K_TAB .AND. Len( aLinks ) > 0
         nLink := nLink % Len( aLinks ) + 1
      CASE nKey == K_SH_TAB .AND. Len( aLinks ) > 0
         nLink := iif( nLink > 1, nLink - 1, Len( aLinks ) )
      CASE nKey == K_ENTER .AND. Len( aLinks ) > 0
         nTarget := aLinks[ nLink ]
      CASE nKey == K_LBUTTONDOWN .AND. MRow() >= nLinkRow .AND. MRow() < nLinkRow + Len( aLinks ) .AND. MCol() > nL .AND. MCol() < nR
         nTarget := aLinks[ MRow() - nLinkRow + 1 ]
      CASE nKey == K_UP .OR. nKey == K_MWFORWARD
         nTop--
      CASE nKey == K_DOWN .OR. nKey == K_MWBACKWARD
         nTop++
      CASE nKey == K_PGUP
         nTop -= nBody
      CASE nKey == K_PGDN
         nTop += nBody
      CASE nKey == K_HOME
         nTop := 1
      CASE nKey == K_END
         nTop := nMaxTop
      ENDCASE
      IF nTarget > 0 .AND. nTarget != nTopic
         AAdd( aHistory, { nTopic, nTop, nLink } )
         IF Len( aHistory ) > 100
            hb_ADel( aHistory, 1, .T. )
         ENDIF
         aForward := {}; nTopic := nTarget; nTop := 1; nLink := 1
      ENDIF
   ENDDO
   __dbgRestScreen( 0, 0, MaxRow(), MaxCol(), cSaved )
   RETURN .T.

#include "helpdocs.ch"

// hbide help topics: single source for Help>Contents and Help>Index.
// Each topic: { keyword list, title, body }

function HBIDEHelpTopics()

   local a := {}

   AAdd( a, { "welcome hbide ide introduction", "Welcome to hbide", ;
      "hbide is a text-mode IDE for the Harbour language." + hb_eol() + hb_eol() + ;
      "It edits Harbour source with syntax colors, builds and runs it with hbmk2, " + ;
      "runs snippets in memory as scripts, and includes a visual dialog designer " + ;
      "(Options > Designer)." + hb_eol() + hb_eol() + ;
      "Menus open with the mouse or with Alt plus the highlighted letter " + ;
      "(for example Alt+F for File). The full list is in 'Keyboard shortcuts'." } )

   AAdd( a, { "file new open save as exit bak backup", "File menu", ;
      "New            Starts an empty buffer ('noname.prg'). If the current buffer has" + hb_eol() + ;
      "               unsaved changes you are asked to Save, Discard or Cancel first." + hb_eol() + hb_eol() + ;
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
      "Copy / Paste                    Whole current line, internal clipboard." + hb_eol() + hb_eol() + ;
      "Delete Line (Ctrl+Y)            Removes the current line." + hb_eol() + hb_eol() + ;
      "Duplicate Line                  Inserts a copy of the current line below." } )

   AAdd( a, { "find search replace goto repeat f3 f5", "Find, Replace, Goto Line", ;
      "Find... (F5)           Case-insensitive search from the cursor." + hb_eol() + ;
      "Repeat Last Find (F3)  Next match of the last search." + hb_eol() + ;
      "Replace...             Replaces every match in the buffer as ONE undoable" + hb_eol() + ;
      "                       operation (Ctrl+Z restores all of them)." + hb_eol() + ;
      "Goto Line...           Jumps to a line number." + hb_eol() + hb_eol() + ;
      "Note: blanks at the END of the search text cannot be told apart from input" + hb_eol() + ;
      "field padding and are ignored; leading blanks are kept." } )

   AAdd( a, { "keyboard shortcuts keys f2 f3 f5 ctrl esc ins ovr", "Keyboard shortcuts", ;
      "F2       Save            Ctrl+Z  Undo" + hb_eol() + ;
      "F3       Find next       Ctrl+U  Redo" + hb_eol() + ;
      "F5       Find...         Ctrl+Y  Delete line" + hb_eol() + hb_eol() + ;
      "Esc      Closes dialogs; with a clean buffer it exits the IDE (with unsaved" + hb_eol() + ;
      "         changes it asks first)." + hb_eol() + ;
      "Ins      Toggles insert/overwrite; the status bar shows INS or OVR." + hb_eol() + hb_eol() + ;
      "In dialogs: Tab/Shift+Tab moves between fields, Enter confirms, arrows move" + hb_eol() + ;
      "inside lists and radio groups, Space toggles check boxes." } )

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
      "Not implemented upstream (menu entries alert 'Not implemented yet!'): " + hb_eol() + ;
      "Window Move/Size/Zoom/Iconize/Tile, Options Exchange Screens," + hb_eol() + ;
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

   AAdd( a, { "about version harbour fivetech", "About hbide", ;
      "hbide - Harbour IDE" + hb_eol() + ;
      "FiveTechSoft - https://github.com/FiveTechSoft/hbide" + hb_eol() + hb_eol() + ;
      "Written in Harbour. Uses the Harbour compiler and hbmk2." + hb_eol() + ;
      "The same information is in Help > About..." } )

return a

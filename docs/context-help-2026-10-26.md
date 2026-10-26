# Context help and linked topics

Changes: help.prg, the Help methods and F1 handling in hbide.prg, CompilerFlags' existing Help callback, tests/test_help.prg. No designer, editor, menu or debugger changes.

- F1 in the editor opens Welcome. F1 while a main menu command is highlighted resolves the command without executing it, closes the popup and opens its help topic.
- Specific contexts: Compiler flags, Display settings, Dialog designer, Debugger, Find/Replace/Goto. File/Edit/Run/Options/Help get their general topic as fallback.
- Existing Help > Contents and Index use the linked viewer. Related topics can be followed with Tab/Shift+Tab + Enter or a mouse click. Backspace goes back, Alt+Right forward, retaining topic/scroll/link state. History capped at 100.
- Up/Down, wheel, PageUp/PageDown, Home/End scroll. Esc closes and restores the previous screen.
- Compact layout grows with topic size and fits 25x80 through 40x120. Original help title and body data are retained; new specific topics and a Harbour sample are added.
- Compiler Options' existing Help button now opens Compiler flags rather than the broad Options menu topic. This reuses the safe nested-dialog wrapper. F1 inside arbitrary modal dialogs is not claimed: they retain their normal controls.

Validation: built IDE on Linux, test_help passed context mapping, wrap width, links, history and exact screen restoration. Actual IDE keystrokes verified F1 over Compiler Flags, Enter to Run, Backspace back, real Alt+Right forward. At 25x80 the complete Welcome topic and all related links fit. In Compiler Options, toggled Warnings locally, tabbed to Help, opened/closed help, confirmed the edited dialog was restored, then Cancel and reopen confirmed Warnings reverted. All captures inspected.

Caveats: Windows runtime untested. This is topic-level contextual help, not symbol lookup into Harbour API documentation or an editor clipboard exporter. No new key mapping in the designer. The debugger windows topic requires the preceding debugger-layout patch. No publication was attempted.

References for design intent: Borland user guide, contextual status/help and keyboard interaction, https://bitsavers.org/pdf/borland/turbo_c/Turbo_C++_Users_Guide_1990.pdf ; screenshots https://www.toughdev.com/content/2021/06/revisiting-borland-turbo-cc-a-great-ide-back-in-the-90s/ . Implementation is new Harbour code, not copied proprietary IDE source.

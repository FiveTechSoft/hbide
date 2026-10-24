# Checkpoint editor de codigo - rama editor-fixes (2026-10-25)

## Alcance

- Continuacion de docs/editor-checkpoint-2026-10-24.md: matriz completa de
  opciones del IDE verificada en vivo (xdotool + capturas inspeccionadas) y
  correccion de los fallos detectados durante la propia matriz.
- Entorno de verificacion: Linux, Harbour 3.2.1dev gcc, gttrm/X11 sobre xterm
  UTF-8 (locale UTF-8, HBIDE_UTF8=1, XTerm*metaSendsEscape: true).
  Windows NO verificado: nada de lo probado aqui debe leerse como validado alli.

## Fallos corregidos en este bloque

1. Hotkeys de Alert muertos con opciones "&Save"/"&Discard"/"&Cancel"
   (commit 071f368). Causa: hb_gt_def_Alert (hbgtcore.c) compara la tecla
   pulsada con el PRIMER caracter de cada opcion; con el prefijo '&' ese
   caracter es '&' y la letra nunca casa. Ademas el '&' se renderizaba
   literal. Fix: opciones sin '&' (primeras letras unicas por dialogo).
   Verificado en vivo: S/D/C y Escape en "Unsaved changes".
2. Marcos de dialogo como 'oooo'/'cccc' en modo UTF8 (commit d8eb435).
   Causa: hb_DispBox parsea el frame con el BOXCP del GT
   (hb_gt_def_Box, hbgtcore.c) pero hbide.prg lo generaba con
   hb_UTF8ToStr (CP anfitrion = UTF8, 3 bytes/caracter): 0x94='ö' arriba,
   0x80='Ç' abajo. Menus y debugger no fallaban porque usan
   HB_B_SINGLE_UNI/HB_B_DOUBLE_UNI = hb_UTF8ToStrBox (box.ch/cdpbox.c),
   que convierte al BOXCP. Fix: hb_UTF8ToStrBox en los 4 sitios afectados
   (HelpView + 3 marcos de grupo de Compiler Flags). Bajo CP anfitrion EN
   funcionaba por casualidad; el bug solo se veia en modo UTF8.
3. Tema Help "Welcome" afirmaba "On Linux terminals Alt+letter menu keys
   are not available" (commit 31c1b6f): texto obsoleto tras ea9cba1;
   reescrito (menus con raton o Alt+letra resaltada).
4. (Bloque previo del mismo dia, ea9cba1) Tras combinaciones Alt+letra sin
   menu abierto el cursor podia quedar oculto: ShowCursor al procesar
   K_ALT_* fuera de menu.

## Cobertura verificada en vivo en este bloque

Toda entrada ejecutada via menu Alt+letra o atajo, con captura inspeccionada:

- File: New (con guardia Unsaved), Open end-to-end (titulo y contenido),
  Save F2 en fichero con nombre (graba directo), Save As (nombre, escritura,
  retitulado), Exit limpio (EXIT=0).
- Edit: Undo/Redo, Copy/Paste/Cut linea, Duplicate/Delete Line, Goto Line,
  Find F5 (+F3 repeticion), Replace end-to-end ("1 replacement(s)" y texto
  cambiado).
- Run: Start exitoso end-to-end (hbmk2 compila, alerta de salida, auto-run
  con "Run after build": el hijo dibuja su propio Alert y al cerrarse el
  IDE se restaura), Start fallido (aviso correcto), Script (compila el
  buffer en memoria y lo ejecuta dentro del IDE), Debug (debugger Harbour
  vendored abre sobre __hbide_dbg__.prg; Alt+X aborta y vuelve limpio).
- Options: Compiler Flags (radios, checkboxes, OK/Cancel/Help; marcos de
  grupo correctos tras d8eb435), Display (radios 40x120/30x100/25x80).
- Help: About (Enter cierra), Index (keyword sin match -> alerta
  "No help topic matches"; con match -> HelpView del tema), Contents
  (listbox 7 temas; Enter abre HelpView; Escape vuelve al picker por
  diseño del bucle), HelpView con marco correcto tras d8eb435.
- Alertas: Unsaved Save/Discard/Cancel por tecla (tras 071f368) y
  Escape=Cancel conservando el buffer.
- Tecleo UTF-8 real (acentos, ñ) correcto en el editor.

## Limites conocidos

- Verificado solo en la maquina/xterm descritos; EN=CP437 medido solo ahi.
- Alt+letra verificado con xterm metaSendsEscape; otros terminales dependen
  de su modo meta (ver ChangeLog 2026-10-24).
- Pushbuttons GET con '&': la letra va al GET activo; Cancel se activa con
  Tab+Enter, raton o Escape (comportamiento GET estandar).
- El proceso hijo de Run>Start comparte la pantalla del terminal: su salida
  pisa la del IDE hasta que termina y el IDE se repinta.
- Cobertura global 100% y scroll de raton NO se afirman.

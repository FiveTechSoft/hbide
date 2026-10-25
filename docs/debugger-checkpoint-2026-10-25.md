# Checkpoint debugger integrado - rama designer-robustness (2026-10-25)

## Alcance

- Integracion y verificacion del debugger de Harbour (hbdebug/) desde el IDE:
  inventario funcional con efecto verificado (pty + detector de colores),
  mas las correcciones de robustez listadas abajo. Continua el trabajo de
  bloques anteriores (BPs F9 en editor, presets Run>Debug, cursor visible
  en el browser de codigo, prefill de InputBox).
- Entorno de verificacion: Linux, Harbour 3.2.1dev gcc, pty xterm-256color.
  Windows NO verificado en este bloque (verificado por separado bajo Wine
  en entregas previas).

## Fallos corregidos en este bloque

1. Crash 9001 "Error recovery failure" al usar Animate, el dialogo Colors,
   o cualquier sesion con init.cld presente (commit edbce02).
   Causa: HBDbWindow:LoadColors (dbgtwin.prg) reconstruia el colorSpec del
   browser con 4 slots, mientras HBBrwText:New y GetLineColor (cursor
   visible) usan 5. LoadSettings->DoScript("Options Colors") y el dialogo
   Colors ejecutan LoadColors: a partir de ahi DispRow indexaba el slot 5
   en un array de 4 y la sesion quedaba congelada descartando teclas.
   Detectado con sonda temporal: "nClr=5 len=4 spec=[N/BG,W+/B,R/BG,GR+/B]".
   Fix: LoadColors anade aClr[1] como 5o slot, igualando HBBrwText:New.
   Inocuo para los browses de stack/vars/point (sus colorBlocks <= 4).
2. Restore Settings no aplicaba TabWidth al browse en vivo (commit posterior).
   Causa: el caso TABWIDTH de DoScript asignaba ::nTabWidth sin propagarlo a
   ::oBrwText:nTabWidth ni refrescar (bug presente tambien en upstream
   harbour/src/debug/debugger.prg); el dialogo Options>Tab Width si lo hace.
   Detectado al verificar el efecto real del Restore: la marca de BP volvia
   pero la expansion de tabs no. Fix: misma propagacion con guarda NIL que
   ya usa LineNumbers(). Verificado: archivo con tab real, Restore cambia la
   expansion igual que el dialogo (D==B, distinto de A/C con ancho 4).
   NUM ON/OFF revisado: ya enruta por ::LineNumbers(), que propaga bien.
3. Prefill de InputBox (commit 6d36850, bloque anterior ya entregado):
   el primer caracter tecleado reemplaza la seleccion completa; la edicion
   normal y Cancel se conservan.

## Anomalias cerradas

- "Animate hace un paso y congela": era el fallo 1. Verificado tras el fix:
  la app avanza sola (salidas "step a"/"step b" impresas), ENTER en
  inkey(0) continua y el debugger cierra limpio al terminar la app.
- "Locate>Goto y F5 fallan tras usar la ventana Command": misma causa
  (sesion rota por el 9001) amplificada por limites del detector de
  pruebas (NUM OFF elimina los numeros de linea que el detector lee;
  exec-sobre-BP es amarillo/azul, no blanco/azul). Tras el fix, 3/3:
  Command primero -> GOTO 5 -> cursor en 5; BP 4 + F5 -> parada en 4.

## Verificado con efecto en este bloque

- Save/Restore Settings efectivo (no solo dialogo): BP 4 + TabWidth 8
  guardados en verify.cld ("Options Tab 8", "BP 4 __hbide_dbg__.prg");
  tras quitar el BP y volver a Tab 4, Restore recoloca la marca de BP en
  la linea 4. El Restore ademas ejercita DoScript->LoadColors con el fix.
- Regresion con init.cld presente: F5 para en BP con color exec-sobre-BP,
  GOTO, Resume (re-vista del punto de ejecucion, no reinicio), F5 tras
  Resume, F7 a cursor, Find/Next/Previous (4->6->4).

## Semantica upstream documentada (no bugs)

- Watchpoints: solo visualizacion; Tracepoints: paran al cambiar el valor
  (dbgentry.c SHOWLINE solo evalua TPs). Documentado en en.txt:358-363.
- File>Resume: re-vista del punto de ejecucion; no reinicia el programa
  ni su estado.
- La parada inicial del debugger es en la linea del init proc del wrapper,
  no en la linea 1 de Main.

## Pendiente

- Spot-check del path editor F9 BP + Run>Debug (presets) tras el fix 1.
- Monitor Private/Static/Global, Window Next/Prev, temas de ayuda del IDE
  para WP/TP/teclas/comandos, entradas NotSupported del menu Window.
- Rebuild y publicacion de hbide.exe en el proximo checkpoint verificado.

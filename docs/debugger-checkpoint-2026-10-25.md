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

## Monitor de variables (verificado con efecto)

Fixture con local/static/private/public + DYNAMIC, ejecucion detenida tras
las asignaciones (pty, ventana Monitor visible):
- Local solo -> NL <Local,N>=1; Public solo -> NU <Public,N>=5 (mas GETLIST,
  public interno de Harbour); Private solo -> NP; Static solo -> NS.
- All -> los cinco listados con tipo y valor correctos.
- Al desactivar todos los flags la ventana Monitor se cierra (HideVars).
- LIMITACION REAL: Monitor>Global no puede mostrar nada en esta compilacion.
  Harbour no soporta variables GLOBAL: hb_dbg_vmVarGCount/__DBGVMVARGLIST en
  src/vm/hvm.c son stubs "#if 0" mantenidos "only for compatibility with
  xHarbour debugger", y la gramatica (harbour.y) no tiene declaracion GLOBAL
  (DYNAMIC es solo una declaracion extern; una asignacion posterior crea
  una private, que es como aparece en el Monitor). No es un bug del IDE.

## Limitaciones upstream documentadas (NO son funciones implementadas)

- Window Move/Size/Zoom(F2)/Iconize/Tile y Options Exchange Screens /
  swap on Input / Menu Bar: stubs de upstream que solo muestran el alert
  "Not implemented yet!" (verificado las 8). Quedan como limitaciones;
  construirlas seria funcionalidad nueva, fuera de la semantica upstream.
- Monitor>Global: ventana vacia siempre (Harbour sin GLOBALs; ver seccion
  Monitor). 
- Limitacion visual conocida durante la ejecucion (p.ej. Animate): la
  salida de la app puede aparecer superpuesta al debugger y quedar bandas
  sin repintar al hacer scroll. Observado igual en Linux (gttrm) y Windows
  (gtwvt) con nuestra integracion. SaveAppScreen/RestoreAppScreen/
  SaveAppState/RestoreAppState/Step/Animate son byte-identicos a
  harbour/src/debug upstream, lo que prueba que esos metodos se heredan
  sin cambios; no descarta interaccion con el canvas/gt del host, y ambas
  plataformas usan nuestra integracion, asi que no se afirma causalidad
  upstream definitiva. F4 (App Screen) es la alternativa para ver la
  pantalla de la app. Avance funcional != correccion visual aqui.

## Defecto Help-tras-debugger: CORREGIDO (7865ae2)

Sintoma original: tras una sesion de debugger (Run>Debug, Alt+X para
salir), Help>Contents no abria el picker de temas ('c' era no-op) y un
Enter posterior disparaba "Error BASE/1004 No exported method: EVAL"
(la app sobrevivia tras OK). Reproducido en Linux (pty) y Windows (Wine).

Causa raiz (probada con instrumentacion): HBDbMenu:aMenus es un THREAD
STATIC de construccion compartido por todo el proceso y nunca se vacia:
la barra del IDE permanece en el tras BuildMenu(). __dbgBuildMenu()
(hbdebug/dbgmenu.prg) construia el menu del debugger sobre esa pila, asi
que New() marcaba la barra del debugger como popup y el Build() final
(profundidad 2) ejecutaba la rama de sub-menu anidado: sobrescribia el
bAction del ULTIMO item de la barra del IDE ("~Help") con el objeto
barra del debugger. Despues Alt+H abria la barra del debugger como popup
de Help (sin hotkey 'C': 'c' no-op; item 7 = "~Options" con bAction =
OBJETO submenu) y Enter Eval()uaba ese objeto -> BASE/1004. Confirmado
con log en HBDbMenu:EvalAction: bar=5 popup=7 item=[ ~Options ]
bAction=O.

Fix (hbdebug/dbgmenu.prg, 15 lineas): construir el menu del debugger en
una pila privada (save/NIL/restore de aMenus alrededor de MENU...ENDMENU).
Efecto secundario positivo: la barra del debugger queda lPopup=.F. y se
posiciona como barra (render limpio, ver capturas).

Verificacion del ciclo debugger->salir->Help->Contents->Debugger:
- Linux: 3 arranques frescos x 2 aperturas de Contents + 3 sesiones de
  debugger consecutivas en UN solo proceso: Contents abre el topic
  Debugger sin EVAL en todos los casos; Help>About abre su dialogo;
  el menu Options del propio debugger sigue funcionando.
- Windows (Wine, exe rebuild, capturas reales): sesion 1 y tras 3
  sesiones Help>Contents abre con el topic Debugger legible y sin error
  (wfix_02, wfix_03); Help>About abre el dialogo HbIde 1.0 (wfix_06);
  F4 ida/vuelta limpio: debugger -> app screen (canvas compartido IDE,
  comportamiento documentado) -> debugger (wfix_07..wfix_09); editor
  limpio tras Alt+X final (wfix_10). El menu del debugger renderiza
  correcto desde la sesion 1 (wfix_01).
- Sin perdida de commits previos; la limitacion visual durante Animate
  permanece documentada y NO se da por resuelta con estas capturas.

## Pendiente

- Spot-check del path editor F9 BP + Run>Debug (presets) tras el fix 1.
- Monitor Private/Static/Global, Window Next/Prev, temas de ayuda del IDE
  para WP/TP/teclas/comandos, entradas NotSupported del menu Window.
- Rebuild y publicacion de hbide.exe en el proximo checkpoint verificado.

## 2026-10-26: Tab Width presentation regression

- Correction: the earlier PPO+TAB absence in the PTY model was a cascade
  coverage/z-order observation, not lost source. Do not classify it as data loss.
- Separate reproducible defect: increasing Tab Width from 4 to 12 kept the
  code browser's old expanded maximum-line width. The generated fixture has
  four tabs before `x := x + 41`; at width 12 those tabs alone exceed the old
  limit, so MemoLine returned spaces. The file and buffer remained unchanged.
- Fix: recalculate expanded line width on Tab Width changes, honor the width
  supplied to the browser constructor, and size expansion for every tab rather
  than a fixed extra 256 characters.
- Linux PTY function matrix: 57/58 before fix, 58/58 twice after fix.
  The former committed 56/56 did not cover the new live Tab Width effect.
- Native regression: 7 checks cover 4 -> 12 -> 4, unchanged source/buffer,
  constructor width, and a line with 100 tabs. The pre-fix implementation fails
  at the width-12 text assertion; the fix passes all seven.
- Actual Linux terminal captures inspected at width 4 and 12 show the complete
  same line moved right. No Windows validation or global visual closure implied.
- RunAtStartup, CodeBlockTrace and ShowAllGlobals remain menu-state coverage
  only here, pending independent observable-effect tests.

## 2026-10-26: Command and startup effects

- `test_debug_commands_pty.py`: 9/9 twice in fresh Linux sessions. GOTO 3
  and GOTO 70 move the viewport to the requested line; FIND selects a matching
  line after a distant GOTO; INPUT runs a real command file (Num Off, TabWidth
  12, Goto 60), with separate effects checked. NUM ON restores numbers.
- `test_debug_startup_pty.py`: two fresh processes, default RunAtStartup and
  init.cld Options NoRunAtStartup. Execution highlight stops on the injected
  init procedure's return in the default case and on __dbgInvokeDebug in the
  disabled case. This proves a startup effect at that specific entry point;
  it is not a claim that either setting starts at the user's Main.
- CodeBlockTrace remains menu-state coverage: a single-line Eval fixture did
  not distinguish on/off (both stepped to the following statement).
- ShowAllGlobals remains menu-state coverage. Public variables cannot prove
  this setting: its code filters module GLOBAL/EXTERNAL GLOBAL entries, not
  PUBLICs. This Harbour compiler's GLOBAL limitation remains documented.

## 2026-10-26: CodeBlockTrace differential effect

- `test_debug_codeblock_pty.py`: extended multi-line codeblock, breakpoint on
  Eval at line 7, then F8. With CodeBlockTrace on, execution stops at line 4
  (first block statement); off stops at line 5 (block return). Repeated twice,
  each with fresh on/off processes. This proves the setting skips the block
  entry event in this Harbour implementation, NOT that it skips every statement
  inside an extended block. The previous single-line fixture was insufficient.
- ShowAllGlobals alone remains state-only among the three options discussed.

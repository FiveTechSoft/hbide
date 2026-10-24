# Checkpoint editor de codigo - rama editor-fixes (2026-10-24)

## Alcance

- Peticion: probar el editor de codigo (no el diseñador) y corregir los fallos
  detectados. Commit/push autorizado en la rama; sin merge ni PR.
- Entorno de verificacion: Linux, Harbour gcc, gttrm/X11 sobre xterm UTF-8.
  Windows NO verificado: nada de lo probado aqui debe leerse como validado alli.

## Fallos reproducidos y corregidos

1. DeleteLine/PasteLine/DuplicateLine dependian del modo INS/OVR: ahora son
   independientes del modo.
2. El editor arrancaba en modo overwrite: ahora insert por defecto, con
   indicador INS/OVR en la barra de estado.
3. Dialogo Open roto (botones fuera de sitio, no dejaba teclear el nombre) y
   Run>Start fallido: corregidos.
4. Botones del dialogo Find fuera del marco: corregidos.
5. Escape con cambios sin guardar salia sin avisar (perdida de trabajo): ahora
   pregunta Save/Discard/Cancel; el mismo chequeo cubre File>Exit y Open.
6. Sin undo/redo: pila de operaciones Ctrl+Z/Ctrl+U (coalescing de tecleo,
   limite 300) y marcador de estado guardado honesto (bifurcacion tras undo,
   sin coalescing sobre el punto guardado, ajuste por truncacion).
7. Sin red de seguridad al guardar: copia .bak conservadora (temporal unico,
   rename con un erase+retry; si falla avisa y no borra contenido ajeno).
8. Sin Replace: ReplaceAll insensible a mayusculas en todo el buffer como una
   unica operacion deshacible, con dialogo y entrada de menu; repintado
   completo que conserva gutter y colores.
9. Prefill de los GET en Find/Replace corrompia lo tecleado (modo overwrite):
   campos vacios.
10. AllTrim silencioso alteraba busquedas con espacios iniciales: primero
    RTrim literal; luego sustituido por entrada libre (HBIDE_DlgInput) que
    conserva TODOS los blancos tecleados como dato (ver seccion Find/Replace
    con entrada libre mas abajo).
11. Cambios externos en disco no detectados: sello DiskStamp (fecha+hora+
    tamaño). Sondeo ~2s; buffer limpio -> aviso + recarga (nunca silencioso);
    buffer sucio -> Reload/Keep mine (Keep no repregunta por el mismo cambio);
    guardia Overwrite/Cancel al guardar y en Run.
12. Borrado externo se confundia con "sin cambios" (habria recreado el archivo
    sin avisar): FileVanished distingue ausente de sin-cambios; aviso una vez
    conservando el buffer y decision Recrear/Cancelar antes de escribir.

## Pruebas en vivo (Linux)

- Replace: 7 reemplazos exactos multi-match sin bucle ni reescaneo; undo/redo
  de los 7 como una sola operacion; alerta de 0 coincidencias; guardia de
  patron vacio; repintado conserva gutter/colores.
- DiskStamp: aviso automatico sin entrada; Keep mine conserva lo propio y no
  reavisa; Overwrite escribe y resincroniza sellos (sin falsos avisos); Cancel
  no escribe; borrado externo -> aviso una vez; Cancel no recrea; Recreate
  regenera el archivo identico al contenido del buffer.

## Limitaciones reales (declaradas, no resueltas)

- El sello fecha+hora+tamaño puede no detectar una edicion de mismo tamaño
  dentro de la resolucion temporal del filesystem; no hay verificacion de
  contenido.
- La recarga tras cambio externo va al inicio del archivo (no conserva cursor).
- Si el archivo reaparece tras un borrado, se trata como cambio externo normal.
- En esta GT los menus se abren con raton; Alt+letra no abre menus en Linux
  gttrm (colision con la entrada española; posible via HB_INKEY_EXT, no
  evaluado).
- EOL: hbide.prg sigue CRLF y editor.prg LF, convencion previa del repo.

## No solicitado / no implementado (funciones nuevas, no fallos)

- tvhl (resaltado multilenguaje): evaluado estaticamente, viable como modulo
  contenido, NO integrado.
- Alt+menus via HB_INKEY_EXT: candidata apuntada por otro worker, sin abordar.
- Stubs: ninguno pendiente. Todas las opciones de menu estan implementadas
  (New/Save As/Display/Help en la seccion de la tarde; Debug en Pendiente
  declarado resuelto mas abajo).
- Diseñador: intacto (su trabajo vive en la rama hermana designer-robustness).

## Actualizacion 2026-10-24 (tarde): opciones de menu implementadas

### Implementado y verificado en vivo

1. File>New real: plantilla base, guardia de cambios sin guardar con Discard.
2. File>Save As real: dialogo, escritura en disco, retitulado de la ventana.
   Save (F2) sobre buffer sin nombre delega en Save As.
3. Compiler Flags: dialogo persistente (Warnings / Debug info / Strict) cuyas
   opciones se aplican en Run>Start via hbmk2. Hallazgo upstream: la forma
   larga "-compiler=" hace fallar hbmk2 3.2.1dev (BASE/1068 en
   LegacyWarning/ParamToString, reproducido fuera del IDE); se usa "-comp=".
4. Help>Contents y Help>Index (help.prg): 9 temas que documentan el
   comportamiento real del IDE; visor con marco propio; Index localiza el
   tema desde una busqueda (p.ej. "undo" abre "Edit menu" directamente).
5. Options>Display: presets 40x120 / 30x100 / 25x80. Verificado ida y vuelta
   40x120 -> 25x80 -> 40x120 con el contenido del buffer intacto (el xterm se
   redimensiona de verdad y la ventana de codigo se recrea al nuevo tamano).
   Si el terminal rechaza el resize, se revierte y avisa
   "Terminal does not support WxH" (verificado con xterm sin allowWindowOps).

6. Edit>Copy + Edit>Paste: copia de linea y pegado debajo de la actual;
   verificado por bytes en disco tras F2 ("alpha X" duplicada, xxd).
7. Help>About: dialogo con titulo/version/copyright y boton OK (captura v21).
8. Run>Script: compila el buffer en memoria (hb_CompileFromBuf) y lo ejecuta
   (hb_HrbRun); verificado con un script que escribe un archivo via
   hb_MemoWrit: el archivo aparece con el contenido esperado.

### Alt+letra: caracterizacion completa (corrije la nota anterior)

- La nota previa "Alt+letra no abre menus en gttrm" era un artefacto de la
  configuracion del terminal, no del IDE ni de gttrm.
- gttrm entrega K_ALT_* correctamente cuando el terminal envia meta como
  prefijo ESC. Con xterm hace falta: -xrm 'XTerm*metaSendsEscape: true'.
- Con el default de xterm (eightBitInput), Alt+o llega como byte alto 0xEF
  que gttrm no reconoce como Alt y el IDE lo pasa al editor: de ahi la
  "corrupcion del buffer" observada. Con metaSendsEscape no hay filtracion
  (verificado: Alt+O abre Options, Alt+F abre File, Escape limpio).
- Probado con sonda InKey: Alt+O = 280 (K_ALT_O) con metaSendsEscape,
  byte crudo 239 sin el.

### Glifos CP437 (botones/sombras): requisito de DOS capas

- El render correcto exige: (a) el xterm arrancado con locale UTF-8 (si no,
  renderiza Latin1 y Chr(255/220/223) se ven como ÿ/Ü/ß) y (b) el proceso
  hbide con locale UTF-8 (gttrm activa su modo UTF-8 al detectarla;
  hbide clava EN/CP437 por defecto; HBIDE_UTF8=1 habilita el modo UTF8
  experimental, ver seccion Unicode mas abajo).
- Con ambas capas, botones y sombras se ven limpios (verificado en capturas).

### Notas de harness (reproducibilidad)

- Xvfb :99 + xterm local con: -xrm 'XTerm*metaSendsEscape: true'
  -xrm 'XTerm*allowWindowOps: true', LANG=C.UTF-8 LC_ALL=C.UTF-8.
- allowWindowOps solo es necesario para probar el resize real de Display;
  sin el, el camino de rechazo queda cubierto.

### Actualizacion (dialogos Open/Save As): Enter confirma, sin machacar texto

- Open: Enter en el GET de nombre confirma y abre lo tecleado (antes
  saltaba el foco y perdia el texto tecleado).
- El STATE del listbox solo sincroniza el GET cuando cambia la seleccion
  (Tab hacia la lista ya no machaca el nombre tecleado).
- Enter sobre una seleccion de la lista la abre directamente (antes no-op).
- Save As: Enter en el GET confirma y guarda (verificado: archivo en disco).
- Mismo tratamiento Enter=confirma en Help>Contents (lista de temas abre
  el visor), Help>Index (GET filtro), Goto Line, Find y Replace (GETs).
- Rechazo >250 chars preservado en ambas rutas Enter (alerta tras cerrar).
- Mecanica: VALID con LastKey()==K_ENTER -> lOk + exitState:=GE_ESCAPE
  (getexit.ch). Sin tocar hbwindow.prg ni el RTL.

### Find/Replace con entrada libre: blancos finales son dato (2026-10-24 noche)

- Causa: los GET de ancho fijo (Space(N)) hacen indistinguible un blanco
  final tecleado del padding del campo; buscar "alpha " (con espacio)
  encontraba "alphaY" y no permitia exigir el blanco.
- Fix: HBIDE_DlgInput (hbide.prg), editor de linea libre usado por Find y
  Replace: la cadena crece con lo tecleado, sin buffer fijo. Enter confirma
  el dialogo, Tab/CursorAbajo avanza al siguiente control (ultimo control
  pasa a los botones OK/Cancel via Activate), Esc cancela. Los botones
  conservan su ruta GET/STATE original (End cierra el READ).
- Detalle Harbour: Empty(" ") es .T.; el lector usa Len(cKey)>0 para que un
  ESPACIO tecleado sea dato. Misma razon para Len(cFind)>0 en vez de Empty()
  al decidir si buscar.
- Detalle HBWindow: End() solo hace ReadKill (mata el READ); la ventana se
  retira con Hide() (Activate lo hace al salir del READ). En las rutas del
  lector (sin READ) hay que llamar Hide(): con solo End() quedaba el marco
  del dialogo pintado tras cerrar (residuo detectado en Replace; el Alert de
  "n replacement(s)" restauraba ademas el area guardada con el marco).
- Verificado en vivo (Xvfb, build gcc/Linux): Find "alpha " desde Ctrl+Home
  salta "alphaY" y cae en "alpha X" (fila 2, col 1); Replace "alpha " ->
  "beta  " produce exactamente 1 reemplazo y bytes en disco
  "alphaY\nbeta  X\nz\n" (xxd); Esc cancela sin tocar el buffer; Tab ->
  OK ejecuta la busqueda; Tab -> Tab -> Enter (Cancel) cierra sin buscar
  (cursor quieto en fila 1); sin residuos de dialogo en ninguna ruta.

### Bateria Find/Replace y ajustes de cursor en gutter (2026-10-24 noche, ronda 2)

- Fallo: tras Ctrl+Home el cursor queda en el gutter (nCol=1) y FindText
  calculaba SubStr(linea, nCol-4+1) = inicio negativo: se descartaba la
  mayor parte de la linea 1 y Find perdia coincidencias reales (diagnosticado
  por la barra de estado: "row: 1, col: -3").
  Fix (editor.prg): nStart = Max(::nCol-4+1, 1) y nPos += nStart-1.
  Sin cambio de comportamiento para nCol>=5.
- Fallo: la guardia Empty(cText) rechazaba busquedas de solo espacios
  (Empty(" ") es .T. en Harbour). Fix: Len(cText)==0.
- Fallo: ShowStatus mostraba "col: -3" con el cursor en el gutter.
  Fix (hbide.prg): Max(ColPos()-4, 1).
- Bateria en vivo (Xvfb, build gcc/Linux; verificada por recortes de la
  barra de estado):
  * Home+Delete sobre "alpha" y Find "lpha" desde el inicio: fila 1 col 2
    (antes se perdia por el fallo del gutter).
  * Cursor Left/Left/End, Find "alpha " (blanco final): fila 2 col 1.
  * Find de solo espacios " ": fila 2 col 6 (con la guardia Len).
  * Find vacio: no mueve el cursor.
  * Token de 40 caracteres (mas largo que el campo de 28): encontrado,
    fila 2 col 1; el campo hace scroll horizontal y muestra la cola.
  * F3 (FindNext): avanza de fila 1 col 1 a fila 2 col 1.
  * Replace con cadena de reemplazo vacia: bytes en disco
    "alphaY\nX\nz\n" (xxd).
  * Dialogo Find capturado completo con botones tras Tab -> OK.
- UTF-8 experimental (HBIDE_UTF8=1): la entrada libre hace eco multibyte
  correcto en el campo ("óú" visible, no '?' como los GET antiguos) y Find
  encuentra "óú" con el cursor visual sobre el glifo correcto. Detalle: la
  columna de status tras el salto cuenta BYTES (21) en vez de caracteres
  (18); el salto por bytes de FindText es preexistente (capturas u9-u19),
  no lo introduce la entrada libre. Sigue como limitacion experimental.

### Padding fantasma al teclear tras End (2026-10-24 noche)

- Fallo: teclear al final de linea (tras End) guardaba 4 blancos fantasma
  despues del caracter ("abc" + End + "X" -> "abcX    "). Causa: el handler
  de tecleo de HBSrcEdit::EditKey calculaba el relleno como nCol-len-1 pero
  nCol va en coordenadas con gutter (K_END pone len+5): siempre rellenaba 4.
- Fix: nCol-len-5 (editor.prg). Los blancos intencionales se preservan:
  click de raton mas alla del fin de linea + teclear rellena exactamente el
  hueco real hasta el click (verificado en vivo: Y cae en su columna).
- Sin trim global: no se toca ningun blanco ya existente en los archivos.

### Unicode: integracion UTF-8 por locale (2026-10-24 noche, CORRIGE analisis anterior)

- CORRECCION: el analisis anterior ("causa arquitectonica: 1 byte = 1 celda,
  ningun CP tiene glifo para emoji, la via unicode vive fuera del repo")
  estaba contaminado por el arnes: el xterm de pruebas arrancaba SIN modo
  UTF-8 (la locale solo llegaba al proceso hijo, no a xterm). gttrm detecto
  terminal no-UTF-8 y cayo a traduccion por byte (chrattr), que descarta
  acentos. El modelo de celda de Harbour SI es wchar de 16 bits:
  HB_GT_UNICODE_BUF viene definido en el gttrm.c upstream y la libgttrm.a
  construida lo lleva (verificado por simbolos: hb_cdpU16CharToUTF8).
- Integracion minima en hbide.prg (METHOD New): OPT-IN explicito con la
  variable de entorno HBIDE_UTF8=1 (0/NO lo desactivan). Sin ella, EN/CP437
  clavado como siempre: se descarto la activacion automatica por locale
  porque el modo UTF-8 degrada widgets de dialogo y fuentes CP437 (ver
  limitaciones), una regresion del valor por defecto. Term/box CP quedan EN
  en ambos modos: bordes de caja CP437 intactos. Cambio reversible, sin
  tocar toolchain ni otros archivos.
- Verificado en vivo (xterm -u8, locale UTF-8, capturas u9-u19):
  * Render: áéíóú ñ € correctos en el editor y dentro de DispBox.
  * Coordenadas: status y cursor por CARACTER (End = col 24 en linea de 23
    caracteres; Right a traves de á/é avanza 1 columna por caracter y el
    cursor visual queda alineado).
  * Insertar: teclear áñ inserta los bytes UTF-8 correctos (C3 A1 C3 B1) y
    se muestran bien; el archivo guardado lleva exactamente esos bytes.
  * Borrar: BackSpace elimina el caracter multibyte ENTERO (sin byte
    colgante); guardado correcto.
  * Buscar (F5): "óú" encontrado y el cursor salta a la coincidencia (la
    busqueda es por subcadena de bytes y funciona con UTF-8).
  * Guardar/reabrir: byte-exacto (md5 identico sin ediciones; con edicion
    solo cambian los bytes esperados).
- Limitaciones declaradas del modo UTF-8 (ABIERTAS):
  * Emoji y todo >U+FFFF se muestran como U+FFFD (celda wchar de 16 bits);
    la alineacion de columnas sigue siendo correcta.
  * Los glifos CP437 de widgets (sombras de botones, marcas) se ven '?'
    en los dialogos; el eco de los GETs de dialogo muestra '?' para
    acentos aunque el contenido tecleado es correcto (Find encontro "óú").
  * Los archivos fuente CP437/Latin1 existentes se ven con '?' en modo
    UTF-8 (sus bytes altos no son UTF-8 valido); al guardar sin editar la
    integridad byte-exacta se mantiene (md5 identico verificado). Con
    locale no-UTF-8 el IDE sigue en EN/CP437 y esos archivos se comportan
    como siempre.
  * Con locale C/POSIX el modo es EN/CP437, comportamiento previo identico
    (verificado en vivo: UI y edicion ASCII correctas).
  * Tras un Find en modo UTF-8 la columna de status cuenta bytes en la
    posicion del salto (el cursor visual cae en el glifo correcto);
    inconsistencia preexistente del salto por subcadena de bytes.
- Verificado en modo por defecto (sin HBIDE_UTF8): legacy CP437 se ve
  correcto (espaéol/línea), EDITAR un archivo CP437 y guardar preserva los
  bytes altos (0x82/0x81/0xED) y aplica la edicion; dialogo Find con
  sombras de boton correctas, sin '?'.
- Unicode NO queda resuelto en general: queda como opcion experimental
  HBIDE_UTF8=1 con las limitaciones anteriores. Emoji fuera de alcance.
  Pista para fix futuro de widgets: el Commander resolvio glifos con un
  mcbutton vendored y hb_UPadR (pendiente evaluar para GETs).

### Pendiente declarado

- Run>Debug: implementado (commits 966a386 / 42d4df1): Alt+X aborta el
  depurado y vuelve al IDE de forma segura, nombres .hrb unicos sin
  colision de simbolos y sesiones re-armables.
- Terminales con meta de 8 bits: comportamiento documentado, sin fix en app
  (indistinguible de entrada internacional legitima).
- Windows/GTWVT: sin verificar; Display y Alt pueden comportarse distinto.

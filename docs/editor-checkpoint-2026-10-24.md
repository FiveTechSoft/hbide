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
10. AllTrim silencioso alteraba busquedas con espacios iniciales: RTrim
    literal en ambos dialogos, con nota visible "(trailing blanks ignored)".
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
- Los blancos finales tecleados en Find/Replace son indistinguibles del
  padding del GET fijo: se ignoran y se declara en la UI.
- EOL: hbide.prg sigue CRLF y editor.prg LF, convencion previa del repo.

## No solicitado / no implementado (funciones nuevas, no fallos)

- tvhl (resaltado multilenguaje): evaluado estaticamente, viable como modulo
  contenido, NO integrado.
- Alt+menus via HB_INKEY_EXT: candidata apuntada por otro worker, sin abordar.
- Stubs que siguen stubs: File>New, Save As, Debug, Display, Help
  Index/Contents.
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
  hbide con LANG conteniendo "UTF-8" (gttrm activa su modo UTF-8 leyendo
  getenv("LANG"); hbide no fija codepage y el VM queda en CP437 por defecto,
  que es lo correcto para los glyphs CP437 de BtnDisplay).
- Con ambas capas, botones y sombras se ven limpios (verificado en capturas).

### Notas de harness (reproducibilidad)

- Xvfb :99 + xterm local con: -xrm 'XTerm*metaSendsEscape: true'
  -xrm 'XTerm*allowWindowOps: true', LANG=C.UTF-8 LC_ALL=C.UTF-8.
- allowWindowOps solo es necesario para probar el resize real de Display;
  sin el, el camino de rechazo queda cubierto.

### Pendiente declarado

- Run>Debug: por implementar (libhbdebug.a ya esta enlazada: HbDbWindow y
  __dbg* vienen de ahi).
- Terminales con meta de 8 bits: comportamiento documentado, sin fix en app
  (indistinguible de entrada internacional legitima).
- Windows/GTWVT: sin verificar; Display y Alt pueden comportarse distinto.

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

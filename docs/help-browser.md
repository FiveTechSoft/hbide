# Navegador de ayuda (Help > Contents)

Organizacion de la ayuda segun la referencia aportada por el usuario
(TVEDIT): indice jerarquico a la izquierda, panel de lectura a la
derecha, paneles turquesa estilo TurboVision y botones verdes con
sombra difuminada abajo.

## Organizacion

Los 16 temas existentes se conservan intactos y se agrupan en cuatro
secciones (HBIDEHelpSections): 1. Basics, 2. Build and run,
3. Advanced, 4. Help and about. Cada tema aparece exactamente una vez;
las cabeceras de seccion muestran un resumen de sus temas.

## Uso

- Tab / Shift+Tab ciclan el foco: indice, texto, botones.
- Indice: flechas/PgUp/PgDn/Home/End; Enter o Right abre en el panel
  de lectura. Click selecciona.
- Lectura: scroll con flechas/PgUp/PgDn/Home/End/rueda; Left/Right van
  al tema anterior/siguiente; Enter vuelve al indice.
- F7 o el boton Search: busca en titulos y cuerpos; salta al primer
  resultado. F3 o Next: siguiente resultado (circular). La linea de
  estado muestra "Match i/n".
- Export .md: escribe hbide-help.md (Markdown, orden del arbol) en el
  directorio actual; el resultado se anuncia en la linea de estado.
- Close o Esc: cierra. Navegar no toca el estado de la aplicacion.

## Limites

- Idioma de rotulos y contenido: ingles, como el resto del IDE (la
  referencia del usuario es español; la UI de hbide es inglesa).
- El buscador no resalta el texto dentro del panel; posiciona el tema
  y la linea.
- Sin colapsado de secciones: el arbol se muestra expandido.
- La sombra de los botones es una barra difuminada inset (trama CP437
  bajo la cara). Limite del GT (investigado a fondo, 2026-10-26): gttrm tiene un modo
  Unicode (fUTF8) que se activa por //GTTRM:UTF8, sonda de terminal o LANG;
  en esta build (r2608271822, UNICODE_BUF) el modo forzado rompe TODA la
  salida de glifos (probado en VTE real), y en modo normal solo la trama
  (176-178) y la caja simple (179-206) se mapean via ACSC; los semibloques
  (219-223) salen "?". La escritura cruda UTF-8 tambien se corrompe en la
  capa CP del GT. La sombra fina estilo TVision (semibloque inferior) no es
  representable; hb_gtInfo(HB_GTI_ISUNICODE) permite detectarlo en runtime.

## Pruebas

tests/test_help_browser.prg (mismo patron keyPut + restauracion de
pantalla que test_help): cobertura del arbol (16/16 temas, 4
secciones), resumen de seccion, busqueda con y sin resultados,
exportacion real a Markdown con todos los temas, exportar via botones,
busqueda via F7/F3, apertura directa en un tema y restauracion exacta
de la pantalla en todos los caminos.

    cd tests && hbmk2 test_help_browser.prg ../help.prg -gttrm && ./test_help_browser
    # resultado en /tmp/hbide-help-browser-tests.txt

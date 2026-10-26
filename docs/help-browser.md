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
- La sombra es trama CP437 difuminada: este GT no mapea semibloques
  (▄/▐ salen "?"), asi que la sombra solida fina de la referencia no
  es representable; una celda negra solida se leia como bloque pesado.

## Pruebas

tests/test_help_browser.prg (mismo patron keyPut + restauracion de
pantalla que test_help): cobertura del arbol (16/16 temas, 4
secciones), resumen de seccion, busqueda con y sin resultados,
exportacion real a Markdown con todos los temas, exportar via botones,
busqueda via F7/F3, apertura directa en un tema y restauracion exacta
de la pantalla en todos los caminos.

    cd tests && hbmk2 test_help_browser.prg ../help.prg -gttrm && ./test_help_browser
    # resultado en /tmp/hbide-help-browser-tests.txt

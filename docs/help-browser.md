# Navegador de ayuda (Help > Contents)

Organizacion de la ayuda segun la referencia aportada por el usuario
(TVEDIT): indice jerarquico a la izquierda, panel de lectura a la
derecha, paneles turquesa estilo TurboVision y botones verdes con
sombra difuminada abajo.

## Organizacion

Los 23 temas practicos se agrupan en cinco secciones (HBIDEHelpSections):
1. Basics, 2. Editing and files, 3. Build and run, 4. Advanced,
5. Help and about. Los temas originales se conservan; la documentacion
del repo (quickstart y guia de usuario) se incorporo como temas
nuevos: Quick start, The screen, Multiple documents, Saving and
safety, Crash recovery, Projects, Terminal notes y Platform status
and limits. Cada tema aparece exactamente una vez; las cabeceras de
seccion muestran un resumen de sus temas. La ayuda contextual (F1)
tambien cubre los menus Project y Window.

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
- Los documentos completos conservan su Markdown original; las lineas
  largas se ajustan al panel. Los checkpoints fechados son historicos,
  no una afirmacion de pruebas nuevas.

## Pruebas

tests/test_help_browser.prg (mismo patron keyPut + restauracion de
pantalla que test_help): cobertura de todos los temas practicos y documentos completos, 8
secciones, resumen de seccion, busqueda con y sin resultados,
exportacion real a Markdown con todos los temas, exportar via botones,
busqueda via F7/F3, apertura directa en un tema y restauracion exacta
de la pantalla en todos los caminos.

    cd tests && hbmk2 test_help_browser.prg ../help.prg ../hbbutton.prg -gttrm && ./test_help_browser
    # resultado en /tmp/hbide-help-browser-tests.txt

## Documentacion completa sin conexion

Las secciones 6-8 contienen todos los archivos Markdown versionados del
repositorio: manuales, referencia tecnica, checkpoints y planes. Cada
cuerpo conserva el texto completo y muestra su ruta fuente. No requiere
internet ni archivos docs/ junto al ejecutable. Busqueda y exportacion
incluyen estos documentos.

Tras editar documentacion ejecutar:

    python3 scripts/embed_help_docs.py
    python3 scripts/embed_help_docs.py --check

El archivo generado helpdocs.ch se versiona. Python solo se necesita para
actualizarlo, no para compilar ni para leer la ayuda en hbide.

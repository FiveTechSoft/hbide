# hbide: rapido, sencillo y fiable

> Historical design plan (26 October). Current execution and status:
> [COMPLETION_ROADMAP.md](COMPLETION_ROADMAP.md). Do not read this older
> snapshot as a current completion certificate.

Investigacion y plan de trabajo, 26 de octubre de 2026.

El objetivo no es acumular menus. Es editar, construir, depurar y volver al
trabajo sin perder cambios, con respuesta inmediata y una interfaz de texto
cuidada. Harbour primero. C solo cuando un perfil reproducible demuestre que
hace falta y una prueba de equivalencia proteja el comportamiento.

Este documento propone trabajo. No convierte lo pendiente en implementado ni
promete fechas. Las pruebas descritas hasta ahora son Linux; no acreditan el
mismo resultado en Windows. La publicacion del conjunto sigue pendiente.

## Orden de construccion

```text
                     [ Trabajo a salvo ]
                      /              \
        [ Guardado y recuperacion ] [ Build verificable ]
                      \              /
                   [ Documentos independientes ]
                              |
               [ Proyecto + Messages + navegacion ]
                              |
             [ Interaccion uniforme y scroll real ]
                              |
          [ Buscar simbolos + ayuda + depurador pulido ]
                              |
               [ Integraciones opcionales LSP/DAP ]

  En todas las fases: medir -> probar -> mirar -> integrar
```

## Estado que podemos sostener

| Area | Estado y limite |
| --- | --- |
| Ventanas del depurador | Move/Size, Zoom reversible, Tile y Cascade implementados; paso por codigo probado en Linux. Animate tiene defectos visuales conocidos. |
| Ayuda | F1 contextual sobre menus, enlaces y atras/adelante implementados. No implica F1 dentro de cualquier modal ni consulta automatica de toda la API. |
| Rendimiento editor | Parche Harbour integrado; mantenedor confirma Shift/seleccion/cut/undo/redo en IDE real. No se publican cifras sin metodo y distribucion reproducibles. |
| Proyectos | Modelo .hbp, hbmk2, exitcode, Messages y desktop integrados y revalidados por el mantenedor; no confundir integracion local con publicacion. |
| Regresion de pruebas UI | GTCGI introduce Enter y no sirve para probar esta cola interactiva. Suite aislada GTSTD revalidada 3/3 por el mantenedor, modulo y build IDE correctos; discrepancia cerrada. |
| Documentos multiples | Multidocumento real implementado (aEditors/nCurrent; New/Open/Close; Next/Prev Ctrl+F6/Ctrl+Shift+F6; menu Window; journals por doc; SaveAs con rechazo de ruta abierta). Verificado en Linux: 37/37 checks PTY (tests/test_multidoc_pty.py): A/B/A sin copiar texto ni borrar undo/redo, cursor, scroll, seleccion y breakpoints por documento, journals sin mezcla, recovery en lote tras kill -9, cierre por doc y salida con revision; capturas VTE reales entregadas. Pendiente: validacion Windows. |
| Guardado | Guardado atomico por fichero demostrado (tmp en el mismo volumen + rename, .bak). Recuperacion visible tras crash/kill: journal central (~/.hbide/recovery) con refresco cada 2 s solo mientras el buffer esta sucio y aviso al arrancar con Recuperar/Descartar/Despues. Durabilidad declarada: se recupera el contenido del ultimo tick de 2 s, no cada tecla; escritura atomica del journal (tmp+rename) para no ofrecer journals rotos; si el journal no se puede escribir, la edicion continua y se avisa una vez por racha de fallos. Limites declarados: una clave por ruta absoluta (alias/symlinks no se resuelven) y un solo buffer. Cada instancia escribe su propio journal (nombre con id de sesion), asi guardar o descartar en una instancia nunca borra el trabajo sin guardar de otra; si el journal no puede escribirse, el editor avisa una vez por racha de fallos (la recuperacion queda OFF visible, nunca se supone activa). Verificado en Linux: E2E kill -9 + rearranque + Recuperar + guardado byte-exacto, suite test_recovery 36/36. Pendiente: comparar antes de recuperar y validacion Windows. |
| Disenador | Tiene flujo propio en evolucion. Preservar su trabajo y separar codigo generado de handlers manuales; no duplicar aqui ese desarrollo. |

Las notas locales con evidencia mas detallada estan en
[ventanas](borland-window-layout-2026-10-26.md),
[ayuda](context-help-2026-10-26.md) y
[proyectos](project-module-2026-10-26.md).

El mantenedor tiene reservados editor.prg y hbide.prg para P0 de guardado y
Run > Start. Multifichero espera ese cierre; este plan no modifica esas zonas.

## Prioridades y criterios de salida

| Orden | Mejora concreta | Sale de la fase cuando... |
| --- | --- | --- |
| P0 | Guardado transaccional por fichero | Si falla crear/escribir/cerrar/reemplazar, el contenido anterior y el buffer siguen recuperables. Pruebas de permiso denegado, disco lleno simulado y proceso terminado entre pasos. No borrar el unico original para simular un reemplazo seguro. |
| P0 | Recuperacion visible de cambios sin guardar | Al reabrir tras cierre forzado aparecen buffers modificados, incluidos los sin nombre; se pueden recuperar, comparar o descartar explicitamente. Una copia oculta que nadie encuentra no basta. |
| P0 | Unificar build seguro | Tanto proyecto como Run > Start usan exitcode y resultado de ESTA compilacion. Un ejecutable viejo nunca convierte un fallo en exito. Probar compilador ausente, error Harbour/C, rutas con espacios y -run en HBP. |
| P0 | Separar inspeccion de ejecucion | Abrir un proyecto externo no ejecuta hooks, plugins ni binarios configurados por el proyecto. Build, Debug y metadatos que invoquen hbmk2 son acciones explicitas, no efectos de mirar un fichero. |
| P1 | Documentos multiples reales | Cada documento conserva texto, nombre, dirty, undo/redo, cursor, scroll, seleccion y breakpoints. Cambiar A/B/A no copia texto al fichero equivocado ni borra undo. Cerrar uno pregunta solo por ese documento; salir revisa todos. |
| P1 | Escritorio de proyecto | Sources/Messages vuelve al documento correcto; diagnosticos obsoletos se identifican como tales. HBP conserva bytes y tokens no evaluados; el editor no pretende ser otro hbmk2. |
| P1 | Build sin bloquear la interfaz | Salida incremental, estado y cancelacion real del proceso/arbol cuando la plataforma lo permita; tras cancelar no se habilita Run sobre el producto anterior. Sin cambiar cwd global durante edicion concurrente. |
| P2 | Barras de scroll funcionales | Flechas, carril y thumb representan posicion/rango; clic de pagina, arrastre, rueda y teclado concuerdan. Vacios, una linea, extremos, resize y ventanas inactivas no producen divisiones por cero ni restos. |
| P2 | Navegacion uniforme | Selector rapido de fichero abierto/proyecto, historial atras/adelante y busqueda de simbolos sin abrir docenas de dialogos. Una unica tabla de comandos alimenta menus, atajos y ayuda. |
| P2 | Buscar/reemplazar en proyecto | Resultados con fichero/linea/contexto, cancelacion y vista previa de reemplazos. Confirmacion antes de escribir varios ficheros; los cambios no confirmados no llegan a disco. |
| P2 | Texto y terminal fiables | CRLF/LF y codificacion se preservan; acentos, pegado multilinea, tabs y ancho de caracteres no corrompen texto ni posicion. Fallback CP437 probado, no promesa universal Unicode. |
| P3 | Inteligencia Harbour | Primero simbolos/documento, definicion y ayuda de parametros verificables. Evaluar servidor existente y compatibilidad antes de escribir otro o prometer rename semantico. |
| P3 | Depurador acabado | Corregir Animate/repaint y documentar limites; separar comandos disponibles de stubs. No anunciar Global si la VM no lo soporta. |
| P3 | Git y cambios | Ver diff/estado y comparar versiones antes de operaciones destructivas. No ejecutar comandos arbitrarios del repositorio al abrirlo. |
| Despues | LSP/DAP interoperables | Solo si hay servidor/adaptador util, licencia compatible, coste medido y capacidades probadas. El IDE conserva funciones locales si faltan o fallan. |

P0 es una puerta de calidad, no una razon para tirar los bloques ya hechos.
Se integra lo probado y se corrigen primero los caminos que pueden perder
trabajo o presentar una compilacion fallida como utilizable.

## Que tomar de cada referencia

| Referencia comprobada | Lo que interesa | Lo que no copiar |
| --- | --- | --- |
| Turbo C++ 3.0, manual Borland 1992 [1] | Escritorio, proyecto, ventanas y depurador como un flujo coherente. | Codigo propietario, opciones sin funcionamiento o limites historicos como requisito actual. |
| Turbo Vision mantenido [2,3] | Teclado/raton, foco y terminal moderno. La visibilidad de scrollbars cambia por estado en el diseno clasico. | Migrar a C++ solo por adoptar su apariencia; mezclar bytes CP437 y UTF-8 sin contrato. |
| VS Code: hot exit [4] | Copias de buffers sin guardar y recuperacion facil de encontrar. | Su politica exacta de 2016 como si fuese la politica actual: la fuente es historica. |
| VS Code: Workspace Trust [5] | Distinguir leer codigo de ejecutar herramientas/configuracion del proyecto. | Considerar una casilla de confianza una garantia contra cualquier codigo malicioso. |
| Helix [6,7] | Selectores rapidos de simbolos/diagnosticos y capacidades de lenguaje separadas de la UI. | Afirmar diagnostico de todo el proyecto si el servidor solo analiza ficheros abiertos. |
| Extension Harbour/xHarbour [8] | Inventariar soporte real existente: diagnosticos, simbolos y depuracion. | Suponer compatibilidad LSP/DAP, reutilizacion de codigo o licencia por el solo README. |
| LSP y DAP [9,10] | Contratos de mensajes para separar UI de herramientas, capacidades y resultados. | Convertir los protocolos en requisito de la primera version o prometer capacidades sin backend. |
| SQLite, atomic commit [11] | Diseno ante escrituras parciales, cache del SO y fallos de energia. | Llamar atomico a cualquier rename o anadir una base de datos sin necesidad. |

La referencia FoxPro solicitada para sus barras de scroll sigue en investigacion
separada. Su aspecto ya orienta la exploracion visual, pero aqui no se afirma
haberlo instalado, medido ni reproducido su comportamiento. No comparar latencia
con hardware historico a partir de una captura o de un emulador.

## Diseno tecnico propuesto

Separar documentos, vistas y procesos sin reescribir todo de golpe:

- Documento: identificador estable, ruta canonica, texto, version, dirty,
  historial y estado de recuperacion. Dos vistas pueden mostrar un documento;
  una ruta no debe crear silenciosamente dos copias divergentes.
- Vista: geometria, foco, cursor, seleccion y desplazamiento. El modelo sigue
  vivo aunque la ventana se oculte. Definir expresamente que es por documento
  y que es por vista antes de compartir una seleccion entre vistas.
- Proyecto: HBP original y configuracion; miembros literales y datos resueltos
  por hbmk2 no se confunden. No recorrer ciclos de subproyectos sin limite.
- Trabajo de build/busqueda: ID propio, raiz y entorno capturados, estado,
  salida, exitcode y cancelacion. Un resultado tardio no pisa el trabajo nuevo.
- Diagnostico: origen, fichero, rango, severidad y version/build de referencia.
  Una edicion posterior invalida o etiqueta su posicion; no saltar a ciegas.
- Comando: ID, etiqueta, atajo, disponibilidad y accion. Una funcion ausente
  se desactiva o no se muestra, nunca simula un exito.

No se propone una jerarquia nueva por gusto. Se introducen estas separaciones
solo donde resuelven una colision real: buffers multiples, jobs sin cwd global,
resultados obsoletos y restauracion despues de fallos.

### Guardado y recuperacion: contratos distintos

1. Guardar: escribir temporal en el mismo volumen, verificar resultado,
   cerrar/sincronizar segun plataforma y reemplazar mediante ruta soportada.
   Preservar permisos relevantes y detectar cambios externos. Investigar el
   reemplazo Windows y enlaces antes de proclamar atomicidad multiplataforma.
2. Recuperar: snapshots o journal de buffers modificados, con version e
   identidad, actualizados fuera del camino de cada tecla y con limites de
   almacenamiento. No sobreescribir el original como forma de autosave.
3. Restaurar: lista visible al arrancar, incluso para documentos sin nombre.
   Limpiar copias solo tras guardar/descartar con exito; recuperar no ejecuta
   proyectos, scripts ni configuracion ajena.

Una .bak ayuda, pero no sustituye ninguno de estos contratos. No prometer
"nunca se pierde nada" ante energia/hardware que aun no se han probado [11].

### Fluidez: objetivos propuestos, no resultados

- Medir mediana y p95 por accion sobre 500, 4.000 y 20.000 lineas, mas Unicode,
  lineas largas y proyecto multifichero. Registrar maquina/build/driver.
- Separar tecla->ultimo byte, ventana de silencio y render de terminal. Una
  medida de PTY no incluye render ni red. No publicar cifras mezcladas.
- Presupuesto inicial propuesto: p95 de navegacion/edicion ordinaria <16 ms
  hasta ultimo byte en la maquina de referencia. Ajustarlo con evidencia, no
  presentarlo como garantia de todos los equipos ni del render.
- Background no significa un hilo por funcion: cola acotada, debounce,
  cancelacion y descarte de resultados de versiones anteriores.
- Optimizar el cuello medido, conservando el mismo resultado. El snapshot de
  undo requiere pruebas diferenciales antes de pasar a deltas por lineas.

### Acabado visual y facilidad de uso

Mantener el lenguaje Turbo Vision: marco, foco claro, jerarquia simple, color
con significado y sombras discretas. Las barras inspiradas en FoxPro deben
controlar scroll de verdad. Decidir de forma consistente si una barra inactiva
queda visible atenuada; no asumir que ocultarla al perder foco es un bug [3].

Probar 25x80 y 40x120, resize, oclusion, restauracion de modal y terminal sin
raton. El color no puede ser el unico aviso de error: texto e icono/marca
acompanan. Todo flujo principal funciona por teclado; atajos no contradicen
las etiquetas. Las filas cortadas tienen ruta de lectura completa.

## Puerta de integracion

Ninguna fase termina por compilar solamente:

1. Borrar binario/resultado anterior; build fallido corta la cadena. Fixtures
   aislados; no depender de basura dejada por otra suite.
2. Unitarias de modelo y parser; errores con stdout/stderr en distinto orden,
   comillas, espacios, rutas Windows y salida sin diagnosticos.
3. Regresiones de editor: escribir/pegar/borrar/seleccionar/undo/redo, varios
   buffers y conflicto externo. Comparar texto y estado contra referencia.
4. Interaccion GTTRM real con teclas, raton si disponible y pantalla inspeccionada.
   GTCGI sirve para otros usos, no sustituye al teclado de una terminal.
5. Inyeccion de fallos de guardado/build/recuperacion y resultados tardios.
6. Linux y Windows se validan por separado. Registrar no probado sin ocultarlo.
7. Mantenedor integra el conjunto y repite sus pruebas. Entregado, integrado,
   publicado y ejecutado por el usuario son estados diferentes.

## Decisiones abiertas antes de ampliar alcance

- Matriz minima soportada de sistemas/terminales/codificaciones y tamanos.
- Formato, ubicacion y retencion de recuperacion, con politica de privacidad.
- Proceso portable de build asincrono y cancelacion del arbol de procesos.
- Servidor Harbour candidato: capacidades reales, licencia, dependencias,
  cobertura de dialectos y coste de distribucion. README no es prueba de LSP.
- Cambios masivos: vista previa, undo entre ficheros y conflictos externos.
- Distribucion reproducible y smoke tests Windows sin reabrir diagnosticos
  agotados ni confundir binario viejo con el estado actual del repositorio.

## Fuentes leidas

Consultadas el 26-10-2026. Son referencias de diseno, no dependencias nuevas.
No se ha copiado codigo de estas fuentes.

1. Borland, *Turbo C++ 3.0 User's Guide* (1992), manual primario:
   https://bitsavers.org/pdf/borland/turbo_c/Turbo_C++_3.0_Users_Guide_1992.pdf
2. magiblot, Turbo Vision, documentacion del proyecto, terminal/Unicode/clipboard:
   https://github.com/magiblot/tvision/
3. Mantenedor y comunidad, estado/visibilidad de scrollbars (24-11-2023):
   https://github.com/magiblot/tvision/discussions/128
4. Daniel Imms, VS Code, diseno historico de hot exit (30-11-2016):
   https://code.visualstudio.com/blogs/2016/11/30/hot-exit-in-insiders
5. VS Code, Workspace Trust, documentacion oficial actual:
   https://code.visualstudio.com/docs/editing/workspaces/workspace-trust
6. Helix, Language servers, documentacion oficial:
   https://docs.helix-editor.com/master/lsp.html
7. Comunidad Helix, diagnosticos de proyecto y limites del servidor (06-06-2023):
   https://github.com/helix-editor/helix/discussions/7254
8. APerricone, extension Harbour/xHarbour, README del proyecto:
   https://github.com/APerricone/harbourCodeExtension
9. Microsoft, LSP 3.17, especificacion de protocolo, cancelacion/progreso:
   https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
10. Microsoft, DAP, vista general y separacion UI/adaptador:
    https://microsoft.github.io/debug-adapter-protocol/overview.html
11. SQLite, Atomic Commit, condiciones de almacenamiento y recuperacion:
    https://sqlite.org/atomiccommit.html

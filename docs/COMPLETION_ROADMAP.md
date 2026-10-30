# hbide: roadmap de cierre

Actualizado: 30 de octubre de 2026. Rama: `designer-robustness`.
Base inicial auditada: `f91fa20`. Cambios posteriores y su evidencia en COMPLETION_LOG.md.
No es una certificacion del IDE completo.

## Que significa 100%

Una version del IDE para trabajo real con Harbour: editar varios ficheros sin
perder datos, abrir proyectos, construir y ejecutar el resultado correcto,
depurar, disenar dialogos, generar codigo y volver a editarlo. Cada comando
visible debe tener efecto comprobado. Compilar o mostrar un menu no basta.

El cierre requiere inventario completo, pruebas de aceptacion y regresion,
revision visual y paquetes identificados por fuente y hash. Linux y Windows
se certifican por separado. Wine es evidencia complementaria, no sustituye
una pasada Windows nativa. macOS y Android aparecen en la guia, pero no estan
certificados: hay que fijar su contrato antes de prometer soporte completo.

No hay porcentaje global ni fecha inventada. Mientras quede una funcion del
alcance sin implementar o una prueba obligatoria pendiente, no se anuncia 100%.
Una limitacion de la VM no se convierte en funcion terminada: se declara,
se comunica y se decide su tratamiento. No se retiran requisitos para subir
un porcentaje. Nuevas ideas se separan del cierre de la version actual.

## Ruta

```text
 M0 Inventario y pruebas reproducibles
                 |
 M1 Datos y editor -> M2 Proyectos, build y ejecucion
                 |                    |
                 +------ M3 Depurador -+
                              |
                   M4 Disenador y GUI
                              |
                 M5 Windows y distribucion
                              |
                 M6 Regresion y cierre del alcance

 Siempre: reproducir -> corregir -> probar -> mirar -> commit/push
```

## Estados

- **Pendiente**: no comprobado en esta linea base o falta trabajo.
- **En curso**: hay un siguiente paso concreto en ejecucion.
- **Parcial**: existe evidencia, pero no cubre toda la aceptacion.
- **Bloqueado**: se registra causa y salida; no equivale a esperar al usuario.
- **Verificado**: prueba identificada sobre una fuente/build identificada.

Un hito no queda verificado por sumar pruebas de versiones distintas. Las
correcciones de hoy no heredan automaticamente pruebas antiguas ni Windows.

## Hitos y aceptacion

| ID | Trabajo | Aceptacion para cerrar | Estado inicial |
| --- | --- | --- | --- |
| M0 | Inventario de menus, atajos, comandos y limites | Cada entrada de IDE, debugger, proyecto, ayuda y diseñador tiene ID, accion, prueba Linux/Windows y resultado. Diferencias entre fuente y documentacion reconciliadas. | En curso |
| M1 | Editor, guardado y recuperacion | New/Open/Save/SaveAs/SaveAll/Close, dirty, conflictos externos, seleccion, UTF-8/LF/CRLF, undo/redo y multidocumento sin cruce de estado. Fallos de escritura y kill/restart conservan original y cambios recuperables. Comparacion antes de recuperar revisada. | Parcial Linux; Windows pendiente |
| M2 | Proyectos, navegacion, build y run | HBP preservado; abrir no ejecuta hooks; errores saltan al fichero correcto; argumentos literales. Fallo/cancelacion nunca ejecuta binario antiguo. Rutas con espacios, compilador ausente y diagnosticos obsoletos. Medir bloqueo UI y resolver salida/cancelacion segun contrato. | Parcial Linux; Windows pendiente |
| M3 | Debugger completo | Step/trace/go/cursor, BP tras ediciones, watches/tracepoints, variables, expresiones, pila, workareas, ventanas, comandos y settings con efecto real. Animate sin corrupcion visible. Resolver Exchange Screens/swap on Input; no stubs. Reinicio y Global requieren investigar soporte VM y contrato explicito. | Parcial; faltantes conocidos |
| M4 | Disenador y GUI | Todos los controles: crear, editar propiedades/eventos, mover/resize, foco, atajos, undo/redo, guardar/recargar JSON, generar/abrir PRG, compilar y ejecutar desde IDE. Preservar handlers. Disenos grandes accesibles; sombras, bordes y restauracion modal limpios en 25x80/40x120. | Parcial Linux; Windows pendiente |
| M5 | Plataformas y paquete | Build limpio Linux y Windows de la misma fuente; hashes y version visibles; smoke del binario distribuido exacto. Windows: F12, drag/resize y generar/abrir/ejecutar, editor/debugger/ayuda. Instalacion en entorno limpio y licencias/dependencias revisadas. | Pendiente |
| M6 | Cierre verificable | Matriz completa sin fallos criticos ni opciones decorativas; regresion completa repetida sobre el candidato final; capturas completas; docs coinciden; restantes exclusiones y decisiones explicitas, entrega comprobada. | Pendiente |

## Cola inmediata

| ID | Hallazgo / siguiente paso | Evidencia y salida |
| --- | --- | --- |
| Q11 | ComboBox faltante (correccion usuario 29Oct23:44). | Implementado Linux: F2, propiedades/items/eventos, JSON, resize, LISTBOX DROPDOWN nativo. PTY25checks incluye generar/compilar, abrir/cerrar, seleccionar con teclado/raton y variable enlazada; capturas reales inspeccionadas. Height reserva area desplegable, minimo4. No editable libre; Windows pendiente. |
| Q12 | Ejecucion: fuente, rutas, errores y argumentos. | Correcciones publicadas hasta e3a00a6: sin reescritura Main; includes locales/SDK; Start rutas literales/no falso Build OK; Script conserva fila de app y restaura editor; argumentos vacios no desaparecen. Pruebas por revision en COMPLETION_LOG.md. Build sigue sincronico/no cancelable. |
| Q01 | Baseline automatizada disponible; ampliar cobertura. | Runner de modelos y runnerPTY con revision/hash por caso. Nueve modelos y32casos registradosPTY pasan limpiosdfd8d27, mismoSHA binario6c2829fe. Evidencia docs/evidence/linux-pty-dfd8d27.json. Es baseline historica, no heredada tras cambios de Run. Intento3351441:35PASS y1expectativa obsoleta Calls, corregida/probada en3e6fb2a. Runner actual38suites; no pasada completa actual niWindows. |
| Q02 | Discrepancia Iconize corregida. | Ayuda corregida en7254317; layout y PTY comandos18/18 confirman iconize/restore/viewport. Ayuda GTTRM120x40 inspeccionada. |
| Q03 | Dos opciones visibles llaman `NotSupported()`. | `hbdebug/dbgmenu.prg`: Exchange Screens y swap on Input. Investigar mecanismo antes de parchear; Menu Bar ya tiene implementacion aprobada y pruebas Linux. |
| Q04 | Animate: prueba funcional no prueba acabado. | `test_debug_animate_pty.py` acredita avance, no ausencia de tearing. Capturar secuencia real con salida de app, diferentes velocidades y F4 ida/vuelta. |
| Q05 | Windows actual sin entorno heredado. | Reconstruir toolchain si viable; no repetir indefinidamente el diagnostico Wine agotado. Si no hay Windows nativo, informar esa carencia y continuar Linux. |
| Q06 | Decisiones aprobadas 29Oct21:24. | F2 duplicadas ciclan+Enter; Menu Bar ocultable con recuperacion Alt+O,M. Implementacion y pruebas Linux; Windows pendiente. |
| Q07 | Inventario fuente vs comparacion Borland. | La comparacion es historica: Iconize existe; evaluar/modificar expresiones tiene caminos upstream. Auditar antes de declarar funciones ausentes. |
| Q08 | Datos/editor: fallos corregidos con reproduccion. | Delete/Ctrl+G; UTF8valido/host; CRLFuniforme; F3adyacentes/wrap; encoding+BOMtrascrash. Ver log para revision/pruebas; no herencia automatica. |
| Q10 | TAB: bytes preservados sin word-wrap. | Antes hb_MLEval repetiaTAB; modelo fisico crudo y pintura tabstops4 con cursor/seleccion/raton/scroll.120checks editor y recuperacionTABPASS. Splitter/reflow wrapconTAB probado con UTF8+undo/redo, no todas las acciones heredadas. Regresion32PTYdfd8d27 posteriorPASS; no cubre todas lasaccioneswrap. |
| Q09 | Terminadores mixtos: preservacion por linea implementada. | CRLF/LF/CR y EOF sin terminador, split/join/cut/paste/replace con undo/redo y cursor reflow:46checks Linux. Kill/recuperar/guardar mixto byteexacto PTYPASS. No certifica Windows ni todos los caminos word-wrap heredados. |

## Ampliaciones que no se confunden con cierre probado

El [plan de diseno anterior](ROADMAP.md) y la
[comparacion Borland](turbo-cpp-comparison-2026-10-29.md) se conservan como
historia y propuestas. Sus tablas no son el estado actual.

Pendientes de acotar durante M0: ventanas independientes de editor con
Tile/Cascade/Zoom, persistencia de sesion/preferencias, navegacion de ayuda y
copiar ejemplos, importacion de PRG generado al diseñador sin tocar handlers,
busqueda/reemplazo en proyecto y scroll completo. No afirmar two-way arbitrario
por tener una previsualizacion de codigo.

LSP/DAP, Git integrado, impresion, shell adicional y nuevas demos no se
convierten en dependencias de cierre por aparecer en una lista de ideas. Si
pasan a alcance de la version, se les asigna requisito y aceptacion antes.
Las demos TOTAL ON, agenda y FoxPro no certifican el conjunto del IDE.

## Seguimiento

- [COMPLETION_INVENTORY.md](COMPLETION_INVENTORY.md): primer inventario generado,
  47 contratos vinculados a116acciones de menu y rutas ampliadas de teclado/comandos; son conexiones de fuente, no116 funciones
  terminadas. Incluye dos stubs. Aun faltan modales, editor y gestos.

- Registro de cada lote en [COMPLETION_LOG.md](COMPLETION_LOG.md): fuente,
  plataforma, build/hash, comando, resultado y limites.
- Cambios pequenos y frecuentes en esta rama, sin merge ni force-push a master.
- Partes cada 20 minutos por el canal acordado: cambio real, pruebas, bloqueo
  y siguiente paso. Si no hay cambio, decirlo; un parte no sustituye trabajo.
- Capturas completas cuando haya cambio visible, incluidos bordes inferiores.
- No optimizar por intuicion: Harbour primero; C solo para cuello medido.
- En cada cierre revisar requisitos, no solo contar checks. La misma prueba
  repetida no es progreso adicional ni porcentaje.

## Referencias de verificacion

`hbide.prg`, `editor.prg`, `designer.prg`, `help.prg`, `project.prg`,
`projectui.prg`, `nav.prg`, `recovery.prg`, `hbdebug/dbgmenu.prg`,
`hbdebug/debugger.prg` y `tests/`, leidos en la base indicada.
El registro conserva las discrepancias para que el roadmap no herede estados
obsoletos de las notas del 25-26 de octubre.

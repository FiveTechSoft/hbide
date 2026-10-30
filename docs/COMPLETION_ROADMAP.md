# hbide: roadmap de cierre

Actualizado: 31 de octubre de 2026. Rama: `designer-robustness`.
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

No hay porcentaje global ni fecha inventada. No hay pesos ni denominador estable de tareas que permitan estimarlo: siete hitos, cero cerrados, uno en curso, cuatro parciales y dos pendientes de aceptación. Cero hitos cerrados no significa cero implementación. Mientras quede una funcion del
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
| Q17 | Seleccion por doble clic y raton del editor. | Fix6b17647: resaltado antiguo no era rango editable; ahora escritura/Delete/Copy/Cut operan sobre palabra.20modelos+15inventario+33docs,mouse18+EditMenu37PTY de fuente limpia; capturas fisicas120x40 seleccion/sustitucion/Undo inspeccionadas. Extension84e8d90 mouse31checks: TAB, EOLmixto, PageDown, viewporthorizontal, espacios/relleno y limitesrueda. Primer probeEOF38537e6 fallo por tecla de harness incorrecta; ledger conserva ambos. No contrato inventado de gutter/marco,25x80 niWindows; no cierreM1. |
| Q11 | ComboBox faltante (correccion usuario 29Oct23:44). | Implementado Linux: F2, propiedades/items/eventos, JSON, resize, LISTBOX DROPDOWN nativo. PTY25checks incluye generar/compilar, abrir/cerrar, seleccionar con teclado/raton y variable enlazada; capturas reales inspeccionadas. Height reserva area desplegable, minimo4. No editable libre; Windows pendiente. |
| Q12 | Ejecucion: fuente, rutas, errores y argumentos. | Correcciones publicadas hasta e3a00a6: sin reescritura Main; includes locales/SDK; Start rutas literales/no falso Build OK; Script conserva fila de app y restaura editor; argumentos vacios no desaparecen. Pruebas por revision en COMPLETION_LOG.md. 5032ed5 preserva nombre resuelto byte-exacto en Start (argv del compilador falso comprobado); 53feb8e rechaza HBP no legible sin confundirlo con vacío válido. Conjunta015970f:12PTY+10modelos+modelo adicional PASS, mismo binario; Navigation tuvo primer intento interrumpido externamente y repetición PASS. Evidencia linux-m2-joint-015970f.json. 803951d rechaza salida que coincide con fuente normalizada para evitar reemplazar una fuente sin extensión por ejecutable. b6a4f11 amplía la protección a documentos nombrados abiertos; cuatroPTY+diezmodelosPASS limpios, evidencia linux-open-document-collision-b6a4f11.json. No inventaría fuentes cerradas ni resuelve todos los alias por enlaces. Build sigue sincronico/no cancelable; probes Linux de cancelación no integrados y líder terminado no garantiza árbol terminado. |
| Q01 | Baseline actual coherente; ampliar cobertura. | Conjunta Linux a95687b:42PTY+1guard+diezmodelos+modelo adicional HBPread PASS, mismo binario60b7d1b9, sin fallos/reintentos/interrupciones (linux-joint-a95687b.json); no62global/Windows. Bloque posterior c468989:5PTY GUI/editor/navigation+diezmodelos PASS; Navigation interrumpido al agotar lote110s y repetidoPASS, registrado por separado (linux-gui-c468989.json), no sumado como misma conjunta. DebugFunctions original de esperas fijas sigue sin resultado actual completo; modo explícito --idle-settle c072cec conserva58aserciones y pasó limpio53.37s+diezmodelos, sin afirmar equivalencia temporal/visual. Exits16 aislado de imports ejecutables y Commands69 explícito PASS sobrea7c2cd2. Último global48c7c37:49casos ejecutados,47PASS/2fallos de secuencia modal de prueba, diez modelos PASS; tres interrupciones externas. Fallos aislados sin cambio de producto y Commands69+Exits16propios/69importados PASS limpios5faadfe. No49verdes juntos ni herencia a HEAD; runner actual91; el guard estático cuenta aparte de90casos/modosPTY (dos modos DebugFunctions no son dos funciones). Baseline histórico tras fix Cascade: diez modelos y43suitesPTY distintas con resultado final PASS sobre53be664 limpio, mismoSHA16465a64, sin mutaciones. Evidencia docs/evidence/linux-pty-53be664.json conserva45intentos: dos fallos de infraestructura PATH luego PASS y dos interrupciones externas sin resultado luego PASS. No es pasada sin reintentos. Históricos63239d2/0768ac2 y fafdf0c conservados. Dos stubs, combinacionesQ13, visual exhaustiva yWindows pendientes; no100%. |
| Q16 | Integridad de temporales Debug y scripts CLD. | 90b567a crea PRG/HRB exclusivos y comprueba escritura completa/cierre; errores impiden compilar/ejecutar y limpian sólo temporales propios. TresPTY+12modelos237b0a6PASS limpios: PRGparcial32, HRBparcial256 y compilaciónrechazada. Captura nativa focal del aviso PRG inspeccionada; no todas las geometrías/Windows/fsync. CLDdefault/extensión/cwdantesPATH/init implementado de572e6; opcionalinit ausente silencioso corregido3f6e726 tras descubrir aviso espurio. INPUT explícito ausente/no legible avisa. No transacción de scripts arbitrarios ni Restart implementado; unloadHRB deja PUBLIC/SET/DB vivos en fixture aislado. Evidencias por revisión en docs/evidence/, no suma global. |
| Q14 | Expectativa NumOff reconciliada. | Intento fafdf0c limpio conserva42PASS+1fallo textual en docs/evidence/linux-pty-fafdf0c.json. Comparador corregido en929a6bc, DebugFunctions58PASS limpio. Nueva pasada63239d2 completa43PASS+10modelos sustituye candidato, no reescribe el intento anterior. |
| Q02 | Discrepancia Iconize corregida. | Ayuda corregida en7254317; layout y PTY comandos18/18 confirman iconize/restore/viewport. Ayuda GTTRM120x40 inspeccionada. |
| Q03 | Dos opciones visibles llaman `NotSupported()`. | `hbdebug/dbgmenu.prg`: Exchange Screens y swap on Input. Investigación Linux aislada dcef66c/d66316b: snapshots GT no son superficies ocultas; contexto NUL separado preserva salida sólo con geometría efectiva igual. Teclas sintéticas y colores quedan aislados por contexto; tecla PTY real no llega automáticamente a NUL. Puente idle aislado puede reenviarla pero también durante Sleep; distinción de stack sólo observada en fixture. Integración, resize y excepciones no aceptados. No hay toggle integrado ni Swap universal. Investigar mecanismo antes de parchear; Menu Bar ya tiene implementacion aprobada y pruebas Linux. |
| Q13 | Restore de layout manual puede tapar Calls. | Reproducido: Save asignaba rectangulos por foco actual y Next, no por identidad. Corregido con Window Select por nombre; PTY compara geometria guardada/re-guardada y Calls visible tras restores repetidos, captura inspeccionada. Iconized tambien guarda estado y rectangulo original: restore repetido y expansion con contenido comprobados, capturas inspeccionadas. Zoom guarda rectangulo previo y permite unzoom tras restore con geometria original verificada. Pruebas adicionales: Calls destruido y Monitor oculto se recrean/reabren con geometria exacta. Points oculto tras Delete ALL tambien reabre con geometria exacta; iconizado restaura repetidamente y expande su browser; zoom oculto restaura dos veces y unzoom devuelve layout original. Cascade guarda celdas enteras (antes decimales rechazados por Move dejaban ventanas en1,0); restauración repetida exacta comprobada. Capturas completas inspeccionadas. Parcial: no todas las combinaciones entre ventanas ni Windows. |
| Q04 | Animate: prueba funcional no prueba acabado. | `test_debug_animate_pty.py` acredita avance, no ausencia de tearing. Secuencias20fps Speed1/5 con salida real y F4 ida/vuelta capturadas; screenshots completos y contactos2fps inspeccionados, docs/evidence/animate-35f84ec/. Parcial: no ausencia de tearing certificada, transitorios<50ms y otras pantallas/plataformas pendientes. |
| Q05 | Windows actual sin entorno heredado. | Reconstruir toolchain si viable; no repetir indefinidamente el diagnostico Wine agotado. Si no hay Windows nativo, informar esa carencia y continuar Linux. |
| Q06 | Decisiones aprobadas 29Oct21:24. | F2 duplicadas ciclan+Enter; Menu Bar ocultable con recuperacion Alt+O,M. Implementacion y pruebas Linux; Windows pendiente. |
| Q07 | Inventario fuente vs comparacion Borland. | La comparacion es historica: Iconize existe; evaluar/modificar expresiones tiene caminos upstream. Auditar antes de declarar funciones ausentes. |
| Q15 | Comparacion previa a recuperar. | Resumen Compare read-only implementado b633b36: lectura/tamaños/igualdad byte-exact cuando comparable; UTF8/BOM reconstruye bytes de guardado sólo con codepage conocido y roundtrip lossless; no afirma igualdad de texto normalizada. Compare vuelve a la decisión sin cargar/guardar/descartar. c4ead06: Compare/Codepage/CodepageRefusal/Utf8Bom/Help y diez modelos limpios PASS, recovery77, captura inspeccionada. View bytes añadido254c0b9: snapshots hex/ASCII seguros, J/D y scroll, salida sin mutar. CuatrocasosPTY+diezmodelos limpios PASS. Los tamaños de PTY inicial no certifican visor25x80: New fija40x120 y puede redimensionar el terminal; dos capturas son iguales. Verificación posterior con entrypointRecoveryViewProbe+ApplyDisplay valida dimensiones efectivas y capturas distintas25x80/40x120 del visor directo (docs/evidence/recovery-byte-geometry/); no cambia startup40x120. Parcial: no diff por líneas ni texto Unicode interpretado; no cierra M1/Windows. |
| Q08 | Datos/editor: fallos corregidos con reproduccion. | Delete/Ctrl+G; UTF8valido/host; CRLFuniforme; F3adyacentes/wrap; encoding+BOMtrascrash. Lectura comprobada antes de Open/Load y recarga; journal no legible/metadata/codepage/flags incompatibles/targetNUL rechazados antes de mutar; nombres destino preservados byte-exact. Joint0620762:20PTY+1guard+diezmodelosPASS, anterior a flags/targetNUL. Evidencias posteriores específicas por revision en docs/evidence/. Noherencia a HEAD ni Windows. |
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
  67 contratos vinculados a116acciones de menu y rutas ampliadas de teclado/comandos; son conexiones de fuente, no116 funciones
  terminadas. Incluye dos stubs. Modales IDE:43declaraciones inventariadas y43enlaces focales; diseñador30declaraciones/79pares enlazados. No aceptación completa. Debugger:27sitios de entrada no GET inventariados, sin aceptación implícita de callers. Faltan alertas dinámicas y gestos.

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

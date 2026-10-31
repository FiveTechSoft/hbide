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
| Q46 | Tab sobre selección dependía de dirección del rango. | 64382ac expandeTab después de borrar rango, en punto real de inserción. Antes5PASS2FAIL; cleanTab7/Identity5/Destructive19/Selection7mismo4cebd9e0+21modelosPASS. Nativefourspacescd col5/Undoabcd inspeccionados. Runner156=155PTY+guard. docs/evidence/linux-selection-tab.json. No wordwrap/Unicode/Windows global. |
| Q45 | Escribir texto idéntico sobre selección dejaba dirty falso. | a600e4c conserva dirty previo si selección no registra cambio neto. CleanIdentity5/Destructive19/Selection7/OVR3mismof495a8f0+21modelosPASS. Nativealpha col2/Close sinprompt inspeccionados. Runner155=154PTY+guard. docs/evidence/linux-selection-identity.json. No política general de no-op ni Windows. |
| Q44 | Escribir sobre selección absorbía escritura anterior en Undo. | 2fcc82b pasa selección previa a RecordEdit como frontera explícita. Antes5PASS2FAIL; clean Selection7/Cut7/NoChange9/Changed5 mismo128d0816+21modelos(87repaint)PASS. NativeUndoXalpha/RedoXYpha inspeccionados. docs/evidence/linux-selection-undo-boundary.json. No agrupación universal ni Windows. |
| Q43 | Cut absorbía escritura anterior en Undo. | 1c46903 marca Cut como operación separada; clean Cut7/Changed5/Boundary6/Block9 mismoadaf68d6+21modelosPASS. NativeUndoXalpha/RedoXpha inspeccionados. docs/evidence/linux-cut-undo-boundary.json. |
| Q42 | Replace conservaba selección de texto anterior. | 1dba6ee limpia rango sólo si cambia salida. Clean Changed5/Identity3/Boundary6/Spaces10 mismo05c99a2b+21modelosPASS; nativeomXega/Undoomega inspeccionados. Extensión6a85950NoChange9 conserva rango trasCancel/identidad/sinmatches; sin nuevo fix. docs/evidence/linux-replace-selection.json y linux-replace-nochange-selection.json. |
| Q41 | Clipboard interno no cruzaba documentos. | 764472e comparte cClipboard entre instancias; Undo/Redo siguen porbuffer. Copy/Paste6 y4model checks, nativebeta/alpha/Undoinspeccionados. ExtensionesClose8/Block9cubren Cut,cierre/New,EOLmixto. No OSclipboard/Windows. docs/evidence/linux-clipboard-multidoc.json, linux-clipboard-lifetime.json y linux-clipboard-block.json. |
| Q40 | Duplicate Line conservaba selección antigua. | 0fa7d14 limpia rango antes de duplicar; antes5/6PTY por borrado de bloque al escribir, después6PASS+4model checks. Native120x40 copia/Undo inspeccionados. Sin cambio Cut niWindows. docs/evidence/linux-duplicate-selection.json. |
| Q39 | OVR idéntico ensuciaba sin cambiar bytes. | a4857f7 activa dirty sólo si cambia línea. Antes2/3PTY, después3PASS+4model checks cursor/redo. NativeOVRcol2/Close sinprompt inspeccionados. No contrato global de no-op. docs/evidence/linux-overtype-identity.json. |
| Q38 | Delete Line dejaba ancla fuera de rango. | 8f256d5 limpia selección antes de quitar línea; selección3->1, Delete, typing antes error, después6PASS+4model checks. Native120x40typing/Undo inspeccionados. docs/evidence/linux-delete-selection.json. |
| Q37 | Recarga corta dejaba selección antigua. | f758bbe limpia selección en LoadText antes de sustituir líneas; ancla3 tras recarga1 causaba BASE/1132. Después4PASS+4model checks; nativeXfresh/Undo inspeccionados. Sin resolver política filenameUndoLoad. docs/evidence/linux-reload-selection.json. |
| Q36 | Paste descartaba línea sólo espacios. | 797dea5 usa Len>0, no Empty; antes2/4, después4PASS+4model checks conTAB. NativePaste/Undo y disco exactos. No cambio clipboard completamente vacío. docs/evidence/linux-clipboard-spaces.json. |
| Q35 | Replace idéntico marcaba dirty sin cambio. | 3516276 compara salida byte-exact antes mutar, conserva conteo y redo. Antes2/3, después3PASS+3model checks. Nativecount1/Close sinprompt inspeccionados. docs/evidence/linux-replace-identity.json. |
| Q34 | Undo Replace absorbía typing anterior. | 880fae2 añade frontera explícita de op Replace; antes2/3, después6PASS+6model checks. Typing normal aún fusiona. NativeUndoXalpha/RedoXomega inspeccionados. docs/evidence/linux-replace-undo-boundary.json. |
| Q33 | Replace descartaba búsquedas sólo espacios. | 7fd0a6b acepta Len>0; antes2/4, después10PASS y nativecount4/resultado inspeccionados con bytesEOL/TAB/trailing exactos. No expansión Unicode/multiline/Windows. docs/evidence/linux-replace-spaces.json. |
| Q28 | Tipo de propiedad objeto tras editar. | daed4cc refresca valor/accesibilidad tras setter, Enter deja de usar tipo inicial. Escalar a array antes5/6, despuesType6Getter6Setter8+20modelos15inventario33docsPASS. Native120x40array browserinspeccionado yResumeexacto. Getter se invoca; no promesa sin efectos/rollback/externalupdates/Windows. docs/evidence/debug-object-type-change/. |
| Q27 | Titulo de inspector array/hash tras navegar. | 8cd5a01 repinta ShowCaption tras SetCaption: antes8/11porfixture tituloestatico, ediciones1/21/40 yaeranexactas. DespuesHashNav11ArrayNav11LongHash7LongArray7+20modelos15inventario33docsPASS. Native120x40End40/PageDown36inspeccionados,Resumeexacto. No datoscorruptos/reordenacion/Windows. docs/evidence/debug-container-caption/. |
| Q26 | Enter en array/hash vacio dentro de objeto. | 53e20eb explica Array is empty/Hash is empty en vez de no hacer nada. Antes10/12, sin crash/mutacion; despuesObjectEmpty12TopEmpty12LongObject8+20modelos15inventario33docsPASS. Native120x40ambasalertasinspeccionadas yResumeexacto. No agregar elementos/politica readonly/Windows. docs/evidence/debug-object-empty-child/. |
| Q25 | Miembro objeto largo valido. | f82ad4f reserva columna valor con miembro61caracteres y setter62, antes5/8 por numero truncado. a8c0989corrige comparador de mayusculas, LongObject8Getter6Setter8+20modelos15inventario33docsPASS. Native120x40numero987654321completo yCancel99/Resumeexacto inspeccionados. No cambio simbolos63/Windows. docs/evidence/debug-long-object-member/. |
| Q24 | Claves largas del inspector hash. | e537b71 limita columna clave a mitad del ancho: antes edicion real41 invisible, columna valor negativa;5/7. Despues longkey7+Depth24PASS mismoIDE,20modelos15inventario33docs. Native120x40edicion41/Cancel99mantiene41 y Resumeexacto inspeccionados. bc0adb0 extiende reserva al array hijo de clave larga: antes5/7, despues LongArray7+LongHash7+Depth24PASSmismoIDE,20modelos15inventario33docs. Nativearray120x40edit41/Cancel99/Resumeexacto inspeccionado. No clave alterada/scroll nuevo/Windows. docs/evidence/debug-long-hash-key/ ydebug-long-array-path/. |
| Q23 | Variables unicas de Paste sin distinguir mayusculas. | 5d74cc3 corrige DsnVarUsed: NVAR1 antes se duplicaba como nVar1 y compartia enlace. Antes15/18, despues dosfixtures18PASScadauno+20modelos15inventario33docs. Native120x40 nVar2/Paste y NVAR1/Undo inspeccionados, JSONRedoexacto. No cambia enlaces compartidos manuales ni referencias de handlers. docs/evidence/designer-clipboard-case/. |
| Q22 | Flag readonly explicito entre inspectores. | a9ecaa6 propaga lEditable a hijos array/hash/object desde objeto. Probe de expresion .F. antes11/12 por objetoarray; despues12PASS+Depth24+20modelos. Ampliacionddd482f readonly20en cincofixtures+normalDepth24mismoIDE. Native355a765objetoarray alerta/Resumeexacto inspeccionado. No cambia defaultMonitor/Watch ni readonlytop, noarbitrarydepth/Windows. docs/evidence/debug-readonly-depth/ ylinux-debug-readonly-expanded.json. |
| Q21 | Seleccion inicial de fichero/proyecto y buffer GET. | b8d4852completa fixSTATEvacio/PadR250. Antesmouse13/14;intermediocf03a1dmouse14PASSperoKeyboard12/14porcolanombrecorto. Ambosretenidos;despuesmouse14keyboard14+20modelosPASS. Native49dce27keyboardyclikfisicoProjectexactoinspeccionados. Conjuntae563049seisPTY+20modelos15inventario33docs,mismoIDE84f0cd33sinreintentos. Nombres255rechazadosmax250sintruncar,manualpathprioritario. docs/evidence/file-modal-first-item/ ylinux-file-project-joint-e563049.json. |
| Q20 | Errores de propiedades del debugger. | dbb3870respeta flaggetterlCanAcc: getterfallido nohabilitaeditartextodeerror. Antes5/6,despues6PASS;normalDepth24y20modelos. Conjuntaa28051fScalar9Getter6Depth24Watch14Structured21+20modelos15inventario33docsPASS,mismoIDE67c8c3d5. Setterfallido8PASSerror/refresco/Cancel/Resume1exacto, sinprometerrollbackparcial. Nativegetter21eaca0/setter7b5f7cdinspeccionados. docs/evidence/debug-getter-failure/,debug-setter-failure/ ylinux-debug-inspector-joint-a28051f.json. |
| Q19 | CandidatoLinux identificado, no release. | Exportlimpio,build fuera del repo,manifest de hashes/toolchain/ldd; About muestra revision inyectada solo enexport y unrecorded en buildnormal, Version1.0intacta. SmokeAbout4+HelpMouse18+RunSource8 del binarioexacto56a4804PASS. Dosbuildsstrip557e51f identicos mismohost/toolchain; no generalizado a otros. Avisos:14modulosdebugger remiten aLICENSE.txt ausente y14sin cabeceraGPL detectada, sin inferir titularidad/licencia. Gate de release sigue1esperado; no instalador/portable/Windows/aceptacionM5. Posteriorf9c2af6exportstrippedSHAd3900284pasa8smokesAbout4Help18Run8Getter6Setter8Longlist5FileMouse14Keyboard14;manifestlinux-candidate-file-list-smoke.json. Previoafixa9ecaa6,noseheredaalactual;determinismoanterior557e51fsolomismohost/toolchain. Nuevoexport6317d0eSHA8029e6bf pasa8smokes+4extrasLongObject8LongHash7LongArray7ClipboardCase18 sobrebinarioexacto, dospasosacotados;linux-candidate-containers-extra.json. No matriz112global ni nueva prueba de determinismo. |
| Q18 | Enlaces de ayuda con prefijo compartido. | Filtro no exacto excluia Debugger windows al estar en Debugger. Se compara identidad exacta del titulo; prueba de modelo y clic anidado con cuerpo, historialBack/Forward y retorno sin cambiar fuente. Evidencia por revision enCOMPLETION_LOG, no cierreLinuxglobal/Windows. |
| Q17 | Seleccion por doble clic y raton del editor. | Fix6b17647: resaltado antiguo no era rango editable; ahora escritura/Delete/Copy/Cut operan sobre palabra.20modelos+15inventario+33docs,mouse18+EditMenu37PTY de fuente limpia; capturas fisicas120x40 seleccion/sustitucion/Undo inspeccionadas. Extension84e8d90 mouse31checks: TAB, EOLmixto, PageDown, viewporthorizontal, espacios/relleno y limitesrueda. Primer probeEOF38537e6 fallo por tecla de harness incorrecta; ledger conserva ambos. No contrato inventado de gutter/marco,25x80 niWindows; no cierreM1. |
| Q11 | ComboBox faltante (correccion usuario 29Oct23:44). | Implementado Linux: F2, propiedades/items/eventos, JSON, resize, LISTBOX DROPDOWN nativo. PTY25checks incluye generar/compilar, abrir/cerrar, seleccionar con teclado/raton y variable enlazada; capturas reales inspeccionadas. Height reserva area desplegable, minimo4. No editable libre; Windows pendiente. |
| Q12 | Ejecucion: fuente, rutas, errores y argumentos. | Correcciones publicadas hasta e3a00a6: sin reescritura Main; includes locales/SDK; Start rutas literales/no falso Build OK; Script conserva fila de app y restaura editor; argumentos vacios no desaparecen. Pruebas por revision en COMPLETION_LOG.md. 5032ed5 preserva nombre resuelto byte-exacto en Start (argv del compilador falso comprobado); 53feb8e rechaza HBP no legible sin confundirlo con vacío válido. Conjunta015970f:12PTY+10modelos+modelo adicional PASS, mismo binario; Navigation tuvo primer intento interrumpido externamente y repetición PASS. Evidencia linux-m2-joint-015970f.json. 803951d rechaza salida que coincide con fuente normalizada para evitar reemplazar una fuente sin extensión por ejecutable. b6a4f11 amplía la protección a documentos nombrados abiertos; cuatroPTY+diezmodelosPASS limpios, evidencia linux-open-document-collision-b6a4f11.json. No inventaría fuentes cerradas ni resuelve todos los alias por enlaces. Build sigue sincronico/no cancelable; probes Linux de cancelación no integrados y líder terminado no garantiza árbol terminado. |
| Q01 | Baseline actual coherente; ampliar cobertura. | Conjunta Linux a95687b:42PTY+1guard+diezmodelos+modelo adicional HBPread PASS, mismo binario60b7d1b9, sin fallos/reintentos/interrupciones (linux-joint-a95687b.json); no62global/Windows. Bloque posterior c468989:5PTY GUI/editor/navigation+diezmodelos PASS; Navigation interrumpido al agotar lote110s y repetidoPASS, registrado por separado (linux-gui-c468989.json), no sumado como misma conjunta. Actualizacion31Oct: originalfixedwait58PASS114.25sclean628b088enlinux-debug-functions-original-current.json; ya no pendiente en esa revision, no herencia a HEAD ni equivalencia visual. Historico: modo explícito --idle-settle c072cec conserva58aserciones y pasó limpio53.37s+diezmodelos, sin afirmar equivalencia temporal/visual. Exits16 aislado de imports ejecutables y Commands69 explícito PASS sobrea7c2cd2. Último global48c7c37:49casos ejecutados,47PASS/2fallos de secuencia modal de prueba, diez modelos PASS; tres interrupciones externas. Fallos aislados sin cambio de producto y Commands69+Exits16propios/69importados PASS limpios5faadfe. No49verdes juntos ni herencia a HEAD; runner en aquel corte125; el guard estático cuenta aparte de124casos/modosPTY (dos modos DebugFunctions no son dos funciones). Baseline histórico tras fix Cascade: diez modelos y43suitesPTY distintas con resultado final PASS sobre53be664 limpio, mismoSHA16465a64, sin mutaciones. Evidencia docs/evidence/linux-pty-53be664.json conserva45intentos: dos fallos de infraestructura PATH luego PASS y dos interrupciones externas sin resultado luego PASS. No es pasada sin reintentos. Históricos63239d2/0768ac2 y fafdf0c conservados. Dos stubs, combinacionesQ13, visual exhaustiva yWindows pendientes; no100%. |
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

### Regresión conjunta reciente del editor

Clean7b7f4af: doce suites recientes de selección/reload, no-op OVR/DeleteEOF/
BackspaceBOF, Replace identidad/frontera/espacios y clipboard (espacios,
multidocumento, Cut/cierre/New y bloques) pasan sobre el mismo binario8835931a,
en dos pasos acotados sin reintentos;21modelos15inventario33docs PASS.
Ledger `docs/evidence/linux-editor-clipboard-joint.json`. Sustituye la conjunta
98f3dfd de nueve suites para este bloque, no sus evidencias históricas.
No son147modos globales ni cierreM1/Windows. Runner147=146modosPTY+guard.
Candidate8 export513e9b9 incluyeQ39-Q41:8smokes+6extrasPASS en binarioexacto
4b4a5ca9. No release/instalador/licencias/Windows ni matrizcompleta.

### Corte posterior Q42-Q44

Runner153entradas=152modosPTY+guard estático al corteQ44; esto no es
153funciones aceptadas ni matriz completa. Evidencia conjuntaQ44 incluye
sólo sus cuatro suites y21modelos, sin heredar las doce suites de7b7f4af.
ClipboardUTF8 suma modo byte-exacto y modo terminalC.UTF-8 con ancho
anunciado correcto: café/niño nativos inspeccionados, no Unicode universal.
Ledgers linux-clipboard-utf8.json y linux-clipboard-utf8-terminal.json.

CandidatoLinux9 export6a85950 stripped2908eae5 pasa8smokes estándar y
Cut7/Changed5/NoChange9/UTF8Terminal10/Block9 sobre mismo binario inalterado.
Ledger linux-candidate-cut-replace.json. PredateQ44; no release, instalador,
licencias resueltas, Windows, matriz global o nueva prueba de determinismo.
Extensión960f4f4: Delete/Backspace/Enter19,Selection7,Cut7PASS mismo
b0e2bf20limpio; ledger linux-selection-destructive-boundary.json. No nuevofix
ni capturas. Runneractual154=153modosPTY+guard;153anterior era corteQ44.

Siete hitos conservan estados: cero cerrados, uno en curso, cuatro parciales,
dos pendientes. Decisiones oversizededit/filenameUndoLoad y límiteM2 intactos.

### Conjunta editor posterior Q46

Clean9f2736c:20suites distintas sobre mismo53cdeb14, cuatro pasos acotados
sin reintentos;21modelos15inventario33docsPASS. Incluye selecciónTab/identidad/
destructivas/boundary, Cut, cincoReplace, cincoClipboard, Delete/Duplicate/
Reload/EOF/OVR. Ledger linux-editor-selection-joint.json. Sustituye conjunta
12suites7b7f4af para este bloque, no historia; no155modosglobales ni cierreM1.

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
  110 contratos vinculados a116acciones de menu y rutas ampliadas de teclado/comandos; son conexiones de fuente, no116 funciones
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

Nota31Oct: EOL149era ejecuciones; bloqueUTF8word8duplicado se retira,141checks del modelo. Historial preservado, no149casos distintos.

### Q29 - Snap en limites impares

fa78719 MoveSelected y DragControl reclampan despues de redondear, como
ClampGhost. GET10dialog41x14 antesrow12col30 fuera delinterior; despues11/29.
Antes432PASS2FAILmodelo; cleanfa78719Snap6Case18y21modelosPASS. Extension
clean5cc04acDrag6Arrows6sameIDEed24ffa6 conserva dimensiones/binding/UndoRedo.
Nativo120x40 teclado borde/Undo inspeccionados, no dragpixels/Windows.
No politica oversized. Ledgers linux-designer-snap-edges.json y
linux-designer-snap-drag.json.

### Q19 - Candidato mas reciente, no release

Export3b3c606 incluye Q29. StrippedSHA
`ea72f2261cc4bcf68fbe3488b1764bf6d89709b9c581a5e2bc50018bccc8d072`.
Ocho smokes y seis extras pasan en mismo binario inalterado: Snap6,Drag6,
GET9,Combo9,Checkbox9,WindowLayout16. Manifest en
linux-candidate-snap-runtime-extras.json. No nueva prueba determinismo,
Windows, instalacionlimpia o licenciaaclarada. No closureM5.

### Q30 - DBF HRB APIs y WorkAreas real

HRB rechazaba DBCREATE antes de entrar al debugger aunque codigo C estaba
linkado. REQUEST explicito de DBCREATE/DBUSEAREA/DBAPPEND/DBCLOSEALL/
DBSELECTAREA registra esas APIs. Dos DBF propios temporales, WorkAreas
alias/estructura/status,paneles,Esc/F6 y ResumeALPHArecord1exacto. Antes1/10,
despuesclean23bd0afWorkAreas10Scopes16sameIDE90a92c94+21modelosPASS;
linux-debug-workareas.json. Native120x40dosalias
inspeccionados. No implica catalogo completo HRB/RDD o Windows.

### Q19 - Candidato con Q30 incluido

Export6cfda9d strippedSHA
`81daf8ccd89fc1b1854712354193ad46ceb810edab85785ecebbbed04dcbd059`.
Ocho smokes estandar y seis extras sobre mismo binario inalterado:
WorkAreas10ScriptDBF5Snap6Drag6GET9Combo9. Manifest+logs extras en
linux-candidate-rdd-extras.json. No release/licencia/Windows/instalacion/
determinismo ni matriz128completa. Sourceexport identificado, no herencia
al HEADposterior.

### Q31 - Help debugger hit-test

Clic en cuerpo de Help cambiaba topic segun fila aunque fuera del browser.
Antes9/10; restringir coordenadas a columna topics conserva Keys tras
body/outside y clicizquierdocolumna abreFunction. Native120x40ambas capturas
inspeccionadas; no paginas/geometrias/Windows global. Ledger por revision.

# hbide: roadmap de cierre

Actualizado: 2 de noviembre de 2026. Rama: `designer-robustness`.
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

## Trabajo siguiente y evidencia vigente

Corte 2 noviembre02:10 Q540: candidato aceptado en alcance focal **C103**,
fuente `ef8c78792a1b5726d61dd61467b6cd77f0aaa5cc`,
bin `046e0aa60f3a72a335ebf203caaf6f9293644b4a9cd0c37cead6309138648bdd`.
Repaint no dibuja editor oculto; explicit Open currenthidden restaura ventana
completa/foco/watch, sin cambiar cancel/repintado/otros documentos.
Own8smokes/docs34/About/ldd/hidden20/reopenstrong11/parentMouse9/external5/close11
PASS, native1202x762hidden/reopen completos inspeccionados. C102 previo NOaceptado
por reopengate8/1 y8/3 conservado, no se borra fallo ni cambia su identidad.
No herencia matrizC101/Windows/install/license/hito. ReceiptC103Q540 propio.
Docs posteriores no embebidos, sin rebuild por docs. Reserva430MiB aprox;
preservaciones autorizadas cerradas, no mas retiros/build/export por inercia.

Historico anterior, no evidencia heredada por C103:


Corte 2 noviembre01:53 Q538: candidato aceptado en alcance focal **C101**,
fuente `2be7bb73e4133019648a725d6135cf4c2d21ad6d`,
bin `3dbd3a36ed387fea25839e0a01f019927e7f80882d5544313e14e610f2e8b148`.
Watch no asocia plantilla inicial al homonimo cwd/noname.prg; explicit Open
relativo sigue vigilado. Own8smokes/docs34/About/ldd/focal22/regresiones32PASS.
Native1202x762before/after inspeccionadas completas, plantilla conservada.
Recovery legacy ambiguo conserva comportamiento previo, no formato/politica nueva
ni solucion de ambiguedad. C100 export fallido antes compile intacto, C99 intacto.
Receipt linux-untitled-watch-c101-q538.json detalla baseline y readiness failures.
No matriz heredada/fullmatrix/Windows/install/licencias/cierre de hitos.
Docs posteriores no embebidos, sin rebuild por docs. Reserva170MiB aprox;
no nuevas retiradas/export/build sin defecto/capacidad.

Historico anterior, no evidencia heredada por C101:


Corte 2 noviembre01:21 Q533: ultimo candidato aceptado en alcance focal **C99**,
fuente `283f99c604db3de1b270666df1fdb64b2eec38c8`,
bin `42fc43771b08081372b9de7d9a7c534d407ba0286b17d20e94f4e6484f2a50f8`.
C98 trataba clicks status/bordes/titulo como coordenadas fuente; statusclick
tras cursor beta movia X a line38 con padding. Baseline cinco bordes5PASS5FAIL.
C99 rechaza Down/DBL fuera del rectangulo editor antes de ClearSelection/GoTo;
gutter/interior y host menu/close mantienen sus rutas, wheel no cambia.
Own8smokes/About/ldd/docs34 PASS; nonclient10/interiorMouse37 frescos PASS.
Visual nativa1202x762 antes Xline38/despues alphaXbeta row1 inspeccionada,
fuente/bordes/status completos. Primer harness tras Undo no encontraba beta
por viewport scrolleado; corregido CtrlPgUp/Home, logs iniciales conservados.
DBL interno no instrumentado por el harness nuevo, no todos tamanos/geometrias.
C98 conservado, no herencia de matriz/Windows/install/license/cierre de hitos.
Q534 docs posteriores no embebidos C99, sin build por docs. Reserva65MiB;
no mas retiradas autorizadas ni build pesado sin defecto concreto y capacidad.
Siguiente lectura/tests ligeros de hueco distinto, no variantes equivalentes.
Politicas y gates pendientes intactos.

Historico anterior, no evidencia heredada por C99:

Corte 2 noviembre01:12 Q530: ultimo candidato aceptado en alcance focal **C98**,
fuente `a02c032dfaf9c7184a865a8095cbbef09ff43e43`,
bin `a7b445bb3d80bf8a750a2de0a7ac582e7439644410df0071f17d706a4c1e1c3c`.
Debug comparte cwd con el host por una ruta independiente de Script. C97 con
hb_cwd("child") y F5 deja falso deleted/Recreate, wrong child save y temporales
.prg/.hrb en el directorio original: baseline4PASS5FAIL. C98 restaura cwd tras
HRB normal/error recuperado ANTES FErase y retorno al host. No impide cambios
cwd del programa durante run ni cambia toggles/restart/Cancel.
Own8smokes/About/ldd/docs34 PASS; Debugnormal9/error10 y repeticionnormal9,
Scriptnormal7/error8 frescos PASS. Limpieza de temporales en directorio correcto,
save original exacto y no childsave comprobados. Visual nativa1202x762 antes
falso aviso/despues editor limpio inspeccionada con fuente/bordes/status completos.
C97 conservado, no herencia matriz/Windows/install/license ni cierre de hitos.
No garantia hostcwd eliminado/inaccesible ni aislamiento general del proceso.
C78/C79 preservados independientes SHA-size-mode-mtime-uid-gid-inventario y
recheck original antes de retirar solo expandido redundante; bin/logs/originales
intactos. Se paro527998976bytes libres al alcanzar500MiB, C80 intacto.
Tras build reserva287MiB. Q531docs posteriores no embebidos C98, no rebuild
por docs. Siguiente hueco distinto reproducible, no variantes equivalentes.
Politicas y gates pendientes intactos.

Historico anterior, no evidencia heredada por C98:

Corte 2 noviembre01:07 Q528: ultimo candidato aceptado en alcance focal **C97**,
fuente `8db62f6e73fdd4fa8bebf6a296ae8066fe4d1a1f`,
bin `3170ef0f89bc2867e7ea636a9edae5d4e7cc9a9863f31ac15b79dac5674b6f2e`.
Script comparte cwd con el host: un hb_cwd("child") dejaba rutas relativas
apuntando a otra carpeta al volver. C96 mostraba falso File deleted/Recreate;
aceptar guardaba child/script.prg en vez del original. Baseline normal3PASS4FAIL,
error4PASS4FAIL. C97 restaura cwd del host tras HRB normal/error recuperado,
antes del poll/status/repaint. El script puede cambiar cwd durante su ejecucion.
Own8smokes/About/ldd/docs34 PASS; focal normal7/error8, ScriptErrors9/Screen7/
HBPportable3 frescos PASS. Visual nativa1202x762 antes falso aviso/despues editor
limpio inspeccionada con fuente/bordes/status completos. Probes iniciales25x80/
poll y fixture LOCAL tras sentencia corregidos, logs retenidos sin ocultar fallos.
C96 conservado, sin heredar matriz. No fix Debugcwd/general process isolation/
cwdhost eliminado ni Windows/install/license/cierre de hitos o politicas.
Q529 docs posteriores no embebidos C97, sin build por docs. Reserva160MiB;
no mas retiradas autorizadas. Siguiente hueco distinto con reproduccion concreta,
no variantes equivalentes ni builds para consumir reserva.

Historico anterior, no evidencia heredada por C97:

Corte 2 noviembre00:52 Q521: ultimo candidato aceptado en alcance focal **C96**,
fuente `ea630625ac5cab04a30a1f17fae3ee5016e0d7e2`,
bin `861deed01575d869459a6e4384df0a4d0ba63b99326c5dc04a50ddc256dd68f9`.
HBP valido con miembro sub\source.prg compila en hbmk2 real, pero C95 lo
marcaba missing y Enter no abria sub/source.prg existente (baseline1PASS2FAIL).
C96 normaliza separadores solo al resolver miembros literales de Open con
hb_DirSepToOS: conserva token y bytes HBP, no cambia parser de diagnosticos.
Own8smokes/About/ldd/docs34 PASS; portable3/spaces3/native3/horizontal4/
ProjectMouse11 PASS. Modelo project recompilado exit0/sentinelPASS separado
 del IDE. Visual nativa1202x762 antes !missing/despues ruta resuelta y editor
PORTABLE_MEMBER inspeccionada con bordes/status completos. Primer ls esperaba
nombre plain pero hbmk2 produce source; primer ProjectMouse sin PATH compilador
fallo y se repitio con PATH correcto, logs iniciales conservados.
No hereda matriz C95/Windows/install/license ni cierra hitos o politicas.
C95 conservado. C75-C77 preservados reversiblemente uno por uno con SHA/size/
mode/mtime/uid/gid/inventario y recheck original completos antes de retirar
solo copias expandidas redundantes; originales/binarios/logs intactos.
Lote detenido al alcanzar613MiB; tras C96 reserva391MiB. No mas retiradas.
Q523 cuatro modos frescos ProjectBOM3/EOF3/extensionless3/GCCcolon6,15PASS.
Q524 cuatro modos editor FindRepeat7/ReplaceUndo6/CtrlTtab3/DeleteLineUndo6,
22PASS. Q525 standalone Designer load/write/schema recompilados exit0 y
sentinelPASS, seis fuentes SHA identicas al export C96, helpers separados
del runtime IDE. Sin nueva decision UndoLoad ni suite completa. Reserva382MiB.
Q526 docs posteriores no embebidos C96; no build por docs. Siguiente hueco
funcional distinto, sin variantes equivalentes del parser/history/modelos.
Gates y politicas pendientes intactos.

Historico anterior, no evidencia heredada por C96:

Corte 2 noviembre00:39 Q516: último candidato aceptado en alcance focal **C95**,
fuente `1cdedd93da118bcdb33866d574943a784a00c0f6`,
bin `112573c77e3fe18c930a8bc76404027d0472d5a42aa06c1ed25a2ab2d23dd845`.
Q507 reproduce C93 ListPick filtro WindowListcafé: Backspace corta un byte y
deja UTF8 incompleto. C95 elimina carácter completo con hb_ULeft/hb_ULen,
sin nueva dependencia de helper, política ni upgrade del UTF8 experimental.
Own8smokes/About/ldd/docs34, filtroUTF8 5/WindowList9/Goto6 fresh PASS;
helperlexical autónomo141PASS separado del IDE. Native1202x762C93caf+glyph
corrupto/C95caf_ inspeccionados, fuente/bordes/status enteros. C94 intermedio
no finalaceptado: GetUPrev funcionó focal pero añadía dependencia nav-onlyhelper;
C95 usa API nativa y tiene aceptación propia. C93/C94conservados. No hereda
matriz ni soporte picturedGET/Unicode general/graphemes/casefold/Windows/licencia.
Fixture inicial apertura picturedGETaccentpath falló antes de filtro; privatecwd
Tablistbox abre café exacto. Ese límite experimental sigue sin corregir.
Q509MessageList8/Q510freeinput33/Q511clipboard22 fresh PASS acotados, no
herencia de candidatos anteriores ni modelos completos. Q513SaveAll/refusal4,
Q514deepmixed/deepBOM/Compare3 y Q515Project/Build5 modos frescos PASS con
receipts propios, sin matriz completa. Docs posteriores no
embebidosC95; no build por docs. Reserva actual~109MiB, no
más retiradas autorizadas. Próximo regresión identificada/hueco distinto sin
variantes equivalentes ni builds para consumir reserva. Gates/políticas siguen.

Histórico anterior, no evidencia heredada por C95:

Corte 2 noviembre00:11 Q504: último candidato aceptado en alcance focal **C93**,
fuente `2fb1b433c789f37ffcd45da4bc8cc3cd96627e61`,
bin `4139216fcc8dc49e1c8492f651250c6418addc0ebab55da5b948b391a61f37ee`.
Q502 reproduce C92 ProjectDesktop con clickcol0 fuera del panel alineado s02:
Enter abre s02 en vez s01 originalmente seleccionado. Es ruta independiente
de ListPick, no helper compartido. C93 limita MCol al interior del panel sin
cambiar activación. Own8smokes/About/ldd/docs34, horizontal4 y ProjectMouse11
PASS. Native1202x762beforeC92s02MARKER02/afterC93s01MARKER01, mismos eventos,
bordes inferiores/status completos inspeccionados. C92 conservado; no hereda
matriz/DBL interno/todos tamaños/Windows/install/licencia ni cierra hitos.
Docs posteriores no embebidosC93, no build sólo por docs. C81 árbol preservado
reversible íntegro antes retirar sólo expandido. Q503loteautorizadoC72-C74 uno
por uno preservado íntegro igual, detenido al alcanzar reserva550MiB; binarios,
fuentes originales/manifiestos/logs/evidencia intactos. No más retiradas.
Builds ligados a defectos concretos, no a consumir reserva. Próximo regresión
identificada y hueco funcional distinto, sin variantes equivalentes. Políticas
pendientes y gates anteriores permanecen abiertos.

Histórico anterior, no evidencia heredada por C93:

Corte 2 noviembre00:05 Q501: último candidato aceptado en alcance focal **C92**,
fuente `cdac56d54fd36c416678734e5ca94ba2595607a4`,
bin `d507d5446402cebf36dbd2692a549b76c5b5928753599f826351525085ebfcfb`.
Q495 reproduce HelpExport C91 siguiendo symlink y truncando notas de fixture.
C92 usa escritor compartido sibling exclusivo/verificado y promoción, rechaza
symlink/dangling/directory/FIFO observados con error claro. Regular overwrite
sigue permitido, sin nueva política. 8smokes oficiales/About/ldd/docs34 PASS;
symlink3/regular5/directory4/FIFO4/dangling4 fresh PASS. Native1202x762 beforeC91
Wrote+targetfixture alterado /afterC92 error+target intacto, bordes completos
inspeccionados. Clasificación previa NO es lock; no garantía TOCTOU ante cambios
concurrentes de alias/directorio padre. C91 conservado, sin herencia de matriz.
C82exportado preservado íntegro en archivo independiente antes retirar sólo
expandido; bin/manifiestos/logs/fuente original/evidencia intactos. Espacio~87MiB,
no más retiradas autorizadas. Docs posteriores no embebidosC92, no build por docs.
Q497-Q500 añaden regresión propia fresca ListPick/Helpwheel, SaveAs/recovery,
M2promotion/retry/missingoutput y M4mixed/validveto/ComboClipboard/InspectorSmall
con receipts separados. No equivalen a matriz completa ni herencia de C91.
Windows/install/license/gates/políticas siguen abiertos. Próximo hueco funcional
distinto, no variantes equivalentes. Espacio posterior~75MiB.

Histórico anterior, no evidencia heredada por C92:

Corte 1 noviembre23:40 Q491: último candidato aceptado en alcance focal **C91**,
fuente `a0e87553d3a05138583d6831c3a49a34ff652d58`,
bin `2bd8ffa509e6fec8589b338e9683193d9ef811ee285c01020af175217f0fe9b8`.
Q488 reproduce C90: ListPick acepta clicks fuera del diálogo horizontalmente
si comparten fila, y Enter salta a destino incorrecto. C91 limita MCol al
interior, sin cambiar activación. 8 smokes oficiales/About/ldd/docs34 PASS;
GotoFunction6, WindowList9, MessageList8 frescos PASS. MessageList usa dos
diagnósticos GCC reales warning/error con ruta que contiene dos puntos.
Píxeles nativos completos beforeC90/afterC91: XPROCEDURE fila7 incorrecta
frente Xfunction Main fila2 conservada; bordes inferiores/status completos.
C90 conservado. No hereda matriz, DBL instrumentado, todos los callers,
Windows/install/licencias ni cierre de hitos. Docs posteriores no embebidosC91.
Q487 C90UTF8 horizontal input7PASS es histórico, no regresión C91 implícita.
C83 árbol exportado preservado reversible e íntegro antes retirar sólo
expandido, bin/fuente original/manifiestos/logs/evidencia intactos. Espacio
posterior C91 ~150MiB; no nuevas retiradas autorizadas. Próximo: regresión
identificada y hueco funcional distinto, no variantes equivalentes ni builds
sólo por docs. Políticas/gates pendientes permanecen.

Histórico anterior, no evidencia heredada por C91:

Corte 1 noviembre23:28 Q486: último candidato aceptado en alcance focal **C90**,
fuente `6678e43385060fb018065ec0b842f00e604e44d2`,
bin `28e836faac4040ac64737a9cccfd9d5a8d3de60cbdfe9a0d4a3a23f5757ccb7d`.
Find/Replace/RunArguments free-form ignoran botones directos en C88; fix consume
DOWN/UP del mismo botón mediante hitTest nativo. C89falló focal por constante
sin include: rechazado/conservado, no sustituto aceptado. C90includecorregido,
8smokes oficiales frescos, Findmouse7/Replacebothfields11/Args14 y pairededges8
PASS; tecladoEditMenu37/Args14 separado. Píxeles completos beforeC88/afterC90
inspeccionados: Cancel cierra y restaura fuente/bordes/status. No hereda C88.
Catálogo posterior34byteexact no embebidoC90. Inventario detecta30ramas mouse,
29linksacotados; DBL sigue sin enlace instrumentado. Q483 secuencia rápida
5PASS no prueba el evento DBL interno. Q484 Find con café UTF8/BOM/mixedEOL
7PASS: Cancel conserva selección, OK busca fé y limpia rango, Undo exacto;
no grafemas/caracteres anchos ni todos los consumidores Unicode. No funciones/porcentaje/cierreM0.
Próximo: aceptación focal restante y documentación; no nuevos builds por docs.
Todos los gates/políticas/plataformas abiertos del bloque histórico permanecen.

Histórico anterior, no evidencia heredada por C90:

Corte 1 noviembre23:04 Q476: candidato anterior **C88**,
fuente `e32c6ece0a8d461f04f7244eb451e378211c7f14`,
bin `e85c0951c2310b4c103188bafacc0852a9906fc3c7b6873f06276246d6ae0b38`.
Q460 corrige RadioGroup mouse de Compiler Options con hit-test nativo;
8smokes oficiales/About/ldd/docs34PASS, mouse9/keyboard14/Display9/generatedRadio9
PASS y píxeles before/after completos inspeccionados. Q461last-firstradio,
Q463-Q467nav/TEXT/editor/SaveConflict/recovery, Q471Displaymouse y Q472-Q473M2/
designer añaden aceptación focal fresca de C88 con receipts propios.
No hereda matriz/modelos/píxeles de C87. Docs posteriores al build no están
embebidos C88; catálogo actual34byteexact, tooling posterior separado.

M0:27ramas sintácticas mouse con contratos acotados incluyen clasificadores y
no-ops; no son27funciones completas ni inventario exhaustivo. No cierre M0.
Siguiente: validar huecos de modales concretos y mantener regresión identificada;
no seguir variantes equivalentes sólo para subir conteos. Políticas M2Cancel,
M3ExchangeScreens/SwapOnInput/restart, oversizededit/filenameUndoLoad y revisión
Windows/install/licencias siguen abiertas. No porcentaje global ni hito cerrado.

Histórico anterior, no evidencia heredada por C88:

Corte 1 noviembre21:34 Q418: candidato anterior C87,
fuente e84d41e1d57f35aa1b42fe538b4ab11aa598f6fe,
bin a7f08d630682a8c13ac6ead900cead971c128fa5f974b23be2114d73191fca48.
8smokes oficiales/13TEXTcompilerfixtures39checksPASS; PRINTERabreviaciónfix.
GTSTD141PASS separado, sin heredar matriz/modelos/píxeles previos. Píxeles
C86/C87Q418 limitados al picker. Q420-Q425 agregan aceptaciónfocal sólo de
ese binario, detallada al final. Q430-Q432Save/Replace/Find también acotados
aC87; Q427-Q428 procedencia factual, no licencia elegida. Q433docs posteriores
no embebidos C87. Q434-Q439 contratosM0/gestos acotados detallados al final;
Q448docs posteriores tampoco embebidos, sin rebuild por docs. Q442-Q447
gestos medidos y contratosM0 acotados detallados al final.

Histórico anterior, no evidencia heredada por C87:

Q409candidato anterior C86, fuente81c06602b621616005bc9b2e45195fd9184f51a9,
bin c46a6b8134656df89aa177188b44bc261e2f7c72a6f1e0005ffaf9de9ee89a27.
Aceptación Q410-Q416 limitada a ese binario, no heredada por C87.

Histórico anterior, no evidencia heredada por C86:

Q405candidato anterior C85, fuente fbca0b71789b6d5dd3589587cf138ac91cbc90ba,
bin351bd50074b28c6fdfc5b029382c891ac6974ec799a828fc536f86628ba85f34.
8smokes/cincoTEXT15checksPASS identificados en sus receipts.

Histórico anterior, no evidencia heredada por C85:

Actualización 1 noviembre20:49 Q395: candidato anterior C83,
fuente c245e8c3047f97a8674f75bb0f1ae33123defe1e,
bin 92504b3338a3e2f24a14615d54d8ad4fd14b12f9901fd53cd8c1f8aa157309a5.
8smokes/cincofocal17checksPASS y aceptación posterior Q398-Q402 limitada
a ese binario, no evidencia del candidato C85.

Histórico anterior, no evidencia heredada por C83:

Actualización 1 noviembre20:38 Q389: último candidato identificado C81,
fuente299a1047a050517342b0aa4ebfb9170095e0388b,
bin2309304ec2ed54d6f005ef5afb6cbc0649d03cdaeec3f7322e6e9592303d059a.
8smokes/cuatro nav12checksPASS, integra END CLASSaliasQ387. Sin heredar matriz,
modelos/píxeles; Q391docs posteriores no embebidos. Detalle al final.

Histórico anterior, no evidencia heredada por C81:

Actualización 1 noviembre20:28 Q384: último candidato identificado C79,
fuentece049bfb140c38d0123c148c8711c7a488bba81e,
bin71194ee29d394ae294257a506d0d2c1add01cf5ffa307225d462b28ee95505b6.
8smokes/cuatro nav12checksPASS, integra BOMrawQ382. Sin heredar matrices,
modelos/píxeles; Q385docs posteriores no embebidos. Detalle al final.

Histórico anterior, no evidencia heredada por C79:

Corte 1 noviembre20:21 Q373-Q380 añade regresiones focales sobre C77exacto
(saveclose/nav/designer/BP/recoveryUTF8), detalladas al final. No se suman en
una matriz global ni heredan píxeles/modelos. Q381docs posteriores no embebidos.

Actualización 1 noviembre20:02 Q370: último candidato limpio identificado C77,
fuente74db43fe4e4bc5dae5f54e4663a4ffb8e9d0abd9,
bin b0ad4e6bb4ad5f5d87eef67111995dfdce3963c59745e2b101f543ea323beaeb.
Builder8smokes y seis modosclipboard27checksPASS. Integra corrección selección
virtualQ368, sin heredar matrices/modelos/píxeles. Q371docs posteriores no
embebidos; detalle al final. M5/M6 y decisiones pendientes sin cambios.

Histórico anterior, no evidencia heredada por C77:

Actualización 1 noviembre19:36 Q359: último candidato limpio identificado C75,
fuente93d3876480c5217e4eadddc2f88a4400c321146a,
bin e78652a51a586d67550d526c05a1ac54278d7b62459d26a23beace1afca024ef.
Builder8smokes y cuatro modosclipboard19checks PASS. Integra Q357 vacío copiado,
pero no hereda matriz ni píxeles; Q360docs posteriores no están embebidos.
Detalle Q355-Q360 al final. M5/M6 y decisiones pendientes sin cambios.

Histórico anterior, no evidencia heredada por C75:

Corte 1 noviembre19:10 Q347-Q350: candidato identificado C73,
source87222cbcada24332b0088889b1f34b59585b54f0,
bin18b791540ace75694a01f6774a80b09860bb656d7e7b4fde7e09b89d034973be.
Q347builder oficial strip-debug:8smokes/Aboutrevision/docs34byteexact/ldd PASS;
5modos focales22checksPTY PASS. Q348siete scripts críticos independientes PASS:
SaveAllparcial, SaveAsidentidad/colisión+killrestart, Replace/SelectionUndo,
Runemptyargs y ProjectMessages. Q349cinco modos48checks PASS: compilador ausente,
fallo conoutput, éxito sinoutput, conflictos externos literales y clipboardmultidoc.
Q350cuatro modos diseñador52checks PASS: mixedruntime, GETVALIDveto, ComboClipboard
handlers, Inspectorclose25x80. Runtime generado instrumentado acotado, no stock.
Q348primera invocación recuperación sin binario posicional inválida; Q350primer
GET sin --kind inválido. Corregidas y PASS; intentos retenidos, no retry-free.
Estos bloques son evidencia del MISMO C73, no matriz completa ni nuevos píxeles.
Q352dos rebuilds independientes mismo host/compilador/strip reproducen C73byteexact;
raíz mínima mismo host About/help/inspectordrag25x80 PASS, no instalación limpia.
Q353copia upstreamHarbour separada y procedencia14avisos:4archivos idénticos,
10modificados. No licencia global ni redistribución autorizada; LICENSE raíz
sigue ausente y decisión del titular/revisión de paquete abiertas.
Q354docs posteriores no embebidos en C73; no rebuild por receipts/docs.
C72focal anterior sourcea40862b43a362095202a85bdfc590f1d54ff8cee,
bin53d7a97a94793a1f946bb16005eba613cbce6f38d5ceef6fdf6d872a9a6d9937.
Q342tokens HBP literales sin extensión resuelven .prg como hbmk2, conservando
token/originalbytes. Compilerfixture exit0, C71baseline2/1, C72focal3checks y
4projectregresiones/modelProject PASS, par nativo1202x762 completo inspeccionado.
Q343quotedspace3checksPTY/modelProjectguards PASS; Q34437modelos GTSTD fresh
source95bacc5limpioPASS. No37modosIDE ni certificación del binarioC72.
C71focal previo fuente2ad2f5cc0096523d2fa1d0cbd2cd28de2be544b2,
bin632ba2ac1afd6cdd3cf1220820e9c5f0fcac5b4570acc7931c4fcba2457f905d.
Q339Delete EOL sin selección ancla join para preservar BP intactos tras
vacías idénticas. C70baseline2PASS3FAIL; C71LF5/CRLF5checksPTY y tres
scriptsBP PASS, modeloEOL184/0. Par nativo1202x762 completo inspeccionado.
Q338Backspace inicio presentaba defecto independiente: C69baseline2/3;
C70sourcea489844f48553e65d0629cbae915e5f2a3195a98,
bind822794b7f21dafc10d789a03ad818572e12bf80a813264b3da8bcdc5e976155,
LF5/CRLF5checksPTY y tresregresiones/EOL178 PASS, par nativo inspeccionado.
Q34037modelos GTSTD fresh del source25b3585 limpioPASS, no37modosIDE.
C69identificado anterior: fuente81671a06363b92386d77ce540a1d528c88f66340,
bin742396e08064b4692ff96a064e019d8a7f02c698a69deea0ceebc1c9b7f2b8e9:
About/catálogo34/ldd/8smokes y21checksPTY PASS. C68export parcial por disco
lleno nunca fue candidato; reintento C69 documentado, no ocultado.
C67focal Enter sourcefa2d571b2164e44230d228332a091c9a3ec5d608,
bin57a059065dc2f736bd53c91c5781c1c9b3004a7aad505c492936bcaeb303886f,
Q3336checksPTY/4regresiones y164modelo; Q334CRLF6checks/EOL172 PASS.
C66focal DECLARED METHOD sourcefa41c0a1afdb65ace575cb00174f4afbce63ca47,
bind981da58befdee0cecdec71232f6bbb921d6073267802757ec02e0873d1d112a;
Q32912checksPTY/111modelo PASS; Q330otros12checks compiler-valid PASS.
C65último identificado limpio: fuente59dd2ceb3755359aa9ca3b0bda5f61b4d5b620de,
bin86a0e16aec7151c495319069deb197542d4697f358c34802041c8ac7195f604b,
About/catálogo34/ldd/8smokes y navegación/editor27checksPTY PASS. No heredados aC66.
C64focal METHOD implícito source92949b344380ae3d6bd73364b7894c2a31e65cd5,
bin17169a76081a72c66609d72493effbefb67c5f1ed69ec7c47af5cc6d270f4625.
Q32415checksPTY/106modelo PASS; Q325otros15checks compiler-valid PASS.
C63focal previoCtrlT TAB: source89f6eb5bbd335c2ca37ed1e1f8718b55290210de,
bin9b49b783fe8176f915825a8b4570b0b7cc82d5231e62576835e7b8f9c1816d6a.
Q320cincomodosPTY23checksPASS; Q32122modelo/6PTYchecks postexport PASS.
C61identificado fuentef63e189288ae03122f892e0edccefc4129452503,
bine0399cb224f06c707b228d5d3291e3957a81bccd22278de355ac02f00e325c43:
About/catálogoQ314/ldd/8smokes/6BPmodos32checks PASS, no heredados aC63.
Q345docs posteriores no embebidos en C72, C71, C70 ni C69. No sumar fuentes/binarios
como matriz. Sin fullpreprocessor/customstream/navcontinuation/Windows/release/hitos.
C30 sigue siendo el candidato con plan353 reconciliado,
export049b5332628bbb8faa4458863405bc20438320ca,
bin96d77549996ebf15bf0040a7e134f5ce630ddaa22c5d073ad4df6e13df70ef29.
Plan353 reconciliado sin faltantes ni extras:352PTY y1guardafuente.
352scripts originales congelados +1navigation adaptado al viewer EscQ242.
About necesita EXPECT_REV12charsQ241. Fallos/reintentos/interrupciones
conservados, no afirmar ejecucion global sin fallos. Tres --create inertes
Q222 excluidos del conteo. No sumar smokes/focales solapados. No release,
licencias, Windows, instalacion limpia ni cierre de hitos. Evidencias
linux-c30-plan-reconciliation-q243.json y linux-c30-final-blocks117131-q243.json.
Siguiente brecha M0: mantener docs y contratos de teclado consistentes;
Q244 reconcilia seleccion/copia y elimina nota historica contradictoria.
No habilita WordStar/Ctrl+C ni cambia politica/teclas del producto.

Corte1Nov10:39: Q211metadatosliteral(TimeGet/Size) yrecreacionchecks
literales,31modelosfreshsobre6f45c00/2PTY10checks,87guardas. Q212titulo
inspectorcentrado y[■]arribaizquierda,4PTY28checkssobre0676a5a,dos
capturas802x477inspeccionadas. Q213SaveAsliteralnuevo sin falsoOverwrite,
3PTYsobre c87004f y87guardas,nativa1202x762inspeccionada. Las fuentes
sondistintas:noheredar31modelos alultimobin ni actualizaresasclaimsC29.

Q210 corrige M1: nombresPOSIXliteral* no eluden rechazoenlaces.
Atomic56/59antes59/59despues,4PTYsobrefuente6d686ed,binarioexacto;
no raceproof/Windows/cierreM1. M3se detienen variantes equivalentes:
Q205duplica timeout/Q207sin callback dejaappvisible; no GTadapter
ni cambio toolchain/politica autorizado, ambostogglespendientes.

Corte operativo C29/Q203 (1 noviembre, 10:10): candidato export7760ab2,
strippededbe6756 incluye selectorUTF8Q196 y fixturemixta. Ocho smokes y
dos modos37checks sobre binario exacto; tres modos30checks mas con
loader/libc/libm Debian12 (Q203), no VM/instalacion limpia. Q198/Q199
registran30modelos sobre sus fuentes, no herencia al candidato. Q200/Q201
acreditan generacion/compilacion/runtime mixto y accionesTabEnter; Q202
separa AltCconSETCANCELdefault (aborto) del launcher explicitoSetCancel(.F.).
No se modifica politica del generado. Q206: usuario pidio boton arriba izquierda10:16:27; implementado[x]
conclick/F4/JSONpreservado y regresiondrag,4PTY26checks sobre48de499.
Q209 cambiaxpor[■]usandomismoAPI/codigo deotrasventanas,4PTY26checks
sobred4489ed ydosactuales802x477inspeccionadas. Ultimas capturas C29 completas
inspeccionadas: comillasUTF8U y retorno al error fila2col9.


- **M4:** Q175 revisa alcanzar el borde y volver dentro del mismo gesto.
  Se conserva el punto de agarre: el panel permanece clampado hasta que
  ese punto vuelve al rango visible. No se confunde con el offset inicial
  incorrecto corregido en Q169. No se cambia a arrastre relativo ni se
  cambia la politica de controles sobredimensionados pendiente de decision.
- **M5, siguiente paso:** separar el smoke Linux aislado de una instalacion
  limpia en otro sistema. Q173 oculta checkout y compilador, pero usa las
  bibliotecas del mismo host. Windows nativo, instalador y licencias siguen
  pendientes. Q171 solo acredita dos rebuilds byte-identicos con el mismo
  host y toolchain. Q189 añade userspace Debian12 con librerias propias,
  pero sigue kernel/dispositivos del host y no es instalador ni VM.
  Q193 bloquea LICENSE.txt vacio o symlink y registra hash/tamano sin
  asignar licencia. El gate de avisos sigue abierto, no es clearance legal.
- **M6:** no repetir una matriz de horas por cada cambio documental.
  Q164 acredita 309 modos sobre su fuente, anterior al arreglo Q169. El
  registro contiene353variantes. Q243 ya reconcilia C30 sobre binario
  unico:352scripts originales +1navigation adaptadoEsc,352PTY+1guardafuente.
  No son353funciones ni353scriptsoriginalesPASS; no hereda Q164 ni cierraM6.
  Siguientes puertas: modelos de la fuente actual, revision visual y
  distribucion/licencias/Windows, sin repetir horas por cambio documental.
- **M2:** Q176-Q178 comprueban compilador ausente, restauracion sin reiniciar,
  exito sin output y error tras crearlo. Conservacion del binario anterior
  y ausencia de lanzamiento obsoleto. Q179 corrige el salto al primer error
  si status0 no produce output y existe binario antiguo. No resuelven
  Cancel ni bloqueo de UI. Q181 nombra el output conservado si falla
  la sustitucion del destino; prueba con directorio bloqueante real.
  Q183 lo comprueba con hbmk2 real y reintento exitoso sin reiniciar.
  Q184 hace accesible la salida larga de Start en el visor con scroll;
  las alertas cortas conservan su comportamiento. Q194 consolida20
  modos/267checks sobre fuente2bdecc7 y un solo binario, no cierra M2.
- **M2/M3:** Cancel sigue abierto sin helper C ni contrato rebajado a
  process-group. Exchange Screens y swap on Input siguen siendo stubs;
  el hook INKEYREAD probado no distingue espera y poll. Global/reinicio
  necesitan contrato y soporte VM, no toggles decorativos. Q199 caracteriza
  GLOBAL como no soportado en toolchain694428e1 (compilerE0030 y VM
  count0/listvacia), sin quitar el requisito ni cerrar M3.
  Q204 recupera argumentos del frameINKEY desde Harbour con sentinelVM;
  llamadasC__ACCEPT quedan unknown. Q205 prueba puenteGTNUL/visible y
  tecla real, pero timeout .05se duplica a121ms al devolver0alhook.
  No se integra asi ni se declaran toggles implementados.

| Evidencia | Alcance que si acredita | Lo que no acredita |
| --- | --- | --- |
| Q164 | 309/309 modos: 308 PTY y una guarda, 29 modelos, 66 guardas, 34 docs, fuente6ad102e | Arreglo Q169 posterior, candidato final o Windows |
| Q169/Q170 | Arreglo del origen de arrastre clampado; rutas horizontal y vertical, antes/despues y capturas | Todos los gestos o terminales; matriz global del nuevo binario |
| C27 | Export4f9c681, ocho smokes y cinco modos recientes/27checks del binario851540d5 | Release, licencias, instalacion limpia o herencia de309 |
| Q171 | Dos reconstrucciones independientes byte-identicas a C27, mismo host/toolchain | Reproducibilidad entre sistemas o compiladores |
| Q173 | Tres modos/30checks en raiz reducida sin checkout/compilador | Otra distribucion, instalador o maquina limpia |

Los hashes completos y los registros estan en los archivos de evidencia
citados en el seguimiento. No hay porcentaje global ni hito cerrado nuevo.

## Cola historica auditada

La tabla siguiente conserva la secuencia anterior. No es la cola de trabajo
actual; la prioridad vigente es la seccion de arriba.

| ID | Hallazgo / siguiente paso | Evidencia y salida |
| --- | --- | --- |
| Q131 | Explicitcontinuationbracketcontext/repaint. | Source9dcf9a3/before2PASS2FAIL/28PTY6modes26models203repaint57guardtests34docsPASS/nativeinspected;linux-editor-bracket-continuation.json.No generallexer/Windows/global. |
| C23 | TemporaryLinuxcandidatehastaQ130. | Exportcdc0de1/bin207a589e,8smokes10recent74checksPASSexactbinary,34docpreflight/nativenueva;linux-candidate-recent-c23.json.No release/Windows/licenses/fullmatrixinherit. |
| Q130 | M0 registerhelpbrowser/projectUImodels. | Source1258a6f/26models57guardtests34docsPASS;linux-help-project-extra-models-q130.json.GTSTDnotpixels/PTY/Windows/global. |
| Q129 | M0 registerexistingdebuglayout/tabwidthmodels. | Source54ed845/24models57guardtests34docsPASS;linux-debug-extra-models-q129.json.GTSTDnotpixels/PTY/Windows/global.Prior22modelsremainhistorical. |
| Q128 | M0 failclosedguardrunnernegativefixtures. | Sourcefd6d538/6suites57unittests34docsPASS;linux-tooling-guards-negative-q128.json.No productbinary/PTY/models/pixels/Windows/global. |
| Q127 | M0 sourcetrackedtoolingguardrunner. | Source6be9a2b/5suites51unittests34docsPASS;linux-tooling-guards-q127.json.No productfix/PTY/models/pixels/Windows/global. |
| Q126 | ?/??bracketliteralnotfalsecomment. | Sourced130b52/before2PASS2FAIL/34PTY6modes22models195repaint36inventory34docsPASS/nativeinspected;linux-editor-bracket-output.json.No runtime/generallexer/Windows/global. |
| Q125 | M5 builderstalecataloguebarrierexecuted. | Source073cd3e/2isolatedintegration5docguards36inventory34docsPASS;linux-candidate-document-preflight-integration.json.No realbinary/candidate/Windows/global. |
| Q124 | Literal.hhheaderlisted/openedexact. | Source3565f64/before1PASS2FAIL/15PTY5modes22models36inventory34docsPASS,nativeinspected;linux-project-hh-header.json.No compiler/bridge/Windows/global. |
| Q123 | M0 F1contexthelpdirect/File/Editrealroutes. | Sourceafb4576/39PTY2modes36inventory34docsPASS;linux-inventory-context-help-f1.json.No newproductfix/pixels/models/Windows/global. |
| Q122 | M0 Alt0WindowListexactdispatchlinked. | Source6976fd2/72PTY2modes35inventory34docsPASS;linux-inventory-windowlist-altzero.json.No productfix/pixels/models/Windows/global. |
| Q121 | MatrizLinuxregistradacompletahastaQ120. | 221/221=220PTY+1guardPASSsource8305ef0/bina5d54a69;22models34inventory5exportdoc5noticeguards34docsPASS;linux-full-matrix-q121.json.No newfix/pixels/candidate/Windows/licenses/hitos. |
| Q120 | M5 documentpreflightworkswithout.git. | Sourcedf5af1d/5guards+actualexport34docsPASS/stalemutationreject;linux-export-document-preflight.json.34inventory.No productbinary/newcandidate/release/Windows/global. |
| C22 | CandidatoLinux temporalhastaQ119. | Export4e15503/bin46292e4c,8smokes10recent64checksPASSexactbinary/nativenueva;linux-candidate-recent-c22.json.No release/licenses/Windows/install/fullmatrixinherit.C21historical. |
| Q119 | Regresiónconjuntaeditor/nav/inputconayudasincronizada. | Source1070624/109PTY20modos22models34inventory34docsPASS;linux-joint-editor-input-q119.json.Priorhelpdriftdisclosed.Nofullmatrix/newpixels/candidate/Windows/global. |
| Q118 | M0 AltF8/AltF7 exactdispatchlinked. | Sourcebe3610c/44PTY2modes34inventory34docsPASS;linux-inventory-alt-diagnostic-dispatch.json.No productfix/pixels/models/Windows/global. |
| Q117 | Codeblockbracketliteral preservesfollowingcode. | Sourcefbe33df/32PTY6modes22models191repaint33inventory34docsPASS;nativeinspected;linux-editor-bracket-codeblock.json.No runtimecodeblock/generallexer/Windows/global. |
| Q116 | Bracketliteraltrasoperadoreslógicosnoconfundecomentario. | Antes2PASS2FAIL7guards38PTY22models33inventory34docsPASSsource21036f1;nativeinspeccionado;linux-editor-bracket-logical.json. No runtime/type/generallexer/Windows. |
| Q115 | M0 CtrlF2SaveAllexactolink/conflictos/fallos. | 4modos40checks+2scenarios33inventory34docsPASSsource4eeb0cd;linux-inventory-saveall-ctrlf2.json. No productfix/pixels/models/global. |
| Q114 | M5 guardasfailclosedauditoravisos,gatepermaneceabierto. | Source0ad7d31/5guards32inventory34docsPASS;28fuentes14LICENSEreferenciasausentes14sinheaderdetectado;gate1expected;linux-distribution-notice-gate.json. No licenseclearance/release/Windows. |
| Q113 | Bracketliteraltras*/%^noconfundecomentarios. | Antes2PASS2FAIL;7guards38PTY22models32inventory34docsPASSsourceb756ad2;nativeinspeccionado;linux-editor-bracket-arithmetic.json. No runtime/type/generallexer/Windows. |
| Q112 | RegresióninputIDE/debugger trasGTkeymap. | 11modos163checks+2scenarios22models32inventory34docsPASSsourceec9d3a0;linux-input-joint-q112.json. No fullmatrix/newfix/pixels/candidate/Windows. |
| Q111 | PrevDoc conunbufferinertebytes/dirty/cursor+Undo. | 3modos21checks32inventory34docsPASSsource433c773;linux-prevdoc-single.json. No productfix/pixels/models/Windows/global. |
| Q110 | PrevDoc modo80x25xterm-256colorcon8checksíntegros. | 4modos23checks32inventory34docsPASSsource0b2e615;linux-prevdoc-compact-256.json. No productfix/pixels/modelrerun/allterminals/Windows. |
| Q109 | xtermCtrlShiftF6 no insertasecuencia;PrevDocfunciona. | Antes2PASS7FAIL;localHarbourkeymap/sourcec1bba4f52PTY32inventory34docsPASS/nativeinspeccionado;linux-prevdoc-shortcut.json. No otherterminals/Windows/modelrerun/global. |
| Q108 | M0 conserva condiciónmultilíneaCtrlF6vinculada. | source63a5f55multidoc37checks31inventory34docsPASS;linux-inventory-multiline-dispatch.json. No CtrlShiftF6/productfix/pixels/global. |
| Q107 | Navegación conserva contextoindex/intro entrecomentariomultilínea. | Antes2PASS1FAIL;3modelguards15PTY22models30inventory34docsPASSsource4775e6b;native2of2Target8exact;linux-navigation-multiline-gap.json. No preprocesadorgeneral/Windows. |
| Q106 | M0 F5Find real éxito/Cancel/missing vinculado. | Source3ac5026/3modos21checks30inventory34docsPASS;linux-inventory-find-f5.json. No productfix/pixels/modelrerun/global. |
| Q105 | TAB antesbracketliteral no contamina estado posterior. | Antes3PASS1FAIL;5newguards35PTY22models29inventory34docsPASSsource4610113;nativeinspeccionado;linux-editor-bracket-tabs.json. C21/Q104predatesfix. |
| C21 | CandidatoLinux temporal incluyeQ100/Q101/Q102. | Exportdf2e7a5 binary6d116c74,8smoke11modos57checksPASSexactbinary/nativainspeccionada;linux-candidate-comparisons-c21.json. No release/Windows/licenses/install/fullmatrixinherit. |
| Q104 | Matriz Linux registrada completa hastaQ103. | 212/212distinct=211PTY+guardPASSsourcea0b7b82binary1bf96b2e;22models29inventory34docs;linux-full-matrix-q104.json. No newfix/pixels/candidate/Windows/licensing/Cancel/hitos. Q87historicalseparate. |
| Q103 | Regresión conjunta editor/navegación/proyecto hastaQ102. | Fuente7647451 binarybbfc505b20modos85checks22models29inventory34docsPASS;linux-joint-editor-project-q103.json. No full212/newfix/pixels/candidate. |
| Q102 | M0 inventaría IF/ELSEIF ademásCASE;F2/F3 vinculados. | 2newguards29inventory34docsPASS/2PTYsuitesFindRepeat7checks+Backupscenario fuente26f69d3;linux-inventory-if-dispatch.json. No productfix/pixels/modelrerun/global. |
| Q101 | Comparaciones bracketliteral no abren bloque falso. | Compiler-valid9operators;antes2PASS2FAIL;12guardas36PTY22models27inventory34docsPASS sourcea1d0892;nativeinspeccionado;linux-editor-bracket-comparisons.json. No lexercompleto/Windows. |
| Q100 | Bracketliteral tras minus no abre bloque falso. | Compiler-validantes2PASS2FAIL;5guardas/24PTY22models27inventory34docsPASS source3564515;nativeinspeccionado;linux-editor-bracket-minus.json. No lexercompleto/Windows. |
| C20 | CandidatoLinux temporal incluyeQ91-Q99. | Export6da0304 binary5a4f86e8,8smoke+9modos41checksPASSexactbinary;nativeQ99inspeccionado;linux-candidate-bracket-context-c20.json. No release/Windows/licencias/install/globalmatrix. |
| Q99 | Contexto bracket conserva intro cruzando comentario multilinea. | Antes2PASS2FAIL;cachelazyestado+pintado/6guardas/20PTY22models27inventory34docsPASS source240471f;nativeinspeccionado;linux-editor-bracket-multiline.json. No lexercompleto/Windows. |
| Q98 | Evitar rescansprefijo innecesarios bracket. | Antes3pasadas600strings4229bytes921msestehost;despues0/1/3msvs28/231/921ms100/300/600strings;2longlineguardas+21PTY22models27inventory34docsPASS source6acb198;linux-editor-bracket-gap-performance.json. No C/generalperf/global. |
| Q97 | Comentario completo conserva contexto bracketliteral. | Fixturecompiladaantes2PASS2FAIL;5repaintguardas/21PTY22models27inventory34docsPASS sourcea4ad3a1;nativecommentmagenta/literalyellow/cyaninspeccionado;linux-editor-bracket-gap.json. No lexercompleto/Windows. |
| Q96 | M0 enlaza Ctrl+G/extendedDelete a dispatch exacto. | Guardafuente/contexto/condicion+48PTY27inventory34docsPASS fuente63a03f1;linux-inventory-ctrlg-delete.json. No nuevoproducto/pixels/global. |
| Q95 | Regresion conjunta editor/nav/proyecto trasQ91-Q94. | Fuente26698af binary578a6fa3,15modos63checksPTY+22models26inventory34docsPASS,mismoidentity/sinretries;linux-joint-editor-project-q95.json. No newfix/pixels/candidato/matrizglobal. |
| Q94 | Bracketstrings tras +/== no contaminan bloque/pintado. | Fixturecompiladaantes2PASS2FAIL;4repaintguardas/17PTY22models26inventory34docsPASS source0dbf0cc;nativeamarillo/cyaninspeccionado;linux-editor-bracket-operator.json. No lexercompleto/Windows. |
| Q93 | Sources incluye header.hpp literal. | ProyectoC/hppcompiladoantes1PASS2FAIL;3modelguards/12PTY22models26inventory34docsPASS sourceb45b674;nativeSources/Enterinspeccionados;linux-project-hpp-header.json. No puenteC++/compiladornuevo/Windows. |
| Q92 | Bracketstrings en arrayliteral/coma no abren bloque falso. | Fixturecompiladaantes2PASS2FAIL;4repaintguardas/16PTY22models26inventory34docsPASS fuente0ff5902;nativeambascadenasamarillas/posteriorescyaninspeccionado;linux-editor-bracket-list.json. No lexercompleto/Windows. |
| Q91 | Bracketliteral tras ( no contamina pintado/estado. | Fixturecompiler-valid return([/*literal]);antes2PASS2FAIL;4repaintguardas/17PTY22models26inventory34docsPASS fuente49aa4a5;nativeamarillo/cyaninspeccionado;linux-editor-paren-bracket.json. No lexercompleto/Windows. |
| C19 | CandidatoLinux temporal incluye Q86/Q88/Q89. | Export6a2f06d binaryab4ac913,8smoke+6modosrecientesPASSmismaidentidad;nativeINITEXIT/saltoexactinspeccionado;linux-candidate-lifecycle-comments.json. No release/Windows/licencias/instalacion/globalmatrix. |
| Q90 | M0 vincula Designer y Watchpoint a pruebas reales de menu. | Dosguardas alcanceacotadoListbox/scalarwatch;32PTY26inventory34docsPASS fuenteff81639;linux-inventory-designer-watch.json. No nuevoproducto/pixels/global. |
| Q89 | INIT/EXIT conservan tipo en GoToFunction. | Fixturecompiladaantes2PASS1FAIL;5guardas+41PTY22models24inventory34docsPASS fuente43b6f33;native3/3tiposdistintos/saltoCleanup5exact;primerbaselineinterrumpidoexterno/repetidoPASS;linux-navigation-init-exit.json. No runtime/modificacionciclo/parsergeneral/Windows. |
| Q88 | NOTE linecomment no abre bloque falso. | Fixturecompiladaantes1PASS2FAILnavegacion;scanner/pintadoestado,4lexical5repaintguardas;18PTY22models24inventory34docsPASS sourcea0d088e. NativeNOTE magenta/Target4Xexact/fullborders;linux-editor-note-comment.json. No parserstatementsep/Windows/global. |
| Q87 | Matriz Linux registrada completa tras aliasesnavegacion. | 201/201(200PTY+guard)PASS fuente84e58b3/binario2bdfbe63,22modelos24inventario34docs,sinfallos/reintentos. linux-full-matrix-q87.json. No nuevofix/visual/candidato/Windows/hitos. |
| Q86 | GoToFunction incluye DESTRUCTOR CLASS explicito. | Fixturecompiladaantes1PASS2FAIL,4guardasmiembro/binding/continuacion;linux-navigation-destructor.json. No macrosgenerales/Windows/global. |
| C18 | Candidato Linux temporal actualizado hastaQ85. | Export813d95d,8smoke+10modosnavegacion34checks binarioexacto0d9a1505,visualASSIGNinspeccionado;linux-candidate-navigation-aliases.json. No release/licencias/Windows/instalacion/globalmatrix. |
| Q85 | M0 vincula F5LivePRG fuera delmenu. | Contratosdispatchancladosafuente/contexto/condicion,5guardasfailclosed24inventario;linux-inventory-f5-route.json. No producto/candidato/global. |
| Q84 | GoToFunction cualifica PROCEDURE nombre CLASS cls como metodo. | Fixturecompiladaantes1PASS2FAIL;4guardas ordinaria/comentario/continuacion;linux-navigation-procedure-class.json. No macrosgenerales/Windows/global. |
| Q83 | GoToFunction incluye ACCESS/ASSIGN CLASS explicitos. | Fixturecompiladaantes1PASS2FAIL;metodosDemo:Value/Demo:_Value,5guardas;linux-navigation-access-assign.json. ExtensionASSIGNjumpindependiente3checks,linux-navigation-assign-jump.json,sinnewfix. No inferenciamiembros/macrosgenerales/Windows/global. |
| Q82 | GoToFunction reconoce CREATE CLASS dehbclass.ch. | Fixturecompiladaantes1PASS2FAIL,aliasacotadoycontinuacion,4guardas; linux-navigation-create-class.json. No macrosgenerales/Windows/global. |
| Q81 | GoToFunction incluye declaraciones partidas con ;. | Fixture hbmk2valida, antes1PASS2FAIL; joinacotado conserva primera linea,5guardas nuevas. Evidencia linux-navigation-declaration-continuation.json. ExtensioncompactaFUNCTION;compiladavalida,antes1PASS2FAIL;3guardasymodoPTY,linux-navigation-declaration-compact.json. ExtensionSTAT;compiladavalida,antes2PASS1FAILsalto;5guardas,linux-navigation-declaration-static.json. No preprocesadorgeneral/candidatoC17actualizado/matrizglobal. |
| C17 | Candidato Linux temporal actualizado hastaQ80. | Export990b8ad,8smoke+12modosrecientes sobrebinarioexacto39c990e1,visualQ80nativoinspeccionado. Evidencia linux-candidate-recent-navigation.json; no release/licencias/Windows/instalacion/matrizglobal. |
| Q80 | GoToFunction conserva contexto de indice tras comentario terminado. | Fixture compilada, antes2PASS1FAIL;5guardas nuevas para nombre/doblecomentario/retorno/string yRETURNliteral. Evidencia linux-navigation-array-gap-comment.json; no lexercompleto/matrizglobal. |
| Q79 | M0 vincula pruebas recientes a acciones deproyecto/navegacion. | BOM/EOF/aliasesC++ yQ78encontratosOpen/Sources/GoToFunction;2guardasinventario19total. Evidencia linux-inventory-project-navigation.json. No producto/visual/matrizglobalnueva. |
| Q78 | ] dentro de comentario real de indice array filtraba funcion falsa. | Fixturecompilado antes2PASS1FAIL; distincion acotada nombre/valor antes[ y RETURNliteral. Evidencia linux-navigation-array-bracket-comment.json. No lexercompleto/Windows. |
| Q77 | Matriz Linux actual completa sobre fuente congelada531a6f1. | 191/191entradas(190PTY+guard)PASSmismo6c039e03;22modelos17inventory34docs. Primerloteexterno120sinterrumpido,DuplicateSelectionrepetidaPASS. Evidencia linux-full-matrix-q77.json. No nuevofix/candidato/Windows/visual/hitos. |
| Q76 | Sources omitía .cc existente compilado porhbmk2. | Antes1PASS2FAIL. Inventariar aliases C++ .cc/.cxx/.cx como fuente literal, sin cambiarPRG/HBP. Evidencia linux-project-cxx-source.json. No puenteC++/compiler modes/Windows. |
| Q75 | Caption duplicado resaltaba primerhijo envezdelsegundo. | Antes4PASS1FAIL. Mapa lineas declaracion porindice generado, PRG/JSONintactos. Guardas duplicadosSAY/GETcompartido/omitidos. Evidencia linux-designer-duplicate-anchor.json. No todosmodos/Windows. |
| Q74 | F5 perdia highlight GET renombrado por nombre reservado. | Antes4PASS1FAIL; generador devuelve mapa real de bindings para ancla, sin mutar modelo/JSON. Guardas reservado/conflicto tipos. Evidencia linux-designer-binding-anchor.json. No todosbindings/duplicados/Windows. |
| Q73 | Caption decontrol igual al tituloresaltaba constructor enF5. | Antes4PASS1FAIL. Excluir HBWindow():Dialog en lookupcaption dehijo; guardasSAY/boton. Evidencia linux-designer-dialog-caption-anchor.json. No duplicadosentrecontroles/bindings/Windows. |
| Q72 | ENDDUMP con comentario ocultaba funciones Harbour posteriores. | Fixture compilado real, antes1PASS2FAIL. Matcher raw con limites de token y comentarios/separador, sin estado C filtrado. Evidencia linux-navigation-enddump-comment.json. No preprocesador completo/Windows. |
| Q71 | DOS EOF final ocultaba ultima fuente HBP. | hbmk2 real compila, antes1PASS2FAIL. Quitar un EOF final solo de copia parseo, original/EOF interno intactos. Evidencia linux-project-eof.json. No encoding general/Windows. |
| Q70 | BOMUTF8 deHBP formaba parte del primerfilename. | hbmk2realcompila,IDEantes1PASS2FAIL. QuitarBOMsólodecopiaparseo,cOriginalintacto. Evidencia linux-project-bom.json. NoUnicodegeneral/UTF16/Windows. |
| Q69 | LivePRG no anclaba botón con accelerator en captiongenerado. | Antes4PASS1FAIL F5; aplicaDsnAccelCaptionantesDsnQuote. Evidencia linux-designer-button-anchor.json, sin captionsduplicadosambiguos/Windows. |
| Q68 | LivePRG perdía highlight deSAY con caption entrecomillado. | Antes4PASS1FAIL F5; lookupusa mismoserieDsnQuote. Evidencia linux-designer-quote-anchor.json. No duplicadosambiguos/todosbindings/Windows. |
| Q67 | CandidatoLinux16 incluyeQ62/Q63/Q64/Q66. | Export3109a9a stripped773983e1;8smokes+MixedQuote14/Pragma3/Backtick4/Color6PASSmismobinario,2pasossinreintentos. linux-candidate-designer-quotes.json. TemporalNOrelease/Windows/global/licencias/instalador/nuevospixels. |
| Q66 | GenerarPRG cambiaba comillasdobles de captions por apóstrofos. | Antes11PASS3FAIL con F9/compilar/runtime; hb_StrToExp preservaliteral. Evidencia linux-designer-quote-runtime.json, sin todoscontroles/Unicode/Windows. |
| Q64 | GCC con colorANSI no aparecía enMessages. | GCCrealcoloralways antes2PASS4FAIL; normalizaciónacotadaCSI m/K sóloparseo,rawintacto. Aceptación linux-gcc-colored-diagnostics.json; no flagsHBP/visorOutput/ANSIgeneral/Windows. |
| Q63 | Literal con apertura backtick y cierre apóstrofo contaminaba comentarios. | FixtureHarbourválido, antes2PASS2FAIL. Pintado/scanner/navegación reconocen pareja; aceptación linux-editor-backtick-literal.json. No lexercompleto/Windows. |
| Q62 | Texto#pragma begindump en#define ocultaba funciones reales. | Fixturecompilado, antes1PASS2FAIL. Matchdirectivaexacta,no substring. Aceptación/evidenciaseparada linux-navigation-pragma-macro.json; no preprocesadorcompleto/Windows. |
| Q61 | CandidatoLinux15 incluyeQ59/Q60. | Exportf440946 stripped80eca2c5;8smokes+Bracket4/BracketVariants7/NavArray3/EscapeVariants7/Caret6PASSmismobinario,2pasossinreintentos. linux-candidate-bracket-navigation.json. TemporalNOrelease/Windows/global/licencias/instalador/nuevospixels. |
| Q60 | Go to Function mostraba función falsa dentro de comentario multilinea en índice array. | FixtureHarbourcompilado, antes2PASS1FAIL/local3PASS. Se conserva estado/* al no existir cierre]enlínea. Clean33f5009Array3/Literal3/Typed3/BracketVariants7PASSmismobinario+22modelos16lexical118repaint;34docsPASStrasregenerarcatálogoobsoletoinicial. Nativepicker2/2Targetline7inspeccionados/F2exacto. linux-navigation-array-comment.json. Runner177=176PTY+guard. No lexercompleto/Windows. |
| Q59 | Literal entre corchetes tras := contaminaba comentario de líneas posteriores. | 65e9324 reconoce contextoacotado:=[] sin enmascarar índicesarray. Antes2PASS2FAIL; cleanBracket4/Variants7/Adjacent6 mismo binario+22modelos118repaintPASS. Nativebracketliteral/arrayindex/returninspeccionados,F2exacto. docs/evidence/linux-editor-bracket-assignment.json. Runner175=174PTY+guard al corte; extensión1480594Variants7/Bracket4/EscapeVariants7/Caret6PASSmismobinario sin nuevofix/model/pixels, linux-editor-bracket-variants.json. Runneractual176=175PTY+guard. No todoscontextosbracket/Windows. |
| Q58 | Columna GCC visual/tab no equivale a carácter. | adeb10f resuelve caso acotado sólo con fuenteASCII exacta, rendering y caret único; anchos1..32 coincidentes deben dar mismo carácter. CleanCaret6/Colon6/Message9 mismo binario+22modelos115repaintPASS,10asercionesmodelo de mapping/fallback. NativeTABsalto2:9 inspeccionado. docs/evidence/linux-gcc-caret-column.json. Sin evidencia/ambiguo/noASCII conserva número, por lo que gapgeneral permanece; no flagsHBP/Windows/global. Runner169=168PTY+guard al corte; extensión16c698d5modosGCCreales(default/byte/tab4/tab16/absent)6cadamodoPASSmismobinario, ausentefallback16noaciertosemántico. linux-gcc-column-variants.json. Runneractual174=173modosPTY+guard. Perf2687627cleanCaret6/Colon6/Message9+22modelosPASS; fuente20MiB/sincaretx30 79=>0ms ylínea30k155=>4ms sóloestehost; linux-gcc-caret-performance.json. |
| Q57 | Comilla escapada en e-string abría comentario falso en pintado. | 5f18c39 scanner/painter respetan E/e y backslash; fixturecompiladoválido. Antes2PASS2FAIL; cleanEscape4/Adjacent6/LineComments6 mismo binario+22modelos115repaintPASS. Nativecadena/returncyaninspeccionados yF2exacto. docs/evidence/linux-editor-escape-literal.json. Runner168=167PTY+guard en corteQ57; extensiónc867554Variants7/Escape4/Adjacent6/Caret6PASSmismobinario sin nuevofix/modelrun/pixels; linux-editor-escape-variants.json. Runneractual170=169PTY+guard. No bracketliteral/lexercompleto/Windows. |
| Q56 | Pintado absorbía delimitadores de comentario adyacentes a palabra/operador. | 3fb6f1f para token antes de &&,/*,// y deja consumir comentario al tokenizer. Antes3PASS2FAIL; cleanAdjacent6/LineComments6/MessageSelection9 mismo binario+22modelos112repaintPASS. Nativecomentariosmagenta y código posterior*/inspeccionados, F2exacto. docs/evidence/linux-editor-adjacent-comments.json. Runner167=166PTY+guard, no lexercompleto/Windows. |
| Q55 | Message/Project jump reusaba buffer con marca antigua, typing borraba bloque. | fb2feea limpia marca tras abrir con éxito en JumpMessage/ProjectDesktop. Antes5PASS1FAIL; cleanMessageSelection9/NavSelection7/Colon6 mismo binario+22modelos112repaintPASS. NativeXunknown_name/Undo inspeccionados, disco exacto. docs/evidence/linux-message-selection.json. Runner166=165PTY+guard, no global/Windows. |
| Q54 | Go to Function/Goto Line dejaban rango marcado viejo y typing borraba bloque inesperado. | 4eaafa3 limpia selección sólo al confirmar salto, Cancel conserva rango. Cleand417e7f NavSelection7/Literal3/Typed3/Find7 mismo binario+22modelosPASS; nativeTargetX/Undo inspeccionados. docs/evidence/linux-navigation-selection.json conserva primerfalloCancel deharness. Runner165=164PTY+guard, no global/Windows. |
| Q53 | DiagnósticoGCC tomaba componente numérico de ruta como línea. | 5fc4ddb exige severidad después de localización y usa prefijo para level. Antes3PASS3FAIL, cleanColon6/Output2/LineComments6/Messages18 mismo binario+22modelosPASS. Nativeerrorbad.c:2/rutaexacta/jump2:9 inspeccionados. docs/evidence/linux-project-colon-diagnostic.json. Wrappergccreal, no aceptaciónhbmk2colonpath/Windows/encodinggeneral. Runner164=163PTY+guard. |
| Q52 | Comentarios &&/asterisco contaminaban color de líneas posteriores con /* literal. | dd94e1d scanner y pintado respetan comentarios de línea Harbour. Antes3PASS3FAIL, cleanLineComments6/Literal3/Typed3/Find7 mismo binario+22modelos112repaintPASS. Native120x40 comentarios magenta y return cyan inspeccionados, F2 bytes exactos. docs/evidence/linux-editor-line-comments.json. Runner163=162PTY+guard; no lexercompleto/viewporthorizontal/Windows. |
| Q51 | Picker mostraba tipos como nombres de métodos y CLASS VAR como clase. | 87f7a90 acepta nombre tras METHOD FUNCTION/PROCEDURE y excluye alias CLASS VAR/METHOD. Fixture hbclass.ch compilado; cleanTyped3/Literal3/Find7/Navigation35 mismo binario y22modelos15lexicalPASS. Capturas picker4/4 y saltoNewlínea9 inspeccionadas. docs/evidence/linux-navigation-typed-methods.json. No macrosarbitrarias/contextoimplícito/Windows. Runner162=161PTY+guard. |
| Q50 | Go to Function ocultaba declaraciones tras marcadores de comentario literales. | e870acd/18cd290 distingue literales y comentarios y aísla el estado del bloque C dump. CleanNavLiteral3/Find7/Repeat7/Navigation35 mismo4ec0ef2b,22modelosPASS con12léxicos; nativepicker2/2 y saltoTargetlínea4 inspeccionados. docs/evidence/linux-navigation-lexical.json. Runner161=160PTY+guard. No gramática completa/Windows/cierre global. |
| Q49 | Find exitoso conservaba rango antiguo, escritura borraba texto no esperado. | 040e2ea limpia selección sólo si encuentra match, forward/wrap; Cancel/missing conservan rango. CleanFind7/NoChange9/Changed5/Virtual6mismo5e401ae6+21modelosPASS. NativealXpha/Undoalpha inspeccionados. Runner159=158PTY+guard. docs/evidence/linux-find-selection.json. No búsqueda limitada a rango/Windows/global. Extensióncleane2482e6Repeat7/Find7/NoChange9mismo1696d442PASSsinreintentos; docs/evidence/linux-find-repeat-selection.json. Runner160=159PTY+guard en ese corte, no nuevofix. |
| Q48 | Cut de rango enteramente virtual provocaba dirty falso. | d9c148b SelDelete compara línea empaquetada antes de marcar dirty; eliminación real/multilínea conserva cambio. CleanVirtualSelection6/VirtualBS5/Cut7/Destructive19mismoae53bc5f+21modelosPASS. Nativecol9/Close sinprompt inspeccionados. Runner158=157PTY+guard. docs/evidence/linux-virtual-selection.json. No política clipboardvacío/Windows. |
| Q47 | Retroceso en columna virtual ensuciaba sin cambio. | 56e76ad marca dirty sólo si posición de borrado existe; conserva desplazamiento y borrado real. CleanVirtual5/EOF6/Tab7/Identity5mismo98a4ede3+21modelosPASS. Nativecol10/Close sinprompt inspeccionados. Runner157=156PTY+guard; Candidate10anteriorQ47. docs/evidence/linux-virtual-backspace.json. No política globalvirtualspace/Windows. |
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

### Candidate10 - editor Q44-Q46 incluido

Export3ac96d2 stripped8e63f56f pasa8smokes y Tab7/Identity5/Destructive19/
Selection7/Cut7 mismo binario inalterado, dos pasos sinreintentos. Ledger
linux-candidate-selection.json. PredateNEXUSdemo, no release/instalador/
licencia/Windows/matriz155completa ni nueva prueba de determinismo.
NEXUS es demo adicional solicitada31Oct11:15 y entregada11:22, no cierreM1-M6.
Fuente/instrucciones demos/nexus.prg y demos/NEXUS.md; evidencianativa
 docs/evidence/nexus-demo/. Botonesverdes/sombra sincorchetes, datosficticios.

### Candidate11 - Q47-Q49 incluido

Exporte4130d5 stripped9936b5ee pasa8smokes+Virtual6/VirtualBS5/Find7/Repeat7/
Tab7 mismo binario inalterado, dos pasos sinreintentos. Ledger
linux-candidate-find-virtual.json. Incluye fuenteNEXUS pero no ejecución
NEXUSenestecandidato. No release/licencia/instalador/Windows/matriz159global/
nuevascapturas/determinismo. Último cambiofuncional040e2eaQ49 sin cambios.

### Candidate12 - navegación Q50/Q51 incluida

Exportedc5f65 strippeda473bf4b pasa8smokes estándar+Typed3/Literal3/Navigation35
mismo binario inalterado, dos pasos sin reintentos ni interrupciones. Ledger
linux-candidate-navigation.json. No nuevofix/release/licencia/instalador/
Windows/matriz161global/nuevascapturas/determinismo/NEXUSejecutado.

### Conjunta focal Q50-Q54

Clean2b5ad8b: nueve suites distintas de navegación/proyecto/pintado/Find,
mismo f8988087, dos pasos sin reintentos ni interrupciones;22modelos
112repaint/15inventory/34docs PASS. Ledger linux-navigation-project-joint.json.
No nueva corrección/matriz164PTY/global/Windows/nuevos píxeles/cierre de hito.

### Candidate13 - Q52-Q55 incluidos

Export041df6d stripped582e15f2 pasa8smokes estándar+MessageSelection9/
NavSelection7/Colon6/LineComments6, mismo binario inalterado, dos pasos
sin reintentos ni interrupciones. Ledger linux-candidate-current-navigation.json.
No nuevofix/matriz165PTY/Windows/release/licencias/instalador/nuevos píxeles/
determinismo/NEXUSejecutado.

### Conjunta focal actual Q56-Q58 y guardas navegación/proyecto

Cleand2e74bc:11suites distintas de pintado/caret/diagnósticos/navegación/Find,
mismo binario, dos lotes PTY acotados y22modelos115repaint PASS;15inventory34docs.
Ledger linux-paint-project-joint.json. Sin reintentos/interrupciones ni nueva
corrección/captura/matriz168PTY/Windows/cierre de hito.

### Candidate14 - Q56-Q58 incluidos

Exportb1e49e8 stripped371f2170 pasa8smokes estándar+Escape4/Adjacent6/
Caret6/MessageSelection9 mismo binario, dos pasos sin reintentos/interrupciones.
Ledger linux-candidate-paint-caret.json. No nuevofix/matriz168PTY/Windows/
release/licencia/instalador/nuevos píxeles/determinismo/NEXUSejecutado.
Q58 conserva sus límites de evidenciaASCII/caret no universal.

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

### Q117 - codeblock bracket literal context

Expression-start pipe now preserves bracket strings for empty/argument blocks
and comment gaps. 32 Linux PTY checks in six modes, 22 models and native120x40
inspected; evidence linux-editor-bracket-codeblock.json. Bounded lexical fix,
not full lexer/runtime/Windows/global milestone acceptance.


### Seguimiento Q132 (1 noviembre 2026)

Corregido repaint de continuacion al quitar/reponer ;: invalidacion previa
en Backspace y contexto lexical comparado exacto. Seis modos PTY, 37 checks,
26 modelos, 206 controles repaint y 57 guardas PASS sobre fuente `46aeb904`.
Evidencia en `docs/evidence/linux-editor-continuation-edit-q132.json`;
no hereda matriz Q121 ni cierra hitos abiertos.


### Seguimiento Q133 (1 noviembre 2026)

Delete y seleccion de ; invalidan contexto antes del repaint; ambos fallos
reproducidos antes y corregidos. Seis modos PTY/50 checks, 26 modelos,
210 controles repaint y 57 guardas PASS en fuente `c4dfe153`. Evidencia
`docs/evidence/linux-editor-continuation-delete-q133.json`. Matriz completa
y hitos pendientes conservan sus limites.


### Seguimiento Q134 (1 noviembre 2026)

Cobertura nueva sin arreglo de producto: Enter/joins de continuacion,
Undo/Redo/F2 en cuatro modos PTY, 48 checks y 57 guardas PASS. Expectativa
inicial corregida tras contraste con Harbour; la linea vacia termina
continuacion. Evidencia `docs/evidence/linux-editor-continuation-joins-q134.json`.
No nueva matriz global ni cierre de hitos.


### Seguimiento Q136 (1 noviembre 2026)

Matriz Linux registrada nueva 228/228 (227PTY+1guarda) PASS sobre134fd459,
binario62e7b63e;26modelos57guardas34docs PASS. Q135162/228 queda solo
historico reportado tras reset, no heredado. Q136 incluye una interrupcion
externa de navigation y repeticion explicita PASS, documentadas. Evidencia
`docs/evidence/linux-full-matrix-q136.json`. No equivale a100%ni cierre
de Windows/licencias/instalacion/hitos.


### Seguimiento C24 (1 noviembre 2026)

Candidato exportado3d109f8/binarioa05367ba:8smokes+5modosrecientes60checks
PASS,34docpreflight,ldd y visual nativa exactbinary. Evidencia
`docs/evidence/linux-candidate-c24.json`. No release/licencias/Windows/
instalacion ni herencia de matrizQ136.


### Seguimiento Q137 (1 noviembre 2026)

Probe INKEYREAD cinco checks PASS y baseline27modelos/57guardas PASS.
El hook actual no distingue poll de espera (cero argumentos en ambos);
Swap on Input y Exchange Screens siguen abiertos sin degradar contrato.
Evidencia `docs/evidence/linux-debug-input-hook-q137.json`; no arreglo
ni cierre M3/global, continúan áreas independientes.


### Seguimiento Q138 (1 noviembre 2026)

Modelo InspEdit13pares texto no-evento/79checks PASS;baseline28modelos/
57guardas PASS. Sin arreglo producto ni visual/PTY/Windows ni cierreM4.
Evidencia `docs/evidence/linux-designer-inline-fields-q138.json`.


### Seguimiento Q139 (1 noviembre 2026)

Seis pares texto inline en tres modos PTY/30checks y57guardas PASS,
visualAction/F10 inspeccionada. Evidencia
`docs/evidence/linux-designer-inline-text-q139.json`; no arreglo ni
aceptacion todoscampos/handlerexecution/Windows/cierreM4.


### Seguimiento Q140 (1 noviembre 2026)

13pares texto no-evento en7tipos:7modosPTY66checks57guardasPASS. Sin
arreglo ni cierreM4; capturaItems tiene recorte horizontal y celda
cursorgris anotados, no aceptacion pixelglobal. Evidencia
`docs/evidence/linux-designer-inline-text-q140.json`.


### Seguimiento Q141 (1 noviembre 2026)

20pares evento inline en6modosPTY92checks57guardasPASS. Edicion y
persistencia, no ejecucion de handlers ni cierreM4. Celda gris Q140
pendiente de causa; no se considera arreglada. Evidencia
`docs/evidence/linux-designer-inline-events-q141.json`.


### Seguimiento Q142 (1 noviembre 2026)

Ajustes numericos/Style en7modosPTY77checks57guardasPASS,rafagaUndo/Redo
y persistencia exactas. Sin decision oversized ni nueva UI/arreglo/
cierreM4. Evidencia `docs/evidence/linux-designer-inline-numeric-q142.json`.


### Seguimiento Q143 (1 noviembre 2026)

DialogoName/Caption/Width/Height:2modosPTY30checks57guardasPASS con
regresionButton,visualcaption inspeccionada. Evidencia
`docs/evidence/linux-designer-dialog-inline-q143.json`;sin arreglo ni
aceptacioncolores/oversized/Windows/cierreM4.


### Seguimiento Q144 (1 noviembre 2026)

Back/Text/Focus con pickerreal:2modosPTY33checks57guardasPASS,
visualPicker/resultadoN/G inspeccionada. Sin arreglo/runtime/Windows/
cierreM4. Evidencia `docs/evidence/linux-designer-dialog-colors-q144.json`.

### Seguimiento Q145 (1 noviembre 2026)

Inventario de inspector por par control/campo: 60 pares fuente (53+7 dialogo),
con contratos focales Q139-Q144, no aceptacion global. Guardas negativas de
identidad/tipo/clave/control/prueba impiden vincular silenciosamente otra ruta.
Sin ejecucion de handlers, nueva aceptacion PTY/visual o cierreM4.


### Seguimiento Q146 (1 noviembre 2026)

Matriz focal actual de inspector:22/22modos268checksPTY63guardasPASS
en fuente b820b25, sin reintentos.60pares con rutas focales, no porcentaje
ni aceptacion completa. Sin nuevos pixeles/modelos/handlers/Windows ni
cierreM4; evidencia `docs/evidence/linux-inspector-matrix-q146.json`.


### Seguimiento Q147 (1 noviembre 2026)

Corregida restauracion al deseleccionar Combo: restos de inspector
10->7campos y tirador resize. Modelo oldFAIL/newPASS,29modelos,3PTY32checks,
63guardas34docsPASS. Native antes/despues completos40x120 inspeccionados.
CeldaQ140 identificada como tirador, residual al deseleccionar antes del
arreglo; no cursor ni arreglo de tirador seleccionado previsto.
Evidencia `docs/evidence/linux-designer-inspector-repaint-q147.json`.
Sin aceptacion de todosgestos/geometrias/Windows ni cierreM4.


### Seguimiento Q148 (1 noviembre 2026)

Button Action/Focus editados inline,F10,F9,compilacion y runtime
Enter/Space:12checks,regresiones en evidencia Q148. No todos handlers
ni aceleradores/Windows/cierreM4;sin arreglo de producto ni nuevos pixels.


### Seguimiento Q149 (1 noviembre 2026)

Combo/List STATE editado inline,F10,F9,compilacion y runtime valor2/3
con handler ejecutado:3PTY26checks63guardas34docsPASS incl.Buttonregresion.
Evidencia `docs/evidence/linux-designer-inline-state-runtime-q149.json`.
Sin otros handlers/tipos/Windows/cierreM4 ni nuevos pixeles/modelos.


### Seguimiento Q150 (1 noviembre 2026)

Handlers inline al runtime en seis tipos existentes:GET/Radio VALID,
Checkbox/Combo/List STATE,ButtonAction/Focus.6PTY47checks63guardas34docs
PASS. Sin todos pares evento/tipo,WHEN/otros handlers, nuevos pixeles,
Windows/global/cierreM4. Evidencia
`docs/evidence/linux-designer-inline-events-runtime-q150.json`.


### Seguimiento Q151 (1 noviembre 2026)

20pares evento/tipo inspector editadosinline,F10,F9,compilacion y
runtimeconmarcadores.T.:6PTY51checks63guardas34docsPASS. Solo ejecucion
focal.T.,no vetos.F./orden/cuentas/parametros/excepciones/nuevos pixels/
Windows/global/cierreM4. Evidencia
`docs/evidence/linux-designer-inline-all-events-runtime-q151.json`.


### Seguimiento Q152 (1 noviembre 2026)

VALIDinline.F. bloqueaTab a sentinel y.T. siguiente permite entrada
enGET/Radio/Checkbox/List/Combo:5PTY50checks63guardas34docsPASS.
Sin Buttonveto/WHENfalse/todasteclas/pixeles/Windows/cierreM4.
Evidencia `docs/evidence/linux-designer-inline-valid-veto-runtime-q152.json`.


### Seguimiento Q153 (1 noviembre 2026)

WHEN.F. editadoinline omite seis tipos existentes;sentinelrecibe
escritura+Tabcommit,bindingrechazadoigual,FOCUSGUIausente.6PTY47checks
63guardas34docsPASS.Sin all-skipped/re-enable/otrasteclas/Windows/
cierreM4,nuevosmodelos/pixeles. Evidencia
`docs/evidence/linux-designer-inline-when-veto-runtime-q153.json`.


### Seguimiento Q154 (1 noviembre 2026)

Modeloinspector104transicionesaltura+16panelmoves enmodos40x120/25x80
byteexactincremental==Redraw;29modelos63guardas34docsPASS. No mismoheight,
nuevoPTY/pixels/25x80native/Windows/cierreM4;sin arreglo. Evidencia
`docs/evidence/linux-designer-inspector-repaint-models-q154.json`.


### Seguimiento Q155 (1 noviembre 2026)

Conjuntofocalactual41/41modos434checksPTY63guardas34docsPASSen3acc1d1,
7lotes sinreintento/interrupcion. Inspector22+selection1+runtime18.
No matrizglobalIDE/modelos/pixeles nuevos/todascombinaciones/Windows/M4.
Evidencia `docs/evidence/linux-designer-inspector-runtime-q155.json`.


### Seguimiento Q156 (1 noviembre 2026)

Fixturestandalone native25x80/40x120 recibos/cuatropixelesinspeccionados,
seleccionCombo ydialogosinrestos.63guardas34docsPASS. No startupIDE25x80,
endtoend/gestos/otroslayouts/Windows/cierreM4 ni arreglo. Evidencia
`docs/evidence/linux-designer-inspector-native-geometry-q156.json`.


### Seguimiento Q157 (1 noviembre 2026)

All-skipped deuncontrolWHEN.F.inline,F10,F9,runtime retorna sinteclas
en6tipos:6PTY41checks63guardas34docsPASS. No multicontrol/re-enable/
Windows/global/M4,nuevosmodelos/pixeles. Evidencia
`docs/evidence/linux-designer-inline-all-skipped-runtime-q157.json`.


### Seguimiento Q158 (1 noviembre 2026)

IDErealDisplay25x80->designerCombo->deseleccion:3PTY22checks63guardas
34docsPASS,nativepaircompletoinspeccionadosinrestos. No startup25x80,
todostipos/gestos/layouts/Windows/cierreM4niarreglo. Evidencia
`docs/evidence/linux-designer-inspector-ide-small-q158.json`.


### Seguimiento Q159 (1 noviembre 2026)

VALIDTab.F./.T.veto incluyeButtonActionNIL:6PTY60checks63guardas34docs
PASS. No vetodeAction,otrasteclas/mouse/Windows/cierreM4niarreglo.
Evidencia `docs/evidence/linux-designer-inline-valid-six-types-q159.json`.

### Seguimiento Q160 (1 noviembre 2026)

21enlacesruntimeporpar aparte depersistencia,con guardasidentidad/tipo/
pruebaexistente. NoPASSactualniporcentaje,cierreM4/Windows niarreglo.


### Seguimiento C25 (1 noviembre 2026)

TemporalLinux48ec271/bine3298a29:8smokes+6recent55checks,ldd/preflight
34docsPASS,nativepairactualIDE25x80inspeccionadosinrestos. No release/
install/licencias/Windows/globalheredado/cierreM4M5. Evidencia
`docs/evidence/linux-candidate-c25.json`.


### Seguimiento Q161 (1 noviembre 2026)

Dos controles del mismo tipo con WHEN falso regresan sin teclas en 1,5 s.
Se comprueban ambos handlers, valores conservados y ausencia de foco GUI.
La primera expresion se edita en el inspector, se guarda con F10 y el PRG
generado con F9 se compila y ejecuta. Seis tipos y regresion de un control:
12 modos PTY, 105 comprobaciones, 66 guardas y 34 documentos PASS.
Fuente b4b6c529326aa8ad62889f71bf86ad50510d42e2, binario
b9dea838a99851e20d044c6045a10e7245a827afe5d88a95b80dc1426cc90ead.
No arreglo de producto, mezcla de tipos, reactivacion, nuevos modelos o
pixeles, Windows, matriz global ni cierre M4. Button comparte lDummy.
El primer probe tuvo un fallo en el separador esperado del array; se
corrigio la prueba, no el producto. Evidencia: 
`docs/evidence/linux-designer-inline-pair-all-skipped-q161.json`.


### Seguimiento Q162 (1 noviembre 2026)

OptionsDisplay25x80 real antes del diseñador: siete tipos con ajustes
numericos/estilo e historial84checks, texto/Undo/Redo/Esc73, picker de
colores del dialogo18 y shrink7. Dieciseis modos pequeños182checks mas
tres regresiones40x120/41checks:19PTY223checks,66guardas34docsPASS,
sin fallos/reintentos/interrupciones en lote final. Fuente
9260c97b30704c0d1488c816845172be68f64920, binario
909296d23925c65b328a8226239b5b8878119153c2c6011b03b53465156ead64.
No arreglo de producto, startup25x80, nuevos pixeles/modelos, campos de
eventos pequeños, runtime generado, todosgestos/layouts/Windows/global
ni cierreM4. Evidencia `docs/evidence/linux-designer-inline-ide-small-q162.json`.


### Seguimiento Q163 (1 noviembre 2026)

Veinte pares evento/tipo expuestos: texto/F10/Undo/Redo/Esc en IDE real
OptionsDisplay25x80. Seis modos98checksPTY,66guardas34docsPASS. Fuente
198434df00480c49da610be84d06232bcf5c1c53, binario
b9cbfbec71e137666703c724c633a7ff9b8d10174b89461304a809395dfb812e.
Capturas nativas802x477 de State Combo editado/Redo/deseleccion revisadas: valor
largo recortado visualmente pero JSON exacto; handle previsto seleccionado,
deseleccion limpia y marcos inferiores completos. Primer harness nativo
asumio clave vacia existente tras Undo; ausencia es baseline valido. Se
corrigio solo el harness y se repitio completo. No arreglo, ejecucion de
handlers, startup25x80, modelos, todosgestos/layouts/Windows/global/M4.
Evidencia `docs/evidence/linux-designer-inline-events-small-q163.json`.


### Seguimiento Q164 (1 noviembre 2026)

Fuente congelada `6ad102ef132ae30d2bcf7242a6501d3485d990ac`, binario
`2a7dc67d887465834f9080523220a7aa7972f1b698840ffc7b7b2db0010c7314`.
309/309 modos registrados PASS: 308 PTY y una guarda estructural de recovery.
Plan y ledger coinciden, casos unicos, fuente y hash sin cambios. No se
heredan los 228 modos de Q136 ni resultados de otras fuentes.
29 modelos, 66 guardas de tooling y 34 documentos tambien PASS en esa fuente.
Tres capturas nativas del mismo binario, IDE real Display25x80: Combo State
editado, Undo/Redo y deseleccion. Pixeles completos revisados: valor JSON
exacto, recorte visual del texto largo previsto, handle solo seleccionado,
sin restos de State/borde/handle y con marcos inferiores completos.
No hubo casos fallidos, repetidos ni interrumpidos. El limite de sesion a
07:03 y la pausa a 07:36 ocurrieron entre lotes, reconciliados antes de
continuar; no se describe como una ejecucion continua de reloj.
Checkpoint conserva ejecutable exacto, plan, receipt, ledger y logs.
No arreglo de producto, release, instalacion limpia, licencias, Windows,
todos los comportamientos, porcentaje global ni cierre de hitos.
Evidencia: `docs/evidence/linux-full-matrix-q164.json`.


### Seguimiento C26 (1 noviembre 2026)

Export `db19100e183a3a2ed4363b267010c9a2349a2262`, binario stripped
`2842ec0f8975bc3a58abea96116fa1d12f2d4776ef96088e79948ab33a0f76d4`.
8 smokes estandar mas 5 recientes67checks PASS exact binary. Dependencias
ldd resueltas y preflight34docs en export fuera.git. Combo numeric15,
Combo eventos19, Button texto15, Combo pairWHEN11, shrink7. Native actual
IDE25x80 State edit/UndoRedo/deseleccion revisado sin restos, JSON exacto,
handle previsto seleccionado y bordes completos. No release/install/
licencias/Windows/matriz309heredada/cierreM4M5. Evidencia
`docs/evidence/linux-candidate-c26.json`.


### Seguimiento Q165 (1 noviembre 2026)

Cadena de seis parejas GET->Radio->Checkbox->List->Combo->Button->GET:
ambos WHEN falsos evaluados, vuelta sin teclas1,5s, valores conservados
y sin foco GUI. Primer WHEN editado inline/F10/F9, peer preloaded, PRG
generado compilado y ejecutado. Seis modos64checks mas tres regresiones27:
9PTY91checks66guardas34docsPASS. Fuente 03a7a2a3157aba75294459a1cf13698bb7564061
binario 3878b9fa0db4762304912b8c3ff5eddfb06261f19b5cab35599850154f869627.
No arreglo, las30parejas, reactivacion, nuevos modelos/pixeles/Windows/
herenciaQ164/cierreM4. Evidencia `docs/evidence/linux-designer-inline-mixed-skipped-q165.json`.


### Seguimiento Q166 (1 noviembre 2026)

WHEN falso salta al sentinel, que habilita el control. ShiftTab vuelve
a evaluar WHEN y entra al control: typing GET, Down Radio/List/Combo,
toggle Checkbox y Tab Button. Valores finales exactos.6PTY52checks,
66guardas34docsPASS. Fuente 679c848d42cf4cfaa5ea1eac4801337f45f118e6,
binario 9012194518fe40df0dac09aaddcf70bb8e9abaa055d60eac132285e103593d77.
Primer lote fallo solo Button esperado NIL; tras foco/Tab GuiReader
escribe buffer.F. sin pulsacion. Codigo Harbour PushButton y hbgetu
confirman contrato: corregida prueba, nuevo lote completo PASS. No
arreglo de producto, prueba Action, reactivacion arbitraria, modelos/
pixeles/Windows/herencia matriz/cierreM4. Evidencia
`docs/evidence/linux-designer-inline-when-reenable-q166.json`.


### Seguimiento Q167 (1 noviembre 2026)

Seis contratos WHEN enlazan pares iguales/mixtos y reactivacion acotada,
con limites explicitos. Persistencia sigue sin afirmar ejecucion de
handlers. Nueva guarda evita ampliar esas afirmaciones.67guardas
(46inventario),34docsPASS en d89d810. No nuevaejecucionPTY/modelos/
pixeles/arregloproducto/Windows/porcentajeglobal/cierreM4. Evidencia
`docs/evidence/linux-designer-when-runtime-links-q167.json`.


### Seguimiento Q168 (1 noviembre 2026)

GTSTD40x120/25x80, dialogo y siete tipos: seis posiciones solicitadas,
incluidas esquinas extremas.480cambios reales de posicion clamp, bytes
SaveScreen incremental iguales a Redraw completo;104transicionesaltura
y16movimientos previos se mantienen.29modelos67guardas34docsPASS
en a604c24f0613860946a4f19310cab992b4934890. No producto/arreglo/PTY/
pixelesnativos/todoslayouts/gestos/Windows/herenciamatriz/cierreM4.
Evidencia `docs/evidence/linux-designer-inspector-edge-model-q168.json`.


### Seguimiento Q169 (1 noviembre 2026)

Corregido offset de arrastre contra posicion solicitada fuera de pantalla:
se ancla al InspRect visible. Antes100px de arrastre en25x80 no movian
el panel; ahora sigue los100px. Before4PASS1FAIL, after7PTY74checksPASS,
29modelos67guardas34docsPASS;96draganchors ademas de104height/480edge/
16moves. Fuente d32e91e0c5555a3585b4e296d63b13960b879e58, binario
7e7b1c6b85f1b5f1b9d2564240d60966976a5edb424003cf6d1768ae9419d05d.
Nativas completas antes/despues inspeccionadas, underlay limpio y bordes
inferiores completos. Primer harness titulo corregido48->49 antes de
comparacion final. No todasgestos/vertical/Windows/herenciamatriz/M4/100%.
Evidencia `docs/evidence/linux-designer-inspector-drag-anchor-q169.json`.


### Q170 (1 noviembre 2026): arrastre vertical

Inspector clampado abajo tras50CtrlDown, arrastre5filas arriba en25x80/40x120;
4PTY20checks67guardas34docsPASS. OldC26 5PASS1FAIL frente al delta vertical.
Nativa25x80 mismo binario antes/despues95px inspeccionada, underlay limpio
y bordes completos. Fuente deccb7a31c2cefcbd1f92b022b2361db4fdf48e0, binario
671da6af795bef5f7465c85c11f3653482b28f12182477541e866c07a198f393.
No nuevo arreglo/modelos/todosgestos/Windows/herenciamatriz/cierreM4.
Evidencia `docs/evidence/linux-designer-inspector-vertical-drag-q170.json`.


### C27 (1 noviembre 2026): candidato temporal con arrastre corregido

Export4f9c681c605e8386b56cef228eeb3f21f1162031, strippedbin
851540d50a7451ba5b200a1cb9bf1c3e9bf3d40851ee7cc1f12493c359fe8d93.
8smokes mas5recientes27checksPASS exactbin,lddresuelto y34docspreflight
en export fuera.git. Cuatro arrastres horizontal/vertical25x80/40x120
y shrink25x80. Nativepair exactbin bottomclamp->5filasarriba revisado,
underlay limpio/bordescompletos. No release/install/licencias/Windows/
matriz309heredada/global/hitos. Evidencia `docs/evidence/linux-candidate-c27.json`.


### Q171 (1 noviembre 2026): reconstruccion independiente Linux

Dos extracciones frescas de source.tar C27 en directorios distintos,
compiler/strip verificados por hash, buildinfo exacto y sin prebuilts
heredados. Ambas reconstrucciones strip-debug byte-identicas entre si
y al candidato851540d50a7451ba5b200a1cb9bf1c3e9bf3d40851ee7cc1f12493c359fe8d93.
Fuente del candidato4f9c681c605e8386b56cef228eeb3f21f1162031. Runner555a4b1,
67guardas34docsPASS. Es comparacion acotada al mismo host/toolchain/librerias,
no determinismo entre maquinas/compiladores/entornos, instalacion limpia,
licencias, Windows, nuevo runtime/productfix/native ni cierre de M5.
Evidencia `docs/evidence/linux-candidate-rebuild-q171.json`.


### Q172 (1 noviembre 2026): barreras de entrada del rebuild

Seis fixtures negativos: archive/binario/compiler/strip alterados,
candidato fallido y output existente se rechazan antes de ejecutar
compilador; output previo conservado.73guardas34docsPASS en
49fea792bcbc70df930c8660e73d496dca1f2493. No nuevo build/runtime real,
PTY/modelos/pixeles/Windows/licencias/release/global/cierreM5. Evidencia
`docs/evidence/linux-rebuild-input-guards-q172.json`.


### Q173 (1 noviembre 2026): Linux con raiz reducida

C27 ejecutado sin checkout ni compilador visibles: solo binario,
bibliotecas del sistema, dispositivos y carpeta de trabajo de la prueba.
Red aislada y PATH sin herramientas. El conductor de las pruebas queda
fuera de la raiz de la aplicacion. About4, ayuda embebida21 y arrastre
Display25x80/5: tres modos PTY,30checks PASS;73guardas34docsPASS.
Fuente del candidato4f9c681c605e8386b56cef228eeb3f21f1162031, binario
851540d50a7451ba5b200a1cb9bf1c3e9bf3d40851ee7cc1f12493c359fe8d93.
Runner bfcdb3c. Usa las bibliotecas del mismo host: no es una instalacion
limpia en otra maquina/distribucion, instalador, licencias, Windows,
matriz completa, nuevos pixeles ni cierre M5.
Evidencia `docs/evidence/linux-candidate-isolation-q173.json`.


### Q175 (1 noviembre 2026): borde y retorno en un mismo arrastre

Se conserva el punto de agarre del raton al llegar al borde; el panel
permanece clampado hasta que ese punto vuelve al rango. No es el offset
inicial incorrecto de Q169, ni se cambia el producto a arrastre relativo.
Cuatro modos PTY24checks73guardas34docsPASS. Fuente 5dc4f317df6dfc98221b53794635086797a11060,
binario e4da362bb7a9815c0763240cf236e1a68d2ae11269a48ae1af78e0b3cb39085f.
Tres nativas C27 revisadas, bordes y underlay limpios. No todas las
variantes de gesto, nueva UX, Windows, matriz global ni cierre M4.
Evidencia `docs/evidence/linux-designer-inspector-edge-return-q175.json`.


### Q176 (1 noviembre 2026): compilador ausente

Se compila un ejecutable real previo y se inicia el IDE con PATH vacio.
Dos Run > Start fallan con mensaje claro, conservan binario y fuente
byte-exactos, no ejecutan el binario anterior ni dejan temporales y
el editor sigue usable. Un modo PTY11checks73guardas34docsPASS en
e3719180e2da1663b668f601aa5781d4190f30cd, binario
091d1888ad79f54a9a515e0b559ef4445361495eabefd0abaec6194561cb0d6e.
Primer probe corrigio solo la expectativa de mensaje partido en dos
lineas. No arreglo de producto ni prueba de Cancel, respuesta de UI,
Windows, matriz global o cierre M2.
Evidencia `docs/evidence/linux-missing-compiler-q176.json`.


### Q177 (1 noviembre 2026): recuperar el compilador sin reiniciar

Dos builds fallan con compilador ausente y conservan el ejecutable previo.
Se restaura el compilador en el PATH de la misma sesion: se compila un
binario distinto, se lanza solo el resultado nuevo y desaparecen los
diagnosticos del fallo anterior. Fuente byte-exacta y editor usable.
Dos modos PTY27checks73guardas34docsPASS en
30a268db94e9f2c2a41db135e9b98c910d11621e, binario
f35ca99fa0df6567f62de7aeedc35a8a2ee4fda1e3db42bc4441e38810919bb2.
Sin arreglo de producto, Cancel, respuesta UI, Windows, todas las
variantes de fallo, matriz global ni cierre M2.
Evidencia `docs/evidence/linux-restored-compiler-q177.json`.

#### Actualización Q247: C31 focal, no sustitución global de C30

Copy de rango F8 ya repinta al retirar marca: C31 export93e45a4 pasa
7scripts/77checks de selección. Dos modelos editor repaint/EOL fresh
separados y píxeles completos antes/después inspeccionados. La matriz353
de Q243 sigue perteneciendo exclusivamente a C30, no se hereda a C31.
Detalles/fallos de arnés/interrupción: evidence/linux-copy-selection-repaint-q247.json.

### Seguimiento Q291-Q294 (1 noviembre 2026)

Q291 navegación bareTEXT: baseline1PASS2FAIL, C48cuatro scripts12PASS y
modelo99PASS, capturas completas inspeccionadas. Primer arnés buscaba nombre
fantasma en toda pantalla y lo veía en fuente bajo modal; se corrigió a filas
del selector, sin esconder el fallo. Q292color/cache separa payload literal de
comentarios reales, baseline3PASS3FAIL y C49cuatro scripts27checksPASS. Modelos
12TEXT/210repaint/141EOL independientes. Q293 amplía TEXT a15modelo y10PTYchecks
para edición del terminador sin producto nuevo, integra modelo37fresh todosPASS.
Recibos: linux-nav-text-block-q291.json, linux-editor-text-block-q292.json y
linux-model-baseline-q293.json. Q294 enlaza aceptación y actualiza catálogo.
No nueva matriz IDE, Windows, release ni cierre de hito.

### Seguimiento Q295-Q297 (1 noviembre 2026)

Q295comentarios tras bareTEXT: compiler-valid slash/ampersand espaciado,
comentarios bloque cerrados consecutivos y lowercase. Rechazo TEXT&&adyacente
preservado; límite corregido antes de C51. Cinco scriptsPTY41checksPASS,
modelos25TEXT/210repaint/141EOLPASS y par nativo completo inspeccionado.
Recibo linux-editor-text-comment-q295.json. Q29637modelos GTSTD recompilados
source0771c54 limpio PASS, recibo linux-model-baseline-q296.json; globalVM/
inputhook siguen caracterizando límites. Q297aceptación/inventario/catálogo
actualizados, no nuevo build por documentación ni herencia de matriz/Windows.

### Seguimiento Q298-Q302 (1 noviembre 2026)

Q298C52 limpio identificado: fuente90e6d10, bin01c5434ab5b37bb687d19e50265d7ab6906641ce56d5ca4cc1c29bebbd566696,
8smokes y5PTY34checksPASS; catálogo34byteexact/ldd/About de la misma exportación.
No distribución despejada ni herenciaC30. Q299variableTEXT continuada no es
opener: baseline3PASS3FAIL, C53cincoPTY41checksPASS, modelos29TEXT/210repaint/
141EOL; primer modelo erró coordenadaBackspace27PASS2FAIL, corregido29PASS,
fallo preservado. Q300comentario prefijo cerrado permiteTEXT: dosfixtures
compiler-valid, baseline3PASS3FAIL, C54seisPTY47checksPASS, modelos36TEXT/
210repaint/141EOL. Ambos pares nativos completos inspeccionados. Recibos
linux-clean-candidate-q298.json, linux-editor-text-continuation-q299.json,
linux-editor-text-prefix-comment-q300.json. Q30137modelosfresh sourcebc48cac
limpioPASS, recibo linux-model-baseline-q301.json. Q302reconcilia aceptación/
inventario/catálogo. No rebuild sólo docs ni matriz nueva/Windows/hito.

### Seguimiento Q303-Q306 (1 noviembre 2026)

Q303DuplicateLine diffgreedy encontraba prefijo idéntico más allá de inserción
real y dejabaBP en la copia. Baseline corregido4PASS2FAIL; primer aceleradoru
no duplicaba, corregido a l y retenido. C55cincoPTY33checks yBPpolicyprobePASS;
primera invocaciónBPprobe sinargv corregida y retenida. EOL144/repaint210PASS,
par nativo completo inspeccionado. Q304PasteLine confirmado independientemente
4PASS2FAIL, mismo ancla explícita; C56cincoPTY30checksPASS, modelos147EOL/
210repaint y par nativo completo. Recibos linux-duplicate-identical-bp-q303.json,
linux-paste-identical-bp-q304.json. Q30537modelos GTSTD fresh source5938958
limpioPASS, recibo linux-model-baseline-q305.json. Q306aceptación/inventario/
catálogo reconciliados. Sin rebuild sólo docs ni matriz/Windows/hito.

### Seguimiento Q307-Q310 (1 noviembre 2026)

Q307DeleteLine idénticas retirabaBP de superviviente por prefijo diff ambiguo.
Ancla de borrado explícita; baseline2PASS3FAIL, C57cincoPTY31checks+BPpolicyprobe
PASS, modelos152EOL/210repaint y par nativo completo inspeccionado. Q308arnés
postexport24checksDelete/CtrlY/unmarkedCutPASS, borrar propia instrucción marcada
no resucitaBP conUndo. Recibos linux-delete-identical-bp-q307.json y
linux-delete-identical-bp-dispatch-q308.json. Q30937modelosGTSTD source247cd40
limpioPASS, recibo linux-model-baseline-q309.json. Q310aceptación/inventario/
catálogo actualizados, no nuevo producto/build por docs/matriz/Windows/hito.

### Seguimiento Q311-Q314 (1 noviembre 2026)

Q311Cut rango de iniciofila1 a iniciofila2 conservabaBP de instrucción borrada
cuando endpoint era idéntico. Baseline1PASS3FAIL; C58modelo correcto/gutterstale
3PASS1FAIL retenido, C59Display explícito corrige. CincoPTY34checks+BPpolicyprobe,
155EOL/210repaintPASS. Q312Delete/BS misma selección con baseline propio1PASS3FAIL;
C60cincomodos27checks+BPpolicyprobe, 161EOL/210repaintPASS. Pares nativos completos
inspeccionados. Recibos linux-cut-identical-bp-q311.json y
linux-selection-delete-identical-bp-q312.json. Enter/typeover no modificados.
Q31337modelosGTSTD fuentee61606b limpioPASS, recibo linux-model-baseline-q313.json.
Q314aceptación/inventario/catálogo actualizados. No rebuild sólo docs/matriz/Windows/hito.

### Seguimiento Q315-Q319 (1 noviembre 2026)

Q315C61 exportf63e189/bin e0399cb224f06c707b228d5d3291e3957a81bccd22278de355ac02f00e325c43,
8smokes/6modosBP32checksPASS, About/docs34/ldd mismoexport, sin nueva matriz.
Recibo linux-clean-candidate-q315.json, avisos/licencias pendientes. Q316CtrlT
con rango borraba otra palabra y dejabaMARK; baseline1PASS3FAIL, C62cincoPTY29checks,
modelo13PASS/par nativo completo. Fixturemodelooverstrike12PASS1FAIL conservada,
insertmodecorrige. Q317postexportreverse/TAB/UTF8/wholelineBP16checksPASS.
Recibos linux-delete-word-selection-q316.json y linux-delete-word-selection-guards-q317.json.
Q31837modelosGTSTD sourcedd9b373 limpioPASS, recibo linux-model-baseline-q318.json.
Q319aceptación/inventario/catálogo reconciliados, no rebuild sólo docs ni Windows/hito.

### Seguimiento Q320-Q323 (1 noviembre 2026)

Q320CtrlT tomabaTAB como parte de palabra y borraba siguiente palabra hastaespacio.
Baseline1PASS2FAIL; C63cincomodosPTY23checksPASS, modelos18DeleteWord/161EOL/
210repaint y par nativo completo inspeccionado. Recibo linux-delete-word-tab-boundary-q320.json.
Q321postexport22modelo/6PTYchecksPASS no-op virtualEOL/actualEOL/empty/redo/
clipboard/nojournal/nofalseprompt, recibo linux-delete-word-noop-q321.json.
Q32237modelosGTSTD source584c00b limpioPASS, recibo linux-model-baseline-q322.json.
Q323aceptación/inventario/catálogo actualizados, no rebuild sólo docs ni Windows/hito.

### Seguimiento Q324-Q327 (1 noviembre 2026)

Q324METHOD implícito tras ENDCLASS faltaba en Go to function. Fix acotado
al último CLASS/CREATE CLASS, distingue miembro de implementación. Baseline
C63 1/2; C64 15checksPTY/106modelo PASS y par nativo completo inspeccionado.
Q325otros15checksPTY con cincofixtures compiler-valid PASS. Q32637modelos
fresh sobre7f7b581 PASS. Receipts linux-nav-implicit-method-q324.json,
linux-nav-implicit-contexts-q325.json y linux-model-baseline-q326.json.
Q327docs/catálogo actualizados; no rebuild sólo docs ni matriz/Windows/hito.

### Seguimiento Q328-Q332 (1 noviembre 2026)

Q328C65 candidato limpio identificado de59dd2ce con8smokes y27checksPTY
navegación/editor. No matriz completa/install/licencias. Q329DECLARED METHOD
explícito omitido en picker: C65baseline1/2, fixfa41c0a/C66,12checksPTY y
111modeloPASS, pareja nativa completa inspeccionada. Q330cuatrofixtures
compiler-valid12checksPTY PASS; Q33137modelosfresh7d7f996 PASS. Q332docs y
catálogo, sin rebuild sólo docs. Evidencias linux-clean-candidate-q328.json,
linux-nav-declared-method-q329.json, linux-nav-declared-contexts-q330.json,
linux-model-baseline-q331.json. No Windows/hito; no soporte de DESTRUCTOR
implícito rechazado por compilador ni de preprocesador arbitrario.

### Seguimiento Q333-Q336 (1 noviembre 2026)

Q333Enter en vacía antes de idéntica dejaba BP sobre línea nueva: C66baseline
4/2; fixfa2d571/C67,6checksPTY/4scriptsBP y164modelo PASS, par nativo completo.
Q334CRLF6checksPTY/EOL172checks PASS; modelo cubre final vacío y BPactual.
Q33537modelosfresh7ba77e7limpio PASS; ejecución preliminar con tests modificados
no se usa como baseline limpio. Receipts linux-enter-identical-blank-bp-q333.json,
linux-enter-blank-guards-q334.json y linux-model-baseline-q335.json. Q336docs y
catálogo, sin rebuild sólo docs. No política BP nueva/matrizglobal/Windows/hito.

### Seguimiento Q337-Q341 (1 noviembre 2026)

Q337C69 identificado tras C68export parcial por disco lleno.8smokes y21checks
focalesPASS; interrupción y limpieza de ejecutables derivados con hashes
retenidas enreceipt. Q338Backspace blankjoin: C69baseline2/3, C70LF5/CRLF5 y
3regresiones/EOL178 PASS, pareja nativa completa. Q339Delete EOL independiente:
C70baseline2/3, C71LF5/CRLF5 y3regresiones/EOL184 PASS, pareja nativa completa.
Q34037modelos fresh25b3585limpioPASS. Q341docs/catálogo sin rebuild sólo docs.
Receipts linux-clean-candidate-q337.json, linux-backspace-identical-blank-bp-q338.json,
linux-delete-eol-blank-bp-q339.json y linux-model-baseline-q340.json.
No nueva política BP/matrizglobal/Windows/install/licencias/hito.

### Seguimiento Q342-Q345 (1 noviembre 2026)

Q342default .prg para tokens HBP literales sin extensión: compilerfixture
exit0/C71baseline2/1/C72focal3checks y4regresionesProject/modelProject PASS,
par nativo completo inspeccionado. Q343quotedspace3checksPTY/modelguards PASS.
Q34437modelosfresh95bacc5limpioPASS. Q345docs/catálogo sin rebuild sólo docs.
Receipts linux-project-extensionless-q342.json,
linux-project-extensionless-guards-q343.json y linux-model-baseline-q344.json.
Flags/macros/filtros/wildcards no evaluados al abrir. No Windows/hito/matrizglobal.

### Seguimiento Q346-Q351 (1 noviembre 2026)

Q346ocho gruposguardas PASS sobre5e06df1. Q347C73 identificado87222cb con
8smokes y22checks focales. Q348siete scripts críticos, Q349cinco modos48checks,
Q350cuatro modos52checks PASS en el mismo binarioC73. Dos invocaciones inválidas
previas retenidas, corregidas PASS; no ejecución sin reintentos. Q351reconcilia
estado/docs/catálogo sin producto/build nuevo. Receipts linux-tooling-guards-q346.json,
linux-clean-candidate-q347.json, linux-critical-paths-c73-q348.json,
linux-critical-build-isolation-c73-q349.json y linux-designer-critical-c73-q350.json.
No suma de checks como porcentaje/matriz, nuevos píxeles, Windows o hito.

### Seguimiento Q352-Q354 (1 noviembre 2026)

Q352dos rebuilds independientes mismohost/compilador/strip byteexactC73 y tres
smokesPTY raíz mínima PASS. No VM ni instalación limpia. Q353referencia literal
LICENSE.upstream.txt separada en third-party/harbour desde upstream694428e,
14avisos iniciales idénticos;4archivos completos idénticos/10difieren. No licencia
para código propio/modificaciones ni clearance de paquete. Receipts
linux-c73-rebuild-isolation-q352.json y harbour-notice-provenance-q353.json.
Q354docs/catálogo sin producto/build. M5 sigue pendiente, igual que Windows y M6.

### Q355-Q360 (1 noviembre 2026): recuperación y clipboard vacío

Q355C73 recuperación/encoding cinco modos PASS; primer fixture mixedEOL+BOM
contradictorio conservado como inválido, no defecto de producto. Q356guardas de
fixture incompatibles:12subcasos y deepmixedEOL válido PASS.
Q357Copy de línea vacía se confundía con clipboard ausente: C73baseline2PASS2FAIL.
Presencia compartida explícita en productores, sin cambiar Paste debajo de línea.
C74focal4PTYchecks y cuatro regresiones PASS; modelos separados187/202PASS,
píxeles antes/después1202x762 completos inspeccionados sólo C73/C74.
Q358seis modos31checks C74PASS: ausencia no-op, CopyLF, DeleteLF/CRLF,
Cut de límite vacío LF/CRLF compartido entre documentos tras Undo del origen.
Cut conserva dos fragmentos vacíos, sin cambiar semántica de bloques.
Q359C75 identificado por builder oficial strip-debug fuente
93d3876480c5217e4eadddc2f88a4400c321146a,
bin e78652a51a586d67550d526c05a1ac54278d7b62459d26a23beace1afca024ef.
8smokes/About revisión exacta/docs34byteexact/ldd y cuatro modosclipboard19checks
PASS sobre ese binario intacto. Es el último candidato limpio identificado,
no hereda matrices ni píxeles previos; C30 sigue único plan histórico completo.
Q360reconcilia docs/catálogo, no nuevo producto/build/píxeles; docs posteriores
no embebidos en C75. Windows/install/licencias/M5/M6/políticas siguen abiertos.
Evidencias: linux-recovery-encoding-c73-q355.json,
linux-empty-line-clipboard-q357.json, linux-empty-clipboard-guards-q358.json,
linux-clean-candidate-q359.json.

### Q361-Q371 (1 noviembre 2026): aceptación focal y selección virtual

Q36137modelosGTSTD fresh fuente cb77bfb PASS separados, no aceptación IDE.
Q362C75 cinco scripts clipboard lifecycle/UTF8/CtrlTnoop/journalUndoReload PASS;
dos invocaciones sin binario posicional inválidas retenidas antes de corregir.
Q363cinco Replace33checks PASS; Q364 límite UTF8 frente a UTF8EX documentado,
probe biblioteca separado, sin cambiar CP/toolchain ni prometer Unicodecasefold.
Q365cinco selecciónvirtual/Duplicate/TAB30checks PASS. Q366cinco proyectos PASS:
BOM/EOF/extensionless y diagnósticos reales leading-space/colon con GCCwrapper.
Q367cinco modos fallo-promoción/retry/output/argv PASS; compilerfixtures acotados.
Todos estos bloques son C75, no se heredan por candidatos posteriores.
Q368detecta regresión clipboard de selección virtual sin bytes/límites: C75Copy
3PASS1FAIL y Cut3PASS1FAIL independientes. C76focal ambos4/0; seis regresiones
PASS y modelo204/0 separado. Primer fixture combinado contaminado retenido.
Presencia de selección depende ahora de contenido real; CopyLine/DeleteLine
vacías siguen válidas, Cut de límite real conserva semántica de dos fragmentos.
Par C75/C76 nativo1202x762 completo inspeccionado: ya no se inserta líneaespuria.
Q369compactación temporal reversible11archives con SHAdecomprimido verificado,
sin retirar árboles/binarios/logs/manifiestos/evidencia; no cambio de producto.
Q370C77 limpio identificado fuente74db43fe4e4bc5dae5f54e4663a4ffb8e9d0abd9,
bin b0ad4e6bb4ad5f5d87eef67111995dfdce3963c59745e2b101f543ea323beaeb.
Builderstrip-debug/Aboutrevision/docs34byteexact/ldd/8smokes y seis modosclipboard
27checksPASS sobre ese binario intacto. Último candidato identificado, sin
heredar matriz/modelos/píxeles; C30 único plan histórico completo. Q371docs
posteriores no embebidos en C77, sin rebuild por docs. M5/M6/Windows/install/
licencias y políticas pendientes abiertos. Evidencias linux-model-baseline-q361,
linux-clipboard-recovery-c75-q362, linux-replace-c75-q363,
utf8-casefold-investigation-q364, linux-selection-virtual-c75-q365,
linux-project-c75-q366, linux-build-retry-c75-q367, linux-virtual-clipboard-q368,
linux-clean-candidate-q370 (JSON en docs/evidence).

### Q372-Q381 (1 noviembre 2026): regresiones focales del candidato C77

Q37237modelosGTSTD fresh fuente b35f28c PASS, separados del binario IDE.
Q373cinco scriptsC77Save/Close/conflictos/SaveAsrefusal+killrestartPASS: original,
externo, dirty y documentos/journals separados conservados. Q374cinco navscripts
15checksPASS: METHODimplícito/DECLARED/TEXT/continuación/PROCEDURECLASS.
Q375labelsDECLARED corregidos sólo harness,3checksC77PASS. Q376ocho grupos
herramientasPASS fuente72515f8, no aceptaciónIDE.
Q377cuatro modosdesigner52checksC77PASS, runtimegenerado instrumentado acotado.
Q378tres modos144checksC77PASS: sietecontrolesaprobados cargados/creados,
Cut/Paste/UndoRedo y clones separados con variablesúnicas; persistenciaJSON,
no píxeles ni aceptaciónruntimegenerado. Q379seisscriptsBPidentity33checksLF
PASS, conserva/drop según instrucciónoriginal; no debuggercompleto.
Q380cuatromodosC77PASS: deepmixedEOL y UTF8BOM separados kill/recover/saveexactos,
Compare readonly/snapshots/Later, mouseUTF8terminal17checksBOM/TAB/mixedEOL.
Cada prueba verificó hash C77intacto b0ad4e6bb4ad5f5d87eef67111995dfdce3963c59745e2b101f543ea323beaeb,
fuente74db43fe4e4bc5dae5f54e4663a4ffb8e9d0abd9. Ningún bloque sustituye matriz
completa ni nueva inspección de píxeles. C30único planhistórico completo.
Q381reconcilia docs/catálogo, sin producto/buildIDE; docs posteriores no
embebidosC77, no rebuild por receipts. Windows/install/licencias/M5/M6 y
políticas pendientes intactos. Receipts docs/evidence/linux-*-q372 a q380.json.

### Q382-Q385 (1 noviembre 2026): navegación de BOM en vista raw

Q382fixtureUTF8BOM compiler-valid con carácter fueraCP437 abre raw sin pérdida.
C77baseline1PASS1FAIL omitía primera PROCEDURE. Sólo la copia del scanner ignora
la firma inicial; buffer/encoding/CP no cambian. C78focal3/0 y cuatro regresiones
12checksPASS; lexical113/0 separado. Píxeles completos1202x762 antes/después
inspeccionados: alertasinfunción pasa a Mainline1/1of1, glyphsraw siguenraw.
Q383lexical119/0 añade BOMcomentario/directiva/TEXT/dump/linefísical y no elimina
firma embebida. Q384C79limpio identificado fuentece049bfb140c38d0123c148c8711c7a488bba81e,
bin71194ee29d394ae294257a506d0d2c1add01cf5ffa307225d462b28ee95505b6.
Builderstrip-debug/Aboutrevision/docs34byteexact/ldd/8smokes y cuatro modosnav
12checksPASS binintacto. Último identificado, no hereda matrices/modelos/píxeles
C77/C78; C30único planhistóricocompleto. Q385docs/catálogo posteriores no embebidos,
no nuevo producto/buildIDE ni cierreWindows/install/licencias/M5/M6/políticas.
Receipts linux-nav-raw-bom-q382.json y linux-clean-candidate-q384.json.

### Q386-Q391 (1 noviembre 2026): END CLASS y candidato C81

Q38637modelosGTSTD fresh724da0cPASS separados. Q387fixture compiler-valid
CREATE CLASS/END CLASS omitía METHODimplícito: C79baseline1PASS2FAIL.
Equivalencia terminador END CLASS/ENDCLASS restaura contexto; C80focal3/0,
cuatro navregresiones12checks y lexical123/0separado. Par nativo1202x762
completo inspeccionado: Demo:Pingline5 aparece sin listar miembrodeclarante.
Q388cuatrocontextosLOCKED/TAB/typed/latestclass hblibexit0+12PTYchecksC80PASS.
Q389C81 limpio identificado fuente299a1047a050517342b0aa4ebfb9170095e0388b,
bin2309304ec2ed54d6f005ef5afb6cbc0649d03cdaeec3f7322e6e9592303d059a.
Builderstrip-debug/Aboutrevision/docs34byteexact/ldd/8smokes y cuatro navmodos
12checksPASS binintacto. Último candidato identificado, sin heredar matrices,
modelos/píxeles; C30único planhistóricocompleto. Q390compactación temporal
reversible de8archives con SHAdecomprimido verificado, sin perder árboles,
binarios/logs/manifests/evidencia. No cambio de producto ni distribución.
Q391docs/catálogo posteriores no embebidos en C81, sin rebuild por docs.
M5/M6/Windows/install/licencias y políticas pendientes intactos.
Receipts linux-nav-end-class-q387.json, linux-nav-end-class-contexts-q388.json,
linux-clean-candidate-q389.json.

### Q392-Q396 (1 noviembre 2026): terminador continuado y C83

Q39237modelosGTSTDfresh78df81bPASS separados. Q393seismodosC81clipboard/virtual/
SaveAll/Close37checksPASS. Q394END ; seguido CLASS compiler-valid hblibexit0
omitía METHODimplícito: C81baseline1PASS2FAIL. InicioEND/ENDCLASS se une por la
ruta lógica ya existente; C82focal3/0, cinco contextoshblib0+15PTYchecksPASS,
lexical127/0separado con negativo ENDIF. PíxelesC81/C82 completos1202x762
inspeccionados muestran Demo:Pingline6 y2of2, jump/savebytes separado.
Q395C83limpio identificado fuentec245e8c3047f97a8674f75bb0f1ae33123defe1e,
bin92504b3338a3e2f24a14615d54d8ad4fd14b12f9901fd53cd8c1f8aa157309a5.
Builderstrip-debug/Aboutrevision/docs34byteexact/ldd/8smokes y cincofocal17checks
PASS binintacto: continuedEND/rawBOM/DECLARED/emptyline/virtualCopy.
Último identificado, sin heredar matrices/modelos/píxeles; C30único planhistórico
completo. Q396docs/catálogo posteriores no embebidosC83, no rebuild por docs.
Windows/install/licencias/M5/M6 y políticas pendientes intactos. Evidencia:
linux-clipboard-save-c81-q393.json, linux-nav-continued-end-q394.json,
linux-clean-candidate-q395.json.

### Q397-Q401 (1 noviembre 2026): aceptación focal actual C83

Q39737modelosGTSTDfresh c7d0adePASS separados del IDE. Q398cincoC83modosM2
62checksPASS: compiladorausente/fallatrasoutput/éxitosinoutput/emptyargv/
ProjectMessages; fixturescompilercontrolados acotados para fallos.
Q399cincoC83modosrecoveryPASS: deepmixedEOL y UTF8BOM separados kill/recover/
saveexactos, Comparereadonly/snapshots/Later, journalUndoalbaseline y Reload
retiran recuperaciónobsoleta y reinicianlimpio. Q400cuatrodesigner52checksPASS:
mixedruntime23/GETVALIDveto10/ComboClipboardSTATE9/Inspectorclose25x80JSON10.
Generatedruntimeinstrumentado para valores/salida, no stockdistribución.
Cada modo verificó binC83intacto92504b3338a3e2f24a14615d54d8ad4fd14b12f9901fd53cd8c1f8aa157309a5,
fuentec245e8c3047f97a8674f75bb0f1ae33123defe1e. No es matrizcompleta ni nuevo
píxel/Windows/install/licencias/M5/M6; no cambia políticaspendientes.
Q401docs/catálogo posteriores no embebidosC83, sin rebuild por receipts.
C30 sigue único planhistóricocompleto. Receipts linux-model-baseline-q397,
linux-build-run-c83-q398, linux-recovery-c83-q399 y linux-designer-c83-q400
(JSON en docs/evidence).

### Q402-Q406 (1 noviembre 2026): TEXT estándar y candidato C85

Q402cinco modos editor C83exacto52checksPASS: EnterCRLF6/BackspaceCRLF5/
continuationBackspace12/Delete12/mouseUTF8terminal17. No herencia a C85.
Q403defecto reproducido con TEXT TO FILE válido en std.ch: C83listaba una
función dentro del payload y ocultaba la real tras comentario literal.
Baseline1PASS2FAIL; scanner reconoce TEXT TO FILE y TEXT TO PRINTER como
bloques raw estándar hasta ENDTEXT. No ejecuta payload ni evalúa macros.
C84focal fuente6d855540cdff2c85335f69ad38ee9ecb2f8e8a3f,
bin584878460045dae3e8c13a1c2604006b025f47b9ba57c1f67e2e1055a1456be3:
focal3PASS/cuatroregresiones12checksPASS. ModeloGTSTD131PASS separado.
Píxeles completos C83/C84 inspeccionados: Phantomline3 sustituido por RealLine7;
no corrección de colores de sintaxis. Q404cuatro contextos compilador exit0
(PRINTER/FILEtabs/bare/expresión) y12checksPTY C84PASS, sin nuevos píxeles.
Q405C85oficial fuente fbca0b71789b6d5dd3589587cf138ac91cbc90ba,
bin351bd50074b28c6fdfc5b029382c891ac6974ec799a828fc536f86628ba85f34:
stripdebug/Aboutrev/docs34byteexact/ldd/8smokesPASS, cincoTEXT15checksPASS.
Receipts linux-nav-text-stream-q403.json, linux-nav-text-contexts-q404.json y
linux-candidate-c85-q405.json. Compactación reversible C81-C84source.tar
verificada con SHA original/manifest cuando existe/decomprimido; árboles,
binarios, logs y evidencia conservados,741523760bytes liberados.
Q406docs/catálogo posteriores no embebidos C85. No matriz completa,
herencia de modelos/píxeles, Windows/install/licencias ni cierre de hito.

### Q407-Q411 (1 noviembre 2026): TEXT continuado y C86

Q407persistió contextos estándar, cincofixturescompiler-valid/15checks C85PASS.
Q408ocho toolingguardgroups fuente86ef24aPASS separados del producto.
Q409reprodujo tres comandos estándar continuados TEXT ; TO FILE / TEXT TO ;
FILE / TEXT TO ; PRINTER: cada compilerexit0, C85cada1PASS2FAIL.
Unión limitada a prefijos estándar antes de reconocer TEXT conserva líneas
físicas y excluye payload. C86oficial fuente81c06602b621616005bc9b2e45195fd9184f51a9,
bin c46a6b8134656df89aa177188b44bc261e2f7c72a6f1e0005ffaf9de9ee89a27:
8smokes/Aboutrev/docs34/lddPASS+trescontinuados9checks+cincoestándar15PASS.
LexicalGTSTD136PASS separado; initial135/1 por comparación prefix del helper
conservado, corregido con negación de igualdad exacta antes de build final.
Píxeles completos1202x762C85/C86 inspeccionados: Phantomline4 pasa a RealLine8,
no cambio en colores fuente. Q410persistió fixture parametrizado por líneas,
nuevecompilerfixtures27checksC86PASS incluyendo doblecontinuación/comentario.
Receipts linux-nav-text-continuation-q409.json y
linux-text-continuation-contexts-q410.json. Compactación reversibleC85-C86tar
SHA original/manifest/decomprimido idénticos;370928288bytes liberados, resto
intacto. Q411docs/catálogo posteriores no embebidos C86, sin rebuildpor docs.
No nueva matrizcompleta/modelosheredados/píxelesextra/Windows/install/licencias
ni cierre de hito; macros/customstreams/CP/toolchain/políticas no cambiadas.

### Q412-Q417 (1 noviembre 2026): aceptación focal C86

Q412cinconav15checksPASS: rawBOM/ENDCLASS/DECLARED/bareTEXT/arraycomment.
Q413cincomodosrecoveryPASS: deeppathmixedEOL y UTF8BOM por separado,
kill/recover/save exacto; Compare readonly/reopenrefresh/Later; Undo/Reload
retiran journal obsoleto y restart no lo ofrece. Q414cincomodosclipboard30checks
PASS: Copy/Cutvirtualvacío no-op/Undo, línea física vacía PasteUndoRedo,
blockmixedEOL/UTF8multidoc bindings/historia independientes.
Q415cincoM2modos62checksPASS: compilerabsent/failureoutput/missingoutput,
argvvacíos Start/Script/Debug, diagnóstico real proyecto preserva dirtybuffer,
sin duplicación ni save silencioso. Primer intento harness sin compilerPATH
falló antes del IDE; log retenido, repetido con PATH explícito, no retry-free.
Q416cuatromodosdesigner52checksPASS: fixturemixed12controles/F9/compile/
runescape-save-cancel-selectors; GETVALIDfalse/true; clipboardComboSTATE y
bindings independientes; inspector25x80 close/F4/JSON. Defaultmixed8checks
adicionales conservados por separado, no usados para inflar52checks.
Cada modo confirmó binC86intacto
c46a6b8134656df89aa177188b44bc261e2f7c72a6f1e0005ffaf9de9ee89a27,
fuente81c06602b621616005bc9b2e45195fd9184f51a9. Runtimegenerado instrumentado
para observar valores/salida, no certificación del paquete. Sin nuevos
píxeles/modelos/matrizcompleta/Windows/install/licencias/cierre de hito.
Receipts linux-c86-nav-regression-q412.json, linux-c86-recovery-q413.json,
linux-c86-clipboard-q414.json, linux-c86-m2-q415.json y
linux-c86-designer-q416.json. Q417docs/catálogo posteriores no embebidosC86.

### Q418-Q419 (1 noviembre 2026): PRINTER abreviado y C87

Q418compilador confirmó TEXT TO PRIN y TEXT TO PRINT válidos; C86cadauno
1PASS2FAIL con phantompayload y declaración real oculta. FIL(3letras) y ENDT
rechazados, logs conservados. Scanner usa helper existente de keywords para
PRINTER>=4letras, sin aceptar PRI/PRINTERCUSTOM ni cambiar terminador ENDTEXT.
C87oficial fuentee84d41e1d57f35aa1b42fe538b4ab11aa598f6fe,
bin a7f08d630682a8c13ac6ead900cead971c128fa5f974b23be2114d73191fca48:
8smokes/Aboutrev/docs34byteexact/lddPASS+13compilerfixtures39PTYchecksPASS,
incluye PRINTE y abreviación continuada. ModeloGTSTD141PASS separado.
Píxeles1202x762C86/C87 completos inspeccionados: Phantomline3 pasa a RealLine7,
colores fuente intactos, sin corrección coloring. Receipt
linux-nav-printer-abbrev-q418.json. Q419compactación reversible source.tarC87
verifica SHA original/manifest/decomprimido, preserva árboles/bin/log/evidencia.
Docs/catálogo Q419posteriores no embebidos C87, sin rebuild por docs.
Sin matrizcompleta/modelosheredados/Windows/install/licencias/cierre de hito,
macros/customstreams/payloadexecution/CP/toolchain/políticas no cambiados.

### Q420-Q426 (1 noviembre 2026): aceptación focal C87

Q420cinconav15checksPASS(rawBOM/ENDCLASS/DECLARED/bareTEXT/arraycomment).
Q421compactación reversible20unstrippedantiguos, SHA original/manifest/gzip
restaurado idénticos;81595286bytes liberados, árboles/bins/log/manifests/evidencia
intactos. Hardlinks entre exports descartados, copias independientes.
Q422cincoeditor52checksPASS: EnterCRLF6/BackspaceCRLF5, continuationjoinBS12/
Delete12, UTF8terminalmouse17 bytes exactos/BOM/TAB/mixedEOL/history. Iniciales
dos sesiones LF por envCRLF ignorado se conservaron identificadas LF; repetidas
con --crlf realPASS, sin cambiar asserts. Q423cincomodosrecoveryPASS:
deeppathmixedEOL/BOM separados killrecover/saveexact, Compare/Laterreadonly
refresh, Undo/Reloadjournalretirement/restart. Q424cuatroM2modos55checksPASS:
promotionfailure retieneoutput, unblockretryfreshrealrun, missingoutputdiag
jump, RunargumentsmodalOK/Cancel/Esc/quotevalidation/clear. Controlledcompiler
fixtures y escenario retry explícito, no afirmación retry-free.
Q425cuatrodesigner52checksPASS: mixed12controles/F9compile/runescape-save-
cancel-selectors, GETVALIDveto/allow, ComboClipboardSTATE/bindingsindependientes,
inspector25x80close/F4/JSON. Runtimegenerado instrumentado para valores/salida,
PTYsemántica/JSON no píxeles. Cada modo confirmó binC87intacto
 a7f08d630682a8c13ac6ead900cead971c128fa5f974b23be2114d73191fca48,
fuentee84d41e1d57f35aa1b42fe538b4ab11aa598f6fe. Receipts por Q420-Q425.
Q426docs/catálogo posteriores no embebidos C87, sin rebuild por docs.
No nuevos píxeles/modelos/matrizcompleta/Windows/install/licencias/hito.

### Q427-Q433 (1 noviembre 2026): procedencia factual y editor C87

Q427comparación local Harbour694428e limpio:14compiledvendored,4idénticos/
10difieren fuera de avisos iniciales idénticos, sin cambios desdeQ353.
en.txt idéntico; dbgscript.prg helper local sin mismo nombre upstream. Copia
LICENSE.upstream.txt exacta; inventarioHBP28fuentes:14referencias LICENSE raíz
faltantes/14sinheaderGPLdetectado. Esto no decide derechos ni licencia.
Q428READMEhbdebug corrige afirmación obsoleta de sólo2archivosmodificados/
restobyteexact. Commitcomparación no se presenta como revisiónoriginalimport.
Licencia de código propio/modificaciones, excepción y paquete siguen abiertos.
Q429ocho toolingguardgroups858582dPASS separados del producto.
Q430cincoSave/ConflictmodesC87PASS: SaveAllparcial, SaveAsfailureidentity/F2,
colisiónSaveAsrechazada+killrestartdosdocsseparadosbyteexact, SaveAllCancel/
Reloadpreservanexterno/backupysinfalsecount. Q431cincoReplace33checksPASS:
spaces/trailing/cancel, identitycleanclose, nochange selección preservada,
replace limpia staleSelection, historia aislada antes/después.
Q432tresFind21checksPASS: menú/F5/Repeat/wrap consumen selección al éxito,
Cancel/notfound conservan selección y Undo exacto.
Cada modo producto confirmó C87fuentee84d41e1d57f35aa1b42fe538b4ab11aa598f6fe,
bin a7f08d630682a8c13ac6ead900cead971c128fa5f974b23be2114d73191fca48
intacto. Receipts por Q427/Q429-Q432. Sin nuevos modelos/píxeles/matrizcompleta/
Windows/install/licencias/hito. Q433docs/catálogo posteriores no embebidosC87,
sin rebuild por docs; no cambiosCP/casefold/toolchain/políticas pendientes.

### Q434-Q440 (1 noviembre 2026): contratos M0 y gestos medidos

Q434vincula cinco dispatch exactos editor(click/doubleclick/Enter/BS/Delete)
y siete suites navegación recientes;18dispatchlinks en total. Initialtest
51PASS1FAIL por denominador antiguo13 quedó registrado y fue corregido a18,
52unitsPASS, sin retirar asserts. Links no son PASS actual ni cierre M0.
Q435introduce links de gestos exactos por fuente/contexto/condición, con
wrongcontext/duplicate/missingtest failclosed guards. Q436C87tresinspector
modes17checksPASS(horizontal40x120/vertical25x80/edge-return25x80), JSONintacto.
Contrato sólo headerclose/drag bajo main-dispatch no-placing, no todoshit-tests.
Q437C87ProjectMouse11checksPASS: clickselect/Enter, scroll+doublesource,
headerdouble/missing/emptyMessagesno-open, realdiagdoubleexactrow, bytesintactos.
Q438C87HelpMouse18checksPASS: tree/scrolledrow/SearchNextExportClose,
relatedlinks/history/dirtyreturn/Undo. Su checkwheelbounds no prueba movimiento.
Q439nueva HelpWheel24checksPASS incluye7medidasnuevascounter: Home1,max>3,
down1a2/up2a1/upclamp, Endmax/downclamp/upmax-1. El resto conserva workflow
click/sourceUndo, no se suma como variantes independientes. ProductoC87intacto,
fuentee84d41e1d57f35aa1b42fe538b4ab11aa598f6fe,
bin a7f08d630682a8c13ac6ead900cead971c128fa5f974b23be2114d73191fca48.
Inventario mouse vincula9de27ramas fuente con alcancefocal,18siguenpendientes;
ramas no son funciones y vínculos no son PASS.55inventoryunitsPASS y catálogo34
byteexact. Receipts por Q434-Q439. Q440docs/catálogo posteriores no embebidosC87,
sinbuildpor docs, nuevosmodelos/píxeles/matrizcompleta/Windows/licencia/hito.

### Q442-Q449 (1 noviembre 2026): wheel y ratón debugger acotados

Q442nuevoEditorWheelC87 9checksPASS:100logicalCRLFsinseparatorfinal,
cursor±1/viewportcross/top-endclamp/closeclean/no diskchange. Initial7/2
por esperar100 con CRLFfinal que crea blank101 se conserva como errorfixture,
no defectoproducto. Q443tresrutas parent/Editorwheel links scope menuclosed/
visibleeditor, no selection/hidden/menu states. Q444nuevolinkviewerwheel9PASS,
UI separada de Contents: topiclargo/±1/top-endclamp/dirtyreturn/Undoexact.
Combinedkeyboard-wheelbranches vinculadas sólo wheel, no nueva aceptaciónkeys.
Q445dosdebuggermousefixtures14PASS: localclick/Enter/doubleclickedCnotpriorB/
CancelpreservaA/resumeexpectedvalues y caller-calleeframe101/202/borders/no source
change. Q446rightclick8PASSincl1nuevoignoredMonitorgridcheck, no contextmenu
feature. Restantesramasclasificadas:2IsNavKeyinternas, designerUPtrace,
3readerarmrelease/doublesuppression requierenfixturepropio, IDEleftparent,
AppScreeninputconsumption, modalclose. Q447Helpmodalclose11PASSincl4newchecks:
col8titleoutside stays; closecol3 yedgecol5 afterreopenKeys cierran; resumesource
exact. ContratoShowModal sóloHelp, no todoscallers/coordenadas.
M0mouse19de27ramasfuente conlinksacotados,8pendientes; no porcentaje deIDE ni
funciones, links no son runtimePASS.55inventoryunitsPASS. ReceiptsQ442/Q444-Q447.
C87fuentee84d41e1d57f35aa1b42fe538b4ab11aa598f6fe,
bin a7f08d630682a8c13ac6ead900cead971c128fa5f974b23be2114d73191fca48
intacto. PTYcounter/grid/JSON no son píxeles nuevos. Q448docs/catálogo posteriores
noembebidosC87, sinbuildpor docs. Q449toolingguards separados, no producto/
modelos/fullmatrix/Windows/install/licencias/cierre de hito.

### Q450-Q455 (1 noviembre 2026): rutas de ratón y límites del inventario

Q450 prueba el PushButton emitido por F9 de C87 compilado con helpers del
checkout48641da, identificados con hashes separados del binario IDE:10PASS.
Press arma sin ejecutar, release coincidente ejecuta una vez, cruces de frontera
no ejecutan, doble rápido añade una acción, Esc sale. Initial9/1 usaba0.2s por
edge y produjo dos singles legítimos;0.01s por edge reproduce double, sin fix.
Q451 C87AppScreen9PASS: menu press oculta debugger, releasepareado no reabre,
nextkey restaura; F4 también, resume valores/sourceexact. Probe coordenadas
incompleto y tres fallos de expectativasunit se conservan, final55unitsPASS.
Q452 C87parentleft9PASS: Fileclick/outside, visibleeditor inserción/Undoexact,
closeglyphoculta, hidden click/typing ignora, File/reopen/F2originalexact.
Q453 C87wheelUndo12PASS: cruza viewport, primerUndoelimina typing sin entrada
wheel fantasma, Redo y dos ediciones separadas conservan límites/CRLFexactos.
Dos links HBIDE_IsNavKey son clasificación interna, no gestos adicionales ni
prueba de rendimiento/instrumentación. Q454 C87releaseunpaired8PASS: canvas,
title y closeglyph no cambian grilla ni controlsJSON, close release solo no
oculta inspector. DSN_TRACE vacío, no prueba de logging habilitado o drag.
Initialsyntaxerrorfixture retenido; ningún cambio producto en Q450-Q454.

Las27ramas sintácticas detectadas tienen contratos acotados, incluidos ignored,
trace-only y clasificadores. No es inventario exhaustivo de gestos, no cuenta
funciones completas y no cierra M0. Sigue pendiente cobertura de subrutas,
coordenadas, controles y estados, modelos completos, revisión visual, Windows,
instalación/licencias y repetición de matriz final. C87fuentee84d41e1d57f35aa1b42fe538b4ab11aa598f6fe,
bin a7f08d630682a8c13ac6ead900cead971c128fa5f974b23be2114d73191fca48 intacto.
Nuevos documentos/catálogo no están embebidos en C87; no build por docs.
Q455 consolida esta evidencia y catálogo34byteexact, sin nuevos píxeles,
fullmatrix o cierre. Cada receipt Q450-Q454 conserva alcance y fallos previos.

### Q457-Q462 (1 noviembre 2026): selección y corrección RadioGroup

Q457 C87wheel con palabra marcada: down extiende endpoint a segunda fila;
down/up contrae palabra, typing/Undo/Redo CRLFexactos, dosmodos9checksPASS.
Q458 añade UTF8host/terminal, café tras TAB, BOM/mixedEOL, dosmodos9PASS.
InitialCPR40;1 del harness anunciaba terminal sin avanceUTF8 y pintaba caf?;
CPR1;2 como suiteUTF8 existente corrige fixture, no producto. Logs retenidos.
Q459 actualF8key forward/reverse across short EOL: virtualcol11, typing elimina
frontera física sin padding; Undo/Redoexact,7PASS. Caracterización de comportamiento
existente, no cambio de política. No se siguen variantes wheel equivalentes.

Q460 sí reproduce defecto: Compiler Options caption y bullet MSVC no cambian GCC
en C87, checkboxes sí. HitGetAt RADIOGROUP buscaba borde nativo aunque Options
oculta ese box y pinta grupo titulado aparte. Fix usa hitTest positivo de item y
value públicos1based, evita inferir geometría o marcador desde píxeles. Incluye
primer item aunque nR-row-1 sea negativo. No cambia ListBox ni toolchain.
C88oficial nuevo, fuentee32c6ece0a8d461f04f7244eb451e378211c7f14,
bin e85c0951c2310b4c103188bafacc0852a9906fc3c7b6873f06276246d6ae0b38.
Ocho smokesfresh/About/ldd/docs34PASS; CompilerMouse9 vsbaselinefallo,
CompilerKeyboard14,Display9,generatedRadio9PASS. No hereda aceptación C87.
Native1202x762before/afterinspeccionados: mismoclickMSVCantesGCC/ahoraMSVC,
status/lowerborders completos. Initialvisualy294 seleccionó Borland en C88
(correcto para esacoordenada); recaptura y277 sobre MSVC, no defecto adicional.
Probe Helpmenubar y fallos previos quedan en receiptsQ460.

Para compilar sin mezclar copias independientes se usa gitarchive tar.gz con
archive_file/archive_format/hash en manifiesto, rebuild acepta formatolegacy
source.tar o nuevocomprimido y rechaza traversal/nombre desconocido/falta/tamper.
Nueve rebuildguards y cuatro preflightguardsPASS; no revisión de redistribución.
Q461 último MinGW64 a primeroGCC por mouse llega argvexacto:13checksPASS,
incluye9checks repetidosQ460 y4adicionales, no13featuresnuevas. Q462docs/catalog
posteriores no embebidosC88. Matrizcompleta/modelos/Windows/install/licencias,
políticas pendientes y cierreM0-M6 siguen abiertos.

### Q463-Q468 (1 noviembre 2026): regresiones frescas C88

Sobre C88fuentee32c6ece0a8d461f04f7244eb451e378211c7f14,
bin e85c0951c2310b4c103188bafacc0852a9906fc3c7b6873f06276246d6ae0b38,
sin heredar aceptación de C87: Q463 cinco modos navegación15checksPASS
(rawBOM/ENDCLASS/DECLARED METHOD/TEXTblock/arraycomment). Q464 trececontextos
TEXT compiler-valid y39PTYchecksPASS: FILEliteral/bare/expression/tab y
PRINTERabbrev4/5/6/continuations. No lexical141/modelos nuevos.
Q465 cinco modos SaveConflictPASS: SaveAllpartial/SaveAsfailedidentity/
refusalrecovery21checks/conflictCancel/conflictReload. Filenameplaneadoinexistente
se corrigió al listado failure_identity; no se omitió modo.
Q466 siete modos editor63checksPASS: continuationBS/Delete12+12, UTF8mouse17,
EnterblankBP LF/--crlf6+6, BackspaceblankBP LF/--crlf5+5. PTYcolors no píxeles.
Q467 cinco modos recoveryPASS: deepmixedEOL/deepBOMseparados, Compare read-only,
Undo/Reload retiranjournals y restart no ofreceobsoletos. Dos invocacionescleanup
omitieron binaryarg y fallaron antesIDE; corregidas/repetidasPASS, iniciales
retenidas y receiptintermedio544eb0e visible. No defectoproductoenestosruns.
Q468 consolida docs/catálogo34byteexact, posterioresnoembebidosC88. No matriz
completa/modelos/píxeles nuevos/Windows/install/licencias/cierre de hito.

### Q470-Q474 (1 noviembre 2026): campos mouse y regresiones C88

Q470 enlaza CompilerOptions mouse sólo campos probados y botones; guard nuevo
excluye Strict/AutoRunmouseclaims,56inventoryunitsPASS. Q471 Displaymouse6PASS:
Cancelpreserva40x120, third25x80/middle30x100/first40x120 caption+OK negocia
dimensiones exactas, dosdocumentosUndo/savebytesexactos. No píxeles nuevos.
Q472 freshC88M2fourmodes55PASS: promotionfailure9/retry15/missingoutputdiag17/
RunArgumentsmodal14. Compilerfixturecontrolado y escenario retryexplícito,
no promesa sinretry. Retainedoutput/path/backup/source/nooldlaunch y Scriptargv
exactos. Q473 freshC88designerfourmodes52PASS: mixed--actions23/GETvalidveto10/
ComboClipboard9/Inspector25x8010. Runtimehelpers checkoutaf9c552 idénticos a
candidatefuente; identidad separada de IDE. Initialnombrevalidruntimeincorrecto
falló antesIDE; listadoactualvalid_veto ejecutadoPASS, nota retenida.
C88 fuentee32c6ece0a8d461f04f7244eb451e378211c7f14,
bin e85c0951c2310b4c103188bafacc0852a9906fc3c7b6873f06276246d6ae0b38 intacto.
Q474 consolida docs/catálogo34byteexact posteriores noembebidosC88; sin build
por docs. No modelos nuevos/fullmatrix/Windows/install/licencia/cierre M0-M6.


### Q517-Q519 (2 noviembre 2026): M4 y HelpExport frescos C95

Q517 cuatro modos M4, 52 checks PASS: mixed actions23/GET VALID veto10/
ComboClipboard9/Inspector25x80 close10. Runtime helpers separados del IDE;
cuatro fuentes coinciden byte a byte con el candidato, no todos los controles.
Q518 hipotesis FIFO en ReadFileChecked no confirmada: Open/Project rechazan
FIFO antes del reader. Dos probes esperaban otra alerta y fallaron por esa
expectativa; logs retenidos. No bloqueo demostrado, defecto ni parche nuevo.
Se detienen variantes equivalentes. Q519 cinco modos HelpExport, 20 checks PASS:
symlink3/regular5/directory4/FIFO4/dangling4. Alias y destinos conservados;
regular overwrite y mode preservados. Sin garantia concurrente TOCTOU de
alias/parent directory. Cada receipt identifica fuente/binario y logs propios.
C95 source1cdedd93da118bcdb33866d574943a784a00c0f6,
bin112573c77e3fe18c930a8bc76404027d0472d5a42aa06c1ed25a2ab2d23dd845 intacto.
Docs posteriores no embebidos en C95; sin build por docs ni retiradas nuevas.
No nuevos pixeles/fullmatrix/models/Windows/install/license/cierre de hitos.

Q534toolinginitial: guardnonclient añade rama interna31 frente30esperadas;
dos inventoryunits fallaron. Enlace acotado nuevo30/31, no feature nueva ni
DBLinstrumentado. Denominador actualizado y repeticion completa registrada.

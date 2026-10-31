# Registro de cierre hbide

## 29 octubre 2026: baseline y roadmap

Base: `f91fa208b0f736d230e865da53a4a441fcfc525a`, Linux x86_64,
GCC 11.4.0. Harbour core `694428e1c12f726675b19324d62167fa77d68185`,
compilado localmente. Sin reutilizar `tests/hbide` ni `hbide.exe` incluidos.
`hbmk2 hbide.hbp -quiet`: exit 0.
SHA256 del IDE base reconstruido:
`e52c87becdea39c4cd899e34170138f7173de367df7464a2c2af9a6ad7a8f52f`.

| Prueba | Resultado nuevo | Alcance |
| --- | --- | --- |
| test_designer | 409 PASS / 0 FAIL | Modelo/GUI simulada GTSTD; no gestos reales Windows |
| test_atomic | 37 PASS | Helpers de escritura/promocion; no certificacion de fallo electrico |
| test_recovery | 46 PASS / 0 FAIL | Modelo de journals; no reemplaza kill/restart interactivo |
| test_project | exit 0 | Build HBP y fallos; no visual |
| test_nav_pty.py | 35/35 PASS | Linux PTY sobre IDE base reconstruido |
| test_debug_animate_pty.py | PASS | Termina sum=6 y vuelve al IDE; NO acredita ausencia de tearing |
| test_debug_layout | PASS 324 casos geometricos + runtime | Tile/Zoom/restore/move/cancel/size/cascade/iconize/grow/shrink; GTSTD, no cierre visual |

Runner nuevo: `scripts/completion_baseline.py`. Compila y ejecuta de nuevo
cinco probes (designer, atomic, recovery, project, help), aisla resultados,
registra fuente y si hay cambios sin commit, y falla ante timeout/error. No
pretende ser suite completa. Pasada inicial con correccion de ayuda local:
5 builds y 5 ejecuciones exit 0. Todas las salidas se guardan fuera del checkout.

### Correccion comprobable

La ayuda y la nota de ventanas seguian diciendo que Iconize no existia.
La fuente ya lo implementaba (`533d993`) y el menu lo invocaba. Se actualiza
el texto sin alterar el comportamiento. Prueba layout confirma restauracion
de geometria y que el browser nunca se redimensiona al alto de icono.
`test_help` recompilado con texto corregido: exit 0, incluye integridad de
palabras y anchura de panel en todos los temas. Revision del roadmap mediante
render HTML local: titulo, diagrama y tablas legibles; no captura del IDE ni
prueba visual de la ayuda integrada.

### Pendiente tras este lote

- Completar inventario y matriz, no asumir cobertura por los checks anteriores.
- Pasada visual real del IDE/ayuda; Animate sigue abierto.
- Exchange Screens, swap on Input y Menu Bar llaman NotSupported.
- Windows fuente actual y binario final sin validar. No hay entorno Wine
  heredado; el bloqueo historico no se atribuye al usuario.
- Decisiones paleta F2 y Menu Bar preservadas, sin comportamiento inventado.
- No cambio en master ni reemplazo del EXE Windows con build no comprobada.

## Segundo checkpoint: inventario y comprobacion de Iconize

Sobre `725431774041179d5aa5f7daf4e32c6ec31f52d9`, rebuild IDE exit 0.
`test_debug_commands_pty.py`: 18 PASS / 0 FAIL, incluidos Iconize desde menu,
restauracion del contenido y preservacion del viewport lejos de la primera
linea. No se ha inferido esto solo por ver la implementacion.

La ayuda corregida se abrio en GTTRM120x40 con harness directo a
`HBIDEHelpBrowser`. Captura real inspeccionada: texto completo de Iconize,
marcos, botones y borde inferior visibles. No es prueba del ciclo completo
IDE->menu->ayuda ni una validacion Windows.

`scripts/audit_completion_surface.py` genera el inventario de menu principal,
debugger y paleta del diseñador, mas condiciones de dispatch de comandos,
teclas del diseñador y escritorio de proyecto. Resultado inicial:115acciones
de menu,148rutas de dispatch,3stubs. `--check-stubs` devuelve exit1 esperado:
la puerta de cierre falla mientras haya opciones visibles sin implementar.
`wired` NO equivale a probado, ni cada ruta a una funcion distinta. Aun faltan
inspector, modales, barra de ayuda y atajos globales; M0 sigue abierto.

Intento visual Animate con salida de app: cuatro capturas separadas y parada
Alt+D no mostraron mezcla persistente en esos instantes. NO descarta flashes
entre frames, no resuelve tearing y no cierra Q04. Hace falta grabacion continua
y oraculo que distinga pantalla de app de pantalla del debugger.

## Tercer checkpoint: fallo real en comandos de geometria

Reproduccion sobre fuente `0b48cb7` sin modificar el debugger:
prueba layout nueva `WINDOW MOVE -99 -99` -> FAIL numeric move negative clamps,
exit1. Las rutas numericas no usaban los limites que si aplicaban las flechas.

Correccion Harbour: `WindowCommandRect` valida dos enteros, rechaza parametros
malformados/tamanos no utilizables sin alterar geometria, limita posicion y
tamano al escritorio sin cubrir menu/status, restaura una ventana iconizada
antes de aplicar un tamano valido. Limpiar zoom evita restauracion obsoleta.

Pruebas posteriores sobre el parche local:
- Build IDE exit0.
- Layout:324casos geometricos mas runtime anterior y nuevos casos numericos:
  negativos, extremos, tamano enorme, validos, seis malformados, signo positivo
  e invalidacion/restauracion iconizada. PASS.
- PTY comandos ampliada:22PASS/0FAIL. Incluye comando numerico real, error
  legible y retorno al IDE sin inutilizar Command.
- Capturas terminal real: ventana limitada al extremo inferior/derecho con
  menu/status intactos; error de tamano malformado visible, geometria intacta.
  Inspeccionadas completas, no Windows.
- PTY functions58/58 y session23/23 pasan sobre el build anterior7254317;
  no se afirman repetidas despues del parche de geometria.

El inventario amplia rutas a inspector/edicion, bucle principal y ayuda.
Sigue siendo conexion estatica; faltan modales/campos, editor y gestos.

El runner tambien detecta fallo textual del probe atomic, cuyo codigo legacy
no cambia el exitcode al fallar. Las cinco suites reconstruidas tras el
parche de geometria y la ampliacion de ayuda pasan de nuevo. SHA256 IDE local:
`31fbac8769e6fd9deae597951d83349f670fe125426d6711f1542b17d30944f7`.
No se distribuye como binario Windows. Inventario ampliado:223rutas y23campos
de inspector detectados, sin certificar que sean independientes ni completos.

## Cuarto checkpoint: decisiones aprobadas y aplicadas

El 29Oct21:24 el propietario aprobo las dos propuestas presentadas:
letras duplicadas de paletaF2 ciclan y Enter ejecuta; barra debugger ocultable
recuperable con Alt+O,M, visible por defecto. F10 sigue siendo Trace.

Cambios Harbour:
- HbMenu: detectar todas las coincidencias del mnemonic en popup. Si hay
  varias, avanzar/ciclar resaltado sin ejecutar. Unica sigue inmediata.
  Flechas/Enter/Esc conservan su funcion.
- Debugger: MenuBar con check real; ocultar no redimensiona paneles ni ocupa
  fila0. Alt+letra abre temporalmente barra y popup; Esc la vuelve a ocultar.
  Alt+O,M la restaura de forma persistente. `Options MenuBar ON/OFF` explicito
  es idempotente y se guarda/restaura en CLD.

Evidencia Linux sobre parche local basado en488d754:
- Disenador:414/414 (cinco regresiones nuevas ciclo/wrap/Enter/Esc/unica).
- PTY diseñador:18/18, incluidos duplicados sin cerrar paleta y flujo
  JSON->F12->generar->abrir editor.
- PTY comandos:28/28, incluidos ocultar, Alt+O temporal, Esc, Alt+O,M y
  Save->cambiar->Restore del estado oculto. La restauracion tambien cambia
  fichero/foco del browser; el arnes vuelve a abrir su fixture antes de
  comprobar geometria, sin confundir ese cambio esperado con fallo producto.
- Layout:324casos geometricos y runtime, mas MenuBar/check/row0/comandos.
- Cinco probes recompilados pasan; build IDE exit0.
- Capturas completas reales inspeccionadas: Paste resaltado tras dosP y
  paleta aun abierta; barra oculta, Options temporal y barra recuperada.

Quedan DOS stubs visibles: Exchange Screens y swap on Input. No se ha
implementado un toggle sin efecto. Referencia de semantica leida:
https://www.fivetechsoft.com/harbour/src/debug/en.txt . MenuBar deja de ser
bloqueo de decision; Windows y tearingAnimate siguen pendientes.

Tras488d754 y antes de este parche: Monitor10/10, callstack y codeblockPASS.
Grabacion Animate30fps/10s sobre salida de app, muestras visuales sin mezcla
persistente; no es prueba de todas las velocidades ni cierre de tearing.

## Quinto checkpoint: Delete no es Ctrl+G

Una regresion ampliada encontro un fallo real anterior: Delete con seleccion
abria Go to Function en lugar de borrar. Harbour normaliza ambas teclas al
codigo clasico7. El bucle principal ahora conserva HB_KX_DEL para no consumir
Delete como atajo de navegacion. No se cambian las reglas de breakpoints.

Antes del parche:2fallos en seleccion/breakpoint, dialogo inesperado visible.
Despues: politica de borrado13/13PASS (incluida nueva comprobacion de ausencia
del dialogo), navegacion35/35PASS con Ctrl+G real, filtro, Enter/Esc, mensajes,
argumentos y SaveAll. Linux, build local basado en98d38bb.

Ampliacion sobre98d38bb sin este parche: SaveAll fallo5/5 y SaveAs negativa
con cierre forzado/recuperacion21/21PASS. Functions58/58PASS tambien repetida
sobre98d38bb: su espera minima fija supera108s, no confundir timeout100s del
runner anterior con fallo del producto. No se han repetido todas las suites
sobre el cambio de Delete ni se declara cerradoM1 o certificadoWindows.

## Sexto checkpoint: transaccion de repintado del debugger

La fuenteHarbour GT base confirma que HB_GTI_SETWIN hace flush inmediato
si DispCount es0. Activate restauraba el snapshot previo antes de actualizar
source, watches y paneles. Se agrupan restauracion y repintado en una sola
transaccion Harbour; ALWAYS garantiza liberar la transaccion al salir. Show
no es ya propietario implicito de SaveAppScreen. Scripts de settings se
cargan fuera de la transaccion: pueden pedir entrada o ejecutar comandos.

Sobre parche local basado en8d8063a: functions58/58PASS, startupON/OFF PASS.
Animate ahora comprueba tambien DispBegin anidado de app:2 durante,0 al
terminar; suma6 y retornoIDE PASS. Exitpaths16/16 y comandos28/28 pasan
sobre la version anterior del mismo parche (antes de ampliar ALWAYS/settings),
no se atribuyen como repetidos al parche final.

CapturaGTTRM real30fps10s con salidaapp y speed3; pantalla completa durante
Animate y parada revisadas, bordes/status intactos. Es una correccion del orden
de publicacion del buffer, no evidencia de ausencia de todo tearing: faltan
oraculo de transitorios, otras velocidades y Windows. Dos stubs siguen abiertos.

## Septimo checkpoint: ejecucionPTY reproducible

Nuevo runner `scripts/completion_pty.py`: lista21suites, compila IDE por
defecto, registra revision, cambios locales, hashIDE/test/runner, salida,
tiempo y log por suite en JSONL. `--case` permite lotes; `--reuse-build` es
explicito. Detecta FAIL impreso aunque exit sea0. Timeout no se etiqueta
como fallo producto; mata descendientes y para para inspeccion. No hereda
pruebas entre revisiones ni afirma cobertura visual/Windows. Doce arneses
que fijaban /home/sandbox/hbide/hbide ahora usan ruta relativa o HBIDE_BIN.

Ampliacion sobre31e0d75: multidoc37/37, project-messages18/18,
project-desktop21/21, exitpaths16/16PASS; recovery-multi, retention,
deep-path y route-guard PASS. Project-desktop y exitpaths ejecutados con
cambios de rutas de arnes locales, sin cambiar codigo del producto.

## Octavo checkpoint: inventario con contratos, sin falsosPASS

`tests/completion_acceptance.json` vincula17acciones a contratos y pruebas
concretas. El generador valida IDs/ficheros y muestra las23propiedades de
inspector detectadas, aun pendientes de prueba individual. Rutas editor ya
incluidas:316rutas de dispatch en total, no funciones independientes.
Enlace a prueba no equivale a ejecucion: resultado sigue exigiendo ledger
con revision/hash exactos. Las98acciones restantes no reciben cobertura
por proximidad; dos siguen como stub. No se afirma inventario exhaustivo.

## Noveno checkpoint: UTF-8 valida valores escalares

Nueva prueba reprodujo6fallos reales del helper: aceptaba overlongs de3/4
bytes, surrogates y valores por encima deU+10FFFF. No se afirma perdida de
datos observada: se demuestra clasificacion erronea en el guard de guardado
raw. Se restringe segundo byte de E0/ED/F0/F4 conforme a Unicode17 tabla3-7:
https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-3/

Antes:16/22PASS. Despues:22/22clasificacionesPASS, con limites validos a
ambos lados y no-caracterU+FFFF permitido. Otras12pruebas de SaveFile raw
rechazan cada entrada invalida, conservan original exacto y dirty:34/34PASS.
Runner modelos incorpora la suite: seis modelos recompiladosPASS sobre
parche local de1fcfe87. Sin cambio visual ni certificacionWindows.

## Decimo checkpoint: CRLF uniforme no se convierte a LF

Reproducido enLinux: abrir/guardar sin editarCRLF cambiaba todos los saltos
porLF por heredar HBEditor:GetText(hb_eol). CRLF/LF antes1PASS/1FAIL.
HBSrcEdit detecta terminador uniforme al cargar texto/fichero y lo conserva
al serializar. Diario usaGetText y recuperacionLoadText, asi conserva tambien
el formato sin metadata paralela. Nueva linea usa ese terminador uniforme.
No se cambia la politica de ficheros mixtos ni se afirma preservarlos.

Prueba4/4PASS: CRLF/LF load-save byte exacto; Enter, undo, redo y recarga de
contenido de diario retienen terminadores. CasoEnter fija insert igual que
IDE (sin elloOverwrite de HBEditor tiene otra semantica). Siete modelos
recompiladosPASS; SaveAsrecuperacion21/21 y SaveAllfallo5/5PASS sobre parche
local de c73337a. Sin cambio visual. Windows nativo pendiente.

## CRLF: comprobacion de cierre forzado real

El arnesdeep-path ahora verifica que el diario equivale a original+edicion,
no solo que el guardado equivale a un diario que ya pudo perder formato.
CasoCRLF nuevo enrunnerPTY. Sobreproducto db61c34: LF yCRLF reales pasan
abrir→editar→diario→SIGKILL→reiniciar→recuperar→guardar byte exacto. No es
solo simulacionLoadText. Regresiones limpiasdb61: recoverymulti/retention/
deeppath, BPdelete yAnimatePASS, ledgerconhash estable.

## Undecimo checkpoint: F3 no salta coincidencias

FindNext incrementaba columna y FindText volvia a empezar despues de ella:
se saltaban matches adyacentes. Wrap tampoco incluia la linea actual.
Nueva reproduccion6casos:4PASS/2FAIL. Se elimina incremento duplicado y se
completa wrap. Suite ampliada12/12PASS: adyacentes, solapadas, multilinea,
case-insensitive, unica coincidencia y miss sin mover cursor.

Ocho modelos recompiladosPASS antes de ampliar6casos extra de busqueda;
la suite ampliada12/12 y navegacionPTY35/35PASS sobre parche deeff5d10.
Capturas reales completas inspeccionadas: tercera a deaaaa trasF3, luego
primera al envolver; statuscol3/col1 y bordes inferiores intactos.
Debuggerfunctions58/58 tambien repetida sobreeff5d10 limpio antes del parche.

## Duodecimo checkpoint: encoding recuperado, no solo texto

FlujoPTY real UTF8+BOM yé reprodujo corrupcion de formato al recuperar:
original convierte aCP437 para editar; diario guardaba bytes editor sin
flags; despues deSIGKILL→Recover→Save saliaCP437 sinBOM. Dos checks fallaban.
No se recupera encoding desde disco, que puede cambiar tras el cierre.

Journal nuevo para encoding especial usa sobre versionado: flagsUTF8/BOM/raw,
codepage y texto en UN solo fichero atomico. No sidecar separable por crash.
Diarios legacy siguen byte exactos sin metadata inventada. Recuperar restaura
flags y convierte codepage solo con roundtrip lossless; si no cabe conserva
journal y explica como reabrir. Buffers legacy limpian flags previos.

Sobre parche53df776: UTF8+BOM→editar→diario→kill→recuperar→guardar byteexacto
PASS; LF/CRLF, multi,retention,routeguard ySaveAsrecuperacionPASS. Ocho modelos
PASS, recovery53checks incluye envelope atomico/read legacy/rewrite legacy.
Sin certificadoWindows. Encodingraw/cambio de codepage aun necesitanPTY
especifica; no se afirma toda conversion cubierta.

## Encoding: ampliacionPTYraw y codepage

Sobreproducto ff49ba3: UTF8raw con euro fuera deCP437 abre con aviso,
se edita sin cortar la secuencia, kill/recovery/save retiene bytes exactos.
Otro caso parte deUTF8+BOM editado enCP437 y recupera conHBIDE_UTF8=1:
conversion lossless y fichero final exactosPASS. Test/runner ampliados;
no se confunde esta direccion lossless con probar rechazo inverso.

## Encoding: rechazo lossless inverso probado

UTF8editor con€→kill→reiniciarCP437: recuperar avisa que requiere codepage
original, no reemplaza buffer con conversionlossy. Diario de la misma
version y fichero original siguen byte exactos, IDE usable. PTY PASS sobre
producto12cd4d3. Esto cubre tambien la salida segura, no solo conversionOK.

## UTF8host: detectar encoding sin depender del codepage

Otro casoPTY descubrioUTF8sinBOM abierto bajoHBIDE_UTF8=1, kill y recuperado
bajoCP437: flags originales quedabanfalse y guardabaCP437. Deteccion anterior
comparaba hb_StrToUTF8 con original, siempre iguales bajoUTF8host. Se valida
secuencia y presencia de bytesmultibyte, independiente del codepage.

Antes dos checks de bytes finales fallaban. Despues flujo realUTF8host→CP437
PASS, juntoBOM/conversionlossless/rechazolossy. SuiteUTF8 ahora78/78:22validacion,
44deteccionEN/UTF8 y12guardadosraw. Ocho modelos recompiladosPASS. Producto
basado en1a8f2f8; no se afirma encoding arbitrario niWindows.

## Consolidacion de regresion sin cierre global

Se incorpora test_editor_repaint al runner modelos:31checks de hotpath,
undo, UTF8, BP y resaltado. Nueve modelos localesPASS. Roadmap mantiene
terminadores mixtos como fallo abierto y los arreglos recientes separados
de su evidencia, sin sustituir baseline inicial por certificacion actual.
Sobreproducto3443a46: comandos28/session23/startupON-OFFPTYPASS; cambios
locales solo docs/runner, binario verificado estable.

Animate: regiones grandes analizadas en todos180frames de cada video30fps
speed1/8 y otros180speed0 grabado antes de activarlo. No mezcla global
app/debugger detectada; speed0 original ya empezaba eneditor y se descarto.
No hay oraculo de texto/celdas ni de transitoriosmenoresde33ms; no cierra
tearing. CapturasF4 app/retorno completas siguen limpias.


## Terminadores mixtos por linea, no normalizacion global

El editor conserva ahora el terminador de cada linea en un objeto Harbour.
Split hereda la frontera local; join conserva la del fragmento final;
fronteras nuevas al EOF usan el primer terminador del documento. Las ops
undo guardan texto y frontera juntos, tambien en cut/paste/duplicate/replace.
El diario usa GetText con esos bytes, sin una segunda tabla desincronizable.

36checks: mezclas CRLF/LF/CR, EOF sin terminador, vacios, split/join,
cut/paste/duplicate/replace y undo/redo. Nueve modelos Linux PASS.
IDE real: editar, SIGKILL, recuperar y guardar mixtos byteexacto PASS;
CRLF, Delete/BP13, navegacion35, SaveAllfallo5 PASS sobre candidato.
Captura completa tras recuperacion y guardado inspeccionada, sin bordes
cortados. No demuestra terminadores por pixeles: el oraculo son los bytes.
No certifica Windows, todos los caminos word-wrap heredados ni el IDE entero.
RunnerPTY suma recovery-mixed-eol con revision/hash del candidato por caso.


## Undo de lineas soft-wrap

Prueba adicional encontro que redo reconstruia fragmentos soft-wrap como
lineas fisicas. La operacion undo incluye ahora su estado soft/hard, ademas
de texto y terminador. Antes40checks con1fallo; despues41/41, incluidos
load/edit/undo/redo soft-wrap y reflow conservando fronteras fisicas.
No se afirma cierre del cursor durante reflow ni de todos los caminos wrap.
Nueve modelos recompiladosPASS antes de publicar.


## Cursor durante reflow y gutter

Insertar12Z al inicio de un parrafo ancho10 producia caracteres repartidos
entre palabras. ReFormParagraph heredado usa columnas de texto; HBSrcEdit
le pasaba columna con gutter+4. Adaptacion Harbour traduce ambas direcciones
y conserva frontera fisica del parrafo. Pruebas inicio/interior/fragmento
siguiente y undo/redo: antes42/46, despues46/46. Nueve modelosPASS.
Captura del probe visual reflow inspeccionada completa; no es una nueva
opcion de word-wrap ni certificacion de todas sus acciones heredadas.


## Baseline candidato completo del runner Linux

Sobrec313ae8 limpio se ejecutaron los28casos registrados del runnerPTY,
sin fallos impresos, exits nozero ni cambios de fuente/binario. SHA256
b223675c3f4495a30ee39d17d6d3a58e67c70d149c79f65e1cf3857be6418e27.
Hashes porcaso en docs/evidence/linux-pty-c313ae8.json. Nueve modelos
recompiladosPASS sobre esa revision. No hereda exitos de otras revisiones.

Este baseline completa el runner existente, no el inventario entero:
Exchange/swapInput, revision visual exhaustiva, oraculo tearing y Windows
nativo siguen pendientes. AnimatePTY solo acredita avance funcional.


## Tabs y lineas fisicas sin conversion silenciosa

Reproduccion: hb_MLEval repetia el byte TAB al cargar (TABinicial se
convertia en4TAB). El editor sin word-wrap usa ahora lineas fisicas crudas,
conservando tambien una linea de70000caracteres como una sola linea fuente.
Solo la pintura expande tabs a paradas de4columnas; cursor, seleccion,
raton y scroll traducen entre posicion de caracter y pantalla. Experimento
de marcador flecha1celda descartado, no forma parte del producto.

59checks EOL/editorPASS y nueve modelosPASS. Prueba anterior de fidelidad
TAB fallaba; ahora pasa. IDEreal editar→kill→recuperar→guardar con TAB y
CRLF/LF/CR conserva bytes exactos, navegacion35PASS. Captura IDEcompleta
inspeccionada tras recuperar/guardar: indentacion4columnas, bordes completos.
Word-wrap heredado con TAB sigue fuera de este arreglo y pendiente.
El baseline28PTYpublicado corresponde ac313ae8, no a este producto nuevo.


## Tecla TAB sobre archivos con TAB preservados

La tecla TAB seguia calculando espacios por indice de caracter, no columna
visual. Despues de unTABexistente insertaba3espacios en vez de4. Calculo
por VisualCol tanto en deteccion hotpath como insercion; pruebas visual5 y
visual7, undo y redo.63checks editor y nueve modelosPASS. No afecta al
contrato de insertar espacios con la teclaTAB ni cierra word-wrapconTAB.

## Scroll izquierdo sobre TAB

Prueba de50pasos izquierda desde linea con50TAB detecto32posiciones de
cursor dentro del gutter/fuera de viewport. GoTo ajusta ahora tambien
origen visual a la izquierda, no solo a la derecha.113checks editorPASS
(50son pasos del mismo contrato, no50funciones), nueve modelosPASS.

## Clipping derecho del texto coloreado

Captura real tras scrollTABmostro token sobrescribiendo borde derecho.
El pintor limitaba largo por anchura del editor, sin restar inicio del
token. Se limita a nRight-nCol+1. Probe SaveScreen con celda centinela
fuera del editor: antes falla, despues114/114checksPASS. Captura corregida
inspeccionada completa, borde limpio. Nueve modelosPASS.


## Word-wrap con TAB sin repetir bytes

Se reproduce perdida tambien con word-wrap activado. Splitter Harbour por
columnas conserva cada byte y distingue fragmentos suaves de fronteras
fisicas. Reflow conserva cursor por offset de caracter, no por expansion
destructiva.120checks editorPASS: TABsimple/consecutivos,12inserciones,
undo/redo, UTF8+TAB. Nueve modelosPASS; probe visual wrap inspeccionado.
No equivale a todas las acciones heredadas del editor ni a Windows.

## Highlight de seleccion recortado al viewport

Dobleclick sobre palabra larga podia sobrescribir fuera del editor aunque
el pintor de tokens ya estaba corregido. Palabra/rango usan interseccion
visible, incluyendo seleccion que empieza a la izquierda del viewport.
Celda centinela: antes121PASS1FAIL; despues122PASS. Nueve modelosPASS.
Captura IDEreal con palabra160caracteres seleccionada inspeccionada:
highlight termina antes del borde derecho y segunda linea sigue limpia.

## Trazabilidad tambien en modelos

Runner modelos guarda hash de cada fuente/test/binario y del runner,
cambios tracked, revision y segundos porcaso. Detecta cambios de fuente o
test mientras ejecuta y falla en vez de atribuir resultado ambiguo a HEAD.
Nueve modelos recompiladosPASS con campos nuevos. Sin cambio de producto.

## Contratos de editor y documentos vinculados

Se vinculan13entradas mas a pruebas ya existentes e inspeccionadas:
New/Open/Save/SaveAs, undo/redo, cut/paste/delete/duplicate/replace y
cambio de documento. Se distingue prueba de modelo frente a despacho
real del menu/modal; no se presenta una como la otra.32de115acciones con
contrato vinculado, no porcentaje ni cobertura total. Inventario regenerado
con lineas de fuente actuales. Gate de stubs sigue fallando como debe:2.

## Seleccion sobre soft-wrap sin saltos inventados

SelectionText insertaba newline entre fragmentos visuales de una misma
linea fisica. Ahora solo separa fronteras fisicas; el clipboard sigue
usando hb_eol para lineas reales. SelDelete hereda estado soft/hard del
fragmento final, igual que su terminador.126checks editorPASS, incluidos
seleccion/cut/undo/redo sobre wrap; nueve modelosPASS. No certifica todas
las operaciones de clipboard ni sus modales.

## GoTo respeta gutter y final de fragmento suave

Delete al final de fragmentosoft borraba caracter en vez de unir: GoTo
heredado limitaba columna a ancho+1 sin gutter4. El origen/cursor se
actualiza ahora con coordenadas fuente y se limita por longitud real del
fragmento, no por anchura visual sin gutter.132checks editor y nueve
modelosPASS. PTY navegacion35/recuperacionTAB/multidocPASS sobre candidato.
Primer lote multidoc interrumpido por limiteexterno120s, repetido solo yPASS;
no se atribuye exito al intento interrumpido. Captura seleccion larga
repetida e inspeccionada con marco intacto. Sin certificacion global.

## Menu Edit real, no solo modelo

NuevoPTY ejecuta Undo/Redo/Duplicate/Delete/Copy/Paste/Cut y Replace modal
por sus menus reales y guarda tras cada paso.13checks byteexactos sobre
archivo CRLF/LFconTAB, incluido undo de Replace. Primer intento tenia dos
expectativas equivocadas de cursor tras Delete: copiaba realmente beta,
no alpha. Se corrigio fixture navegando explicitamente al objetivo; no se
modifico producto para satisfacer una expectativa errada.

Runner suma edit-menu (30casos); contratos33/115, con limites porcontrato.
Este commit no cambia producto. Gate2stubs y Windows siguen abiertos.

## Find/Goto/Replace: modales reales y cancelacion

EditmenuPTY ampliado22checks: Find real navega beta en linea2 conTAB,
Goto real llega linea3, Esc conserva fila/datos en Find/Goto/Replace.
Replace conserva espacios finales y undo restaura bytes exactos. No se
ha cambiado producto. Contratos34de115, sin convertir conteo en avance
porcentual. Inputs invalidos Goto todavia no cubiertos por este contrato.

## Extremos reales Goto y Replace

EditmenuPTY29checks: Goto0/negativo limita primera linea, valor999999 a
ultima. Replace vacio borra solo coincidencias y Undoexacto; texto ausente
reporta0 y conserva bytes. Sin cambio de producto; contrato ampliado,
no se elimina requisito. LinuxPTY, no validacion visual de cada modal.

## 29Oct23:54 ComboBox faltante

- Tipo propio `combobox`, paletaF2 (M), propiedades/inspector, items/variable numerica, ancho/alto del desplegable, eventos, JSON, undo/resize y generacion nativa `LISTBOX ... DROPDOWN`. No es campo editable libre.
- Reserva altura de popup en geometria para no generar fuera del dialogo, minimo4. El runtime exige8pares de color (ListBox normal7); probado el artefacto generado para impedir falso positivo de compilacion.
- Mouse usa hitTest nativo para desplegable cerrado/abierto; seleccion se sincroniza con GET, sin heuristica de bordes de listbox normal.
- Candidato: nueve suites modelosPASS; diseñador426checks, diseñadorPTY18 yComboBoxPTY25. ComboBoxPTY generaPRG, compila/ejecuta, prueba Espacio/flecha/Tab y clic abrir/seleccionar, guarda variable3. Repetir limpio antes de atribuir a commit.
- Capturas UIreal: paleta/properties completas, runtime desplegado conItem2 seleccionado inspeccionado. No certificaWindows ni variantes de input editable. Tree/Tabs/Grid siguen propuestas sin aprobar implementacion.

### ComboBox seguimiento: limites coherentes
- Inspector respeta minimoHeight4 como propiedades/JSON/resize; PTY27 comprueba reduccion repetida y restauracion7.
- Aviso de barra oculta tiene en cuenta fila superior adicional delComboBox: altura7 minima para scrollbar visible,6paraListBox. Modelo añade2checks.
- Correccion contable: ec13c5b tuvo427checks diseñador, no426 anotados durante preparacion. Este ajuste tiene429.

## 30Oct00:02 Inventario tras ComboBox
- Enlazados contratos específicos de ListBox/ComboBox y persistencia/generación a las pruebas reales existentes, sin atribuir cobertura a otros controles.
- Añadido expected_label obligatorio por contrato. Insertar un menu antes de otro cambiaIDs ordinales: ahora auditoría falla si ID y etiqueta dejan de corresponder, evita aceptación silenciosamente aplicada a otra acción.
- Inventario regenerado116acciones,40contratos enlazados. No porcentaje de terminado. Gate sigue fallando por2stubs.
- Regresión producto fa94083: menús/modalesEdit29PASS y navegación35PASS, mismoSHA binario en ledger /tmp/hbide-regression-fa94083/results.jsonl. No pasada global.

## 30Oct00:04 Roundtrip GUI automatizado
- Nuevofixture generaPRGs reales RadioGroup/ListBox/ComboBox/CheckBox/Input masOK; se compilan y ejecutan enPTY, se comprueban valores finales enarchivo.
-21checksPASS candidato: teclado/raton, ListBox/ComboBox8items con scroll y seleccionSixth tras llegarEighth; ComboBox toma foco desdeotroGET y abre. No simula resultados ni sustituye revisionpixel/Windows.
- Runner32casos,44contratos enlazados de116acciones, no porcentaje. ManualRoundtrip aclara que ya existe automatizacion, conserva procedimiento visual.

## 30Oct00:19 Baseline Linux actual coherente
-32/32suitesPTY,32unicas, sin fuente/binario cambiados durante ejecucion, todos arbol limpio dfd8d27dcba70157a47966dd89f1e28029c8720b. BinarioSHA2566c2829febc3a2aea230b475e375ddc72484bbc1f185dc13ec21b9c08f49b8f3d.
- Fuenteproducto siguefa94083; dfd8d27 añadeaceptacion/documentacion. Nueve modelos limpiosPASS.
- Ledgercommitted docs/evidence/linux-pty-dfd8d27.json conserva fechas, hashesrunner/test/binario, tiempos y tailslogs. Registro original /tmp/hbide-pty-dfd8d27/results.jsonl.
- Sustituye baseline28c313ae8 para la suite registrada. No equivale inventarioexhaustivo,100%IDE,revisionpixel completa niWindows. AnimatePASS es funcional,2stubs siguenpendientes.

## 30Oct00:25 Run/Debug sin modificar fuente
- ReproduccionPTY: reemplazo global Main->__Main cambiaba literal"Main Maintenance" antesdecompilar.4FAILenproducto anterior.
- EliminadoStrTran enScript/Debug; HB_HRB_BIND_FORCELOCAL aislaMain y simbolosHRBsin cambiar texto fuente. Scriptadopta aislamiento queDebugyausaba.
-8checksPTY limpio126aa30PASS: main()minuscula, dosrunsScript+dosDebug, salidaexacta y editorusable. Nueve modelosPASS. Debugsession/startup limpiosPASS; commands/functionsPASS candidato mismo producto. Tests muestranMainoriginal ahora.
- Baseline32dfd8d27 es anterior, no heredada. Nuevo runner33casos; Windows pendiente.

## 30Oct00:33 Start con paths literales
- Reproduccion: Startfallaba con carpeta que contieneespacios,2FAIL. Buildahorausa hb_processRun argv sin shell, captura stdout/stderr enmemoria; autoruncitaejecutable. Rechazaargsmalformados antesdebuild.
-6checksPTY candidatoPASS: dosbuild/run bajo pathconespacios/apostrofe/$HOME/puntoycoma; buildfallidoinforma,preserva binarioanteriorbyteexacto y noejecutaobsoleto. Nueve modelos y navegacion35PASS candidato.
- Runner34casos. Windows no validado, proceso build sigue sincronico/no cancelable. Baseline32anteriornoheredada.

## 30Oct00:38 Script compile error lifecycle
- CompilerAPI .T. reporta errores medianteErrorBlock: antes escapaban alhandlergeneral y diálogoStack, dejando menú/editor corruptos trascerrar.
- Captura localCOMPILER enScript, restaura ErrorBlock antesdemensaje breve conDescription/Operation(linea), repinta después. Runtime behavior sin cambio.
-9checks candidato: dosruns literales, errorruntime/dismiss, runválido trasruntime, compileerror/dismiss/editorusable, runválido trascompile. Nueve modelosPASS; runner35casos. Windows pendiente.

## 30Oct00:41 Script/Debug source include directory
- Fuenteenotra carpeta incluia local.chqueexistejuntoalfichero: Script/DebugcompilabanenCWDysinrutaorigen,4FAILPTY.
- Ambos compiladores añaden -Ideldirectoriodelsource, o.pardefecto. Sin cambiarCWDniidentificadores.
-8checksLinuxPTY candidatoPASS conheaderlocal/macro,literaloriginal y dosrunsScript/Debug enpathconespacios. Windowspendiente. Runner36casos.

## 30Oct00:44 Standard header discovery
- Alañadirinkey.chalfixturelocal,Script/Debugfallaban4checks:ScriptusabarutafijaWindows,Debugnoañadiastandardheaders.
- HBIDECompilerIncludehonraHB_INC_INSTALL/HB_INCLUDEvalidos,despuesencuentrainstalacionhbmk2delPATHcomprobandoinkey/hbclass/std, sinrutasprivadascodificadas.
-8checksIncludePTYcandidatoPASS conheaderlocal+estandar ymacro. ModeloProjectpruebaPATH,overrideexplicito yfallbackoverrideinvalido. NoactualizaPATHniinstalacion;Windowspendiente.

## 30Oct00:48 Start quiet failure truth
- InspeccionvisualconPATHsincompilerdescubrioalertaBuildOKconstdoutvacioantesdeallegarBuildfailed. BuildOKahorarequiereexit0ybinariotemporalexiste; silencionopruebaexito.
-9checksStartPTY: incluyecompiladorfalsoexit7sinoutput, noBuildOK,failurevisible,editorusable. Nueve modelosPASS.
- VisualcomplementoStartconpathespaciado: logcompilacioncompletoycerrar/autorunrestauraeditor limpio; valorStartpathOKescrito. Capturarealsinrecortarbordes.

## 30Oct01:03 Baseline36: expectativa obsoleta Calls
-3351441 limpio/mismoSHA2edfcd57:35suitesPASS,CallStacktestfallo por exigir__MAINtraseliminarreescrituraMain. PantallaactualmostrabaCalls MAINcorrecto; nofalloproducto.
- Expectativaajustada a MAINenfilaCallsconmarco, manteniendoBUMP/on/off/step. Falloinicialconservadoen/tmp/hbide-pty-3351441/results.jsonl, noanunciar36PASSdeesarevision.

## 30Oct01:07 Script screen ownership
- ReproduccionPTY: elidle delIDE sobrescribia la ultima fila deun Script esperandoInkey(0). DosFAILantesdelcambio.
- Script suspende status durante ejecucion, recupera ownership y repintaeditor/status despuesdesalida normaloaborto. Compilacion conserva sugestiondeerroreslocal.
-7checksScriptScreenPASS: dosrunsconmarkerultimafila, valoresoriginales yrestauracionINS, editorusable. ScriptErrors9PASS y nueve modelosPASS candidato. Capturas completas input/retorno inspeccionadas. Runner37suites; Windows pendiente.

## 30Oct01:10 Empty Run arguments
- Argumentosentrecomillasvacios desaparecian delparsercompartido: tresmodos devolvianfirst/twowords/last envezdecincoargumentos. ReproduccionconvaloresrealesStart/Script/Debug, noejecucionsimulada.
- Tokenizer diferencia palabramarcadadecontenidovacio; preserva vacios yposiciones sin cambiarliterales/metacaracteres. Pruebafinalincluyevacioinicial,intermedio,final ypalabraconespacio:7checksPASS. ModeloProjectañade vacios/quotesadyacentes, nuevemodelosPASS candidato.
- Runner38suites, no baselinecompletaheredada. Windows pendiente.

## 30Oct01:14 Parentheses in diagnostic paths
- ParserHarbourusabaprimer')': carpetascomo folder(old)/test.prg perdianeldiagnostico. Modelofallabaantes. Ahora busca(digitos)seguidodeError/Warning,sinconfundirparentesisdelpath otexto.
- ModeloProjectpruebaold/(12)/test(3) yruta/lineaexacta. Nueve modelosPASS candidato. FixtureProjectMessagesrealahoracompila folder(12)/bad1.prg:18checksPASS,incluidos Enterlinea3,rebuild ybufferdirtysinrecarga/duplicado.
- Capturascompletas Messagesconpath ysaltoexacto inspeccionadas. NoherenciadebaselinegeneralniWindows.

## 30Oct01:22 Live project member existence
- SourcesreteniaexistsdelProjectOpen: unficheroexternocreadodespuesseguia!missingynosepodiaabrir. PTY23PASS/1FAILantes.
- RefrescaexistenciadecadamiembroalprepararSources,sinrecargarHBP,modificarbuffersniejecutarhooks. Crear/eliminarafueraactualizamarca/rutadenavegacion.
- ProjectDesktop24checksPASS candidato y nueve modelosPASS. CapturascompletasSourcesconlate.prgcreadoyeliminadoinspeccionadas. Noafirmawatchautomaticosininteraccion,recargadeHBPnimanejoTOCTOUcompleto.

## 30Oct01:44 Baseline38 actual
-38suitesPTY distintasPASS en4616d245cc0d22a5f4a1ec90130a6eac87d5c217 limpio, binarioSHA50e26dc1a450bb6048ecd32a3ba6b8e258d242b43754766abe912c964713d356, sinmutacionesentrecasos. Nueve modelosPASStambienlimpios.
- Ledgerguardadodocs/evidence/linux-pty-4616d24.json. Runnerrebuildinicial, reutilizacionexplicita delmismoSHAposterior. Lote2interrumpidoporlímiteexternodespuesde3casoscompletos; comprobadosprocesosterminados, EditMenurepetidosoloestePASS.38resultadoscompletosunaRevision.
- Baseline3351441 seconserva35PASS+expectativaCallsfallida, no se cambiaretroactivamente. Esta nuevabaselineposteriorlasustituyecomocandidatoactual.
- Noescoberturaexhaustiva100%,noWindowsnative,noacabadoAnimatecertificado; dosstubsvisiblessiguenbloqueandogate. Fuenteproducto sin cambiosenestelotedocumental.

## 30Oct01:52 Compiler Flags acceptance
- Sin cambio de producto. Nueva pruebaPTYrealTab/Space/Enter/Esc: opciones por defecto; Cancel descarta; OK transmite warnings/debug/strict/incremental/optimize; GCC->MSVC cambiaargv.
-10checksPASS candidato. hbmk2falsocapturaargv ydevuelveexit7: pruebarealprocesoargumentos/noexito, noafirmaMSVCinstaladonibuildWindows.
- Runner39suites; baseline38de4616d24 permanecevalida paraesos38casos, nuevocontratosevalidaaparte.48contratosvinculados116acciones,2stubs.

## 30Oct01:59 Help matches current behavior
- Auditoria encontro textoobsoleto: Newprometiabuffervacio+preguntadesave, Finddeciaignorartailblanks, paletasinComboBox, roadmapviejo. ModeloHelpfallabaantes.
- Ayudacorregida: Newindependientecontemplateypreservaciondocs; blanksliterales+replacementvacio; ComboBoxselection-only; COMPLETION_ROADMAPactual.
- Cuatrocontratosdecontenidonuevos, nueve modelosPASS candidato. CapturasrealesFile/Findcompletasinspeccionadas. Cambiosoloayuda/tests/docs,noimplementacioneditor. Baseline38anteriornoesnuevacertificaciondelbinariodeayudaactual.

## 30Oct02:07 Display resizes every document
-40x120->25x80redimensionabasoloeditoractivo; alvolverotrodocpintabasobreborde/statusycursorfuerapantalla. Capturareal+2FAILPTYantes.
- ApplyDisplayactualizatodoslosbuffersantesderepintar.7checksPTYcandidatoPASS: reducir/ampliar, cursor/ultimalineavisiblesenotrodoc, uso nuevasfilas, undo/savebyteexactoenambosdocs. Capturascompletasantes/despuesinspeccionadas.
- Runner40suites/49contratos116acciones; baseline38de4616d24anteriornoheredada. Windows pendiente.

## 30Oct02:14 Real Help acceptance
- Sin cambio de producto. Nueva suitePTY25x80: Indexmatching,keywordinexistente,Contents,F1contextualFile sin ejecutaraccion, cierrealsourcedirtyyundo/savebyteexacto.
-9checksPASS candidato; enlaces/history/wrappingconmodeloprevio. Runner41suites,51contratos116acciones2stubs. Noafirma41PASScompleta niWindows.

## 30Oct02:22 Display distant cursor coverage
- Sin cambio de producto. DisplayPTYañadeCancel(sinresize) y ambosdocsconscroll/cursorlejanoantesdereducir.8checksPASS candidato.
- Expansionmantienescrollanteriorlegal: testajustadoacomprobargeometriaexpandida,noforzarfiladecursorofirstrowquenoformanpartedelcontrato. Intenciónde41suitesrunnerseconserva; baseline38noheredada.

## 30Oct02:28 Close Project/Window/About acceptance
- Sin cambio de producto.11checksPTYreales: Aboutabre/cierraalsourcedirty; WindowCloseCancelconserva/Discarddelultimodocrecreastarterysindisksave; ProjectCloseconservasourcedirty, Sourcesdaavisonoprojectysourcedisk/HBPintactos.
- IntentoinicialAboutusabaAlt+AenvezdemnemónicoB; corregidoharness,no producto. Runner42,54contratos116acciones2stubs. Baseline38historicanoheredada.

## 30Oct02:35 Nested Compiler Help
- Sin cambio de producto. CompilerFlagsPTYahorapruebaHelpencimadeopcioneseditadas,aunnoaplicadas. Escvuelvecontroles/valores; OKposteriortransmiteesosflagsalproceso.
-12checksPASS candidato, amplia10previos,no22checks. Mismorunner42;51->54contratospreviossincrementonuevo. NoafirmaMSVCbuildporcapturarargv.

## 30Oct02:49 Debugger search first row and misses
- ModeloaisladoreproduceSearchfromTopnoencontrabaprimera fila y missmovianRowhastafinaldesincronizandocursor. Dosfallosantes; modelonuevo6contratosPASSdespues.
- Scanlocalnindependiente,modificabrowsersoloconmatch; conservaGoTopparamatchfromTopparaevitarcambiodeviewportencontratoprevio. Case/next/previouspreservados.
- DiezmodelosPASS candidato. DebugCommands30checksPASS candidato, peroPTYporsisolosaltoprimerafilanodistinguiabugantes: nuevaaceptacionsemanticasebasaenmodelo,límiteregistrado. NoafirmafixGOTOgeneralnitodasrutasLocate. Baseline38anteriornoheredada.

## 30Oct02:57 Locate Goto cancellation
- NuevaaceptacionmenurealFind/Next/GotoexponeEscenGotomoviafila1envezdecancelar.35PASS/1FAILantes; SearchLineahorachequeaLastKeyESCantesdeGoto.
-36checksDebugCommandsPASS candidato y diezmodelosPASS. Find/Next/Gotolinkedcontratos57/116, runner42sincrementodesuites. NoafirmaLocateglobalniWindows; baseline38anteriornoheredada.

## 30Oct03:16 Baseline42 actual
- 42 suites PTY distintas PASS sobre 0768ac2182930d7ddfaa55c7a77a12ea5bf538d5 limpio, binario SHA64a7f206183ed782ac61d09495bb1328075ddcfc0ca650e8e928aa68b8867db6. Build fresco inicial y reutilizacion explicita del mismo binario, sin mutaciones durante los casos.
- Diez suites de modelo PASS en la misma revision limpia. Ledger completo en docs/evidence/linux-pty-0768ac2.json; logs originales /tmp/hbide-pty-0768ac2 y /tmp/hbide-completion-fjg413mg. Sin reintentos ni fallos en esta pasada.
- Sustituye baseline38 como candidato actual, conservando los historicos sin reetiquetarlos. Incluye ampliaciones de CompilerFlags, Help, Display, Close y Locate. No equivale a 100%, acabado Animate, revision visual exhaustiva ni Windows nativo; dos stubs visibles pendientes. No cambia codigo de producto.

## 30Oct03:23 Locate Find cancellation
- Esc en Search string seguia ejecutando la busqueda previa y movia la navegacion a su coincidencia, en vez de cancelar. Prueba final de menu real: 37PASS/1FAIL antes. El termino anterior ya se preservaba; la nueva comprobacion separada lo verifica, no se atribuye como arreglo.
- Locate comprueba K_ESC antes de guardar o buscar. DebugCommands38PASS y diez modelosPASS candidato. Captura completa tras cancelar inspeccionada: navegacion permanece en linea60 y modal cerrado.
- No cierra Locate global ni Windows. El baseline42 sobre0768ac2 sigue historico tras este cambio de producto; no se hereda como nueva pasada completa.

## 30Oct03:28 Locate Previous and Case acceptance
- Sin cambio de producto. DebugCommands amplia38->42checks: menus Next/Previous sobre dos coincidencias reales; Case sensitive rechaza mismatch uppercase y al desactivarse encuentra el mismo texto.
- 42checksPTY PASS candidato, enlaza dos contratos nuevos (59/116). Mismo runner42suites, no confundir42checksdeDebugger con42suitesglobales. No acredita Locate exhaustivo ni Windows; baselineglobal0768ac2 sigue historico.

## 30Oct03:34 Monochrome restore is state, not toggle
- Restaurar settings guardados en monocromo alternaba a color si ya estaba mono; segunda restauracion alternaba de nuevo. PTY43PASS/1FAIL antes, no estado idempotente.
- MonoDisplay acepta parametroopcional; comando sin valor conserva togglehistorico, ON/OFF fija estado y rechaza valorinvalido. Save escribe explicitamente ON/OFF para ambosestados, sin cambiar lectura de archivoslegados.
-49checksDebugCommandsPASS y diezmodelosPASS candidato. Verifica repetirrestoremono, restorecolor desde mono, formatoON/OFF y comandoinvalido. Captura completamonocromo trasrestore inspeccionada. Contratos60/116, runner42suites; no baselineglobalheredado niWindows. Otrossettingsconsemanticaslegacy siguenpenderauditarlos.

## 30Oct03:40 Restore default speed/tab/startup
- Save omitiaspeed0, tab4 ystartupON. Guardar esosdefaults, cambiarlos y restaurar no losreponia:49PASS/3FAILantes enPTYreal.
- Save escribe siempre RunSpeed, OptionsTab yRunAtStartup/NoRunAtStartup. Sin cambiarelparser de archivosantiguos ni afirmarrestorecompletodelresto. Nuevostestsinspeccionanarchivoemitido yre-guardadotrasrestore.
-55checksDebugCommandsPASS y diezmodelosPASS candidato. Sin cambio visual: correcciondeestadosserializados yrestaurados. Runner42suites/60contratos, baselineglobal0768ac2historico. Monitorflags/otrossettings aunrequierenauditoria.

## 30Oct03:47 Restore monitor scopes without toggling
- Guardar LocalON y restaurar estandoactivo loapagaba; siguiente restoreloencendia. PTY11PASS/1FAILantes, efecto realenvariablesZZZ9/AAA1.
- Public/Private/Static/Local/Global aceptanON/OFFexplicitos y Save siempreescribeestado; comando/menu sinvalor conservatogglelegacy. Estadoinvalido rechazadosincambios.
-18checksMonitorPASS y55CommandsPASS candidato, diezmodelosPASS. Pruebasrestauracionrepetida, scopesreales Local/Public/Private/Static yOFFdesdeON. Global soloverificaserializacionflag, noimplementavariablesGLOBAL ausentesenVM. CapturacompletaLocaltrasrestoreinspeccionada.
- No cierraRestorecompleto: Sort/Stack/Case/path yotrosestadosaunpendientesauditoria; baselineglobal0768ac2historico. Runner42suites/60contratos sinincrementos.

## 30Oct03:58 Restore CallStack and source numbers
- CallStackON se guardaba como ViewCallStack(toggle): fixtureaisladopierdeCalls alprimerrestoreantes. NumON seomitía: trasNumOFFrestore seguiaoculto. Reproduccionesantesguardadasporseparado.
- Save escribe CallStackON/OFF yNumON/OFF, usando parserexistentedeCallStack. PruebaCallStackoriginalampliadaverificaONrepetido, OFFdesdeON yNextRoutine original. DebugCommands56PASS, CallStackampliadoPASS y diezmodelosPASS candidato.
- Noafirmalayoutmanualresuelto: pruebascombinadasdetectaronpanelessuperpuestostrasrestaurarlayoutmanual, inclusoestadoCallStackcorrecto. Casoconservadoen /tmp/hbide-stack-tiled-after y /tmp/hbide-stack-restore-after2; investigarorden/geometria porventana. No seeliminaelrequisito alaislarpruebadeflag.
- Runner42suites/60contratos sinincremento; baselineglobal0768ac2historico. Windows pendiente.

## 30Oct04:06 Named manual layout restoration
- Q13 reproducido con Tile, dosWindowNext ysave/restore: geometria antes/despuescambiabaentreCode/Calls/Command porasignarrectangulos desdefocoactual, no ventanaoriginal. Testaisladocomparaarchivoantes/re-guardadoyvisibilidadCalls/BUMP.
- SaveusaWindowSelectCODE/COMMAND/CALLSTACK/MONITOR/POINTS envezdecicloNext, conservafocofinal; posicionorigenantesdesizeevitaclampingporelrectanguloanterior. Nuevocomando seleccionaventanaexistentevisible,rechazaotras. Archivoslegacy siguenleyendosecomoscripts, no seatribuyecorreccionretroactiva.
- Commands56,Monitor18,CallStackconlayoutampliado y10modelosPASS candidato. CapturacompletaCode/Calls/Commandtrasrestoreinspeccionada, sinpaneltapado. Pruebarestore repetido ygeometriabyteigual. Noafirmaiconized/zoom/hidden/windowsetdiferente resueltosniWindows; Q13parcialhastaampliarcasos.

## 30Oct04:13 Restore iconized window state
- Q13nuevofallo: guardarCallsiconizedemitiaWindowSize3x15, restoreloexpandia yrechazabatamañomenor4; mostrabaBUMP envezdeicono. PTYaisladofallabaantes.
- Save guarda rectangulooriginaldesdeelregistroicon yestadoON/OFF. WindowIconize admiteestadoexplicito idempotente, sinvalorconservatoggle. Restoreexpandeantesderectangulo yreaplicaestado, sinperderbrowser ni sugeometriaoriginal.
- CallStackampliadoPASS (restoreiconrepetido, ocultacontenido, expanderecuperaCalls/BUMP), Commands56PASS y diezmodelosPASS candidato. Dos capturascompletasicon/restauradoinspeccionadas. Q13parcial: zoom/hidden/windowsetdiferenteaunpendiente; noWindows. Runner42suites/60contratos, baselineglobal0768ac2historico.

## 30Oct04:20 Restore zoom return bounds
- Guardarventanazoomedperdiarectanguloderetorno; despuesrestoreZoomdejabapanelmaximizado. PTYantesfallabacomparaciondegeometriaoriginal/unzoom, excluyendofocofinalintencionadodiferente.
- Saveguardarectanguloprezoom yreaplicaWindowZoomdespuesdeltodoslosrectangulos. PTYCallStackampliadoPASS,Commands56PASS y10modelosPASS candidato. Capturascompletaszoom/unzoomtrasrestoreinspeccionadas; unzoomrecuperapanelCallsdividido.
- Q13parcial: hidden/cambiosdeconjuntodeventanas aunpendientes; noafirmaacabadozoomgeneral nicertificacionWindows. Runner42suites60contratos, baselineglobal0768ac2historico.

## 30Oct04:25 Restore variable ordering
- SaveomitiaSortOFF: guardardeclarationorder, activarSort yrestoredejabavariablesalfabeticas. PTY18PASS/1FAILantes.
- SortON/OFFexplicito, OFFrecargaordenoriginal; sinvalorconservaaccionSortONlegacy. Saveescribeestadoambos. PruebaMonitor22PASS,10modelosPASS candidato: declarationordertrasrestore, ONrepetido, OFFexplicito yvalorinvalido. CapturacompletaZZZantesAAAtrasrestoreinspeccionada.
- No cierraRestorecompleto: Case/path/points/hidden/windowsetdifferentpendientes. Runner42suites60contratos, baselineglobal0768ac2historico, Windows pendiente.

## 30Oct04:31 Restore search case setting
- SaveomitiaCaseSensitive, restaurar no reponia valor guardado:56PASS/1FAILantes, uppercasefallabamatchdespuesdeguardarsinCase yactivarlo.
- LocateCaseSensitiveadmiteON/OFFexplicitos, sinvalor/menu conservatoggle. Saveescribeambosestados. Commands60PASS y10modelosPASS candidato: OFFrestauradomatch, ONrepetidorechazomismatch, archivoexplicito e invalidorechazado.
- Sin nuevo cambio visual; nuevocheckdeestadosemanticousanavegacionyaexistente. No cierraRestoreglobal: path/points/hidden/windowsetdifferentpendientes. Runner42suites60contratos, baselineglobal0768ac2historico;Windows pendiente.

## 30Oct04:37 Restore empty source path
- Saveomitiapathvacio: guardarvacio,cambiarlo yrestoreconservabadirectorioajeno. Commands60PASS/1FAILantes.
- SaveemiteOptionsPathinclusovacio; parserexistenteyatrataemptycomoborradoexplicito. Commands64PASS y10modelosPASS candidato: archivoemitido, vaciorepuesto, sourceexternonoresuelvetrasclear ypathnovaciorestauraresolucionreal.
- Sin cambio visualnuevo; no cierraRestoreglobal(points/hidden/windowsetdifferentpendientes). Runner42suites60contratos, baselineglobal0768ac2historico;Windowspendiente.

## 30Oct04:49 Restore exact point sets
- BPscriptsejecutabantoggle: restoresobremismobreakpointloeliminaba. ReproduccionfinalfallaprimercomparadorBP; masadelantefixtureviejoaborta(no produceTOTAL), noregistrarPASSglobalantes. Unprimerintentobpnoentrabaporfuenteajena; añadidoResumeparaoperarsobremoduloVMreal.
- SavesnapshotemiteDeleteALLantesdeBP/WP/TP, luegoreconstruyesetexacto; funcionBPserializapornombre envezdeintentarlineaNIL. Scriptlegacy sigueconsemanticaanterior. Commands68PASS candidato: BPigualtrasrestore,repetido,WP/TPsin duplicados,BPMAIN, setvaciolimpiarposteriores. DiezmodelosPASScandidato.
- CapturacompletaWatch1+2=3trasdosrestoresinspeccionada, sinfilasduplicadas; captura noacredita por si sola breakpointfuncional. NoafirmaSnapshotRestoreexhaustivo/Windows; baselineglobal0768ac2historico,runner42suites60contratos.

## 30Oct04:53 Restored points stop execution
- Sin cambio de producto. Nueva suitePTYindependientecompruebaefectoVM, no soloreserializacion: BPline4guardado yrestauradodosveces haceGo detenerseexactamenteline4; TPn guardadorestavradodosveces, cambio realn:=99 yGo detieneenline5convalor99.
- DoscontratosdeefectoPASS candidato. Runner43suites (antes42), sin nuevobaselineglobal. NocertificaBPfuncionalporfuncion ni todasexpresionesTP; sesemanticaseconservaWPdisplayonly. Baselineglobal0768ac2historico,Windows pendiente.

## 30Oct05:14 Full regression attempt and stale Num assertion
-43suitesPTYdistintas sobre fafdf0c limpio,mismoSHAfab935d870e9609b02bbb018809ad1ef1a4f0894b6c3bbe95066832a78380b2b,sinmutaciones:42PASS yDebugFunctions57checksPASS/1FAIL. DiezmodelosPASS. Ledger docs/evidence/linux-pty-fafdf0c.json conserva fallo,no43PASS.
- FalloesexpectativaexactaNumOffvsNumOFF; mismo fixtureRestoreefectivoPASS, parsercaseinsensitive. Testcorrigecomparadorlineacompletacaseinsensitive,sincambioproducto. Sevalidaraparte,enrevisionnueva; no reetiquetarcorridaoriginal.

## 30Oct05:22 Restore changed window set acceptance
- Sincambiodeproducto: CallStackfixtureampliadodestruyeCallsconOFF,luegorestaura layoutONyverificaCalls/BUMP ygeometriaguardadaexacta. MonitorfixtureocultaLocalyrestauralayoutverificavaloresygeometriaexacta.
- CallStackampliadoPASS yMonitor24PASS candidato. Q13ampliado doscasosconcretosdeconjuntocambiado, no cierra todascombinacioneshidden/points/icon/zoom. Runner43suites60contratos; intento globalfafdf0cconserva42PASS+expectativaobsoleta, nolohereda.

## 30Oct05:43 Baseline43 current
-43suitesPTYdistintasPASS sobre63239d288bae435905d406d24c607daa685cadbc limpio, mismoSHAe955ab2cfb28c8b9f6367c60c8ae66b7a4b8c155f573530bbefe28386fd7935c. Buildfrescoinicial yreuseexplicito,mismabinariorevision,sinmutacionesfallosnireintentos.
-DiezmodelosPASSmismafuente. Ledger docs/evidence/linux-pty-63239d2.json; logsoriginales /tmp/hbide-pty-63239d2 y /tmp/hbide-completion-0u4e11sz. ConsolidaSave/Restore yQ13hastaCallsrecreado/Monitorhidden.
-Sustituyebaselineactualsinreetiquetarhistoricos: fafdf0c42PASS+1expectativafallida,0768ac2baseline42 y4616d24baseline38 conservados. No100%,noWindows,Animatefuncionalnoacabado,2stubs ycombinacionesQ13pendientes. Sin cambiodeproductoenestelotedocumental.

## 30Oct05:48 Settings write failure is visible
- SaveSettingsignorabahb_MemoWritfallido. PTYconparentinexistenteantesfallabaexigiravisovisible,mientrasguardadoinexistente.
- Chequearetorno ypublicaCannotSaveSettingsconrutaenCommand, tantopormenúcomocomando. PTYrestoredpointsexpandidoPASS: avisovisible,archivonoexiste yexpresion6*7devuelve42despues. DiezmodelosPASScandidato,capturacompletaavisoleibleinspeccionada.
- Noafirmaescrituraatomicanirollbackenfalloparcial; esosriesgosrestan. Baseline43sobre63239d2pasahistoricotrascambioproducto,nohereda43PASS. Windows pendiente.

## 30Oct05:53 Safe settings replacement
- Escritura directa de settings por symlink sobrescribia el destino enlazado. ReproduccionPTYantes falla preservarbytesoriginales, sin atribuir crash/fallo parcial no reproducido.
- SaveSettings usa helper existente HBIDE_AtomicWriteFile: temporal verificado, permisos conservados y replace POSIX; rechazo symlink deja enlace/destino intactos y contenido nuevo recuperable en temp. Aviso incluye fallo/recovery del helper.
- RestoredPoints ampliadoPASS: symlink/original intactos, temp recuperable, overwrite regular modo0640 conservado, sin temp tras exito. DiezmodelosPASS incluyen fault-injection helper existente. No certifica atomicidad Windows ni durabilidad fsync ni todos los fallos parciales. Baseline43sobre63239d2historico.

## 30Oct05:58 Missing settings restore is visible
- RestoreSettingsarchivoinexistenteacababasesilenciosamentesincambios. PTYantesfallaavisovisible.
- RestoreexplicitoavisaSettingsFileNotFoundconruta yretornasinaplicarscript. StartupLoadSettingssilencioso cuandoinitcldausente conservado, nosetocaflujoauto.
- RestoredPointsexpandidoPASS y10modelosPASScandidato: aviso yexpresion8*8=64muestranusabilidadposterior. Capturacompletaavisorutainspeccionada. NoacreditavalidaciondescriptmalformadoniRestoretransaccional. Baseline43sobre63239d2historico,Windows pendiente.

## 30Oct06:02 Speed dialog bounds
- RunSpeed dialogaceptaba-5 ySaveguardabadelaynegativo; reproduccionantesfallaarchivo. RiesgodeInkeynegativono secertificacomononblock/hang,sereportasoloinputinvalidoobservado.
- Dialogaplicacota0..65534igualsuperioralcomandoexistente, Escnopublica. PTYrestoredpointsexpandidoPASS: -5->0,65535->65534,Escconedit99preservavalor7. DiezmodelosPASScandidato.
- Sin cambio visualnuevo, nopruebaacabadoAnimate. Baseline43sobre63239d2historico,Windows pendiente.

## 30Oct06:06 Consistent tab-width bounds
- DialogoguardabaTab-3mientrasbrowserclamp1; comando0guardaba0mientrasbrowser1. Reproduccionantesfallavalorserializado,noatribuyebugdepinturanoreproducido.
- Dialog/comandoclamp1..16,Escpreserva ybrowserNILseguro. PTYrestoredpointsexpandidoPASS: -3->1,99->16,comando0->1,Esc12preserva4. DiezmodelosPASScandidato; noacabadoAnimate/Windows. Baseline43sobre63239d2historico.

## 30Oct06:11 Restore CodeblockTrace policy
- SaveomitiaCodeblockTrace: guardarON,alternarOFF,restaurardosvecesdejabaOFF; F8entrabalinea5envezde4. ReproduccionVMrealantesfallaexacta.
- ComandoCodeblockTraceON/OFFexplicito ySaveescribeestado; sinvalor/menu conservatoggle. Fixtureexistenteampliadoambosmodosguardados/restauradosdosvecesPASS: F8line4ON,line5OFF. DiezmodelosPASScandidato. Unerrorintermediodelparche(nombreparametroomitido)se corrigioantesdecommit, no productopublicado.
- Sin cambio visualnuevo,nocertificaAnimate. Baseline43sobre63239d2historico,Windows pendiente.

## 30Oct06:15 Link expanded settings acceptance
- Sin cambio de producto. Inventario enlaza Speed, Tab Width, Save Settings y Restore Settings con sus pruebas reales acumuladas: 64 contratos de 116 acciones. Contar contratos no mide completitud ni cobertura exhaustiva.
- Los contratos conservan límites: acabado de Animate, Windows, scripts malformados y combinaciones de layout siguen pendientes.

## 30Oct06:36 Baseline actualizada tras fixes de settings
- Revisión limpia 53be664, diez modelos PASS y 43 suites PTY distintas con resultado final PASS. Mismo binario SHA256 16465a647b0d259eea9f616327e8d8c1014b7b39eeba22cd1eb8e087e488ea6b, sin mutaciones durante los tests.
- No es una pasada sin reintentos: 45 resultados conservan dos fallos de infraestructura (GuiRoundtrip y ComboBox sin PATH de hbmk2), repetidos PASS con PATH correcto y sin cambios. Dos llamadas externas de 120s interrumpieron Navigation y Multidoc sin resultado; procesos ausentes confirmados antes de repetir, ambos PASS después.
- Evidencia durable docs/evidence/linux-pty-53be664.json; conserva intentos, hashes y límites. Baseline anterior63239d2 queda histórica, sin reescribirla. Esto no cierra visual exhaustiva, Windows, dos stubs ni todas las combinaciones Q13.

## 30Oct06:41 Q13 Points hidden/icon/zoom acceptance
- Solo tests y documentación, sin parche de producto. CallStack PTY amplía comprobaciones: Points oculto por Delete ALL reabre con geometría exacta y contenido; iconizado restaura dos veces y expande el browser; iconizado oculto restaura geometría; zoom oculto restaura dos veces y unzoom devuelve layout original.
- El primer intento falló por expectativa textual incorrecta WP x en vez del formato real x <wp, N>:. Corregida la expectativa; caso ampliado PASS sin cambio de producto. No se etiqueta como fallo de producto.
- Capturas completas de Watch restaurado con zoom y unzoom inspeccionadas, valor n=1 visible, borde inferior y barra de estado completos. No cierra Q13 global ni Windows. Baseline completo43+10 corresponde a53be664, anterior a esta ampliación del test.

## 30Oct06:46 Q13 Cascade settings coordinates
- Reproducción real: Save de Cascade emitía Window Move 2.00 2.00 y3.00 4.00; el parser numérico solo admite enteros. Restore dejaba Calls/Command en1,0. Igualdad de geometría guardada/re-guardada fallaba antes.
- Save serializa coordenadas/tamaños con Int, porque son celdas. CallStack PTY ampliado compara Cascade y Restore repetido; candidato PASS y diez modelos PASS. Captura completa de Cascade restaurado dos veces inspeccionada: títulos escalonados, fuente frontal, bordes inferiores y estado completos.
- No cambia el parser para scripts antiguos con decimales, ni arregla todo Q13/Windows. Baseline43+10 sobre53be664 queda histórico tras este cambio de producto.

## 30Oct06:51 Newly opened panes in named layouts
- Reproducción: Cascade con Calls visible, luego WP x creaba Points de3x2. ResizeWindows no aplicaba el layout nombrado al nuevo pane y reutilizaba el ancho antiguo de Calls.
- ResizeWindows vuelve a aplicar TILE/CASCADE al incorporar un pane; sin modo nombrado conserva rectángulos manuales. CallStack ampliado prueba viewport útil tras WP en Cascade, Monitor y diez modelos PASS candidato.
- Captura completa inspeccionada de Watch nuevo con n=1 tras seleccionar Points y reaplicar Cascade. Selección por comando no certificada como equivalente a Next en Cascade. No cierra todas las combinaciones ni Windows.

## 30Oct06:56 Window Select in Cascade
- Window Select enfocaba Points pero no lo movía al slot frontal como Next/Prev: prueba registraba Points2,2 frente a Command4,6. Antes falla, después PASS.
- WindowSelect aplica Cascade cuando ese modo sigue activo; manual/TILE mantienen geometría. CallStack ampliado y diez modelos PASS candidato; captura completa inspeccionada de selección directa Points al frente, sin reaplicar Cascade manualmente.
- No certifica todos los caminos de foco/ratón ni Windows. Baseline completo53be664 histórico.

## 30Oct07:05 Colors complete-list validation
- Reproducción: Options Colors con una sola entrada copiaba ese color a las11 posiciones. Ahora parsea/valida una lista completa antes de sustituir la paleta; error visible y estado intacto si faltan/sobran valores, llaves/comillas o hay caracteres no admitidos.
- Sin evaluar expresiones. Conserva tokens Harbour N/B/G/R/W/I/X/U, números, brillo/parpadeo y espacios; fuente local hbgtcore.c verificada para no rechazar tokens válidos. Prueba aplica paleta completa con GR+/N,7/0,U/N,I y restaura original.
- RestoredPoints ampliado PASS y diez modelos PASS candidato. Captura completa inspeccionada del diagnóstico y colores previos conservados. Un intento del test usó JSON sin convertir llaves Harbour; corregido antes de publicar. No es validación transaccional del script Restore entero ni de todos los modales de color.
- Path For Files Cancel probado: ya conserva ruta anterior, se añade test sin parche de producto.

## 30Oct07:10 Calls opening in TILE
- Calls se crea por otro camino que Monitor/Points. Abrirlo tras TILE solapaba Watch y Command; prueba real de rectángulos falla antes (Calls1,64..18,79; Watch1,40..11,79).
- ShowCallStack incorpora el nuevo pane al layout nombrado, sin cambiar los rectángulos manuales. CallStack ampliado compara no solapamiento; candidato PASS y diez modelos PASS. Captura completa inspeccionada: Source/Watch/Calls/Command disjuntos, datos y bordes completos.
- No cierra todas las combinaciones de quitar/reabrir ni Windows. Baseline completo53be664 histórico.

## 30Oct07:19 Development environment recovery
- At07:11 the temporary development environment was lost, including checkout, toolchain and unversioned test logs. Published code remained safe at d47c3af; cloned branch and remote/master verified again.
- Rebuilt Harbour694428e1c12f726675b19324d62167fa77d68185, built hbide, and executed new checks on clean d47c3af: CallStack expanded suite PASS plus ten model suites PASS. New binary b26cc2f0241c3b2a15e5d54ac78307119fc9b93523c62fb9ad9f34ee68c710b3.
- Evidence docs/evidence/linux-recovered-d47c3af.json records NEW executions, not recovered prior logs. Prior unversioned bytes remain unavailable. Published historical ledgers remain unchanged. No product change and no full-regression or Windows claim.

## 30Oct07:25 Animate visual samples at two speeds
- No product change. On35f84ec, binaryb26cc2f0, recorded16s at20fps for Speed5 (0.5s/step) and Speed1 (0.1s/step) with real application output. Inspected2fps contact sheets and full screenshots.
- Alt+D interrupts; F4 shows clean sampled app output (FRAME4 / FRAME23); space returns to debugger at line11 /49 with full source/command/borders/status. Source scroll at Speed1 observed in samples.
- Evidence screenshots and manifest in docs/evidence/animate-35f84ec/. Videos transferred separately, not included as repository bytes. This does not prove no tearing: sampling may miss transitions shorter than50ms and other platforms/sizes remain untested. Q04 stays partial.
- Initial attempt failed terminal focus and was discarded; later Escape was not the interrupt shortcut, so final runs use Alt+D. No product failure inferred from those setup attempts.

## 30Oct07:28 Build cancellation feasibility, no product change
- Investigated Harbour processOpen/nonblocking PRead/processValue/processClose in local runtime source and a real parent+child probe. processClose killed only the direct process; spawned child remained. processValue returned0 for the signal-terminated direct process in this environment. Remaining child explicitly killed after observing it.
- Runnable Linux-only probe in tests/probes/, outside acceptance runner. This is evidence against an unsafe replacement of processRun, not implemented cancellation. A real build cancellation needs tree ownership, output draining, explicit cancelled state, cwd restoration and stale-binary refusal.
- Existing synchronous build and visible Esc-cannot-cancel contract unchanged. Windows process-tree cancellation unverified.

## 30Oct07:31 Isolated Linux process-group feasibility
- Second probe launches disposable parent/child under setsid then signals the owned group through posix_kill from hbunix. Both were gone after KILL; group result0 means success, processValue0 still does not distinguish cancellation.
- Preserved exploratory source in tests/probes/build_cancel_group.prg. No product integration: external setsid dependency, no group-identity guard, detached descendants and other platforms remain unresolved. Never signal a shared/existing group.
- No claim of implemented Cancel. Current UI contract unchanged. No remaining probe processes or PID files.

## 30Oct07:42 Current debugger regression
- Ten distinct debugger PTY suites PASS on clean e0d3f59 with one freshly built binary de014d4f: Commands, Functions, RestoredPoints, CallStack, Session, Startup, Monitor, Codeblock, Exits, Animate. No failures, retries or mutations in this pass. Ten model suites also PASS on the same revision.
- Durable evidence docs/evidence/linux-debug-e0d3f59.json. This validates recent debugger fixes together; it is not the full43-suite IDE regression, exhaustive visual or Windows acceptance. Baseline43-suite53be664 remains historical.

## 30Oct07:46 Delete TP index
- Reproducción: Delete TP0 no eliminaba el tracepoint; Save todavía emitía TP n. DoCommand comparaba cParam2 con TP en vez de cParam1.
- Corregido selector compartido WP/TP. RestoredPoints ampliado PASS después y diez modelos PASS candidato. No cambio visual nuevo. Baseline debugger10+10 de e0d3f59 queda histórico tras este cambio de producto; no herencia de aceptación completa.

## 30Oct07:55 Editing tracepoints preserves their type
- Reproducción: Enter sobre TP n y editar n+1 guardaba WP n+1 y cambiaba el modo VM a watchpoint. WatchpointEdit forzaba wp y false.
- Conserva WP_TYPE y pasa el indicador TP correspondiente a __dbgSetWatch. RestoredPoints ampliado comprueba TP n+1 guardado y que el tracepoint editado sigue deteniendo la VM en línea5 al cambiar n. Candidato PASS y diez modelos PASS.
- Captura completa inspeccionada: n+1 <tp,N> tras editar, sin bordes perdidos. Un intento del test dejó foco en Points al enviar otro Enter; corregido seleccionando Command. No se atribuye ese fallo de preparación al producto. No aceptación global/Windows heredada.

## 30Oct08:02 Strict point-deletion indexes
- Reproducción: `delete tp 0oops` eliminaba el punto0 porque IsDigit solo comprobaba el prefijo y Val truncaba el resto. Las rutas de BP y WP/TP ahora exigen un índice completo de dígitos.
- RestoredPoints ampliado preserva puntos ante sufijo no numérico, decimal y negativo; el índice entero0 sigue borrando. Primer candidato TP/BP PASS y diez modelos PASS. Repetición limpia del test ampliado TP/BP/WP registrada aparte tras commit.
- No cambio visual nuevo, no certificación del conjunto ni Windows. DELETE ALL conserva su ruta anterior.
- Repetición limpia e5d5c0c: RestoredPoints TP/BP/WP PASS y diez modelos PASS, sin mutaciones; evidencia docs/evidence/linux-delete-index-e5d5c0c.json. Binario 7cec83af7ff634aff6f4c6b1d4791fa8467ada0ecadadbb989df72d8bf36e167.

## 30Oct08:10 Malformed BP lines cannot toggle existing points
- Reproducción nueva: con BP4 existente, `bp 4oops` lo desactivaba. La creación/conmutación de BP también usaba IsDigit y Val, fuera de las rutas DELETE ya corregidas.
- Usa el validador de entero completo. RestoredPoints ampliado comprueba que 4oops y4.5 conservan BP4; siguen pasando TP/BP/WP DELETE. Candidato PASS y diez modelos PASS. Las formas de función BP MAIN y línea entera conservan sus caminos.
- Sin cambio visual nuevo, sin certificación global ni Windows.
- Repetición limpia b51db35: RestoredPoints PASS y diez modelos PASS, sin mutaciones; docs/evidence/linux-bp-line-b51db35.json. Binario 16c373a62e2eba4eb9bd45dd6f5f9eb49d72da0a3d8cfed03c4975ca131c4c79.

## 30Oct08:27 Debugger regression after point fixes
- Diez suites PTY distintas con resultado final PASS sobre415fe07 limpio y un binario3a3c9250: Commands68/68, Functions58/58, RestoredPoints, CallStack, Session, Startup, Monitor, Codeblock, Exits y Animate. Diez modelos PASS en la misma revisión. Sin mutaciones durante las pruebas.
- Una llamada agrupada Points+CallStack agotó el límite externo120s después de cerrar Points; CallStack quedó sin resultado cerrado, se repitió separadamente y pasó. No es una pasada sin reintentos ni se atribuye fallo al producto.
- Evidencia docs/evidence/linux-debug-415fe07.json conserva la interrupción. No es la regresión IDE completa43, aceptación visual exhaustiva ni Windows. Sin cambio de producto en este lote.

## 30Oct08:36 Breakpoint deletion range before VM narrowing
- Reproducción: `delete bp 4294967296` borraba BP0 porque la API VM convierte el índice a entero C. Ser una cadena completa de dígitos no bastaba.
- BreakPointDelete comprueba el rango del array VM antes de llamar al borrado. RestoredPoints conserva BP ante4294967296,4294967297 y un entero mucho mayor;0 sigue borrando. Candidato PASS y diez modelos PASS.
- WP/TP ya comprobaba rango antes de la API; no se atribuye este fallo a esa ruta. Sin cambio visual, sin aceptación completa ni Windows heredada.
- Repetición limpia4dd4ae3: RestoredPoints PASS y diez modelos PASS, sin mutaciones; docs/evidence/linux-bp-range-4dd4ae3.json. Binario c8b4cf1a22c4fc0b06359abc912e892cb1a7488cc409b9177b9b8895c867e353.

## 30Oct08:45 Breakpoint line range before VM narrowing
- Reproducción adicional: `bp 4294967300` desactivaba BP4 por estrechamiento a entero C en __dbgIsBreak. La guarda de borrado por índice no cubría esta API de línea.
- BreakPointToggle rechaza línea no entera, no positiva o mayor que2147483647 antes de consultar/modificar VM. Prueba conserva BP4 ante4294967300 y un entero mucho mayor; mantiene los casos válidos existentes. Candidato RestoredPoints PASS y diez modelos PASS.
- Sin nuevo cambio visual ni certificación Windows. El límite sigue la API VM firmada32bits del runtime comprobado.
- Repetición limpiade1029f: RestoredPoints PASS y diez modelos PASS, sin mutaciones; docs/evidence/linux-bp-line-range-de1029f.json. Binario 2d6a756705c4c26dac6454f09dba14c07e8f74e18a71879f0e541bc091d94fc6.

## 30Oct08:54 Safe cursor actions without source
- Reproducción: al desaparecer el fuente temporal, volver desde otro fuente muestra File not found y elimina el browser. F9 intentaba leer RowPos de NIL y abría No exported method. F7 compartía la lectura no protegida.
- F9 sin línea explícita y F7 no actúan si no hay browser. Nueva suite debug-missing-source: elimina temporal del fixture tras abrir otro fuente, Step descubre ausencia, F9/F7 conservan evaluador usable; restaura fuente, lo reabre y BP4 detiene VM; salida al IDE comprobada. Candidato PASS. Runner ahora44 suites, no44 suites verificadas en este candidato.
- Capturas completas inspeccionadas: fuente ausente con resultado64 y sin modal; fuente recuperado y parada VM en línea4, bordes/status completos. No certifica todas las acciones sin fuente, toda recuperación ni Windows.
- Repetición limpiabacdb88: MissingSource y RestoredPoints PASS, diez modelos PASS, sin mutaciones, mismo binario6ecf4b95722cddaafff8302e1a6b197dcecbb5480b32ed12ad9f94c3193cc9a5. Evidencia docs/evidence/linux-missing-source-bacdb88.json.

## 30Oct09:02 Navigation and breakpoint commands without source
- Reproducción: en el estado File not found, `goto 3` abría No exported method. Locate/Find y refrescos de BP también usaban browser sin guarda. BP4 recibió módulo NIL tras fallar búsqueda y abrió Argument error.
- Goto/Locate no leen browser inexistente; BP no consulta VM sin módulo conocido y refrescos de BP comprueban browser. MissingSource ampliado recorre Goto/Find/Locate/Num/BP/Delete, evalúa81 después de cada acción, recupera fuente y verifica parada VM4. Candidato PASS y diez modelos PASS.
- Sin afirmar que todas las acciones sin fuente estén cubiertas. Num ya tenía guarda, se prueba sin cambio. No aceptación global ni Windows.
- Repetición limpiad0164b8: MissingSource ampliado y RestoredPoints PASS, diez modelos PASS, mismo binario07420b60504849c36fb04ccad69ce3ed66a901da1d7e3d0a3730ef52f9214411, sin mutaciones; docs/evidence/linux-missing-navigation-d0164b8.json. Captura completa inspeccionada: fuente ausente, resultado81 tras secuencia de comandos, sin modal y bordes completos.

## 30Oct09:11 Closing last point without source
- Reproducción: sin fuente/browser, WP n y Delete WP ALL abrían No exported method en WatchpointsHide al redimensionar NIL.
- Guarda el redimensionado. MissingSource ampliado verifica Monitor on/off, WP/TP add/delete y CallStack on/off con evaluación81 tras cada acción; recupera fuente y parada VM4. Candidato PASS y diez modelos PASS. No fallo observado en Monitor/CallStack para esa secuencia, sin parche allí.
- Sin aceptación exhaustiva de combinaciones/layouts ni Windows.
- Repetición limpiae9ea238: MissingSource y RestoredPoints con resultado final PASS, diez modelos PASS, mismo binario1d550b333bbc9301844e330d059e4523f697c57e2f367f494c3c88c478f47d3c, sin mutaciones. Primera ejecución RestoredPoints interrumpida por límite externo120s, repetida aparte PASS; no pasada sin reintentos. Evidencia docs/evidence/linux-missing-panes-e9ea238.json.
- Inspección visual encuentra restos duplicados del título/borde de fuente arriba tras toggles sin fuente. Sin modal y evaluación81 correctos, pero acabado visual NO cerrado; investigar repintado por separado.

## 30Oct09:23 Repaint after hiding auto-layout panes
- Capturas por paso reproducen fondos antiguos restaurados tras ocultar Watch/Monitor/Calls: títulos/bordes duplicados. HideVars además reservaba filas para Points aunque estuviera oculto.
- Repinta el conjunto visible después de ocultar; HideVars solo reserva Points visible. Inspección de capturas nuevas confirma sin restos duplicados y fuente vuelve a fila1 sin hueco superior. MissingSource añade comprobación de título único y fila1 tras cierres.
- La prueba textual anterior pasaba pese a los restos visibles: no se usa como sustituto de la inspección de píxeles. Sin cierre exhaustivo de todos los layouts ni Windows.
- Repetición limpiaafc616a: MissingSource, CallStack y Monitor PASS, diez modelos PASS, mismo binarioe3f1e1a76af10a33e97396d21d59d6d14d9aa78222779f136367b6db736d992b, sin mutaciones; docs/evidence/linux-pane-repaint-afc616a.json.

## 30Oct09:32 Direct source reopening verified
- Eliminado el paso de abrir otro archivo antes de recuperar el fuente del fixture. Reabrir directamente el fuente que reaparece funciona y BP4 sigue deteniendo VM; no se reprodujo la hipótesis de bloqueo por mismo nombre y no hay parche de producto.
- El test queda más exigente al no depender del archivo intermedio. No certifica detección automática de reaparición ni todos los caminos de búsqueda.
- Repetición limpia8172063: MissingSource PASS y diez modelos PASS, sin mutaciones; docs/evidence/linux-direct-reopen-8172063.json. Binario 99760dcc0284e0dfc24c680c29629d313fe9206d04fe61a5bf2a2361bfe8b4d1.

## 30Oct09:48 Joint debugger regression after missing-source and repaint fixes
- Once suites PTY distintas PASS sobre3f13bcd limpio, mismo binario0b2f292715c0f6e0a2fc8591383f991cc9972bcf0fcb19de7f59514ca9c03a25: Commands68/68, Functions58/58, RestoredPoints, MissingSource, CallStack, Session, Startup, Animate, Monitor, Codeblock y Exits. Diez modelos PASS en la misma revisión.
- Sin fallos, reintentos, interrupciones ni mutaciones durante esta pasada. Ledger docs/evidence/linux-debug-3f13bcd.json. No es la regresión IDE completa44, acabado visual exhaustivo ni Windows. Sin cambio de producto en este lote.

## 30Oct09:55 Missing PPO preserves source identity
- Reproducción: Options PreprocessedCode sin archivo PPO dejaba visible el PRG pero cambiaba cPrgName; BP4 ya no se añadía. Guardado sin BP confirmó la divergencia.
- Calcula destino y solo cambia nombre/modo al existir. RestoredPoints ampliado comprueba BP4 guardado como PRG y parada VM4 después del intento PPO fallido. Candidato PASS.
- Primer reemplazo local alcanzó una declaración incorrecta y falló build; descartado antes de la prueba válida, no publicado. No cambio visual de interfaz en este fallo de estado.
- Repetición limpia5182343: Functions58/58 (incluye PPO existente ida/vuelta) y RestoredPoints PASS, diez modelos PASS, mismo binariob2339cc843180ab66ba237bdf617a0c2ba4be8dc9538c65ae18e86c8e0e2b7e7, sin mutaciones; docs/evidence/linux-ppo-5182343.json. Regresión11PTY3f13bcd histórica tras el cambio.

## 30Oct10:06 Missing open with empty search path preserves source
- Reproducción: Path For Files vacío y View archivo-inexistente sustituía la vista por browser vacío, sin aviso. La existencia se comprobaba solo si había ruta configurada.
- Comprueba siempre existencia; búsqueda adicional solo si hay ruta. Si no encuentra, muestra aviso anterior y conserva fuente/nombre/modo. RestoredPoints ampliado comprueba fuente preservado y parada VM4 posterior. Candidato PASS y diez modelos PASS.
- Primer assert del aviso esperaba texto sin salto de línea; ajustado a la presentación real antes de validación. No aceptación global ni Windows.
- Repetición limpiadfdb76c: RestoredPoints PASS y diez modelos PASS, sin mutaciones; docs/evidence/linux-open-missing-dfdb76c.json. Binario954d54bc0d8235438544bc5f88ce74cb8b99ce72402348003e576b9711918933. Capturas completas inspeccionadas: aviso legible, fuente anterior conservado y parada VM4 posterior, sin bordes perdidos.

## 30Oct10:14 Source paths and failed PPO return verified
- Pruebas añadidas, sin parche de producto: Path For Files con carpeta y nombre de fuente con espacios resuelve y abre contenido correcto.
- PPO existente abre; desaparece PRG, intento de volver conserva PPO; reaparece PRG y toggle vuelve directamente a fuente. Verificado tras corrección5182343, sin nuevo fallo observado en esas rutas.
- RestoredPoints ampliado PASS candidato; no certifica todos los formatos de ruta ni Windows.
- Repetición limpia3883111: RestoredPoints ampliado PASS y diez modelos PASS, sin mutaciones; docs/evidence/linux-source-path-3883111.json. Binario23ed3bb3f67c2f63b68a041270880ab1e7cd396f983069e29d5de980fce7827c.

## 30Oct10:23 Settings dialog Cancel verified
- Save y Restore: editar nombre y Escape conserva el nombre anterior en la siguiente apertura del diálogo. Bytes de archivo anterior intactos y no aparece archivo con nombre abandonado.
- Caso PASS, sin parche de producto. No se cambia el nombre por defecto tras errores porque eso requiere separar destino intentado de última ruta válida y no se ha establecido contrato nuevo.
- Repetición limpia4728d46: RestoredPoints ampliado PASS y diez modelos PASS, sin mutaciones; docs/evidence/linux-settings-cancel-4728d46.json. Binario31b50660913f1071ded1b614d79fa3d5724c47752645357b723b6292845e0965.

## 30Oct10:32 Debugger help summary reconciled
- El tema general Debugger aún decía Iconize y Menu Bar no implementados; Debugger windows ya los describía correctamente. Resumen corregido: Iconize funcional, recuperación Menu Bar Alt+O,M y solo Exchange Screens/swap on Input pendientes.
- Modelo añade contrato de consistencia y PTY verifica lectura real del resumen. Candidato Help11/11 y diez modelos PASS. Primeros intentos del test no confirmaban la selección intermedia de Index o no la cerraban; corregido el recorrido, sin atribuir fallo al producto.
- No nueva función ni certificación global/Windows.
- Repetición limpia468c936: Help11/11 y diez modelos PASS, sin mutaciones; docs/evidence/linux-help-summary-468c936.json. Binariocc930ebe01c471bdb9bfc049c4d780b1560a7a1b55c02340dedc5045902d25b2. Captura completa inspeccionada: Iconize, Menu Bar Alt+O,M y dos stubs legibles, bordes completos.

## 30Oct10:40 External-change safety acceptance
- Nueva suite PTY external-changes, sin parche de producto: recarga limpia; modificación externa de igual tamaño con mtime restaurado detectada; Keep mine conserva buffer, Save vuelve a pedir overwrite; Cancel conserva disco y buffer.
- Overwrite explícito guarda buffer y .bak idéntico a versión externa; borrado externo mantiene buffer, Cancel no recrea, Recreate explícito recupera archivo y conserva .bak anterior. Candidato PASS.
- Primeros intentos de recorrido eligieron foco incorrecto o esperaron aviso sin salto de línea; corregidos antes de validación. Runner45 suites, no45 verificadas en esta fuente. No prueba exhaustiva de carreras concurrentes, archivos mayores8MB ni Windows.
- Repetición limpia3fb16c8: ExternalChanges PASS y diez modelos PASS, sin mutaciones; docs/evidence/linux-external-3fb16c8.json. Binario2940d7edb707c115889686082f9c5461e1e210a107ffbafbd85c8d1f50d09261.

## 30Oct10:48 Failed recovery read cannot become empty buffer
- Reproducción PTY: journal no legible se recuperaba como buffer vacío asociado al archivo original, sin aviso. MemoRead devolvía vacío tanto por error como para contenido válido.
- ReadBase usa vfLoad para distinguir NIL de cadena vacía y devuelve estado de lectura. RecoverJournal comprueba lectura y conversión antes de cambiar documento o preguntar por descartar buffer abierto; ante fallo avisa y conserva estado/journal/disco.
- Nueva RecoveryUnreadable PTY PASS candidato y diez modelos PASS. Modelo distingue journal vacío válido de archivo ausente. Runner46 suites, no46 verificadas juntas. No certifica toda corrupción ni carreras concurrentes/Windows.
- La repetición limpia11066e7 detectó que vfLoad también devolvía NIL para archivo vacío válido en este runtime. Ese candidato NO se publica como aceptado. Sustituido por apertura/seek/lectura con tamaño y estado comprobados; journal vacío válido vuelve a distinguirse del fallo. Nuevo candidato PTY y diez modelos PASS.
- Repetición limpia1ac613c: RecoveryUnreadable, RecoveryRetention y RecoveryMulti PASS, diez modelos PASS (incluye vacío válido), mismo binario684eb0aff6a301ff6d450df347dcaab1b34bd61d0897052f64353e1c1f092dcf, sin mutaciones; docs/evidence/linux-recovery-read-1ac613c.json. Captura completa inspeccionada: aviso legible y documento original sin sustituir, bordes completos.

- Recuperación: siete cabeceras exactas HBIDE-J1 dañadas reproducidas como aceptadas por el lector anterior. El lector ahora devuelve estado fallido si reconoce la versión pero no puede validar flags/longitud/codepage completo; no carga esos bytes como fuente legacy. Conserva texto sin marcador y journal vacío válido. Candidato: modelo62PASS, PTY Malformed/Unreadable PASS; pendiente repetición limpia. No implica detección de toda corrupción (p. ej. marcador alterado) ni validación de todos los identificadores de codepage.
- Repetición limpia aeaf980: Malformed, Unreadable, Retention, Multi, CodepageRefusal y Utf8Bom PASS; diez modelos PASS, recovery62comprobaciones. Binario único68cb2bdcd22f58169c91d3840b752486a62a351efb9fdc95ec4ea5fbee054686, sin mutaciones ni reintentos. Captura del aviso inspeccionada completa. Evidencia docs/evidence/linux-recovery-envelope-aeaf980.json. Runner47, no47suites aceptadas juntas.

- Recuperación codepage desconocido: fixture J1 válido con NO_SUCH reproduce error BASE/1302 HB_TRANSLATE al recuperar. Se comprueba hb_cdpExists antes de traducir o tocar documentos y se avisa conservando journal/documento. La hipótesis inicial de traducción sin cambio no se confirmó: hubo error de runtime. Raw no requiere ese traductor. Candidato UnknownCodepage/Malformed PTY PASS; pendiente repetición limpia.
- Repetición limpia c875aec: UnknownCodepage/Malformed/Unreadable/Codepage/CodepageRefusal/Utf8Raw PASS, diez modelos PASS. Binario3f6a6bf241549ded9e09e18aa19a6ab0887e1cea7686aca819c584241e7598ed, sin mutaciones/reintentos. Aviso de codepage inspeccionado completo. docs/evidence/linux-recovery-codepage-c875aec.json. Runner48, no48aceptadas juntas.
- Regresión conjunta limpia e12456b:14PTY de recuperación +1guard estático (15casos distintos), diez modelos PASS, sin fallos/reintentos/interrupciones. Incluye permisos, metadatos dañados, codepage desconocido, sesiones múltiples, retención, path profundo, UTF8host/raw/BOM, conversión/refusal, tabs y EOLmixed/CRLF. Binario80d7b8f923c69d6f3a7abbb63c23d3520cb906c9819e35f8bd02ac2b41ae4878. docs/evidence/linux-recovery-joint-e12456b.json. Noes48suitesIDE ni certificaciónWindows.

- Recuperación destino exacto: reproducido scan que quita espacio final de /tmp/source.prg[espacio]. PTY con dos ficheros vecinos muestra recuperación+F2 dirigida al nombre sin espacio; el destino real no recibe el texto. Sidecar escrito sin separadores ahora se lee sin trim de espacios/CR/LF, preservando bytes del nombre. Candidato PTY TargetSpace PASS; pendiente repetición limpia. No cambia rescate sin sidecar ni añade soporte UI general para todos los nombres POSIX.
- Repetición limpia2d320ca: TargetSpace, UnknownCodepage, Malformed, Unreadable, Multi, Retention PASS y diez modelos PASS (recovery64). Un binarioaeb2ca3e5a7800888708b31c3a795b34f1af44aad93132b3c40aea98369979ef, sin mutaciones/reintentos. Prueba byte-exact de ambos ficheros, no inferencia visual. docs/evidence/linux-recovery-target-2d320ca.json. Runner49, no49aceptadas juntas.

- Global limpio48c7c37:49casos distintos ejecutados (48PTY+1guard), diez modelos PASS. 47casos PASS; DebugCommands67PASS/1FAIL en resolución de path restaurado después de modal de fichero ausente; DebugExits exit0 pero importa/reimprime ese fallo, por tanto no aceptado. No declarar global verde. Tres interrupciones externas por límite de lote antes del resultado final (RunEmptyArgs, Navigation, DebugCommands), luego ejecutados individualmente. Un binariocbffb8e2b1df2e18bae08e87859e355a743e2d3e6c4bc2df50ceaa2ef14c2cc4, sin mutaciones. docs/evidence/linux-global-48c7c37.json. Hipótesis a aislar: test no cierra nuevo modal FileNotFound y comandos posteriores se consumen en él.
- Aislamiento sin cambio de producto: comprobar y cerrar con Enter el modal FileNotFound tras el caso path vacío hace pasar DebugCommands69checks en el mismo binario global. Se corrige secuencia de prueba, no se elimina la comprobación de resolución real del path restaurado. Candidato PASS; repetición limpia pendiente.
- Repetición limpia5faadfe: DebugCommands69checks PASS; DebugExits16propios+69importados PASS, mismo binariobaec39bc1c4478936691fbfe77117fba9df111a7434d4f4a5b8d19007535bb30, sin mutaciones/reintentos en esta repetición. docs/evidence/linux-debug-modal-5faadfe.json. Producto no cambió respecto48c7c37; no presentar como49casos repetidos en5faadfe ni borrar fallos/interrupciones anteriores.

- M1 lectura de fuente: modelo LoadFile sobre fichero existente sin permisos reproduce pérdida de texto/nombre/dirty anteriores (lectura vacía silenciosa). Se comparte lector comprobado con recuperación, se valida antes de cambiar estado y OpenInDoc precarga antes de crear/cambiar documento; OpenInEditor devuelve el resultado real. Candidato modeloEOL133PASS y OpenUnreadable/RecoveryUnreadable PTY PASS. Comparación previa a recuperar sigue pendiente; esto no la sustituye.
- Repetición limpia2889418: seisPTY OpenUnreadable/RecoveryUnreadable/Malformed/TargetSpace/ExternalChanges/Multidoc PASS +diez modelos PASS (EOL133checks). Binarioa23549aace1f14365255def77a0b642d6595faa5b8b32fd40d4333057871c193, sin mutaciones/reintentos. Captura aviso completa inspeccionada, buffer activo visible intacto. docs/evidence/linux-open-read-2889418.json. Runner50, no50aceptadas juntas.

- Recarga externa: reproducido aviso "reloaded" antes de leer un fichero cambiado sin permisos. El lector conservaba el buffer, pero el aviso afirmaba éxito prematuramente. ReloadFromDisk ahora devuelve éxito/fallo y el aviso de éxito sólo aparece después de cargar. Se conserva el stamp visto para no avisar cada tick fallido; volver legible cambia su hash y permite nueva detección. Candidato ReloadUnreadable/ExternalChanges PASS. No cubre carreras arbitrarias ni cambio de permisos sin modificación detectable en ficheros >8MB.
- Repetición limpia c31832e: ReloadUnreadable/ExternalChanges/OpenUnreadable PASS y diez modelos PASS; binariod6b1a76828488db3d7d5ec00ce57c9e9306fe441a227fcd8238875c2349a1632, sin mutaciones/reintentos. Captura inspeccionada: error de lectura legible, texto anterior intacto, bordes completos. docs/evidence/linux-reload-read-c31832e.json. Runner51, no51aceptadas juntas.

- M1 comparación previa parcial: nueva opción Compare en recuperación muestra resumen read-only de estados de lectura, tamaños y igualdad/diferencia byte-exact de payload/disco cuando representación comparable. EncodingUTF8/BOM indica que no son directamente comparables, sin afirmar igualdad de texto. Cerrar vuelve a Recover/Discard/Later, sin recuperar ni guardar por mirar. No es diff por líneas ni vista completa, no cierra todo M1. Candidato Compare/RetentionPTY PASS y diez modelos PASS; se añaden casos encoded/damaged antes de repetición limpia.
- Repetición limpia b633b36: Compare/Retention/Multi/Malformed/Codepage PASS, diez modelos PASS (recovery72checks); binario19f0b1075b07de828ba2076532c84b2044ba1dfad36ef5bd727055f0bb5f2a9e, sin mutaciones/reintentos. Captura de comparación completa inspeccionada. docs/evidence/linux-recovery-compare-b633b36.json. Runner52, no52aceptadas juntas. Comparación por líneas/contenido sigue pendiente.

- Comparación previa: View bytes abre snapshot read-only de payload editor/disco crudo, J/D, scroll/Home/End, hex+ASCII seguro (control/noASCII como puntos), Esc vuelve al resumen y después a decisión. No edita/exporta/guarda. Modelo cubre controles/offset. Dos candidatosPTY fallaron por expectativas de marcador contiguo que cruzaba filas16bytes; assertions corregidas a fragments visibles, no producto para ocultarlo. Compare25x80/40x120 candidatofinal PASS. Vista básica de bytes, no diff por líneas ni interpretación Unicode.
- Limpio254c0b9: Compare/CompareLarge/Retention/Multi PASS+diezmodelosPASS (recovery74), binff8e91ea59ea85dca8a28869f6edf7ff61faf975a43958fc4a9b886614e4966d. Captura real inspeccionada: hex/ASCII y controles legibles; geometría de lanzamiento no demuestra tamaño de pantalla IDE (capturas small/large resultaron iguales), no se presentan como evidencia visual de dos tamaños. docs/evidence/linux-recovery-byteview-254c0b9.json. Runner53,nofull53.

- Reconciliación de evidencia: New fija SetMode40x120, por lo que lanzar PTY25x80/40x120 no acredita por sí solo ambas geometrías efectivas. Se retira esa interpretación de Q15; quedan comprobaciones byte-exact/scroll/salida y captura real legible. Ayuda/guía actualizadas con Compare/View bytes y límites. Catálogo offline estaba desfasado y se regenera; baselineQ01 distingue global49fallida y repetición modal, no hereda un verde actual.

- Snapshot del visor: prueba cambia disco mientras está abierto; D sigue mostrando el snapshot original, cerrar/reabrir muestra bytes nuevos y no los sobrescribe. Teclas texto/F2 ignoradas, Later mantiene journal/buffer y versión externa. Título aclara snapshots, no vista live. Candidato Compare/CompareLargePASS; no nueva certificación geométrica.

- Geometría real del visor: entrypoint de pruebas separado RecoveryViewProbe, sin modificar producto, crea IDE y llama ApplyDisplay con25x80/40x120, verifica MaxRow/MaxCol antes del visor. Capturas ahora sí distintas, inspeccionadas completas: datos/controles/status caben. Guardadas docs/evidence/recovery-byte-geometry/. Esto prueba visor directo, no flujo startup25x80 (startup fija40x120).

- Compare UTF8/BOM: reconstrucción byte-exact de guardado con codepage registrado y roundtrip lossless, BOM incluido, sin cambiar codepage global ni buffers. Codepage desconocido/inconsistencia no produce igualdad reconstruida. Modelo77checks candidatoPASS; no diff de líneas ni texto normalizado. Ayuda/guía sincronizadas.

- Flags recuperación: modelo yPTY reproducen aceptación de BOMsinUTF8; cuatro combinaciones incompatibles010/011/101/111 se rechazan por Decode antes de mutar. Invariantes del escritor: BOMrequiereUTF8, rawexclusivoUTF8/BOM. Journal conservado. Candidato diez modelos+InvalidFlags/Utf8RawPASS; no es detección exhaustiva de corrupción.

- Target sidecar con NUL: PTY reproduce buffer asociado a ruta que contiene byteNUL (no nombre válido para APIs de ficheros). RecoverJournal ahora rechaza antes de cargar/mutar, conservando journal y documento. No se rechazan espacios/CR/LF legales POSIX ni se impide rescate sin sidecar.

- Consolidación M1: Q08 enlaza lectura fuente/recarga y validación journal/flags/destino; Q15 identifica revisión de reconstrucciónUTF8 y Q01 runner55 (54PTY+1guard), sin heredar todos a HEAD. Se refresca catálogo offline después de los últimos registros. Próxima pasada conjunta conserva misma revisión para todos los casos M1 seleccionados.

- M2 probe Linux: nuevo experimento valida PID/pgrp/session=startprocess y starttime antes de señalizar grupo aislado, drena stdout/stderr, flagcancel independiente deexit0. Fixture parent+child: OWNED/CANCELLEDtrue,kill0,ambosgone. No integración producto; quedan check-to-signalrace,detached/leaderexit/flood/startup/UI/Windows. No se declara cancelación terminada.

- M2 probe: finite256KiB/stdout+256KiB/stderr antesSTARTED sin deadlock; groupownercancel y parent/childgone. Scriptausente sale2, probeavisa fallo sinseñalizargrupo. Noequivale a launcher ausente ni floodinfinito, no integraciónproducto. Harness reproducible tests/probes/check_cancel_owned.py.

- M2 negativo: líder sale0 antesreadiness, probeOWNEDfalse/CANCELLEDfalse/no señal, hijo siguevivo alretornar. Fixturefinito3s confirmado gonealexpirar. Exit0noequivale árbolterminado. Preservar como limitación, no integrar hasta resolver supervisiondescendientes.

- M2 Start: PTY de recuperación con nombre terminado en espacio reproduce argv de compilador apuntando al vecino sin espacio, por AllTrim del nombre de documento ya resuelto. Start conserva ahora ruta exacta al generar comando; GET de selección sigue quitando padding donde corresponde. Prueba usa compilador falso que registra argv y falla7, sin ejecutar binario/vecino. No promete compilar todos los nombresPOSIX ni resuelve cancelación.

- M2 Project Open: modelo Linux no-root reproduce que un HBP existente sin permiso de lectura se aceptaba como proyecto vacío por hb_MemoRead. La apertura comprueba lectura completa antes de seleccionar ruta/contenido; distingue vacío válido de fallo. No cambia la política histórica del objeto-modelo de limpiar estado al fallar Open; el host sigue publicando oProject sólo si Open tiene éxito. Añadidas pruebas modelo y PTY; no cancela build ni certifica Windows.

- Consolidación: Q12 registra los fixes de ruta fuente y lectura HBP, conjunta M2 y su intento Navigation interrumpido. Q01 actualiza runner57 (56PTY+guard, no57aceptados juntos). Roadmap explicita siete hitos sin pesos/porcentaje:0cerrados/1en curso/4parciales/2pendientes de aceptación, no0%implementado. Inventario regenerado para líneas actuales; vínculo de prueba no significa aceptación. Manual offline sincronizado.

- M3 INPUT/RestoreSettings: PTY no-root reproduce silencio al leer script existente sin permisos. DoScript usa lectura comprobada y muestra Cannot read script antes de ejecutar cualquier línea; scripts legibles conservan comportamiento. No valida transaccionalmente comandos malformados ni cambia la naturaleza ejecutable de los scripts de debugger. Build/UI y Windows no cubiertos por esta corrección.

- M2 diagnostics: compilador Harbour real imprime un nombre relativo con espacio inicial sin indentar/escapar. Parser AllTrim lo perdía; modelo reproduce ruta incorrecta y ahora preserva todo el prefijo anterior a (linea). No interpreta log arbitrariamente indentado ni certifica todos los formatos/Windows. Evita saltar al vecino sin espacio al existir ambos.

- M2 exact diagnostic follow-through: real HBP references " leading.prg" alongside leading.prg. PTY builds/fails, Enter lands line2/column1 in exact source, edits+saves it and proves neighbor untouched. First draft's1.5s startup wait saw blank screen; changed test to established4s wait, no product change. Repeat identified by clean-source runner below. M3 read-script remains non-transactional for malformed commands; DebugFunctions long attempt still unverified.

- M1 atomic save: symlink refusal previously promised recovery at a temp path even if hb_MemoWrit failed (read-only directory). Model reproduced2failures; now promises recovery only after write+size verification, otherwise explains failure and asks to keep buffer open/save elsewhere. Link/target untouched. Added dangling-link refusal regression too, already PASS before fix. Does not close temp-allocation race or certify crash durability/fsync/Windows.

- M2 data-loss guard: recovered source without extension gives Start identical source/output paths on Linux. Successful fake compiler reproduced promotion over source and automatic reload of executable bytes. Start now refuses matching normalized absolute source/output paths before compiler launch (case-insensitive comparison selected on Windows, not Windows-tested). Does not resolve hardlink/symlink alias identity generally. Focal PTY proves saved source preserved; ordinary paths require regression.

- Start collision guard follow-up: recovered relative target precious and absolute target are both checked; fake compiler invocation marker stays absent, source and neighbor unchanged. Q12 describes data-loss guard separately from still-unimplemented process cancellation; runner61 (60PTY+guard) counts available cases, not joint acceptance. Offline docs synchronized.

- M2 output collision with another open document: recovered precious (extensionless) stays open while precious.prg builds. Fake successful compiler reproduced replacing the other document's disk bytes. Start refuses normalized output matching any named open editor before compiler invocation. Does not inventory all unopened files as source or resolve inode/link aliases. No interactive cancellation or Windows acceptance.

- Harness isolation: DebugExits imported DebugCommands and silently ran69 unrelated checks before its16 own checks, exceeding call budget. Shared pure Scr parser extracted byte-for-byte; DebugExits imports no executable test module and honors HBIDE_BIN. Exit-case assertions unchanged. This removes incidental prerequisite execution, not69checks from the explicit Commands suite; that suite remains separately runnable. No product change and no claim of equivalent combined coverage from16exitchecks alone.

- DebugFunctions optional --idle-settle keeps all58checks and max per-pump deadline but returns after250ms output-idle (checked on200ms poll). Draft58PASS in53s, unlike fixed-wait original that exceeds per-call budget. Original mode remains separately registered and unverified on current candidate; idle settle result is explicitly mode-specific, not proof of original timing/visual acceptance. No product changes; isolated Exits16 and explicit Commands69 retained separately.

- M3 script lookup: bundled manual en.txt:625-664 defines scripts as command sequences, .cld default and cwd-before-PATH resolution including init.cld. Old binary failed real PATH init fixture (saved Tab4 instead of13). Shared resolver now supplies extension, exact cwd precedence and PATH lookup; explicit directories never fall back by basename. Existing unreadable cwd candidate is selected and rejected by checked read, not silently replaced with PATH version. Inactive startup still executes only Options commands. No malformed-script transaction, no new script authority/sandboxing, no Windows acceptance. Runner64 is63PTYcases/modes plus1staticguard, not joint acceptance.

- M3 missing INPUT: explicit missing script used to return silently. PTY reproduced the absent notice; DoScript now reports Script file not found with the requested name, without changing state or invoking commands. Startup lookup remains existence-guarded, so normal missing init.cld stays quiet. Visual support is a full25x80 reconstruction from the existing test parser, not a native screenshot: notice legible, but ACS borders/colors are approximate and do not certify terminal appearance.

- Follow-up to missing INPUT: Activate also loads optional init.cld after New, so the new missing-script message leaked into normal startup despite New's existence guard. Existing startup tests missed the extra command notice. LoadSettings now checks optional existence too; explicit INPUT still reports missing file. PTY asserts absence of startup init warning before exercising explicit missing INPUT. Prior claim that startup stayed quiet was too broad and is corrected here.

- Debug temporary integrity: read-only cwd reproduced silent source-temp write failure. PRG/HRB now use exclusive creation, complete-write and close checks before compilation/run; owned failed temporaries are erased, preexisting files/links are not truncated. Explicit error allows retry once permissions recover. Models cover exact bytes, empty, existing, bad parent and symlink refusal; focalPTY checks read-only failure, source unchanged and later usable Debug. Not an atomic/fsync durability guarantee or native Windows acceptance. Runner65 includes64PTYcases/modes plus guard; baseline now12models.

- Direct HRB write failure test: Linux RLIMIT_FSIZE256 with ignored SIGXFSZ allows the small source temp but forces a partial compiled module write. New PTY confirms Cannot create debug module, no debugger starts, all owned debug temps removed, original source intact and editor usable after dismissal. No product change or test-only hook. This covers the earlier direct HRB failure gap; native Windows and native visual of this specific module notice remain unverified. Runner66 is65PTYcases/modes plus guard, not66accepted functions.

- Debug failure coverage extended without product changes: same bounded fixture with RLIMIT_FSIZE32 forces partial PRG creation, and a separate syntax-rejected source exercises compiler failure. Both confirm expected notice, no debugger entered, exact original source, no owned debug temp left and usable editor after dismissal. HRB256 mode remains separately registered. Runner68 is67PTYcases/modes plus guard, not independent functions or joint acceptance; Windows and all error/cleanup races still pending.

- Temp sibling selection: seeded model reproduced that File() alone accepts an existing directory as a free temporary path. Helper now rejects directories and links as well as files at selection time; existing dangling-link model already passed and remains. Atomic model46/46PASS after fix, before45/46. Comments no longer promise guaranteed ownership: selection is not reservation and concurrent creators remain an open race. No production cancellation, no claim of race-free save/build or Windows acceptance.

- Atomic save creation boundary: deterministic competing-creator fixture proves unchecked MemoWrit can truncate a selected temp path. AtomicWriteFile now reserves with exclusive create and writes via that handle, checks full length/close before promotion. Complete temp retained on later failure; own partial write erased without promising recoverable complete content. Atomic46/46PASS; initial wording draft failed existing could-not-write assertion, explanation corrected. RLIMIT64 partial512 refuses/preserves ORIGINAL/no false promise/no partial temp. No threaded race/full path ownership/fsync/Windows guarantee; Start compiler output still only name-selected.

- Backup promotion: deterministic missing-temp boundary reproduces old erase-and-retry fallback deleting existing backup when both renames fail. Not a native Windows reproduction. DoSave now uses checked read plus AtomicWriteFile for .bak, no erase-before-retry. Failure still reports and continues saving the buffer. Model checks exact backup/source, missing/unreadable source keeps prior backup, directory promotion refusal preserves sentinel and retains named complete bytes. Same after-close/fsync/platform limits as atomic helper; baseline13models, not a completion percentage.

- F2 backup follow-through: real F2 saves exact prior disk bytes as .bak; next save with .bak directory/sentinel reports failure but saves new buffer, preserves sentinel and retains exact complete prior source in named temp. Initial test expected contiguous Saving anyway but actual modal wraps the words across lines; corrected assertion without product change. No native visual/Windows/global acceptance. Runner69 is68PTYcases/modes plus guard.

- Park-and-replace rollback explanation: missing replacement fixture restores original successfully but returned false with empty failure detail. Model reproduced54/55; helper now states replacement failed/original restored and identifies attempted replacement source without claiming a nonexistent new copy. No native Windows result implied. SaveAll source audit confirms it already calls DoSave (including backup); no policy change needed. Remaining first-session/File-menu backup guarantees in help corrected to attempted copy with visible failure.

- DBG-042 source path acceptance gap: new isolated Linux PTY verifies Esc keeps original directory, Enter persists a changed directory with spaces, and File Open really displays source found there. No product change: existing behavior passed. Linked contract and added explicit runner case (70 entries, 69 PTY cases/modes plus static guard). Not additional independent features or Windows acceptance.

- M2 compiler output: F6 viewer formerly truncated long lines with no horizontal navigation. New queued-key model reproduces inaccessible diagnostic tail, then passes after Left/Right offset/clamping. Empty output and left boundary covered. First fixture draft exceeded default typeahead capacity and waited; corrected to512 before reproducing product failure. Actual GTTRM direct viewer25x80 screenshots inspected before/after scroll: BEGIN and second line at left, full DIAGNOSTIC TAIL at right, complete lower border visible. Direct viewer is not the entire project/F6 integration. No Windows/Unicode-column certification.

- Compiler output integration: isolated fake hbmk2 emits long compiler line and exits1; real ProjectOpen ->F9->failed build->F6->Right reveals DIAGNOSTIC TAIL; Esc returns to unchanged failure/messages state. New explicit PTY case, no product hooks. Direct visual evidence remains separately scoped.

- First runner integration attempt on4c7c121 timed out at30s without an assertion result; direct rerun passed23.6s. Fixture waited up to200ms after each of240 arrow keys when no repaint remained, so runtime varied. Changed only test transport to batches8 (below typeahead capacity) with drain, preserving all checks. Timeout ledger retained separately; no product defect inferred.

- M3 checked source reads: explicit File Open of chmod000 source replaced prior code with empty view silently (PTY reproduction). Open/PPO now read once with explicit status before mutating identity; browser accepts checked bytes. Automatic module load reports unavailable source instead of displaying a false empty file. Browser LoadFile itself refuses without changing rows/cursor; empty readable file remains valid. PTY covers Open/PPO refusal and readable PPO; model covers failed reload/cursor and empty file. First assertion wrongly expected Main visible although fixture starts at final init line; changed to exact prior code-region comparison. Diff review also caught and removed accidental extra LoadText before commit. Native terminal focal screenshot inspected: original source/exec band intact, full Cannot read source path and complete code/command borders/status visible. Startup resize means not25x80 certification.

- Checked automatic debugger source load: separate PTY switches to another source, makes actual debug module unreadable, then steps back. Cannot read source caption appears once; F7/F9, evaluator, navigation, monitor/watch/trace/callstack remain usable. Restoring read permissions permits direct reopen and a real VM breakpoint at line4. No product patch beyond8af4a20; missing-file and unreadable-file fixtures remain distinct.

- M1 failed Save As identity: nonexistent destination parent reproduced caption/name changing despite failed write, including initially clean buffer. DoSave now returns explicit write success; SaveAs restores old filename/stamps on failure and deletes old journal only on actual success. PTY clean/dirty modes verify old name, unchanged source/destination, stable journal file set and later F2 writes original. Actual terminal screenshot inspected after failed save dismissal: old name/source, all lower borders and status restored. Not all failure kinds/Windows or25x80 certification.

- Failed SaveAs crash coverage: named dirty document keeps exact .journal/.target bytes across refused SaveAs; kill9 and restart recover under original name, disk unchanged until F2; final save equals original bytes plus lost edit exactly and clears journals. New crash mode, no product change beyondfaedce4. Other aliases/failure types/Windows remain separate.

- SaveAll conflict cancellation audit: no product defect reproduced. New PTY changes inactive dirty document on disk, Keep mine at switch watcher, Cancel at overwrite guard; summary1saved/1failed, external disk bytes unchanged, local dirty edit retained and other document saved. Initial fixture expected unwrapped Overwrite it? but real dialog wraps; corrected to it? without changing product. Existing dirty-based count works for this path; no speculative bool patch.

- SaveAll Reload defect: after switch watcher Reload cleans a formerly dirty buffer, old loop still backed it up/wrote it and counted saved. PTY reproduced prior .bak replaced. Now rechecks dirty after switch, skips writing/backup and reports reloaded(not saved) separately. Other dirty document saves normally. Native actual terminal summary inspected:1saved,1reloaded(not saved), complete dialog/OK/shadow/editor bottom/status. First visual attempt Ctrl+F2 terminal delivered literal sequence, so discarded that capture and repeated via actual File menu action. Not Windows/25x80 certification.

- SaveAs overwrite Cancel route: existing dirty named document and existing destination, Esc at overwrite confirmation preserves old identity, source/destination bytes and journal file set; subsequent F2 writes original only. No product defect reproduced, no additional product patch. Distinct from failed-write rollback test.

- Accepted SaveAs overwrite: exact old destination bytes become .bak, old source stays unchanged, new destination equals edited source, journals removed after success; next edit/F2 targets new name and updates backup to prior destination generation. New PTY, no additional product defect/patch or global acceptance.

- M4 property Esc audit: queued native GET/inline edit checks control properties, dialog properties and inspector edits preserve model, clean state and empty undo on Esc. No product defect reproduced. Initial fixture omitted production FitWindow and Redraw synchronized model dimensions to its mismatched test window; corrected fixture setup before attributing any failure. This is a queued-key model/UI-path check, not full PTY or visual/Windows acceptance.

- M4 property final geometry: GET width4 at col34 enlarged to20 remained beyond canvas because origin limits used old footprint. Queued property dialog reproduces; final footprint now reclamps origin after width/height/caption edits. GET model verifies single undo restores original and redo restores col18/width20. Initial test hotkey did not activate OK; Tab to OK/Space corrected test transport. Focal native terminal direct canvas redraw inspected, GET fully inside right border; explicit CLS/redraw means not modal restoration proof or full IDE/Windows acceptance. Other control footprints still require separate coverage.

- Final property footprint coverage extended through actual queued dialogs: Listbox/ComboBox width4->20,height4->8 from row6/col34 reclamps to row2/col18, one undo exact and redo. Button caption20 grows footprint and reclamps inside, undo exact. No product patch beyondb1ab5b6. Initial button fixture tabbed onto Cancel; corrected tab count, not product. No separate visual/platform certification inferred from queued-key model.

- M4 inspector footprint: inline button caption grows outside canvas from right-edge origin; reproduced through InspEdit+Enter. InspSetText now clamps final footprint to model interior, including radio items growth; model verifies button and radiogroup height+undo exact. Fixture initially used unsupported type string radio instead of radiogroup, corrected to actual palette type. Native focal direct redraw inspected: longer button and shadow fit right interior; inspector Col19 matches; full canvas/inspector/status visible. Explicit CLS/redraw is not modal restoration or full IDE/Windows acceptance. Oversized controls larger than model interior remain separate unresolved case, not claimed fixed.

### 2026-10-30 Designer safe writes

- Reproduced refused partial write that had truncated the destination.
- Moved existing editor atomic replacement helpers unchanged to safeio.prg;
  designer JSON/PRG writes now share them. Updated standalone build inputs.
- Error path preserves design and reports recoverable complete temp names in
  a bounded scrollable dialog. Actual 25x80 pixels inspected at top and after
  scrolling to the path suffix, with all dialog borders and status visible.
- Added exact-byte/refusal model and Linux RLIMIT actual SaveJson/GeneratePrg
  probe. No Windows/global milestone acceptance; oversized editing unchanged.

### 2026-10-30 Designer Save As identity

- New focused model reproduced SaveJson(.T.) changing cFileName to a failed
  destination. It now commits identity only after successful write.
- Regression covers failure retaining original name/dirty, subsequent normal
  Save writing original, and successful Save As committing the new name.
- SelectFileName is overridden only in the model fixture to avoid coupling
  this state invariant to keyboard layout. Actual file-picker UI is separate.
- Follow-up extends fixture to use the actual SelectFileName dialog with
  queued Ctrl+Y/text/Tab/Enter before the same failed-write identity check.
  Both real picker and isolated state path pass; no pixel claim is made for
  this backing-state-only change.

### 2026-10-30 Designer promotion refusal integration

- Extended real SaveJson/GeneratePrg fixture with directory destinations
  containing a sentinel. Both refuse without changing the sentinel; JSON
  remains dirty with the same identity, and retained complete temporary
  files decode as a valid model / match generated PRG bytes exactly.
- This extends helper-level checks to the actual methods. It is not a new
  product fix or global/Windows acceptance.

### 2026-10-30 Designer JSON decode refusal

- Reproduced truncated JSON containing controls:[] replacing the current
  design: decoder returned0 but left a partial hash that passed model shape.
- LoadJson now requires nonzero decode status and permits only JSON whitespace
  after the parsed value. Truncated objects, trailing junk and trailing NUL
  are rejected without changing model/name/dirty/history.
- Added19th model suite. Valid trailing whitespace loads, undo restores the
  previous model and redo restores loaded model. Filename after undo keeps
  existing semantics; no decision to change it is implied.

### 2026-10-30 Designer load refusal coverage

- Missing and chmod000 JSON paths preserve model, filename, dirty flag and
  undo count. Existing behavior passes; no product change was required.
- Loading invalid control entries skips them, reports the count, clears the
  file association and stays dirty so saving cannot overwrite the raw source.
- Focused Linux model coverage only; not a new UI/Windows acceptance.

### 2026-10-30 Legacy designer focus load

- Reproduced JSON without colorfocus inheriting the previously open design's
  focused-control color. Reset focus to the model default before applying an
  explicit nonempty key, so legacy/empty-key loads are state-independent.
- Regression covers missing/empty/explicit focus and undo/redo across load.
  No filename-history semantic change or oversized-edit policy is included.

### 2026-10-30 Designer optional control schema

- Reproduced listbox JSON without items raising a bound/index exception.
  Missing optional item lists now become empty strings before direct access.
  Non-string variable fields are repaired before identifier normalization.
- Added20th model suite, with numeric/logical fields, missing items for radio,
  list and combo, code generation, plus actual LoadJson paths for each type.
  No new controls or oversized-edit behavior added.

### 2026-10-30 Generated local name collisions

- Reproduced generated GET variable oDlg causing duplicate local declaration.
- Generator now reserves its own locals and later array names before binding
  controls; conflict hash matches Harbour's case-insensitive identifiers.
- Model conflict checks plus eight generated HRB compiles cover local names,
  mixed case, item-array collisions and cross-type case collisions. Original
  model bindings are not renamed in place. Compile evidence is not execution.

### 2026-10-30 Designer non-text event fields

- Reproduced numeric JSON when/valid/focus/state reaching AllTrim during
  generation and raising an argument error. Normalization clears non-string
  optional event expressions, matching existing action-field handling.
- Model generation and actual LoadJson paths cover all four fields. String
  expressions remain untouched; no arbitrary event code is executed in tests.

### 2026-10-30 Generated reserved-name runtime smoke

- Extended the eight reserved/case-collision artifacts beyond HRB compilation:
  each builds as an executable, enters the actual generated dialog and returns
  false after queued Esc. Wrapper catches runtime errors and verifies return.
- This tests initialization and exit only, not editing/binding interactions,
  visual appearance or all event paths. No new product fix in this step.

### 2026-10-30 Property Cancel button coverage

- Extended property cancellation fixture beyond Esc: edit a field then Tab
  to the explicit Cancel button and Enter, for both control and dialog.
  Model, dirty and undo remain unchanged; no product fix required.
- Initial queued Alt+C did not trigger under GTSTD and timed out; replaced
  with actual field traversal, not counted as product failure or a pass.

### 2026-10-30 Handler text roundtrip

- Actual JSON Load/Save/Load preserves string action/when/valid/focus/state
  expressions byte-exact, including quoted arguments. Generated source retains
  handler text. No event expression is executed by this model check.
- Existing behavior passes; no product fix or arbitrary PRG two-way import.

### 2026-10-30 Narrow GET JSON preservation

- Reproduced documented drag minimum1 expanding to4 when JSON reloaded.
- Normalization now retains widths1..3 already valid through drag. Inspector
  and property minimums remain4; no inferred UI policy change.
- Actual Load/Save/Load and generated Space(width) preserve1/2/3. This follows
  existing documented drag contract; oversized and filename-undo unaffected.

### 2026-10-30 Narrow GET generated runtime

- Generated GET width1/2/3 artifacts compile and run through actual GTTRM
  READ; keyboard enters X/XY/XYZ then Tab/OK, and exported bound values match.
- Six checks (three compiles and three final bound values), not six features.
  This is runtime state evidence, not pixel appearance or mouse acceptance.

### 2026-10-30 Narrow GET mouse roundtrip

- Extended runtime probe to click each generated width1/2/3 field, type the
  exact-width value and click OK; final bound strings match keyboard results.
- Nine checks: three compiles, three keyboard values and three mouse values.
  No product change, pixel certification or six independent feature claims.

### 2026-10-30 Long handler property acceptance

- Actual control property dialog preserves >180-character action/when/valid/
  focus/state expressions when accepted, including quoted arguments. Undo
  restores the exact pre-dialog model; editing action then Esc keeps it whole.
- Existing behavior passes; no product fix or handler execution. This checks
  model integrity, not pixel readability of the horizontally scrolling field.

### 2026-10-30 Inline event field acceptance

- Actual ComboBox inspector when/valid/focus/state edits preserve exact
  expression text, set dirty and add one undo. Undo/redo restores model
  exactly; replacing text then Esc keeps accepted text and history unchanged.
- Fields resolved by current InspFields keys, not hardcoded row numbers.
  Coverage is ComboBox, not every control that shares inline editing code.

### 2026-10-30 Integrated inline caret diagnosis

- Rechecked long When Tail/Home/Esc in the actual IDE, not only a direct
  designer fixture. Disabled terminal blinking for capture; caret appears
  after TAIL and on Start_ after Home, with borders and status intact.
- Gray canvas block is the ComboBox resize handle drawn by DrawControls,
  not a misplaced caret. Separate instrumented GT position agrees. No
  product change or global/Windows acceptance. Evidence in
  docs/evidence/inline-integrated/README.md, including excluded setup errors.

### 2026-10-30 Inline event control matrix

- Expanded queued native inspector acceptance/dirty/one-undo/undo/redo/Esc
  checks from ComboBox to GET, checkbox, button, radiogroup, listbox and ComboBox.
  Twenty actual control/event pairs: GET When/Valid, other controls Focus,
  checkbox/listbox/ComboBox State. Keys resolved via InspFields; absent
  fields are not silently skipped. No product change or handler execution.
- This is a model/UI-path matrix, not twenty independent features or visual
  acceptance for every field. Integrated pixels above remain When/ComboBox.

- Fixture correction: first matrix used the unsupported short type "radio".
  xBase substring membership still exposed three fields, so that pass did not
  certify a native radio control. Replaced it with actual DSN_RADIO value
  "radiogroup" and reran from a clean revision. Earlier evidence is retained
  but superseded for the radio portion, not described as native radio proof.

### 2026-10-30 Generated synthetic event runtime

- Six real designer artifacts compile and run in GTTRM: GET, checkbox,
  button, radiogroup, listbox, ComboBox. Each records actual When/Valid;
  controls exposing Focus/State record those, and Button records Action.
- Each dialog exits normally through OK and returns true. Twenty event
  pairs plus Button Action, six compiles, six OK returns and one unchanged
  source guard are34checks, not34features. The event trace is retained.
- Synthetic handlers return true; no private expressions executed. This
  does not establish When/Valid rejection semantics, exact call counts,
  every interaction path, visual appearance, Windows or milestone closure.

### 2026-10-30 Generated GET event veto and recovery

- Synthetic GET When false skips entry (X cannot enter); after enabling,
  ShiftTab re-evaluates When, Y enters and OK returns true with exact Y.
- Valid false on first Tab blocks departure. After End/Y and enabling,
  Valid is re-evaluated and OK returns true with exact XY, confirming focus
  stayed on the GET. Two generated compiles plus veto/recovery assertions
  and unchanged-source guard are12checks, not12functions.
- Initial fixture expected XY after Y alone, but observed Y because input
  replaced X after veto. Fixed the test sequence with End, no product fix.
  Scope is generated GET keyboard path, not all controls/events or Windows.

### 2026-10-30 Integrated ComboBox physical resize

- Actual IDE physical mouse handle drag20x6->25x8; JSON Save, Undo/Save20x6
  and Redo/Save25x8 preserve exact control arrays/handler. Full pixels show
  wider face, shifted handle and retained lower borders/status.
- No product fix. Terminal shortcut interception and early mis-targeted
  coordinates excluded as setup mistakes. Reproduction/results/pixels in
  docs/evidence/combobox-drag/. One geometry/control, not global acceptance.

### 2026-10-30 Physical drag minimum roundtrip

- Integrated ComboBox shrink clamps4x4, Undo20x6/Redo4x4; GET10->1,
  Undo10/Redo1, actual F12 reload/Save keeps1 with exact controls/handler.
- Full pixels inspected: width1 GET is covered by selection resize handle,
  noted rather than claimed ideal. No product change or property minima
  change. Reproduction/state/pixels added to combobox-drag evidence folder.

### 2026-10-30 Physical resize under viewport offset

- Actual IDE160x70 load, ComboBoxrow40,col130 revealed byTab; physical
  handle shrink20x6->15x4, Undo20x6/Redo15x4 exact JSON controls/handler.
  Full pixels retain borders/status. Uses existing5d4cb20 binary.
- Initial click hit border one row too low, no resize; excluded rather than
  treating ensuing UndoLoad as acceptance. No product/policy change.
  Reproduction and state added to docs/evidence/combobox-drag/.

### 2026-10-30 Modal field inventory denominator

- Audit now extracts30 GET declarations from EditProperties/DlgProperties/
  SelectFileName with stable surface/variable/occurrence IDs, kind, picture,
  label, source line and literal enclosing conditions. Includes buttons;
 30 is not a function count or expanded control/field-pair denominator.
- Field acceptance stays pending; four existing surface contracts remain
  linked separately. Extraction is source wiring, not native modal behavior.
  Unrelated dialogs, gestures and full per-control expansion still pending.

### 2026-10-30 Modal control/field expansion

- Strict type-only condition parser expands30declarations to79control/field
  pairs (buttons included), with stable IDs and acceptance still pending.
  Unknown guard syntax fails instead of guessing; no arbitrary eval.
- Eight Python inventory tests check exact surface counts, source/labels,
  nested guards, repeated fields, pictures/buttons, determinism, control
  exclusions and fail-closed unknown conditions. These are extractor tests,
  not79native modal acceptance tests or a global function denominator.

### 2026-10-30 Dialog modal seven-field acceptance

- Actual queued DlgProperties accepts caption/name/width/height/back/text/
  focus together, one undo and dirty, exact undo/redo; editing each field
  then Esc preserves accepted model and history. Seven pair IDs link the
  precise test without claiming every boundary/pixel/platform accepted.
- First fixture emptied controls but left selected1; Undo normalizes it0,
  causing snapshot mismatch. Corrected fixture to selected0 before capture;
  not a product defect or filename-undo decision. No product change.

### 2026-10-30 Dialog modal boundary paths

- Actual queued DlgProperties width/height1 clamps to existing GET bbox
  minimum62x23; Undo restores exact pre-dialog snapshot.
- Invalid? and empty Back/Text/Focus strings keep exact prior model;
  acceptance retains existing one-undo behavior. No no-op optimization or
  new policy. Linked only to corresponding five dialog pairs.
- These are chosen boundaries, not full color grammar, all numeric sizes,
  pixels, Windows or global acceptance. No product change required.

### 2026-10-30 File picker long-path truncation

- Reproduced actual SelectFileName truncating80-char default to35 before
  GET. Buffer nowMax255/Len(default)+20 with visible@S35. Default and typed
  path preserve exact bytes; Esc/Cancel empty, model/identity/history intact.
- Integrated F11 Tail/Home/Esc full pixels inspected, no file saved. Evidence
  filename-scroll/. Fixture typeahead512 avoids overflow timeout; initial
  visual forgot clearing default, corrected before evidence. No arbitrary
  length/platform/filenameUndoLoad policy promise.

### 2026-10-30 Native long-path SaveAs/Load

- Actual picker SaveAs to80-char internal-space path commits full filename,
  valid JSON, clean state; no35-char destination created. Native Load accepts
  unchanged long default and restores exact saved model/identity.
- Temporary isolated directory only. Extends picker-only evidence into real
  I/O; no arbitrary-length/filesystem/Windows or filenameUndoLoad acceptance.

### 2026-10-30 File picker caller cancellation

- Source audit finds only SaveJson/LoadJson call SelectFileName; GeneratePrg
  writes Lower(cDlgName)+.prg directly and is not affected by picker buffer.
- Actual native Esc/Cancel through SaveAs and Load preserve identity, clean
  state, exact model/history; cancelled SaveAs creates no requested file and
  existing JSON bytes remain unchanged. Temporary directory only.
- No product change or filenameUndoLoad policy inference. This covers clean
  caller cancellation, not all dirty/load-discard combinations or platforms.

### 2026-10-30 Dirty picker caller cancellation

- Extended actual SaveAs/Load Esc/Cancel matrix to clean and dirty states;
  exact model/identity/dirty/history and existing file bytes retained,
  requested new filename not created. No product change.
- Source check: LoadJson has no discard confirmation; it validates and then
  pushes old model to Undo. No new prompt or filenameUndoLoad policy added.

### 2026-10-30 Control modal pair links and button fields

- Existing GET/List/Combo width-height and Button caption modal tests now
  link their exact field/control IDs. Button Action/When/Valid/Focus links
  preserve-prefilled-long-handler acceptance, not newly typed execution.
- New actual Button modal acceleratorZ and brackets checkbox acceptance
  set dirty/oneUndo, exact Undo/Redo. No product change. Twenty-two of79
  source pairs now have focal links; this is not22fully certified fields.
  Button State is not exposed and was deliberately not linked.

### 2026-10-30 Control modal variable/items matrix

- Actual GET/checkbox/radiogroup/listbox/ComboBox variable edits and the three
  selection-control item edits accept exact valid values, one undo/dirty,
  exact Undo/Redo. Items contain internal spaces and quoted text.
- Eight more pair links:30of79 source pairs focal, not a certification rate.
  First queued sequence tabbed once too far on GET/checkbox and hit Cancel;
  corrected native field counts, no product defect. No runtime execution,
  invalid identifiers, exhaustive item grammar, pixels or Windows claimed.

### 2026-10-30 Native modal newly typed event matrix

- Twenty exposed When/Valid/Focus/State pairs across six controls accept
  newly typed quoted synthetic expressions through actual EditProperties,
  dirty/oneUndo and exact Undo/Redo. Field order is modal, not inspector.
- Seventeen new pair links and three upgraded Button prefill-only links:
 47of79 source pairs now focal linked, not a completion fraction. Button
  State is not exposed. No handler execution, product fix or pixels/platform
  acceptance. Button Action remains separately prefill-only acceptance.

### 2026-10-30 Native modal captions and new Action

- Say/checkbox/Button newly typed quoted/ampersand captions accepted exactly
  with Undo/Redo; Button newly typed synthetic Action exact, dirty/oneUndo
  and exact Undo/Redo. No handler executed or product change.
- Two new links, upgraded Button caption/Action links:49of79 source pairs
  focal linked, not completion fraction. All geometry/pixels/platform limits
  remain explicit; no accelerator runtime claim from preserving ampersand.

### 2026-10-30 Native modal position matrix

- Row1/Col2 through actual EditProperties for all seven controls accepts
  exact interior position, dirty/oneUndo, exact Undo/Redo. Fourteen new focal
  links make63of79 source pairs linked, not a completion fraction.
- No product change or oversized/negative/all-boundary/drag/pixels/platform
  acceptance. Remaining sixteen unlinked source pairs are modal OK/Cancel
  declarations across controls/dialog, not sixteen missing product functions.

### 2026-10-30 Explicit modal button matrix and inventory links

- Explicit Cancel after Row edit for seven control types retains exact model,
  clean state and empty history. Existing explicit OK Row1/Col2 matrix is
  linked independently; Dialog OK/Cancel links point to existing actual test.
- All79source pairs now have focal test links, not79complete acceptances.
  Boundary combinations, dirty histories, visual/platform coverage remain
  open; M0/M4 are not closed by filling link cells. No product change.

### 2026-10-30 Bounded IDE modal field inventory

- Added26source declarations across GotoLine/CompilerFlags/Replace/Find/
  RunArguments/Display, including four free-form HBIDE_DlgInput fields that
  GET-only inventory would miss. Multiline GET kind continuation parsed.
- Ten inventory tests check source identities and native kinds/non-GET
  inclusions. Field links remain pending; existing menu tests not inherited
  as whole-field acceptance. Other modals and gestures still pending.
- No product change, no M0 closure. M2 synchronous limit stays unchanged;
  no process-group-only cancellation contract or helper C introduced.

### 2026-10-30 IDE modal focal test links

- Fourteen of26 bounded IDE declarations link existing exact field tests:
  compiler radio/five flags/OK/Help, Display preset/OK, Replace two free-form
  inputs, Find input and Goto number. Enter/Esc is not explicit Cancel/OK.
- AutoRun remains unlinked: fake compiler fails, so it does not establish
  post-success launch behavior. Compiler/Display explicit Cancel untested by
  those Esc suites. Source links do not inherit past PASS to current HEAD.
- No product change or global percentage; pending links identify real gaps.

### 2026-10-30 Explicit Compiler/Display Cancel

- Real PTY changes five compiler switches then activates Cancel button;
  next fake compiler argv retains previous flags. Display switches preset
  then explicit Cancel leaves40x120 grid unchanged. Esc paths retained.
- Two new IDE field links (16of26), not equivalent behavior inferred from
  Esc. No product change; AutoRun post-success behavior still unaccepted.

### 2026-10-30 Compiler AutoRun success path

- New real-hbmk2 PTY regression: default-on, accepted-off, Cancel after
  toggle-on retaining off, then accepted-on. Each build removes the prior
  executable first; launch writes exact arguments including an empty one.
- 20 focal checks, new runner entry;17of26 IDE modal declarations linked.
  No product change or M2 acceptance. Initial harness wrongly expected
  quiet-compiler Build OK text; real compiler output uses Done instead.
  Corrected harness condition, not product behavior.

### 2026-10-30 RunArguments and edit modal buttons

- RunArguments actual OK/Cancel and Esc preserve or change actual Script
  argv, quoted/empty tokens included. Invalid quote leaves prior argv;
  explicit empty clears.14 focal checks. Harness initially used CtrlY,
  unsupported by the free-form input; corrected to Home+Delete.
- Goto/Find/Replace actual OK/Cancel, cursor/byte-exact mutation checks
  and Replace Undo. Existing EditMenu suite now37checks.
- All26inventoried IDE modal declarations now have focal links. This
  does not close M0, any other milestone, or full field/visual/platform
  acceptance. New runner entry, no product change.

### 2026-10-30 File/help modal inventory expansion

- Added17source declarations: ProjectOpen4/OpenFile4/SaveAs3/HelpPick3/
  HelpIndex3, with actual native kinds and source identity tests. Total
  IDE declarations43; prior26focal links retained, new17not implicitly
  accepted from existing menu tests.11Python inventory tests.
- Excludes generic dynamic alerts, debugger inputs and remaining gestures;
  no exhaustive claim. Runner now82entries (81case/modes+static guard).

### 2026-10-30 Help modal explicit buttons

- HelpIndex filter+actualOK/Cancel, multiple-match HelpPick actualOK/
  Cancel, return to source and Undo/save byte identity. Help16checks.
- Five new focal links:31of43IDE declarations. Picker selection changes
  unaccepted. Initial harness forgot view returns to picker, not source;
  corrected extra Esc between independent scenarios, no product change.

### 2026-10-30 File/project modal explicit buttons

- Actual OpenFile/ProjectOpen OK/Cancel, type path then focus list without
  changing selection, actual Home/Down list selection reflected into GET
  and selected resource opened. Directory order is observed, not assumed
  alphabetical.14checks including SaveAs actual Cancel retaining dirty
  identity/no destination and OK exact mixed EOL bytes/original untouched.
- Eleven focal links added,42of43IDE declarations. HelpPick selection
  changes remain unlinked. No product change or milestone closure.
- Early harness assumed Directory alphabetical order, then used End
  (not a supported native list selection) and off-by-one screen row;
  corrected fixtures/observation, retained checks on actual opened item.

### 2026-10-30 Help picker selection identity

- Home/Down changes multiple-match selection from Debugger to Debugger
  windows; actual OK asserts exact topic title/body, not any Debugger text.
  Help17checks. All43inventoried IDE declarations now focal-linked, not
  complete modal/visual/platform acceptance. No product change.

### 2026-10-30 Debugger non-GET input inventory

- Inventoried27call sites, not27fields/functions:18InputBox,6inline
  __dbgInput and3HBDbInput constructors. Raw arguments, containing
  method/function and preceding source preserved;3explicit readonly
  inspectors distinguished. Shared InputBox implementation is not
  acceptance of each caller; no runtime links inferred.
-13Python inventory tests protect counts/source lines, constructors vs
  declarations, readonly branches and expression validators. Generic
  alerts and remaining gestures still outside this bounded inventory.

### 2026-10-30 Debugger caller-specific focal links

- Seven27input call sites linked to source-reviewed tests: TracepointAdd,
  WatchpointDel, Save/RestoreSettings, TabWidth, Locate and SearchLine.
  Each link states actual input/result and exclusions. Opening a popup
  is not accepted as proving its settings effect. Remaining20unlinked.
- Input constructors, readonly inspectors and inline object/array/hash
  editors remain separate and unaccepted by these links.

### 2026-10-30 Debug numeric modal behavior

- New27check real debugger PTY: Tab12/typedEsc/low1/high16; Speed5/
  typedEsc/low0/high65534. Nonnumeric input shows validation error, then
  Esc preserves prior setting. Each stage saves settings and asserts
  exact values, not just popup text. Restores4/0.
- Speed configuration is not Animate timing acceptance. Eight27caller
  links now focal-linked;84runner entries=83cases/modes+guard. No product
  change.20models rerun separately from PTY to avoid combined shell ceiling.

### 2026-10-30 Debug scalar edit and readonly inspector

- Actual Monitor n changes1to41; typed99/Esc and invalid expression/Esc
  preserve41. Command ?? n refuses typed edits before/after change.
  Resume increments and writes42, proving debuggee effect rather than
  only painted value.9focal checks; readonly nested values untested.
- Ten27inputcallerslinked.85runner entries84cases/modes+guard. No
  product change; initial inspector spacing assertion corrected from
  raw screen evidence.

### 2026-10-30 Structured debugger inspectors and nested editing

- Array/hash/object actual Monitor inspector rejects direct typed replacement.
  Enter opens nested browser: editing enabled by default, not recursively
  readonly. Nested scalar/property accepts41; typed99/Esc and invalid
  expression/Esc preserve41. Resume writes exact {41,2},hash values or
  object property41.21checks,14of27callers linked.
- No product change. Explicit lEditable false, deeper nesting, pointers/
  blocks and getter/setter faults not accepted.86runner entries85cases/
  modes+guard.

### 2026-10-30 Watchpoint input and readonly inspection

- Actual Point Watch add n=>1 and Points Enter edit n+2=>3; add/edit
  typedEsc and invalid expression/Esc preserve exact saved WP list.
  Points CtrlEnter (nativeK_CTRL_ENTER10) inspector shows3 and refuses
  typing. Resume debuggee writes2, unchanged by watch operations.
-14focal checks,17of27caller links.87runner entries86case/modes+guard.
  Structured inspection and side-effect expressions remain unaccepted.
  No product change or milestone closure.

### 2026-10-30 Debugger INPUT existing-file validation fix

- Reproduced actual INPUT filename popup rejecting an existing CLD: validator
  checked padded256byte HBDbInput buffer before external AllTrim. Fixed
  hb_FileExists(AllTrim(cFile)), same path normalization already used by
  execution. No process/cancel policy change.
-10PTYchecks actualINPUT script appliesTab11; missing file rejects then
  Esc preserves state; typedCancel unchanged. Path with spaces accepted/
  Cancel preserves; Open Another file resolves filename through path.
-20of27callerslinked;88runner entries87case/modes+guard. Not all paths/
  platforms, not milestone closure.

### 2026-10-31 Debugger Colors and SET inline inputs

- Actual Colors first entry W/R verified in saved palette; typedEsc
  and wrong-type validation/Esc preserve it. Actual Sets Decimals5
  verified both browser and Set(3) expression query; typedEsc and wrong
  type/Esc preserve5. Restores SET2/full original palette.12checks.
-22of27callerslinked;89runner entries88case/modes+guard. Only first
  color and numeric SET, not all settings/platforms. Initial fixture
  tried numeric value on logical Exact; corrected fixture to Decimals,
  no product change.

### 2026-10-31 Debugger breakpoint index modal

- Actual DELETE BP with no arguments opens index input. TypedEsc
  preserves exact two-function VM breakpoint list; negative/huge/
  malformed/fractional indices preserve;0deletesfirst;ALLclears.
  Saved settings reads VM list,16checks.23of27caller links.
-90runner entries89case/modes+guard. No product change, not all
  indices/sourcebreakpoints/visual/platform acceptance.

### 2026-10-31 Bounded mouse event source inventory

-27event-condition branches across IDE/editor/designer/help/project/
  HBWindow/debugger/DBWindow, preserving source/context/raw condition.
  Includes wheel, click/doubleclick and synchronous DOWN/UP/DBL reader
  routes. Not27gestures/functions or runtime acceptance. Internal drag
  loops/hit-tests/other controls remain outside this bounded inventory.
-15Python inventory tests; static function context correctly handles
  lower-case declarations. No product change or milestone closure.

## 31 octubre: doble clic del editor con seleccion operativa

La prueba PTY envio dos pulsaciones y verifico el evento K_LDBLCLK en una
instrumentacion temporal retirada. Antes: la palabra se resaltaba, pero
escribir Z producia `alpha Zbeta`. `SelectWord` usaba el resaltado antiguo,
no el rango consultado por las operaciones de edicion. Ahora establece el
mismo rango semiabierto que la seleccion de teclado. No cambia Paste:
continua insertando debajo de la linea, como ya hacia el IDE.

Nueva prueba `editor-mouse`: clic en byte correcto, TAB expandido, doble clic
mas escribir/Delete/Copy/Cut, Undo exacto, rueda y limite superior sin cambiar
los bytes. Comparaciones con fixture de EOL mixtos. Son efectos focales Linux
PTY, no todos los gestos ni aceptacion visual/Windows. El probe de repintado
incluye seleccion de palabra compartida, sustitucion, Backspace y Undo.

### Raton en viewport desplazado y espacios

Ampliacion focal del mismo harness: PageDown y clic sobre fila visible
comparan el byte de la fila real; End desplaza horizontalmente una linea de
150 caracteres y se comprueban clic y doble clic de ENDMARK, sustitucion y
Undo. Clic sobre espacio y tras EOL comprueba posicion y relleno exactos.
La rueda en EOF conserva bytes y queda en la fila vacia final. Se declara
PTY40x120 para coincidir con el tamano usado por defecto por el IDE, sin
presentar la antigua configuracion25x80 del harness como prueba a ese tamano.
No se infiere contrato de clic en marco, gutter ni fuera del editor.

El primer intento del limite EOF en38537e6 fallo: el harness envio Ctrl+End,
que en HBEditor significa fin de ventana, no fin del archivo. Se corrige a
Ctrl+PageDown segun el contrato de Harbour; no se cambia el producto. Se
retienen ambas ejecuciones por revision y no se oculta ese fallo del probe.

## 31 octubre: raton en Sources y Messages de proyecto

Harness nuevo `project-mouse`: clic selecciona sin abrir, Enter abre el
fichero seleccionado, doble clic sobre lista desplazada abre la fuente
exacta; cabecera, fuente ausente y Messages vacio no abren fichero. Build
real fallido produce diagnostico bad.prg:3 y doble clic abre la fuente en
fila3. Todos los bytes de las fuentes se comparan sin cambios. La prueba
quita su miembro missing del HBP tras probarlo para poder alcanzar el error
del compilador; no modifica fuentes ni producto. Linux PTY40x120 focal,
no certificacion visual, Windows ni todos los limites horizontales.

## 31 octubre: clic de Contents no salta a la fila siguiente

Reproducido con el IDE: clic en Quick start mostraba The screen. El indice
pinta `itop + fila - lbT - 1`, mientras el hit-test omitia el -1. Se igualan
ambos offsets y el limite de filas. Harness HelpMouse11checks: Quick start,
primera fila Basics, fila visible tras End del indice, Search/Next reales,
rueda acotada, Export genera catalogo, Close y Undo preservan bytes de fuente.
Las coordenadas de Search se buscan en la fila de botones, no en mensajes
que tambien contienen la palabra Search. Linux40x120 focal, no Windows ni
todos los bordes/gestos de ayuda. Producto corregido solo en el hit-test.

## 31 octubre: raton de Monitor modifica la variable correcta

Nuevo DebugMouse: tres locales A/B/C. Clic sobre B y Enter edita solo B;
doble clic sobre C edita solo C, doble clic A mas Esc conserva A. Resume
produce el array exacto `{12,42,53}`, con incremento real de A. Fuente sin
cambios byte-exactos. Se borra el valor existente con Home/Delete antes de
escribir: el primer harness insertaba53 delante de33 y una expresion regular
sin limite aceptaba erróneamente el prefijo53 de5333. La comprobacion final
del debuggee detecto ese fallo; ahora las aserciones exigen fin de valor y
se comprueba el resultado completo. No se cambia el contrato del campo ni
el producto. LinuxPTY40x120 focal, no todas las variables/scroll/Windows.

## 31 octubre: enlace Debugger windows no desaparece por prefijo

El flujo real de enlaces Quick start -> Debugger mostraba solo Run menu y
Keyboard shortcuts. `c != cTitle` con SET EXACT OFF considera el titulo
Debugger windows igual al prefijo Debugger, por lo que se excluia el enlace.
Se usa `!(c == cTitle)` para excluir solo el mismo titulo. Modelo exige el
enlace; HelpMouse18 comprueba primer/ultimo enlace, historial Back/Forward,
enlace anidado con titulo y cuerpo, retorno y Undo byte-exactos. No se ha
cambiado SET EXACT global ni la busqueda del usuario.

El modelo de ayuda de8366119 tambien usaba desigualdad no exacta para
prohibir self-links. Detecto como fallo el enlace de prefijo ahora permitido.
Se corrige ese assert a identidad exacta, igual que el producto; se conserva
el primer resultado fallido y se repite sobre fuente nueva. Las dosPTY de
8366119 pasaron; no se presenta esa revision como20modelos verdes.

## 31 octubre: Calls por raton cambia el contexto de locales

Nuevo DebugStackMouse: Main con mainVar101 llama Child con childVar202.
Con parada anidada, clic sobre MAIN en Calls muestra solo MAINVAR101;
clic sobre CHILD vuelve a CHILDVAR202. Resume finaliza con salida exacta
done y las fuentes byte-identicas. No se atribuye salto de linea de codigo:
el upstream tiene esa parte desactivada y aqui se verifica el contexto de
Monitor. LinuxPTY40x120 focal, no recursividad/pila larga/Windows. No cambio
de producto ni conteo de ramas como funciones nuevas.

## 31 octubre: Monitor desplazado conserva la identidad de variable

Doce locales, ventana de Monitor corta: PageDown expone las ultimas, doble
clic edita una fila visible a99; PageUp vuelve al principio y clic+Enter
edita V02 a77. Resume compara el array completo de doce valores, no un
prefijo ni solo el texto pintado; fuente byte-exacta. Sin cambio de producto.
LinuxPTY40x120 focal, no todos los tipos de variable ni Windows.

## 31 octubre: candidato Linux desde export limpio

Nuevo `scripts/build_linux_candidate.py --output /ruta/fuera-del-checkout`
rechaza fuente sucia, destino existente y salida dentro del repo. Exporta
HEAD, no usa binarios heredados, compila en otra carpeta y registra hashes
de fuente, hbmk2, binario y tests, ldd y logs. Smoke del binario exacto con
HelpMouse y RunSource desde el export; HOME/recovery aislados por harness.
No es instalador ni paquete portable, no revisa licencias ni acreditaWindows.
No cambia Version1.0 ni publica archivos a terceros. M5 permanece pendiente.

### Determinismo Linux acotado

Dos exports/builds limpios de d1b3c82 pasan HelpMouse18/RunSource8 pero sus
ELF difieren en6bytes: nombre temporal hbmk_*.c de la tabla de simbolos.
Copias con `strip --strip-debug` resultan byte-identicas y el binario
strippeado tambien pasa18+8checks. Se añade opcion explicita --strip-debug:
conserva original y hashes, registra herramienta y prueba el candidato final.
No se elimina esa evidencia ni se afirma reproducibilidad entre toolchains,
maquinas, plataformas o fuentes distintas.

## 31 octubre: avisos de distribucion sin licencia inventada

Inventario local HBP:14fuentes del debugger llevan GPL2o posterior con
excepcion Harbour y remiten a LICENSE.txt, ausente en el repo. Otras14 no
incluyen esa cabecera en lo inspeccionado; esto NO demuestra ausencia de
licencia ni titularidad. No se asigna licencia por inferencia ni se copian
terminos para todo el proyecto. `audit_distribution_notices.py` registra
rutas/hashes y `--check-release` falla mientras requiere revision. Es una
puerta de distribucion, no bloqueo de desarrollo. M5 sigue pendiente de
licencia/avisos aplicables, instalacion limpia y Windows.

## 31 octubre: identidad visible sin inventar version

About conserva Version1.0 y muestra Source con12caracteres de revision.
Build normal declara unrecorded, no adivina HEAD al arrancar. El candidato
Linux genera buildinfo.ch solo dentro del export e incluye hash de ese
header en manifest. Smoke About confirma revision esperada, OK, documento
dirty y Undo byte-exacto. Manifest distingue candidato de release no
habilitado por avisos pendientes; no se habilita publicacion de paquetes.

## 31 octubre: seleccion de palabra Unicode con TAB y EOL mixto

Se añaden8checks al modelo EOL (149total): UTF8 café tras TAB usa posiciones
de caracteres; escribir/Cut/Copy operan sobre la palabra exacta y conservan
TAB/CRLF/LF, Undo/Redo restauran bytes, Copy limpia mark y clic logico sobre
espacio quita seleccion previa. No declara gestos UTF8 nativos ni todas las
reglas de identificador Unicode. Sin cambio de producto ni politica de fuente.

## 31 octubre: reuse-build exige prueba de identidad

El runner podia etiquetar HEAD aunque el binario reutilizado fuese anterior.
Ahora un build fresco emite build-identity.json con revision, estado, hash de
bytes tracked y binario; --reuse-build valida todos antes de ejecutar. Puede
usar --build-receipt de otra carpeta. Cambios durante build no emiten recibo;
cambios durante prueba invalidan resultado. Tests de validacion rechazan
campos ausentes y fuente/dirty/bytes/binario distintos. Evidencia historica
baeda47 conserva su procedencia comprobada, no se reescribe retroactivamente.

### Inputs locales no tracked tambien invalidan reuse

Snapshot incluye ahora archivos fuente/include/HBP/HBC/HBM/Python no tracked
no ignorados, con ruta y bytes. Evita que un header local añadido cambie el
build sin cambiar HEAD/status tracked. No promete detectar toda dependencia
externa del compilador; el hash del binario sigue siendo el objeto probado.

## 31 octubre: doble clic con Enter, Backspace y overtype

EditorMouse37checks amplia31con6efectos: Enter sustituye palabra por CRLF
sin alterar terminadores vecinos; Backspace borra solo palabra; overtype
sustituye palabra sin comerse byte siguiente. Undo compara el fixture entero
en los tres casos. Gestos PTY sobre IDE real, no solo SelectWord directo.
Sin cambio de producto, no Windows/aceptacion global.

## 31 octubre: gestos UTF8 preservan datos, display no certificado

EditorMouseUtf8 verifica8efectos de clic/doble clic con cafe/naive/ano
acentuados: reemplazo/Delete/Undo comparan bytes completos con BOM,TAB,CRLF/LF.
El host opt-in UTF8 en esta configuracion pinta caf?,na?ve,a?o; una asercion
separada registra esa limitacion y los gestos localizan esa pintura, sin
pretender mostrar Unicode correctamente. Son9checks incluyendo observacion
de display. No se cambia traduccion global ni se considera resuelto el
renderUTF8. Prueba funcional de datos, no certificacion visual niWindows.


### Correccion del diagnostico UTF8: respuesta de terminal simulada

La atribucion anterior queda limitada al simulador: GTTRM detecta UTF8
pintando í y consultando cursor (harbour/src/rtl/gttrm/gttrm.c hb_trm_isUTF8).
El simulador respondia siempre columna1, que significa ISO. Cambiar solamente
LC_ALL no corrige esa respuesta. Modo --utf8-terminal responde columna2 a esa
consulta y observa café,naïve,año literales, mas los mismos8efectos byte-exactos.
Se mantienen ambos modos separados:9checks cada uno. Ningun cambio de producto
ni certificacion de terminal real/pixeles; no hay defecto de producto demostrado.
La evidencia anterior conserva su dato real, no sugiere un fallo Unicode general.

### UTF8 nativo: seleccion/reemplazo/Undo con evidencia visual

Fuente limpia54f2288 reconstruida: terminal Linux xfce4 real120x40, LANGC.UTF-8,
hostUTF8 y deteccion de cursor real. Dobleclick fisico selecciona café tras TAB;
teclearZ sustituye palabra completa y Undo restaura fixture BOM/TAB/CRLF/LF
byte-exacto. Inspeccion de tres capturas confirma café/naïve/año legibles,
seleccion solo de café, Z y Undo, marco inferior completo. Evidencia y script
original en docs/evidence/editor-mouse-utf8/. No todas las acciones Unicode,
Windows ni cierre de hito. Repite ademas modoPTYUTF8 de9checks en esa fuente.

## 31 octubre: inspeccion estructurada a otra profundidad

Prueba debugger real añade array de array, hash de hash y objeto con array:
24checks verifican apertura, rechazo de reemplazo directo, Enter a contenedor
interno,41aceptado,Cancel99conserva41,expresion invalida rechazada y salida
exacta completa del debuggee tras Resume. No se confunde rechazo de reemplazo
directo con readonly recursivo: esas rutas son editables por contrato actual.
Sin cambios de producto, getterfallido/lEditablefalse y profundidad arbitraria
siguen sin aceptacion.20modelos frescos38c4fdd en ledger separado.

## 31 octubre: getter de objeto fallido no habilita setter

Reproduccion real: getterBad falla con Zero divisor y su texto de error
aparece en inspector, pero Enter abre editor (5/6checks PASS). El constructor
ignoraba flaglCanAcc ya devuelto por __dbgObjGetValue y marcaba todo par
getter/setter editable. Se conserva ese flag en OMSG_EDIT, evitando editar un
texto de error como valor real. No cambia edicion de propiedades legibles,
readonly recursivo ni politica general de setters. Fixture con backing1 y
getterfallido/setter existente; debe rechazar Enter y Resume conservar1.

Getterfallido verificacion nativa: fuente21eaca0 reconstruida,6checksPTYPASS;
xfce4-terminal120x40 errorZero divisor legible, Enter muestra Value cannot be
edited, nuncaeditor. Resume conserva backing1exacto. Dos capturas inspeccionadas
con marcos completos de alerta y paneles, script+hashes/receipt en
 docs/evidence/debug-getter-failure/. No todosgetters/Windows.

Enlaces del inventario actualizados sin cambiar pruebas a funciones cerradas:
EditVar y tres inspectores enlazan profundidad acotada; objeto enlaza getter
fallido manteniendo limite setter/arbitrarios/readonlyfalse.15tests de
inventarioPASS, no15funciones nuevas ni pasadaPTYglobal.

## 31 octubre: setter que lanza error conserva el debuggee de la fixture

8checks reales adicionales sin cambio de producto: getter legible1/setter que
falla con Zero divisor muestra error, refresca1,99Escconserva1yResumeescribe1
exacto. No generaliza rollback de setters con efectos parciales; no cambian
fallback de acceso/clase, politica de propiedades ni readonly recursivo.

Setterfallido fuente7b5f7cd reconstruida:8PTYchecksPASS y terminal nativoLinux
120x40. Inspeccion de pixeles: alertaZero divisor legible con campo provisional41
aun visible mientras alerta; cerrarla refresca backing1, luego99EscyResume1exacto.
Marcos completos en ambas capturas. No rollback de efectos parciales niWindows.
Evidencia docs/evidence/debug-setter-failure/ con script/receipt/hash.

## 31 octubre: candidato Linux incluye smokes de getter/setter

El build exportado fuera del checkout añade getterfallido6/setterfallido8 a
About/HelpMouse/RunSource. Ensaya el binario exportado y stripped, no el IDE
heredado del checkout. Sigue candidato interno, no release/licencias/portabilidad
niWindows; no hereda toda la matriz de pruebas del IDE de desarrollo.

## 31 octubre: correccion de conteo EOL duplicado

Revision encontro bloqueUTF8word8checks identico repetido dos veces en EOL.
Se elimina una copia, sin cambio de producto:141checks en vez de149ejecuciones.
Los149historicos no representan149casos distintos. Se mantienen los8checks
UTF8word una vez, las pruebasPTY y capturas nativas independientes. Se repite
suite20modelos actual; no se reescribe evidencia historica ni se infla cobertura.

## 31 octubre: UTF8 raton Enter/Backspace/Copy/Cut

Los dos modos de terminal simulado ahora tienen17checks cada uno: se añaden
Enter/Backspace/CopyPaste/Cut y su Undo, comparando fixture completo BOM/TAB/
acentos/CRLF/LF. Paste conserva contrato de insertar debajo de linea, no se
convierte a pegar en cursor por inferencia. Datos exactos, no nuevos pixels ni
Windows. Conteo de modos no equivale a dos funciones ni toda matriz global.

## 31 octubre: botones de fichero/proyecto con raton

10checks reales Linux120x40: OpenOK/Cancel,SaveAsOK/Cancel,ProjectOK/Cancel
pulsados con raton. Paths con espacios, identidad solo cambia trasOK, dirty
retiene contenido trasCancel; comparacion completa de tres ficheros/EOLmixto.
No se confunde con prueba teclado de botones/listas. Primer intento25x80del
simulador no tuvo pintura util; no se afirma25x80ni defecto de producto.
Sin cambio de producto niWindows, no todosmodales ni cliclista en este caso.

## 31 octubre: primer item de lista modal con filename vacio

Mouse14checks descubrio13PASS1FAIL: primerproyecto ya seleccionado visualmente,
click+OKnoabreporqueGETvacioy marcadorcLastLBsuprimeSTATEsin cambio de indice.
STATEahora sincroniza si item cambia O GETvacio; path manual no vacio conserva
prioridad al solo enfocar lista. Mismo fix en Openfile/Openproject, sin cambiar
250chars ni politica de SaveAs. Primer item no alfabetico: no asumir Directory
ordenada. Pruebas comparan fichero/proyecto exacto y bytes tras editar/guardar.

Regresion del primer fixcf03a1d:Mouse14PASS peroKeyboard12/14 por nombre corto
tras largo enGET (aaa.prgith spaces.prg). STATEinicial expuso cola deGET no
rellenada; VarPut ahoraPadR250antesAssign/Display, conserva ancho del buffer.
No se presenta cf03a1d como verde global; ambos intentos quedan en ledger.

Filelistfix nativeLinux120x40 fuente49dce27 fresca: tecladoTabHomeDown muestra
nombrecortoaaa.prgsincola traslargo,ProjectTabHome sincronizaprimerbbb.hbp yOK
abreproyectoexactoconmiembroespaciadoquotedexistente. Pixeles/marcoscompletos
inspeccionados. Intento mousefisico no enfoco/activo y quedo modal; noaceptacion
nativeMouse,14PTYratonporseparado. No fallo producto atribuido sin diagnostico.
Evidencia docs/evidence/file-modal-first-item/native-results.json y capturas.

Correccion captura fisica: imagen real1400x900seprevisualiza1337x859; coordenadas
anterioreseranpreview y no caian en control. Con435,314y681,504reales,clickprimer
bbb.hbpsincronizaGETyOKabreproyectoexacto; miembroquotedespaciadoexiste. Pixeles
de seleccion/apertura inspeccionados,marcoscompletos/bytesintactos. Sin cambio
producto; fuente49dce27/binarydelreceiptprevio sinrecompilarni mutar.
Evidencia physical-results.json/physical-capture.py en mismo directorio.

## 31 octubre: limite de nombres lista tras sync inicial

5checks adicionales Linux: filename255seleccionado por raton y proyecto255por
Home se rechazanexplicitamente max250sintruncar;nombrecorto manual conserva
prioridadpeseaiteminiciallargo;actualeditor ytresficherosbyteexactos. No nuevo
limite ni politica, regression del fixSTATEvacio/PadR250. Enlaces inventario
actualizados para teclado/raton/longlist sin convertir testencierre de funcion.

## 31 octubre: candidato exportado incluye regresion filelist

Smokes internos añaden LongList5/Mouse14/Keyboard14 al binario exportado,
posterior a fixesSTATEinicial/PadR250. No heredar candidato anteriorb9575d7 a
fuente actual; conservar manifiesto por revision. Sigue candidato no release,
licencias/instalacion/Windows pendientes, no104matrizglobal.

## 31 octubre: parametro readonly explicito conserva hijo de objeto

Probeexpresiondebugger invoca __dbgArrays/Hashes/Object(v,nombre,.F.),sin
cambiar politicaeditable del Monitor. Arrayarray/hashhashrechazannestedEnter;
objetoarrayperdia.F.enconstructorhijo(11/12checks). Sepropaga::lEditableen
constructoreshijosarray/hash/object. No convierteInputBoxreadonlytopa readonly
recursivo por inferencia; no cambia valorpordefecto.T., ni politica de watchers.

Readonlyexplicito nativeLinux120x40fuente355a765fresca: objetoarray abrecon.F.,
Entersobrescalar1rechazaconalertalegible,Resumeconservaarray{1,2}exacto.
Doscapturasinspeccionadasmarcoscompletos. No cambia politicaMonitor ni certifica
otroscontenedores. Evidencia debug-readonly-depth/native-results.json/script.

Readonlyexplicito ampliado a20checks: añade objetohash y objetoobjetoarray,
ademas arrayarray/hashhash/objetoarray. Las cincofixture invocan.F.desde
expresiondebugger, rechazanEntersobrescalar yResumeproducevalorcompletoexacto.
No cambios de producto ni politicaMonitor/default; no profundidad arbitraria.

## 31 octubre: reconciliacion de cola con evidencia reciente

RoadmapQ20getter/setter,Q21filelist,Q22readonlyexplicito enlazan fuentes,
primerosfallos/regresionintermedia,conjuntas/capturas y limites actuales.
Q19distingue candidatof9c2af6deactuala9ecaa6,determinismo557e51fnoheredado.
Estados de los7hitos intactos:0cerrados. No porcentaje ni acumulacion de
checksporversion como cierre de producto. OriginalFunctions fixedwait pendiente.

## 31 octubre: limites explicitos de estructuras vacias

12checks reales Monitorarray/hashvacios: inspector top abre/rechaza reemplazo,
EntermuestraArray/Hash is empty,cerrarvuelveMonitor,Resumeescribe{}o{=>}exacto.
Sin cambio producto, cubre guardasdeLen0antesdeabrirbrowser; no todoscontenedores,
readonlyexplicito/objetovacio/nativoWindows ni nueva politica de inspeccion.

## 31 octubre: objeto sin datos no equivale a lista vacia

FixtureHBClasssinAddDataaunexpone metodosmodalfixture/realclass.7checks reales
abreninspector,EntersobreMethodrechazaedicion,cierranavuelvenMonitor yResume
conservaClassNameexacto. Primer probe esperaba alertaemptyantesdeabrirbrowser,
se corrigio expectativa al observar metodos; no defecto de producto demostrado.
Sin producto nuevo, no objeto sinmetodosarbitrario/Windows/pixels.

Inventario enlaza las pruebas readonlyexplicito/guardasarrayhashvacios/objeto
sinAddData con limites distintosdeldefaultMonitor. No cuenta5fixturescomo
5funcionesnuevasni sustituyeaceptacionplataformas.15inventario/33docsPASS.

MethodOnlyObject ampliado10checks: metodoAAProbeescribiriamarker si ejecutado.
Abrirbrowser,EntersobreMethodyResumedejanmarkerausente,ClassNameexacto. Esto
comprueba noejecucion, no solo textoMethod/alerta. Getterconefectos sigue fuera
deesta promesa: inspeccionarpropiedades legibles usa getters por contrato.

## 31 octubre: clipboard/historia del diseñador real

12checks ComboBox real creadoF2,Copy/dosPaste/Cut/UndoRedo/F10persistencia:
modeloscompletosexactos,variablesunicas,nuevavariabletrasCutUndoPaste,items/
dimensionespreservados y offsetconclampalaltoexistente. Primer harness esperaba
autogrowysinclampyabrioEntertrasF10yaasociado(disparabapropiedades),corregido
sinproducto. No nueva politicaoversized/UndoLoadfilename,todoscontroles/eventos
nonnil/runtime/Windows/pixels. No se declaranhandlersnonnilprobadosporvacios.

## 31 octubre: clipboard ComboBox con handlers no vacios

El test PTY ahora escribe items no predeterminados y when/valid/focus/state
con argumentos entre comillas mediante el inspector real. Comprueba los
valores exactos en JSON antes de Copy, dos Paste, Cut, Undo y Redo. Tras un
nuevo Copy cambia Items del origen, pega y exige que el clipboard conserve
el valor anterior; Undo del pegado y de la edicion restaura modelos completos.
18 checks. Un primer intento de la ampliacion obtuvo 16/18: el harness
suponia que el inspector recordaba el campo State tras los cambios de
seleccion; se ancla ahora con Up hasta Row y Down hasta Items. No fue un
fallo de producto. No se ejecutan esos handlers ni se renombran sus
referencias internas al duplicar la variable enlazada. No todos los tipos,
revision visual nueva ni Windows, y no cierra M4.

## 31 octubre: Paste no debe compartir una variable por diferencias de caja

Reproducido en IDE real: original NVAR1 escrito en inspector, Paste elegia
nVar1. DsnVarUsed comparaba con distincion de mayusculas, pero Harbour no.
El generador admite compartir variables del mismo tipo, asi que no se
presenta como error de compilacion: se viola el contrato de enlace unico al
pegar. Fixture mixto antes15PASS3FAIL; JSON y log retenidos en
`docs/evidence/designer-clipboard-case/`. DsnVarUsed ahora compara Upper de
ambos nombres. No cambia la opcion de compartir nombres escritos a mano,
ni reescribe referencias dentro de handlers. Tres checks de modelo para
mayusculas mixtas, prefijo mixto y nombre distinto; dos modos del mismo PTY
son dos fixtures, no dos funciones ni109aceptaciones globales.

5d74cc3 limpio: ambos fixtures clipboard18PASS sobre el mismo binario;
20modelos completos PASS,15inventario y33docs. Terminal nativo120x40:
Paste muestra nVar2, Undo muestra NVAR1, JSONRedo igual a Paste. Capturas
completas inspeccionadas, incluidos bordes inferiores. Las dos ComboBox
se solapan por el offset de una celda previsto, sin prometer no solapamiento.

## 31 octubre: claves largas no deben ocultar el valor del hash

Fixture hash con clave de144bytes y hash hijo. Antes5PASS2FAIL: edita y el
programa reanuda con41, pero el inspector no muestra41 ni permite comprobar
visualmente el Cancel de99, porque la columna de ruta toma todo el ancho y
la columna de valor queda negativa. Log y pantalla previos retenidos.
La columna de clave ahora ocupa como maximo la mitad del ancho disponible;
la clave real no cambia, solo se recorta su representacion. No es scrolling
horizontal nuevo ni cambio de claves. La primera prueba exploratoria tambien
exigia el sufijo de un titulo largo, que ya se trunca a proposito: se retiro
esa expectativa de titulo, no se presenta como defecto de producto.

e537b71 limpio: LongHash7+StructuredDepth24PASS sobre el mismo binario,
20modelos actuales,15inventario33docsPASS. Capturas nativas120x40 edit41 y
Cancel99mantiene41 inspeccionadas completas, Resume exacto. Primer script
de captura pulso un Enter adicional y dejaba1; corregida secuencia de
captura, sin cambio de producto. No certificacion de todas las geometrias.

## 31 octubre: array hijo de clave hash larga

La misma ruta larga llegaba al inspector array, que calculaba su propia
columna sin limite. Fixture hermano con array hijo antes5/7:41 se aplicaba
pero no se veia. Misma reserva de media ventana para el valor, nombre real
intacto. No es otra funcion por añadir un modo de fixture.
Una investigacion separada probo nombres de miembro de120bytes: Harbour
trunca simbolos a63 y no forma el par getter/setter; no se usa ese fixture
invalido como prueba de fallo de columna objeto ni se cambia esa politica.

bc0adb0 limpio: LongArray7+LongHash7+StructuredDepth24PASS mismoIDE,
20modelos15inventario33docsPASS. Native120x40array hijo de clave larga,
41 visible, Cancel99 conserva41 y Resumeexacto. Capturas completas
inspeccionadas. Evidencia `docs/evidence/debug-long-array-path/`.

## 31 octubre: asercion de valor acotada al browser

Los dos fixtures LongHash/LongArray ahora buscan41 en la columna de valor
de las primeras ocho filas y exigen la ruta V["long_key_ en la columna
izquierda de esa misma fila. Antes buscaban41 en toda la pantalla. No se
cambia producto ni se cuenta cobertura funcional nueva por precisar el
comparador. Se reagrupa regresion de clipboard y contenedores tras los fixes.

## 31 octubre: miembro objeto valido largo

Fixture nuevo de61caracteres, dentro del limite de simbolo63 y setter62:
no se reutiliza el fixture invalido120bytes. Antes5/8: escalar123456789 y
editado987654321 aparecen cortados; el programa reanuda con987654321 exacto,
pero no puede leerse completo en el inspector80columnas. Reserva de media
ventana para valor igual que hash/array, sin alterar miembro ni setter.
Log y pantalla previos retenidos. El test exige nombre y numero entero en
la misma fila del browser, no el numero en el codigo fuente.

Primer runner f82ad4f conserva5/8 por comparador de nombre en minusculas:
el browser muestra el miembro DATA en mayusculas. Pantalla anterior prueba
987654 truncado; pantalla tras fix numero entero. Comparador se corrige
sin distinguir caja y se repite, no se borra el intento anterior.

a8c0989limpio LongObject8+Getter6+Setter8PASS mismoIDE,20modelos actuales,
15inventario33docsPASS. Native120x40numero987654321entero,Cancel99 conserva,
Resume exacto y capturas completas inspeccionadas. NoWindows ni cierreM3.

## 31 octubre: candidato Linux posterior a fixes de columnas y clipboard

Export limpio6317d0e, build fuera del checkout y strip-debug conservando raw.
SHA8029e6bfc008d774914126bdc7bddd3539dc4d66cd0e9649597e5cdd05d31f56.
Ocho smokes estandar PASS, despues LongObject8/LongHash7/LongArray7/
ClipboardCase18 PASS contra ese mismo binario, hashes previos/posteriores
iguales, cuatro extras desde los tests del export. Dos pasos acotados.
Manifest y extras en linux-candidate-containers-extra.json. No release,
licencias/install portable/Windows/matriz112 ni nuevo determinismo.

## 31 octubre: Enter sobre propiedad array/hash vacio

Antes el inspector objeto no hacia nada al pulsar Enter sobre array/hash
vacio; array/hash top y otros contenedores ya explican que estan vacios.
Dos fixtures reales antes10/12, sin crash ni mutacion: fallo de feedback,
no perdida de datos. Ahora alerta Array is empty/Hash is empty, conservando
el mismo modelo y regreso al Monitor. No permite agregar elementos ni cambia
politica readonly. Pantallas y log previos retenidos.

53e20eblimpio ObjectEmpty12+TopEmpty12+LongObject8PASS mismoIDE,
20modelos15inventario33docsPASS. Native120x40ambasalertas inspeccionadas,
bordes completos y Resume valores{}y{=>}exactos. NoWindows/cierreM3.

## 31 octubre: titulo del inspector debe seguir el registro seleccionado

Con40elementos End/PageDown movian y editaban el elemento correcto, pero
el titulo seguia V[1..40]: SetCaption solo guarda texto, no repinta. Hash y
array antes8/11 cada fixture, tres fallos de titulo; Resume completo ya
probaba ediciones exactas en1/21/40, no se afirma corrupcion. Ahora repinta
ShowCaption tras SetCaption en ambos inspectores. No cambio de navegacion,
reordenacion, edicion ni estructura del contenedor. Logs/pantallas previos
retenidos. Dos modos del mismo harness no son dos funciones nuevas.

8cd5a01limpio HashNav11ArrayNav11LongHash7LongArray7PASS mismoIDE,
20modelos15inventario33docsPASS. Native120x40hashEndtitulo40 yresaltado40,
Home/PageDowntitulo36yresaltado36 inspeccionados completos;Resumeexacto.
PTY80x25PageDownmueve1a21; no se presupone21en todas las geometrias.

## 31 octubre: cambio de tipo de una propiedad en inspector objeto

Cambiar nValue escalar por {41,2} mostraba el array pero Enter seguia
abriendo editor escalar: despacho usaba cache del tipo inicial. Antes5/6,
Resume ya conservaba array exacto; no perdida de dato. Tras el setter se
actualizan valor y accesibilidad del item desde getter, tambien tras error
del setter. No transaccion de setters con efectos ni actualizacion externa
arbitraria. Se prueba abrir el array tras editar y Resume exacto.

daed4cclimpio Type6Getter6Setter8PASSmismoIDE+20modelos15inventario33docs.
Native120x40arraybrowsertrascambiodetipo inspeccionado,Resume{41,2}exacto.
Getter se invoca explicitamente para refrescar cache tras intentar setter;
no promesa de getter libre de efectos, rollback ni cambios externos.

## 31 octubre: cambio de tipo ampliado a cuatro fixtures

El mismo PTY prueba escalar a array/hash de dos elementos y a array/hash
vacios. Cada fixture exige representacion, Enter abre browser correcto o
alerta vacio, y Resume valor entero exacto.24checks, cuatro fixtures no
cuatro funciones. No nuevo cambio de producto ni getter sin efectos.

## 31 octubre: recuperacion de entorno y regresion de inspectores

Entorno efimero reiniciado; checkout publicado1903975 recuperado sin perdida
conocida de trabajo pendiente. Harbour694428e1 recompilado: version declarada
igual pero hashhbmk2nuevo78e2990e, no identidad de binario heredada.
Make general agoto envolvente durante contrib opcionales; herramientas y
librerias necesarias funcionan y build IDE PASS. Regresion limpia1903975:
Readonly20Depth24Type24Method10ObjectEmpty12 mismo nuevoIDE, dospasos acotados,
20modelos15inventario33docsPASS. No nueva captura/candidato/determinismo,
ni116global/Windows. Evidencia linux-rebuilt-guards-1903975.json.

## 31 octubre: clipboard de siete tipos, pruebas de modelo

Probe separado132checks usa metodos reales Copy/Paste/Cut/Undo/Redo con
say,get,checkbox,button,radiogroup,listbox,combobox. Valores no predeterminados,
handlers con comillas, bindings originales en mayusculas, snapshots completos,
fuente mutada tras Copy y tercer binding unico. Copy no dirty/history; nueva
accion limpia Redo. Todos los campos presentes salvo posicion/binding deben
conservarse exactos. No es gesto PTY/pixels/runtime ni ejecucion de handlers;
se incluyen campos no expuestos de esos tipos solo como datos de modelo.
Runner de modelos ahora21, no21funciones ni cierreM4. Sin producto nuevo.

## 31 octubre: clipboard PTY de siete tipos cargados

63checks reales IDE: F12carga fixture JSON con cada tipo existente, Tab
selecciona,Copy/dosPaste/Cut/UndoRedo/F10 persistencia exacta. Campos no
binding/posicion, comillas/items/handlers y binding unico sin caja. No
creacionF2de todoslos tipos ni escritura inspector de estos fixtures: son
modelos cargados, no se presenta el JSON inyectado como gesto de edicion.
No pixeles/runtime/ejecucionhandlers/Windows ni117aceptacionesglobales.

## 31 octubre: clipboard tras crear cada tipo con F2

Modo --create del mismo harness: siete tipos creados realmente conF2,
63checksCopyPasteCutUndoRedo/F10, tipo y campos del modelo predeterminado.
No se inyecta JSON en este modo, ni se afirma editar todoslos handlers:
la prueba cargada anterior conserva ese alcance distinto. P y R duplicadas
requieren Enterparaaceptarmenu y otropara colocar; primeros probes sin el
segundo Enter fallaron en harness de creacion, corregidos sin producto.
118entradasrunner son117casos/modosPTY+guard, no118funciones/cierre.

## 31 octubre: bindings pegados independientes en el artefacto generado

Fixture checkbox LVAR1 con STATE MarkState(),F12carga/CopyPaste/F10/F9reales.
El PRG F9 se compila, solo instrumentando return para registrar ambas
variables y añadiendo handler de fixture. Dos ejecuciones: Space primero
produce{.T.,.F.};TabSpace segundo produce{.F.,.T.};handler preservado ejecuta
en ambos.9checks, no todosloscontroles/handlers runtime, no pixels/Windows.
No producto nuevo: prueba el efecto real del fixcaseinsensitive5d74cc3.

## 31 octubre: candidato limpio con toolchain reconstruido

Export23ddc8b,strip-debugSHA d4b9d08fe76676981628162a1bb8986b563663c4dec99c55bd603b3a5acd2484.
Ocho smokes estandar y seisextras Type24EmptyChild12HashNav11ArrayNav11
ClipboardRuntime9Case18PASS binario exacto, hashes antes/despues iguales.
Extras dospasosacotados desde export, no119matrizglobal. Manifestretiene
nuevohashcompiler78e2990e. No release/licencias/install/Windows/determinismo.
Evidencia linux-candidate-current-extras.json, no herencia del candidato previo.

## 31 octubre: GET pegado con binding de texto independiente

Fixture GET CVAR1/VALIDMarkState(),cargaCopyPasteF10F9reales,compilaPRGreal
instrumentado solo para registrar AllTrim de ambosvalores. Primeraejecucion
AlphaTab deja{"Alpha",""};segundaTabBetaTab deja{"","Beta"};VALID preservado
se ejecuta enambas.9checks, sin producto nuevo/pixels/Windows ni todoslos
handlers. Complementa checkboxSTATE, no se generaliza a todoslostipos.

## 31 octubre: ComboBox pegado con binding numerico independiente

Fixture NVAR1/STATEMarkState(),F12CopyPasteF10F9reales;PRGrealcompilado,
instrumentacion return para valores. Dos ejecuciones: abrirprimerdropdown,
DownTab produce{2,1};Tabal segundo,SpaceDownTab produce{1,2}. STATEejecuta
ambas.9checks. Sin producto nuevo/pixels/Windows, no todoshandlers/tipos.

## 31 octubre: reconciliar inventario con pruebas recientes

Vinculados Ctrlclipboard/history DSN009..013 a modelos y PTY recientes,
F2sietetipos separado de JSONnondefaults y F9runtime3tipos. Rutas inline
array/hash/object enlazan columnaslargas,navegacion,tipo/empty. Vinculo no
PASS; popupentryclic no se prueba por atajo, nueva redaccion lo conserva.
Inventario regenerado de fuente,15checksPASS,33docs reembebidos. No cambio
producto ni cierre M0/M4 por aumentar contratos.

## 31 octubre: popupclipboard siete tipos

Nuevo --popup reusa fixturesF12sietetipos, pero cada Copy/Paste/Cut/Undo/Redo
abre F2yactiva entrada por mnemonic, duplicadosP/R ciclan+Enter. Primera
exploracion63checksPASS con snapshotdirtyd63eaa68, no defectoenproducto.
Seagrega comprobacionpopupvisible por operacion antesdelcleanrun.
No mouse,pixels,Windows ni cumplimiento global. Runner122=121PTYmodes+guard.

Cleanb8f77d7: popup119PASS=63modelchecks+56popupvisible assertions, seven
fixtures. Case18 and GETruntime9PASS sameIDEf2a5a2af;21modelsPASS plus
15inventory33docs. Durable docs/evidence/linux-clipboard-popup-types.json.
No sourceproduct change, no pixel/mouse/Windows acceptance.

## 31 octubre: matrizDebugFunctions original completada

Clean628b088freshIDEc6463596 completa originalfixedwait sin--idle-settle:
58PASS0FAIL114.25s. Antes solo idle58current y originalpendiente; pendiente
resuelto para esta revision. Se mantienen seis aserciones checkmark soloestado,
no efectos de RunAtStartup/CBTrace/ShowAllGlobals. No visual/Windows/global.
Ledger+log:docs/evidence/linux-debug-functions-original-current.json.
Inventario enlaza17rutas acotadas: popup cuando probado, Fkeys se etiquetan
como tales, Sort solo retencionvista, WorkAreas solo ningunDBF.
No nuevo cierre de milestone ni cambio producto por esta reconciliacion.

## 31 octubre: Window popup efectos acotados

Nueva prueba realpopup Move/SizearrowsEscEnter, Zoomroundtrip charactergrid,
Iconize->Tilereattachbrowser, focuscycle y Resumeexact12locals. Exploratorio
16PASS, sinbugproductenfixture. No pixeles/solapamientoglobal/Windows.
Se vinculan5entradas,97contratosmenu/116acciones no97funcionesaceptadas.
Runner123entradas=122PTYmodes+guard. Modelo layout existente sigue
independiente, no se asume ejecutado por vincular archivo.

Cleana16b3eaWindowpopup16+MonitorMouseScroll7PASSsameIDE9f23f866,
15inventory33docs. docs/evidence/linux-window-layout-popup.json conserva
buildreceipt y logs. No se declara aceptacion pixel ni modelo layout nuevo.

## 31 octubre Q29: Snap no sale del dialogo en bordes impares

Antesmovimientoclamp->round permiteGETrow12col30 conmax11/29, modelo
432PASS2FAIL. Despuesround->reclamp teclado+drag; ClampGhost ya lo hacia.
21modelosPASSdirty186bdbd1, PTY6PASS tras corregir harness: Gduplicado
requiereEnter y primer intento5/6 no era productofallo. Capturasnativas
inspeccionadas120x40,GETcompletoalbordeyUndo10/28,RedoJSONexacto.
No autogrow/politicaoversized/dragcertificado/Windows.98contratosmenu
vinculados de116,runner124=123PTYmodes+guard,no124funcionesPASS.

Cleanfa78719Snap6+ClipboardCase18sameIDE84fd72ea y21modelosPASS,
15inventory33docs. Ledgerdocs/evidence/linux-designer-snap-edges.json.
Capturasnativas de snapshotprecommit, no herencia de pixels al build limpio.

## Q29 seguimiento: dragrealPTY

Modo--drag pulsa primera celdaGET, mueveboton32manteniendopulsacion y
suelta al bordeimpar; seischecks incluidas dimensiones/variable/UndoRedo.
Exploratorio6PASSsin cambioproducto. Nativo anterior solo teclado, no se
convierte en dragpixels. Runner125=124PTYmodes+guard.

Clean5cc04acDrag6Arrows6sameIDEed24ffa6,15inventory33docsPASS,
21modelsultima fa78719. docs/evidence/linux-designer-snap-drag.json.

## 31 octubre: candidateLinux actualizado Q29

Export3b3c606freshstrip-debug SHAea72f2261cc4bcf68fbe3488b1764bf6d89709b9c581a5e2bc50018bccc8d072.
Ocho smokes estandarPASS y seisextrasmismobinariohashinalterado:
SnapArrows6Drag6GETRuntime9ComboRuntime9CheckboxRuntime9WindowLayout16.
Preparacion yextras dos pasosacotados sininterrupcion; no se mezcla con
matrizglobal125,nopixels/Windows/determinism/licenciareleaseready.
Durable docs/evidence/linux-candidate-snap-runtime-extras.json conserva
manifestcompilerhash/deps/strip/testidentity ylogs extras. Binarioqueda
/tmp/hbide-linux-current-candidate-3, no publicacionrelease.

## 31 octubre: Monitor efectos de scopes y Sort

Fixture5variables comprueba menuLocal/Public/Private/Static/All y valores,
Sort cambiaordenrealdeclaracion, agregarscopes mantieneorden, editarprimer
rowordenadoQA llegaaQA77 yResumevector12,77,30,40,50exacto. NoGlobal,
shadowingotroframe,tipos/pixels/Windows. Exploratorio11/16fallosparserincluia
bordertrasnumero, corregido16PASS sincambioproducto. Runner126=125PTY+guard;
102contratosmenu/116no102funcionesaceptadas. Seconservanambosintentos.

Cleandea063dScopes16MouseScroll7sameIDE501cd4f8PASS;15inventory33docs,
21modelos ultima fa78719. Ledgerlinux-debug-monitor-scopes.json conserva
clean yambosexploratorios, nocambio producto ni cierreGlobal/M3.

## Q30: registrar APIsRDD paraHRB y probarWorkAreas conDBF

AntesUnknownunregisteredDBCREATEimpideiniciarfixture,1PASS9FAIL. Diagnostico
OperationtemporalconfirmaDBCREATE, retirado sin cambiarDoBreak. REQUEST
DBCREATE/DBUSEAREA/DBAPPEND/DBCLOSEALL/DBSELECTAREA registra simbolos para
HRB (codigo C ya linkado no implica export). Despues10PASS:2DBF temporales,
aliasALPHA/BETA estructuras/statuscorrectos,paneles,Esc/F6,ResumeALPHA
record1datos exactos. Native120x40capturas ambas inspeccionadas. No todos
RDD/HRB/externalDBF/Windows. Runner127=126PTYmodes+guard;102contratosmenu
no102funcionesaceptadas. Cleanrevisionyregresion siguen abajo.

Clean23bd0afWorkAreas10Scopes16mismoIDE90a92c94y21modelosPASS,
15inventory33docs. docs/evidence/linux-debug-workareas.json. Nativo
precommit separado de buildlimpio; no herenciaWindows/global127.

## Q30 Script tambien usa registroRDD

--script corre mismoDBFfixture dosveces desdeRunScript, valorALPHA/record1/
NAMEpadded/QTY11 exacto, retornoeditor sinloadererror yfuenteinalterada.
ExploratorioScript5WorkAreas10mismoIDE PASS; sin nuevo cambio producto.
Runner128=127PTYmodes+guard,no128funciones. No todoRDD/HRB niWindows.

Clean123a73cScriptDBF5WorkAreas10ScriptScreen7sameIDE56fb2196PASS.
linux-script-dbf.jsonretieneidentity+logs;21modelsultima23bd0af.

## 31 octubre candidateLinux con registroRDD

Export6cfda9d strippedSHA81daf8ccd89fc1b1854712354193ad46ceb810edab85785ecebbbed04dcbd059.
8smokesestandarPASS+6extrasWorkAreas10ScriptDBF5Snap6Drag6GET9Combo9PASS
mismobinariohashantes/despuesinalterado. Dospasosacotadossininterrupcion.
Manifest+logsdocs/evidence/linux-candidate-rdd-extras.json. No release,
licenciaaclarada,Windows,instalador,nuevodeterminismo/global128. Localcandidate
/tmp/hbide-linux-current-candidate-4,no distribucionautorizadaimplícita.

## 31 octubre: ToCursor/Breakpoint popup efectos

DosRunCursorparanen6/7conlocal61/101antesmutacion;PointBreakpointagrega8,
Go detienecon151anteswrite,segundopopupquitaBP yGo escribe151exacto.
FileResume no ejecutar, esvolververfuente segun upstream; primerharness
lo confundio y esperaba NoBreakpoints inexistente. Se corrige harness,
no producto. AssertionslistBPseanclan0)8module, no cualquier8decaption.
10PASSexploratorio,104menucontracts/116no104funciones;runner129=128PTY+guard.
NoFileResumecursorlocation acceptance ni invalidthread/multifile/Windows.

Cleanb0b8972CursorPopup10Scopes16WorkAreas10sameIDEc45bf334PASS,
15inventory33docs;21modelosultima23bd0af. linux-debug-cursor-popup.json
retieneclean y exploratorioconexpectativaequivocada, sin productfix.

## 31 octubre regresion conjunta reciente

Clean8e15ed2 13modosPTY mismoIDE4b38b470, dospasosacotadossininterrupcion
nireintentos:ScriptDBF,WorkAreas,CursorPopup,Scopes,SnapArrows/Drag,
GET/Combo/CheckboxRuntime,Getter/Setter,TypeChange,WindowLayout. TodosPASS,
21modelos15inventory33docsPASS. linux-recent-joint-8e15ed2.jsonretiene
receipts/logs/models. No global129,Windows,pixelsnuevo,cierre dehitos.

## Q31 Help debugger ignora clicfuera de topics

Antes9/10:Keysbodyclick seleccionaWatchsegunfila. Ahora hit-test restringido
alrectangulobrowserizquierdo;body/outside conservanKeys,topiccolumnclic
abreFunction.12checks incluyen5menus exactbody,Resumevector/bytesexactos.
Native120x40body/Functioncapturas inspeccionadas. No paginas/geometrias/
Windowsglobal.109contratosmenu/116no109funciones;runner130=129PTY+guard.

Cleanc830b19Help12Cursor10sameIDEee121db4 y21modelosPASS,
15inventory33docs. linux-debug-help-click.json. Nativo precommit
separado, no herenciapixels albuildlimpio. Milestones nocerrados.

## 31 octubre segundo reinicio entorno, evidencia nueva

05:15checkout/toolchain/tmpdesaparecidos, ultimoHEADb3efec2publicadoprotegido.
16modospreviosPASSobservadosentranscriptperoledgerlocalperdido, no evidencia
durable/global. Recuperadorepo limpio yHarbour694428e1, hbmk2SHA1f80870f;
makegeneral120sinterrumpidooptionalcontrib, compiler/coreoperativos.
Nueva pasada fuenteigualb3efec2IDE7d6a9301Help12WorkAreas10ScriptDBF5Snap6
Drag6+21modelos15inventory33docsPASS. linux-second-rebuild-b3efec2.json.
No heredar candidateanteriorbinarios/pixels/determinismo;carpeta candidate4
perdida,manifestpublicadosiguedurable. No producto perdido ni nuevo cierre.

## 31 octubre candidateLinux reconstruido con Q31

Export e0d4b23, compiler1f80870f, strippedSHA
edfb42126ea4074672de9b47bc6ced9ee8427e6d2d85ca07735da3291182d86f.
8smokesestandarPASS + Help12WorkAreas10ScriptDBF5Snap6Drag6PASS
mismo binario verificado antes/despues. Dos pasos acotados, sin retries.
Manifest/logs en linux-candidate-current-help-rdd.json. Carpeta temporal
/tmp/hbide-linux-current-candidate-5. No release, licencia, Windows,
instalador, nueva inspeccion pixels ni cierre de hitos.

## 31 octubre Tracepoint validacion modal focal

Nueva suite16checks:Cancel/invalidadd sinTP,add n=1,edit n+2=3
conservaTP,Cancel/invalidedit/DeleteCancelconservanexpresionexactaCLD;
Go paratrascambioeval4antesoutput,Delete+Go escribe2fuenteinalterada.
Exploratorio16PASS sobrecandidate e0d4b23, no cambio producto.
Runner131=130modosPTY+guard,no131funciones. No nuevos pixels,Windows
ni todos indices/sideeffects. Pendiente clean separado.

Cleanfd3d2acTracepoint16Watch14mismoIDEe1e4e1f0PASSsinretry,
15inventory33docsPASS. linux-debug-tracepoint-modal.json retiene
receipt+logs. No se heredan modelos anteriores a esta fuente.

Cleanbc64f13Stack7MonitorMouse7Help12sameIDEef72604fPASS,
21modelos15inventory33docsPASS. linux-debug-stack-border.json
retieneidentidades/logs. NativeMAIN101/CHILD202inspeccionados,
peroentregaclicfisico titulo no demostrada; no heredar comoPTYPASS.

## 31 octubre frame shadowing real slots

Nueva suite9PASSexploratorioSHAREDcaller101/callee202:editarcaller707
no cambiacallee;editarcallee808no cambiacaller;volver ambosretienevalores.
Resumeexact{707,809}pruebadosslotsVMdistintosconincrementoposterior.
Sinproductfix,nopixelsnuevos,solo2framesnumericos,Windowsno.
Runner132=131modosPTY+guard,no132funciones. Clean pendiente.

Clean03f58d0Shadow9Stack7Tracepoint16WorkAreas10Scopes16sameIDE51b06c97
PASSsinretry,15inventory33docsPASS. linux-debug-shadowed-frame.json
retieneidentidad/logs, sin heredar modelos ni pixels anteriores.

## 31 octubre File Resume viewing cursor comprobado

AmpliadaCursorPopup11checks: tras BP8stop ygoto3, FileResume noejecuta
yPointBreakpointagrega8(no3), probadoenlistanclada;remove+Go151exact.
Exploratorio11PASS,sinproductfix. NuevoenlaceDBG002,110contratos/116
acciones no110funciones. Unfichero, noRestart niWindows.

Clean379c12aCursor11Shadow9WindowLayout16sameIDE3e964e7cPASSsinretry,
15inventory33docsPASS. linux-debug-resume-viewing-cursor.json.

## 31 octubre clipboard ListBox/RadioGroup runtime

Dos suites9checks cadauna: F12cargaNVAR1,CopyPastegeneraNVAR2independiente,
F9artifactcompila;seleccionprimer/segundocontrolproduce{2,1}/{1,2},
STATEListBox/VALIDRadioGrouppreservadosse ejecutan. Instrumentarsoloreturn.
Exploratorio9+9PASS,sinproductfix,nopixels/Windows/allhandlers.
Runner134=133modosPTY+guard,no134funciones. Clean pendiente.

Clean869351cList9Radio9Combo9GET9Checkbox9sameIDE679499f4PASSsinretry,
15inventory33docsPASS. linux-clipboard-five-runtime.json retieneidentidad/logs.

## Q33 Replace no descarta busquedas solo espacios

Find/modalaceptabablancosperoReplaceAllusabaEmpty:antes2/4porcount0
ybytesinalterados. CambiadoLen==0, unespacio4/twoespacios1reemplazos.
NuevaPTY10PASSinclSavebytesmixedEOL/TAB/trailing,UndoRedo/Cancel.
Native120x40count4/resultadobordescompletosinspeccionados,Save/Undoexactos.
Runner135=134modosPTY+guard. No Unicodeexpansion/multiline/Windows.
Primerfixtureexploratoriosinespaciosnocertificababytes;corregidoantesfix.

Clean7fd0a6bSpaces10EditMenu37sameIDE7b9725f0PASSsinretry,
21modelos15inventory33docsPASS. linux-replace-spaces.jsonretieneidentity/logs.

## 31 octubre candidate con Q32 y Q33

Export4ddf0b3 strippedSHAad4b24b8ed4e6cecaf90ea63624e2e9145696b5d9fee5336d8a0049220154e18.
8smokesestandar+Spaces10Stack7Shadow9Cursor11Tracepoint16List9Radio9
PASSmismobinariohashinalterado,dospasosacotadossinretry. Manifest/logs
linux-candidate-spaces-frames.json. Localcandidate6temporal,no entrega
release/licencia/Windows/instalador/nuevos pixels/matriz135global.

## 31 octubre pasted PushButton actual F9

NuevaPTY12checks:firstEnter/TabsecondEnter ejecutan customAction/Focus
yDlgdevuelve.T.;F9retieneambosAction/Focus/style/acceleratortext.
ExploratorioEnterPASS. PrimerharnessesperabaAltQejecutaseautomatico,
pero coreAcceleratorseleccionafoco; no productfix niaceptacionacelerador.
Runner136=135PTY+guard,no136funciones. Noallhandlers/pixels/Windows.

Clean27c724eButton12List9Radio9sameIDE37a39471PASSsinretry,
15inventory33docsPASS. linux-pasted-button-runtime.jsonretieneidentity/logs.

## Q34 Replace no se fusiona con typing previo/posterior

Una lineaalpha,typingX,Replaceomega:antesUndoquitabaXtambien(2/3).
PushOpahorarecibelSeparateparamopcionalymarcaentrada;Replace.T.no
fusionaprevianiadmitetypingposterior. Filtrolegado3slotsconservado.
DespuesPTY6PASS/6modelchecksnew;typingnormalcontinuafusionando.
Native120x40UndoXalpha/RedoXomegainspeccionadosSaveexactos.
Runner137=136PTY+guard. No otroscomandosundosplit niWindows/global.

Clean880fae2Boundary6Spaces10EditMenu37sameIDEcfd57268PASSsinretry,
21modelos15inventory33docsPASS. linux-replace-undo-boundary.json
retieneidentity/logs y6newrepaintchecksnormaltypingfusion/cleanRedo.

## Q35 Identity Replace does not dirty unchanged text

Replacing alpha with alpha counted one match but marked the clean buffer dirty
without an undo entry. Before: 2/3 PTY checks, Close requested a save.
Replace now compares each output line byte-for-byte before applying changes.
The match count is unchanged; identical output leaves dirty state and redo intact.
Three PTY checks and three new model checks cover this case.
Native 120x40 count and Close frames inspected, including full lower borders.
Runner 138 entries = 137 PTY modes plus one guard, not accepted functions.
No Unicode case expansion, Windows or global acceptance claim.

Clean 3516276: Identity3, Boundary6 and Spaces10 on the same binary fe0224bc,
without retry. All 21 model probes, 15 inventory tests and 33 embedded documents
pass. Identity ledger: docs/evidence/linux-replace-identity.json.

## Q36 Paste accepts a copied whitespace-only line

Copy of three spaces followed by Paste did nothing because Empty() discarded it.
Before 2/4 PTY checks; after Len()>0, four checks pass including exact disk
content, Undo and Redo. Four new model checks include TAB plus spaces.
Native 120x40 Paste row3 and Undo row2 inspected with complete lower frames;
exact bytes verified separately. No empty-line clipboard policy change.
Runner139 entries = 138 PTY modes plus guard, not accepted functions.
No Windows or whole-IDE acceptance.

Clean797dea5: Clipboard4, Identity3, Boundary6 and Spaces10 pass on the
same binary14f42d97, without retry; all21models,15inventory,33docs pass.
Ledger docs/evidence/linux-clipboard-spaces.json retains source/hash/logs.
IDE012 acceptance link added after clean run, no product changes.

## Q37 Clear stale selection on shorter reload

A clean buffer selected from row3 back to row1, followed by external reload
of one line, retained anchor row3. Typing then failed (before2/4PTY).
LoadText now clears old selection before replacing lines. After4/4PTY;
four model checks cover selection reset, typing and clean Undo.
First exploratory fixture anchor row1 did not crash and had a wrong cursor
expectation; revised anchor row3 reproduced the real failure before fixing.
Native120x40 Xfresh and Undo fresh inspected with complete lower frames;
saved bytes exact. No filename-UndoLoad policy change or Windows claim.
Runner140=139PTY modes plus guard.

Cleanf758bbe: ReloadSelection4, Clipboard4, Identity3 plus external-change
and unreadable-reload suites pass on same binaryae8c65e2 in two bounded steps,
without retry;21models15inventory33docs pass.
Ledger docs/evidence/linux-reload-selection.json retains identity and logs.

## Q38 Clear stale range after Delete Line

Selection from row3 to row1 followed by Delete Line left an out-of-range
anchor. Next typing failed (before1/3PTY, error dialog).
Delete Line now clears the range before removing the current line.
After6/6PTY cover typing, exact saved bytes, separate Undo typing/deletion
and Redo. Four new model checks cover reset, typing and clean Undo.
Native120x40 Xbeta/gamma then Undo beta/gamma inspected, full lower frames;
bytes exact. Does not change Cut marked-range semantics or Windows claim.
Runner141=140PTY modes plus guard.

Clean8f256d5: DeleteSelection6, ReloadSelection4, Clipboard4 and breakpoint
delete suite pass on same binary95a08995 without retry;21models,15inventory,
33docs pass. Ledger docs/evidence/linux-delete-selection.json.

## 31 October candidate with Q34-Q38 editor fixes

Export2f13366 stripped SHA0cefac5f35df4fc1d716603511230fcc221b5cedc05e0077889de6d65f6ea55e.
Eight standard smoke suites plus DeleteSelection6, ReloadSelection4,
Clipboard4, Identity3, Boundary6 and Spaces10 pass on the exact candidate.
Binary hash unchanged; two bounded steps without retries.
Manifest/toolchain/dependencies/logs retained in linux-candidate-editor-selection.json.
Local temporary candidate7, not release/installer/Windows/license clearance,
full141-mode regression, new determinism proof or new visual acceptance.

## Q39 Identical overtype does not falsely dirty clean buffer

Overtyping first a of alpha with a left bytes unchanged but marked dirty,
with no Undo entry; before2/3PTY, Close asked to save. Dirty now set only
when the edited line differs byte-for-byte; selection deletion keeps its
own dirty state. After3/3PTY and four new model checks: cursor advancement,
real overwrite dirty, no-op redo preservation and redo exact.
Native120x40 OVR alpha/col2 and Close noname inspected, full lower frames;
disk alpha unchanged. Runner142=141PTY modes plus guard.
No blanket no-op editing, Windows or global acceptance.

Cleana4857f7: Overtype3, Identity3, DeleteSelection6 and ReloadSelection4
pass same binary2533a40e without retry;21models,15inventory,33docs pass.
Ledger docs/evidence/linux-overtype-identity.json.

## 31 October no-op boundary keys acceptance

New six-check PTY: Delete at EOF and Backspace at BOF on clean alpha close
without save prompt; both preserve redo of earlier undone X insertion.
Exploratory6PASS, no product fix. Runner143=142PTY modes plus guard.
Not blanket no-op contract, visual or Windows acceptance.

Cleanc376c81: BoundaryNoop6, Overtype3, Identity3 and DeleteSelection6 pass
same binaryc3809152 without retry;15inventory33docs pass. No new model run.
Ledger docs/evidence/linux-boundary-noop.json.

## Q40 Clear stale selection after Duplicate Line

Selection row3->row1, Duplicate Line then typing used the old range and
silently removed source text instead of inserting into the duplicate.
Before5/6PTY. Duplicate now clears the range before its line command.
After6/6PTY: exact disk, Undo typing, Undo duplicate and Redo; four new
model checks include clean Undo. Native120x40 alpha/Xalpha/beta/gamma
and Undo alpha/alpha/beta/gamma inspected with full lower frames.
Runner144=143PTY modes plus guard. No marked Cut semantic change,
Windows or global acceptance.

Clean0fa7d14: Duplicate6, Delete6, Reload4 and Overtype3 pass same
binary7c95d9d0 without retry;21models15inventory33docs pass.
Ledger docs/evidence/linux-duplicate-selection.json.

## 31 October joint recent editor regression

Clean98f3dfd: nine recent editor suites pass same binary873f807d without
retry, plus21models15inventory33docs. Ledger linux-editor-recent-joint.json.
Roadmap now indexes Q33-Q40 with individual provenance and current runner144,
without aggregating old per-fix runs into current acceptance. No product change,
full144mode regression, Windows, new visuals or M1 closure.

## Q41 Share editor clipboard across documents

Copy in source alpha followed by Open destination beta and Paste did nothing:
clipboard lived in each editor instance. Changed cClipboard to CLASSDATA;
Undo/Redo remain per document. PTY6PASS, four new model checks source clean,
destination Undo/Redo. Initial fixture wrongly expected CRLF in unterminated
LF-default document; corrected expected LF before acceptance.
Native120x40 destination beta/alpha and Undo beta inspected, full frames;
source disk alpha unchanged. Not OS clipboard or other-app integration.
Runner145=144PTY modes plus guard. No Windows/global claim.

Clean764472e: ClipboardMultidoc6, Spaces4, Duplicate6 and Delete6 pass
same binarye3e1a478 without retry;21models15inventory33docs pass.
Ledger docs/evidence/linux-clipboard-multidoc.json.

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

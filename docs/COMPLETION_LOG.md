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

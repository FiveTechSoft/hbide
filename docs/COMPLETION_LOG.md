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

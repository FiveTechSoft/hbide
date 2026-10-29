#!/usr/bin/env python3
"""Inventory source wiring, not proof of behaviour. --check-stubs is a release gate."""
import argparse, json, pathlib, re, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCES = [('IDE', 'hbide.prg'), ('DBG', 'hbdebug/dbgmenu.prg'), ('DSN', 'designer.prg')]

def inventory():
    entries = []
    for prefix, source in SOURCES:
        lines = (ROOT / source).read_text().splitlines()
        section = 'Palette' if prefix == 'DSN' else ''
        number = 0
        for i, line in enumerate(lines):
            m = re.search(r'MENUITEM\s+"([^"]+)"', line)
            if not m:
                continue
            label = m.group(1).replace('~', '').strip()
            j, parts = i, [line]
            while parts[-1].rstrip().endswith(';') and j + 1 < len(lines):
                j += 1
                parts.append(lines[j])
            block = ' '.join(parts)
            if 'ACTION' not in block:
                section = label
                continue
            action = block.split('ACTION', 1)[1].strip()
            action = re.split(r'\s*;\s*CHECKED', action)[0].rstrip(' ;')
            number += 1
            entries.append(dict(id=f'{prefix}-{number:03}', source=source, line=i+1,
                                menu=section, label=label, action=action,
                                wiring='stub' if ':NotSupported()' in action else 'wired',
                                linux='acceptance_not_linked', windows='not_validated_current_source'))
    routes = []
    for source, begin, end in [
        ('hbdebug/debugger.prg', 'METHOD DoCommand(', 'METHOD '),
        ('designer.prg', 'METHOD Activate(', 'METHOD '),
        ('projectui.prg', 'FUNCTION HBIDEProjectDesktop', 'FUNCTION '),
    ]:
        lines = (ROOT / source).read_text().splitlines()
        active = False
        for i, line in enumerate(lines):
            if not active:
                if line.startswith(begin):
                    active = True
                else:
                    continue
            elif line.startswith(end):
                break
            if re.match(r'\s*(?:CASE|case)\s', line):
                routes.append(dict(source=source, line=i+1, condition=line.strip(),
                                   status='route_only_not_separate_feature'))
    return entries, routes

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--json', action='store_true')
    p.add_argument('--check-stubs', action='store_true')
    args=p.parse_args()
    menus,routes=inventory()
    stubs=[m for m in menus if m['wiring']=='stub']
    report={'scope':'Source inventory only. No runtime or platform certification.',
            'menus':menus,'dispatch_routes':routes,
            'counts':{'menu_actions':len(menus),'stub_menu_actions':len(stubs),'dispatch_routes':len(routes)}}
    if args.json:
        print(json.dumps(report,indent=2))
    else:
        print('# Inventario de acciones hbide\n')
        print('Generado de la fuente. `wired` solo significa que hay una llamada, no que funcione.\n')
        print('No convertir este numero en porcentaje: varias rutas pueden ejecutar la misma funcion.\n')
        print('| ID | Menu | Accion | Fuente:linea | Conexion | Linux | Windows |')
        print('| --- | --- | --- | --- | --- | --- | --- |')
        for m in menus:
            print(f"| {m['id']} | {m['menu']} | {m['label']} | {m['source']}:{m['line']} | {m['wiring']} | Pendiente vincular aceptacion | Fuente actual sin validar |")
        print('\n## Rutas de teclado y comandos\n')
        print('Estas condiciones amplian el inventario fuera del menu. No se suman como funciones independientes.\n')
        print('| Fuente:linea | Condicion |')
        print('| --- | --- |')
        for r in routes:
            condition=r['condition'].replace('|','&#124;')
            print(f"| {r['source']}:{r['line']} | `{condition}` |")
        print('\n## Gate de cierre\n')
        print(f"{len(menus)} acciones de menu; {len(stubs)} stubs. Faltan acciones de inspector, modales, barra de ayuda y rutas globales. No es aun el inventario exhaustivo.")
        print('`python scripts/audit_completion_surface.py --check-stubs` falla mientras haya stubs visibles.')
    return int(args.check_stubs and bool(stubs))

if __name__=='__main__':
    sys.exit(main())

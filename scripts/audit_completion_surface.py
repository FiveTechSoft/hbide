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
        ('designer.prg', 'METHOD InspectorKey(', 'METHOD '),
        ('designer.prg', 'METHOD InspEdit(', 'METHOD '),
        ('hbide.prg', 'METHOD Activate(', 'METHOD '),
        ('help.prg', 'FUNCTION HBHelpInput(', 'FUNCTION '),
        ('help.prg', 'FUNCTION HBIDEHelpOpen(', 'FUNCTION '),
        ('editor.prg', 'METHOD EditKey(', 'METHOD '),
        ('editor.prg', 'METHOD MoveCursor(', 'METHOD '),
        ('hbdebug/debugger.prg', 'METHOD PROCEDURE HandleEvent(', 'METHOD '),
        ('hbdebug/debugger.prg', 'METHOD PROCEDURE CommandWindowProcessKey(', 'METHOD '),
        ('hbdebug/debugger.prg', 'METHOD PROCEDURE CodeWindowProcessKey(', 'METHOD '),
        ('designer.prg', 'METHOD EditProperties(', 'METHOD '),
        ('designer.prg', 'METHOD DlgProperties(', 'METHOD '),
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
                                   context=begin, status='route_only_not_separate_feature'))
    return entries, routes

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--json', action='store_true')
    p.add_argument('--check-stubs', action='store_true')
    args=p.parse_args()
    menus,routes=inventory()
    stubs=[m for m in menus if m['wiring']=='stub']
    specs=json.loads((ROOT/'tests/completion_acceptance.json').read_text())
    acceptance=specs['menus']
    modal_contracts=specs.get('modal_contracts',[])
    for spec in modal_contracts:
        for test in spec['tests']:
            if not (ROOT/'tests'/test).is_file():
                raise SystemExit('Missing modal acceptance test: '+test)
    known={m['id'] for m in menus}
    labels={m['id']:m['label'] for m in menus}
    for ident, spec in acceptance.items():
        if ident not in known:
            raise SystemExit('Unknown acceptance ID: '+ident)
        if spec.get('expected_label') != labels[ident]:
            raise SystemExit('Acceptance label mismatch: '+ident+' expected '+str(spec.get('expected_label'))+' actual '+labels[ident])
        for test in spec['tests']:
            if not (ROOT/'tests'/test).is_file():
                raise SystemExit('Missing acceptance test: '+test)
    for m in menus:
        m['acceptance']=acceptance.get(m['id'])
    report={'scope':'Source inventory only. No runtime or platform certification.',
            'menus':menus,'dispatch_routes':routes,'modal_contracts':modal_contracts,
            'inspector_fields': [dict(line=i+1, label=m.group(1), key=m.group(2), kind=m.group(3))
                for i,line in enumerate((ROOT/'designer.prg').read_text().splitlines())
                if (m := re.search(r'AAdd\( aFields, \{ \"([^\"]+)\",\s*\"([^\"]+)\",\s*\"([^\"]+)\"',line))],
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
            linux='Pruebas vinculadas; ver ledger' if m['acceptance'] else 'Pendiente vincular aceptacion'
            print(f"| {m['id']} | {m['menu']} | {m['label']} | {m['source']}:{m['line']} | {m['wiring']} | {linux} | Fuente actual sin validar |")
        print('\n## Contratos y pruebas vinculadas\n')
        print('Vinculo no significa PASS ni cobertura completa. Revisar ledger con revision/hash exactos.\n')
        for ident, spec in acceptance.items():
            links=', '.join('['+t+'](../tests/'+t+')' for t in spec['tests'])
            print(f"- {ident}: {spec['contract']} Pruebas: {links}")
        print('\n## Contratos modales y edicion inline vinculados\n')
        print('Cobertura focal de rutas reales. Vinculo no significa PASS ni aceptacion de todos los campos; revisar ledger.\n')
        for spec in modal_contracts:
            links=', '.join('['+t+'](../tests/'+t+')' for t in spec['tests'])
            print(f"- {spec['id']} ({spec['surface']}): {spec['contract']} Pruebas: {links}")
        print('\n## Campos de inspector\n')
        print('| Campo | Clave | Tipo | Fuente:linea | Aceptacion |')
        print('| --- | --- | --- | --- | --- |')
        for field in report['inspector_fields']:
            print(f"| {field['label']} | {field['key']} | {field['kind']} | designer.prg:{field['line']} | Pendiente vincular prueba especifica |")
        print('\n## Rutas de teclado y comandos\n')
        print('Estas condiciones amplian el inventario fuera del menu. No se suman como funciones independientes.\n')
        print('| Fuente:linea | Condicion |')
        print('| --- | --- |')
        for r in routes:
            condition=r['condition'].replace('|','&#124;')
            print(f"| {r['source']}:{r['line']} | `{condition}` |")
        print('\n## Gate de cierre\n')
        print(f"{len(menus)} acciones de menu; {len(stubs)} stubs. Incluye rutas de inspector, ayuda y bucle IDE; faltan campos de modales y gestos; rutas del editor incluidas, sin aceptacion completa. No es aun el inventario exhaustivo.")
        print('`python scripts/audit_completion_surface.py --check-stubs` falla mientras haya stubs visibles.')
    return int(args.check_stubs and bool(stubs))

if __name__=='__main__':
    sys.exit(main())

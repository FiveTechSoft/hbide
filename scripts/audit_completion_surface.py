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

def modal_fields():
    """Source field declarations with their explicit enclosing conditions.
    Conditions are preserved, not evaluated as acceptance or control coverage.
    """
    lines=(ROOT/'designer.prg').read_text().splitlines()
    rows=[]
    for surface in ['EditProperties','DlgProperties','SelectFileName']:
        start=next(i for i,line in enumerate(lines) if line.startswith('METHOD '+surface+'('))
        end=next((i for i in range(start+1,len(lines)) if lines[i].startswith('METHOD ')),len(lines))
        stack=[];seen={}
        for i in range(start+1,end):
            line=lines[i];text=line.strip()
            if text.lower().startswith('if '):stack.append(text[3:])
            elif text.lower().startswith('elseif ') and stack:stack[-1]=text[7:]
            elif text.lower()=='else' and stack:stack[-1]='ELSE of '+stack[-1]
            elif text.lower()=='endif' and stack:stack.pop()
            match=re.search(r'@ .*?\bGET\s+(\w+)(.*)',line)
            if not match:continue
            var,tail=match.groups();seen[var]=seen.get(var,0)+1
            kind='button' if 'PUSHBUTTON' in tail else ('checkbox' if 'CHECKBOX' in tail else 'value')
            picture=re.search(r'PICTURE "([^"]*)"',tail)
            following=' '.join(lines[i:min(i+4,end)])
            label=re.search(r'(?:Say\([^\n]*?|CAPTION)\s*"([^"]+)"',following)
            position=re.search(r'oDlg:nTop \+ (\d+), oDlg:nLeft \+ (\d+)',line)
            if position and kind=='value':
                row,col=map(int,position.groups())
                labels=[(int(c),t) for r,c,t in re.findall(r'oDlg:Say\( (\d+), (\d+), "([^"]+)"',following) if int(r)==row and int(c)<=col]
                if labels:
                    label_text=max(labels)[1]
                else:label_text=label.group(1).strip() if label else ''
            else:label_text=label.group(1).strip() if label else ''
            rows.append(dict(id='DSN-FIELD-'+surface+'-'+var+'-'+str(seen[var]),surface=surface,
                variable=var,kind=kind,picture=picture.group(1) if picture else '',
                label=label_text,source='designer.prg',line=i+1,
                conditions=list(stack),acceptance='Pending field-specific acceptance; surface contracts separate'))
    return rows

def modal_control_pairs(fields):
    """Strict evaluator for the observed type-only guards. Unknown syntax fails."""
    source=(ROOT/'designer.prg').read_text()
    constants=dict(re.findall(r'^#define (DSN_\w+)\s+"([^"]+)"',source,re.M))
    controls=['DSN_SAY','DSN_GET','DSN_CHECKBOX','DSN_BUTTON','DSN_RADIO','DSN_LISTBOX','DSN_COMBOBOX']
    def allows(condition,control):
        condition=condition.strip()
        if condition.startswith('(') and condition.endswith(')'):condition=condition[1:-1].strip()
        if ' .or. ' in condition:return any(allows(part,control) for part in condition.split(' .or. '))
        match=re.fullmatch(r'oCtrl\[ "type" \] (==|!=|\$) (.+)',condition)
        if not match:raise ValueError('Unresolved modal condition: '+condition)
        op,rhs=match.groups()
        if op=='$':
            terms=rhs.split(' + "|" + ')
            if any(term not in controls for term in terms):raise ValueError('Unknown modal type set: '+rhs)
            return constants[control] in '|'.join(constants[t] for t in terms)
        if rhs not in controls:raise ValueError('Unknown modal type: '+rhs)
        return (control==rhs) if op=='==' else (control!=rhs)
    pairs=[]
    for field in fields:
        targets=controls if field['surface']=='EditProperties' else ['dialog' if field['surface']=='DlgProperties' else 'filename']
        for control in targets:
            if all(allows(c,control) for c in field['conditions']):
                pairs.append(dict(id=field['id']+'-'+control,declaration_id=field['id'],
                    control=constants.get(control,control),surface=field['surface'],variable=field['variable'],
                    acceptance='Pending field-specific acceptance; source condition expansion only'))
    return pairs

def ide_modal_fields():
    """Bounded IDE modal declarations, including free-form non-GET inputs."""
    lines=(ROOT/'hbide.prg').read_text().splitlines();rows=[]
    for surface in ['GotoLine','CompilerFlags','ReplaceDialog','FindDialog','RunArguments','DisplayOpts','ProjectOpen','OpenFile','SaveAs','HelpPick','HelpIndex']:
        start=next(i for i,line in enumerate(lines) if line.startswith('METHOD '+surface+'('))
        end=next((i for i in range(start+1,len(lines)) if lines[i].startswith('METHOD ')),len(lines))
        seen={}
        for i in range(start+1,end):
            line=lines[i];match=re.search(r'^\s*@ .*?\bGET\s+(\w+)',line)
            free=re.search(r'aIn := HBIDE_DlgInput\( (.*) \)',line)
            if not match and not free:continue
            if match:
                variable=match.group(1)
                # Continuation belongs to this declaration, never the next GET.
                parts=[line];j=i
                while parts[-1].rstrip().endswith(';') and j+1<end:
                    j+=1;parts.append(lines[j])
                block=' '.join(parts)
                kind=next((k.lower() for k in ['PUSHBUTTON','CHECKBOX','RADIOGROUP','LISTBOX'] if k in block),'value')
                caption=re.search(r'CAPTION "([^"]+)"',block)
                label=caption.group(1).strip() if caption else variable
            else:
                args=[part.strip() for part in free.group(1).split(',')]
                variable=args[3];kind='freeform_input';label=variable
            seen[variable]=seen.get(variable,0)+1
            rows.append(dict(id='IDE-FIELD-'+surface+'-'+variable+'-'+str(seen[variable]),
                surface=surface,variable=variable,kind=kind,label=label,source='hbide.prg',line=i+1,
                acceptance='Pending field-specific link; existing menu tests do not certify every field'))
    return rows

def debugger_inputs():
    """Call sites, not unique fields or proof of editability/runtime acceptance.
    Keep raw argument/guard context: dynamic titles and read-only inspectors
    cannot safely be converted into a static GET denominator.
    """
    rows=[]
    for path in sorted((ROOT/'hbdebug').glob('*.prg')):
        lines=path.read_text().splitlines();context='';seen={}
        for i,line in enumerate(lines):
            if re.match(r'^(?:METHOD|FUNCTION|STATIC FUNCTION) ',line):
                context=line.strip();continue
            if line.lstrip().startswith('//'):continue
            match=re.search(r'(::InputBox|__dbgInput|H[Bb]DbInput\(\):new|HbDbInput\(\):new)\(',line)
            if not match:continue
            api=match.group(1)
            parts=[line];j=i
            while parts[-1].rstrip().endswith(';') and j+1<len(lines):
                j+=1;parts.append(lines[j])
            block=' '.join(part.strip() for part in parts)
            kind='inputbox' if api=='::InputBox' else ('inline_input' if api=='__dbgInput' else 'input_constructor')
            readonly=kind=='inputbox' and bool(re.search(r',, \.F\. \)',block))
            key=(context,kind);seen[key]=seen.get(key,0)+1
            method=re.search(r'(?:METHOD(?: PROCEDURE)?|FUNCTION) (\w+)',context)
            surface=method.group(1) if method else 'unknown'
            rows.append(dict(id=f'DBG-INPUT-{path.stem}-{surface}-{kind}-{seen[key]}',
                source=str(path.relative_to(ROOT)),line=i+1,context=context,kind=kind,
                api=api,call=block,mode='explicit_readonly' if readonly else 'editable_or_dynamic',
                preceding_source=' '.join(l.strip() for l in lines[max(0,i-4):i]),
                acceptance='Pending call-specific acceptance; shared implementation is not caller coverage'))
    return rows

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
            'debugger_inputs':debugger_inputs(),'menus':menus,'ide_modal_fields':ide_modal_fields(),'dispatch_routes':routes,'modal_contracts':modal_contracts,'modal_fields':modal_fields(),'modal_control_pairs':modal_control_pairs(modal_fields()),
            'inspector_fields': [dict(line=i+1, label=m.group(1), key=m.group(2), kind=m.group(3))
                for i,line in enumerate((ROOT/'designer.prg').read_text().splitlines())
                if (m := re.search(r'AAdd\( aFields, \{ \"([^\"]+)\",\s*\"([^\"]+)\",\s*\"([^\"]+)\"',line))],
            'counts':{'menu_actions':len(menus),'stub_menu_actions':len(stubs),'dispatch_routes':len(routes),'modal_field_declarations':len(modal_fields()),'modal_control_pairs':len(modal_control_pairs(modal_fields())),'ide_modal_declarations':len(ide_modal_fields()),'debugger_input_calls':len(debugger_inputs())}}
    field_specs=specs.get('modal_field_acceptance',{})
    pair_ids={r['id'] for r in report['modal_control_pairs']}
    for ident,spec in field_specs.items():
        if ident not in pair_ids:raise ValueError('Unknown modal pair acceptance ID: '+ident)
        for test in spec['tests']:
            if not (ROOT/'tests'/test).is_file():raise ValueError('Missing modal pair test: '+test)
    for pair in report['modal_control_pairs']:
        if pair['id'] in field_specs:pair['acceptance']=field_specs[pair['id']]
    ide_specs=specs.get('ide_modal_field_acceptance',{})
    ids={r['id'] for r in report['ide_modal_fields']}
    for ident,spec in ide_specs.items():
        if ident not in ids:raise ValueError('Unknown IDE modal field ID: '+ident)
        for test in spec['tests']:
            if not (ROOT/'tests'/test).is_file():raise ValueError('Missing IDE modal field test: '+test)
    for field in report['ide_modal_fields']:
        if field['id'] in ide_specs:field['acceptance']=ide_specs[field['id']]
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
        print('\n## Declaraciones de campos modales\n')
        print('Extraidas de EditProperties/DlgProperties/SelectFileName. Condiciones literales, no evaluadas. No son funciones ni pares control/campo; botones incluidos. Contratos de superficie arriba no certifican cada campo.\n')
        print('| ID | Etiqueta | Tipo / picture | Condiciones fuente | Fuente:linea | Aceptacion |')
        print('| --- | --- | --- | --- | --- | --- |')
        for field in report['modal_fields']:
            conditions=' AND '.join(field['conditions']).replace('|','&#124;') or 'Siempre'
            print(f"| {field['id']} | {field['label']} | {field['kind']} {field['picture']} | {conditions} | {field['source']}:{field['line']} | Pendiente por campo; contratos de superficie separados |")
        print('\n## Pares control/campo modal\n')
        print('Expansion estricta de condiciones tipo-fuente; falla con sintaxis desconocida. Incluye botones. No es aceptacion runtime ni denominador de funciones.\n')
        print('| Control / superficie | Campos declarados | Aceptacion |')
        print('| --- | --- | --- |')
        for control in dict.fromkeys(r['control'] for r in report['modal_control_pairs']):
            fields=[r['variable'] for r in report['modal_control_pairs'] if r['control']==control]
            linked=sum(isinstance(r['acceptance'],dict) for r in report['modal_control_pairs'] if r['control']==control)
            print(f"| {control} | {', '.join(fields)} | {linked} pares con prueba focal vinculada; restantes pendientes |")
        for pair in report['modal_control_pairs']:
            if isinstance(pair['acceptance'],dict):
                links=', '.join('['+t+'](../tests/'+t+')' for t in pair['acceptance']['tests'])
                print(f"- {pair['id']}: {pair['acceptance']['contract']} Pruebas: {links}")
        print('\n## Campos de modales IDE acotados\n')
        print('GotoLine/CompilerFlags/Replace/Find/RunArguments/Display/ProjectOpen/OpenFile/SaveAs/HelpPick/HelpIndex. Incluye HBIDE_DlgInput libre; no limita inventario a GET. Otros modales y gestos pendientes, sin aceptacion implicita.\n')
        print('| ID | Etiqueta / variable | Tipo | Fuente:linea | Aceptacion |')
        print('| --- | --- | --- | --- | --- |')
        for field in report['ide_modal_fields']:
            linked=isinstance(field['acceptance'],dict)
            print(f"| {field['id']} | {field['label']} | {field['kind']} | {field['source']}:{field['line']} | {'Vinculo focal; ver alcance' if linked else 'Pendiente vinculo por campo'} |")
        for field in report['ide_modal_fields']:
            if isinstance(field['acceptance'],dict):
                links=', '.join('['+t+'](../tests/'+t+')' for t in field['acceptance']['tests'])
                print(f"- {field['id']}: {field['acceptance']['contract']} Pruebas: {links}")
        print('\n## Entradas debugger no GET\n')
        print('Sitios de llamada InputBox/__dbgInput y constructores HBDbInput. No son campos unicos ni aceptacion de cada caller. Modo readonly solo si explicito .F.; resto dinamico. Contexto/argumentos conservados, no evaluados.\n')
        print('| ID | Tipo / modo | Contexto | Llamada fuente | Fuente:linea | Aceptacion |')
        print('| --- | --- | --- | --- | --- | --- |')
        for field in report['debugger_inputs']:
            call=field['call'].replace('|','&#124;')
            print(f"| {field['id']} | {field['kind']} / {field['mode']} | {field['context']} | `{call}` | {field['source']}:{field['line']} | Pendiente caller |")
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

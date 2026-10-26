# Designer: inventario real de eventos Harbour (2026-10-26)

Verificado en fuente (harbour r2608271822; master oficial 694428e1c1 identico
en estas rutas). Todo evento es un codeblock evaluado por el control o por el
reader; no hay mensajes ni callbacks registrados.

## Superficie por control (clausulas @...GET, include/std.ch)

| Control     | WHEN | VALID | FOCUS | STATE |
|-------------|------|-------|-------|-------|
| GET texto   | si   | si    | -     | -     |
| CHECKBOX    | si   | si    | si    | si    |
| LISTBOX     | si   | si    | si    | si    |
| PUSHBUTTON  | si   | si    | si    | si    |
| RADIOGROUP  | si   | si    | si    | no    |

- WHEN (Get:bPreBlock): se evalua al INTENTAR ENTRAR al control
  (HBGetList:GetPreValidate); .F. = el control se salta.
- VALID (Get:bPostBlock): se evalua al INTENTAR SALIR
  (HBGetList:GetPostValidate); .F. = el foco no sale. El bloque recibe el
  Get como parametro (ver RANGE en std.ch: {|_1| RangeCheck(_1,...)}).
- FOCUS (bFBlock): PushButton/CheckBox lo evaluan en setFocus() Y en
  killFocus() (pushbtn.prg:113/158, checkbox.prg:112/140): es "cambio de
  foco", no solo entrada.
- STATE (bSBlock): PushButton lo evalua en select() al SOLTAR la pulsacion
  (pushbtn.prg:148); la activacion inicial del reader NO lo dispara
  (select() sin foco retorna sin evaluar). CheckBox solo cuando el estado
  cambia de verdad (checkbox.prg:130). ListBox en select(xPos)
  (listbox.prg:735/821).
- RADIOGROUP no tiene clausula STATE (std.ch:634): seleccion via reader;
  el valor se lee en VALID.
- Reader GUIReader (tgetlist.prg:842): al activar llama Select(varGet) +
  setFocus; teclas via GUIApplyKey; raton via hitTest (HTCLIENT, HTCAPTION,
  HTDROPBUTTON, HTSCROLL*); SetKey() global funciona dentro del bucle
  Inkey; estados de salida GE_* (GE_SHORTCUT, GE_MOUSEHIT...).

## Estado actual del designer

- Solo PUSHBUTTON enruta a codigo: STATE {|| <accion> } con
  defecto "lOk := .T., oDlg:End()" (DsnButtonAction, designer.prg).
- Ningun WHEN/VALID/FOCUS en el codigo generado; el inspector no tiene
  campos de eventos.

## Diseno aditivo (aprobado en cola P0)

- Nuevas claves de modelo por control: "when", "valid" (todos), "focus"
  (button/checkbox/listbox/radiogroup), "state" (checkbox/listbox; el
  boton ya usa "action"). Vacias = comportamiento actual.
- Inspector (InspFields): campos When/Valid/Focus/State segun tipo.
- Codegen: clausulas WHEN/VALID/FOCUS/STATE solo si la clave no esta
  vacia; el texto se emite tal cual (tipicamente una llamada
  MiDlg_Nombre_Valid()). Los handlers NUNCA se generan: viven en el
  fichero del usuario, fuera de la seccion regenerada; la vista PRG sigue
  de solo lectura.
- Persistencia gratis: el modelo se guarda con hb_jsonEncode (linea 1607).
- Prueba de aditividad: modelo sin eventos -> salida identica a hoy.

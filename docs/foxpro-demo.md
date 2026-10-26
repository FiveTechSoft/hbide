# foxpro.prg: estudio de interfaz

Demo original en Harbour, inspirada en capturas de FoxPro 2.6a DOS. No es
FoxPro, no contiene su codigo y no es un emulador del lenguaje o del motor.
Primera iteracion funcional, no reproduccion al 100%.

Compilar y ejecutar por separado del IDE:

```
hbmk2 demos/foxpro.prg -gttrm -ofoxpro
./foxpro
```

No se modifica hbide.hbp, editor.prg ni hbide.prg. La demo es un solo PRG sin
necesidad de enlazar el IDE. El estudio no se presenta como widget compartido
ya integrado en hbide: esa extraccion requiere revisar su contrato despues.

## Funciones reales

- Menus con F10, flechas y Enter, Alt+letra en las categorias configuradas.
- F4 alterna Browse, Screen, Program y Command; Escape vuelve a Browse.
- Browse en memoria: flechas/paginas/Home/End, columnas izquierda/derecha,
  Enter edita celda con aceptar/cancelar. Record permite append/change/goto y
  delete inmediato de datos ficticios. Ningun fichero de usuario se abre.
- Screen: flechas mueven cursor de colocacion; Ctrl+H abre propiedades de un
  boton; prompt/variable/Disabled, Tab/ShiftTab, aceptar/cancelar. Se conserva
  en el modelo en memoria y se pinta el boton, no se genera SCX ni PRG.
- Program: editor minimo append/backspace/lineas, en memoria, sin ejecutar.
- Command: historial y tres comandos permitidos (browse, screen, modify command).
  Nunca evalua texto arbitrario ni ejecuta comandos del sistema.
- Ayuda/About/limites son notas reales, no resultados de una funcion ausente.
- Mover y redimensionar ventanas: Ctrl+F7 o Window > Move coloca la ventana
  activa con flechas (Enter/Esc termina); Ctrl+F8 o Window > Size estira la
  esquina inferior derecha. Limites: la ventana no sale del escritorio ni
  queda menor que su minimo usable. Los datos, la seleccion, el scroll y el
  foco se conservan; en Screen, los botones colocados y el cursor siguen a la
  ventana. Si al encoger la ventana Screen un boton queda fuera del lienzo
  visible, sus coordenadas NO se reescriben: se deja de pintar y reaparece
  en su posicion original al agrandar (comprobado con capturas). Con raton:
  arrastrar la barra de titulo mueve y arrastrar la esquina inferior derecha
  redimensiona; ambos arrastres verificados con eventos X11 reales (XTEST)
  sobre VTE. La rueda del raton sigue sin prueba fisica. Cada tecla repinta
  la pantalla completa via DispBegin/DispEnd, sin restos; no hay medicion
  comparativa de fluidez contra FoxPro DOS.

## Contraste y limites

Referencias: escritorio/Browse, Screen Builder y Push Button de FoxPro 2.6a
DOS, capturados en prueba independiente. Coinciden las familias de color,
ventanas superpuestas, Command detras, agrupacion del dialogo y teclado.
Difieren fuente, proporciones exactas, tonos de paleta del terminal, menus,
numero de propiedades y semantica de los controles. No hay soporte When/Valid/
Message/Comment, persistencia, motor DBF ni generacion de codigo.

Las flechas y thumb de la barra vertical Browse usan fallback ASCII legible
(^/v/#) hasta resolver el mapeo de glifos DOS sin corromper texto. La barra sigue
la seleccion; su clic implementado no se ha probado con raton real. No se
anuncia arrastre. Se omitieron marcadores de cierre/zoom/horizontal sin accion
para no fingir funcionalidad. El indicador vertical del Screen refleja la
posicion del cursor, no un lienzo infinito desplazable.

El inspector del IDE sigue siendo otro desarrollo. Disabled aqui solo es dato
y apariencia del control en el lienzo, que no es una ventana ejecutada. Variable
es metadato, no una variable del programa en ejecucion. No se copian opciones
que no podamos hacer funcionar en esta demo.

## Pruebas

```
hbmk2 tests/test_foxpro_demo.prg demos/foxpro.prg -dFOXPRO_TEST -gtstd -otest_foxpro
```
La suite de modelo cubre ademas mover/redimensionar: entrada por Ctrl+F7/F8 y
por menu Window, conservacion de contenido, limites de escritorio, tamano
minimo, filas visibles tras redimensionar, cursor retenido dentro del lienzo,
coordenadas de controles intactas al encoger y desplazadas con la ventana al
mover.
./test_foxpro
```

Prueba de modelo: Browse/scroll con 24 filas, append, edicion cancelar/aceptar,
colocacion, boton cancelar/aceptar, menus y Command no evaluable. Capturas de
sesion GTTRM 80x25 inspeccionadas, con F4/Ctrl+H/Enter reales. No prueba Windows
ni comparacion de latencia contra FoxPro DOS. No afirmar igualdad de fluidez
por pasar esta suite o por una captura.
# Calculadora estilo FoxPro (demos/calculator.prg)

Estudio visual y funcional de una calculadora de 4 operaciones con la
estetica FoxPro-DOS: dialogo magenta con sombra, display empotrado y
botones verdes con barra de sombra difuminada (trama CP437, una fila abajo,
inset dos celdas a la izquierda y una a la derecha). Limite del driver gttrm (investigado a fondo, 2026-10-26): gttrm tiene un
modo Unicode (fUTF8) que se activa por //GTTRM:UTF8, sonda de terminal o
LANG; en esta build (FiveTechSoft r2608271822, UNICODE_BUF) el modo forzado
rompe TODA la salida de glifos (probado en VTE real), y en modo normal solo
la trama (176-178) y la caja simple (179-206) se mapean via ACSC; los
semibloques (219-223) salen "?". La escritura cruda UTF-8 tambien se
corrompe en la capa CP del GT. El master oficial harbour/core 694428e1c1
(2026-10-24) tiene gttrm.c, gtchrmap.c y hbgtcore.c byte a byte identicos:
no existe driver gttrm mas nuevo. gtcrs/gtxwc no estan compilados en esta
toolchain (requieren build con ncurses/X11: pospuesto). La sombra fina
estilo TVision (semibloque inferior) no es representable con gttrm;
hb_gtInfo(HB_GTI_ISUNICODE) permite detectarlo en runtime.

Exigencia vigente del usuario (10:20): la sombra inferior Y la lateral
derecha siguen mal; la barra difuminada interim NO es aceptacion visual y
ninguna variante de celda de altura completa lo sera: hacen falta
semibloques o un GT con Unicode sano.

## Ejecutar

    hbmk2 demos/calculator.prg -gttrm && ./demos/calculator

## Uso

- Teclea digitos y operadores directamente: `123+456=` muestra `579`.
- Flechas mueven el foco entre botones (el foco se ve en verde
  brillante); Enter o Espacio pulsan el boton enfocado.
- Teclear una tecla tambien mueve el foco a su boton.
- `C` borra todo; Backspace borra un digito; Esc sale.

## Semantica

- Ejecucion inmediata (calculadora de bolsillo clasica): `2+3*4=`
  calcula de izquierda a derecha y da `20`; no hay precedencia.
- Division entre cero muestra `Error`; el siguiente digito empieza una
  entrada nueva.
- Display de 12 digitos maximo; el punto decimal se acepta una vez.
- Numeros renderizados compactos: sin ceros a la derecha (`2.5`, no
  `2.500000`).

## Pruebas

Modelo puro (estado + transiciones), sin terminal:

    cd tests && hbmk2 test_calculator.prg ../demos/calculator.prg -dCALC_TEST -gttrm
    ./test_calculator   # resultado en /tmp/hbide-calculator-tests.txt

19 aserciones: entrada de digitos, las 4 operaciones, ejecucion
inmediata, punto unico, borrado, navegacion de foco con limites y wrap,
recuperacion de error, reinicio tras `=`.

## Limites

- Sin raton: teclado solamente.
- Sin memoria (M+/MR) ni porcentajes: fuera del alcance del estudio.
- Bordes dibujados celda a celda (CalcBox): una cadena UTF-8 larga
  multibyte puede partir un caracter en la frontera de una escritura GT
  y corromper celdas; el dibujo por celda lo evita.

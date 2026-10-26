# Calculadora estilo FoxPro (demos/calculator.prg)

Estudio visual y funcional de una calculadora de 4 operaciones con la
estetica FoxPro-DOS: dialogo magenta con sombra, display empotrado y
botones verdes con sombra difuminada (trama CP437 de 50%, una fila abajo y
una columna a la derecha, inset): en este GT los semibloques no se mapean y
una celda negra solida completa se lee como un bloque pesado en botones
pequenos.

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

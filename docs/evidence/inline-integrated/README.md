# Integrated inline When scroll, Linux40x120

Full IDE launched directly in GTTRM; Options/Screen designer, actual JSON
load, select ComboBox, focus inspector, edit When, Home, Esc. The test uses
an isolated home/recovery folder and synthetic text. Product source is
unchanged from daa2708. Screens were inspected at full size.

Only terminal cursor blinking was disabled to make the caret visible in
still images. Tail shows the black caret after TAIL; Home shows it on S of
Start_. Inspector, canvas lower borders and status remain intact. Esc exits
editing; selected When retains its orange focus highlight, without the
editing caret. The gray block in the canvas remains in all captures:
DrawControls explicitly draws it at the selected control's bottom-right
resize handle (ComboBox20x6 includes its dropdown height). It is not a
misplaced caret and hiding the terminal cursor does not erase it.

Separate temporary instrumented fixture (not product code) recorded
{expected row,col,GT row,col,cursor style,display nesting,handle position}:
Tail {9,113,9,113,1,0,{19,59}}, Home {9,96,9,96,1,0,{19,59}}.
This corroborates the diagnosis but does not replace integrated pixels.

This establishes the focal Linux integrated When scroll/caret observation,
not all events/controls, handler execution, modal restoration, Windows or
global milestone acceptance. No product bug fix was required for the block.
The earlier script-wrapped terminal trace changed timing and did not reach
When; it is excluded. An experimental hide build initially missed an include
path and failed before launch; its error screen is excluded too.

Reproduce with the current hbide binary built in the checkout, Xvfb,
xfce4-terminal, xdotool and ImageMagick. capture.py currently uses the local
checkout path; adjust it on another installation. Screenshots are synthetic.

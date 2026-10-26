//
// calculator.prg - functional 4-function calculator, FoxPro-DOS style
//
// Demonstrates: green shadowed push buttons (focused = bright), per-cell
// box drawing (CalcBox: long multibyte UTF-8 strings can split a char
// across a GT write boundary and corrupt cells; borders go out per cell),
// keyboard-first driving (arrows + Enter, or type the key directly).
//
// Immediate-execution semantics (classic pocket calculator): "2+3*4="
// computes left to right -> 20, no operator precedence.
//
// Mouse: not wired in this study; keyboard only. Esc exits.
//
// Build the model test:  hbmk2 tests/test_calculator.prg demos/calculator.prg -dCALC_TEST -gttrm
// Run the demo:          hbmk2 demos/calculator.prg -gttrm && ./calculator
//

#include "inkey.ch"

#define CALC_NBUTTONS 17

#ifndef CALC_TEST
PROCEDURE Main()
   LOCAL h := CalcState(), k
   SetColor( "W+/B" )
   CLEAR SCREEN
   CalcPaint( h )
   DO WHILE .T.
      k := hb_keyStd( Inkey( 0, INKEY_ALL + HB_INKEY_EXT ) )
      IF k == K_ESC
         EXIT
      ENDIF
      CalcKey( h, k )
      CalcPaint( h )
   ENDDO
   SetColor( "W/N" )
   CLEAR SCREEN
   RETURN
#endif

FUNCTION CalcState()
RETURN { "display" => "0", "acc" => 0, "op" => "", "entering" => .T., ;
         "focus" => 1, "error" => .F. }

// button captions in focus order: 1..17
STATIC FUNCTION CalcButtons()
RETURN { "C", "7", "8", "9", "/", "4", "5", "6", "*", "1", "2", "3", "-", "0", ".", "=", "+" }

// pure state transition; returns the button index pressed (0 = none)
FUNCTION CalcKey( h, k )
   LOCAL aB := CalcButtons(), n, cKey := ""
   DO CASE
   CASE k == K_LEFT  ; h["focus"] := 1 + Mod( h["focus"] - 2 + CALC_NBUTTONS, CALC_NBUTTONS )
   CASE k == K_RIGHT ; h["focus"] := 1 + Mod( h["focus"], CALC_NBUTTONS )
   CASE k == K_UP    ; h["focus"] := Max( 1, h["focus"] - 4 )
   CASE k == K_DOWN  ; h["focus"] := Min( CALC_NBUTTONS, h["focus"] + 4 )
   CASE k == K_ENTER .OR. k == K_SPACE
      CalcPress( h, aB[ h["focus"] ] )
      RETURN h["focus"]
   CASE k == K_BS
      CalcBackspace( h )
      RETURN 0
   CASE k >= 32 .AND. k <= 126
      n := AScan( aB, Upper( Chr( k ) ) )
      IF n > 0
         h["focus"] := n
         CalcPress( h, cKey )
         RETURN n
      ENDIF
   ENDCASE
RETURN 0

STATIC FUNCTION CalcBackspace( h )
   IF h["error"]
      CalcClearAll( h )
   ELSEIF h["entering"] .AND. Len( h["display"] ) > 1
      h["display"] := Left( h["display"], Len( h["display"] ) - 1 )
   ELSE
      h["display"] := "0"
   ENDIF
RETURN NIL

STATIC FUNCTION CalcClearAll( h )
   h["display"] := "0" ; h["acc"] := 0 ; h["op"] := "" ; h["entering"] := .T. ; h["error"] := .F.
RETURN NIL

STATIC FUNCTION CalcPress( h, cB )
   DO CASE
   CASE cB == "C"
      CalcClearAll( h )
   CASE cB $ "0123456789"
      IF h["error"] .OR. ! h["entering"]
         h["display"] := cB ; h["error"] := .F.
      ELSEIF h["display"] == "0"
         h["display"] := cB
      ELSEIF Len( h["display"] ) < 12
         h["display"] += cB
      ENDIF
      h["entering"] := .T.
   CASE cB == "."
      IF h["error"] .OR. ! h["entering"]
         h["display"] := "0." ; h["error"] := .F.
      ELSEIF ! "." $ h["display"]
         h["display"] += "."
      ENDIF
      h["entering"] := .T.
   CASE cB $ "+-*/"
      IF ! h["error"]
         CalcApply( h )
         h["op"] := cB
         h["entering"] := .F.
      ENDIF
   CASE cB == "="
      IF ! h["error"]
         CalcApply( h )
         h["op"] := ""
         h["entering"] := .F.
      ENDIF
   ENDCASE
RETURN NIL

STATIC FUNCTION CalcApply( h )
   LOCAL nVal
   IF h["entering"]
      nVal := Val( h["display"] )
      DO CASE
      CASE h["op"] == ""  ; h["acc"] := nVal
      CASE h["op"] == "+" ; h["acc"] := h["acc"] + nVal
      CASE h["op"] == "-" ; h["acc"] := h["acc"] - nVal
      CASE h["op"] == "*" ; h["acc"] := h["acc"] * nVal
      CASE h["op"] == "/"
         IF nVal == 0
            h["display"] := "Error" ; h["error"] := .T. ; h["op"] := "" ; h["acc"] := 0
            RETURN NIL
         ENDIF
         h["acc"] := h["acc"] / nVal
      ENDCASE
      h["display"] := CalcNum( h["acc"] )
   ENDIF
RETURN NIL

// compact number rendering: no trailing zeros, dot only when needed
STATIC FUNCTION CalcNum( n )
   LOCAL c
   IF n == Int( n ) .AND. Abs( n ) < 1e12
      c := LTrim( Str( Int( n ), 12, 0 ) )
   ELSE
      c := AllTrim( Str( n, 12, 6 ) )
      DO WHILE Right( c, 1 ) == "0" .AND. "." $ c
         c := Left( c, Len( c ) - 1 )
      ENDDO
      IF Right( c, 1 ) == "."
         c := Left( c, Len( c ) - 1 )
      ENDIF
   ENDIF
RETURN c

// button geometry: index -> { row, col } of its caption on screen
STATIC FUNCTION CalcBtnRect( n )
   LOCAL nRow, nCol
   IF n == 1                                     // C
      RETURN { 8, 16 }
   ENDIF
   nRow := 10 + Int( ( n - 2 ) / 4 ) * 3
   nCol := 10 + ( ( n - 2 ) % 4 ) * 7
RETURN { nRow, nCol }

FUNCTION CalcPaint( h )
   LOCAL aB := CalcButtons(), n, aRC, cCap
   hb_Scroll( 2, 6, 23, 49, , , "N/N" )          // drop shadow of the dialog
   hb_Scroll( 1, 5, 22, 47, , , "W+/RB" )
   CalcBox( 1, 5, 22, 47, "W+/RB" )
   hb_DispOutAt( 1, 19, " Calculator ", "W+/RB" )
   // display: recessed field, right-aligned value
   hb_Scroll( 3, 8, 5, 44, , , "N/W" )
   CalcBox( 3, 8, 5, 44, "N/W" )
   hb_DispOutAt( 4, 10, PadL( Left( h["display"], 30 ), 30 ), "N/W" )
   FOR n = 1 TO CALC_NBUTTONS
      aRC := CalcBtnRect( n )
      cCap := "< " + aB[ n ] + " >"
      CalcBtnShadow( aRC[ 1 ], aRC[ 2 ], Len( cCap ), "N/RB" )
      hb_DispOutAt( aRC[ 1 ], aRC[ 2 ], cCap, iif( n == h["focus"], "W+/G", "W/G" ) )
   NEXT
   hb_DispOutAt( 21, 8, "Arrows move  Enter presses  Esc exits", "W+/RB" )
RETURN NIL

// Dithered shadow bar: one row below, inset two cells left and one right,
// so it reads as a shade under the face, not a second block. CP437 shade
// byte: gttrm maps it through ACS on real terminals; half-block glyphs
// are NOT mapped by this GT, so a solid thin strip is not representable.
FUNCTION CalcBtnShadow( nRow, nCol, nLen, cClr )
   LOCAL i
   FOR i = 2 TO nLen - 1
      hb_DispOutAt( nRow + 1, nCol + i, Chr( 176 ), cClr )
   NEXT
RETURN NIL

// per-cell border: avoids splitting a multibyte UTF-8 char at a GT write
// boundary, which leaves junk cells mid-frame
FUNCTION CalcBox( t, l, b, r, color )
   LOCAL c
   hb_DispOutAt( t, l, hb_UTF8ToStr( "┌" ), color )
   hb_DispOutAt( t, r, hb_UTF8ToStr( "┐" ), color )
   hb_DispOutAt( b, l, hb_UTF8ToStr( "└" ), color )
   hb_DispOutAt( b, r, hb_UTF8ToStr( "┘" ), color )
   FOR c = l + 1 TO r - 1
      hb_DispOutAt( t, c, hb_UTF8ToStr( "─" ), color )
      hb_DispOutAt( b, c, hb_UTF8ToStr( "─" ), color )
   NEXT
   FOR c = t + 1 TO b - 1
      hb_DispOutAt( c, l, hb_UTF8ToStr( "│" ), color )
      hb_DispOutAt( c, r, hb_UTF8ToStr( "│" ), color )
   NEXT
RETURN NIL

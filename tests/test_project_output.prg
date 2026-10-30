#include "inkey.ch"
#include "set.ch"
PROCEDURE Main()
   LOCAL i, cLine := Replicate( "x", 120 ) + "DIAGNOSTIC TAIL", cShown
   SetMode( 25, 80 )
   Set( _SET_TYPEAHEAD, 512 )
   FOR i := 1 TO 120
      hb_keyPut( K_RIGHT )
   NEXT
   hb_keyPut( K_ESC )
   HBIDEProjectOutput( cLine )
   cShown := ScreenText( 3, 4, 3, 76 )
   Check( "DIAGNOSTIC TAIL" $ cShown, "long compiler line tail accessible" )
   FOR i := 1 TO 300
      hb_keyPut( K_LEFT )
   NEXT
   hb_keyPut( K_ESC )
   HBIDEProjectOutput( "BEGIN " + cLine )
   Check( Left( ScreenText( 3, 4, 3, 76 ), 6 ) == "BEGIN ", "left boundary clamped" )
   hb_keyPut( K_ESC )
   HBIDEProjectOutput( "" )
   Check( Empty( ScreenText( 3, 4, 3, 76 ) ), "empty output stays safe" )
   ? "PASS output horizontal navigation and boundaries"
   RETURN
STATIC PROCEDURE Check( lOk, cText )
   IF ! lOk
      ? "FAIL:", cText
      ErrorLevel( 1 )
      QUIT
   ENDIF
   RETURN
STATIC FUNCTION ScreenText( nTop, nLeft, nBottom, nRight )
   LOCAL cSaved := SaveScreen( nTop, nLeft, nBottom, nRight ), cText := "", n
   FOR n := 1 TO Len( cSaved ) STEP 2
      cText += SubStr( cSaved, n, 1 )
   NEXT
   RETURN cText

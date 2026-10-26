#include "inkey.ch"
#include "setcurs.ch"

// Modal project desktop. Returns a navigation request; never edits a buffer.
// Host suspends its idle/status repaint while this dialog owns the screen.
FUNCTION HBIDEProjectDesktop( oProject, cHbmk2 )
   LOCAL cSaved := SaveScreen( 0, 0, MaxRow(), MaxCol() ), nCursor := SetCursor( SC_NONE )
   LOCAL nPick := 1, nTop := 1, nKey, lMessages := .F., aRows, hReturn := NIL
   LOCAL nVisible := MaxRow() - 10, nClick, h
   DO WHILE .T.
      aRows := HBIDEProjectRows( oProject, lMessages )
      nPick := Max( 1, Min( nPick, Len( aRows ) ) )
      nTop := Min( nTop, nPick )
      IF nPick >= nTop + nVisible
         nTop := nPick - nVisible + 1
      ENDIF
      HBIDEProjectPaint( oProject, lMessages, aRows, nPick, nTop, nVisible )
      nKey := hb_keyStd( Inkey( 0, INKEY_ALL + HB_INKEY_EXT ) )
      DO CASE
      CASE nKey == K_ESC
         EXIT
      CASE nKey == K_UP
         nPick--
      CASE nKey == K_DOWN
         nPick++
      CASE nKey == K_HOME
         nPick := 1
      CASE nKey == K_END
         nPick := Len( aRows )
      CASE nKey == K_PGUP
         nPick -= nVisible
      CASE nKey == K_PGDN
         nPick += nVisible
      CASE nKey == K_F4
         lMessages := ! lMessages; nPick := 1; nTop := 1
      CASE nKey == K_F6 .AND. ! Empty( oProject:hBuild )
         HBIDEProjectOutput( oProject:hBuild[ "output" ] )
      CASE nKey == K_F9 .OR. nKey == K_CTRL_F9
         hb_DispOutAt( MaxRow() - 3, 4, PadR( "Building... waiting for hbmk2 (Esc cannot cancel)", MaxCol() - 7 ), "W+/R" )
         oProject:Build( cHbmk2, nKey == K_CTRL_F9 )
         lMessages := .T.; nPick := 1; nTop := 1
      CASE nKey == K_LBUTTONDOWN .OR. nKey == K_LDBLCLK
         nClick := MRow() - 6 + nTop
         IF MRow() >= 6 .AND. MRow() < 6 + nVisible .AND. nClick <= Len( aRows )
            nPick := Max( 1, nClick )
            IF nKey == K_LDBLCLK
               nKey := K_ENTER
            ENDIF
         ENDIF
      ENDCASE
      IF nKey == K_ENTER .AND. Len( aRows ) > 0
         h := aRows[ nPick ]
         IF ! Empty( h[ "path" ] )
            hReturn := { "action" => "open", "path" => h[ "path" ], ;
               "line" => h[ "line" ], "column" => h[ "column" ] }
            EXIT
         ENDIF
      ENDIF
   ENDDO
   RestScreen( 0, 0, MaxRow(), MaxCol(), cSaved )
   SetCursor( nCursor )
   RETURN hReturn

FUNCTION HBIDEProjectRows( oProject, lMessages )
   LOCAL a := {}, h, u
   IF lMessages
      IF ! Empty( oProject:hBuild )
         FOR EACH h IN oProject:hBuild[ "diagnostics" ]
            AAdd( a, { "label" => Upper( h[ "level" ] ) + " " + hb_FNameNameExt( h[ "path" ] ) + ;
               ":" + hb_ntos( h[ "line" ] ) + " " + h[ "text" ], "detail" => h[ "path" ], ;
               "path" => h[ "path" ], "line" => h[ "line" ], "column" => h[ "column" ] } )
         NEXT
      ENDIF
   ELSE
      FOR EACH h IN oProject:aMembers
         AAdd( a, { "label" => iif( h[ "exists" ], "  ", "! " ) + h[ "token" ], ;
            "detail" => h[ "path" ] + iif( h[ "exists" ], "", " [missing]" ), ;
            "path" => iif( h[ "exists" ], h[ "path" ], "" ), "line" => 1, "column" => 1 } )
      NEXT
      FOR EACH u IN oProject:aUnresolved
         AAdd( a, { "label" => "? " + u[ 2 ], "detail" => "HBP line " + hb_ntos( u[ 1 ] ) + ": " + u[ 3 ], ;
            "path" => "", "line" => 1, "column" => 1 } )
      NEXT
   ENDIF
   RETURN a

FUNCTION HBIDEProjectPaint( oProject, lMessages, aRows, nPick, nTop, nVisible )
   LOCAL nR := MaxRow(), nC := MaxCol(), i, n, cState := "Not built in this session", cLine
   DispBegin()
   hb_Scroll( 2, 2, nR - 2, nC - 2,,, "N/W" )
   hb_DispBox( 2, 2, nR - 2, nC - 2, hb_UTF8ToStrBox( "┌─┐│┘─└│" ), "N/W" )
   hb_DispOutAt( 2, 4, " Project - " + hb_FNameNameExt( oProject:cFile ) + " ", "W+/B" )
   hb_DispOutAt( 3, 4, PadR( Right( oProject:cRoot, nC - 7 ), nC - 7 ), "N/W" )
   IF ! Empty( oProject:hBuild )
      cState := iif( oProject:hBuild[ "ok" ], "Build OK", "BUILD FAILED" ) + ;
         " (exit " + hb_ntos( oProject:hBuild[ "exit" ] ) + ") - " + ;
         hb_ntos( Len( oProject:hBuild[ "diagnostics" ] ) ) + " diagnostics"
   ENDIF
   hb_DispOutAt( 4, 4, PadR( cState, nC - 7 ), iif( "FAILED" $ cState, "W+/R", "N/W" ) )
   hb_DispOutAt( 5, 4, PadR( iif( lMessages, "MESSAGES - Enter jumps to source; F6 full output", ;
      "SOURCES - Enter opens; ! missing; ? resolved by hbmk2" ), nC - 7 ), "W+/B" )
   FOR i := 0 TO nVisible - 1
      n := nTop + i
      cLine := ""
      IF n <= Len( aRows )
         cLine := aRows[ n, "label" ]
      ENDIF
      hb_DispOutAt( 6 + i, 4, PadR( Left( cLine, nC - 7 ), nC - 7 ), iif( n == nPick, "W+/B", "N/W" ) )
   NEXT
   IF Len( aRows ) == 0
      hb_DispOutAt( 6, 4, iif( lMessages, "No parsed diagnostics. F6 shows all compiler output.", "No literal sources listed." ), "N/W" )
   ELSE
      hb_DispOutAt( nR - 4, 4, PadR( Right( aRows[ nPick, "detail" ], nC - 7 ), nC - 7 ), "N/W" )
   ENDIF
   hb_DispOutAt( nR - 3, 4, PadR( "F4 Sources/Messages  F9 Build  Ctrl+F9 Rebuild  Esc Close", nC - 7 ), "W+/B" )
   DispEnd()
   RETURN NIL

FUNCTION HBIDEProjectOutput( cOutput )
   LOCAL a := hb_ATokens( cOutput, Chr(10) ), nTop := 1, nKey, nR := MaxRow(), nC := MaxCol(), i, n, cLine
   DO WHILE .T.
      hb_Scroll( 2, 2, nR - 2, nC - 2,,, "N/W" )
      hb_DispBox( 2, 2, nR - 2, nC - 2, hb_UTF8ToStrBox( "┌─┐│┘─└│" ), "N/W" )
      hb_DispOutAt( 2, 4, " Build output - Up/Down/PgUp/PgDn/Home/End - Esc Back ", "W+/B" )
      FOR i := 0 TO nR - 7
         n := nTop + i; cLine := ""
         IF n <= Len( a )
            cLine := a[ n ]
         ENDIF
         hb_DispOutAt( 3 + i, 4, PadR( Left( cLine, nC - 7 ), nC - 7 ), "N/W" )
      NEXT
      nKey := hb_keyStd( Inkey( 0, INKEY_ALL + HB_INKEY_EXT ) )
      DO CASE
      CASE nKey == K_ESC; EXIT
      CASE nKey == K_UP; nTop--
      CASE nKey == K_DOWN; nTop++
      CASE nKey == K_PGUP; nTop -= nR - 6
      CASE nKey == K_PGDN; nTop += nR - 6
      CASE nKey == K_HOME; nTop := 1
      CASE nKey == K_END; nTop := Len( a ) - nR + 7
      ENDCASE
      nTop := Max( 1, Min( nTop, Max( 1, Len( a ) - nR + 7 ) ) )
   ENDDO
   RETURN NIL

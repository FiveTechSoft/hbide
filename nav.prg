#include "inkey.ch"
#include "setcurs.ch"

// Navigation helpers: procedure/function scanner and a small filterable
// list picker shared by Go to Function, Messages and the window list.
// No editor state is touched here; callers own all navigation.

// Returns { { cName, cKind, nLine }, ... } in source order.
// Recognised: [STATIC|INIT|EXIT] FUNCTION|PROCEDURE name, METHOD name ...
// CLASS cls (implementation form only), and CLASS name. Commented-out lines
// (//, *, &&, /* */) and #pragma begindump C blocks are skipped.
FUNCTION HBIDE_ScanProcs( cText )
   LOCAL aOut := {}, aLines, cLine, cL, nLine := 0, lBlock := .F., lDump := .F.
   LOCAL aTok, cT1, cT2, cName, n, cKind, cCls

   cText := StrTran( StrTran( cText, Chr( 13 ) + Chr( 10 ), Chr( 10 ) ), Chr( 13 ), Chr( 10 ) )
   aLines := hb_ATokens( cText, Chr( 10 ) )
   FOR EACH cLine IN aLines
      nLine++
      // C dump contents have their own lexical rules. Do not let an
      // embedded C comment leak into the Harbour scanner after enddump.
      IF lDump
         IF Upper( StrTran( StrTran( AllTrim( cLine ), Chr( 9 ), "" ), " ", "" ) ) == "#PRAGMAENDDUMP"
            lDump := .F.
         ENDIF
         LOOP
      ENDIF
      // Comments inside quoted strings are data, and line comments cannot
      // start a block comment that hides declarations on following lines.
      cL := HBIDE_NavCode( cLine, @lBlock )
      cL := AllTrim( StrTran( cL, Chr( 9 ), " " ) )
      IF Empty( cL )
         LOOP
      ENDIF
      IF Left( cL, 1 ) == "#"
         cT1 := Upper( StrTran( cL, " ", "" ) )
         IF cT1 == "#PRAGMABEGINDUMP"
            lDump := .T.
         ELSEIF "#PRAGMAENDDUMP" $ cT1
            lDump := .F.
         ENDIF
         LOOP
      ENDIF
      IF lDump .OR. Left( cL, 2 ) == "//" .OR. Left( cL, 1 ) == "*" .OR. Left( cL, 2 ) == "&&"
         LOOP
      ENDIF
      aTok := hb_ATokens( cL, " " )
      // collapse blanks left by consecutive spaces
      aTok := HBIDE_Compact( aTok )
      IF Len( aTok ) < 2
         LOOP
      ENDIF
      cT1 := Upper( aTok[ 1 ] )
      cT2 := Upper( aTok[ 2 ] )
      IF cT1 $ "STATIC|INIT|EXIT"
         IF Len( aTok ) < 3
            LOOP
         ENDIF
         cT1 := cT2
         cName := aTok[ 3 ]
         cKind := Lower( iif( HBIDE_IsKw( cT1, "FUNCTION" ), "function", ;
                         iif( HBIDE_IsKw( cT1, "PROCEDURE" ), "procedure", "" ) ) )
         IF Empty( cKind )
            LOOP
         ENDIF
         cKind := "static " + cKind
      ELSEIF HBIDE_IsKw( cT1, "FUNCTION" )
         cKind := "function"; cName := aTok[ 2 ]
      ELSEIF HBIDE_IsKw( cT1, "PROCEDURE" )
         cKind := "procedure"; cName := aTok[ 2 ]
      ELSEIF cT1 == "METHOD"
         // only the implementation form names its class: "METHOD x() CLASS c"
         cCls := ""
         FOR n := 3 TO Len( aTok )
            IF Upper( aTok[ n ] ) == "CLASS" .AND. n < Len( aTok )
               cCls := aTok[ n + 1 ]
               EXIT
            ENDIF
         NEXT
         IF Empty( cCls )
            LOOP
         ENDIF
         cKind := "method"; cName := aTok[ 2 ]
         IF Upper( cName ) == "FUNCTION" .OR. Upper( cName ) == "PROCEDURE"
            IF Len( aTok ) < 3
               LOOP
            ENDIF
            cName := aTok[ 3 ]
         ENDIF
      ELSEIF cT1 == "CLASS" .AND. Len( aTok ) >= 2
         // hbclass.ch aliases for members, not class declarations.
         IF cT2 == "VAR" .OR. cT2 == "METHOD"
            LOOP
         ENDIF
         cKind := "class"; cName := aTok[ 2 ]
      ELSE
         LOOP
      ENDIF
      cName := HBIDE_NameOnly( cName )
      IF Empty( cName )
         LOOP
      ENDIF
      IF cKind == "method"
         cName := cCls + ":" + cName
      ENDIF
      AAdd( aOut, { cName, cKind, nLine } )
   NEXT
   RETURN aOut

// Strip comments and mask string contents without changing line count.
STATIC FUNCTION HBIDE_NavCode( cLine, lBlock )
   LOCAL cOut := "", n := 1, c, q := "", lEscape := .F.
   IF Left( LTrim( cLine ), 1 ) == "*" .AND. ! lBlock
      RETURN ""
   ENDIF
   DO WHILE n <= Len( cLine )
      c := SubStr( cLine, n, 1 )
      DO CASE
      CASE lBlock
         IF SubStr( cLine, n, 2 ) == "*/"
            lBlock := .F.
            cOut += " "
            n++
         ENDIF
      CASE ! Empty( q )
         IF lEscape .AND. c == Chr( 92 )
            n++
         ELSEIF c == q
            IF SubStr( cLine, n + 1, 1 ) == q .AND. q != "]"
               n++
            ELSE
               q := ""
            ENDIF
         ENDIF
         cOut += " "
      CASE SubStr( cLine, n, 2 ) == "//" .OR. SubStr( cLine, n, 2 ) == "&&"
         EXIT
      CASE SubStr( cLine, n, 2 ) == "/*"
         lBlock := .T.
         cOut += " "
         n++
      CASE c == Chr( 34 ) .OR. c == "'" .OR. c == "`" .OR. ;
           ( c == "[" .AND. "]" $ SubStr( cLine, n + 1 ) )
         // A bracket string must close on this physical line. An array
         // index can instead contain a block comment spanning later lines.
         q := iif( c == "[", "]", iif( c == "`", "'", c ) )
         lEscape := n > 1 .AND. Lower( SubStr( cLine, n - 1, 1 ) ) == "e" .AND. c == Chr( 34 )
         cOut += " "
      OTHERWISE
         cOut += c
      ENDCASE
      n++
   ENDDO
RETURN cOut

// FUNC/PROC may be abbreviated to four letters in Harbour/Clipper
STATIC FUNCTION HBIDE_IsKw( cWord, cFull )
   RETURN Len( cWord ) >= 4 .AND. Len( cWord ) <= Len( cFull ) .AND. Left( cFull, Len( cWord ) ) == cWord

STATIC FUNCTION HBIDE_Compact( aTok )
   LOCAL a := {}, c
   FOR EACH c IN aTok
      IF ! Empty( c )
         AAdd( a, c )
      ENDIF
   NEXT
   RETURN a

STATIC FUNCTION HBIDE_NameOnly( c )
   LOCAL i, ch, cOut := ""
   FOR i := 1 TO Len( c )
      ch := SubStr( c, i, 1 )
      IF ch $ "(;:" .OR. ch == " "
         EXIT
      ENDIF
      cOut += ch
   NEXT
   RETURN cOut

// Modal filterable list. Type to filter (case-insensitive substring),
// Up/Down/PgUp/PgDn/Home/End move, Enter picks, Esc cancels, mouse click
// selects and double click picks. Returns the 1-based index into aLabels,
// or 0 when cancelled/empty. Saves and restores the screen itself; the
// caller suspends the idle status painter.
FUNCTION HBIDE_ListPick( cTitle, aLabels, nInit, cHint )
   LOCAL cSaved := SaveScreen( 0, 0, MaxRow(), MaxCol() ), nCursor := SetCursor( SC_NONE )
   LOCAL nW := Min( MaxCol() - 6, 78 ), nH := Min( MaxRow() - 4, Max( 9, Len( aLabels ) + 5 ) )
   LOCAL nT := Int( ( MaxRow() + 1 - nH ) / 2 ), nL := Int( ( MaxCol() + 1 - nW ) / 2 )
   LOCAL nVis := nH - 5, cFilter := "", aIdx, nPick := 1, nTop := 1, nKey, nRet := 0
   LOCAL i, n, cLine, nClick, cCh

   hb_default( @cHint, "Type to filter   Enter select   Esc cancel" )
   hb_default( @nInit, 1 )
   aIdx := HBIDE_ListFilter( aLabels, cFilter )
   nPick := Max( 1, AScan( aIdx, nInit ) )

   DO WHILE .T.
      nPick := Max( 1, Min( nPick, Max( 1, Len( aIdx ) ) ) )
      IF nPick < nTop
         nTop := nPick
      ENDIF
      IF nPick >= nTop + nVis
         nTop := nPick - nVis + 1
      ENDIF
      DispBegin()
      hb_Scroll( nT, nL, nT + nH - 1, nL + nW - 1,,, "N/W" )
      hb_DispBox( nT, nL, nT + nH - 1, nL + nW - 1, hb_UTF8ToStrBox( "┌─┐│┘─└│" ), "N/W" )
      hb_DispOutAt( nT, nL + 2, " " + Left( cTitle, nW - 6 ) + " ", HBDlgTitleColor() )
      hb_DispOutAt( nT + 1, nL + 2, PadR( "Find: " + cFilter + "_", nW - 4 ), "N/BG" )
      FOR i := 0 TO nVis - 1
         n := nTop + i
         cLine := iif( n <= Len( aIdx ), aLabels[ aIdx[ n ] ], "" )
         hb_DispOutAt( nT + 2 + i, nL + 2, PadR( Left( cLine, nW - 4 ), nW - 4 ), iif( n == nPick .AND. n <= Len( aIdx ), "N/BG", "N/W" ) )
      NEXT
      IF Len( aIdx ) == 0
         hb_DispOutAt( nT + 2, nL + 2, PadR( "No match", nW - 4 ), "N/W" )
      ENDIF
      hb_DispOutAt( nT + nH - 2, nL + 2, PadR( Left( hb_ntos( Len( aIdx ) ) + "/" + hb_ntos( Len( aLabels ) ) + "  " + cHint, nW - 4 ), nW - 4 ), "N/BG" )
      DrawShadow( nT, nL, nT + nH - 1, nL + nW - 1 )
      DispEnd()

      nKey := hb_keyStd( Inkey( 0, INKEY_ALL + HB_INKEY_EXT ) )
      DO CASE
      CASE nKey == K_ESC
         EXIT
      CASE nKey == K_ENTER
         IF Len( aIdx ) > 0
            nRet := aIdx[ nPick ]
         ENDIF
         EXIT
      CASE nKey == K_UP
         nPick--
      CASE nKey == K_DOWN
         nPick++
      CASE nKey == K_PGUP
         nPick -= nVis
      CASE nKey == K_PGDN
         nPick += nVis
      CASE nKey == K_HOME
         nPick := 1
      CASE nKey == K_END
         nPick := Len( aIdx )
      CASE nKey == K_MWFORWARD
         nPick -= 3
      CASE nKey == K_MWBACKWARD
         nPick += 3
      CASE nKey == K_BS
         IF Len( cFilter ) > 0
            cFilter := Left( cFilter, Len( cFilter ) - 1 )
            aIdx := HBIDE_ListFilter( aLabels, cFilter )
            nPick := 1; nTop := 1
         ENDIF
      CASE nKey == K_LBUTTONDOWN .OR. nKey == K_LDBLCLK
         nClick := MRow() - ( nT + 2 ) + nTop
         IF MRow() >= nT + 2 .AND. MRow() < nT + 2 + nVis .AND. nClick >= 1 .AND. nClick <= Len( aIdx )
            nPick := nClick
            IF nKey == K_LDBLCLK
               nRet := aIdx[ nPick ]
               EXIT
            ENDIF
         ENDIF
      OTHERWISE
         cCh := hb_keyChar( nKey )
         IF Len( cCh ) > 0 .AND. nKey >= 32
            cFilter += cCh
            aIdx := HBIDE_ListFilter( aLabels, cFilter )
            nPick := 1; nTop := 1
         ENDIF
      ENDCASE
   ENDDO
   RestScreen( 0, 0, MaxRow(), MaxCol(), cSaved )
   SetCursor( nCursor )
   RETURN nRet

STATIC FUNCTION HBIDE_ListFilter( aLabels, cFilter )
   LOCAL a := {}, i, cF := Upper( cFilter )
   FOR i := 1 TO Len( aLabels )
      IF Empty( cF ) .OR. cF $ Upper( aLabels[ i ] )
         AAdd( a, i )
      ENDIF
   NEXT
   RETURN a

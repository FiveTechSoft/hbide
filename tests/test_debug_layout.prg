#include "inkey.ch"
PROCEDURE Main()
   LOCAL oD, a, aR, n, r, c, i, j, nTests := 0
   FOR EACH r IN { 25, 40, 50 }
      FOR EACH c IN { 80, 120, 160 }
         FOR n := 1 TO 8
            a := HBIDE_DbgRects( n, r, c, .F. )
            Assert( Len( a ) == n, 'tile count' )
            FOR i := 1 TO n
               aR := a[ i ]
               Assert( aR[ 1 ] >= 1 .AND. aR[ 2 ] >= 0 .AND. aR[ 3 ] < r - 1 .AND. aR[ 4 ] < c, 'tile bounds' )
               Assert( aR[ 3 ] - aR[ 1 ] >= 2 .AND. aR[ 4 ] - aR[ 2 ] >= 11, 'tile usable' )
               FOR j := i + 1 TO n
                  Assert( aR[ 3 ] < a[ j, 1 ] .OR. a[ j, 3 ] < aR[ 1 ] .OR. ;
                     aR[ 4 ] < a[ j, 2 ] .OR. a[ j, 4 ] < aR[ 2 ], 'tile disjoint' )
               NEXT
               nTests++
            NEXT
            a := HBIDE_DbgRects( n, r, c, .T. )
            Assert( Len( a ) == n, 'cascade count' )
         NEXT
      NEXT
   NEXT
   SetMode( 25, 80 )
   oD := HBDebugger():New()
   oD:oWndCode:cCaption := 'Source - sample.prg'
   oD:oWndCode:bPainted := {|| hb_DispOutAt( oD:oWndCode:nTop + 1, oD:oWndCode:nLeft + 1, 'local nTotal := 9', 'W/B' ) }
   oD:oWndCode:Show( .T. )
   oD:oWndCommand:Show()
   oD:WindowLayout( 'TILE' )
   Assert( oD:oWndCode:nBottom < oD:oWndCommand:nTop, 'runtime tile' )
   aR := { oD:oWndCode:nTop, oD:oWndCode:nLeft, oD:oWndCode:nBottom, oD:oWndCode:nRight }
   oD:WindowLayout( 'ZOOM' )
   Assert( oD:oWndCode:nRight == 79 .AND. oD:oWndCode:nBottom == 23, 'runtime zoom' )
   oD:WindowLayout( 'ZOOM' )
   Assert( oD:oWndCode:nRight == aR[ 4 ], 'runtime restore' )
   hb_keyPut( K_DOWN ); hb_keyPut( K_ESC )
   oD:WindowEdit( .F. )
   Assert( oD:oWndCode:nTop == aR[ 1 ], 'move cancel' )
   hb_keyPut( K_DOWN ); hb_keyPut( K_ENTER )
   oD:WindowEdit( .F. )
   Assert( oD:oWndCode:nTop == aR[ 1 ] + 1, 'move accept' )
   hb_keyPut( K_UP ); hb_keyPut( K_ENTER )
   oD:WindowEdit( .T. )
   Assert( oD:oWndCode:nBottom == aR[ 3 ], 'size accept' )
   oD:WindowLayout( 'CASCADE' )
   Assert( oD:oWndCommand:nTop > oD:oWndCode:nTop, 'runtime cascade' )
   Assert( oD:WindowAt( 5, 10 ) == oD:oWndCode, 'focused panel wins overlaps' )
   oD:NextWindow()
   Assert( oD:WindowAt( 5, 10 ) == oD:oWndCommand, 'next panel wins overlaps' )
   Assert( oD:WindowAt( 0, 0 ) == NIL, 'menu row excluded' )
   hb_MemoWrit( '/tmp/hbide-layout-tests.txt' , 'PASS ' + hb_ntos( nTests ) + ' geometry cases; runtime tile/zoom/restore/move/cancel/size/cascade' )
   Inkey( 0.2 )
   RETURN
PROCEDURE Assert( lOk, cName )
   IF ! lOk
      hb_MemoWrit( '/tmp/hbide-layout-tests.txt', 'FAIL ' + cName )
      ErrorLevel( 1 )
      QUIT
   ENDIF
   RETURN

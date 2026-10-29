#include "inkey.ch"
#include "hbclass.ch"
PROCEDURE Main()
   LOCAL oD, a, aR, n, r, c, i, j, nTests := 0
   LOCAL oBrw
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
   // Cascade 0ab0ed7 puts the focused window in the most-offset front rect.
   Assert( oD:oWndCode:nTop > oD:oWndCommand:nTop, 'runtime cascade' )
   Assert( oD:WindowAt( 5, 10 ) == oD:oWndCode, 'focused panel wins overlaps' )
   oD:NextWindow()
   Assert( oD:WindowAt( 5, 10 ) == oD:oWndCommand, 'next panel wins overlaps' )
   Assert( oD:WindowAt( 0, 0 ) == NIL, 'menu row excluded' )
   oD:NextWindow()
   aR := { oD:oWndCode:nTop, oD:oWndCode:nLeft, oD:oWndCode:nBottom, oD:oWndCode:nRight }
   oD:WindowIconize()
   Assert( oD:oWndCode:nBottom - oD:oWndCode:nTop == 2, 'iconize one interior row' )
   Assert( oD:oWndCode:nRight - oD:oWndCode:nLeft == 14, 'iconize narrow width' )
   oD:WindowIconize()
   Assert( oD:oWndCode:nTop == aR[ 1 ] .AND. oD:oWndCode:nLeft == aR[ 2 ] .AND. ;
      oD:oWndCode:nBottom == aR[ 3 ] .AND. oD:oWndCode:nRight == aR[ 4 ], 'iconize restore' )
   oD:WindowResizeStep( -1 )
   Assert( oD:oWndCode:nBottom == aR[ 3 ] - 1 .AND. oD:oWndCode:nRight == aR[ 4 ] - 1, 'shrink contracts one row/col' )
   oD:WindowResizeStep( 1 )
   Assert( oD:oWndCode:nBottom == aR[ 3 ] .AND. oD:oWndCode:nRight == aR[ 4 ], 'grow restores one row/col' )
   // Scroll position and cursor row must survive iconize/restore: fitting the
   // browser into the icon strip lets HBDbBrowser:Configure() clamp rowPos and
   // shift nFirstVisible, so the browser must stay detached while iconized.
   oBrw := TFakeBrowser():New()
   oD:oWndCode:Browser := oBrw
   oD:WindowIconize()
   Assert( oD:oWndCode:Browser == NIL, 'iconize detaches browser' )
   Assert( oBrw:nResizes == 0, 'iconize does not resize the browser' )
   oD:WindowIconize()
   Assert( oD:oWndCode:Browser == oBrw, 'restore reattaches browser' )
   // The dangerous resize is the one into the one-row icon strip; a repaint
   // with the original geometry is a no-op for a real browser.
   Assert( AScan( oBrw:aHeights, 1 ) == 0, 'browser never resized to icon strip' )
   // Numeric command routes must obey the same desktop limits as arrows.
   oD:oWndCode:Browser := NIL
   oD:DoCommand( 'window move -99 -99' )
   Assert( oD:oWndCode:nTop == 1 .AND. oD:oWndCode:nLeft == 0, 'numeric move negative clamps' )
   oD:DoCommand( 'window move 999 999' )
   Assert( oD:oWndCode:nBottom <= 23 .AND. oD:oWndCode:nRight <= 79, 'numeric move positive clamps' )
   oD:DoCommand( 'window size 999 999' )
   Assert( oD:oWndCode:nBottom <= 23 .AND. oD:oWndCode:nRight <= 79, 'numeric size clamps' )
   oD:DoCommand( 'window size 6 20' )
   oD:DoCommand( 'window move 2 3' )
   Assert( oD:oWndCode:nTop == 2 .AND. oD:oWndCode:nLeft == 3, 'numeric move accepts valid position' )
   oD:DoCommand( 'window size 6 20' )
   Assert( oD:oWndCode:nBottom == 7 .AND. oD:oWndCode:nRight == 22, 'numeric size accepts valid extent' )
   aR := { oD:oWndCode:nTop, oD:oWndCode:nLeft, oD:oWndCode:nBottom, oD:oWndCode:nRight }
   FOR EACH a IN { 'window move abc 2', 'window move 1', 'window move 1 2 3', ;
                   'window move 1.2 3', 'window size 1 1', 'window size -5 20' }
      oD:DoCommand( a )
      Assert( oD:oWndCode:nTop == aR[ 1 ] .AND. oD:oWndCode:nLeft == aR[ 2 ] .AND. ;
         oD:oWndCode:nBottom == aR[ 3 ] .AND. oD:oWndCode:nRight == aR[ 4 ], 'invalid numeric command leaves geometry unchanged' )
   NEXT
   oD:DoCommand( 'window move +3 +4' )
   Assert( oD:oWndCode:nTop == 3 .AND. oD:oWndCode:nLeft == 4, 'numeric signed positive accepted' )
   oD:WindowIconize()
   oD:DoCommand( 'window size 1 1' )
   Assert( oD:IsWindowIconized( oD:oWndCode ), 'invalid size leaves iconized state unchanged' )
   oD:DoCommand( 'window size 8 25' )
   Assert( ! oD:IsWindowIconized( oD:oWndCode ) .AND. oD:oWndCode:nBottom == 10 .AND. ;
      oD:oWndCode:nRight == 28, 'numeric size restores iconized window before resize' )
   oD:MenuBar( .F. )
   Assert( ! oD:lMenuBar .AND. ! oD:oPullDown:GetItemByIdent( 'MENUBAR' ):checked, 'menu bar hides and unchecks' )
   Assert( Empty( AllTrim( TestRowText() ) ), 'hidden menu row blank' )
   oD:OpenMenu( 'O' )
   Assert( oD:oPullDown:IsOpen() .AND. 'Options' $ TestRowText(), 'hidden bar reveals for Options' )
   oD:oPullDown:ProcessKey( K_ESC ); oD:PaintMenuBar()
   Assert( ! oD:lMenuBar .AND. Empty( AllTrim( TestRowText() ) ), 'Esc hides temporary menu' )
   oD:OpenMenu( 'O' ); oD:oPullDown:ProcessKey( Asc('m') )
   Assert( oD:lMenuBar .AND. 'Options' $ TestRowText(), 'Options M restores bar' )
   oD:DoCommand( 'options menubar off' )
   Assert( ! oD:lMenuBar, 'command MenuBar OFF idempotent' )
   oD:DoCommand( 'options menubar off' )
   Assert( ! oD:lMenuBar, 'command MenuBar OFF repeat stable' )
   oD:DoCommand( 'options menubar on' )
   Assert( oD:lMenuBar, 'command MenuBar ON restores' )
   hb_MemoWrit( '/tmp/hbide-layout-tests.txt' , 'PASS ' + hb_ntos( nTests ) + ' geometry cases; runtime tile/zoom/restore/move/cancel/size/cascade/iconize/grow/shrink/numeric-command-bounds' )
   Inkey( 0.2 )
   RETURN
PROCEDURE Assert( lOk, cName )
   IF ! lOk
      hb_MemoWrit( '/tmp/hbide-layout-tests.txt', 'FAIL ' + cName )
      ErrorLevel( 1 )
      QUIT
   ENDIF
   RETURN


CREATE CLASS TFakeBrowser
   VAR nResizes INIT 0
   VAR aHeights INIT {}
   METHOD New() INLINE Self
   METHOD Resize( nTop, nLeft, nBottom, nRight )
ENDCLASS

METHOD Resize( nTop, nLeft, nBottom, nRight ) CLASS TFakeBrowser
   HB_SYMBOL_UNUSED( nLeft )
   HB_SYMBOL_UNUSED( nRight )
   ::nResizes++
   AAdd( ::aHeights, nBottom - nTop + 1 )
   RETURN Self

STATIC FUNCTION TestRowText()
   LOCAL cScreen := SaveScreen( 0, 0, 0, 79 ), c := '', n
   FOR n := 1 TO Len( cScreen ) STEP 2
      c += SubStr( cScreen, n, 1 )
   NEXT
   RETURN c

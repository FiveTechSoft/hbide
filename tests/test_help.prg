#include "inkey.ch"
PROCEDURE Main()
   LOCAL aTopics := HBIDEHelpTopics(), a, n, cBefore
   Assert( HBIDEHelpContext( ' ~Options ', '~Compiler Flags...' ) == 'Compiler flags', 'compiler context' )
   Assert( HBIDEHelpContext( ' ~File ', '~Save F2' ) == 'File menu', 'file context' )
   Assert( HBIDEHelpContext( ' ~Run ', '~Debug' ) == 'Debugger', 'debug context' )
   Assert( HBIDEHelpContext( ' ~Edit ', 'Repl~ace...' ) == 'Find, Replace, Goto Line', 'replace context' )
   Assert( HBIDEHelpContext( '', '' ) == 'Welcome to hbide', 'default context' )
   a := HBIDEHelpLines( 'alpha beta gamma delta epsilon', 10 )
   FOR EACH n IN a
      Assert( Len( n ) <= 10, 'wrap width' )
   NEXT
   Assert( HBIDEHelpLines( '', 20 )[ 1 ] == '', 'empty paragraph' )
   FOR EACH a IN aTopics
      FOR EACH n IN HBIDEHelpLinks( a[ 2 ], aTopics )
         Assert( n > 0 .AND. n <= Len( aTopics ), 'link resolves' )
         Assert( aTopics[ n, 2 ] != a[ 2 ], 'no self links' )
      NEXT
   NEXT
   Assert( Len( aTopics ) == 15, 'topic count' )
   SetMode( 25, 80 )
   hb_DispOutAt( 0, 0, 'EDITOR MUST SURVIVE', 'W/B' )
   cBefore := __dbgSaveScreen( 0, 0, MaxRow(), MaxCol() )
   hb_keyPut( K_ENTER ); hb_keyPut( K_BS ); hb_keyPut( K_ALT_RIGHT ); hb_keyPut( K_ESC )
   HBIDEHelpOpen( 'Welcome to hbide', aTopics )
   Assert( __dbgSaveScreen( 0, 0, MaxRow(), MaxCol() ) == cBefore, 'screen restored after links history' )
   hb_MemoWrit( '/tmp/hbide-help-tests.txt', 'PASS contexts/wrapping/links/history/screenrestore' )
   RETURN
PROCEDURE Assert( lOk, cName )
   IF ! lOk
      hb_MemoWrit( '/tmp/hbide-help-tests.txt', 'FAIL ' + cName )
      ErrorLevel( 1 )
      QUIT
   ENDIF
   RETURN

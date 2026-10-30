#include "inkey.ch"
PROCEDURE Main()
   LOCAL aTopics := HBIDEHelpTopics(), a, n, cBefore, nW, aL
   Assert( HBIDEHelpContext( ' ~Options ', '~Compiler Flags...' ) == 'Compiler flags', 'compiler context' )
   Assert( HBIDEHelpContext( ' ~File ', '~Save F2' ) == 'File menu', 'file context' )
   Assert( HBIDEHelpContext( ' ~Run ', '~Debug' ) == 'Debugger', 'debug context' )
   Assert( HBIDEHelpContext( ' ~Edit ', 'Repl~ace...' ) == 'Find, Replace, Goto Line', 'replace context' )
   Assert( HBIDEHelpContext( 'Project', 'Open .hbp' ) == 'Projects', 'project context' )
   Assert( HBIDEHelpContext( 'Window', 'Next' ) == 'Multiple documents', 'window context' )
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
   n := AScan( aTopics, {| t | t[ 2 ] == 'File menu' } )
   Assert( 'another independent document' $ aTopics[ n, 3 ] .AND. ! 'asked to Save' $ aTopics[ n, 3 ], 'File New help agrees with multidoc behavior' )
   n := AScan( aTopics, {| t | t[ 2 ] == 'Find, Replace, Goto Line' } )
   Assert( 'trailing blanks are kept' $ aTopics[ n, 3 ] .AND. ! 'are ignored' $ aTopics[ n, 3 ], 'Find help preserves trailing blanks' )
   n := AScan( aTopics, {| t | t[ 2 ] == 'Dialog designer' } )
   Assert( 'selection-only ComboBox' $ aTopics[ n, 3 ], 'Designer help names actual ComboBox contract' )
   n := AScan( aTopics, {| t | t[ 2 ] == 'Platform status and limits' } )
   Assert( 'COMPLETION_ROADMAP.md' $ aTopics[ n, 3 ], 'Help links current completion roadmap' )
   Assert( Len( aTopics ) == 23 + Len( HBIDEHelpDocTopics() ), 'topic count' )
   // every topic at the real panel widths (80 and 120 columns): nothing wider
   // than the panel (table rows included) and no word cut in the middle
   FOR EACH nW IN { 44, 84 }
      FOR EACH a IN aTopics
         aL := HBIDEHelpLines( a[ 3 ], nW )
         FOR EACH n IN aL
            Assert( Len( n ) <= nW, 'topic line fits panel: ' + a[ 2 ] )
         NEXT
         Assert( HBCompact( a[ 3 ] ) == HBCompact( JoinLines( aL ) ), 'all characters preserved: ' + a[ 2 ] )
         IF ! Left( a[ 2 ], 5 ) == 'Doc: '
            Assert( HBWordsOf( a[ 3 ] ) == HBWordsOfLines( aL ), 'no word cut/lost: ' + a[ 2 ] )
         ENDIF
      NEXT
   NEXT
   aL := HBIDEHelpLines( "Key      Does something fairly long that has to wrap under its own column", 40 )
   Assert( Len( aL ) >= 2 .AND. Left( aL[ 2 ], 9 ) == Space( 9 ) .AND. ! Left( aL[ 2 ], 10 ) == Space( 10 ), 'table row hangs under description column' )
   aL := HBIDEHelpLines( "x https://github.com/FiveTechSoft/hbide y", 40 )
   Assert( AScan( aL, {| c | "https://github.com/FiveTechSoft/hbide" $ c } ) > 0, 'url kept whole' )
   aL := HBIDEHelpLines( "it's one line" + Chr( 10 ) + "second 'quoted' line" + Chr( 10 ) + "third", 80 )
   Assert( Len( aL ) == 3, 'apostrophes do not swallow line breaks' )
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
STATIC FUNCTION HBWordsOf( c )
   LOCAL w, s := ""
   FOR EACH w IN hb_ATokens( StrTran( StrTran( c, Chr( 13 ), "" ), Chr( 10 ), " " ), " " )
      IF ! Empty( w )
         s += w + "|"
      ENDIF
   NEXT
   RETURN s
STATIC FUNCTION HBWordsOfLines( a )
   LOCAL c, s := ""
   FOR EACH c IN a
      s += HBWordsOf( c )
   NEXT
   RETURN s

STATIC FUNCTION HBCompact( c )
   c := StrTran( c, Chr( 13 ), "" )
   c := StrTran( c, Chr( 10 ), "" )
RETURN StrTran( c, " ", "" )

STATIC FUNCTION JoinLines( aLines )
   LOCAL c, s := ""
   FOR EACH c IN aLines
      s += c
   NEXT
RETURN s

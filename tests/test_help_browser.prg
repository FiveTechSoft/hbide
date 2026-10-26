#include "inkey.ch"
// Model + screen test for the tree help browser in help.prg. Build:
//   hbmk2 tests/test_help_browser.prg help.prg -gttrm
// Result file: /tmp/hbide-help-browser-tests.txt
PROCEDURE Main()
   LOCAL c
   LOCAL aTopics := HBIDEHelpTopics(), aRows := HBIDEHelpTree( aTopics )
   LOCAL a, n, nTopics := 0, cBefore, cOldCwd := hb_cwd()
   // every topic exactly once, sections in order
   FOR EACH a IN aRows
      IF a[ 1 ] == "T"
         nTopics++
         Assert( AScan( aTopics, { | t | t[ 2 ] == a[ 3 ] } ) > 0, 'tree topic exists: ' + a[ 3 ] )
      ENDIF
   NEXT
   Assert( nTopics == Len( aTopics ), 'tree covers every topic' )
   Assert( aRows[ 1 ][ 1 ] == 'S' .AND. aRows[ 1 ][ 3 ] == '1. Basics', 'first row is section 1' )
   Assert( Len( HBIDEHelpSections() ) == 4, 'four sections' )
   // section overview lists its topics
   a := HBIDEHelpSectionText( 3, aTopics )
   Assert( 'Debugger' $ a .AND. 'Dialog designer' $ a, 'section overview lists topics' )
   // search matches across titles and bodies
   a := HBIDEHelpMatches( aTopics, 44, 'JSON' )
   Assert( Len( a ) > 0, 'search finds json' )
   Assert( aTopics[ a[ 1 ][ 1 ], 2 ] == 'Dialog designer' .OR. aTopics[ a[ 1 ][ 1 ], 2 ] == 'Options menu', 'json match in designer/options' )
   Assert( Empty( HBIDEHelpMatches( aTopics, 44, 'ZZZNOPE' ) ), 'no false matches' )
   Assert( Empty( HBIDEHelpMatches( aTopics, 44, '' ) ), 'empty query matches nothing' )
   // reflow: prose wraps, preformatted table rows keep their columns
   a := HBIDEHelpLines( aTopics[ AScan( aTopics, { | t | t[ 2 ] == 'Debugger' } ), 3 ], 30 )
   n := 0
   FOR EACH c IN a
      IF 'F5 Go / stop at breakpoint' $ c .AND. 'F7 Run to cursor' $ c
         n := 1
      ENDIF
   NEXT
   Assert( n == 1, 'preformatted table row not rewrapped' )
   Assert( HBHelpOneLine( 'New            Starts an empty buffer' ) == 'New Starts an empty buffer', 'one-line summary collapses columns' )
   // export writes real markdown with every topic
   hb_cwd( '/tmp' )
   FErase( '/tmp/hbide-help.md' )
   Assert( HBIDEHelpExport( aTopics, 'hbide-help.md' ), 'export writes file' )
   a := hb_MemoRead( '/tmp/hbide-help.md' )
   Assert( '# hbide - Help' $ a, 'markdown title' )
   Assert( '## 1. Basics' $ a .AND. '## 4. Help and about' $ a, 'markdown sections' )
   FOR EACH n IN aTopics
      Assert( n[ 2 ] $ a, 'markdown has topic: ' + n[ 2 ] )
   NEXT
   // interactive: export via buttons, then Esc; screen must be restored
   SetMode( 25, 80 )
   hb_DispOutAt( 0, 0, 'EDITOR MUST SURVIVE', 'W/B' )
   cBefore := __dbgSaveScreen( 0, 0, MaxRow(), MaxCol() )
   hb_keyPut( K_TAB ); hb_keyPut( K_TAB )          // index -> text -> buttons
   hb_keyPut( K_RIGHT ); hb_keyPut( K_RIGHT )      // Export .md
   hb_keyPut( K_ENTER )
   hb_keyPut( K_ESC )
   HBIDEHelpBrowser( aTopics, 0 )
   Assert( __dbgSaveScreen( 0, 0, MaxRow(), MaxCol() ) == cBefore, 'screen restored after export+esc' )
   Assert( hb_FileExists( '/tmp/hbide-help.md' ), 'button export writes file' )
   // interactive: search + next + navigation; screen restored
   hb_keyPut( K_F7 )
   hb_keyPut( Asc( 'j' ) ); hb_keyPut( Asc( 's' ) ); hb_keyPut( Asc( 'o' ) ); hb_keyPut( Asc( 'n' ) )
   hb_keyPut( K_ENTER )
   hb_keyPut( K_F3 )                               // next match, wraps
   hb_keyPut( K_DOWN ); hb_keyPut( K_UP )          // index still navigable
   hb_keyPut( K_ENTER )                            // to text pane
   hb_keyPut( K_PGDN ); hb_keyPut( K_HOME )        // scroll
   hb_keyPut( K_ESC )
   HBIDEHelpBrowser( aTopics, 0 )
   Assert( __dbgSaveScreen( 0, 0, MaxRow(), MaxCol() ) == cBefore, 'screen restored after search+esc' )
   // start on a given topic
   hb_keyPut( K_ESC )
   HBIDEHelpBrowser( aTopics, AScan( aTopics, { | t | t[ 2 ] == 'Debugger' } ) )
   Assert( __dbgSaveScreen( 0, 0, MaxRow(), MaxCol() ) == cBefore, 'screen restored after direct topic' )
   hb_cwd( cOldCwd )
   hb_MemoWrit( '/tmp/hbide-help-browser-tests.txt', 'PASS tree/sections/search/export/buttons/screenrestore' )
   RETURN
PROCEDURE Assert( lOk, cName )
   IF ! lOk
      hb_MemoWrit( '/tmp/hbide-help-browser-tests.txt', 'FAIL ' + cName )
      ErrorLevel( 1 )
      QUIT
   ENDIF
   RETURN

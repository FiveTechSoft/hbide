// Interactive key-queue test: build with -gtstd, NOT -gtcgi (which injects Enter).
#include "inkey.ch"
PROCEDURE Main( cHbmk2 )
   LOCAL oP := HBIDEProject():New(), h, cTmp := hb_DirTemp() + 'hbide-project-ui-' + StrTran( hb_TToS( hb_DateTime() ), ".", "" ) + '/', a
   hb_DirBuild( cTmp )
   hb_MemoWrit( cTmp + 'app.hbp', 'main.prg second.prg' + hb_eol() + '-gtstd' + hb_eol() + '-oapp' )
   hb_MemoWrit( cTmp + 'main.prg', 'procedure Main()' + hb_eol() + '? Compute(3)' + hb_eol() + 'return' )
   hb_MemoWrit( cTmp + 'second.prg', 'function Compute(n)' + hb_eol() + 'return n +' )
   a := HBIDEProjectDiagnostics( 'unexpected' + Chr(34) + hb_eol() + 'second.prg(2) Error E0020 broken', cTmp )
   Assert( Len(a) == 1 .AND. a[1,'line'] == 2, 'unbalanced quote cannot hide next diagnostic' )
   oP:Open( cTmp + 'app.hbp' )
   hb_keyPut( K_ENTER )
   h := HBIDEProjectDesktop( oP, cHbmk2 )
   Assert( h[ 'path' ] == cTmp + 'main.prg' .AND. h[ 'line' ] == 1, 'member returns navigation request' )
   oP:Build( cHbmk2, .T. )
   Assert( oP:hBuild['exit'] != 0, 'actual syntax-error build exit' )
   Assert( HB_ISARRAY(oP:hBuild['diagnostics']), 'diagnostics is array' )
   Assert( Len(oP:hBuild['diagnostics']) == 1, 'one diagnostic before UI' )
   hb_keyPut( K_F4 ); hb_keyPut( K_ENTER )
   h := HBIDEProjectDesktop( oP, cHbmk2 )
   Assert( h[ 'path' ] == cTmp + 'second.prg' .AND. h[ 'line' ] == 2, 'diagnostic returns exact navigation' )
   hb_keyPut( K_F4 ); hb_keyPut( K_F6 ); hb_keyPut( K_ESC ); hb_keyPut( K_ESC )
   h := HBIDEProjectDesktop( oP, cHbmk2 )
   Assert( h == NIL, 'full output returns and cancel has no navigation' )
   hb_MemoWrit( '/tmp/hbide-project-ui-tests.txt', 'PASS sources navigation, diagnostic file/line, output and cancel' )
   RETURN
PROCEDURE Assert( lOk, cText )
   IF ! lOk
      hb_MemoWrit( '/tmp/hbide-project-ui-tests.txt', 'FAIL ' + cText )
      ErrorLevel( 1 )
      QUIT
   ENDIF
   RETURN

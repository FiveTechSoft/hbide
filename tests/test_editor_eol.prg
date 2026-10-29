#include "hbclass.ch"
#include "inkey.ch"
PROCEDURE Main()
   LOCAL o, cFile := hb_DirTemp() + 'hbide-eol-' + hb_ntos( hb_RandomInt( 999999999 ) ) + '.prg'
   LOCAL cCRLF := Chr( 13 ) + Chr( 10 ), cLF := Chr( 10 ), cText, aCase
   LOCAL nPass := 0, nFail := 0, oRecovered, cJournal, lOk
   FOR EACH aCase IN { { 'CRLF', cCRLF }, { 'LF', cLF } }
      cText := 'function Main()' + aCase[ 2 ] + '   return nil' + aCase[ 2 ]
      hb_MemoWrit( cFile, cText )
      o := HBSrcEdit():New( '', 2, 1, 20, 79, .T. )
      o:LoadFile( cFile )
      IF o:SaveFile() .and. hb_MemoRead( cFile ) == cText
         nPass++
         ? 'PASS:', aCase[ 1 ], 'load-save is byte exact'
      ELSE
         nFail++
         ? 'FAIL:', aCase[ 1 ], 'load-save changed bytes'
      ENDIF
   NEXT
   Set( _SET_INSERT, .T. )
   // Fresh edits, undo/redo and journal reload use the same terminator.
   FOR EACH aCase IN { { 'CRLF', cCRLF }, { 'LF', cLF } }
      cText := 'abc' + aCase[ 2 ] + 'def' + aCase[ 2 ]
      o:LoadText( cText )
      o:GoTo( 1, 8 )
      o:Edit( K_ENTER )
      lOk := o:GetText() == 'abc' + aCase[ 2 ] + aCase[ 2 ] + 'def' + aCase[ 2 ]
      o:Undo()
      lOk := lOk .and. o:GetText() == cText
      o:Redo()
      lOk := lOk .and. o:GetText() == 'abc' + aCase[ 2 ] + aCase[ 2 ] + 'def' + aCase[ 2 ]
      cJournal := o:GetText()
      oRecovered := HBSrcEdit():New( '', 2, 1, 20, 79, .T. )
      oRecovered:LoadText( cJournal )
      oRecovered:cFile := cFile
      lOk := lOk .and. oRecovered:SaveFile() .and. hb_MemoRead( cFile ) == cJournal
      nPass += iif( lOk, 1, 0 )
      nFail += iif( lOk, 0, 1 )
      ? iif( lOk, 'PASS:', 'FAIL:' ), aCase[ 1 ], 'split, undo, redo and journal reload'
   NEXT
   FErase( cFile )
   ? 'TOTAL', nPass, 'PASS', nFail, 'FAIL'
   ErrorLevel( iif( nFail == 0, 0, 1 ) )
   RETURN
FUNCTION HBIDE_MsgAlert( cText )
   HB_SYMBOL_UNUSED( cText )
   RETURN 1

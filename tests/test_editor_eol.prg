#include "hbclass.ch"
#include "inkey.ch"
PROCEDURE Main()
   LOCAL o, cFile := hb_DirTemp() + 'hbide-eol-' + hb_ntos( hb_RandomInt( 999999999 ) ) + '.prg'
   LOCAL cCRLF := Chr( 13 ) + Chr( 10 ), cLF := Chr( 10 ), cText, aCase
   LOCAL nPass := 0, nFail := 0, oRecovered, cJournal, lOk, n
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
   // Every edit is checked in both directions, including adjacent metadata.
   cText := 'abc' + cCRLF + 'def' + cLF + 'ghi' + Chr( 13 ) + 'tail'
   o:LoadText( cText )
   Check( o:GetText() == cText, 'mixed CRLF/LF/CR exact load', @nPass, @nFail )
   o:cFile := cFile
   Check( o:SaveFile() .and. hb_MemoRead( cFile ) == cText, 'mixed exact disk save', @nPass, @nFail )
   o:GoTo( 2, 6 )
   o:Edit( K_ENTER )
   cJournal := 'abc' + cCRLF + 'd' + cLF + 'ef' + cLF + 'ghi' + Chr( 13 ) + 'tail'
   Check( o:GetText() == cJournal, 'split inherits local LF', @nPass, @nFail )
   o:Undo()
   Check( o:GetText() == cText, 'mixed split undo', @nPass, @nFail )
   o:Redo()
   Check( o:GetText() == cJournal, 'mixed split redo', @nPass, @nFail )
   oRecovered:LoadText( cJournal )
   Check( oRecovered:GetText() == cJournal, 'mixed journal text reload', @nPass, @nFail )
   FOR EACH aCase IN { { 'Delete join', K_DEL, 1, 8, 'abcdef' + cLF + 'ghi' + Chr( 13 ) + 'tail' }, ;
                      { 'Backspace join', K_BS, 2, 5, 'abcdef' + cLF + 'ghi' + Chr( 13 ) + 'tail' }, ;
                      { 'type', Asc( 'X' ), 2, 6, 'abc' + cCRLF + 'dXef' + cLF + 'ghi' + Chr( 13 ) + 'tail' } }
      o:LoadText( cText )
      o:GoTo( aCase[ 3 ], aCase[ 4 ] )
      o:Edit( aCase[ 2 ] )
      Check( o:GetText() == aCase[ 5 ], aCase[ 1 ], @nPass, @nFail )
      o:Undo()
      Check( o:GetText() == cText, aCase[ 1 ] + ' undo', @nPass, @nFail )
      o:Redo()
      Check( o:GetText() == aCase[ 5 ], aCase[ 1 ] + ' redo', @nPass, @nFail )
   NEXT
   o:LoadText( cText )
   o:GoTo( 4, 5 )
   o:DuplicateLine()
   cJournal := cText + cCRLF + 'tail'
   Check( o:GetText() == cJournal, 'duplicate unterminated final line', @nPass, @nFail )
   o:Undo()
   Check( o:GetText() == cText, 'duplicate EOF undo boundary', @nPass, @nFail )
   o:Redo()
   Check( o:GetText() == cJournal, 'duplicate EOF redo boundary', @nPass, @nFail )
   o:DeleteLine()
   Check( o:GetText() == cText, 'delete final line', @nPass, @nFail )
   o:Undo()
   Check( o:GetText() == cJournal, 'delete final undo boundary', @nPass, @nFail )
   o:LoadText( cText )
   o:ReplaceAll( 'd', 'D' )
   Check( o:GetText() == StrTran( cText, 'd', 'D' ), 'replace keeps boundaries', @nPass, @nFail )
   o:Undo()
   Check( o:GetText() == cText, 'replace undo boundaries', @nPass, @nFail )
   o:LoadText( cText )
   o:GoTo( 1, 6 )
   o:Edit( K_F8 )
   o:GoTo( 3, 6 )
   o:CutSelection()
   cJournal := 'ahi' + Chr( 13 ) + 'tail'
   Check( o:GetText() == cJournal, 'cut multiline keeps final fragment CR', @nPass, @nFail )
   o:Undo()
   Check( o:GetText() == cText, 'cut undo all boundaries', @nPass, @nFail )
   o:Redo()
   Check( o:GetText() == cJournal, 'cut redo boundaries', @nPass, @nFail )
   o:LoadText( cText )
   o:GoTo( 4, 5 )
   o:cClipboard := 'new one' + hb_eol() + 'new two'
   o:PasteLine()
   cJournal := cText + cCRLF + 'new one' + cCRLF + 'new two'
   Check( o:GetText() == cJournal, 'paste multiline at EOF creates preferred boundaries', @nPass, @nFail )
   o:Undo()
   Check( o:GetText() == cText, 'paste EOF undo', @nPass, @nFail )
   o:Redo()
   Check( o:GetText() == cJournal, 'paste EOF redo', @nPass, @nFail )
   FOR EACH aCase IN { { 'line70000', Replicate( 'x', 70000 ) + cCRLF + 'tail' }, ;
                      { 'tab preserved', Chr( 9 ) + 'abc' + cCRLF + 'a' + Chr( 9 ) + 'b' }, ;
                      { 'empty', '' }, { 'one CR', Chr( 13 ) }, ;
                      { 'mixed blanks', cCRLF + cLF + Chr( 13 ) + 'end' }, ;
                      { 'terminated mixed', cText + cLF } }
      o:LoadText( aCase[ 2 ] )
      Check( o:GetText() == aCase[ 2 ], aCase[ 1 ] + ' roundtrip', @nPass, @nFail )
   NEXT
   cText := 'alpha beta gamma delta' + cCRLF + 'second words here' + cLF + 'tail'
   o := HBSrcEdit():New( cText, 2, 1, 20, 79, .T., 10 )
   Check( o:GetText() == cText, 'wordwrap mixed load', @nPass, @nFail )
   o:GoTo( 1, 5 )
   o:Edit( Asc( 'Z' ) )
   Check( o:GetText() == 'Z' + cText, 'wordwrap edit keeps boundaries', @nPass, @nFail )
   o:Undo()
   Check( o:GetText() == cText, 'wordwrap undo soft boundaries', @nPass, @nFail )
   o:Redo()
   Check( o:GetText() == 'Z' + cText, 'wordwrap redo soft boundaries', @nPass, @nFail )
   o:LoadText( cText )
   o:GoTo( 1, 5 )
   FOR EACH aCase IN { 'Z', 'Z', 'Z', 'Z', 'Z', 'Z', 'Z', 'Z', 'Z', 'Z', 'Z', 'Z' }
      o:Edit( Asc( aCase ) )
   NEXT
   Check( o:GetText() == Replicate( 'Z', 12 ) + cText, 'wordwrap reflow keeps logical cursor and boundaries', @nPass, @nFail )
   cJournal := o:GetText()
   o:Undo()
   Check( o:GetText() != cJournal, 'reflow undo changes text', @nPass, @nFail )
   o:Redo()
   Check( o:GetText() == cJournal, 'reflow redo exact', @nPass, @nFail )
   FOR EACH aCase IN { { 'start', 1, 5, 1 }, { 'inside', 1, 10, 6 }, { 'next soft row', 2, 5, 12 } }
      cText := 'alpha beta gamma delta' + cCRLF + 'second words here' + cLF + 'tail'
      o:LoadText( cText )
      o:GoTo( aCase[ 2 ], aCase[ 3 ] )
      cJournal := Left( cText, aCase[ 4 ] - 1 ) + Replicate( 'Z', 12 ) + SubStr( cText, aCase[ 4 ] )
      for n := 1 to 12
         o:Edit( Asc( 'Z' ) )
      next
      Check( o:GetText() == cJournal, 'reflow cursor ' + aCase[ 1 ], @nPass, @nFail )
   NEXT
   cText := Chr( 9 ) + 'abc' + cCRLF + 'a' + Chr( 9 ) + 'b'
   o := HBSrcEdit():New( cText, 2, 1, 20, 79, .T. )
   o:GoTo( 1, 6 )
   o:Edit( Asc( 'Z' ) )
   cJournal := Chr( 9 ) + 'Zabc' + cCRLF + 'a' + Chr( 9 ) + 'b'
   Check( o:GetText() == cJournal, 'edit after tab keeps original tabs', @nPass, @nFail )
   o:Undo()
   Check( o:GetText() == cText, 'tab edit undo byteexact', @nPass, @nFail )
   o:Redo()
   Check( o:GetText() == cJournal, 'tab edit redo byteexact', @nPass, @nFail )
   o:LoadText( Replicate( 'x', 70000 ) + cCRLF + 'tail' )
   Check( o:LineCount() == 2, '70000 characters remain one physical source line', @nPass, @nFail )
   o:LoadText( Chr( 9 ) + 'abc' + Chr( 9 ) + 'def' )
   Check( o:VisualText( o:GetLine( 1 ) ) == '    abc def', 'tabs expand only for paint', @nPass, @nFail )
   o:GoTo( 1, 6 )
   Check( o:Col() == 9, 'screen cursor after first TAB', @nPass, @nFail )
   o:Edit( K_RIGHT )
   Check( o:Col() == 10, 'screen cursor next character', @nPass, @nFail )
   Check( o:CharCol( 1, 5 ) == 2 .and. o:CharCol( 1, 9 ) == 6, 'mouse inverse tab mapping', @nPass, @nFail )
   o:GoTo( 1, 5 )
   o:Edit( K_F8 )
   o:Edit( K_RIGHT )
   o:CutSelection()
   Check( o:GetText() == 'abc' + Chr( 9 ) + 'def' .and. o:cClipboard == Chr( 9 ), 'cut selected TAB is one byte', @nPass, @nFail )
   o:Undo()
   Check( o:GetText() == Chr( 9 ) + 'abc' + Chr( 9 ) + 'def', 'cut TAB undo exact', @nPass, @nFail )
   o:LoadText( Replicate( Chr( 9 ), 50 ) + 'end' )
   o:GoTo( 1, 55 )
   Check( o:Col() <= 79 .and. o:Col() >= 5, 'tab horizontal scroll keeps cursor in viewport', @nPass, @nFail )
   o:LoadText( Chr( 9 ) + 'x' )
   o:GoTo( 1, 6 )
   o:Edit( K_TAB )
   Check( o:GetText() == Chr( 9 ) + Space( 4 ) + 'x', 'TAB insertion uses visual tab stop after raw TAB', @nPass, @nFail )
   o:Undo()
   Check( o:GetText() == Chr( 9 ) + 'x', 'TAB insertion undo', @nPass, @nFail )
   o:Redo()
   Check( o:GetText() == Chr( 9 ) + Space( 4 ) + 'x', 'TAB insertion redo', @nPass, @nFail )
   o:LoadText( Chr( 9 ) + 'ab' )
   o:GoTo( 1, 8 )
   o:Edit( K_TAB )
   Check( o:GetText() == Chr( 9 ) + 'ab  ', 'TAB at visual column7 adds2spaces', @nPass, @nFail )
   FErase( cFile )
   ? 'TOTAL', nPass, 'PASS', nFail, 'FAIL'
   ErrorLevel( iif( nFail == 0, 0, 1 ) )
   RETURN
FUNCTION HBIDE_MsgAlert( cText )
   HB_SYMBOL_UNUSED( cText )
   RETURN 1

STATIC PROCEDURE Check( lOk, cName, nPass, nFail )
   nPass += iif( lOk, 1, 0 )
   nFail += iif( lOk, 0, 1 )
   ? iif( lOk, 'PASS:', 'FAIL:' ), cName
   RETURN

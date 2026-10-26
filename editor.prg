#include "hbclass.ch"
#include "inkey.ch"
#include "setcurs.ch"
#include "directry.ch"

#define _REFRESH_LINE   1
#define _REFRESH_ALL    2

#ifndef MAX_UNDO
#define MAX_UNDO        300
#endif

//-----------------------------------------------------------------------------------------//

function BuildEditor()

   local cCode   := "function Main()"  + hb_eol() + hb_eol() + ;
                    '   Alert( "Hello world from Harbour" )' + hb_eol() + hb_eol() + ;
                    "return nil"
   local oEditor := HBSrcEdit():New( cCode, 2, 1, MaxRow() - 2,;
                                     MaxCol() - 1, .T. ), nKey

   oEditor:SetColor( "W/B,N/BG" )
   oEditor:cFile = "noname.prg"

return oEditor

//-----------------------------------------------------------------------------------------//

CLASS HBSrcEdit FROM HBEditor

   DATA   cFile
   DATA   cClrString   INIT "GR+"
   DATA   cClrOperator INIT "R+"
   DATA   cClrKeyword1 INIT "G+"
   DATA   cClrKeyword2 INIT "BG+"
   DATA   cClrSelRow   INIT "N/BG"
   DATA   cClrComment  INIT "RB+"
   DATA   cClrNumber   INIT "W+"

   DATA   cOperators   INIT "[{}],||[<>]<><=>=(),;.::=!=():),{})[]){}+=++---=*=/=%=^==$" + ;
                            "[{||,...>,>],()[?"
   DATA   cKeywords1   INIT ;
      "FUNCTION,DO,CASE,OTHERWISE,ENDCASE,IF,ELSE,ELSEIF,ENDIF,WHILE," + ;
      "FOR,NEXT,RETURN,CREATE,FROM,DATA,INIT,METHOD,INLINE,ENDCLASS,VIRTUAL," + ;
      "MENU,MENUITEM,PROMPT,IDENT,CHECKED,ACTION,SEPARATOR,ENDMENU," + ;
      "CLEAR,SCREEN,CLASS,BEGIN,SEQUENCE,RECOVER,SWITCH,EXIT,LOOP," + ;
      "WITH,OBJECT,EACH,IN,ACTIVATE,END,ANNOUNCE,REQUEST,PROCEDURE"
   DATA   cKeywords2   INIT "STATIC,LOCAL,NIL,SELF,SUPER,#INCLUDE,#XCOMMAND,#DEFINE," + ;
      "#IFDEF,#IFNDEF,#ENDIF,#ELSE,PRIVATE,PUBLIC,FIELD,MEMVAR,.T.,.F.,.AND.,.OR.,.NOT."

   DATA   cClipboard   INIT ""
   DATA   cFindText    INIT ""
   DATA   nSelRow      INIT 0
   DATA   lMark        INIT .F.   // range-selection anchor active (F8)
   DATA   nMarkRow     INIT 0     // anchor row/col, nCol semantics (5-based)
   DATA   nMarkCol     INIT 0
   DATA   nSelStart    INIT 0
   DATA   nSelEnd      INIT 0
   DATA   aUndo        INIT {}
   DATA   aRedo        INIT {}
   DATA   aBlkCmt      INIT {}   // per-line flag: the line starts inside a /* */ block
   DATA   nBlkDirty    INIT 1    // first line whose block-comment state is stale
   DATA   aBPs         INIT {}   // debugger breakpoints: absolute line numbers (F9)
   DATA   cClrBP       INIT "W+/R"
   DATA   lBPsMoved    INIT .F. // AdjustBPs moved a mark; Edit() repaints
   DATA   nSavedUndoLen INIT 0
   DATA   lInUndo      INIT .F.
   DATA   lOpRecorded  INIT .F.
   DATA   lUtf8        INIT .F.   // the file on disk is UTF-8: convert in/out
   DATA   lUtf8Bom     INIT .F.   // it carried a BOM: write it back
   DATA   lUtf8Raw     INIT .F.   // lossy UTF-8 kept raw: saving invalid UTF-8 is blocked
   DATA   cSeenStamp   INIT ""   // disk stamp last seen (detection, load, own save)
   DATA   cLoadStamp   INIT ""   // disk stamp at last load/own save (save guard)

   METHOD Edit( nKey )
   METHOD EditKey( nKey )
   METHOD LinesSnapshot()
   METHOD RecordEdit( aBefore )
   METHOD PushOp( nRow, aOld, aNew )
   METHOD ApplyOp( aOp, lInverse )
   METHOD Undo()
   METHOD Redo()
   METHOD BlkCmtState( nLine )
   METHOD ScanBlkLine( cText, lIn )
   METHOD LoadText( cText )
   METHOD LoadFile( cFileName )
   METHOD SaveFile()
   METHOD DiskStamp( cFile )
   METHOD DiskChanged()
   METHOD DiskChangedSinceLoad()
   METHOD FileVanished()
   METHOD Display()
   METHOD DisplayLine( nLine )
   METHOD LineColor( nLine ) INLINE ;
                     If( nLine == ::nRow - ::nFirstRow + ::nTop, ::cClrSelRow, ::cColorSpec )
   METHOD MoveCursor( nKey )
   METHOD ShowCursor() INLINE ( SetCursor( SC_NORMAL ), SetPos( ::nRow - ::nFirstRow + 2, ::nCol ) )
   METHOD CopyLine()
   METHOD PasteLine()
   METHOD DeleteLine()
   METHOD DuplicateLine()
   METHOD FindText( cText )
   METHOD FindNext()
   METHOD ReplaceAll( cFind, cReplace )
   METHOD SelectWord( nRow, nTextCol )
   METHOD WordJump( lRight )
   METHOD ClearSelection()
   METHOD HasMark()                        INLINE ::lMark
   METHOD ToggleMark()
   METHOD ToggleBP()
   METHOD AdjustBPs( nRow, aOld, aNew )
   METHOD SelRange()
   METHOD SelectionText()
   METHOD CopySelection()
   METHOD CutSelection()
   METHOD SelDelete( aSel )

ENDCLASS

//-----------------------------------------------------------------------------------------//

METHOD ClearSelection() CLASS HBSrcEdit

   local nOldSelRow := ::nSelRow

   ::nSelRow   = 0
   ::nSelStart = 0
   ::nSelEnd   = 0
   ::lMark     = .F.

   // Refresh the line that had the selection
   if nOldSelRow > 0
      ::Display()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD CopyLine() CLASS HBSrcEdit

   ::cClipboard = ::aText[ ::nRow ]:cText

return nil

//-----------------------------------------------------------------------------------------//

METHOD PasteLine() CLASS HBSrcEdit

   local aLines, n

   if ! Empty( ::cClipboard )
      ::ClearSelection()   // same stale-mark guard as CopySelection
      // A copied/cut block carries hb_eol() between its lines: split it back
      // into real lines (hb_ATokens with lAll=.T. keeps empty ones) instead
      // of embedding the eol bytes inside a single model line.
      aLines := hb_ATokens( ::cClipboard, hb_eol(), .T. )
      // Insert below current line; independent of insert/overstrike mode
      ::PushOp( ::nRow + 1, {}, aLines )
      for n := 1 to Len( aLines )
         if ::nRow + n > Len( ::aText )
            ::AddLine( aLines[ n ], .F. )
         else
            ::InsertLine( aLines[ n ], .F., ::nRow + n )
         endif
      next
      ::lDirty := .T.
      ::GoTo( ::nRow + 1, 5 )
      ::Display()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD DeleteLine() CLASS HBSrcEdit

   if Len( ::aText ) > 1
      ::cClipboard = ::aText[ ::nRow ]:cText
      ::PushOp( ::nRow, { ::cClipboard }, {} )
      ::RemoveLine( ::nRow )
      ::lDirty := .T.
      ::GoTo( ::nRow, 5 )  // GoTo clamps nRow to LineCount
      ::Display()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD DuplicateLine() CLASS HBSrcEdit

   // Insert a copy below current line; independent of insert/overstrike mode
   ::PushOp( ::nRow + 1, {}, { ::aText[ ::nRow ]:cText } )
   ::InsertLine( ::aText[ ::nRow ]:cText, .F., ::nRow + 1 )
   ::lDirty := .T.
   ::GoTo( ::nRow + 1, 5 )
   ::Display()

return nil

//-----------------------------------------------------------------------------------------//

METHOD FindText( cText ) CLASS HBSrcEdit

   local n, nPos, nStart

   // Len(), not Empty(): an all-blank search string is real data
   if Len( cText ) == 0
      return nil
   endif

   ::cFindText = cText

   // Search from current position forward
   for n = ::nRow to Len( ::aText )
      if n == ::nRow
         // gutter positions (nCol <= 4, e.g. after Ctrl+Home) must clamp to
         // the start of the text; SubStr() with a negative start skips most
         // of the line and misses real matches
         nStart = Max( ::nCol - 4 + 1, 1 )
         // hb_UAt/hb_USubStr: char-based positions (nCol/GoTo are char-based;
         // byte At/SubStr misplaced the cursor past multibyte chars in UTF8
         // mode and are identical to the byte versions in 8-bit codepages)
         nPos = hb_UAt( Upper( cText ), Upper( hb_USubStr( ::aText[ n ]:cText, nStart ) ) )
         if nPos > 0
            nPos += nStart - 1
         endif
      else
         nPos = hb_UAt( Upper( cText ), Upper( ::aText[ n ]:cText ) )
      endif
      if nPos > 0
         ::GoTo( n, nPos + 4 )
         ::Display()
         return nil
      endif
   next

   // Wrap around from beginning
   for n = 1 to ::nRow - 1
      nPos = hb_UAt( Upper( cText ), Upper( ::aText[ n ]:cText ) )
      if nPos > 0
         ::GoTo( n, nPos + 4 )
         ::Display()
         return nil
      endif
   next

return nil

//-----------------------------------------------------------------------------------------//

METHOD FindNext() CLASS HBSrcEdit

   local nOldCol := ::nCol

   ::nCol++
   ::FindText( ::cFindText )
   if ::nCol == nOldCol + 1
      ::nCol = nOldCol
   endif

return nil

//-----------------------------------------------------------------------------------------//

// replace every occurrence (case-insensitive) in the whole buffer.
// Recorded as a single undoable op.  Adapted from tvedit.prg ReplaceSel().
METHOD ReplaceAll( cFind, cReplace ) CLASS HBSrcEdit

   LOCAL n, nPos, nFrom, cLine, cNew, nCount := 0
   LOCAL aOld := {}, aNew := {}
   LOCAL cFindU := Upper( cFind )

   if Empty( cFind )
      return 0
   endif

   for n = 1 to Len( ::aText )
      AAdd( aOld, ::aText[ n ]:cText )
      cLine := ::aText[ n ]:cText
      cNew := ""
      nFrom := 1
      while ( nPos := At( cFindU, Upper( SubStr( cLine, nFrom ) ) ) ) > 0
         cNew += SubStr( cLine, nFrom, nPos - 1 ) + cReplace
         nFrom += nPos - 1 + Len( cFind )
         nCount++
      end
      AAdd( aNew, cNew + SubStr( cLine, nFrom ) )
   next

   if nCount > 0
      for n = 1 to Len( ::aText )
         ::aText[ n ]:cText := aNew[ n ]
      next
      ::PushOp( 1, aOld, aNew )
      ::lDirty := .T.
      ::Display()
   endif

return nCount

//-----------------------------------------------------------------------------------------//

METHOD SelectWord( nRow, nTextCol ) CLASS HBSrcEdit

   local cLine, nStart, nEnd, cChar

   if nRow < 1 .or. nRow > Len( ::aText )
      return nil
   endif

   cLine = ::aText[ nRow ]:cText

   // char-based scan (nTextCol/nSelStart/nSelEnd follow nCol semantics):
   // hb_U* are byte-identical in 8-bit codepages, so stable mode is unchanged
   if nTextCol < 1 .or. nTextCol > hb_ULen( cLine )
      ::ClearSelection()
      return nil
   endif

   cChar = hb_USubStr( cLine, nTextCol, 1 )
   if ! HBIDE_IsWordChar( cChar )
      ::ClearSelection()
      return nil
   endif

   // Find word start
   nStart = nTextCol
   while nStart > 1 .and. HBIDE_IsWordChar( hb_USubStr( cLine, nStart - 1, 1 ) )
      nStart--
   end

   // Find word end
   nEnd = nTextCol
   while nEnd < hb_ULen( cLine ) .and. HBIDE_IsWordChar( hb_USubStr( cLine, nEnd + 1, 1 ) )
      nEnd++
   end

   ::nSelRow   = nRow
   ::nSelStart = nStart
   ::nSelEnd   = nEnd
   ::cClipboard = hb_USubStr( cLine, nStart, nEnd - nStart + 1 )

   ::Display()

return nil

//-----------------------------------------------------------------------------------------//

METHOD Edit( nKey ) CLASS HBSrcEdit

   local aBefore := ::LinesSnapshot()

   ::lOpRecorded := .F.
   ::EditKey( nKey )

   if ::lInUndo
      ::lInUndo := .F.
   elseif ! ::lOpRecorded
      ::RecordEdit( aBefore )
      // RecordEdit adjusts breakpoints in PushOp, but edits on this path
      // (Enter, typing, paste) already repainted inside EditKey: repaint so
      // the gutter shows the marks on their shifted lines at once
      if ::lBPsMoved
         ::lBPsMoved := .F.
         ::Display()
      endif
   endif

return Self

//-----------------------------------------------------------------------------------------//

METHOD EditKey( nKey ) CLASS HBSrcEdit

   local nKeyStd := hb_keyStd( nKey )
   local nKeyExt := hb_keyExt( nKey )   // HB_KX_* when an extended special key, else 0
   local nKeyMod := hb_keyMod( nKey )   // HB_KF_* flags of the extended code
   local nOldScrRow := ::Row()
   local cKey, oLine, nPos

   do case
      // Distinct only under HB_INKEY_EXT: the classic set delivers Ctrl+Left
      // as 26 == K_CTRL_Z, so this case must run before the Undo one.
      case nKeyExt == HB_KX_LEFT .and. hb_bitAnd( nKeyMod, HB_KF_CTRL ) != 0
           ::WordJump( .F. )

      // Shift+arrows/Home/End: extended mode stops collapsing them into
      // plain movement. Reuse the F8 anchor: set it if absent, then move;
      // the range highlight and Copy/Cut already read SelRange().
      case nKeyExt >= HB_KX_UP .and. nKeyExt <= HB_KX_END .and. ;
           hb_bitAnd( nKeyMod, hb_bitOr( HB_KF_SHIFT, HB_KF_CTRL, HB_KF_ALT ) ) == HB_KF_SHIFT
           if ! ::lMark
              ::ToggleMark()
           endif
           do case
              case nKeyExt == HB_KX_UP     ; ::EditKey( K_UP )
              case nKeyExt == HB_KX_DOWN   ; ::EditKey( K_DOWN )
              case nKeyExt == HB_KX_LEFT   ; ::EditKey( K_LEFT )
              case nKeyExt == HB_KX_RIGHT  ; ::EditKey( K_RIGHT )
              case nKeyExt == HB_KX_HOME   ; ::EditKey( K_HOME )
              case nKeyExt == HB_KX_END    ; ::EditKey( K_END )
           endcase

      case nKeyStd == K_CTRL_Z
           ::lInUndo := .T.
           ::Undo()

      case nKeyStd == K_CTRL_U
           ::lInUndo := .T.
           ::Redo()

      case nKeyStd == K_LDBLCLK
           ::GoTo( MRow() - ::nTop + ::nFirstRow, Max( MCol() - ::nLeft + ::nFirstCol, 5 ), _REFRESH_ALL )
           ::SelectWord( ::nRow, ::nCol - 4 )

      case nKeyStd == K_LBUTTONDOWN
           ::ClearSelection()
           ::GoTo( MRow() - ::nTop + ::nFirstRow, Max( MCol() - ::nLeft + ::nFirstCol, 5 ), _REFRESH_ALL )

      case nKeyStd == K_MWBACKWARD
           ::Super:Edit( K_DOWN )

      case nKeyStd == K_MWFORWARD
           ::Super:Edit( K_UP )

      case nKeyStd == K_BS
           if ::SelRange() != NIL
              ::SelDelete( ::SelRange() )
           else
           ::ClearSelection()
           IF ::nCol > 5
              ::lDirty := .T.
              ::aText[ ::nRow ]:cText := hb_UStuff( ::aText[ ::nRow ]:cText, --::nCol - 4, 1, "" )
              ::GoTo( ::nRow, ::nCol, _REFRESH_LINE )
           ELSEIF ::nRow > 1
              // Join with previous line
              ::lDirty := .T.
              nPos = hb_ULen( ::aText[ ::nRow - 1 ]:cText )
              ::GoTo( ::nRow - 1, nPos + 1 )
              ::nCol = nPos + 1
              ::Super:Edit( K_DEL )
              ::GoTo( ::nRow, nPos + 5, _REFRESH_ALL )
           ENDIF
           endif

      case nKeyStd == K_DEL
           if ::SelRange() != NIL
              ::SelDelete( ::SelRange() )
           else
           ::ClearSelection()
           nPos = ::nCol
           ::nCol = Max( ::nCol - 4, 1 )
           ::Super:Edit( nKey )
           ::GoTo( ::nRow, nPos, _REFRESH_ALL )
           endif

      case nKeyStd == K_ENTER
           if ::SelRange() != NIL
              ::SelDelete( ::SelRange() )
           else
              ::ClearSelection()
           endif
           ::nCol = Max( ::nCol - 4, 1 )
           ::Super:Edit( nKey )
           ::GoTo( ::nRow, 5 )

      case nKeyStd == K_RIGHT
           if ::nCol - 4 > hb_ULen( ::aText[ ::nRow ]:cText )
              if ::nRow < Len( ::aText )
                 ::GoTo( ::nRow + 1, 5, _REFRESH_ALL )
              endif
           else
              ::Super:Edit( nKey )
           endif

      case nKeyStd == K_LEFT
           if ::nCol <= 5
              if ::nRow > 1
                 ::GoTo( ::nRow - 1, hb_ULen( ::aText[ ::nRow - 1 ]:cText ) + 5, _REFRESH_ALL )
              endif
           else
              ::Super:Edit( nKey )
           endif

      case nKeyStd == K_HOME
           ::GoTo( ::nRow, 5, _REFRESH_ALL )

      case nKeyStd == K_END
           ::GoTo( ::nRow, hb_ULen( ::aText[ ::nRow ]:cText ) + 5, _REFRESH_ALL )

      case nKeyStd == K_CTRL_RIGHT
           ::WordJump( .T. )

      // Alt+Left stays as a second left word jump (works in both modes).
      case nKeyStd == K_ALT_LEFT
           ::WordJump( .F. )

      // Ctrl+Left word jump is bound above via the extended code: in classic
      // inkey both Ctrl+Left and Ctrl+Z arrive as 26, so only a GT delivering
      // extended codes (gttrm + HB_INKEY_EXT, wired in the IDE loop) can tell
      // them apart; elsewhere Ctrl+Left keeps arriving as Undo, as before.

      case nKeyStd == K_CTRL_Y
           ::DeleteLine()

      case nKeyStd == K_F2
           ::SaveFile()

      // Range selection anchor (provisional binding: F8 is unbound in
      // HBEditor, editor.prg and hbide.prg; Shift+arrows collapse to plain
      // arrows under the current event mask, so they cannot carry this yet)
      case nKeyStd == K_F8
           ::ToggleMark()

      // breakpoint on the current line, consumed by Run>Debug
      case nKeyStd == K_F9
           ::ToggleBP()

      case ! HB_ISNULL( cKey := iif( nKeyStd == K_TAB .AND. Set( _SET_INSERT ), ;
           Space( TabCount( ::nTabWidth, ::nCol ) ), ;
           hb_keyChar( nKey ) ) )

           if ::SelRange() != NIL
              ::SelDelete( ::SelRange() )
           else
              ::ClearSelection()
           endif
           ::lDirty := .T.
           oLine := ::aText[ ::nRow ]
           IF ( nPos := ::nCol - hb_ULen( oLine:cText ) - 5 ) > 0
              oLine:cText += Space( nPos )
           ENDIF
           oLine:cText := hb_UStuff( oLine:cText, ::nCol - 4, ;
                                     iif( Set( _SET_INSERT ), 0, 1 ), cKey )
           ::nCol += hb_ULen( cKey )
           IF ::lWordWrap .AND. hb_ULen( oLine:cText ) > ::nWordWrapCol
              ::ReformParagraph()
           ELSE
              ::GoTo( ::nRow, ::nCol, _REFRESH_LINE )
           ENDIF

      otherwise
           ::Super:Edit( nKey )
   endcase

   if ::Row() > ::nTop
      ::DisplayLine( ::Row() - 1 )
   endif

   ::DisplayLine( ::Row() )

   if ::Row() < ::nBottom
      ::DisplayLine( ::Row() + 1 )
   endif

   // Jumps longer than one line (Ctrl+Home/End and friends reach HBEditor's
   // MoveCursor with _REFRESH_NONE) leave the previous current line painted
   // with the current-line color; repaint it so the highlight never lingers
   // on a stale row.
   if ::Row() != nOldScrRow .and. nOldScrRow >= ::nTop .and. nOldScrRow <= ::nBottom
      ::DisplayLine( nOldScrRow )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD LinesSnapshot() CLASS HBSrcEdit

   local aLines := Array( Len( ::aText ) ), n

   for n = 1 to Len( ::aText )
      aLines[ n ] := ::aText[ n ]:cText
   next

return aLines

//-----------------------------------------------------------------------------------------//

// Diff-based op recorder: finds the changed line span between snapshots
// Exact string equality immune to the default SET EXACT OFF ragged compare:
// with EXACT OFF, "abc" == "" (and "abc" == "ab") is .T., which silently
// discards undo ops whose new line is empty or a prefix of the old one.
STATIC FUNCTION HBIDE_StrEq( cA, cB )
return Len( cA ) == Len( cB ) .and. cA == cB

METHOD RecordEdit( aBefore ) CLASS HBSrcEdit

   local aAfter := ::LinesSnapshot()
   local nB := Len( aBefore ), nA := Len( aAfter )
   local nPre := 0, nSuf := 0, i
   local aOld := {}, aNew := {}

   while nPre < Min( nB, nA ) .and. HBIDE_StrEq( aBefore[ nPre + 1 ], aAfter[ nPre + 1 ] )
      nPre++
   end
   while nSuf < Min( nB - nPre, nA - nPre ) .and. ;
         HBIDE_StrEq( aBefore[ nB - nSuf ], aAfter[ nA - nSuf ] )
      nSuf++
   end

   if nPre + nSuf >= nB .and. nPre + nSuf >= nA
      return Self   // no text change
   endif

   for i := nPre + 1 to nB - nSuf
      AAdd( aOld, aBefore[ i ] )
   next
   for i := nPre + 1 to nA - nSuf
      AAdd( aNew, aAfter[ i ] )
   next

   ::PushOp( nPre + 1, aOld, aNew )

return Self

//-----------------------------------------------------------------------------------------//

// Undo stack ops: { nRow, aOldLines, aNewLines } replaces aOld with aNew at nRow
// (model adapted from tvedit's PushUndo, reworked for HBEditor's line array)
METHOD PushOp( nRow, aOld, aNew ) CLASS HBSrcEdit

   local aLast, i, lSame

   if Len( aOld ) == Len( aNew )
      lSame := .T.
      for i = 1 to Len( aOld )
         if ! HBIDE_StrEq( aOld[ i ], aNew[ i ] )
            lSame := .F.
            exit
         endif
      next
      if lSame
         return Self
      endif
   endif

   ::nBlkDirty := Min( ::nBlkDirty, nRow )

   // saved state unreachable once a new edit lands after undoing past it
   if Len( ::aUndo ) < ::nSavedUndoLen
      ::nSavedUndoLen := -1
   endif

   // fuse consecutive single-line edits on the same line (typing bursts);
   // never fuse onto the op that marks the saved state, or the buffer
   // would differ from disk while Len( aUndo ) still matches
   if Len( ::aUndo ) > 0 .and. Len( ::aUndo ) != ::nSavedUndoLen
      aLast := ATail( ::aUndo )
      if Len( aLast[ 2 ] ) == 1 .and. Len( aLast[ 3 ] ) == 1 .and. ;
         Len( aOld ) == 1 .and. Len( aNew ) == 1 .and. ;
         aLast[ 1 ] == nRow .and. aLast[ 3, 1 ] == aOld[ 1 ]
         aLast[ 3, 1 ] := aNew[ 1 ]
         ::aRedo := {}
         ::lOpRecorded := .T.
         return Self
      endif
   endif

   ::AdjustBPs( nRow, aOld, aNew )
   AAdd( ::aUndo, { nRow, aOld, aNew } )
   ::aRedo := {}
   if Len( ::aUndo ) > MAX_UNDO
      ADel( ::aUndo, 1 )
      ASize( ::aUndo, Len( ::aUndo ) - 1 )
      // keep the saved marker aligned with the truncated stack
      if ::nSavedUndoLen > 0
         ::nSavedUndoLen--
      elseif ::nSavedUndoLen == 0
         ::nSavedUndoLen := -1   // saved state fell off the stack
      endif
   endif
   ::lOpRecorded := .T.

return Self

//-----------------------------------------------------------------------------------------//

METHOD ApplyOp( aOp, lInverse ) CLASS HBSrcEdit

   local aDel := iif( lInverse, aOp[ 3 ], aOp[ 2 ] )
   local aIns := iif( lInverse, aOp[ 2 ], aOp[ 3 ] )
   local nRow := aOp[ 1 ], i

   ::nBlkDirty := Min( ::nBlkDirty, nRow )
   ::AdjustBPs( nRow, aDel, aIns )

   for i = 1 to Len( aDel )
      ::RemoveLine( nRow )
   next
   for i = 1 to Len( aIns )
      if nRow + i - 1 > Len( ::aText )
         ::AddLine( aIns[ i ], .F. )
      else
         ::InsertLine( aIns[ i ], .F., nRow + i - 1 )
      endif
   next

return Self

//-----------------------------------------------------------------------------------------//

METHOD Undo() CLASS HBSrcEdit

   local aOp

   if Len( ::aUndo ) == 0
      return Self
   endif

   aOp := ATail( ::aUndo )
   ASize( ::aUndo, Len( ::aUndo ) - 1 )
   ::ApplyOp( aOp, .T. )
   AAdd( ::aRedo, aOp )
   ::lDirty := ( Len( ::aUndo ) != ::nSavedUndoLen )
   ::ClearSelection()
   ::GoTo( Min( aOp[ 1 ], ::LineCount() ), 5, _REFRESH_ALL )

return Self

//-----------------------------------------------------------------------------------------//

METHOD Redo() CLASS HBSrcEdit

   local aOp

   if Len( ::aRedo ) == 0
      return Self
   endif

   aOp := ATail( ::aRedo )
   ASize( ::aRedo, Len( ::aRedo ) - 1 )
   ::ApplyOp( aOp, .F. )
   AAdd( ::aUndo, aOp )
   ::lDirty := ( Len( ::aUndo ) != ::nSavedUndoLen )
   ::ClearSelection()
   ::GoTo( Min( aOp[ 1 ], ::LineCount() ), 5, _REFRESH_ALL )

return Self

//-----------------------------------------------------------------------------------------//

// State cache for multi-line block comments: aBlkCmt[ i ] is .T. when line i
// begins inside /* */. Recomputed lazily from nBlkDirty; edits and undo/redo
// invalidate only from their first affected line, so a repaint scans at most
// from the edited line to the last visible one (O(visible) in the common case,
// O(changed suffix) after an edit near the top).
METHOD BlkCmtState( nLine ) CLASS HBSrcEdit

   local i, lState

   if nLine > Len( ::aText )
      return .F.
   endif

   if ::nBlkDirty <= nLine
      ASize( ::aBlkCmt, Len( ::aText ) )
      // aBlkCmt[i] holds the state at the START of line i; resuming needs the
      // state at the END of line nBlkDirty-1, so rescan that one line.
      lState := iif( ::nBlkDirty > 1,;
                     ::ScanBlkLine( ::aText[ ::nBlkDirty - 1 ]:cText, ;
                                    ::aBlkCmt[ ::nBlkDirty - 1 ] ), .F. )
      for i := ::nBlkDirty to nLine
         ::aBlkCmt[ i ] := lState
         lState := ::ScanBlkLine( ::aText[ i ]:cText, lState )
      next
      ::nBlkDirty := nLine + 1
   endif

return ::aBlkCmt[ nLine ]

//-----------------------------------------------------------------------------------------//

// Scans one line and returns the block-comment state at its end, mirroring
// DisplayLine's tokenizer: '"' and "'" strings are skipped (/* inside a
// string does not open a comment) and // ends the scan (a later /* stays a
// line comment). Byte-level scan: the delimiters and quotes are ASCII and
// UTF-8 continuation bytes can never alias them.
METHOD ScanBlkLine( cText, lIn ) CLASS HBSrcEdit

   local n := 1, nLen := Len( cText ), c

   while n <= nLen
      c := SubStr( cText, n, 1 )
      if lIn
         if c == "*" .and. SubStr( cText, n, 2 ) == "*/"
            lIn := .F.
            n++
         endif
      elseif c == '"' .or. c == "'"
         n++
         while n <= nLen .and. SubStr( cText, n, 1 ) != c
            n++
         end
      elseif c == "/" .and. SubStr( cText, n, 2 ) == "/*"
         lIn := .T.
         n++
      elseif c == "/" .and. SubStr( cText, n, 2 ) == "//"
         exit
      endif
      n++
   end

return lIn

//-----------------------------------------------------------------------------------------//

METHOD LoadText( cText ) CLASS HBSrcEdit

   local xRet := ::Super:LoadText( cText )

   ::aUndo := {}
   ::aRedo := {}
   ::nSavedUndoLen := 0
   ::lInUndo := .F.
   ::nBlkDirty := 1

return xRet

//-----------------------------------------------------------------------------------------//

METHOD LoadFile( cFileName ) CLASS HBSrcEdit

   local xRet, cRaw := hb_MemoRead( cFileName )
   local cConv, cBody

   // UTF-8: convert to the editor codepage on load, convert back on save,
   // but only when the conversion is provably lossless: a file with chars
   // CP437 cannot represent loads with its original bytes untouched
   // (mojibake display, byte-faithful save) so F2 can never destroy data.
   ::lUtf8 := .F.
   ::lUtf8Bom := .F.
   ::lUtf8Raw := .F.
   cBody := cRaw
   if Left( cBody, 3 ) == HBIDE_Utf8Bom()
      cBody := SubStr( cBody, 4 )
      ::lUtf8Bom := .T.
   endif
   if ::lUtf8Bom .or. HBIDE_IsUtf8( cBody )
      cConv := hb_UTF8ToStr( cBody )
      if hb_StrToUTF8( cConv ) == cBody
         cRaw := cConv
         ::lUtf8 := .T.
      else
         ::lUtf8Bom := .F.   // raw view: the BOM stays in the bytes shown/saved
         ::lUtf8Raw := .T.
         HBIDE_MsgAlert( "UTF-8 file with characters outside CP437: opened raw " + ;
                "to avoid data loss on save" )
      endif
   endif

   ::cFile := cFileName
   ::aBPs := {}   // breakpoints belong to the previous buffer
   xRet := ::LoadText( cRaw )

   if hb_FSize( cFileName ) > 8 * 1024 * 1024
      HBIDE_MsgAlert( "File larger than 8 MB: the disk watch compares date+time+size " + ;
             "only, so a same-size external edit may go unnoticed until you save" )
   endif

   ::cSeenStamp := ::cLoadStamp := ::DiskStamp( ::cFile )

return xRet

//-----------------------------------------------------------------------------------------//

// date+time+size+content stamp of the file on disk ("" when missing or
// unreadable). The MD5 of the bytes catches a same-size edit inside the
// filesystem timestamp resolution, which the plain stamp could not tell
// apart. Cap: files over 8 MB keep the plain stamp - measured cost of
// read+MD5 per watch check here: 0.15 ms (100 KB), 1.6 ms (1 MB),
// 12.9 ms (8 MB), 60 ms (32 MB); 8 MB bounds the hitch at ~13 ms per
// 2-second check, 32 MB would be a visible 60 ms hitch.
METHOD DiskStamp( cFile ) CLASS HBSrcEdit

   local aDir, cStamp

   if Empty( cFile ) .or. ! File( cFile )
      return ""
   endif

   aDir := Directory( cFile )
   if Len( aDir ) == 0
      return ""
   endif

   cStamp := DToS( aDir[ 1, 3 ] ) + "|" + aDir[ 1, 4 ] + "|" + hb_ntos( aDir[ 1, 2 ] )
   if aDir[ 1, 2 ] <= 8 * 1024 * 1024
      cStamp += "|" + hb_MD5( hb_MemoRead( cFile ) )
   endif

return cStamp

//-----------------------------------------------------------------------------------------//

METHOD DiskChanged() CLASS HBSrcEdit

   local cStamp := ::DiskStamp( ::cFile )

return ! Empty( cStamp ) .and. cStamp != ::cSeenStamp

//-----------------------------------------------------------------------------------------//

// save-time guard: the disk version moved since our last load/own save,
// even when the change was already acknowledged ("Keep mine")
METHOD DiskChangedSinceLoad() CLASS HBSrcEdit

   local cStamp := ::DiskStamp( ::cFile )

return ! Empty( cStamp ) .and. cStamp != ::cLoadStamp

//-----------------------------------------------------------------------------------------//

// the file existed at load/own save and is now missing (external deletion);
// "" from DiskStamp must never be read as "unchanged"
METHOD FileVanished() CLASS HBSrcEdit

return ! Empty( ::cLoadStamp ) .and. Empty( ::DiskStamp( ::cFile ) )

//-----------------------------------------------------------------------------------------//

// A fresh sibling temp name that is guaranteed not to exist, so nothing
// preexisting is ever treated as ours. Returns "" if no free name is found.
function HBIDE_UniqueSibling( cBase, cExt )

   local cTmp, nTry := 0

   hb_default( @cExt, "" )
   do while nTry++ < 20
      cTmp := cBase + ".tmp-" + StrZero( hb_randomInt( 999999 ), 6 ) + cExt
      if ! File( cTmp )
         return cTmp
      endif
   enddo

return ""

//-----------------------------------------------------------------------------------------//

// Write cContent to cFile without truncating the user's original in place:
// write a sibling temp file, verify its size, stamp the original's
// permissions on it (hb_vfAttrGet/Set, real native API), then move it over
// the destination. On POSIX the rename replaces atomically, so a crash can
// leave either the old or the new file, never a half-written one. If the
// original's attributes cannot be read or applied, the save ABORTS without
// modifying the destination (fail-closed). On ANY failure the temp with the
// full new content is KEPT and @cFailInfo names it, so nothing the user
// wrote is lost even when the destination cannot be touched.
// Symlink policy (fail-closed, documented): renaming would silently replace
// the LINK with a regular file, and writing through the link in place would
// reintroduce the non-atomic truncation this helper removes. Saving to a
// symlinked destination is REFUSED until a safe strategy exists: the
// destination and link stay untouched and the new content goes to a named
// recoverable temp.
function HBIDE_AtomicWriteFile( cFile, cContent, cFailInfo )

   local cTmp, lOk := .F., nAttr := 0, aDir

   cFailInfo := ""

   cTmp := HBIDE_UniqueSibling( cFile )
   if Empty( cTmp )
      cFailInfo := "no free temp name next to " + cFile
      return .F.
   endif

   aDir := Directory( cFile )
   if Len( aDir ) > 0 .and. "L" $ aDir[ 1 ][ F_ATTR ]
      hb_MemoWrit( cTmp, cContent )
      cFailInfo := cFile + " is a symlink: saving there is not safe yet. " + ;
                   "Destination untouched; your content is recoverable at " + cTmp
      return .F.
   endif

   do while .T.   // single-exit block; the temp is kept on every failure
      // read the original's permissions BEFORE touching anything
      if File( cFile ) .and. ! hb_vfAttrGet( cFile, @nAttr )
         cFailInfo := "could not read attributes of " + cFile + "; destination untouched"
         exit
      endif
      if ! hb_MemoWrit( cTmp, cContent ) .or. hb_FSize( cTmp ) != Len( cContent )
         cFailInfo := "could not write the temp file; destination untouched"
         exit
      endif
      // stamp the original's permissions on the replacement (aborts above
      // when impossible, so the destination is never silently demoted)
      if File( cFile ) .and. ! hb_vfAttrSet( cTmp, nAttr )
         cFailInfo := "could not preserve the permissions of " + cFile + "; destination untouched"
         exit
      endif
      lOk := HBIDE_ReplaceFile( cTmp, cFile, @cFailInfo )
      exit
   enddo

   if ! lOk .and. File( cTmp )
      cFailInfo += " (new content kept at " + cTmp + ")"
   endif

return lOk

//-----------------------------------------------------------------------------------------//

// Move cTmp over cTarget, fail-closed: the original destination is never
// destroyed before the replacement stands in place, and every failure path
// leaves BOTH the original and the new content on disk, named in
// @cRecovery. POSIX rename(2) replaces an existing target atomically. The
// Windows path cannot rename over an existing file, so it parks the
// destination first (never erased), moves the new file in and rolls back on
// failure; if the ROLLBACK also fails, the original survives at its park
// name and the new content at cTmp - cRecovery says exactly where. Not
// atomic on Windows and does not claim to be.
function HBIDE_ReplaceFile( cTmp, cTarget, cRecovery )

   local lOk

   cRecovery := ""
#ifdef __PLATFORM__WINDOWS
return HBIDE_ParkReplace( cTmp, cTarget, @cRecovery )
#else
   lOk := FRename( cTmp, cTarget ) == 0
   if ! lOk
      cRecovery := "rename failed; original untouched at " + cTarget
   endif
return lOk
#endif

//-----------------------------------------------------------------------------------------//

// Park-and-replace with rollback. The Windows replace strategy; factored
// out so fault-injection tests can exercise it on any platform.
function HBIDE_ParkReplace( cTmp, cTarget, cRecovery )

   local cHold

   cRecovery := ""
   if ! File( cTarget )
      if FRename( cTmp, cTarget ) != 0
         cRecovery := "rename failed; new content kept at " + cTmp
         return .F.
      endif
      return .T.
   endif

   cHold := HBIDE_UniqueSibling( cTarget )
   if Empty( cHold )
      cRecovery := "no free park name; original untouched at " + cTarget + ", new content kept at " + cTmp
      return .F.
   endif
   if FRename( cTarget, cHold ) != 0
      cRecovery := "could not park the original; it is untouched at " + cTarget + ", new content kept at " + cTmp
      return .F.
   endif
   if FRename( cTmp, cTarget ) != 0
      if FRename( cHold, cTarget ) != 0
         cRecovery := "replace and rollback BOTH failed: original preserved as " + cHold + ", new content kept at " + cTmp
      endif
      return .F.
   endif
   FErase( cHold )   // replacement complete: drop the park copy

return .T.

//-----------------------------------------------------------------------------------------//

METHOD SaveFile() CLASS HBSrcEdit

   local lOk, cContent, cFailInfo := ""
   if Empty( ::cFile )
      return .F.
   endif

   // raw-view UTF-8: an edit that cut a multibyte sequence (cursor/
   // backspace inside it) makes the bytes no longer valid UTF-8. Saving
   // that would corrupt the original file, so block it explicitly.
   if ::lUtf8Raw .and. ! HBIDE_Utf8Valid( ::GetText() )
      HBIDE_MsgAlert( "Save blocked: the edit broke UTF-8 multibyte sequences " + ;
             "and would corrupt the file" )
      return .F.
   endif

   // Atomic write through a verified temp file (see HBIDE_AtomicWriteFile):
   // the original is never truncated in place. Byte content matches the old
   // direct-write paths exactly (GetText() with its default argument, same
   // as the parent's SaveFile used).
   if ::lUtf8
      cContent := If( ::lUtf8Bom, HBIDE_Utf8Bom(), "" ) + hb_StrToUTF8( ::GetText() )
   else
      cContent := ::GetText()
   endif

   lOk := HBIDE_AtomicWriteFile( ::cFile, cContent, @cFailInfo )

   if lOk
      ::lDirty := .F.
      ::nSavedUndoLen := Len( ::aUndo )
      ::cSeenStamp := ::cLoadStamp := ::DiskStamp( ::cFile )   // our own save is not an external change
   else
      HBIDE_MsgAlert( "Save failed: " + cFailInfo )
   endif

return lOk

//-----------------------------------------------------------------------------------------//

METHOD Display() CLASS HBSrcEdit

   local nRow, nCount

   DispBegin()
   nRow = ::nTop
   nCount = ::nBottom - ::nTop + 1
   while --nCount >= 0
      ::DisplayLine( nRow++ )
   end
   DispEnd()

return Self

//-----------------------------------------------------------------------------------------//

METHOD DisplayLine( nLine ) CLASS HBSrcEdit

   local n, cLine, cToken := "", cColor, nCol, nStart, nPos, aSel
   local cOperators := ::cOperators
   local lInComment := .F.
   local lInBlk := ::BlkCmtState( ::nFirstRow + nLine - ::nTop )
   local nRowNum := ::nFirstRow + nLine - ::nTop

   DispBegin()
   hb_DispOutAt( nLine, ::nLeft, PadL( nRowNum, 4 ), ;
                 iif( AScan( ::aBPs, nRowNum ) > 0, ::cClrBP, "N/W" ) )
   hb_DispOutAt( nLine, ::nLeft + 4,;
                 SubStrPad( cLine := ::GetLine( ::nFirstRow + nLine - ::nTop ),;
                 ::nFirstCol, ::nRight - ::nLeft - 4 + 1 ),;
                 ::LineColor( nLine ) )

   n = 1
   while n <= hb_ULen( cLine )
      while hb_USubStr( cLine, n, 1 ) == " " .and. n <= hb_ULen( cLine )
         n++
      end

      if n > hb_ULen( cLine )
         exit
      endif

      // Continuation of a multi-line block comment: consume to */ or EOL
      if lInBlk
         nStart = n
         while n <= hb_ULen( cLine ) - 1 .and. hb_USubStr( cLine, n, 2 ) != "*/"
            n++
         end
         if n <= hb_ULen( cLine ) - 1
            n += 2
            lInBlk := .F.
         else
            n = hb_ULen( cLine ) + 1
         endif
         cToken = hb_USubStr( cLine, nStart, n - nStart )
         lInComment = .T.
      // Check for line comment - color rest of line as comment
      elseif hb_USubStr( cLine, n, 2 ) == "//"
         cToken = hb_USubStr( cLine, n )
         n = hb_ULen( cLine ) + 1
         lInComment = .T.
      // Check for block comment start
      elseif hb_USubStr( cLine, n, 2 ) == "/*"
         nStart = n
         n += 2
         while n <= hb_ULen( cLine ) - 1 .and. hb_USubStr( cLine, n, 2 ) != "*/"
            n++
         end
         if n <= hb_ULen( cLine ) - 1 .and. hb_USubStr( cLine, n, 2 ) == "*/"
            n += 2
         else
            n = hb_ULen( cLine ) + 1
         endif
         cToken = hb_USubStr( cLine, nStart, n - nStart )
         lInComment = .T.
      else
         do case
            case hb_USubStr( cLine, n, 1 ) == '"'
                cToken += '"'
                while hb_USubStr( cLine, ++n, 1 ) != '"' .and. n <= hb_ULen( cLine )
                   cToken += hb_USubStr( cLine, n, 1 )
                end
                if n <= hb_ULen( cLine )
                   cToken += '"'
                endif
                n++

            case hb_USubStr( cLine, n, 1 ) == "'"
                cToken += "'"
                while hb_USubStr( cLine, ++n, 1 ) != "'" .and. n <= hb_ULen( cLine )
                   cToken += hb_USubStr( cLine, n, 1 )
                end
                if n <= hb_ULen( cLine )
                   cToken += "'"
                endif
                n++

            case hb_USubStr( cLine, n, 1 ) $ cOperators
               while hb_USubStr( cLine, n, 1 ) $ cOperators .and. n <= hb_ULen( cLine )
                  cToken += hb_USubStr( cLine, n++, 1 )
               end

            case ! hb_USubStr( cLine, n, 1 ) $ " " + cOperators .and. n <= hb_ULen( cLine )
               while ! hb_USubStr( cLine, n, 1 ) $ " " + cOperators .and. n <= hb_ULen( cLine )
                  cToken += hb_USubStr( cLine, n++, 1 )
               end

         endcase
      endif

      if ! Empty( cToken )
         if lInComment
            cColor = ::cClrComment
            lInComment = .F.
         else
            do case
               case Left( cToken, 1 ) $ "0123456789" .and. ;
                    Right( cToken, 1 ) $ "0123456789"
                    cColor = ::cClrNumber

               case Left( cToken, 1 ) $ '"' + "'"
                    cColor = ::cClrString

               case Upper( cToken ) $ cOperators
                    cColor = ::cClrOperator

               case "," + Upper( cToken ) + "," $ "," + ::cKeywords1 + "," .and. Len( cToken ) > 1
                    cColor = ::cClrKeyword1

               case "," + Upper( cToken ) + "," $ "," + ::cKeywords2 + "," .and. Len( cToken ) > 1
                    cColor = ::cClrKeyword2

               otherwise
                    cColor = SubStr( ::LineColor( nLine ), 1, At( "/", ::LineColor( nLine ) ) - 1 )
            endcase
         endif

         nCol = 5 + n - hb_ULen( cToken ) - ::nFirstCol
         nStart = If( nCol < 5, 6 - nCol, 1 )
         nCol = Max( nCol, 5 )

         if nCol < ::nNumCols
            hb_DispOutAt( nLine, nCol,;
                          hb_USubStr( cToken, nStart, Min( hb_ULen( cToken ) - nStart + 1, ::nNumCols - 5 ) ),;
                          cColor + SubStr( ::LineColor( nLine ),;
                          At( "/", ::LineColor( nLine ) ) ) )
         endif
         cToken = ""
      endif
   end

   // Draw selection highlight (word selection, then F8 range selection)
   if ::nSelRow > 0 .and. ::nFirstRow + nLine - ::nTop == ::nSelRow
      nCol = 5 + ::nSelStart - ::nFirstCol
      nStart = ::nSelEnd - ::nSelStart + 1
      if nCol >= 5 .and. nCol < ::nNumCols
         hb_DispOutAt( nLine, nCol,;
                       hb_USubStr( ::aText[ ::nSelRow ]:cText, ::nSelStart, nStart ),;
                       "N/W" )
      endif
   elseif ::lMark .and. ( aSel := ::SelRange() ) != NIL .and. ;
          ( nPos := ::nFirstRow + nLine - ::nTop ) >= aSel[ 1 ] .and. nPos <= aSel[ 3 ]
      nCol  = iif( nPos == aSel[ 1 ], aSel[ 2 ], 5 )
      nStart = iif( nPos == aSel[ 3 ], aSel[ 4 ], hb_ULen( ::aText[ nPos ]:cText ) + 5 )
      if nStart > nCol
         nStart -= nCol
         nCol = 5 + ( nCol - 4 ) - ::nFirstCol
         if nCol >= 5 .and. nCol < ::nNumCols
            hb_DispOutAt( nLine, nCol,;
                          hb_USubStr( ::aText[ nPos ]:cText, nCol - 5 + ::nFirstCol, nStart ),;
                          "N/W" )
         endif
      endif
   endif

   DispEnd()

return Self

//-----------------------------------------------------------------------------------------//

// F8 range-selection anchor. Selection = normalized range between anchor
// and cursor; zero-width is no selection. All positions follow nCol
// semantics (text position = nCol - 4) and all slicing is char-based
// (hb_U*), byte-identical in 8-bit codepages.
METHOD ToggleMark() CLASS HBSrcEdit

   if ::lMark
      ::lMark = .F.
   else
      ::nMarkRow = ::nRow
      ::nMarkCol = ::nCol
      ::lMark    = .T.
   endif
   ::Display()

return nil

//-----------------------------------------------------------------------------------------//

// toggle a debugger breakpoint on the current line; Run>Debug presets them
METHOD ToggleBP() CLASS HBSrcEdit

   local nAt := AScan( ::aBPs, ::nRow )

   if nAt > 0
      ADel( ::aBPs, nAt )
      ASize( ::aBPs, Len( ::aBPs ) - 1 )
   else
      AAdd( ::aBPs, ::nRow )
   endif
   ::DisplayLine( ::nRow - ::nFirstRow + ::nTop )

return nil

//-----------------------------------------------------------------------------------------//

// keep breakpoints glued to their instruction across an edit that replaces
// aOld with aNew at nRow (called by PushOp and ApplyOp, so undo/redo shift
// symmetrically). A BP below the range shifts by the line delta; a BP above
// is untouched; a BP inside the range follows its line text when it
// survives, otherwise stays visible at the top of the range: it always
// stops where the gutter shows it, never silently on another instruction.
METHOD AdjustBPs( nRow, aOld, aNew ) CLASS HBSrcEdit

   local nDelta := Len( aNew ) - Len( aOld )
   local nOldEnd := nRow + Len( aOld ) - 1
   local aKept := {}, nBP, nAt

   if nDelta == 0
      return Self   // in-place text edits keep every mark
   endif
   ::lBPsMoved := .T.
   for each nBP in ::aBPs
      if nBP > nOldEnd
         AAdd( aKept, nBP + nDelta )
      elseif nBP < nRow
         AAdd( aKept, nBP )
      else
         // mark inside the replaced range: follow its instruction text,
         // preferring the same relative slot so duplicate lines can't
         // steal the mark
         nAt := 0
         if nBP - nRow + 1 <= Len( aNew ) .and. ;
            HBIDE_StrEq( aNew[ nBP - nRow + 1 ], aOld[ nBP - nRow + 1 ] )
            nAt := nBP - nRow + 1
         else
            nAt := AScan( aNew, { | c | HBIDE_StrEq( c, aOld[ nBP - nRow + 1 ] ) } )
         endif
         if nAt > 0
            AAdd( aKept, nRow + nAt - 1 )
         elseif nDelta > 0
            AAdd( aKept, nRow )   // line split: mark stays on the first fragment
         endif
         // net deletion of the marked instruction: the mark is DROPPED.
         // A BP must never stop silently on a different instruction.
      endif
   next
   ::aBPs := aKept

return Self

//-----------------------------------------------------------------------------------------//

// { nRow1, nCol1, nRow2, nCol2 } normalized (start before end), or NIL
METHOD SelRange() CLASS HBSrcEdit

   if ! ::lMark
      return NIL
   endif
   if ::nMarkRow < ::nRow .or. ;
      ( ::nMarkRow == ::nRow .and. ::nMarkCol <= ::nCol )
      if ::nMarkRow == ::nRow .and. ::nMarkCol == ::nCol
         return NIL
      endif
      return { ::nMarkRow, ::nMarkCol, ::nRow, ::nCol }
   endif

return { ::nRow, ::nCol, ::nMarkRow, ::nMarkCol }

//-----------------------------------------------------------------------------------------//

// Selected text; lines joined with hb_eol(). "" when no selection.
METHOD SelectionText() CLASS HBSrcEdit

   local aSel := ::SelRange()
   local cOut, n

   if aSel == NIL
      return ""
   endif
   if aSel[ 1 ] == aSel[ 3 ]
      return hb_USubStr( ::aText[ aSel[ 1 ] ]:cText, aSel[ 2 ] - 4, aSel[ 4 ] - aSel[ 2 ] )
   endif
   cOut = hb_USubStr( ::aText[ aSel[ 1 ] ]:cText, aSel[ 2 ] - 4 )
   for n = aSel[ 1 ] + 1 to aSel[ 3 ] - 1
      cOut += hb_eol() + ::aText[ n ]:cText
   next
   cOut += hb_eol() + hb_USubStr( ::aText[ aSel[ 3 ] ]:cText, 1, aSel[ 4 ] - 5 )

return cOut

//-----------------------------------------------------------------------------------------//

METHOD CopySelection() CLASS HBSrcEdit

   local aSel := ::SelRange()

   if aSel != NIL
      ::cClipboard := ::SelectionText()
      // Exit extend mode after copying: with the F8 persistent-anchor model
      // the mark otherwise survives and a later typing burst or Cut would
      // silently operate on a stale, still-extended range.
      ::ClearSelection()
   endif

return nil

//-----------------------------------------------------------------------------------------//

// Cut = copy + delete of the range; one undoable op merging r1..r2
METHOD CutSelection() CLASS HBSrcEdit

   local aSel := ::SelRange()
   local aOld

   if aSel == NIL
      return nil
   endif
   ::cClipboard = ::SelectionText()
   aOld = ::SelDelete( aSel )
   ::PushOp( aSel[ 1 ], aOld, { ::aText[ aSel[ 1 ] ]:cText } )

return nil

//-----------------------------------------------------------------------------------------//

// Delete the marked range from the model WITHOUT recording an undo op:
// CutSelection records it explicitly, while the destructive-key paths in
// EditKey (type-over, Del, BS, Enter) let the Edit() wrapper's RecordEdit
// fuse delete + following edit into a single undoable op.
// Returns the removed lines (aOld); cursor lands at the block start.
METHOD SelDelete( aSel ) CLASS HBSrcEdit

   local aOld := {}, cMerged, n

   for n = aSel[ 1 ] to aSel[ 3 ]
      AAdd( aOld, ::aText[ n ]:cText )
   next
   cMerged = hb_USubStr( aOld[ 1 ], 1, aSel[ 2 ] - 5 ) + ;
             hb_USubStr( aOld[ Len( aOld ) ], aSel[ 4 ] - 4 )
   ::aText[ aSel[ 1 ] ]:cText := cMerged
   for n = aSel[ 1 ] + 1 to aSel[ 3 ]
      ::RemoveLine( aSel[ 1 ] + 1 )
   next
   ::ClearSelection()
   ::lDirty = .T.
   ::GoTo( aSel[ 1 ], aSel[ 2 ], _REFRESH_ALL )

return aOld

//-----------------------------------------------------------------------------------------//

// Ctrl+Right/Left word jump. Char-based via hb_U* (byte-identical in 8-bit
// codepages, so stable mode keeps its behavior); wraps lines like K_RIGHT.
METHOD WordJump( lRight ) CLASS HBSrcEdit

   local cLine := ::aText[ ::nRow ]:cText
   local nPos := Max( 1, ::nCol - 4 )   // 1-based text position
   local nLen := hb_ULen( cLine )

   if lRight
      if nPos > nLen
         if ::nRow < Len( ::aText )
            ::GoTo( ::nRow + 1, 5, _REFRESH_ALL )
         endif
         return nil
      endif
      while nPos <= nLen .and. HBIDE_IsWordChar( hb_USubStr( cLine, nPos, 1 ) )
         nPos++
      end
      while nPos <= nLen .and. ! HBIDE_IsWordChar( hb_USubStr( cLine, nPos, 1 ) )
         nPos++
      end
   else
      if nPos <= 1
         if ::nRow > 1
            ::GoTo( ::nRow - 1, hb_ULen( ::aText[ ::nRow - 1 ]:cText ) + 5, _REFRESH_ALL )
         endif
         return nil
      endif
      nPos--
      while nPos > 1 .and. ! HBIDE_IsWordChar( hb_USubStr( cLine, nPos, 1 ) )
         nPos--
      end
      while nPos > 1 .and. HBIDE_IsWordChar( hb_USubStr( cLine, nPos - 1, 1 ) )
         nPos--
      end
   endif
   ::GoTo( ::nRow, nPos + 4, _REFRESH_ALL )

return nil

//-----------------------------------------------------------------------------------------//

METHOD MoveCursor( nKey ) CLASS HbSrcEdit

   local lResult := .T.

   if nKey == K_LEFT
      if Col() > 5
         lResult := ::Super:MoveCursor( nKey )
      else
         if ::nFirstCol > 1
            ::nCol--
            ::nFirstCol--
            ::Display()
         endif
      endif
   else
      lResult = ::Super:MoveCursor( nKey )
   endif

return lResult

//-----------------------------------------------------------------------------------------//

static function SubStrPad( cText, nFrom, nLen )

return hb_UPadR( hb_USubStr( cText, nFrom, nLen ), nLen )

//-----------------------------------------------------------------------------------------//

// Word constituent for selection/word-jump: ASCII alnum + '_' always; under
// the UTF-8 opt-in any non-ASCII lead byte too, so accented letters behave
// as part of words. 8-bit codepages keep the exact previous behavior.
static function HBIDE_IsWordChar( cChar )

   if cChar $ "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
      return .T.
   endif

return hb_cdpSelect() == "UTF8" .and. ! Empty( cChar ) .and. Asc( cChar ) >= 0x80

//-----------------------------------------------------------------------------------------//

STATIC FUNCTION TabCount( nTabWidth, nCol )
   RETURN Int( nTabWidth - ( nCol - 1 ) % nTabWidth )

//-----------------------------------------------------------------------------------------//

// .T. when every byte of cText is valid UTF-8 (pure ASCII included)
function HBIDE_Utf8Valid( cText )

   local nI := 1, nLen := Len( cText ), nB, nJ, nNeed

   while nI <= nLen
      nB := Asc( SubStr( cText, nI, 1 ) )
      if nB < 0x80
         nI++
      else
         if nB >= 0xC2 .and. nB <= 0xDF
            nNeed := 1
         elseif nB >= 0xE0 .and. nB <= 0xEF
            nNeed := 2
         elseif nB >= 0xF0 .and. nB <= 0xF4
            nNeed := 3
         else
            return .F.
         endif
         if nI + nNeed > nLen
            return .F.
         endif
         for nJ := 1 to nNeed
            nB := Asc( SubStr( cText, nI + nJ, 1 ) )
            if nB < 0x80 .or. nB > 0xBF
               return .F.
            endif
         next
         nI += nNeed + 1
      endif
   end

return .T.

//-----------------------------------------------------------------------------------------//

// .T. when cText is valid UTF-8 with at least one multibyte sequence
function HBIDE_IsUtf8( cText )

return HBIDE_Utf8Valid( cText ) .and. hb_StrToUTF8( cText ) != cText
//-----------------------------------------------------------------------------------------//

function HBIDE_Utf8Bom()

return hb_BChar( 0xEF ) + hb_BChar( 0xBB ) + hb_BChar( 0xBF )

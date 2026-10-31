#include "hbclass.ch"
#include "inkey.ch"
#include "setcurs.ch"
#include "directry.ch"
#include "fileio.ch"

#define _REFRESH_NONE   0
#define _REFRESH_LINE   1
#define _REFRESH_ALL    2

#ifndef MAX_UNDO
#define MAX_UNDO        300
#endif

//-----------------------------------------------------------------------------------------//

function BuildEditor()

   // unique within the process: journal filenames also carry the recovery
   // session id, so a plain counter can never collide across instances
   static nDocSeq := 0
   local cCode   := "function Main()"  + hb_eol() + hb_eol() + ;
                    '   Alert( "Hello world from Harbour" )' + hb_eol() + hb_eol() + ;
                    "return nil"
   local oEditor := HBSrcEdit():New( cCode, 2, 1, MaxRow() - 2,;
                                     MaxCol() - 1, .T. ), nKey

   oEditor:SetColor( "W/B,N/BG" )
   oEditor:cFile = "noname.prg"
   oEditor:cDocId = hb_ntos( ++nDocSeq )
   // a fresh HBEditor leaves nCol at the window edge (gutter cell); the first
   // document is normalised by its first repaint, later File>New documents
   // were not, so typing before any cursor key landed in the wrong place
   oEditor:GoTo( 1, 5, _REFRESH_NONE )

return oEditor

//-----------------------------------------------------------------------------------------//

// A physical boundary belongs to the line before it. Keeping it on the
// line object lets edits move text without a parallel array drifting out of sync.
CLASS HBIDETextLine FROM HBTextLine
   DATA cEol INIT ""
ENDCLASS

CLASS HBSrcEdit FROM HBEditor

   DATA   cFile
   DATA   cEol        INIT NIL   // preferred terminator for new boundaries
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

   // One editor clipboard across documents; undo/history stay per buffer.
   CLASSDATA cClipboard INIT ""
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
   METHOD RecordEdit( aBefore, lSeparate )
   METHOD PushOp( nRow, aOld, aNew, lSeparate )
   METHOD ApplyOp( aOp, lInverse )
   METHOD Undo()
   METHOD Redo()
   METHOD BlkCmtState( nLine )
   METHOD ScanBlkLine( cText, lIn )
   METHOD LoadText( cText )
   METHOD GetText( lSoftCR )
   METHOD ReformParagraph()
   METHOD AddLine( cLine, lSoftCR )
   METHOD InsertLine( cLine, lSoftCR, nRow )
   METHOD LoadFile( cFileName, cRaw )
   METHOD SaveFile()
   DATA   cRecoveredBase INIT ""
   DATA   lJournalWarned INIT .F.   // one-shot: recovery write failing
   DATA   cDocId        INIT ""     // unique per editor instance (multi-doc):
                                    // journals of unnamed buffers key on it,
                                    // otherwise two "noname" docs would share
                                    // one journal and clobber each other
   METHOD JournalKey()
   METHOD UpdateJournal()
   METHOD JournalDiscard()
   METHOD SetDirty( l )
   METHOD DiskStamp( cFile )
   METHOD DiskChanged()
   METHOD DiskChangedSinceLoad()
   METHOD FileVanished()
   METHOD Display()
   METHOD DisplayLine( nLine )
   METHOD LineColor( nLine ) INLINE ;
                     If( nLine == ::nRow - ::nFirstRow + ::nTop, ::cClrSelRow, ::cColorSpec )
   METHOD MoveCursor( nKey )
   METHOD Col()
   METHOD GoTo( nRow, nCol, nRefreshMode )
   METHOD RefreshLine()
   METHOD VisualText( cText )
   METHOD VisualCol( nRow, nCharCol )
   METHOD CharCol( nRow, nVisualCol )
   METHOD ShowCursor() INLINE ( SetCursor( SC_NORMAL ), SetPos( ::Row(), ::Col() ) )
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

   local aLines, n, aBefore

   // Whitespace-only copied lines contain data, not an absent clipboard.
   if Len( ::cClipboard ) > 0
      ::ClearSelection()   // same stale-mark guard as CopySelection
      // A copied/cut block carries hb_eol() between its lines: split it back
      // into real lines (hb_ATokens with lAll=.T. keeps empty ones) instead
      // of embedding the eol bytes inside a single model line.
      aLines := hb_ATokens( ::cClipboard, hb_eol(), .T. )
      // Insert below current line; independent of insert/overstrike mode
      aBefore := ::LinesSnapshot()
      for n := 1 to Len( aLines )
         if ::nRow + n > Len( ::aText )
            ::AddLine( aLines[ n ], .F. )
         else
            ::InsertLine( aLines[ n ], .F., ::nRow + n )
         endif
      next
      ::RecordEdit( aBefore )
      ::lDirty := .T.
      ::GoTo( ::nRow + 1, 5 )
      ::Display()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD DeleteLine() CLASS HBSrcEdit

   local aBefore := ::LinesSnapshot()

   if Len( ::aText ) > 1
      // Delete Line acts on the current line, not the marked range.
      // Old anchors may point past the line array after the deletion.
      ::ClearSelection()
      ::cClipboard = ::aText[ ::nRow ]:cText
      ::RemoveLine( ::nRow )
      ATail( ::aText ):cEol := ""
      ::RecordEdit( aBefore )
      ::lDirty := .T.
      ::GoTo( ::nRow, 5 )  // GoTo clamps nRow to LineCount
      ::Display()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD DuplicateLine() CLASS HBSrcEdit

   local aBefore := ::LinesSnapshot()

   // The line command consumes the old range before moving its cursor.
   ::ClearSelection()
   // Insert a copy below current line; independent of insert/overstrike mode
   ::InsertLine( ::aText[ ::nRow ]:cText, .F., ::nRow + 1 )
   ::RecordEdit( aBefore )
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
   for n = 1 to ::nRow
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

   // FindText already starts after the cursor. A second increment skipped
   // adjacent/overlapping matches and moved the cursor when no match exists.
   ::FindText( ::cFindText )

return nil

//-----------------------------------------------------------------------------------------//

// replace every occurrence (case-insensitive) in the whole buffer.
// Recorded as a single undoable op.  Adapted from tvedit.prg ReplaceSel().
METHOD ReplaceAll( cFind, cReplace ) CLASS HBSrcEdit

   LOCAL n, nPos, nFrom, cLine, cNew, nCount := 0
   LOCAL aOld := {}, aNew := {}
   LOCAL lChanged := .F.
   LOCAL cFindU := Upper( cFind )

   // An all-space search is data, just as it is in FindText.
   if Len( cFind ) == 0
      return 0
   endif

   for n = 1 to Len( ::aText )
      AAdd( aOld, HBIDE_LinePack( ::aText[ n ] ) )
      cLine := ::aText[ n ]:cText
      cNew := ""
      nFrom := 1
      while ( nPos := At( cFindU, Upper( SubStr( cLine, nFrom ) ) ) ) > 0
         cNew += SubStr( cLine, nFrom, nPos - 1 ) + cReplace
         nFrom += nPos - 1 + Len( cFind )
         nCount++
      end
      cNew += SubStr( cLine, nFrom )
      lChanged := lChanged .or. ! HBIDE_StrEq( cNew, cLine )
      AAdd( aNew, cNew )
   next

   if lChanged
      // The prefilled range belongs to the old text, not the result.
      ::ClearSelection()
      for n = 1 to Len( ::aText )
         ::aText[ n ]:cText := aNew[ n ]
      next
      ::PushOp( 1, aOld, ::LinesSnapshot(), .T. )
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

   // Use the same half-open range as keyboard selection. The old
   // nSelRow-only highlight was invisible to SelRange(), so typing,
   // Delete and Copy did not act on the double-clicked word.
   ::ClearSelection()
   ::nMarkRow := nRow
   ::nMarkCol := nStart + 4
   ::lMark := .T.
   ::GoTo( nRow, nEnd + 5, _REFRESH_ALL )
   ::cClipboard := ::SelectionText()

   ::Display()

return nil

//-----------------------------------------------------------------------------------------//

METHOD Edit( nKey ) CLASS HBSrcEdit

   local aBefore, lSelectionEdit, lDirtyBefore
   local cCharKey := iif( hb_keyStd( nKey ) == K_TAB .AND. Set( _SET_INSERT ), ;
                          Space( TabCount( ::nTabWidth, ::VisualCol( ::nRow, ::nCol - 4 ) ) ), ;
                          hb_keyChar( nKey ) )

   // Pure cursor/scroll keys cannot change the text: skip the whole-file
   // snapshot + diff (cost grows with the file size on every arrow, PgDn,
   // wheel step). Everything else is recorded exactly as before.
   if HBIDE_IsNavKey( nKey )
      ::lOpRecorded := .F.
      ::EditKey( nKey )
      ::lInUndo := .F.
      return Self
   endif

   // Single-char insertion with no selection and no wordwrap edits exactly
   // one line: EditKey records that one-line op directly via PushOp, so the
   // whole-file snapshot+diff (O(file size) on EVERY typed char; measured
   // 2026-10-26: 0.28 -> 4.87 ms/char from 100 to 20k lines) is skipped.
   // MUST stay in lockstep with the hot branch in EditKey below.
   if ! HB_ISNULL( cCharKey ) .and. ::SelRange() == NIL .and. ! ::lWordWrap
      ::lOpRecorded := .F.
      ::EditKey( nKey )
      ::lInUndo := .F.
      return Self
   endif

   aBefore := ::LinesSnapshot()
   lDirtyBefore := ::lDirty
   lSelectionEdit := ::SelRange() != NIL
   ::lOpRecorded := .F.
   ::EditKey( nKey )

   if ::lInUndo
      ::lInUndo := .F.
   elseif ! ::lOpRecorded
      // Replacing/deleting a marked range is one distinct undo action,
      // not part of typing before or after that range.
      ::RecordEdit( aBefore, lSelectionEdit )
      // Delete+insert can reproduce the selected bytes exactly. SelDelete
      // dirties eagerly; no recorded change must keep the old dirty state.
      if lSelectionEdit .and. ! ::lOpRecorded
         ::lDirty := lDirtyBefore
      endif
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
   local cKey, oLine, nPos, lHotPath, lBlkBefore, lSkipTail := .F., cOldLine

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
           ::GoTo( MRow() - ::nTop + ::nFirstRow, 4 + ::CharCol( MRow() - ::nTop + ::nFirstRow, ;
                    Max( 1, MCol() - ::nLeft - 4 + ::VisualCol( MRow() - ::nTop + ::nFirstRow, ::nFirstCol ) ) ), _REFRESH_ALL )
           ::SelectWord( ::nRow, ::nCol - 4 )

      case nKeyStd == K_LBUTTONDOWN
           ::ClearSelection()
           ::GoTo( MRow() - ::nTop + ::nFirstRow, 4 + ::CharCol( MRow() - ::nTop + ::nFirstRow, ;
                    Max( 1, MCol() - ::nLeft - 4 + ::VisualCol( MRow() - ::nTop + ::nFirstRow, ::nFirstCol ) ) ), _REFRESH_ALL )

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
              // Vertical movement can retain a column past a short EOL.
              // Backspace there moves left but removes no source byte.
              if ::nCol - 5 <= hb_ULen( ::aText[ ::nRow ]:cText )
                 ::lDirty := .T.
              endif
              ::aText[ ::nRow ]:cText := hb_UStuff( ::aText[ ::nRow ]:cText, --::nCol - 4, 1, "" )
              ::GoTo( ::nRow, ::nCol, _REFRESH_LINE )
           ELSEIF ::nRow > 1
              // Join with previous line
              ::lDirty := .T.
              nPos = hb_ULen( ::aText[ ::nRow - 1 ]:cText )
              ::GoTo( ::nRow - 1, nPos + 1 )
              ::nCol = nPos + 1
              ::aText[ ::nRow ]:cEol := ::aText[ ::nRow + 1 ]:cEol
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
           if ::nRow < Len( ::aText ) .and. ::nCol > hb_ULen( ::aText[ ::nRow ]:cText )
              ::aText[ ::nRow ]:cEol := ::aText[ ::nRow + 1 ]:cEol
           endif
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
           Space( TabCount( ::nTabWidth, ::VisualCol( ::nRow, ::nCol - 4 ) ) ), ;
           hb_keyChar( nKey ) ) )

           lHotPath := ( ::SelRange() == NIL )
           if ::SelRange() != NIL
              ::SelDelete( ::SelRange() )
           else
              ::ClearSelection()
           endif
           // Tab expansion belongs to the insertion point after deleting
           // the range, not its old moving endpoint (direction-dependent).
           if nKeyStd == K_TAB .and. Set( _SET_INSERT )
              cKey := Space( TabCount( ::nTabWidth, ::VisualCol( ::nRow, ::nCol - 4 ) ) )
           endif
           oLine := ::aText[ ::nRow ]
           // capture BEFORE the past-EOL padding below: the recorded undo op
           // must restore the line as it was, padding included in the new
           // side only (snapshot+diff did exactly that)
           cOldLine := oLine:cText
           IF ( nPos := ::nCol - hb_ULen( oLine:cText ) - 5 ) > 0
              oLine:cText += Space( nPos )
           ENDIF
           if lHotPath
              // state entering the next line before this char: a char that
              // toggles /* or */ recolors everything below
              lBlkBefore := ::BlkCmtState( ::nRow + 1 )
           endif
           oLine:cText := hb_UStuff( oLine:cText, ::nCol - 4, ;
                                     iif( Set( _SET_INSERT ), 0, 1 ), cKey )
           if ! HBIDE_StrEq( cOldLine, oLine:cText )
              ::lDirty := .T.
           endif
           ::nCol += hb_ULen( cKey )
           IF ::lWordWrap .AND. hb_ULen( oLine:cText ) > ::nWordWrapCol
              ::ReformParagraph()
           ELSEIF lHotPath
              if ! ::lWordWrap
                 // direct one-line undo op: Edit() skipped the whole-file
                 // snapshot+diff for this key (lockstep comment there)
                 ::PushOp( ::nRow, { HBIDE_LinePack( oLine, cOldLine ) }, { HBIDE_LinePack( oLine ) } )
              endif
              ::nBlkDirty := Min( ::nBlkDirty, ::nRow )
              IF ::BlkCmtState( ::nRow + 1 ) != lBlkBefore
                 ::GoTo( ::nRow, ::nCol, _REFRESH_ALL )
              ELSE
                 // hot path: single-line edit, no coloring context change.
                 // One colored repaint of the current line replaces the old
                 // uncolored RefreshLine + 3 colored DisplayLine (prev/cur/
                 // next) per character (4 full-line paints -> 1, 3
                 // tokenizations -> 1). GoTo still scrolls horizontally and
                 // does a full Display() itself when the view shifts.
                 ::GoTo( ::nRow, ::nCol, _REFRESH_NONE )
                 ::DisplayLine( ::Row() )
                 lSkipTail := .T.
              ENDIF
           ELSE
              ::GoTo( ::nRow, ::nCol, _REFRESH_LINE )
           ENDIF

      otherwise
           ::Super:Edit( nKey )
   endcase

   if ! lSkipTail
      if HBIDE_IsNavKey( nKey ) .and. ! ::lMark
         // Pure cursor move: only the current-row highlight (LineColor)
         // changes. The new row gains it here; the old row loses it in the
         // nOldScrRow block below, and same-row moves need no repaint at
         // all (GoTo repaints everything itself when the view scrolls).
         // With the F8 range mark active the selection highlight can span
         // lines, so that path keeps the full 3-line tail.
         if ::Row() != nOldScrRow
            ::DisplayLine( ::Row() )
         endif
      else
         if ::Row() > ::nTop
            ::DisplayLine( ::Row() - 1 )
         endif

         ::DisplayLine( ::Row() )

         if ::Row() < ::nBottom
            ::DisplayLine( ::Row() + 1 )
         endif
      endif
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

   // ::aText is an access method: read it once, not once per line
   local aText := ::aText, nLen := Len( aText )
   local aLines := Array( nLen ), n

   for n = 1 to nLen
      aLines[ n ] := HBIDE_LinePack( aText[ n ] )
   next

return aLines

//-----------------------------------------------------------------------------------------//

// Diff-based op recorder: finds the changed line span between snapshots
// Exact string equality immune to the default SET EXACT OFF ragged compare:
// with EXACT OFF, "abc" == "" (and "abc" == "ab") is .T., which silently
// discards undo ops whose new line is empty or a prefix of the old one.
STATIC FUNCTION HBIDE_StrEq( cA, cB )
return Len( cA ) == Len( cB ) .and. cA == cB

METHOD RecordEdit( aBefore, lSeparate ) CLASS HBSrcEdit

   local aAfter := ::LinesSnapshot()
   local nB := Len( aBefore ), nA := Len( aAfter )
   local nPre := 0, nSuf := 0, i, lExact, nMin
   local aOld := {}, aNew := {}

   // Exact compare without a function call per line: SET EXACT ON makes
   // == exact for strings (see HBIDE_StrEq); restored right after.
   lExact := Set( _SET_EXACT, .T. )
   nMin := Min( nB, nA )
   while nPre < nMin .and. aBefore[ nPre + 1 ] == aAfter[ nPre + 1 ]
      nPre++
   end
   nMin := Min( nB - nPre, nA - nPre )
   while nSuf < nMin .and. aBefore[ nB - nSuf ] == aAfter[ nA - nSuf ]
      nSuf++
   end
   Set( _SET_EXACT, lExact )

   if nPre + nSuf >= nB .and. nPre + nSuf >= nA
      return Self   // no text change
   endif

   for i := nPre + 1 to nB - nSuf
      AAdd( aOld, aBefore[ i ] )
   next
   for i := nPre + 1 to nA - nSuf
      AAdd( aNew, aAfter[ i ] )
   next

   ::PushOp( nPre + 1, aOld, aNew, lSeparate )

return Self

//-----------------------------------------------------------------------------------------//

// Undo stack ops: { nRow, aOldLines, aNewLines, lSeparate } replaces lines.
// lSeparate keeps explicit commands out of adjacent typing bursts.
// (model adapted from tvedit's PushUndo, reworked for HBEditor's line array)
METHOD PushOp( nRow, aOld, aNew, lSeparate ) CLASS HBSrcEdit

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
   if ! hb_defaultValue( lSeparate, .F. ) .and. ;
      Len( ::aUndo ) > 0 .and. Len( ::aUndo ) != ::nSavedUndoLen
      aLast := ATail( ::aUndo )
      if ( Len( aLast ) < 4 .or. ! aLast[ 4 ] ) .and. ;
         Len( aLast[ 2 ] ) == 1 .and. Len( aLast[ 3 ] ) == 1 .and. ;
         Len( aOld ) == 1 .and. Len( aNew ) == 1 .and. ;
         aLast[ 1 ] == nRow .and. aLast[ 3, 1 ] == aOld[ 1 ]
         aLast[ 3, 1 ] := aNew[ 1 ]
         ::aRedo := {}
         ::lOpRecorded := .T.
         return Self
      endif
   endif

   ::AdjustBPs( nRow, aOld, aNew )
   AAdd( ::aUndo, { nRow, aOld, aNew, hb_defaultValue( lSeparate, .F. ) } )
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
         ::AddLine( HBIDE_LineText( aIns[ i ] ), .F. )
      else
         ::InsertLine( HBIDE_LineText( aIns[ i ] ), .F., nRow + i - 1 )
      endif
   next
   for i = 1 to Len( aIns )
      ::aText[ nRow + i - 1 ]:cEol := SubStr( aIns[ i ], Len( HBIDE_LineText( aIns[ i ] ) ) + 2 )
      ::aText[ nRow + i - 1 ]:lSoftCR := Left( aIns[ i ], 1 ) == "S"
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

   local aEnds := {}, aPhysical := {}, n := 1, nStart := 1, c
   local oNew, aLines, i

   // Selection coordinates belong to the old buffer. A shorter reload
   // must not leave an anchor outside the new line array.
   ::ClearSelection()
   ::cEol := hb_eol()
   while n <= Len( cText )
      c := SubStr( cText, n, 1 )
      if c == Chr( 13 ) .or. c == Chr( 10 )
         if SubStr( cText, n, 2 ) == Chr( 13 ) + Chr( 10 )
            c += Chr( 10 )
            n++
         endif
         AAdd( aPhysical, SubStr( cText, nStart, n - nStart + 1 - Len( c ) ) )
         AAdd( aEnds, c )
         nStart := n + 1
      endif
      n++
   end
   AAdd( aPhysical, SubStr( cText, nStart ) )
   if Len( aEnds ) > 0
      ::cEol := aEnds[ 1 ]
   endif
   ::aText := {}
   for n := 1 to Len( aPhysical )
      aLines := HBIDE_WrapLines( aPhysical[ n ], iif( ::lWordWrap, ::nWordWrapCol + 1, 0 ), ::nTabWidth )
      for i := 1 to Len( aLines )
         oNew := aLines[ i ]
         if i == Len( aLines ) .and. n <= Len( aEnds )
            oNew:cEol := aEnds[ n ]
         endif
         AAdd( ::aText, oNew )
      next
   next
   ::lDirty := .F.

   if ::nNumCols > 0
      ::GoTo( 1, 1 )
   endif
   ::aUndo := {}
   ::aRedo := {}
   ::nSavedUndoLen := 0
   ::lInUndo := .F.
   ::nBlkDirty := 1

return Self

//-----------------------------------------------------------------------------------------//

METHOD GetText( lSoftCR ) CLASS HBSrcEdit

   local cText := "", oLine

   for each oLine in ::aText
      cText += oLine:cText
      if ! oLine:__enumIsLast()
         cText += iif( oLine:lSoftCR .and. ::lWordWrap, ;
                       iif( hb_defaultValue( lSoftCR, .F. ), Chr( 141 ) + Chr( 10 ), "" ), ;
                       oLine:cEol )
      endif
   next

return cText

// HBEditor uses text columns. The source editor adds a four-cell gutter,
// so reflow must translate both the input and returned cursor position.
METHOD ReformParagraph() CLASS HBSrcEdit
   local cText := "", cEnd := "", lNext := .T.
   local nStart := ::nRow, nLine, nOffset := Max( 0, ::nCol - 5 ), aLines

   while lNext .and. ::nRow <= Len( ::aText )
      cText += ::aText[ ::nRow ]:cText
      cEnd := ::aText[ ::nRow ]:cEol
      lNext := ::aText[ ::nRow ]:lSoftCR
      ::RemoveLine( ::nRow )
   end
   aLines := HBIDE_WrapLines( cText, ::nWordWrapCol + 1, ::nTabWidth )
   for nLine := Len( aLines ) to 1 step -1
      hb_AIns( ::aText, nStart, aLines[ nLine ], .T. )
   next
   ::aText[ nStart + Len( aLines ) - 1 ]:cEol := cEnd
   nLine := 1
   while nLine < Len( aLines ) .and. nOffset >= hb_ULen( aLines[ nLine ]:cText )
      nOffset -= hb_ULen( aLines[ nLine++ ]:cText )
   end
return ::GoTo( nStart + nLine - 1, nOffset + 5, _REFRESH_ALL )

// Wrap by display columns without expanding or repeating any source byte.
STATIC FUNCTION HBIDE_WrapLines( cText, nWidth, nTabWidth )
   local aLines := {}, nStart := 1, n := 1, nCols := 0, nBlank := 0
   local nLen := hb_ULen( cText ), c, oLine
   if nWidth <= 0
      return { HBIDETextLine():New( cText, .F. ) }
   endif
   while n <= nLen
      c := hb_USubStr( cText, n, 1 )
      nCols += iif( c == Chr( 9 ), nTabWidth - ( nCols % nTabWidth ), 1 )
      if c == " " .or. c == Chr( 9 )
         nBlank := n
      endif
      if nCols >= nWidth .and. n < nLen
         if nBlank >= nStart
            n := nBlank
         endif
         oLine := HBIDETextLine():New( hb_USubStr( cText, nStart, n - nStart + 1 ), .T. )
         AAdd( aLines, oLine )
         nStart := n + 1
         nCols := 0
         nBlank := 0
      endif
      n++
   end
   AAdd( aLines, HBIDETextLine():New( hb_USubStr( cText, nStart ), .F. ) )
return aLines

METHOD AddLine( cLine, lSoftCR ) CLASS HBSrcEdit
return ::InsertLine( cLine, lSoftCR, Len( ::aText ) + 1 )

METHOD InsertLine( cLine, lSoftCR, nRow ) CLASS HBSrcEdit
   local oNew := HBIDETextLine():New( cLine, lSoftCR )
   if nRow > 1
      oNew:cEol := ::aText[ nRow - 1 ]:cEol
      if Len( ::aText[ nRow - 1 ]:cEol ) == 0
         ::aText[ nRow - 1 ]:cEol := ::cEol
      endif
   else
      oNew:cEol := ::cEol
   endif
   hb_AIns( ::aText, nRow, oNew, .T. )
return Self

// Undo strings carry soft-wrap state plus their physical boundary.
STATIC FUNCTION HBIDE_LinePack( oLine, cText )
return iif( oLine:lSoftCR, "S", "H" ) + hb_defaultValue( cText, oLine:cText ) + oLine:cEol

STATIC FUNCTION HBIDE_LineText( cLine )
   local n := Len( cLine )
   do while n > 0 .and. ( SubStr( cLine, n, 1 ) == Chr( 13 ) .or. SubStr( cLine, n, 1 ) == Chr( 10 ) )
      n--
   end
return SubStr( cLine, 2, n - 1 )

//-----------------------------------------------------------------------------------------//

METHOD LoadFile( cFileName, cRaw ) CLASS HBSrcEdit

   local xRet, lReadOk
   local cConv, cBody

   if cRaw == NIL
      cRaw := HBIDE_ReadFileChecked( cFileName, @lReadOk )
      if ! lReadOk
         HBIDE_MsgAlert( "Cannot read file; current document untouched: " + cFileName )
         return NIL
      endif
   endif

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

// Preserve the old backup if read, write or promotion cannot complete.
function HBIDE_BackupFile( cSource, cFailInfo )
   local lReadOk := .F., cBytes := HBIDE_ReadFileChecked( cSource, @lReadOk )
   if ! lReadOk
      cFailInfo := "could not read " + cSource + "; previous backup untouched"
      return .F.
   endif
return HBIDE_AtomicWriteFile( cSource + ".bak", cBytes, @cFailInfo )

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
      ::JournalDiscard()   // the journal exists only for unsaved work
      ::lDirty := .F.
      ::nSavedUndoLen := Len( ::aUndo )
      ::cSeenStamp := ::cLoadStamp := ::DiskStamp( ::cFile )   // our own save is not an external change
   else
      HBIDE_MsgAlert( "Save failed: " + cFailInfo )
   endif

return lOk

//-----------------------------------------------------------------------------------------//

// P0 recovery: while the buffer is dirty, keep its full text in the central
// recovery journal (2 s cadence from the IDE loop). The journal is deleted
// on a successful save and on an explicit discard; a survivor at the next
// start means the previous session ended with neither and is offered back.
// The else branch self-heals stale journals of this same file (e.g. after a
// reload-from-disk, which is not a save but drops the dirty state).
// Journal identity of THIS document: the file key when named, a per-instance
// key when unnamed, so several unsaved "noname" buffers each keep their own
// journal (the .target sidecar still records the intended name for the
// recovery prompt).
METHOD JournalKey() CLASS HBSrcEdit

   if Empty( ::cFile ) .or. ::cFile == "noname.prg"
      return "noname-" + ::cDocId
   endif

return HBIDE_RecoveryKey( ::cFile )

//-----------------------------------------------------------------------------------------//

METHOD UpdateJournal() CLASS HBSrcEdit

   local hEncoding := NIL

   if ::lUtf8 .or. ::lUtf8Bom .or. ::lUtf8Raw .or. hb_cdpSelect() != "EN"
      hEncoding := { "utf8" => ::lUtf8, "bom" => ::lUtf8Bom, "raw" => ::lUtf8Raw, "cp" => hb_cdpSelect() }
   endif
   if ::lDirty
      if ! HBIDE_RecoveryWrite( ::JournalKey(), ::cFile, ::GetText(), hEncoding )
         // journal failing (disk full, permissions): editing must never stop,
         // but the user is warned ONCE per failing streak, so they don't
         // assume crash recovery is active when it isn't
         if ! ::lJournalWarned
            ::lJournalWarned := .T.
            HBIDE_MsgAlert( "Crash recovery journal cannot be written (" + ;
                            HBIDE_RecoveryDir() + "). Editing continues, but unsaved-changes recovery is OFF.", ;
                            { "OK" }, "Recovery degraded" )
         endif
      else
         ::lJournalWarned := .F.   // a new failure streak warns again
      endif
   else
      HBIDE_RecoveryDelete( ::JournalKey() )
   endif

return nil

//-----------------------------------------------------------------------------------------//

// lDirty is inherited PROTECTED from HBEditor: external callers (recovery)
// go through this setter.
METHOD SetDirty( l ) CLASS HBSrcEdit

   hb_defaultValue( l, .T. )
   ::lDirty := l

return nil

//-----------------------------------------------------------------------------------------//

METHOD JournalDiscard() CLASS HBSrcEdit

   if ! Empty( ::cRecoveredBase )
      HBIDE_RecoveryDeleteBase( ::cRecoveredBase )
      ::cRecoveredBase := ""
   endif
   HBIDE_RecoveryDelete( ::JournalKey() )

return nil

//-----------------------------------------------------------------------------------------//

// Model columns remain character positions. Only painting and the screen
// cursor expand tabs, so selection, save and undo retain the original bytes.
METHOD VisualText( cText ) CLASS HBSrcEdit
   local cOut := "", n, c, nCol := 0, nSpaces
   if !( Chr( 9 ) $ cText )
      return cText
   endif
   for n := 1 to hb_ULen( cText )
      c := hb_USubStr( cText, n, 1 )
      if c == Chr( 9 )
         nSpaces := ::nTabWidth - ( nCol % ::nTabWidth )
         cOut += Space( nSpaces )
         nCol += nSpaces
      else
         cOut += c
         nCol++
      endif
   next
return cOut

METHOD VisualCol( nRow, nCharCol ) CLASS HBSrcEdit
   if !( Chr( 9 ) $ ::GetLine( nRow ) )
      return Max( 1, nCharCol )
   endif
return hb_ULen( ::VisualText( hb_ULeft( ::GetLine( nRow ), Max( 0, nCharCol - 1 ) ) ) ) + ;
       Max( 0, nCharCol - 1 - hb_ULen( ::GetLine( nRow ) ) ) + 1

METHOD CharCol( nRow, nVisualCol ) CLASS HBSrcEdit
   local n := 1, nScreen := 1, cText := ::GetLine( nRow ), c
   if !( Chr( 9 ) $ cText )
      return Max( 1, nVisualCol )
   endif
   while n <= hb_ULen( cText ) .and. nScreen < nVisualCol
      c := hb_USubStr( cText, n++, 1 )
      nScreen += iif( c == Chr( 9 ), ::nTabWidth - ( ( nScreen - 1 ) % ::nTabWidth ), 1 )
   end
return n + Max( 0, nVisualCol - nScreen )

METHOD Col() CLASS HBSrcEdit
return ::nLeft + 4 + ::VisualCol( ::nRow, ::nCol - 4 ) - ;
       ::VisualCol( ::nRow, ::nFirstCol )

METHOD GoTo( nRow, nCol, nRefreshMode ) CLASS HBSrcEdit
   local nFirstRow := ::nFirstRow, nFirstCol := ::nFirstCol
   nRefreshMode := hb_defaultValue( nRefreshMode, _REFRESH_NONE )
   nRow := Max( 1, Min( nRow, ::LineCount() ) )
   if nCol == -1
      nCol := hb_ULen( ::GetLine( nRow ) ) + 5
   endif
   nCol := Max( 5, nCol )
   if ::lWordWrap
      nCol := Min( nCol, hb_ULen( ::GetLine( nRow ) ) + 5 )
   endif
   ::nRow := nRow
   ::nCol := nCol
   ::nFirstRow := Max( 1, Min( ::nFirstRow, nRow ) )
   if nRow > ::nFirstRow + ::nNumRows - 1
      ::nFirstRow := nRow - ::nNumRows + 1
   endif
   ::nFirstCol := Max( 1, ::nFirstCol )
   do while ::Col() < ::nLeft + 4 .and. ::nFirstCol > 1
      ::nFirstCol--
   end
   do while ::Col() > ::nRight .and. ::nFirstCol < ::nCol - 4
      ::nFirstCol++
   end
   if nRefreshMode == _REFRESH_ALL .or. nFirstRow != ::nFirstRow .or. nFirstCol != ::nFirstCol
      ::Display()
   elseif nRefreshMode == _REFRESH_LINE
      ::RefreshLine()
   endif
   SetPos( ::Row(), ::Col() )
return Self

METHOD RefreshLine() CLASS HBSrcEdit
return ::DisplayLine( ::Row() )

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
   local nVisualFirst := ::VisualCol( nRowNum, ::nFirstCol )

   DispBegin()
   hb_DispOutAt( nLine, ::nLeft, PadL( nRowNum, 4 ), ;
                 iif( AScan( ::aBPs, nRowNum ) > 0, ::cClrBP, "N/W" ) )
   hb_DispOutAt( nLine, ::nLeft + 4,;
                 SubStrPad( cLine := ::VisualText( ::GetLine( ::nFirstRow + nLine - ::nTop ) ),;
                 nVisualFirst, ::nRight - ::nLeft - 4 + 1 ),;
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

         nCol = 5 + n - hb_ULen( cToken ) - nVisualFirst
         nStart = If( nCol < 5, 6 - nCol, 1 )
         nCol = Max( nCol, 5 )

         if nCol < ::nNumCols
            hb_DispOutAt( nLine, nCol,;
                          hb_USubStr( cToken, nStart, Min( hb_ULen( cToken ) - nStart + 1, ::nRight - nCol + 1 ) ),;
                          cColor + SubStr( ::LineColor( nLine ),;
                          At( "/", ::LineColor( nLine ) ) ) )
         endif
         cToken = ""
      endif
   end

   // Highlight only the visible intersection; selection may begin left of
   // the viewport or continue past the right border.
   if ::nSelRow > 0 .and. nRowNum == ::nSelRow
      nCol := ::VisualCol( nRowNum, ::nSelStart )
      nStart := ::VisualCol( nRowNum, ::nSelEnd + 1 )
   elseif ::lMark .and. ( aSel := ::SelRange() ) != NIL .and. ;
          nRowNum >= aSel[ 1 ] .and. nRowNum <= aSel[ 3 ]
      nCol := ::VisualCol( nRowNum, iif( nRowNum == aSel[ 1 ], aSel[ 2 ] - 4, 1 ) )
      nStart := ::VisualCol( nRowNum, iif( nRowNum == aSel[ 3 ], aSel[ 4 ] - 4, ;
                                        hb_ULen( ::GetLine( nRowNum ) ) + 1 ) )
   else
      nCol := nStart := 0
   endif
   nCol := Max( nCol, nVisualFirst )
   nStart := Min( nStart, nVisualFirst + ::nRight - ( ::nLeft + 4 ) + 1 )
   if nStart > nCol
      hb_DispOutAt( nLine, ::nLeft + 4 + nCol - nVisualFirst, ;
                    hb_USubStr( cLine, nCol, nStart - nCol ), "N/W" )
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
            HBIDE_StrEq( HBIDE_LineText( aNew[ nBP - nRow + 1 ] ), HBIDE_LineText( aOld[ nBP - nRow + 1 ] ) )
            nAt := nBP - nRow + 1
         else
            nAt := AScan( aNew, { | c | HBIDE_StrEq( HBIDE_LineText( c ), HBIDE_LineText( aOld[ nBP - nRow + 1 ] ) ) } )
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
      cOut += iif( ::aText[ n - 1 ]:lSoftCR .and. ::lWordWrap, "", hb_eol() ) + ::aText[ n ]:cText
   next
   cOut += iif( ::aText[ aSel[ 3 ] - 1 ]:lSoftCR .and. ::lWordWrap, "", hb_eol() ) + ;
           hb_USubStr( ::aText[ aSel[ 3 ] ]:cText, 1, aSel[ 4 ] - 5 )

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
   ::PushOp( aSel[ 1 ], aOld, { HBIDE_LinePack( ::aText[ aSel[ 1 ] ] ) }, .T. )

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
      AAdd( aOld, HBIDE_LinePack( ::aText[ n ] ) )
   next
   cMerged = hb_USubStr( HBIDE_LineText( aOld[ 1 ] ), 1, aSel[ 2 ] - 5 ) + ;
             hb_USubStr( HBIDE_LineText( aOld[ Len( aOld ) ] ), aSel[ 4 ] - 4 )
   ::aText[ aSel[ 1 ] ]:lSoftCR := ::aText[ aSel[ 3 ] ]:lSoftCR
   ::aText[ aSel[ 1 ] ]:cEol := ::aText[ aSel[ 3 ] ]:cEol
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
         // UTF-8 encodes scalar values in their shortest form only.
         // Restrict the second byte for overlongs, surrogates and >U+10FFFF.
         nJ := Asc( SubStr( cText, nI + 1, 1 ) )
         if ( nB == 0xE0 .and. nJ < 0xA0 ) .or. ;
            ( nB == 0xED .and. nJ > 0x9F ) .or. ;
            ( nB == 0xF0 .and. nJ < 0x90 ) .or. ;
            ( nB == 0xF4 .and. nJ > 0x8F )
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

   local n

   if HBIDE_Utf8Valid( cText )
      // Detection must not depend on the current editor codepage: under
      // UTF8, hb_StrToUTF8() is identity even for real multibyte text.
      for n := 1 to Len( cText )
         if Asc( SubStr( cText, n, 1 ) ) >= 0x80
            return .T.
         endif
      next
   endif

return .F.
//-----------------------------------------------------------------------------------------//

function HBIDE_Utf8Bom()

return hb_BChar( 0xEF ) + hb_BChar( 0xBB ) + hb_BChar( 0xBF )

//-----------------------------------------------------------------------------------------//

// Keys that only move the cursor or scroll (never edit the text).
static function HBIDE_IsNavKey( nKey )

   switch hb_keyStd( nKey )
      case K_UP
      case K_DOWN
      case K_LEFT
      case K_RIGHT
      case K_HOME
      case K_END
      case K_PGUP
      case K_PGDN
      case K_MWFORWARD
      case K_MWBACKWARD
         return .T.
   endswitch

return .F.

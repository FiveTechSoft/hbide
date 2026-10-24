#include "hbclass.ch"
#include "inkey.ch"
#include "setcurs.ch"

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
   DATA   nSelStart    INIT 0
   DATA   nSelEnd      INIT 0
   DATA   aUndo        INIT {}
   DATA   aRedo        INIT {}
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
   METHOD ClearSelection()

ENDCLASS

//-----------------------------------------------------------------------------------------//

METHOD ClearSelection() CLASS HBSrcEdit

   local nOldSelRow := ::nSelRow

   ::nSelRow   = 0
   ::nSelStart = 0
   ::nSelEnd   = 0

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

   if ! Empty( ::cClipboard )
      // Insert below current line; independent of insert/overstrike mode
      ::PushOp( ::nRow + 1, {}, { ::cClipboard } )
      ::InsertLine( ::cClipboard, .F., ::nRow + 1 )
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

   local n, nPos

   if Empty( cText )
      return nil
   endif

   ::cFindText = cText

   // Search from current position forward
   for n = ::nRow to Len( ::aText )
      if n == ::nRow
         nPos = At( Upper( cText ), Upper( SubStr( ::aText[ n ]:cText, ::nCol - 4 + 1 ) ) )
         if nPos > 0
            nPos += ::nCol - 4 - 1
         endif
      else
         nPos = At( Upper( cText ), Upper( ::aText[ n ]:cText ) )
      endif
      if nPos > 0
         ::GoTo( n, nPos + 4 )
         ::Display()
         return nil
      endif
   next

   // Wrap around from beginning
   for n = 1 to ::nRow - 1
      nPos = At( Upper( cText ), Upper( ::aText[ n ]:cText ) )
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

   local cLine, nStart, nEnd, cChar, cWordChars

   if nRow < 1 .or. nRow > Len( ::aText )
      return nil
   endif

   cLine = ::aText[ nRow ]:cText
   cWordChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"

   if nTextCol < 1 .or. nTextCol > Len( cLine )
      ::ClearSelection()
      return nil
   endif

   cChar = SubStr( cLine, nTextCol, 1 )
   if ! cChar $ cWordChars
      ::ClearSelection()
      return nil
   endif

   // Find word start
   nStart = nTextCol
   while nStart > 1 .and. SubStr( cLine, nStart - 1, 1 ) $ cWordChars
      nStart--
   end

   // Find word end
   nEnd = nTextCol
   while nEnd < Len( cLine ) .and. SubStr( cLine, nEnd + 1, 1 ) $ cWordChars
      nEnd++
   end

   ::nSelRow   = nRow
   ::nSelStart = nStart
   ::nSelEnd   = nEnd
   ::cClipboard = SubStr( cLine, nStart, nEnd - nStart + 1 )

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
   endif

return Self

//-----------------------------------------------------------------------------------------//

METHOD EditKey( nKey ) CLASS HBSrcEdit

   local nKeyStd := hb_keyStd( nKey )
   local cKey, oLine, nPos

   do case
      case nKeyStd == K_CTRL_Z
           ::lInUndo := .T.
           ::Undo()

      case nKeyStd == K_CTRL_U
           ::lInUndo := .T.
           ::Redo()

      case nKey == K_LDBLCLK
           ::GoTo( MRow() - ::nTop + ::nFirstRow, Max( MCol() - ::nLeft + ::nFirstCol, 5 ), _REFRESH_ALL )
           ::SelectWord( ::nRow, ::nCol - 4 )

      case nKey == K_LBUTTONDOWN
           ::ClearSelection()
           ::GoTo( MRow() - ::nTop + ::nFirstRow, Max( MCol() - ::nLeft + ::nFirstCol, 5 ), _REFRESH_ALL )

      case nKey == K_MWBACKWARD
           ::Super:Edit( K_DOWN )

      case nKey == K_MWFORWARD
           ::Super:Edit( K_UP )

      case nKeyStd == K_BS
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

      case nKeyStd == K_DEL
           ::ClearSelection()
           nPos = ::nCol
           ::nCol = Max( ::nCol - 4, 1 )
           ::Super:Edit( nKey )
           ::GoTo( ::nRow, nPos, _REFRESH_ALL )

      case nKeyStd == K_ENTER
           ::ClearSelection()
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

      case nKeyStd == K_CTRL_Y
           ::DeleteLine()

      case nKey == K_F2
           ::SaveFile()

      case ! HB_ISNULL( cKey := iif( nKeyStd == K_TAB .AND. Set( _SET_INSERT ), ;
           Space( TabCount( ::nTabWidth, ::nCol ) ), ;
           hb_keyChar( nKey ) ) )

           ::ClearSelection()
           ::lDirty := .T.
           oLine := ::aText[ ::nRow ]
           IF ( nPos := ::nCol - hb_ULen( oLine:cText ) - 1 ) > 0
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
METHOD RecordEdit( aBefore ) CLASS HBSrcEdit

   local aAfter := ::LinesSnapshot()
   local nB := Len( aBefore ), nA := Len( aAfter )
   local nPre := 0, nSuf := 0, i
   local aOld := {}, aNew := {}

   while nPre < Min( nB, nA ) .and. aBefore[ nPre + 1 ] == aAfter[ nPre + 1 ]
      nPre++
   end
   while nSuf < Min( nB - nPre, nA - nPre ) .and. ;
         aBefore[ nB - nSuf ] == aAfter[ nA - nSuf ]
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
         if aOld[ i ] != aNew[ i ]
            lSame := .F.
            exit
         endif
      next
      if lSame
         return Self
      endif
   endif

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

METHOD LoadText( cText ) CLASS HBSrcEdit

   local xRet := ::Super:LoadText( cText )

   ::aUndo := {}
   ::aRedo := {}
   ::nSavedUndoLen := 0
   ::lInUndo := .F.

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
         Alert( "UTF-8 file with characters outside CP437: opened raw " + ;
                "to avoid data loss on save" )
      endif
   endif

   ::cFile := cFileName
   xRet := ::LoadText( cRaw )

   ::cSeenStamp := ::cLoadStamp := ::DiskStamp( ::cFile )

return xRet

//-----------------------------------------------------------------------------------------//

// date+time+size stamp of the file on disk ("" when missing/unreadable).
// Coverage limit: a same-size edit within the filesystem timestamp
// resolution keeps the same stamp and is not detected.
METHOD DiskStamp( cFile ) CLASS HBSrcEdit

   local aDir

   if Empty( cFile ) .or. ! File( cFile )
      return ""
   endif

   aDir := Directory( cFile )
   if Len( aDir ) == 0
      return ""
   endif

return DToS( aDir[ 1, 3 ] ) + "|" + aDir[ 1, 4 ] + "|" + hb_ntos( aDir[ 1, 2 ] )

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

METHOD SaveFile() CLASS HBSrcEdit

   local lOk

   // raw-view UTF-8: an edit that cut a multibyte sequence (cursor/
   // backspace inside it) makes the bytes no longer valid UTF-8. Saving
   // that would corrupt the original file, so block it explicitly.
   if ::lUtf8Raw .and. ! HBIDE_Utf8Valid( ::GetText() )
      Alert( "Save blocked: the edit broke UTF-8 multibyte sequences " + ;
             "and would corrupt the file" )
      return .F.
   endif

   if ::lUtf8
      lOk := hb_MemoWrit( ::cFile, ;
               If( ::lUtf8Bom, HBIDE_Utf8Bom(), "" ) + hb_StrToUTF8( ::GetText() ) )
      if lOk
         ::lDirty := .F.
      endif
   else
      lOk := ::Super:SaveFile()
   endif

   if lOk
      ::nSavedUndoLen := Len( ::aUndo )
      ::cSeenStamp := ::cLoadStamp := ::DiskStamp( ::cFile )   // our own save is not an external change
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

   local n, cLine, cToken := "", cColor, nCol, nStart
   local cOperators := ::cOperators
   local lInComment := .F.

   DispBegin()
   hb_DispOutAt( nLine, ::nLeft, PadL( ::nFirstRow + nLine - ::nTop, 4 ), "N/W" )
   hb_DispOutAt( nLine, ::nLeft + 4,;
                 SubStrPad( cLine := ::GetLine( ::nFirstRow + nLine - ::nTop ),;
                 ::nFirstCol, ::nRight - ::nLeft - 4 + 1 ),;
                 ::LineColor( nLine ) )

   n = 1
   while n <= Len( cLine )
      while SubStr( cLine, n, 1 ) == " " .and. n <= Len( cLine )
         n++
      end

      if n > Len( cLine )
         exit
      endif

      // Check for line comment - color rest of line as comment
      if SubStr( cLine, n, 2 ) == "//"
         cToken = SubStr( cLine, n )
         n = Len( cLine ) + 1
         lInComment = .T.
      // Check for block comment start
      elseif SubStr( cLine, n, 2 ) == "/*"
         nStart = n
         n += 2
         while n <= Len( cLine ) - 1 .and. SubStr( cLine, n, 2 ) != "*/"
            n++
         end
         if n <= Len( cLine ) - 1 .and. SubStr( cLine, n, 2 ) == "*/"
            n += 2
         else
            n = Len( cLine ) + 1
         endif
         cToken = SubStr( cLine, nStart, n - nStart )
         lInComment = .T.
      else
         do case
            case SubStr( cLine, n, 1 ) == '"'
                cToken += '"'
                while SubStr( cLine, ++n, 1 ) != '"' .and. n <= Len( cLine )
                   cToken += SubStr( cLine, n, 1 )
                end
                if n <= Len( cLine )
                   cToken += '"'
                endif
                n++

            case SubStr( cLine, n, 1 ) == "'"
                cToken += "'"
                while SubStr( cLine, ++n, 1 ) != "'" .and. n <= Len( cLine )
                   cToken += SubStr( cLine, n, 1 )
                end
                if n <= Len( cLine )
                   cToken += "'"
                endif
                n++

            case SubStr( cLine, n, 1 ) $ cOperators
               while SubStr( cLine, n, 1 ) $ cOperators .and. n <= Len( cLine )
                  cToken += SubStr( cLine, n++, 1 )
               end

            case ! SubStr( cLine, n, 1 ) $ " " + cOperators .and. n <= Len( cLine )
               while ! SubStr( cLine, n, 1 ) $ " " + cOperators .and. n <= Len( cLine )
                  cToken += SubStr( cLine, n++, 1 )
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

         nCol = 5 + n - Len( cToken ) - ::nFirstCol
         nStart = If( nCol < 5, 6 - nCol, 1 )
         nCol = Max( nCol, 5 )

         if nCol < ::nNumCols
            hb_DispOutAt( nLine, nCol,;
                          SubStr( cToken, nStart, Min( Len( cToken ) - nStart + 1, ::nNumCols - 5 ) ),;
                          cColor + SubStr( ::LineColor( nLine ),;
                          At( "/", ::LineColor( nLine ) ) ) )
         endif
         cToken = ""
      endif
   end

   // Draw selection highlight
   if ::nSelRow > 0 .and. ::nFirstRow + nLine - ::nTop == ::nSelRow
      nCol = 5 + ::nSelStart - ::nFirstCol
      nStart = ::nSelEnd - ::nSelStart + 1
      if nCol >= 5 .and. nCol < ::nNumCols
         hb_DispOutAt( nLine, nCol,;
                       SubStr( ::aText[ ::nSelRow ]:cText, ::nSelStart, nStart ),;
                       "N/W" )
      endif
   endif

   DispEnd()

return Self

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

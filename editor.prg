#include "hbclass.ch"
#include "inkey.ch"
#include "setcurs.ch"

#define _REFRESH_LINE   1
#define _REFRESH_ALL    2

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

   METHOD Edit( nKey )
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

   local cSaved

   if ! Empty( ::cClipboard )
      cSaved = ::cClipboard
      ::nCol = hb_ULen( ::aText[ ::nRow ]:cText ) + 1
      ::Super:Edit( K_ENTER )
      // Super already advanced to new line
      ::lDirty := .T.
      ::aText[ ::nRow ]:cText = cSaved
      ::GoTo( ::nRow, 5 )
      ::Display()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD DeleteLine() CLASS HBSrcEdit

   if Len( ::aText ) > 1
      ::cClipboard = ::aText[ ::nRow ]:cText
      ::aText[ ::nRow ]:cText = ""
      ::nCol = 1
      if ::nRow < Len( ::aText )
         ::Super:Edit( K_DEL )
      endif
      ::lDirty := .T.
      ::GoTo( ::nRow, 5 )
      ::Display()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD DuplicateLine() CLASS HBSrcEdit

   local cSaved := ::aText[ ::nRow ]:cText

   // Go to end of current line, set nCol to text position for Super, split
   ::nCol = hb_ULen( ::aText[ ::nRow ]:cText ) + 1
   ::Super:Edit( K_ENTER )
   // Super already advanced to new line
   ::lDirty := .T.
   ::aText[ ::nRow ]:cText = cSaved
   ::GoTo( ::nRow, 5 )
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

   local nKeyStd := hb_keyStd( nKey )
   local cKey, oLine, nPos

   do case
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

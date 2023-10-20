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

   DATA   cFile        // no longer protected
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
      "FUNCTION,DO,CASE,OTHERWISE,ENDCASE,IF,ELSE,ENDIF,WHILE," + ;
      "FOR,NEXT,RETURN,CREATE,FROM,DATA,INIT,METHOD,INLINE,ENDCLASS,VIRTUAL" + ;
      "MENU,MENUITEM,PROMPT,IDENT,CHECKED,ACTION,SEPARATOR,ENDMENU" + ;
      "CLEAR,SCREEN"
   DATA   cKeywords2   INIT "STATIC,LOCAL,NIL,SELF,SUPER,#INCLUDE,#XCOMMAND" 

   METHOD Edit( nKey )
   METHOD Display()
   METHOD DisplayLine( nLine )
   METHOD LineColor( nLine ) INLINE ;
                     If( nLine == ::nRow - ::nFirstRow + ::nTop, ::cClrSelRow, ::cColorSpec )
   METHOD MoveCursor( nKey )
   METHOD ShowCursor() INLINE ( SetCursor( SC_NORMAL ), SetPos( ::nRow - ::nFirstRow + 2, ::nCol ) )   

ENDCLASS

//-----------------------------------------------------------------------------------------//

METHOD Edit( nKey ) CLASS HBSrcEdit

   local nKeyStd := hb_keyStd( nKey )

   do case 
      case nKey == K_LBUTTONDOWN
           ::GoTo( MRow() - ::nTop + ::nFirstRow, Max( MCol() - ::nLeft + ::nFirstCol, 5 ), _REFRESH_ALL )

      case nKey == K_MWBACKWARD
           ::Super:Edit( K_DOWN )

      case nKey == K_MWFORWARD
           ::Super:Edit( K_UP )

      case nKeyStd == K_BS
           IF ::nCol > 5
              ::lDirty := .T.
              ::aText[ ::nRow ]:cText := hb_UStuff( ::aText[ ::nRow ]:cText, --::nCol - 4, 1, "" )
              ::GoTo( ::nRow, ::nCol, _REFRESH_LINE )
           ENDIF

      case nKeyStd == K_ENTER
           ::Super:Edit( nKey )
           ::GoTo( ::nRow + 1, 5 )

      case ! HB_ISNULL( cKey := iif( nKeyStd == K_TAB .AND. Set( _SET_INSERT ), ;
           Space( TabCount( ::nTabWidth, ::nCol ) ), ;
           hb_keyChar( nKey ) ) )
      
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

   DispBegin()
   hb_DispOutAt( nLine, ::nLeft, PadL( ::nFirstRow + nLine - ::nTop, 4 ), "N/W" )
   hb_DispOutAt( nLine, ::nLeft + 4,;
                 SubStrPad( cLine := ::GetLine( ::nFirstRow + nLine - ::nTop ),;
                 ::nFirstCol, ::nRight - ::nLeft - 4 + 1 ),;
                 ::LineColor( nLine ) )   

   n = 1
   while n < Len( cLine )
      while SubStr( cLine, n, 1 ) == " " .and. n < Len( cLine )
         n++
      end
      do case
         case SubStr( cLine, n, 1 ) == '"'
             cToken += '"' 
             while SubStr( cLine, ++n, 1 ) != '"' .and. n <= Len( cLine )
                cToken += SubStr( cLine, n, 1 )
             end
             cToken += '"'
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

      do case
         case Left( cToken, 1 ) $ "0123456789" .and. ;
              Right( cToken, 1 ) $ "0123456789"
              cColor = ::cClrNumber
 
         case Left( cToken, 2 ) == "//"
              cColor = ::cClrComment

         case Left( cToken, 1 ) $ '"' + "'" 
              cColor = ::cClrString

         case Upper( cToken ) $ cOperators
              cColor = ::cClrOperator

         case Upper( cToken ) $ ::cKeywords1 .and. Len( cToken ) > 1 .and. ;
              ! Upper( cToken ) $ "AT" 
              cColor = ::cClrKeyword1

         case Upper( cToken ) $ ::cKeywords2 .and. Len( cToken ) > 1 .and. ;
              ! Upper( cToken ) $ "AT"
              cColor = ::cClrKeyword2

         otherwise
              cColor = SubStr( ::LineColor( nLine ), 1, At( "/", ::LineColor( nLine ) ) - 1 )
      endcase 

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
   end

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

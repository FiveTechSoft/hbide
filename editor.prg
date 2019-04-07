#include "hbclass.ch"
#include "inkey.ch"

//-----------------------------------------------------------------------------------------//

function BuildEditor()

   local oEditor := HBSrcEdit():New( MemoRead( "hbide.prg" ), 2, 1, MaxRow() - 2,;
                                     MaxCol() - 1, .T. ), nKey

   oEditor:SetColor( "W/B,N/BG" )

return oEditor   

//-----------------------------------------------------------------------------------------//

CREATE CLASS HBSrcEdit FROM HBEditor

   DATA   cClrString   INIT "GR+"
   DATA   cClrOperator INIT "R+" 
   DATA   cClrKeyword1 INIT "G+"
   DATA   cClrKeyword2 INIT "BG+"
   DATA   cClrSelRow   INIT "N/BG"
   DATA   cClrComment  INIT "RB+"
   DATA   cClrNumber   INIT "W+"
 
   DATA   cOperators   INIT "[{}],||[<>]<><=>=(),;.::=!=():),{})[]){}+=++---=*=/=%=^==$" + ;
                            "[{||,...>,>],"
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

ENDCLASS

//-----------------------------------------------------------------------------------------//

METHOD Edit( nKey ) CLASS HBSrcEdit

   ::Super:Edit( nKey )

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

   local n, cLine, cToken := "", cColor
   local cOperators := ::cOperators

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

       hb_DispOutAt( nLine, 4 + ::nLeft + n - Len( cToken ) - ::nFirstCol,;
                     SubStr( cToken, ::nLeft, Min( Len( cToken ) - ::nLeft + 1,;
                             ::nRight - ::nLeft - 4 ) ),;
                     cColor + SubStr( ::LineColor( nLine ),;
                     At( "/", ::LineColor( nLine ) ) ) )
      cToken = ""
   end

return Self

//-----------------------------------------------------------------------------------------//

static function SubStrPad( cText, nFrom, nLen )
   
return hb_UPadR( hb_USubStr( cText, nFrom, nLen ), nLen )

//-----------------------------------------------------------------------------------------//

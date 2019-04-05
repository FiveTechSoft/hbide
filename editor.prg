#include "hbclass.ch"
#include "inkey.ch"

//-----------------------------------------------------------------------------------------//

function Main()

   local oEditor := HBSrcEdit():New( MemoRead( "editor.prg" ), 0, 0, MaxRow(), MaxCol(), .T. )

   oEditor:SetColor( "W/B,N/BG" )
   oEditor:Display()
   
   while ( nKey := Inkey( 0 ) ) != K_ESC
      oEditor:Edit( nKey )
      oEditor:DisplayLine( oEditor:Row() - 1 )
      oEditor:DisplayLine( oEditor:Row() )
      oEditor:DisplayLine( oEditor:Row() + 1 )
   end

return nil   

//-----------------------------------------------------------------------------------------//

CREATE CLASS HBSrcEdit FROM HBEditor

   DATA   cClrString   INIT "GR+"
   DATA   cClrOperator INIT "R+" 
   DATA   cClrKeyword  INIT "G+"
   DATA   cClrSelRow   INIT "N/BG"
   DATA   cClrComment  INIT "RB+"
   DATA   cClrNumber   INIT "W+"
 
   DATA   cOperators   INIT "<><=>=(),;.::=!=():),{})[]){}+=++---=*=/=%=^=="
   DATA   cKeywords    INIT ;
      "FUNCTION,LOCAL,DO,CASE,OTHERWISE,ENDCASE,IF,ELSE,ENDIF,WHILE," + ;
      "FOR,NEXT,RETURN,CREATE,FROM,DATA,INIT,METHOD,ENDCLASS"

   METHOD Display()
   METHOD DisplayLine( nLine )
   METHOD LineColor( nLine ) INLINE If( nLine == ::nRow - ::nFirstRow, ::cClrSelRow, ::cColorSpec )

ENDCLASS

//-----------------------------------------------------------------------------------------//

METHOD Display() CLASS HBSrcEdit

   local nRow, nCount

   DispBegin()
   nRow = ::nTop
   nCount = ::nNumRows
   while --nCount >= 0
      ::DisplayLine( nRow++ )
   end
   DispEnd()

return Self

//-----------------------------------------------------------------------------------------//

METHOD DisplayLine( nLine ) CLASS HBSrcEdit

   local n, cLine, cToken := "", cColor
   local cOperators := ::cOperators

   hb_DispOutAt( nLine, ::nLeft,;
                 SubStrPad( cLine := ::GetLine( ::nFirstRow + nLine ),;
                 ::nFirstCol, ::nNumCols ), ::LineColor( nLine ) )   

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

         case Left( cToken, 1 ) == '"'
              cColor = ::cClrString

         case Upper( cToken ) $ cOperators
              cColor = ::cClrOperator

         case Upper( cToken ) $ ::cKeywords .and. Len( cToken ) > 1
              cColor = ::cClrKeyword

         otherwise
              cColor = SubStr( ::LineColor( nLine ), 1, At( "/", ::LineColor( nLine ) ) - 1 )
      endcase 

       hb_DispOutAt( nLine, n - Len( cToken ) - ::nFirstCol, cToken,;
                     cColor + SubStr( ::LineColor( nLine ),;
                     At( "/", ::LineColor( nLine ) ) ) ) 

      cToken = ""
   end

return Self

//-----------------------------------------------------------------------------------------//

static function SubStrPad( cText, nFrom, nLen )
   
return hb_UPadR( hb_USubStr( cText, nFrom, nLen ), nLen )

//-----------------------------------------------------------------------------------------//

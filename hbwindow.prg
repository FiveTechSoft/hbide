#include "hbclass.ch"
#include "inkey.ch"

//-----------------------------------------------------------------------------------------//

CLASS HbWindow FROM HbDbWindow

   DATA   bInit
   DATA   nIdle     // allows mouse support in READ

   METHOD LoadColors()

   METHOD New( nTop, nLeft, nBottom, nRight, cCaption, cColor )

   METHOD nHeight() INLINE ::nBottom - ::nTop + 1   

   METHOD SayCenter( cMsg, nRow )                         

   METHOD Show( lFocused )

   METHOD Dialog( cCaption, nWidth, nHeight, cColor, bInit ) 
      
   METHOD Hide()   

ENDCLASS

//-----------------------------------------------------------------------------------------//

METHOD New( nTop, nLeft, nBottom, nRight, cCaption, cColor ) CLASS HBWindow

   ::nTop     = nTop
   ::nLeft    = nLeft
   ::nBottom  = nBottom
   ::nRight   = nRight
   ::cCaption = cCaption
   ::cColor   = hb_defaultValue( cColor, GetColors()[ 1 ] )

return Self

//-----------------------------------------------------------------------------------------//

METHOD LoadColors() CLASS HbWindow

   local aClr := GetColors()

   ::cColor := aClr[ 1 ]

   if ::Browser != nil
      ::Browser:ColorSpec = aClr[ 2 ] + "," + aClr[ 5 ] + "," + aClr[ 3 ] + "," + aClr[ 6 ]
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD SayCenter( cMsg, nRow ) CLASS HbWindow

   nRow = hb_DefaultValue( nRow, 0 )

   hb_DispOutAt( ::nTop - 1 + nRow + ( ::nHeight() / 2 ),;
   ::nLeft - 1 + Int( ::nWidth() / 2 ) - Int( Len( cMsg ) / 2 ), cMsg,;
   GetColors()[ 8 ] ) 

return nil

//-----------------------------------------------------------------------------------------//

METHOD Show( lFocused ) CLASS HbWindow

   ::Super:Show( lFocused )

   if ! Empty( ::bInit )
      Eval( ::bInit, Self )
   endif   

   ::nIdle = hb_IdleAdd( { || If( MRow() == ::nTop .and. MCol() == ::nLeft + 2 .and. MLeftDown(),;
                            ReadKill( .T. ),) } )
return nil   

//-----------------------------------------------------------------------------------------//

METHOD Hide() CLASS HbWindow 

   ::Super:Hide()

   if ::nIdle != nil
      hb_IdleDel( ::nIdle )
      ::nIdle = nil
   endif
   
return nil   

//-----------------------------------------------------------------------------------------//

METHOD Dialog( cCaption, nWidth, nHeight, cColor, bInit ) CLASS HbWindow
   
   local nTop    := Int( ( MaxRow() / 2 ) - ( nHeight / 2 ) )
   local nLeft   := Int( ( MaxCol() / 2 ) - ( nWidth / 2 ) )
   local nBottom := Int( ( MaxRow() / 2 ) + ( nHeight / 2 ) )  
   local nRight  := Int( ( MaxCol() / 2 ) + ( nWidth / 2 ) )

   ::New( nTop, nLeft, nBottom, nRight, cCaption, cColor )
   ::bInit   = bInit
   ::lShadow = .T.

return Self

//-----------------------------------------------------------------------------------------//

static function GetColors()

return { "W+/BG", "N/BG", "R/BG", "N+/BG", "W+/B", "GR+/B", "W/B", "N/W", "R/W", "N/BG", "R/BG" }

//-----------------------------------------------------------------------------------------//
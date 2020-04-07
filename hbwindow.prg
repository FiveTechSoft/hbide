#include "hbclass.ch"
#include "inkey.ch"

//-----------------------------------------------------------------------------------------//

CLASS HbWindow FROM HbDbWindow

   DATA   bInit

   METHOD LoadColors()

   METHOD New( nTop, nLeft, nBottom, nRight, cCaption, cColor )

   METHOD nHeight() INLINE ::nBottom - ::nTop + 1   

   METHOD SayCenter( cMsg, nRow )                         

   METHOD Show( lFocused )

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
   ::nLeft + ( ::nWidth() / 2 ) - Len( cMsg ) / 2, cMsg,;
   GetColors()[ 8 ] ) 

return nil

//-----------------------------------------------------------------------------------------//

METHOD Show( lFocused ) CLASS HbWindow

   ::Super:Show( lFocused )

   if ! Empty( ::bInit )
      Eval( ::bInit, Self )
   endif   

return nil   

//-----------------------------------------------------------------------------------------//

static function GetColors()

return { "W+/BG", "N/BG", "R/BG", "N+/BG", "W+/B", "GR+/B", "W/B", "N/W", "R/W", "N/BG", "R/BG" }

//-----------------------------------------------------------------------------------------//
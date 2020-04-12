#include "hbclass.ch"
#include "inkey.ch"
#include "box.ch"
#include "setcurs.ch"

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

   METHOD MouseEvent( nMRow, nMCol )   

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

METHOD MouseEvent( nMRow, nMCol ) CLASS HbWindow

   local cPrevColor, cImage, cBackImage, nHeight, nWidth
   local nPrevCursor := SetCursor( SC_NONE )

   do case
      case nMRow == ::nTop .and. nMCol == ::nLeft + 2 .and. MLeftDown() // close button
           ReadKill( .T. )

      case MLeftDown() .and. ;
           ( ( nMRow == ::nTop .or. nMRow == ::nBottom ) .and. nMCol >= ::nLeft .and. nMCol <= ::nRight ) .or. ;
           ( ( nMCol == ::nLeft .or. nMCol == ::nRight ) .and. nMRow >= ::nTop .and. nMRow <= ::nBottom ) // border
           cBackImage = ::cBackImage
           cPrevColor = ::cColor
           nHeight = ::nBottom - ::nTop + 1
           nWidth  = ::nRight - ::nLeft + 1
           ::cColor = "G+/W" 
           ::Refresh()
           cImage = SaveScreen( ::nTop, ::nLeft, ::nBottom, ::nRight )
           while MLeftDown()
              if MRow() != ::nTop
                 DispBegin()
                 __dbgRestScreen( ::nTop, ::nLeft, ::nBottom + 1, ::nRight + 2, cBackImage )
                 ::nTop  = MRow()
                 ::nLeft = MCol()
                 ::nBottom = ::nTop + nHeight - 1
                 ::nRight = ::nLeft + nWidth - 1
                 cBackImage = __dbgSaveScreen( ::nTop, ::nLeft, ::nBottom + 1, ::nRight + 2 )
                 RestScreen( ::nTop, ::nLeft, ::nBottom, ::nRight, cImage )
                 hb_Shadow( ::nTop, ::nLeft, ::nBottom, ::nRight )
                 DispEnd()
              endif    
           end 
           ::cBackImage = cBackImage
           ::cColor = cPrevColor
           ::Refresh()
           hb_Shadow( ::nTop, ::nLeft, ::nBottom, ::nRight )
           SetCursor( nPrevCursor )

      otherwise
         ::Refresh()   
      
   endcase

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

   ::nIdle = hb_IdleAdd( { || ::MouseEvent( MRow(), MCol() ) } )

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
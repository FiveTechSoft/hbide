#include "hbclass.ch"
#include "inkey.ch"
#include "box.ch"
#include "setcurs.ch"
#include "hbmenu.ch"

//-----------------------------------------------------------------------------------------//

CLASS HbWindow FROM HbDbWindow

   DATA   bInit
   DATA   nIdle     // allows mouse support in READ
   DATA   GetList
   DATA   lDesign INIT .F.

   METHOD Activate( GetList )

   METHOD End() INLINE ReadKill( .T. )

   METHOD LoadColors()

   METHOD New( nTop, nLeft, nBottom, nRight, cCaption, cColor )

   METHOD nHeight() INLINE ::nBottom - ::nTop + 1   

   METHOD Say( nRow, nCol, cLine )

   METHOD SayCenter( cMsg, nRow )                         

   METHOD Show( lFocused )

   METHOD Dialog( cCaption, nWidth, nHeight, cColor, bInit ) 
      
   METHOD Hide()   

   METHOD MouseEvent( nMRow, nMCol )   

   METHOD MoveControls()   

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

METHOD Activate( GetList ) CLASS HbWindow 

   ::GetList = GetList 
   READ
   ::Hide() 

return nil   

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
   local nCurRow := Row(), nCurCol := Col(), nPrevCursor := SetCursor( SC_NONE )
   local nOldRow, nOldCol, nOldBottom, nOldRight, oCtrl, oPopup, oMenuItem

   do case
      case nMRow == ::nTop .and. nMCol == ::nLeft + 2 .and. MLeftDown() // close button
         ReadKill( .T. )

      case MRightDown()
         hb_idleDel( ::nIdle )
         
         MENU oPopup POPUP 
            MENUITEM "~Add item" ACTION Alert( "add item" )
            SEPARATOR
            MENUITEM "~Generate code..." ACTION Alert( "code" )
         ENDMENU   

         ATail( oPopup:aItems ):bAction = { || Alert( "code" ) }

         ACTIVATE MENU oPopup

         ::nIdle = hb_IdleAdd( { || ::MouseEvent( MRow(), MCol() ) } )

      case ::lDesign .and. MLeftDown() .and. nMRow == ::nBottom .and. nMCol == ::nRight
         while MLeftDown()
            if MRow() != ::nBottom .or. MCol() != ::nRight
               DispBegin()
               ::Hide()
               ::nBottom = MRow()
               ::nRight = MCol()
               ::Show( .T. )
               if ! Empty( ::GetList )
                  for each oCtrl in ::GetList
                     oCtrl:Control:Display()
                  next 
               endif      
               hb_Shadow( ::nTop, ::nLeft, ::nBottom, ::nRight )
               DispEnd()
            endif    
         end 

      case MLeftDown() .and. ;
           ( ( ( nMRow == ::nTop .or. nMRow == ::nBottom ) .and. nMCol >= ::nLeft .and. nMCol <= ::nRight ) .or. ;
             ( ( nMCol == ::nLeft .or. nMCol == ::nRight ) .and. nMRow >= ::nTop .and. nMRow <= ::nBottom ) )
           nOldTop    = ::nTop
           nOldLeft   = ::nLeft
           nOldBottom = ::nBottom
           nOldRight  = ::nRight
           cBackImage = ::cBackImage
           cPrevColor = ::cColor
           nHeight = ::nBottom - ::nTop + 1
           nWidth  = ::nRight - ::nLeft + 1
           ::cColor = "G+/W" 
           ::Refresh()
           cImage = __dbgSaveScreen( ::nTop, ::nLeft, ::nBottom, ::nRight )
           if MRow() != ::nTop .or. MRow() != ::nBottom
              nMRow = MRow() - ::nTop
           else
              nMRow = 0
           endif      
           if MCol() != ::nLeft .or. MCol() != ::nRight
              nMCol = MCol() - ::nLeft
           else
              nMCol = 0
           endif      
           while MLeftDown()
              if MRow() != ::nTop .or. MCol() != ::nLeft .or. MCol() != ::nRight
                 DispBegin()
                 __dbgRestScreen( ::nTop, ::nLeft, ::nBottom + 1, ::nRight + 2, cBackImage )
                 ::nTop  = MRow() - nMRow
                 ::nLeft = MCol() - nMCol
                 ::nBottom = ::nTop + nHeight - 1
                 ::nRight = ::nLeft + nWidth - 1
                 cBackImage = __dbgSaveScreen( ::nTop, ::nLeft, ::nBottom + 1, ::nRight + 2 )
                 RestBlock( ::nTop, ::nLeft, ::nBottom, ::nRight, cImage )
                 hb_Shadow( ::nTop, ::nLeft, ::nBottom, ::nRight )
                 DispEnd()
              endif    
           end 
           ::cBackImage = cBackImage
           ::cColor = cPrevColor
           ::Refresh()
           hb_Shadow( ::nTop, ::nLeft, ::nBottom, ::nRight )
           ::MoveControls( nOldTop, nOldLeft, nOldBottom, nOldRight ) 
           SetCursor( nPrevCursor )
           SetPos( nCurRow - nOldTop + ::nTop, nCurCol - nOldLeft + ::nLeft )

      otherwise
         ::Refresh()   
      
   endcase

return nil

//-----------------------------------------------------------------------------------------//

function RestBlock( nTop, nLeft, nBottom, nRight, cImage )

   local nImgHeight   := nBottom - nTop + 1
   local nImgWidth    := nRight - nLeft + 1
   local nBlockWidth  := Min( nImgWidth, Min( nRight, MaxCol() ) - Max( nLeft, 0 ) + 1 )
   local nBlockHeight := Min( nImgHeight, MaxRow() - nTop + 1 )
   local cResult := "", n, cLine

   for n = 1 to nBlockHeight
      cLine = SubStr( cImage, 1 + ( ( n - 1 ) * ( nImgWidth * 4 ) ), nImgWidth * 4 )
      if nLeft < 0
         cResult += SubStr( cLine, 1 - ( nLeft * 4 ), nBlockWidth * 4 )
      elseif nRight > MaxCol()
         cResult += SubStr( cLine, 1, nBlockWidth * 4 )
      else
         cResult += cLine   
      endif   
   next

   __dbgRestScreen( Min( nTop, MaxRow() ), Max( nLeft, 0 ),;
                   Min( nBottom, MaxRow() ), Min( nRight, MaxCol() ),;
                   cResult )  

return nil

//-----------------------------------------------------------------------------------------//

METHOD MoveControls( nOldTop, nOldLeft, nOldBottom, nOldRight ) CLASS HbWindow 

   local oCtrl

   if ! Empty( ::GetList )
      for each oCtrl in ::GetList
         oCtrl:row += ( ::nTop - nOldTop )
         oCtrl:col += ( ::nLeft - nOldLeft )
         if ! Empty( oCtrl:Caption )
            oCtrl:CapRow += ( ::nTop - nOldTop )
            oCtrl:CapCol += ( ::nLeft - nOldLeft )
         endif
         if ! Empty( oCtrl:Control )
            if oCtrl:Control:IsKindOf( "PUSHBUTTON" )
               oCtrl:Control:row += ( ::nTop - nOldTop )
               oCtrl:Control:col += ( ::nLeft - nOldLeft )
            endif   
            if oCtrl:Control:IsKindOf( "LISTBOX" ) 
               oCtrl:Control:top    += ( ::nTop - nOldTop )
               oCtrl:Control:left   += ( ::nLeft - nOldLeft )
               oCtrl:Control:bottom += ( ::nBottom - nOldBottom )
               oCtrl:Control:right  += ( ::nRight - nOldRight )
               oCtrl:Control:CapRow += ( ::nTop - nOldTop )
               oCtrl:Control:CapCol += ( ::nLeft - nOldLeft )
            endif
         endif
      next 
   endif
   
return nil   

//-----------------------------------------------------------------------------------------//

METHOD Say( nRow, nCol, cLine ) CLASS HbWindow

   hb_DispOutAt( ::nTop + nRow, ::nLeft + nCol, cLine, GetColors()[ 8 ] ) 

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

   lFocused = hb_DefaultValue( lFocused, .T. )

   ::Super:Show( lFocused )

   if ! Empty( ::bInit )
      Eval( ::bInit, Self )
   endif   

   if lFocused
      ::nIdle = hb_IdleAdd( { || ::MouseEvent( MRow(), MCol() ) } )
   endif   

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
   ::Show()

return Self

//-----------------------------------------------------------------------------------------//

static function GetColors()

return { "W+/BG", "N/BG", "R/BG", "N+/BG", "W+/B", "GR+/B", "W/B", "N/W", "R/W", "N/BG", "R/BG" }

//-----------------------------------------------------------------------------------------//
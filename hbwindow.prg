#include "hbclass.ch"
#include "inkey.ch"
#include "box.ch"
#include "setcurs.ch"
#include "hbmenu.ch"

//-----------------------------------------------------------------------------------------//

CLASS HbWindow FROM HbDbWindow

   DATA   bInit
   DATA   bRepaint       // callback to repaint background behind this window
   DATA   cVirtImage     // virtual window image (full size, even when partially off-screen)
   DATA   lRedrawPending INIT .F.
   DATA   nIdle          // allows mouse support in READ
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
         if ::lDesign .and. MRow() > ::nTop .and. MRow() < ::nBottom .and. ;
            MCol() > ::nLeft .and. MCol() < ::nRight
            hb_idleDel( ::nIdle )

            MENU oPopup POPUP
               MENUITEM "~Add item" ACTION Alert( "add item" )
               SEPARATOR
               MENUITEM "~Generate code..." ACTION Alert( "code" )
            ENDMENU

            ATail( oPopup:aItems ):bAction = { || Alert( "code" ) }

            ACTIVATE MENU oPopup

            ::nIdle = hb_IdleAdd( { || ::MouseEvent( MRow(), MCol() ) } )
         endif

      case ::lDesign .and. MLeftDown() .and. nMRow == ::nBottom .and. nMCol == ::nRight
         while MLeftDown()
            if MRow() != ::nBottom .or. MCol() != ::nRight
               DispBegin()
               if ::bRepaint != nil
                  Eval( ::bRepaint )
               else
                  ::Hide()
               endif
               ::nBottom = MRow()
               ::nRight = MCol()
               ::Show( .T. )
               if ! Empty( ::GetList )
                  for each oCtrl in ::GetList
                     oCtrl:Control:Display()
                  next
               endif
               DrawShadow( ::nTop, ::nLeft, ::nBottom, ::nRight )
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
           if ::nTop >= 0 .and. ::nLeft >= 0 .and. ;
              ::nBottom <= MaxRow() .and. ::nRight <= MaxCol()
              ::cVirtImage = __dbgSaveScreen( ::nTop, ::nLeft, ::nBottom, ::nRight )
           endif
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
                 if ::bRepaint != nil
                    Eval( ::bRepaint )
                 else
                    __dbgRestScreen( ::nTop, ::nLeft, ::nBottom + 1, ::nRight + 2, cBackImage )
                 endif
                 ::nTop  = MRow() - nMRow
                 ::nLeft = MCol() - nMCol
                 ::nBottom = ::nTop + nHeight - 1
                 ::nRight = ::nLeft + nWidth - 1
                 if ::bRepaint == nil
                    cBackImage = __dbgSaveScreen( ::nTop, ::nLeft, ::nBottom + 1, ::nRight + 2 )
                 endif
                 RestBlock( ::nTop, ::nLeft, ::nBottom, ::nRight, cImage )
                 DrawShadow( ::nTop, ::nLeft, ::nBottom, ::nRight )
                 DispEnd()
              endif
           end
           ::cColor = "W/W"
           ::Refresh()
           ::cColor = cPrevColor
           ::MoveControls( nOldTop, nOldLeft, nOldBottom, nOldRight )
           nCurRow = nCurRow - nOldTop + ::nTop
           nCurCol = nCurCol - nOldLeft + ::nLeft
           if ::bRepaint != nil
              DispBegin()
              Eval( ::bRepaint )
              RestBlock( ::nTop, ::nLeft, ::nBottom, ::nRight, ::cVirtImage )
              DrawShadow( ::nTop, ::nLeft, ::nBottom, ::nRight )
              if nCurRow >= 0 .and. nCurRow <= MaxRow() .and. ;
                 nCurCol >= 0 .and. nCurCol <= MaxCol()
                 SetCursor( nPrevCursor )
                 SetPos( nCurRow, nCurCol )
              else
                 SetCursor( SC_NONE )
              endif
              DispEnd()
              if ::nTop >= 0 .and. ::nLeft >= 0 .and. ;
                 ::nBottom <= MaxRow() .and. ::nRight <= MaxCol()
                 ::cVirtImage = __dbgSaveScreen( ::nTop, ::nLeft, ::nBottom, ::nRight )
              endif
           else
              ::cBackImage = cBackImage
              ::Refresh()
              DrawShadow( ::nTop, ::nLeft, ::nBottom, ::nRight )
              if nCurRow >= 0 .and. nCurRow <= MaxRow() .and. ;
                 nCurCol >= 0 .and. nCurCol <= MaxCol()
                 SetCursor( nPrevCursor )
                 SetPos( nCurRow, nCurCol )
              else
                 SetCursor( SC_NONE )
              endif
           endif

      otherwise
         if ::nTop >= 0 .and. ::nLeft >= 0 .and. ;
            ::nBottom <= MaxRow() .and. ::nRight <= MaxCol()
            ::Refresh()
         endif

   endcase

return nil

//-----------------------------------------------------------------------------------------//

function RestBlock( nTop, nLeft, nBottom, nRight, cImage )

   local nImgHeight   := nBottom - nTop + 1
   local nImgWidth    := nRight - nLeft + 1
   local nBlockWidth  := Min( nImgWidth, Min( nRight, MaxCol() ) - Max( nLeft, 0 ) + 1 )
   local nBlockHeight := Min( nImgHeight, Min( nBottom, MaxRow() ) - Max( nTop, 0 ) + 1 )
   local cResult := "", n, nFirstRow, cLine

   if nBlockWidth <= 0 .or. nBlockHeight <= 0
      return nil
   endif

   nFirstRow = If( nTop < 0, -nTop + 1, 1 )

   for n = nFirstRow to nFirstRow + nBlockHeight - 1
      cLine = SubStr( cImage, 1 + ( ( n - 1 ) * ( nImgWidth * 4 ) ), nImgWidth * 4 )
      if nLeft < 0
         cResult += SubStr( cLine, 1 - ( nLeft * 4 ), nBlockWidth * 4 )
      elseif nRight > MaxCol()
         cResult += SubStr( cLine, 1, nBlockWidth * 4 )
      else
         cResult += cLine
      endif
   next

   __dbgRestScreen( Max( nTop, 0 ), Max( nLeft, 0 ),;
                   Min( nBottom, MaxRow() ), Min( nRight, MaxCol() ),;
                   cResult )

return nil

//-----------------------------------------------------------------------------------------//

// Draws shadow parts independently:
// - Right shadow only if right edge + 2 cols fits on screen
// - Bottom shadow only if bottom edge + 1 row fits on screen
// hb_Shadow draws: bottom row at nBottom+1 (from nLeft+2 to nRight+2)
//                  right cols at nRight+1..nRight+2 (from nTop+1 to nBottom+1)
// We simulate partial shadow by calling hb_Shadow with clipped rectangles

static function DrawShadow( nTop, nLeft, nBottom, nRight )

   local lBottomVisible := ( nBottom + 1 <= MaxRow() )
   local lRightVisible  := ( nRight + 2 <= MaxCol() )

   if lBottomVisible .and. lRightVisible
      // Both visible, draw normally
      hb_Shadow( Max( nTop, 0 ), Max( nLeft, 0 ), nBottom, nRight )

   elseif lRightVisible
      // Only right shadow: draw shadow for a thin rectangle so only right cols appear
      // hb_Shadow draws right edge at nRight+1..nRight+2, from nTop+1 to nBottom+1
      // Use nBottom clamped to MaxRow()-1 so the right edge rows stay on screen
      hb_Shadow( Max( nTop, 0 ), nRight, Min( nBottom, MaxRow() - 1 ), nRight )

   elseif lBottomVisible
      // Only bottom shadow: draw shadow for a thin rectangle so only bottom row appears
      // hb_Shadow draws bottom edge at nBottom+1, from nLeft+2 to nRight+2
      // Use nRight clamped to MaxCol()-2 so the bottom edge cols stay on screen
      hb_Shadow( nBottom, Max( nLeft, 0 ), nBottom, Min( nRight, MaxCol() - 2 ) )

   endif

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

   if ::bRepaint != nil
      Eval( ::bRepaint )
      ::lVisible = .F.
   else
      ::Super:Hide()
   endif

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

static function DrawBorder( nTop, nLeft, nBottom, nRight, cColor )

   local cBox := hb_UTF8ToStrBox( "┌─┐│┘─└│" )

   hb_DispBox( nTop, nLeft, nBottom, nRight, cBox, cColor )

return nil

//-----------------------------------------------------------------------------------------//


#include "hbclass.ch"
#include "inkey.ch"
#include "box.ch"
#include "setcurs.ch"
#include "hbmenu.ch"
#include "button.ch"
#include "set.ch"

// raw gttrm mouse event codes (measured: Inkey EXT delivers 0x44000000+code)
#define DSNK_MLDOWN  1002
#define DSNK_MLUP    1003
#define DSNK_MLDBL   1006

static s_aTrapStack := {}  // saved PgDn/PgUp handlers per armed READ level (nesting-safe)

//-----------------------------------------------------------------------------------------//

static function ScrCharCode( nR, nC )
   // screen byte at (nR,nC); SaveScreen returns char+attr pairs
   return Asc( SaveScreen( nR, nC, nR, nC ) )

static function ScrAttrCode( nR, nC )
   return Asc( SubStr( SaveScreen( nR, nC, nR, nC ), 3, 1 ) )

CLASS HbWindow FROM HbDbWindow

   DATA   bInit
   DATA   bPopup        // design mode: right-click popup callback
   DATA   bRepaint       // callback to repaint background behind this window
   DATA   cVirtImage     // virtual window image (full size, even when partially off-screen)
   DATA   lRedrawPending INIT .F.
   DATA   nIdle          // allows mouse support in READ
   DATA   nIdleRead      // idle hook that feeds mouse clicks into READ
   DATA   nMinW          // min width when resizing with the mouse (frame incl.)
   DATA   nMinH          // min height when resizing with the mouse (frame incl.)
   DATA   nMaxBottom     // lowest row the window may occupy (NIL = MaxRow())
   DATA   bAfterDrag    // block evaluated after a mouse drag/resize ends (designer hook restore)
   DATA   nMaxRight      // rightmost col the window may occupy (NIL = MaxCol())
   DATA   oArmGet        // GET armed by a mouse DOWN (route mode)
   DATA   lSkipUp        // swallow the UP after a double-click event
   DATA   nPendRow, nPendCol, nPendAt  // queued mouse click while READ is busy
   DATA   lReadMouse INIT .F.  // left button state seen by the idle hook
   DATA   GetList
   DATA   lDesign INIT .F.
   DATA   lClamped INIT .F.   // .T. when Dialog() had to move/cut the window to fit the screen
   DATA   nReqWidth INIT 0     // size requested in Dialog(), before any clamp
   DATA   nReqHeight INIT 0

   METHOD Activate( GetList )

   METHOD ReadMouse()        // polls the mouse while READ waits
   METHOD MouseClick( nR, nC )  // focuses/activates the clicked GET
   METHOD HitGetAt( nR, nC )    // { oGet, nBottomFrame } under a screen point
   METHOD FocusGet( oGet )      // keyboard-driven focus, no activation
   METHOD DsnMouseRoute( nKey, oWnd, oGet )  // synchronous reader mouse route

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
   ::nMinW    = 6
   ::nMinH    = 3
   ::oArmGet  = nil
   ::lSkipUp  = .F.

return Self

//-----------------------------------------------------------------------------------------//

METHOD Activate( GetList ) CLASS HbWindow

   local bPrevRoute, lRoute := hb_GetEnv( "DSN_NOROUTE" ) != "1"

   DsnGetUInstall()
   ::GetList  = GetList
   ::oArmGet := nil
   ::lSkipUp := .F.
   ::nPendRow := nil
   if lRoute
      // reader route mode: mouse events arrive synchronously inside the
      // READ; the MLeftDown() polling hook would double-process clicks
      bPrevRoute := SetGetUMouseRoute( { | nK, oG | ::DsnMouseRoute( nK, Self, oG ) } )
   else
      ::lReadMouse := MLeftDown()
      ::nIdleRead = hb_IdleAdd( { || ::ReadMouse() } )
   endif
   HBPageTrapInstall()
   // host IDE (when linked) counts open modals so its idle painter and the
   // locale notice stay off the dialog; ALWAYS keeps the count right on a Break
   if hb_IsFunction( "HBIDE_MODAL" )
      Do( "HBIDE_MODAL", 1 )
   endif
   BEGIN SEQUENCE
      READ
   ALWAYS
      if hb_IsFunction( "HBIDE_MODAL" )
         Do( "HBIDE_MODAL", -1 )
      endif
   END SEQUENCE
   HBPageTrapRemove()
   if lRoute
      SetGetUMouseRoute( bPrevRoute )
   endif
   if ::nIdleRead != nil
      hb_IdleDel( ::nIdleRead )
      ::nIdleRead := nil
   endif
   ::Hide()

return nil

//-----------------------------------------------------------------------------------------//

// Polls the left mouse button while READ waits and turns a click
// (press followed by release) into a focus/activation request.

METHOD ReadMouse() CLASS HbWindow

   local lNow := MLeftDown()

   if lNow .and. ! ::lReadMouse
   endif
   if ::lReadMouse .and. ! lNow
      // click released: queue it; the READ may be busy navigating
      ::lReadMouse := .F.
      ::nPendRow := MRow()
      ::nPendCol := MCol()
      ::nPendAt  := Seconds()
   endif
   ::lReadMouse := lNow
   if ::nPendRow != nil
      // MouseClick returns .F. only while the READ is between GETs; retry
      // briefly, then drop the click
      if ::MouseClick( ::nPendRow, ::nPendCol ) .or. Seconds() - ::nPendAt > 3
         ::nPendRow := nil
      endif
   endif

return nil

//-----------------------------------------------------------------------------------------//

// Focuses the GET under the click and, for pushbuttons and checkboxes,
// also activates it. Focus is moved through the reader itself: Ctrl+Home
// goes to the first GET and Tab advances, so the READ state stays
// consistent. Returns .T. when a GET was hit.

// Mouse button edge from the InKey event stream (armed in Activate via
// SetKey under a widened _SET_EVENTMASK): race-free alternative to the
// ReadMouse() polling, which can miss press/release pairs shorter than
// its poll cycle. Both paths guard on ::lReadMouse, so the first edge
// seen wins and no click is queued twice.

METHOD MouseEdge( lDown ) CLASS HbWindow

   if lDown
      ::lReadMouse := .T.
   elseif ::lReadMouse
      ::lReadMouse := .F.
      ::nPendRow := MRow()
      ::nPendCol := MCol()
      ::nPendAt  := Seconds()
   endif

return nil

//-----------------------------------------------------------------------------------------//

// Hit-tests a screen point against the GETs of ::GetList.
// Returns { oHit, nHitBot }: the GET under ( nR, nC ) (NIL when none) and
// the bottom frame row for framed controls.

METHOD HitGetAt( nR, nC ) CLASS HBWindow

   local oGet, oHit := nil, cCls := "", nHitRow := -999, nHitCol := -999
   local nRight, nBottom, nHitBot := -1

   for each oGet in ::GetList
      cCls := If( Empty( oGet:control ), "", Upper( oGet:control:className() ) )
      do case
         case cCls == "LISTBOX" .or. cCls == "RADIOGROUP"
            // framed multi-row controls: recover the frame extents from the
            // screen border characters (control internals are protected);
            // items live one row inside the frame, so the frame rows miss
            // border bytes differ by codepage: CP437 (196/179/191/192) or
            // UTF-16 low bytes under UTF-8 terminals (0/2/16/20)
            nRight := oGet:col + 1
            do while nRight < MaxCol() - 1 .and. AScan( { 196, 205, 0, 80 }, ScrCharCode( oGet:row, nRight ) ) > 0
               nRight++
            enddo
            nBottom := oGet:row + 1
            do while nBottom < MaxRow() - 1 .and. AScan( { 179, 186, 2, 81 }, ScrCharCode( nBottom, oGet:col ) ) > 0
               nBottom++
            enddo
            if cCls == "LISTBOX"
            endif
            if AScan( { 191, 187, 16, 87 }, ScrCharCode( oGet:row, nRight ) ) > 0 .and. ;
               AScan( { 192, 200, 20, 90 }, ScrCharCode( nBottom, oGet:col ) ) > 0 .and. ;
               nR > oGet:row .and. nR < nBottom .and. nC > oGet:col .and. ;
               ( nC < nRight .or. ( cCls == "LISTBOX" .and. oGet:control:vScroll != NIL .and. nC == nRight ) ) .and. ;
               ( oGet:row > nHitRow .or. ( oGet:row == nHitRow .and. oGet:col > nHitCol ) )
               oHit    := oGet
               nHitRow := oGet:row
               nHitCol := oGet:col
               nHitBot := nBottom
            endif
         otherwise
            // single-row controls (plain GET, CHECKBOX, PUSHBUTTON, radio item);
            // a pushbutton also owns its 3D shadow row just below
            if ( nR == oGet:row .or. ( cCls == "PUSHBUTTON" .and. nR == oGet:row + 1 ) ) .and. ;
               nC >= oGet:col .and. nC <= oGet:col + If( oGet:buffer != nil, Len( oGet:buffer ), 30 ) .and. ;
               ( oGet:row > nHitRow .or. ( oGet:row == nHitRow .and. oGet:col > nHitCol ) )
               oHit := oGet
               nHitRow := oGet:row
               nHitCol := oGet:col
            endif
      endcase
   next

return { oHit, nHitBot }

METHOD MouseClick( nR, nC ) CLASS HbWindow

   local oGet, oHit := nil, cCls := "", nHitRow := -999, nHitCol := -999, nHit2 := 0
   local nCur, nTgt, cKeys, nIdx, nCurV, nRight, nBottom, nHitBot := -1, nJ, nK, cK, nI2, cLine, nIdx2
   local aHitScan

   if Empty( ::GetList ) .or. GetActive() == nil
      return .F.  // READ busy between GETs: caller retries
   endif

   aHitScan := ::HitGetAt( nR, nC )
   oHit    := aHitScan[ 1 ]
   nHitBot := aHitScan[ 2 ]

   if oHit == nil
      return .T.  // click outside any control: handled, nothing to do
   endif

   nCur := AScan( ::GetList, { | g | g == GetActive() } )
   nTgt := AScan( ::GetList, { | g | g == oHit } )
   if nCur == 0 .or. nTgt == 0
      return .F.
   endif

   // go to the first GET, then Tab forward to the target; moving past the
   // last GET would end the READ, so never wrap around
   cKeys := Chr( K_CTRL_HOME ) + Replicate( Chr( K_TAB ), nTgt - 1 )
   cCls := If( Empty( oHit:control ), "", Upper( oHit:control:className() ) )
   do case
      case cCls == "PUSHBUTTON"
         cKeys += Chr( K_ENTER )
      case cCls == "CHECKBOX"
         cKeys += Chr( K_SPACE )
      case cCls == "LISTBOX" .or. cCls == "RADIOGROUP"
         // select the clicked item; items start one row below the frame top
         if cCls == "LISTBOX" .and. oHit:control:vScroll != NIL
            nHit2 := oHit:control:vScroll:hitTest( nR, nC )
            do case
            case nHit2 == HTSCROLLUNITDEC ; cKeys += Chr( K_UP )
            case nHit2 == HTSCROLLUNITINC ; cKeys += Chr( K_DOWN )
            case nHit2 == HTSCROLLBLOCKDEC ; cKeys += Chr( K_PGUP )
            case nHit2 == HTSCROLLBLOCKINC ; cKeys += Chr( K_PGDN )
            endcase
            if nHit2 != 0
               __Keyboard( cKeys )
               return .T.
            endif
         endif
         nIdx := nR - oHit:row - 1
         if nIdx >= 0
            if cCls == "RADIOGROUP"
               // current selection from the "(*)" marker inside the frame
               nCurV := -1
               for nJ := oHit:row + 1 to nHitBot - 1
                  for nK := oHit:col + 1 to oHit:col + 5
                     if ScrCharCode( nJ, nK ) == 42  // '*' of the "(*)" marker
                        nCurV := nJ - oHit:row - 1
                        exit
                     endif
                  next
                  if nCurV >= 0
                     exit
                  endif
               next
            else
               // listbox: the clicked row is a VISIBLE offset; the absolute
               // item is the scroll offset (public topItem) plus that row.
               // The bar position is the GET variable, updated live by the
               // READ (the screen-attribute scan this replaces misread the
               // bar whenever only two item rows were visible, and the raw
               // row offset was wrong once the list was scrolled)
               nIdx += oHit:control:topItem
               nCurV := oHit:varGet()
               if ! HB_ISNUMERIC( nCurV )
                  nCurV := 1
               endif
               nIdx := Max( 1, Min( oHit:control:itemCount, nIdx ) )
            endif
            if nCurV >= 0 .and. nIdx != nCurV
               cKeys += Replicate( Chr( If( nIdx > nCurV, K_DOWN, K_UP ) ), Abs( nIdx - nCurV ) )
            endif
         endif
   endcase
   #ifdef MC_DEBUG
      cK := ""
      for nI2 := 1 to Len( cKeys )
         cK += hb_ntos( Asc( SubStr( cKeys, nI2, 1 ) ) ) + ","
      next
      cLine := "r=" + hb_ntos( nR ) + " c=" + hb_ntos( nC ) + " hit=" + cCls + " tgt=" + hb_ntos( nTgt ) + ;
               " cur=" + hb_ntos( nCur ) + " idx=" + hb_ValToStr( nIdx ) + " curv=" + hb_ValToStr( nCurV ) + ;
               " keys=" + cK + hb_eol()
      hb_MemoWrit( "/tmp/mc.log", If( File( "/tmp/mc.log" ), MemoRead( "/tmp/mc.log" ), "" ) + cLine )
   #endif
   __Keyboard( cKeys )

return .T.

//-----------------------------------------------------------------------------------------//

// Moves READ focus to oGet through the keyboard (Ctrl+Home then Tab), so
// READ navigation state stays consistent. No activation key is injected.

METHOD FocusGet( oGet ) CLASS HBWindow

   local nTgt := AScan( ::GetList, { | g | g == oGet } )
   local nTabs := nTgt - 1

   if nTgt > 0 .and. GetActive() != NIL .and. ! ( GetActive() == oGet )
      if hb_GetEnv( "DSN_FGTABS" ) != ""
         nTabs := Val( hb_GetEnv( "DSN_FGTABS" ) )
      endif
      __Keyboard( Chr( K_CTRL_HOME ) + Replicate( Chr( K_TAB ), nTabs ) )
   endif

return nil

//-----------------------------------------------------------------------------------------//

// Synchronous mouse route called from GetUReader (hbgetu.prg) while the
// READ waits on this window. Events arrive as 0x44000000+code; coordinates
// come from MRow()/MCol() at consume time.
// Semantics: DOWN arms the control under the pointer (and focuses it);
// UP activates only when it lands on the SAME armed control; a double
// click arrives as DOWN,UP,DBL,UP so the DBL flags the next UP to be
// swallowed: one activation per double click, never two.

METHOD DsnMouseRoute( nKey, oWnd, oGet ) CLASS HbWindow

   local nCode := hb_bitAnd( nKey, 0xFFFFFF )
   local aHit, oHit, cCls

   do case
   case nCode == DSNK_MLDOWN
      aHit := ::HitGetAt( MRow(), MCol() )
      ::oArmGet := aHit[ 1 ]
      ::lSkipUp := .F.
      cCls := If( ::oArmGet != nil .and. ! Empty( ::oArmGet:control ), ;
                  Upper( ::oArmGet:control:className() ), "-" )
      // no focus injection here: injecting keys while the paired UP event
      // is still in flight makes that UP vanish inside READ navigation
      // (measured 2026-10-24); focus/activation happen on the UP instead
   case nCode == DSNK_MLDBL
      // do NOT re-arm: the UP that follows must not activate again
      ::lSkipUp := .T.
   case nCode == DSNK_MLUP
      if ::lSkipUp
         ::lSkipUp := .F.
         ::oArmGet := nil
      elseif ::oArmGet == nil
      else
         aHit := ::HitGetAt( MRow(), MCol() )
         oHit := aHit[ 1 ]
         if oHit != NIL .and. oHit == ::oArmGet
            ::MouseClick( MRow(), MCol() )   // proven focus+activation path
         elseif oHit != NIL
            ::FocusGet( oHit )               // press-out release-in: focus, no activation
         else
         endif
         ::oArmGet := nil
      endif
   endcase

return .T.

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
            ::nIdle = nil

            if ::bPopup != nil
               Eval( ::bPopup )
            else
               MENU oPopup POPUP
                  MENUITEM "~Add item" ACTION Alert( "add item" )
                  SEPARATOR
                  MENUITEM "~Generate code..." ACTION Alert( "code" )
               ENDMENU

               ATail( oPopup:aItems ):bAction = { || Alert( "code" ) }

               ACTIVATE MENU oPopup
            endif

            if ::nIdle == nil
               ::nIdle = hb_IdleAdd( { || ::MouseEvent( MRow(), MCol() ) } )
            endif
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
               ::nBottom = Max( ::nTop + ::nMinH - 1, Min( MaxBtm( Self ), MRow() ) )
               ::nRight  = Max( ::nLeft + ::nMinW - 1, Min( MaxRgt( Self ), MCol() ) )
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
         if ::bRepaint != nil
            Eval( ::bRepaint )
         endif
         if ::bAfterDrag != nil
            Eval( ::bAfterDrag )
         endif

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
                 ::nTop    = Max( 0, Min( MaxBtm( Self ) - nHeight + 1, MRow() - nMRow ) )
                 ::nLeft   = Max( 0, Min( MaxRgt( Self ) - nWidth + 1, MCol() - nMCol ) )
                 ::nBottom = ::nTop + nHeight - 1
                 ::nRight  = ::nLeft + nWidth - 1
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
           if ::bAfterDrag != nil
              Eval( ::bAfterDrag )
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

function DrawShadow( nTop, nLeft, nBottom, nRight )

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

   local oCtrl, oItem, nDeltaRow, nDeltaCol

   nDeltaRow := ::nTop - nOldTop
   nDeltaCol := ::nLeft - nOldLeft

   if ! Empty( ::GetList )
      for each oCtrl in ::GetList
         oCtrl:row += nDeltaRow
         oCtrl:col += nDeltaCol
         if ! Empty( oCtrl:Caption )
            oCtrl:CapRow += nDeltaRow
            oCtrl:CapCol += nDeltaCol
         endif
             if ! Empty( oCtrl:Control )
               if oCtrl:Control:IsKindOf( "PUSHBUTTON" )
                  oCtrl:Control:row += nDeltaRow
                  oCtrl:Control:col += nDeltaCol
               endif
               if oCtrl:Control:IsKindOf( "LISTBOX" )
                  oCtrl:Control:top    += nDeltaRow
                  oCtrl:Control:left   += nDeltaCol
                  oCtrl:Control:bottom += ( ::nBottom - nOldBottom )
                  oCtrl:Control:right  += ( ::nRight - nOldRight )
                  oCtrl:Control:CapRow += nDeltaRow
                  oCtrl:Control:CapCol += nDeltaCol
               endif
               if oCtrl:Control:IsKindOf( "CHECKBOX" ) .and. HB_IsArray( oCtrl:Control:cargo )
                  oCtrl:Control:cargo[ 2 ] += nDeltaRow
                  oCtrl:Control:cargo[ 3 ] += nDeltaCol
               endif
               if oCtrl:Control:IsKindOf( "RADIOGROUP" )
                  oCtrl:Control:top( oCtrl:Control:top() + nDeltaRow )
                  oCtrl:Control:left( oCtrl:Control:left() + nDeltaCol )
                  oCtrl:Control:bottom( oCtrl:Control:bottom() + nDeltaRow )
                  oCtrl:Control:right( oCtrl:Control:right() + nDeltaCol )
                  if oCtrl:Control:capRow() != nil .and. oCtrl:Control:capRow() != 0
                     oCtrl:Control:capRow( oCtrl:Control:capRow() + nDeltaRow )
                     oCtrl:Control:capCol( oCtrl:Control:capCol() + nDeltaCol )
                  endif
               endif
            endif
       next
       if HB_IsArray( ::cargo )
          for each oCtrl in ::cargo
             if HB_IsObject( oCtrl ) .and. HB_IsArray( oCtrl:cargo )
                oCtrl:cargo[ 2 ] += nDeltaRow
                oCtrl:cargo[ 3 ] += nDeltaCol
             endif
          next
       endif
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

   if lFocused .and. ::nIdle == nil
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

   // A dialog larger than the screen gets negative top/left coordinates and
   // its frame and contents paint corrupted. Move it on-screen, keeping as
   // much of the original design as the terminal can show; controls keep
   // their relative offsets, so controls that still fall outside the screen
   // are not visible (they remain reachable by keyboard). ::lClamped tells
   // the caller the requested size did not fit.
   ::nReqWidth  := nWidth
   ::nReqHeight := nHeight
   ::lClamped := ( nTop < 0 .or. nLeft < 0 .or. nBottom > MaxRow() .or. nRight > MaxCol() )
   if ::lClamped
      nTop    := Max( 0, nTop )
      nLeft   := Max( 0, nLeft )
      nBottom := Min( MaxRow(), nBottom )
      nRight  := Min( MaxCol(), nRight )
   endif

   ::New( nTop, nLeft, nBottom, nRight, cCaption, cColor )
   ::bInit   = bInit
   ::lShadow = .T.
   ::Show()

return Self

//-----------------------------------------------------------------------------------------//

static function MaxBtm( oWnd )

return If( oWnd:nMaxBottom == NIL, MaxRow(), oWnd:nMaxBottom )

//-----------------------------------------------------------------------------------------//

static function MaxRgt( oWnd )

return If( oWnd:nMaxRight == NIL, MaxCol(), oWnd:nMaxRight )

//-----------------------------------------------------------------------------------------//

static function GetColors()

return { "W+/BG", "N/BG", "R/BG", "N+/BG", "W+/B", "GR+/B", "W/B", "N/W", "R/W", "N/BG", "R/BG" }

//-----------------------------------------------------------------------------------------//

static function DrawBorder( nTop, nLeft, nBottom, nRight, cColor )

   local cBox := hb_UTF8ToStrBox( "┌─┐│┘─└│" )

   hb_DispBox( nTop, nLeft, nBottom, nRight, cBox, cColor )

return nil

//-----------------------------------------------------------------------------------------//

//-----------------------------------------------------------------------------------------//

// PgDn/PgUp page the focused LISTBOX instead of ending the READ (stock
// reader behavior): the trap turns each key into a clamped burst of
// Down/Up presses, the same path the mouse scrollbar uses, so the GET
// variable stays in sync. Other controls replay the key untrapped, so
// stock PgDn/PgUp behavior (jump/exit) is preserved for them.

// Arm/disarm the PgDn/PgUp listbox paging trap around a READ. Install
// saves the previous handlers on a stack so consecutive and nested
// dialogs each restore their own level; removing an inner level leaves
// the outer one armed.

function HBPageTrapInstall()

   AAdd( s_aTrapStack, { { K_PGDN, SetKey( K_PGDN ) }, { K_PGUP, SetKey( K_PGUP ) } } )
   SetKey( K_PGDN, { || HBListBoxPage( 1 ) } )
   SetKey( K_PGUP, { || HBListBoxPage( -1 ) } )

return nil

function HBPageTrapRemove()

   local aLevel, aPair

   if ! Empty( s_aTrapStack )
      aLevel := ATail( s_aTrapStack )
      ASize( s_aTrapStack, Len( s_aTrapStack ) - 1 )
      for each aPair in aLevel
         SetKey( aPair[ 1 ], aPair[ 2 ] )
      next
   endif

return nil

function HBPageTrapDepth()

return Len( s_aTrapStack )

function HBListBoxPage( nDir )

   local oGet := GetActive()
   local oCtl, nVis, nCur, nSteps

   if oGet != nil .and. oGet:control != nil .and. oGet:control:IsKindOf( "LISTBOX" )
      oCtl := oGet:control
      nVis := iif( __objHasData( oCtl, "BOTTOM" ) .and. __objHasData( oCtl, "TOP" ), ;
                   Max( 1, oCtl:bottom - oCtl:top - 1 ), 3 )
      nCur := oGet:varGet()
      if ! HB_ISNUMERIC( nCur )
         nCur := 1
      endif
      nSteps := HBListBoxPageSteps( nDir, nCur, nVis, oCtl:itemCount )
      __Keyboard( Replicate( Chr( iif( nDir > 0, K_DOWN, K_UP ) ), Max( 0, nSteps ) ) )
   else
      HBRekeyUntrapped( iif( nDir > 0, K_PGDN, K_PGUP ) )
   endif

return nil

// Clamped page size: never past the first or last item.

function HBListBoxPageSteps( nDir, nCur, nVis, nCount )

return Max( 0, iif( nDir > 0, Min( nVis, nCount - nCur ), Min( nVis, nCur - 1 ) ) )

// Replay a PgDn/PgUp for a non-listbox control without trapping it again:
// clear the trap, reinject the key for the reader, and re-arm the trap
// once the system goes idle (after the replayed key was read). If the
// READ ended in between, the trap stack is already empty and the
// re-arm is skipped so no handler leaks into the caller.

function HBRekeyUntrapped( nKey )

   local bOld := SetKey( nKey )
   local aId  := { nil }

   SetKey( nKey, NIL )
   hb_keyPut( nKey )
   aId[ 1 ] := hb_IdleAdd( { || HBRekeyRestore( nKey, bOld, aId ) } )

return nil

function HBRekeyRestore( nKey, bOld, aId )

   if ! Empty( s_aTrapStack )
      SetKey( nKey, bOld )
   endif
   if aId[ 1 ] != nil
      hb_IdleDel( aId[ 1 ] )
   endif

return nil

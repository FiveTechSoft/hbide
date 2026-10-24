//
// designer.prg - Interactive dialog designer for HbIde
//
// First version: design dialogs visually inside hbide, save them as JSON
// and generate Harbour code (.prg) that rebuilds the dialog with HBWindow.
//
// Written in pure Harbour. No C code.
//

#include "hbclass.ch"
#include "inkey.ch"
#include "setcurs.ch"
#include "hbmenu.ch"

#define DSN_SAY       "say"
#define DSN_GET       "get"
#define DSN_BUTTON    "button"
#define DSN_CHECKBOX  "checkbox"
#define DSN_RADIO     "radiogroup"
#define DSN_LISTBOX   "listbox"

// control palettes for the generated dialog, from hbide's own dialogs
// (white dialog background: input GET from hbide.prg, listbox exact hbide palette)
#define DSN_CLR_GET      "W/B,W+/B,W+/W,GR+/W"
#define DSN_CLR_CHECKBOX "N/W,BG+/W,N/W,GR+/W"
#define DSN_CLR_BUTTON   "GR+/G,W+/G,N/G,BG+/G"
#define DSN_CLR_RADIO    "N/W,N/W,N/W,BG+/W,N/W,GR+/W,BG+/W"
#define DSN_CLR_LISTBOX  "N/BG,GR+/BG,N/BG,W+/G,W+/W,W+/W,GR+/W"

#define CLR_DIALOG    "W+/W"
#define CLR_SAY       "N/W"
#define CLR_GET       "W/B"
#define CLR_BUTTON    "GR+/G"
#define CLR_CHECKBOX  "N/W"
#define CLR_SELECTED  "N/G"
#define CLR_GHOST     "N/BG"
#define CLR_INSP      "W+/B"
#define CLR_INSP_SEL  "N/GR"
#define CLR_INSP_VAL  "N/W"

#define HINT_CANVAS   "F2 add | Enter edit | F4 inspector | Del delete | Arrows move | F9 gen | F10 save | Esc exit"
#define HINT_INSP     "F6 canvas | Enter edit | Left/Right adjust | Ctrl+Arrows move panel | F4 hide"

//-----------------------------------------------------------------------------------------//

CLASS HbDesigner

   DATA oIde                          // HbIde instance (Repaint(), MsgInfo())
   DATA oWnd                          // HbWindow used as design canvas
   DATA aControls    INIT {}          // array of hashes, one per control
   DATA nSelected    INIT 0           // 1-based index in aControls, 0 = none
   DATA cDlgName     INIT "MyDialog"
   DATA cDlgCaption  INIT "My Dialog"
   DATA cDlgColor    INIT CLR_DIALOG
   DATA nDlgWidth    INIT 40
   DATA nDlgHeight   INIT 12
   DATA cFileName    INIT ""          // last JSON file used
   DATA lDirty       INIT .F.
   DATA lEnd         INIT .F.
   DATA lPlacing     INIT .F.         // placing a new control
   DATA cPlacingType INIT ""
   DATA nGhostRow    INIT 1           // ghost position, client relative
   DATA nGhostCol    INIT 1
   DATA lInspector   INIT .F.         // floating object inspector visible
   DATA lInspFocus   INIT .F.         // inspector has keyboard focus
   DATA nInspRow     INIT 2           // inspector screen position
   DATA nInspCol     INIT 86
   DATA nInspField   INIT 1           // focused field in the inspector
   DATA nIdleDraw                     // idle handler: redraw controls
   DATA nOldCursor
   DATA cHint        INIT HINT_CANVAS

   METHOD New( oIde )
   METHOD Activate()

   METHOD AddControl( cType )
   METHOD DeleteSelected()
   METHOD DlgProperties()
   METHOD DragControl( nIndex, nMRow, nMCol )
   METHOD DrawControls()
   METHOD EditProperties()
   METHOD ToggleInspector()
   METHOD InspFields()
   METHOD InspRect()
   METHOD DrawInspector()
   METHOD DlgMinSize()
   METHOD InspValue( cKey )
   METHOD InspSetText( cKey, cVal )
   METHOD InspAdjust( nDelta )
   METHOD InspEdit()
   METHOD InspHit( nMRow, nMCol )
   METHOD DragInspector( nMRow, nMCol )
   METHOD InspectorKey( nKey )
   METHOD GeneratePrg()
   METHOD HitClient( nMRow, nMCol )
   METHOD HitTest( nMRow, nMCol )
   METHOD LoadJson()
   METHOD MoveSelected( nDRow, nDCol )
   METHOD PopupMenu()
   METHOD Redraw()
   METHOD ResumeUI()
   METHOD SaveJson( lAskName )
   METHOD SelectFileName( cTitle, cDefault )
   METHOD ShowHint( cText )
   METHOD SuspendUI()

ENDCLASS

//-----------------------------------------------------------------------------------------//

METHOD New( oIde ) CLASS HbDesigner

   ::oIde = oIde

return Self

//-----------------------------------------------------------------------------------------//

METHOD Activate() CLASS HbDesigner

   local nKey, nIndex, nInspHit, nChoice

   ::nOldCursor = SetCursor( SC_NONE )
   ::oIde:SuspendStatus()

   ::oWnd = HBWindow():Dialog( ::cDlgCaption, ::nDlgWidth, ::nDlgHeight, ::cDlgColor )
   ::oWnd:bRepaint = { || ::oIde:Repaint() }
   ::oWnd:lDesign  = .T.
   ::oWnd:bPopup   = { || ::PopupMenu() }

   ::nIdleDraw = hb_IdleAdd( { || ::DrawControls() } )

   ::ShowHint( HINT_CANVAS )

   while ! ::lEnd

      nKey = InKey( 0, INKEY_ALL )

      if ::lInspector .and. ::lInspFocus .and. ::InspectorKey( nKey )
         loop
      endif

      do case
         case nKey == K_F4
            ::ToggleInspector()

         case nKey == K_F6
            if ::lInspector
               ::lInspFocus = ! ::lInspFocus
               if ::lInspFocus
                  ::ShowHint( HINT_INSP )
               else
                  ::ShowHint( HINT_CANVAS )
               endif
               ::DrawInspector()
            endif

         case nKey == K_ESC
            if ::lPlacing
               ::lPlacing = .F.
            elseif ::lDirty
               ::SuspendUI()
               nChoice = Alert( "Discard unsaved changes?", { "Yes", "No" } )
               ::ResumeUI()
               if nChoice == 1
                  ::lEnd = .T.
               endif
            else
               ::lEnd = .T.
            endif

         case nKey == K_F2
            ::PopupMenu()

         case nKey == K_F3
            ::DlgProperties()

         case nKey == K_F9
            ::GeneratePrg()

         case nKey == K_F10
            ::SaveJson( .F. )

         case nKey == K_F12
            ::LoadJson()

         case nKey == K_ENTER
            if ::lPlacing
               ::AddControl( ::cPlacingType )
            elseif ::nSelected > 0
               ::EditProperties()
            endif

         case nKey == K_DEL
            if ! ::lPlacing
               ::DeleteSelected()
            endif

         case nKey == K_UP
            if ::lPlacing
               ::nGhostRow = Max( 0, ::nGhostRow - 1 )
               ::Redraw()
            else
               ::MoveSelected( -1, 0 )
            endif

         case nKey == K_DOWN
            if ::lPlacing
               ::nGhostRow = Min( ::oWnd:nBottom - ::oWnd:nTop - 2, ::nGhostRow + 1 )
               ::Redraw()
            else
               ::MoveSelected( 1, 0 )
            endif

         case nKey == K_LEFT
            if ::lPlacing
               ::nGhostCol = Max( 0, ::nGhostCol - 1 )
               ::Redraw()
            else
               ::MoveSelected( 0, -1 )
            endif

         case nKey == K_RIGHT
            if ::lPlacing
               ::nGhostCol = Min( ::oWnd:nRight - ::oWnd:nLeft - 2, ::nGhostCol + 1 )
               ::Redraw()
            else
               ::MoveSelected( 0, 1 )
            endif

         case nKey == K_TAB
            if ! Empty( ::aControls )
               ::nSelected = If( ::nSelected >= Len( ::aControls ), 1, ::nSelected + 1 )
               ::nInspField = 1
               ::DrawInspector()
            endif

         case nKey == K_SH_TAB
            if ! Empty( ::aControls )
               ::nSelected = If( ::nSelected <= 1, Len( ::aControls ), ::nSelected - 1 )
               ::nInspField = 1
               ::DrawInspector()
            endif

         case nKey == K_LBUTTONDOWN
            if ::lPlacing
               if ::HitClient( MRow(), MCol() )
                  ::nGhostRow = MRow() - ::oWnd:nTop - 1
                  ::nGhostCol = MCol() - ::oWnd:nLeft - 1
                  ::AddControl( ::cPlacingType )
               endif
            else
               nInspHit = ::InspHit( MRow(), MCol() )
               if ::lInspector .and. nInspHit != 0
                  if nInspHit == -1
                     ::DragInspector( MRow(), MCol() )
                  else
                     ::lInspFocus = .T.
                     ::nInspField = nInspHit
                     ::ShowHint( HINT_INSP )
                     ::DrawInspector()
                  endif
               else
                  if ::lInspFocus
                     ::lInspFocus = .F.
                     ::ShowHint( HINT_CANVAS )
                  endif
                  nIndex = ::HitTest( MRow(), MCol() )
                  if nIndex > 0
                     ::nSelected = nIndex
                     ::nInspField = 1
                     ::DragControl( nIndex, MRow(), MCol() )
                  else
                     ::nSelected = 0
                  endif
                  ::DrawInspector()
               endif
            endif
      endcase

   enddo

   if ::nIdleDraw != nil
      hb_IdleDel( ::nIdleDraw )
      ::nIdleDraw = nil
   endif

   ::oWnd:Hide()
   ::oIde:ResumeStatus()
   ::oIde:Repaint()
   SetCursor( ::nOldCursor )

return nil

//-----------------------------------------------------------------------------------------//
// client area hit test (inside the window frame)

METHOD HitClient( nMRow, nMCol ) CLASS HbDesigner

return nMRow > ::oWnd:nTop .and. nMRow < ::oWnd:nBottom .and. ;
       nMCol > ::oWnd:nLeft .and. nMCol < ::oWnd:nRight

//-----------------------------------------------------------------------------------------//

METHOD PopupMenu() CLASS HbDesigner

   local oPopup, oItem, cType := ""

   ::SuspendUI()

   MENU oPopup POPUP
      MENUITEM "~Label (SAY)"              ACTION cType := DSN_SAY
      MENUITEM "~Input (GET)"              ACTION cType := DSN_GET
      MENUITEM "Check~Box"                 ACTION cType := DSN_CHECKBOX
      MENUITEM "~PushButton"               ACTION cType := DSN_BUTTON
      MENUITEM "~RadioGroup"               ACTION cType := DSN_RADIO
      MENUITEM "ListBo~x"                  ACTION cType := DSN_LISTBOX
      SEPARATOR
      MENUITEM "~Dialog properties..."     ACTION cType := "dialog"
      SEPARATOR
      MENUITEM "~Save JSON    F10"         ACTION cType := "save"
      MENUITEM "~Open JSON    F12"         ACTION cType := "open"
      MENUITEM "~Generate PRG  F9"         ACTION cType := "gen"
   ENDMENU

   // normalize popup geometry (menu builder defaults do not fit 11 items)
   oPopup:nTop    = 21
   oPopup:nLeft   = 30
   oPopup:nRight  = Min( 62, MaxCol() )
   oPopup:nBottom = Min( oPopup:nTop + Len( oPopup:aItems ) + 1, MaxRow() )
   for each oItem in oPopup:aItems
      oItem:nRow = oPopup:nTop + oItem:__enumIndex()
      oItem:nCol = oPopup:nLeft + 1
   next

   ACTIVATE MENU oPopup

   ::ResumeUI()

   do case
      case cType == "dialog"
         ::DlgProperties()
      case cType == "save"
         ::SaveJson( .F. )
      case cType == "open"
         ::LoadJson()
      case cType == "gen"
         ::GeneratePrg()
      case ! Empty( cType )
         ::lPlacing     = .T.
         ::cPlacingType = cType
         ::nGhostRow    = Int( ( ::oWnd:nBottom - ::oWnd:nTop ) / 2 )
         ::nGhostCol    = Max( 0, Int( ( ::oWnd:nRight - ::oWnd:nLeft ) / 2 ) - 4 )
         ::ShowHint( "Place the " + cType + ": arrows/mouse, Enter/click to drop, Esc to cancel" )
   endcase

return nil

//-----------------------------------------------------------------------------------------//

METHOD AddControl( cType ) CLASS HbDesigner

   local oCtrl := { "type" => cType, ;
                    "row"  => ::nGhostRow, ;
                    "col"  => ::nGhostCol }

   do case
      case cType == DSN_SAY
         oCtrl[ "caption" ] = "Label"
      case cType == DSN_GET
         oCtrl[ "variable" ] = DsnUniqueVar( ::aControls, "cVar" )
         oCtrl[ "width"    ] = 10
      case cType == DSN_CHECKBOX
         oCtrl[ "caption"  ] = "Check"
         oCtrl[ "variable" ] = DsnUniqueVar( ::aControls, "lVar" )
      case cType == DSN_BUTTON
         oCtrl[ "caption"     ] = "OK"
         oCtrl[ "accelerator" ] = "O"
         oCtrl[ "action"      ] = "oDlg:End()"
      case cType == DSN_RADIO
         oCtrl[ "variable" ] = DsnUniqueVar( ::aControls, "nVar" )
         oCtrl[ "items"    ] = "Option 1,Option 2,Option 3"
      case cType == DSN_LISTBOX
         oCtrl[ "variable" ] = DsnUniqueVar( ::aControls, "nVar" )
         oCtrl[ "items"    ] = "Item 1,Item 2,Item 3"
         oCtrl[ "width"    ] = 20
         oCtrl[ "height"   ] = 6
   endcase

   AAdd( ::aControls, oCtrl )
   ::nSelected = Len( ::aControls )
   ::lPlacing  = .F.
   ::lDirty    = .T.

   ::ShowHint( "F2 add | Enter edit | Del delete | Arrows move | F9 generate | F10 save | Esc exit" )
   ::Redraw()

return nil

//-----------------------------------------------------------------------------------------//

METHOD DeleteSelected() CLASS HbDesigner

   if ::nSelected >= 1 .and. ::nSelected <= Len( ::aControls )
      hb_ADel( ::aControls, ::nSelected, .T. )
      ::nSelected = Min( ::nSelected, Len( ::aControls ) )
      ::lDirty    = .T.
      ::Redraw()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD MoveSelected( nDRow, nDCol ) CLASS HbDesigner

   local oCtrl, aSize, nMaxRow, nMaxCol

   if ::nSelected >= 1 .and. ::nSelected <= Len( ::aControls )
      oCtrl   = ::aControls[ ::nSelected ]
      aSize   = DsnControlSize( oCtrl )
      nMaxRow = ::oWnd:nBottom - ::oWnd:nTop - 1 - aSize[ 2 ]
      nMaxCol = ::oWnd:nRight  - ::oWnd:nLeft - 1 - aSize[ 1 ]
      oCtrl[ "row" ] = Max( 0, Min( nMaxRow, oCtrl[ "row" ] + nDRow ) )
      oCtrl[ "col" ] = Max( 0, Min( nMaxCol, oCtrl[ "col" ] + nDCol ) )
      ::lDirty = .T.
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD DragControl( nIndex, nMRow, nMCol ) CLASS HbDesigner

   local oCtrl  := ::aControls[ nIndex ]
   local aSize  := DsnControlSize( oCtrl )
   local nOffR  := nMRow - ( ::oWnd:nTop + 1 + oCtrl[ "row" ] )
   local nOffC  := nMCol - ( ::oWnd:nLeft + 1 + oCtrl[ "col" ] )
   local nNewRow, nNewCol, nMaxRow, nMaxCol

   nMaxRow = ::oWnd:nBottom - ::oWnd:nTop - 1 - aSize[ 2 ]
   nMaxCol = ::oWnd:nRight  - ::oWnd:nLeft - 1 - aSize[ 1 ]

   while MLeftDown()
      nNewRow = Max( 0, Min( nMaxRow, MRow() - ::oWnd:nTop - 1 - nOffR ) )
      nNewCol = Max( 0, Min( nMaxCol, MCol() - ::oWnd:nLeft - 1 - nOffC ) )
      if nNewRow != oCtrl[ "row" ] .or. nNewCol != oCtrl[ "col" ]
         oCtrl[ "row" ] = nNewRow
         oCtrl[ "col" ] = nNewCol
         ::lDirty = .T.
         ::Redraw()
      endif
   enddo

return nil

//-----------------------------------------------------------------------------------------//
// returns 1-based index of the control at an absolute screen position

METHOD HitTest( nMRow, nMCol ) CLASS HbDesigner

   local n, oCtrl, aSize, nARow, nACol

   if ! ::HitClient( nMRow, nMCol )
      return 0
   endif

   for n = Len( ::aControls ) to 1 step -1
      oCtrl = ::aControls[ n ]
      aSize = DsnControlSize( oCtrl )
      nARow = ::oWnd:nTop + 1 + oCtrl[ "row" ]
      nACol = ::oWnd:nLeft + 1 + oCtrl[ "col" ]
      if nMRow >= nARow .and. nMRow < nARow + aSize[ 2 ] .and. ;
         nMCol >= nACol .and. nMCol < nACol + aSize[ 1 ]
         return n
      endif
   next

return 0

//-----------------------------------------------------------------------------------------//

METHOD Redraw() CLASS HbDesigner

   if ::oIde == nil .or. ::oWnd == nil
      return nil
   endif

   DispBegin()
   ::oIde:Repaint()
   ::oWnd:Refresh()
   DrawShadow( ::oWnd:nTop, ::oWnd:nLeft, ::oWnd:nBottom, ::oWnd:nRight )
   hb_Scroll( ::oWnd:nTop + 1, ::oWnd:nLeft + 1, ;
              ::oWnd:nBottom - 1, ::oWnd:nRight - 1,,, ::cDlgColor )
   ::DrawControls()
   ::ShowHint()
   DispEnd()

return nil

//-----------------------------------------------------------------------------------------//

METHOD DrawControls() CLASS HbDesigner

   local n, oCtrl

   if ::oWnd == nil .or. ! ::oWnd:lVisible
      return nil
   endif

   // keep the model in sync with window moves/resizes done by mouse
   ::nDlgWidth  = ::oWnd:nRight - ::oWnd:nLeft + 1
   ::nDlgHeight = ::oWnd:nBottom - ::oWnd:nTop + 1

   DispBegin()
   for n = 1 to Len( ::aControls )
      oCtrl = ::aControls[ n ]
      DsnDrawControl( ::oWnd, oCtrl, n == ::nSelected )
   next

   if ::lPlacing
      DsnDrawControl( ::oWnd, { "type"     => ::cPlacingType, ;
                                "row"      => ::nGhostRow, ;
                                "col"      => ::nGhostCol, ;
                                "caption"  => "Label", ;
                                "variable" => "cVar", ;
                                "width"    => 10 }, .T., CLR_GHOST )
   endif

   ::DrawInspector()

   DispEnd()

return nil

//-----------------------------------------------------------------------------------------//

METHOD ShowHint( cText ) CLASS HbDesigner

   if PCount() > 0
      ::cHint = cText
   endif

   hb_DispOutAt( MaxRow(), 0, PadR( ::cHint, MaxCol() + 1 ), "N/W" )

return nil

//-----------------------------------------------------------------------------------------//
// suspend designer window mouse + redraw idles while a modal dialog runs

METHOD SuspendUI() CLASS HbDesigner

   if ::nIdleDraw != nil
      hb_IdleDel( ::nIdleDraw )
      ::nIdleDraw = nil
   endif

   if ::oWnd:nIdle != nil
      hb_IdleDel( ::oWnd:nIdle )
      ::oWnd:nIdle = nil
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD ResumeUI() CLASS HbDesigner

   if ::nIdleDraw == nil
      ::nIdleDraw = hb_IdleAdd( { || ::DrawControls() } )
   endif

   if ::oWnd != nil .and. ::oWnd:nIdle == nil .and. ::oWnd:lVisible
      ::oWnd:nIdle = hb_IdleAdd( { || ::oWnd:MouseEvent( MRow(), MCol() ) } )
   endif

   ::Redraw()

return nil

//-----------------------------------------------------------------------------------------//

METHOD EditProperties() CLASS HbDesigner

   local oCtrl, oDlg, GetList := {}, lOk := .F., lCancel := .F., lDummy
   local cCaption, cVariable, nRow, nCol, nWidth, cAccel, cAction, cItems, nHeight
   local aSize, nMaxRow, nMaxCol

   if ::nSelected < 1 .or. ::nSelected > Len( ::aControls )
      return nil
   endif

   oCtrl     = ::aControls[ ::nSelected ]
   aSize     = DsnControlSize( oCtrl )
   nMaxRow   = ::oWnd:nBottom - ::oWnd:nTop - 1 - aSize[ 2 ]
   nMaxCol   = ::oWnd:nRight  - ::oWnd:nLeft - 1 - aSize[ 1 ]
   cCaption  = PadR( hb_HGetDef( oCtrl, "caption", "" ), Max( 60, Len( hb_HGetDef( oCtrl, "caption", "" ) ) ) + 20 )
   cVariable = PadR( hb_HGetDef( oCtrl, "variable", "" ), Max( 20, Len( hb_HGetDef( oCtrl, "variable", "" ) ) ) + 10 )
   nRow      = oCtrl[ "row" ]
   nCol      = oCtrl[ "col" ]
   nWidth    = hb_HGetDef( oCtrl, "width", 10 )
   cAccel    = PadR( hb_HGetDef( oCtrl, "accelerator", "" ), 4 )
   cAction   = PadR( hb_HGetDef( oCtrl, "action", "" ), Max( 60, Len( hb_HGetDef( oCtrl, "action", "" ) ) ) + 20 )
   cItems    = PadR( hb_HGetDef( oCtrl, "items", "" ), Max( 60, Len( hb_HGetDef( oCtrl, "items", "" ) ) ) + 20 )
   nHeight   = hb_HGetDef( oCtrl, "height", 6 )

   ::SuspendUI()

   oDlg = HBWindow():Dialog( "Control properties", 76, 11, CLR_DIALOG )
   oDlg:bRepaint = { || ::Redraw() }

   @ oDlg:nTop + 2, oDlg:nLeft + 11 GET nRow PICTURE "999" COLOR "N/W,W+/B,W+/W,GR+/W"
   @ oDlg:nTop + 2, oDlg:nLeft + 25 GET nCol PICTURE "999" COLOR "N/W,W+/B,W+/W,GR+/W"
   oDlg:Say( 2, 2, "Row:" )
   oDlg:Say( 2, 20, "Col:" )

   if oCtrl[ "type" ] $ DSN_SAY + "|" + DSN_BUTTON + "|" + DSN_CHECKBOX
      @ oDlg:nTop + 4, oDlg:nLeft + 11 GET cCaption PICTURE "@S40" COLOR "N/W,W+/B,W+/W,GR+/W"
      oDlg:Say( 4, 2, "Caption:" )
   endif

   if oCtrl[ "type" ] $ DSN_GET + "|" + DSN_CHECKBOX
      @ oDlg:nTop + 5, oDlg:nLeft + 11 GET cVariable PICTURE "@S20" COLOR "N/W,W+/B,W+/W,GR+/W"
      oDlg:Say( 5, 2, "Variable:" )
   endif

   if oCtrl[ "type" ] == DSN_GET
      @ oDlg:nTop + 6, oDlg:nLeft + 11 GET nWidth PICTURE "999" COLOR "N/W,W+/B,W+/W,GR+/W"
      oDlg:Say( 6, 2, "Width:" )
   endif

   if oCtrl[ "type" ] == DSN_BUTTON
      @ oDlg:nTop + 5, oDlg:nLeft + 11 GET cAccel COLOR "N/W,W+/B,W+/W,GR+/W"
      oDlg:Say( 5, 2, "Accel:" )
      @ oDlg:nTop + 6, oDlg:nLeft + 11 GET cAction PICTURE "@S40" COLOR "N/W,W+/B,W+/W,GR+/W"
      oDlg:Say( 6, 2, "Action:" )
   endif

   if oCtrl[ "type" ] $ DSN_RADIO + "|" + DSN_LISTBOX
      @ oDlg:nTop + 4, oDlg:nLeft + 11 GET cVariable PICTURE "@S20" COLOR "N/W,W+/B,W+/W,GR+/W"
      oDlg:Say( 4, 2, "Variable:" )
      @ oDlg:nTop + 5, oDlg:nLeft + 11 GET cItems PICTURE "@S40" COLOR "N/W,W+/B,W+/W,GR+/W"
      oDlg:Say( 5, 2, "Items:" )
   endif

   if oCtrl[ "type" ] == DSN_LISTBOX
      @ oDlg:nTop + 6, oDlg:nLeft + 11 GET nWidth PICTURE "999" COLOR "N/W,W+/B,W+/W,GR+/W"
      oDlg:Say( 6, 2, "Width:" )
      @ oDlg:nTop + 7, oDlg:nLeft + 11 GET nHeight PICTURE "999" COLOR "N/W,W+/B,W+/W,GR+/W"
      oDlg:Say( 7, 2, "Height:" )
   endif

   @ oDlg:nBottom - 2, oDlg:nLeft + 10 GET lDummy PUSHBUTTON ;
      CAPTION "  &OK  " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nLeft + 24 GET lDummy PUSHBUTTON ;
      CAPTION " &Cancel " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lCancel := .T., oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeUI()

   // Predictable close: only Esc or the Cancel pushbutton discard; ending the
   // READ by moving past the last GET (Enter/Down) commits the edits.
   if ! lOk .and. ! lCancel .and. LastKey() != K_ESC
      lOk := .T.
   endif

   if lOk
      oCtrl[ "row" ] = Max( 0, Min( nMaxRow, nRow ) )
      oCtrl[ "col" ] = Max( 0, Min( nMaxCol, nCol ) )
      if "caption" $ oCtrl
         oCtrl[ "caption" ] = AllTrim( cCaption )
      endif
      if "variable" $ oCtrl
         oCtrl[ "variable" ] = DsnValidVar( cVariable, ;
            If( oCtrl[ "type" ] == DSN_GET, "cVar", ;
               If( oCtrl[ "type" ] == DSN_CHECKBOX, "lVar", "nVar" ) ) + ;
            hb_ntos( ::nSelected ) )
      endif
      if "width" $ oCtrl
         oCtrl[ "width" ] = Max( 4, Min( 40, nWidth ) )
      endif
      if "items" $ oCtrl
         oCtrl[ "items" ] = AllTrim( cItems )
      endif
      if oCtrl[ "type" ] == DSN_LISTBOX
         oCtrl[ "height" ] = Max( 3, Min( 15, nHeight ) )
      endif
      if oCtrl[ "type" ] == DSN_BUTTON
         oCtrl[ "accelerator" ] = Left( StrTran( AllTrim( cAccel ), "&", "" ), 1 )
         oCtrl[ "action" ]      = AllTrim( cAction )
      endif
      ::lDirty = .T.
      ::Redraw()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD DlgProperties() CLASS HbDesigner

   local oDlg, GetList := {}, lOk := .F., lCancel := .F., lDummy
   local cCaption := PadR( ::cDlgCaption, Max( 50, Len( ::cDlgCaption ) ) + 10 )
   local cName    := PadR( ::cDlgName, 20 )
   local nWidth   := ::nDlgWidth
   local nHeight  := ::nDlgHeight
   local cColor   := PadR( ::cDlgColor, 20 )
   local aMin

   ::SuspendUI()

   oDlg = HBWindow():Dialog( "Dialog properties", 66, 12, CLR_DIALOG )
   oDlg:bRepaint = { || ::Redraw() }

   @ oDlg:nTop + 2, oDlg:nLeft + 11 GET cCaption PICTURE "@S40" COLOR "N/W,W+/B,W+/W,GR+/W"
   oDlg:Say( 2, 2, "Caption:" )

   @ oDlg:nTop + 4, oDlg:nLeft + 11 GET cName COLOR "N/W,W+/B,W+/W,GR+/W"
   oDlg:Say( 4, 2, "Name:" )

   @ oDlg:nTop + 6, oDlg:nLeft + 11 GET nWidth PICTURE "999" COLOR "N/W,W+/B,W+/W,GR+/W"
   oDlg:Say( 6, 2, "Width:" )

   @ oDlg:nTop + 6, oDlg:nLeft + 27 GET nHeight PICTURE "999" COLOR "N/W,W+/B,W+/W,GR+/W"
   oDlg:Say( 6, 20, "Height:" )

   @ oDlg:nTop + 8, oDlg:nLeft + 11 GET cColor PICTURE "@S20" COLOR "N/W,W+/B,W+/W,GR+/W"
   oDlg:Say( 8, 2, "Color:" )

   @ oDlg:nBottom - 2, oDlg:nLeft + 10 GET lDummy PUSHBUTTON ;
      CAPTION "  &OK  " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nLeft + 24 GET lDummy PUSHBUTTON ;
      CAPTION " &Cancel " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lCancel := .T., oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeUI()

   // Predictable close: only Esc or the Cancel pushbutton discard; ending the
   // READ by moving past the last GET (Enter/Down) commits the edits.
   if ! lOk .and. ! lCancel .and. LastKey() != K_ESC
      lOk := .T.
   endif

   if lOk
      aMin = ::DlgMinSize()
      if nWidth < aMin[ 1 ] .or. nHeight < aMin[ 2 ]
         nWidth   = Max( nWidth, aMin[ 1 ] )
         nHeight  = Max( nHeight, aMin[ 2 ] )
         ::ShowHint( "Adjusted to the minimum size: controls inside would be hidden" )
      endif
      ::cDlgCaption = AllTrim( cCaption )
      ::cDlgName    = DsnValidVar( cName, "MyDialog" )
      ::nDlgWidth   = Max( 20, Min( MaxCol() - 4, nWidth ) )
      ::nDlgHeight  = Max( 6, Min( MaxRow() - 3, nHeight ) )
      if Empty( AllTrim( cColor ) )
         if AllTrim( cColor ) != ::cDlgColor
            ::ShowHint( "Color left empty: keeping " + ::cDlgColor )
         endif
      elseif ! DsnValidColor( AllTrim( cColor ) )
         ::ShowHint( "Invalid color '" + AllTrim( cColor ) + "': keeping " + ::cDlgColor )
      else
         ::cDlgColor = AllTrim( cColor )
      endif
      with object ::oWnd
         :nRight   = :nLeft + ::nDlgWidth - 1
         :nBottom  = :nTop + ::nDlgHeight - 1
         :cCaption = " " + ::cDlgCaption + " "
         :cColor   = ::cDlgColor
      end
      ::lDirty = .T.
      ::Redraw()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD SelectFileName( cTitle, cDefault ) CLASS HbDesigner

   local oDlg, GetList := {}, lOk := .F., lCancel := .F., lDummy
   local cFile := PadR( cDefault, 35 )

   ::SuspendUI()

   oDlg = HBWindow():Dialog( cTitle, 45, 7, CLR_DIALOG )
   oDlg:bRepaint = { || ::Redraw() }

   @ oDlg:nTop + 2, oDlg:nLeft + 8 GET cFile COLOR "N/W,W+/B,W+/W,GR+/W"
   oDlg:Say( 2, 2, "File:" )

   @ oDlg:nBottom - 2, oDlg:nLeft + 14 GET lDummy PUSHBUTTON ;
      CAPTION "  &OK  " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nLeft + 28 GET lDummy PUSHBUTTON ;
      CAPTION " &Cancel " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lCancel := .T., oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeUI()

   // Predictable close: only Esc or the Cancel pushbutton discard; ending the
   // READ by moving past the last GET (Enter/Down) commits the edits.
   if ! lOk .and. ! lCancel .and. LastKey() != K_ESC
      lOk := .T.
   endif

   if ! lOk
      return ""
   endif

   cFile = AllTrim( cFile )

return cFile

//-----------------------------------------------------------------------------------------//

METHOD SaveJson( lAskName ) CLASS HbDesigner

   local hModel, cFile

   hb_default( @lAskName, .F. )

   if lAskName .or. Empty( ::cFileName )
      cFile = ::SelectFileName( "Save dialog as JSON", ;
         If( Empty( ::cFileName ), Lower( ::cDlgName ) + ".json", ::cFileName ) )
      if Empty( cFile )
         return nil
      endif
      ::cFileName = cFile
   endif

   hModel = DsnBuildModel( Self )

   hb_MemoWrit( ::cFileName, hb_jsonEncode( hModel, .T. ) )
   ::lDirty = .F.
   ::ShowHint( "Saved " + ::cFileName )

return nil

//-----------------------------------------------------------------------------------------//

METHOD LoadJson() CLASS HbDesigner

   local cFile, cJson, hModel := nil, aMin, nSkipped

   cFile = ::SelectFileName( "Open a JSON dialog", ::cFileName )
   if Empty( cFile )
      return nil
   endif

   if ! File( cFile )
      ::ShowHint( "File not found: " + cFile )
      return nil
   endif

   cJson = MemoRead( cFile )
   hb_jsonDecode( cJson, @hModel )

   if ! DsnValidModel( hModel )
      ::ShowHint( "Invalid dialog JSON: " + cFile )
      return nil
   endif

   ::cDlgName    = DsnValidVar( DsnStr( hb_HGetDef( hModel, "name", "" ), "" ), "MyDialog" )
   ::cDlgCaption = DsnStr( hb_HGetDef( hModel, "caption", "" ), "My Dialog" )
   if Empty( ::cDlgCaption )
      ::cDlgCaption = "My Dialog"
   endif
   ::cDlgColor   = DsnStr( hb_HGetDef( hModel, "color", "" ), CLR_DIALOG )
   ::aControls   = hModel[ "controls" ]
   nSkipped      = Len( ::aControls )
   DsnNormalizeControls( ::aControls )
   nSkipped      -= Len( ::aControls )
   // clamp the dialog to the screen and grow it so no control is left outside
   ::nDlgWidth   = Max( 20, Min( MaxCol() - 4, Int( DsnNum( hb_HGetDef( hModel, "width", 40 ), 40 ) ) ) )
   ::nDlgHeight  = Max( 6, Min( MaxRow() - 3, Int( DsnNum( hb_HGetDef( hModel, "height", 12 ), 12 ) ) ) )
   aMin          = ::DlgMinSize()
   ::nDlgWidth   = Min( MaxCol() - 4, Max( ::nDlgWidth, aMin[ 1 ] ) )
   ::nDlgHeight  = Min( MaxRow() - 3, Max( ::nDlgHeight, aMin[ 2 ] ) )
   ::nSelected   = 0
   ::lPlacing    = .F.
   if nSkipped > 0
      // entries were skipped: keep the original file intact by asking a name
      ::cFileName   = ""
      ::lDirty      = .T.
      ::ShowHint( "Loaded " + cFile + " (" + hb_ntos( nSkipped ) + ;
         " invalid entries skipped)" )
   else
      ::cFileName   = cFile
      ::lDirty      = .F.
   endif

   with object ::oWnd
      :nRight   = :nLeft + ::nDlgWidth - 1
      :nBottom  = :nTop + ::nDlgHeight - 1
      :cCaption = " " + ::cDlgCaption + " "
      :cColor   = ::cDlgColor
   end

   ::Redraw()
   if nSkipped == 0
      ::ShowHint( "Loaded " + cFile )
   endif

return nil

//-----------------------------------------------------------------------------------------//


//-----------------------------------------------------------------------------------------//
// floating object inspector: non-modal, movable panel synced with the
// selected control (or the dialog itself when nothing is selected)

METHOD ToggleInspector() CLASS HbDesigner

   ::lInspector = ! ::lInspector
   if ! ::lInspector
      ::lInspFocus = .F.
   endif
   ::nInspField = 1
   ::Redraw()

return nil

//-----------------------------------------------------------------------------------------//
// { label, key, kind } per field; kind is "num" or "text"

METHOD InspFields() CLASS HbDesigner

   local aFields := {}, oCtrl

   if ::nSelected >= 1 .and. ::nSelected <= Len( ::aControls )
      oCtrl = ::aControls[ ::nSelected ]
      AAdd( aFields, { "Row", "row", "num" } )
      AAdd( aFields, { "Col", "col", "num" } )
      if oCtrl[ "type" ] $ DSN_SAY + "|" + DSN_BUTTON + "|" + DSN_CHECKBOX
         AAdd( aFields, { "Caption", "caption", "text" } )
      endif
      if oCtrl[ "type" ] $ DSN_GET + "|" + DSN_CHECKBOX
         AAdd( aFields, { "Variable", "variable", "text" } )
      endif
      if oCtrl[ "type" ] == DSN_GET
         AAdd( aFields, { "Width", "width", "num" } )
      endif
      if oCtrl[ "type" ] == DSN_BUTTON
         AAdd( aFields, { "Accel",  "accelerator", "text" } )
         AAdd( aFields, { "Action", "action",      "text" } )
      endif
      if oCtrl[ "type" ] $ DSN_RADIO + "|" + DSN_LISTBOX
         AAdd( aFields, { "Variable", "variable", "text" } )
         AAdd( aFields, { "Items",    "items",    "text" } )
      endif
      if oCtrl[ "type" ] == DSN_LISTBOX
         AAdd( aFields, { "Width",  "width",  "num" } )
         AAdd( aFields, { "Height", "height", "num" } )
      endif
   else
      AAdd( aFields, { "Name", "dlgname", "text" } )
      AAdd( aFields, { "Caption", "dlgcaption", "text" } )
      AAdd( aFields, { "Width", "dlgwidth", "num" } )
      AAdd( aFields, { "Height", "dlgheight", "num" } )
   endif

return aFields

//-----------------------------------------------------------------------------------------//

METHOD InspRect() CLASS HbDesigner

   local nHeight := Len( ::InspFields() ) + 2
   local nTop    := Max( 0, Min( MaxRow() - nHeight - 2, ::nInspRow ) )
   local nLeft   := Max( 0, Min( MaxCol() - 33, ::nInspCol ) )   // +2 for the shadow

return { nTop, nLeft, nTop + nHeight - 1, nLeft + 30 }

//-----------------------------------------------------------------------------------------//

// minimum dialog size so no control is left outside (frame included)

METHOD DlgMinSize() CLASS HbDesigner

   local oCtrl, aSize, nMinW := 20, nMinH := 6

   for each oCtrl in ::aControls
      aSize = DsnControlSize( oCtrl )
      nMinW = Max( nMinW, oCtrl[ "col" ] + aSize[ 1 ] + 2 )
      nMinH = Max( nMinH, oCtrl[ "row" ] + aSize[ 2 ] + 2 )
   next

return { nMinW, nMinH }

//-----------------------------------------------------------------------------------------//

METHOD InspValue( cKey ) CLASS HbDesigner

   local oCtrl

   if ::nSelected >= 1 .and. ::nSelected <= Len( ::aControls )
      oCtrl = ::aControls[ ::nSelected ]
      do case
         case cKey == "row"      ; return hb_ntos( oCtrl[ "row" ] )
         case cKey == "col"      ; return hb_ntos( oCtrl[ "col" ] )
         case cKey == "caption"  ; return hb_HGetDef( oCtrl, "caption", "" )
         case cKey == "variable" ; return hb_HGetDef( oCtrl, "variable", "" )
         case cKey == "width"    ; return hb_ntos( hb_HGetDef( oCtrl, "width", 10 ) )
         case cKey == "accelerator" ; return hb_HGetDef( oCtrl, "accelerator", "" )
         case cKey == "action"      ; return hb_HGetDef( oCtrl, "action", "" )
         case cKey == "items"       ; return hb_HGetDef( oCtrl, "items", "" )
         case cKey == "height"      ; return hb_ntos( hb_HGetDef( oCtrl, "height", 6 ) )
      endcase
   else
      do case
         case cKey == "dlgname"    ; return ::cDlgName
         case cKey == "dlgcaption" ; return ::cDlgCaption
         case cKey == "dlgwidth"   ; return hb_ntos( ::nDlgWidth )
         case cKey == "dlgheight"  ; return hb_ntos( ::nDlgHeight )
      endcase
   endif

return ""

//-----------------------------------------------------------------------------------------//

METHOD DrawInspector() CLASS HbDesigner

   local aRect, aFields, n, cLabel, cValue, cColor, nValWidth

   if ! ::lInspector .or. ::oWnd == nil
      return nil
   endif

   aFields   = ::InspFields()
   ::nInspField = Max( 1, Min( Len( aFields ), ::nInspField ) )
   aRect     = ::InspRect()
   nValWidth = aRect[ 4 ] - aRect[ 2 ] - 11

   DispBegin()
   hb_Scroll( aRect[ 1 ], aRect[ 2 ], aRect[ 3 ], aRect[ 4 ],,, CLR_INSP )
   DispBox( aRect[ 1 ], aRect[ 2 ], aRect[ 3 ], aRect[ 4 ], 2, CLR_INSP )
   DrawShadow( aRect[ 1 ], aRect[ 2 ], aRect[ 3 ], aRect[ 4 ] )
   hb_DispOutAt( aRect[ 1 ], aRect[ 2 ] + 2, " Inspector ", CLR_INSP )

   for n = 1 to Len( aFields )
      cLabel = " " + PadR( aFields[ n ][ 1 ] + ":", 9 )
      cValue = PadR( Left( ::InspValue( aFields[ n ][ 2 ] ), nValWidth ), nValWidth )
      if ::lInspFocus .and. n == ::nInspField
         hb_DispOutAt( aRect[ 1 ] + n, aRect[ 2 ] + 1, PadR( cLabel + cValue, 29 ), CLR_INSP_SEL )
      else
         hb_DispOutAt( aRect[ 1 ] + n, aRect[ 2 ] + 1, cLabel, CLR_INSP )
         hb_DispOutAt( aRect[ 1 ] + n, aRect[ 2 ] + 10, cValue, CLR_INSP_VAL )
      endif
   next
   DispEnd()

return nil

//-----------------------------------------------------------------------------------------//

METHOD InspSetText( cKey, cVal ) CLASS HbDesigner

   local oCtrl

   cVal = AllTrim( cVal )

   if ::nSelected >= 1 .and. ::nSelected <= Len( ::aControls )
      oCtrl = ::aControls[ ::nSelected ]
      do case
         case cKey == "caption"
            oCtrl[ "caption" ] = cVal
         case cKey == "variable"
            oCtrl[ "variable" ] = DsnValidVar( cVal, ;
               If( oCtrl[ "type" ] == DSN_GET, "cVar", ;
                  If( oCtrl[ "type" ] == DSN_CHECKBOX, "lVar", "nVar" ) ) + hb_ntos( ::nSelected ) )
         case cKey == "accelerator"
            oCtrl[ "accelerator" ] = Left( StrTran( cVal, "&", "" ), 1 )
         case cKey == "action"
            oCtrl[ "action" ] = cVal
         case cKey == "items"
            oCtrl[ "items" ] = cVal
      endcase
   else
      do case
         case cKey == "dlgname"
            ::cDlgName = DsnValidVar( cVal, "MyDialog" )
         case cKey == "dlgcaption"
            ::cDlgCaption = cVal
            ::oWnd:cCaption = " " + ::cDlgCaption + " "
      endcase
   endif

   ::lDirty = .T.

return nil

//-----------------------------------------------------------------------------------------//

METHOD InspAdjust( nDelta ) CLASS HbDesigner

   local aFields, cKey, oCtrl, aSize, nMaxRow, nMaxCol, aMin, nNew

   aFields = ::InspFields()
   if ::nInspField < 1 .or. ::nInspField > Len( aFields )
      return nil
   endif
   if aFields[ ::nInspField ][ 3 ] != "num"
      return nil
   endif
   cKey = aFields[ ::nInspField ][ 2 ]

   if ::nSelected >= 1 .and. ::nSelected <= Len( ::aControls )
      oCtrl   = ::aControls[ ::nSelected ]
      aSize   = DsnControlSize( oCtrl )
      nMaxRow = ::oWnd:nBottom - ::oWnd:nTop - 1 - aSize[ 2 ]
      nMaxCol = ::oWnd:nRight  - ::oWnd:nLeft - 1 - aSize[ 1 ]
      do case
         case cKey == "row"
            oCtrl[ "row" ] = Max( 0, Min( nMaxRow, oCtrl[ "row" ] + nDelta ) )
         case cKey == "col"
            oCtrl[ "col" ] = Max( 0, Min( nMaxCol, oCtrl[ "col" ] + nDelta ) )
         case cKey == "width"
            oCtrl[ "width" ] = Max( 4, Min( 40, hb_HGetDef( oCtrl, "width", 10 ) + nDelta ) )
         case cKey == "height"
            oCtrl[ "height" ] = Max( 3, Min( 15, hb_HGetDef( oCtrl, "height", 6 ) + nDelta ) )
      endcase
   else
      aMin = ::DlgMinSize()
      do case
         case cKey == "dlgwidth"
            nNew = Max( aMin[ 1 ], Min( MaxCol() - 4, ::nDlgWidth + nDelta ) )
            if nNew != ::nDlgWidth + nDelta .and. ::nDlgWidth + nDelta < aMin[ 1 ]
               ::ShowHint( "Minimum width " + hb_ntos( aMin[ 1 ] ) + ": controls inside would be hidden" )
            else
               ::ShowHint( HINT_INSP )
            endif
            ::nDlgWidth = nNew
            ::oWnd:nRight = ::oWnd:nLeft + ::nDlgWidth - 1
         case cKey == "dlgheight"
            nNew = Max( aMin[ 2 ], Min( MaxRow() - 3, ::nDlgHeight + nDelta ) )
            if nNew != ::nDlgHeight + nDelta .and. ::nDlgHeight + nDelta < aMin[ 2 ]
               ::ShowHint( "Minimum height " + hb_ntos( aMin[ 2 ] ) + ": controls inside would be hidden" )
            else
               ::ShowHint( HINT_INSP )
            endif
            ::nDlgHeight = nNew
            ::oWnd:nBottom = ::oWnd:nTop + ::nDlgHeight - 1
      endcase
   endif

   ::lDirty = .T.
   ::Redraw()

return nil

//-----------------------------------------------------------------------------------------//
// inline edit of a text field inside the inspector

METHOD InspEdit() CLASS HbDesigner

   local aFields, aRect, cKey, cVal, nRow, nCol, nWidth, nKey, lApply := .F.
   local nPos, nOff

   aFields = ::InspFields()
   if ::nInspField < 1 .or. ::nInspField > Len( aFields )
      return nil
   endif
   if aFields[ ::nInspField ][ 3 ] != "text"
      return nil
   endif

   cKey   = aFields[ ::nInspField ][ 2 ]
   cVal   = ::InspValue( cKey )
   aRect  = ::InspRect()
   nRow   = aRect[ 1 ] + ::nInspField
   nCol   = aRect[ 2 ] + 10
   nWidth = aRect[ 4 ] - aRect[ 2 ] - 11
   nPos   = Len( cVal ) + 1
   nOff   = 0

   SetCursor( SC_NORMAL )
   do while .T.
      // horizontal scroll: keep the cursor inside the visible window
      if nPos - 1 - nOff > nWidth - 1
         nOff = nPos - nWidth
      elseif nPos - 1 - nOff < 0
         nOff = nPos - 1
      endif
      hb_DispOutAt( nRow, nCol, PadR( SubStr( cVal, nOff + 1, nWidth ), nWidth ), CLR_INSP_SEL )
      DevPos( nRow, nCol + nPos - 1 - nOff )
      nKey = InKey( 0 )
      do case
         case nKey == K_ENTER
            lApply = .T.
            exit
         case nKey == K_ESC
            exit
         case nKey == K_LEFT
            nPos = Max( 1, nPos - 1 )
         case nKey == K_RIGHT
            nPos = Min( Len( cVal ) + 1, nPos + 1 )
         case nKey == K_HOME
            nPos = 1
         case nKey == K_END
            nPos = Len( cVal ) + 1
         case nKey == K_BS
            if nPos > 1
               cVal = Left( cVal, nPos - 2 ) + SubStr( cVal, nPos )
               nPos--
            endif
         case nKey == K_DEL
            if nPos <= Len( cVal )
               cVal = Left( cVal, nPos - 1 ) + SubStr( cVal, nPos + 1 )
            endif
         case nKey >= 32 .and. nKey <= 255
            if Len( cVal ) < 200
               cVal = Left( cVal, nPos - 1 ) + Chr( nKey ) + SubStr( cVal, nPos )
               nPos++
            endif
      endcase
   enddo
   SetCursor( SC_NONE )

   if lApply
      ::InspSetText( cKey, cVal )
   endif
   ::Redraw()

return nil

//-----------------------------------------------------------------------------------------//
// 0 outside, -1 title bar, n = field index

METHOD InspHit( nMRow, nMCol ) CLASS HbDesigner

   local aRect, nFields

   if ! ::lInspector
      return 0
   endif

   aRect   = ::InspRect()
   nFields = Len( ::InspFields() )

   if nMRow < aRect[ 1 ] .or. nMRow > aRect[ 3 ] .or. ;
      nMCol < aRect[ 2 ] .or. nMCol > aRect[ 4 ]
      return 0
   endif
   if nMRow == aRect[ 1 ]
      return -1
   endif
   if nMRow >= aRect[ 1 ] + 1 .and. nMRow <= aRect[ 1 ] + nFields
      return nMRow - aRect[ 1 ]
   endif

return -1

//-----------------------------------------------------------------------------------------//

METHOD DragInspector( nMRow, nMCol ) CLASS HbDesigner

   local nOffR := nMRow - ::nInspRow
   local nOffC := nMCol - ::nInspCol

   while MLeftDown()
      if MRow() - nOffR != ::nInspRow .or. MCol() - nOffC != ::nInspCol
         ::nInspRow = MRow() - nOffR
         ::nInspCol = MCol() - nOffC
         ::Redraw()
      endif
   enddo

return nil

//-----------------------------------------------------------------------------------------//
// keys while the inspector has focus; returns .T. when consumed

METHOD InspectorKey( nKey ) CLASS HbDesigner

   local aFields := ::InspFields()

   do case
      case nKey == K_ESC .or. nKey == K_F6
         ::lInspFocus = .F.
         ::ShowHint( HINT_CANVAS )
         ::DrawInspector()

      case nKey == K_F4
         ::ToggleInspector()

      case nKey == K_UP
         ::nInspField = Max( 1, ::nInspField - 1 )
         ::DrawInspector()

      case nKey == K_DOWN
         ::nInspField = Min( Len( aFields ), ::nInspField + 1 )
         ::DrawInspector()

      case nKey == K_LEFT
         ::InspAdjust( -1 )

      case nKey == K_RIGHT
         ::InspAdjust( 1 )

      case nKey == K_ENTER
         ::InspEdit()

      case nKey == K_CTRL_UP
         ::nInspRow = Max( 0, ::nInspRow - 1 )
         ::Redraw()

      case nKey == K_CTRL_DOWN
         ::nInspRow = ::nInspRow + 1
         ::Redraw()

      case nKey == K_CTRL_LEFT
         ::nInspCol = Max( 0, ::nInspCol - 1 )
         ::Redraw()

      case nKey == K_CTRL_RIGHT
         ::nInspCol = ::nInspCol + 1
         ::Redraw()

      otherwise
         return .F.
   endcase

return .T.

//-----------------------------------------------------------------------------------------//

METHOD GeneratePrg() CLASS HbDesigner

   local hModel := DsnBuildModel( Self )
   local nSkipped := 0, nConflicts := 0
   local cCode  := DsnGenCode( hModel, @nSkipped, @nConflicts )
   local cFile  := Lower( ::cDlgName ) + ".prg"

   if File( cFile )
      ::SuspendUI()
      if Alert( "Overwrite " + cFile + "?", { "Yes", "No" } ) != 1
         ::ResumeUI()
         return nil
      endif
      ::ResumeUI()
   endif

   hb_MemoWrit( cFile, cCode )
   ::ShowHint( "Generated " + cFile + ;
      If( nSkipped > 0, " (" + hb_ntos( nSkipped ) + " without items skipped)", "" ) + ;
      If( nConflicts > 0, " (" + hb_ntos( nConflicts ) + " name conflicts resolved)", "" ) )

return nil

//-----------------------------------------------------------------------------------------//
// Standalone helpers (no UI): model <-> JSON, code generation.
// Kept UI free so they can be reused and tested outside the IDE.
//-----------------------------------------------------------------------------------------//

function DsnBuildModel( oDesigner )

   local hModel := { "name"     => oDesigner:cDlgName, ;
                     "caption"  => oDesigner:cDlgCaption, ;
                     "width"    => oDesigner:nDlgWidth, ;
                     "height"   => oDesigner:nDlgHeight, ;
                     "color"    => oDesigner:cDlgColor, ;
                     "controls" => {} }
   local oCtrl

   for each oCtrl in oDesigner:aControls
      AAdd( hModel[ "controls" ], oCtrl )
   next

return hModel

//-----------------------------------------------------------------------------------------//
// size of a control in cells: { nWidth, nHeight }

function DsnControlSize( oCtrl )

   local nWidth := 1, nHeight := 1

   do case
      case oCtrl[ "type" ] == DSN_SAY
         nWidth = Max( 1, Len( hb_HGetDef( oCtrl, "caption", "" ) ) )
      case oCtrl[ "type" ] == DSN_GET
         nWidth = hb_HGetDef( oCtrl, "width", 10 )
      case oCtrl[ "type" ] == DSN_CHECKBOX
         nWidth = 4 + Len( StrTran( hb_HGetDef( oCtrl, "caption", "" ), "&", "" ) )
      case oCtrl[ "type" ] == DSN_BUTTON
         nWidth  = Len( hb_HGetDef( oCtrl, "caption", "" ) ) + 3
         nHeight = 2   // caption row + shadow row
      case oCtrl[ "type" ] == DSN_RADIO
         nWidth  = 8 + DsnMaxItemLen( oCtrl )
         nHeight = Len( DsnItems( oCtrl ) ) + 2
      case oCtrl[ "type" ] == DSN_LISTBOX
         nWidth  = hb_HGetDef( oCtrl, "width", 20 )
         nHeight = hb_HGetDef( oCtrl, "height", 6 )
   endcase

return { nWidth, nHeight }

//-----------------------------------------------------------------------------------------//
// items of a radiogroup/listbox as an array (CSV in the "items" property)

function DsnItems( oCtrl )

   local aItems := {}, cItem

   for each cItem in hb_ATokens( hb_HGetDef( oCtrl, "items", "" ), "," )
      cItem = AllTrim( cItem )
      if ! Empty( cItem )
         AAdd( aItems, cItem )
      endif
   next

return aItems

//-----------------------------------------------------------------------------------------//

function DsnMaxItemLen( oCtrl )

   local nMax := 0, cItem

   for each cItem in DsnItems( oCtrl )
      nMax = Max( nMax, Len( StrTran( cItem, "&", "" ) ) )
   next

return nMax

//-----------------------------------------------------------------------------------------//
// draw one control inside the design window (passive, design time only)
// nRow/nCol in the control hash are client relative (0 based)

procedure DsnDrawControl( oWnd, oCtrl, lSelected, cSelColor )

   local nARow := oWnd:nTop + 1 + oCtrl[ "row" ]
   local nACol := oWnd:nLeft + 1 + oCtrl[ "col" ]
   local nMaxCol := Min( oWnd:nRight - 1, MaxCol() )
   local cCaption := hb_HGetDef( oCtrl, "caption", "" )
   local cColor, cText, nWidth, n, aSize, aItems

   // design time: & marks accelerators on checkbox/button captions, so it is
   // not drawn there; SAY captions are literal (runtime Say shows & as-is)

   hb_default( @lSelected, .F. )
   hb_default( @cSelColor, CLR_SELECTED )

   if nARow <= oWnd:nTop .or. nARow >= oWnd:nBottom .or. ;
      nARow < 0 .or. nARow > MaxRow() .or. nACol > nMaxCol .or. nACol < 0
      return
   endif

   do case
      case oCtrl[ "type" ] == DSN_SAY
         cColor = If( lSelected, cSelColor, CLR_SAY )
         cText  = SubStr( cCaption, 1, Max( 0, nMaxCol - nACol + 1 ) )
         hb_DispOutAt( nARow, nACol, cText, cColor )

      case oCtrl[ "type" ] == DSN_GET
         cColor = If( lSelected, cSelColor, CLR_GET )
         nWidth = hb_HGetDef( oCtrl, "width", 10 )
         hb_DispOutAt( nARow, nACol, ;
            Replicate( Chr( 176 ), Min( nWidth, Max( 0, nMaxCol - nACol + 1 ) ) ), cColor )

      case oCtrl[ "type" ] == DSN_CHECKBOX
         cColor = If( lSelected, cSelColor, CLR_CHECKBOX )
         cText  = SubStr( "[ ] " + StrTran( cCaption, "&", "" ), 1, Max( 0, nMaxCol - nACol + 1 ) )
         hb_DispOutAt( nARow, nACol, cText, cColor )

      case oCtrl[ "type" ] == DSN_BUTTON
         cColor = If( lSelected, cSelColor, CLR_BUTTON )
         cText  = " " + StrTran( cCaption, "&", "" ) + " "
         nWidth = Len( cText )
         hb_DispOutAt( nARow, nACol, ;
            SubStr( cText, 1, Max( 0, nMaxCol - nACol + 1 ) ), cColor )
         // shadow: right cell + bottom row, same look as the runtime PushButton
         if nACol + nWidth <= nMaxCol
            hb_DispOutAt( nARow, nACol + nWidth, Chr( 220 ), "N/W" )
         endif
         if nARow + 1 < oWnd:nBottom .and. nARow + 1 <= MaxRow()
            n = Min( nWidth, Max( 0, nMaxCol - nACol ) )
            if n > 0
               hb_DispOutAt( nARow + 1, nACol + 1, Replicate( Chr( 223 ), n ), "N/W" )
            endif
         endif

      case oCtrl[ "type" ] == DSN_RADIO
         cColor = If( lSelected, cSelColor, CLR_CHECKBOX )
         aSize  = DsnControlSize( oCtrl )
         aItems = DsnItems( oCtrl )
         if nARow + aSize[ 2 ] - 1 < oWnd:nBottom .and. nACol + aSize[ 1 ] - 1 <= nMaxCol
            DispBox( nARow, nACol, nARow + aSize[ 2 ] - 1, nACol + aSize[ 1 ] - 1, 1, cColor )
         endif
         for n = 1 to Len( aItems )
            cText = If( n == 1, "(*) ", "( ) " ) + StrTran( aItems[ n ], "&", "" )
            if nARow + n < oWnd:nBottom .and. nARow + n <= MaxRow()
               hb_DispOutAt( nARow + n, nACol + 2, ;
                  SubStr( cText, 1, Max( 0, Min( aSize[ 1 ] - 4, nMaxCol - nACol - 1 ) ) ), cColor )
            endif
         next

      case oCtrl[ "type" ] == DSN_LISTBOX
         cColor = If( lSelected, cSelColor, CLR_GET )
         aSize  = DsnControlSize( oCtrl )
         aItems = DsnItems( oCtrl )
         if nARow + aSize[ 2 ] - 1 < oWnd:nBottom .and. nACol + aSize[ 1 ] - 1 <= nMaxCol
            DispBox( nARow, nACol, nARow + aSize[ 2 ] - 1, nACol + aSize[ 1 ] - 1, 1, cColor )
         endif
         for n = 1 to Min( Len( aItems ), aSize[ 2 ] - 2 )
            cText = PadR( SubStr( aItems[ n ], 1, aSize[ 1 ] - 2 ), aSize[ 1 ] - 2 )
            if nARow + n < oWnd:nBottom .and. nARow + n <= MaxRow()
               hb_DispOutAt( nARow + n, nACol + 1, ;
                  SubStr( cText, 1, Max( 0, nMaxCol - nACol ) ), If( n == 1, "N/W", cColor ) )
            endif
         next
   endcase

return

//-----------------------------------------------------------------------------------------//
// normalize a text into a valid Harbour identifier

function DsnValidVar( cText, cDefault )

   local cResult := "", cChar, n

   cText = AllTrim( hb_defaultValue( cText, "" ) )

   for n = 1 to Len( cText )
      cChar = SubStr( cText, n, 1 )
      if cChar $ "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
         cResult += cChar
      endif
   next

   if Empty( cResult ) .or. IsDigit( Left( cResult, 1 ) )
      cResult = hb_defaultValue( cDefault, "oVar" )
   endif

return cResult

//-----------------------------------------------------------------------------------------//
// generate the .prg that rebuilds the dialog with HBWindow.
// hModel is the hash produced by DsnBuildModel() (or read from JSON)

function DsnGenCode( hModel, nSkipped, nConflicts )

   local cCode := ""
   local oCtrl, n, aSize, cVar, cType, lNew
   local hDeclared := { => }   // variable name => bound type (C/L/N)
   local hGenVars  := { => }   // control index => variable name used (model untouched)
   local cName := hb_HGetDef( hModel, "name", "MyDialog" )

   nSkipped   = 0
   nConflicts = 0

   cCode += "//" + hb_eol()
   cCode += "// " + Lower( cName ) + ".prg - dialog generated by the HbIde designer" + hb_eol()
   cCode += "//" + hb_eol()
   cCode += hb_eol()
   cCode += "#include 'hbclass.ch'" + hb_eol()
   cCode += "#include 'inkey.ch'" + hb_eol()
   cCode += "#include 'setcurs.ch'" + hb_eol()
   cCode += hb_eol()
   cCode += "function Dlg_" + cName + "()" + hb_eol()
   cCode += hb_eol()
   cCode += "   local oDlg, GetList := {}, lOk := .F." + hb_eol()

   // variables used by the bound controls; a name is declared only once.
   // Two controls may share a name only when the type matches; a text GET
   // and a logical CHECKBOX with the same name get separate variables.
   for each oCtrl in hModel[ "controls" ]
      cType = DsnVarType( oCtrl )
      if cType == "" .or. ( oCtrl[ "type" ] $ DSN_RADIO + "|" + DSN_LISTBOX .and. Empty( DsnItems( oCtrl ) ) )
         loop
      endif
      lNew = .F.
      cVar = DsnResolveVar( hDeclared, oCtrl[ "variable" ], cType, @nConflicts, @lNew )
      hGenVars[ oCtrl:__enumIndex() ] = cVar
      if lNew
         do case
            case cType == "C"
               cCode += "   local " + cVar + " := Space( " + ;
                        hb_ntos( hb_HGetDef( oCtrl, "width", 10 ) ) + " )" + hb_eol()
            case cType == "L"
               cCode += "   local " + cVar + " := .F." + hb_eol()
            case cType == "N"
               cCode += "   local " + cVar + " := 1" + hb_eol()
         endcase
      endif
      do case
         case oCtrl[ "type" ] == DSN_RADIO
            cCode += "   local aButt" + hb_ntos( oCtrl:__enumIndex() ) + hb_eol()
         case oCtrl[ "type" ] == DSN_LISTBOX
            cCode += "   local aItems" + hb_ntos( oCtrl:__enumIndex() ) + hb_eol()
      endcase
   next

   cCode += "   local lDummy" + hb_eol()
   cCode += hb_eol()
   cCode += "   oDlg = HBWindow():Dialog( " + DsnQuote( hb_HGetDef( hModel, "caption", "Dialog" ) ) + ", " + ;
            hb_ntos( hb_HGetDef( hModel, "width", 40 ) ) + ", " + ;
            hb_ntos( hb_HGetDef( hModel, "height", 12 ) ) + ", " + ;
            DsnQuote( hb_HGetDef( hModel, "color", CLR_DIALOG ) ) + " )" + hb_eol()
   cCode += hb_eol()

   // item arrays for RADIOGROUP/LISTBOX reference the dialog position
   for each oCtrl in hModel[ "controls" ]
      do case
         case oCtrl[ "type" ] == DSN_RADIO
            if ! Empty( DsnItems( oCtrl ) )
               cCode += "   aButt" + hb_ntos( oCtrl:__enumIndex() ) + " := " + ;
                        DsnRadioButtsCode( oCtrl ) + hb_eol()
               cCode += "   AEval( aButt" + hb_ntos( oCtrl:__enumIndex() ) + ;
                        ", {| o | o:colorSpec := '" + DSN_CLR_RADIO + "' } )" + hb_eol()
            endif
         case oCtrl[ "type" ] == DSN_LISTBOX
            if ! Empty( DsnItems( oCtrl ) )
               cCode += "   aItems" + hb_ntos( oCtrl:__enumIndex() ) + " := " + ;
                        DsnItemsCode( oCtrl ) + hb_eol()
            endif
      endcase
   next
   cCode += hb_eol()

   n = 0
   for each oCtrl in hModel[ "controls" ]
      n++
      do case
         case oCtrl[ "type" ] == DSN_SAY
            cCode += "   oDlg:Say( " + hb_ntos( oCtrl[ "row" ] + 1 ) + ", " + ;
                     hb_ntos( oCtrl[ "col" ] + 1 ) + ", " + ;
                     DsnQuote( oCtrl[ "caption" ] ) + " )" + hb_eol()

         case oCtrl[ "type" ] == DSN_GET
            cCode += "   @ oDlg:nTop + " + hb_ntos( oCtrl[ "row" ] + 1 ) + ;
                     ", oDlg:nLeft + " + hb_ntos( oCtrl[ "col" ] + 1 ) + ;
                     " GET " + hGenVars[ n ] + ;
                     " COLOR '" + DSN_CLR_GET + "'" + hb_eol()

         case oCtrl[ "type" ] == DSN_CHECKBOX
            cCode += "   @ oDlg:nTop + " + hb_ntos( oCtrl[ "row" ] + 1 ) + ;
                     ", oDlg:nLeft + " + hb_ntos( oCtrl[ "col" ] + 1 ) + ;
                     " GET " + hGenVars[ n ] + ;
                     " CHECKBOX CAPTION " + DsnQuote( oCtrl[ "caption" ] ) + ;
                     " STYLE '[X ]'" + ;
                     " COLOR '" + DSN_CLR_CHECKBOX + "'" + hb_eol()

         case oCtrl[ "type" ] == DSN_BUTTON
            cCode += "   @ oDlg:nTop + " + hb_ntos( oCtrl[ "row" ] + 1 ) + ;
                     ", oDlg:nLeft + " + hb_ntos( oCtrl[ "col" ] + 1 ) + ;
                     " GET lDummy PUSHBUTTON CAPTION " + ;
                     DsnQuote( DsnAccelCaption( hb_HGetDef( oCtrl, "caption", "" ), ;
                        hb_HGetDef( oCtrl, "accelerator", "" ) ) ) + " ;" + hb_eol()
            cCode += "      COLOR '" + DSN_CLR_BUTTON + "' STATE { || " + ;
                     DsnButtonAction( oCtrl ) + " }" + hb_eol()

         case ( oCtrl[ "type" ] == DSN_RADIO .or. oCtrl[ "type" ] == DSN_LISTBOX ) .and. ;
               Empty( DsnItems( oCtrl ) )
            // an item-less radio/listbox cannot run: note it and skip it
            nSkipped++
            cCode += "   // skipped " + oCtrl[ "type" ] + " at row " + ;
                     hb_ntos( oCtrl[ "row" ] + 1 ) + ", col " + ;
                     hb_ntos( oCtrl[ "col" ] + 1 ) + ": no items" + hb_eol()

         case oCtrl[ "type" ] == DSN_RADIO .or. oCtrl[ "type" ] == DSN_LISTBOX
            aSize = DsnControlSize( oCtrl )
            cCode += "   @ oDlg:nTop + " + hb_ntos( oCtrl[ "row" ] + 1 ) + ;
                     ", oDlg:nLeft + " + hb_ntos( oCtrl[ "col" ] + 1 ) + ;
                     ", oDlg:nTop + " + hb_ntos( oCtrl[ "row" ] + aSize[ 2 ] ) + ;
                     ", oDlg:nLeft + " + hb_ntos( oCtrl[ "col" ] + aSize[ 1 ] ) + ;
                     " GET " + hGenVars[ n ] + ;
                     If( oCtrl[ "type" ] == DSN_RADIO, ;
                        " RADIOGROUP aButt", " LISTBOX aItems" ) + ;
                     hb_ntos( n ) + ;
                     If( oCtrl[ "type" ] == DSN_RADIO, ;
                        " COLOR 'N/W,N/W,GR+/W'", ;
                        " COLOR '" + DSN_CLR_LISTBOX + "'" ) + hb_eol()
      endcase
   next

   if n > 0
      cCode += hb_eol()
   endif

   cCode += "   oDlg:Activate( GetList )" + hb_eol()
   cCode += hb_eol()
   cCode += "return lOk" + hb_eol()

return cCode

//-----------------------------------------------------------------------------------------//

// caption with the & accelerator marker applied at the accelerator letter;
// if the letter is not in the caption it is appended so the key stays real

function DsnAccelCaption( cCaption, cAccel )

   local nPos

   cCaption = StrTran( hb_defaultValue( cCaption, "" ), "&", "" )
   cAccel   = Left( StrTran( AllTrim( hb_defaultValue( cAccel, "" ) ), "&", "" ), 1 )

   if ! Empty( cAccel )
      nPos = At( Upper( cAccel ), Upper( cCaption ) )
      if nPos > 0
         cCaption = Stuff( cCaption, nPos, 0, "&" )
      else
         cCaption += " (&" + cAccel + ")"
      endif
   endif

return cCaption

//-----------------------------------------------------------------------------------------//

// bound type of a control: C text, L logical, N numeric, "" unbound

function DsnVarType( oCtrl )

   do case
      case oCtrl[ "type" ] == DSN_GET      ; return "C"
      case oCtrl[ "type" ] == DSN_CHECKBOX ; return "L"
      case oCtrl[ "type" ] == DSN_RADIO .or. oCtrl[ "type" ] == DSN_LISTBOX
         return "N"
   endcase

return ""

//-----------------------------------------------------------------------------------------//
// declare cVar with cType; on a name clash with another type pick a free
// numbered variant and count the conflict

function DsnResolveVar( hDeclared, cVar, cType, nConflicts, lNew )

   local n, cNew

   if ! ( cVar $ hDeclared )
      hDeclared[ cVar ] = cType
      lNew = .T.
      return cVar
   endif
   if hDeclared[ cVar ] == cType
      return cVar   // same name, same type: share the variable
   endif

   nConflicts++
   n = 2
   cNew = cVar + hb_ntos( n )
   while cNew $ hDeclared
      n++
      cNew = cVar + hb_ntos( n )
   enddo
   hDeclared[ cNew ] = cType
   lNew = .T.

return cNew

//-----------------------------------------------------------------------------------------//

function DsnButtonAction( oCtrl )

   local cAction := AllTrim( hb_HGetDef( oCtrl, "action", "" ) )

return If( Empty( cAction ), "lOk := .T., oDlg:End()", cAction )

//-----------------------------------------------------------------------------------------//

// normalize controls read from JSON: drop foreign entries, coerce field
// types (hand-edited files may hold strings where numbers are expected) and
// migrate legacy button captions with & into the accelerator property

procedure DsnNormalizeControls( aControls )

   local oCtrl, nPos, cCaption, n, cType, cPrefix
   local cTypes := "|" + DSN_SAY + "|" + DSN_GET + "|" + DSN_CHECKBOX + "|" + ;
                   DSN_BUTTON + "|" + DSN_RADIO + "|" + DSN_LISTBOX + "|"

   // drop entries that are not usable controls
   for n = Len( aControls ) to 1 step -1
      oCtrl = aControls[ n ]
      cType = If( HB_IsHash( oCtrl ), hb_HGetDef( oCtrl, "type", "" ), "" )
      if ! HB_IsString( cType ) .or. ! ( "|" + cType + "|" $ cTypes )
         hb_ADel( aControls, n, .T. )
      endif
   next

   for each oCtrl in aControls
      // numeric geometry
      oCtrl[ "row" ] = Max( 0, Int( DsnNum( hb_HGetDef( oCtrl, "row", 0 ), 0 ) ) )
      oCtrl[ "col" ] = Max( 0, Int( DsnNum( hb_HGetDef( oCtrl, "col", 0 ), 0 ) ) )

      // text fields must be strings
      if "caption" $ oCtrl .and. ! HB_IsString( oCtrl[ "caption" ] )
         oCtrl[ "caption" ] = ""
      endif
      if "accelerator" $ oCtrl .and. ! HB_IsString( oCtrl[ "accelerator" ] )
         oCtrl[ "accelerator" ] = ""
      endif
      if "action" $ oCtrl .and. ! HB_IsString( oCtrl[ "action" ] )
         oCtrl[ "action" ] = ""
      endif

      // items accepts a CSV string or a JSON array of strings
      if oCtrl[ "type" ] $ DSN_RADIO + "|" + DSN_LISTBOX
         if HB_IsArray( hb_HGetDef( oCtrl, "items", "" ) )
            oCtrl[ "items" ] = DsnItemsFromArray( oCtrl[ "items" ] )
         elseif ! HB_IsString( oCtrl[ "items" ] )
            oCtrl[ "items" ] = ""
         endif
      endif

      // sizes with the same clamps as the properties dialog
      if oCtrl[ "type" ] == DSN_GET
         oCtrl[ "width" ] = Max( 4, Min( 40, Int( DsnNum( hb_HGetDef( oCtrl, "width", 10 ), 10 ) ) ) )
      endif
      if oCtrl[ "type" ] == DSN_LISTBOX
         oCtrl[ "width" ]  = Max( 4, Min( 40, Int( DsnNum( hb_HGetDef( oCtrl, "width", 20 ), 20 ) ) ) )
         oCtrl[ "height" ] = Max( 3, Min( 15, Int( DsnNum( hb_HGetDef( oCtrl, "height", 6 ), 6 ) ) ) )
      endif

      // every bound control needs a valid, non-empty variable name
      if oCtrl[ "type" ] $ DSN_GET + "|" + DSN_CHECKBOX + "|" + DSN_RADIO + "|" + DSN_LISTBOX
         cPrefix = If( oCtrl[ "type" ] == DSN_GET, "cVar", ;
                  If( oCtrl[ "type" ] == DSN_CHECKBOX, "lVar", "nVar" ) )
         if Empty( DsnValidVar( hb_HGetDef( oCtrl, "variable", "" ), "" ) )
            oCtrl[ "variable" ] = DsnUniqueVar( aControls, cPrefix )
         else
            oCtrl[ "variable" ] = DsnValidVar( oCtrl[ "variable" ], cPrefix )
         endif
      endif

      // legacy models keep the & inside the caption: move it to the accelerator property
      if oCtrl[ "type" ] == DSN_BUTTON
         cCaption = hb_HGetDef( oCtrl, "caption", "" )
         if ( nPos := At( "&", cCaption ) ) > 0
            if Empty( hb_HGetDef( oCtrl, "accelerator", "" ) )
               oCtrl[ "accelerator" ] = SubStr( cCaption, nPos + 1, 1 )
            endif
            oCtrl[ "caption" ] = StrTran( cCaption, "&", "" )
         endif
      endif
   next

return

//-----------------------------------------------------------------------------------------//
// model read from JSON is usable: a hash with an array of controls

function DsnValidModel( hModel )

return HB_IsHash( hModel ) .and. "controls" $ hModel .and. HB_IsArray( hModel[ "controls" ] )

//-----------------------------------------------------------------------------------------//
// first free variable name with a prefix: cVar1, cVar2, ...

function DsnUniqueVar( aControls, cPrefix )

   local n := 1

   while DsnVarUsed( aControls, cPrefix + hb_ntos( n ) )
      n++
   enddo

return cPrefix + hb_ntos( n )

//-----------------------------------------------------------------------------------------//

static function DsnValidColor( cColor )

   local cItem, aPair, cTok

   if Empty( cColor ) .or. Len( cColor ) > 30
      return .F.
   endif

   // no empty items: reject leading/trailing/doubled separators
   if Left( cColor, 1 ) $ ",/" .or. Right( cColor, 1 ) $ ",/"
      return .F.
   endif
   if ",," $ cColor .or. "//" $ cColor .or. ",/" $ cColor .or. "/," $ cColor
      return .F.
   endif

   // each comma item is one color pair: "fg" or "fg/bg"
   for each cItem in hb_aTokens( cColor, "," )
      aPair = hb_aTokens( cItem, "/" )
      if Empty( cItem ) .or. Len( aPair ) > 2
         return .F.
      endif
      for each cTok in aPair
         if ! DsnValidColorToken( cTok )
            return .F.
         endif
      next
   next

return .T.

//-----------------------------------------------------------------------------------------//

// one side of a color pair: Harbour color letters, then optional + (bright) / * (blink)
static function DsnValidColorToken( cTok )

   local n, c, lMod := .F.

   if Empty( cTok ) .or. Len( cTok ) > 6
      return .F.
   endif

   for n = 1 to Len( cTok )
      c = Upper( SubStr( cTok, n, 1 ) )
      if c $ "+*"
         lMod := .T.
      elseif c $ "WBGRNCMYUIX"
         if lMod
            return .F.
         endif
      else
         return .F.
      endif
   next

   if lMod .and. Len( cTok ) == 1
      return .F.
   endif

return .T.

//-----------------------------------------------------------------------------------------//

static function DsnVarUsed( aControls, cName )

   local oCtrl

   for each oCtrl in aControls
      if HB_IsHash( oCtrl ) .and. hb_HGetDef( oCtrl, "variable", "" ) == cName
         return .T.
      endif
   next

return .F.

//-----------------------------------------------------------------------------------------//
// JSON array of strings -> CSV "items" property

function DsnItemsFromArray( aItems )

   local cResult := "", u

   for each u in aItems
      if HB_IsString( u ) .and. ! Empty( AllTrim( u ) )
         cResult += If( Empty( cResult ), "", "," ) + AllTrim( u )
      endif
   next

return cResult

//-----------------------------------------------------------------------------------------//
// coercions for values read from hand-edited JSON

static function DsnStr( u, cDefault )

return If( HB_IsString( u ), u, cDefault )

//-----------------------------------------------------------------------------------------//

static function DsnNum( u, nDefault )

   local c, n, lOk

   if HB_IsString( u )
      // digit strings are coerced, anything else falls back to the default
      c = AllTrim( u )
      lOk = ! Empty( c )
      for n = 1 to Len( c )
         if ! IsDigit( SubStr( c, n, 1 ) )
            lOk = .F.
            exit
         endif
      next
      u = If( lOk, Val( c ), nDefault )
   endif

return If( HB_IsNumeric( u ), u, nDefault )

//-----------------------------------------------------------------------------------------//

// { "One", "Two" } literal for a control's items

static function DsnItemsCode( oCtrl )

   local aItems := DsnItems( oCtrl )
   local cCode  := "{", n

   for n = 1 to Len( aItems )
      cCode += If( n > 1, ", ", " " ) + DsnQuote( aItems[ n ] )
   next

return cCode + If( Len( aItems ) > 0, " }", "}" )

//-----------------------------------------------------------------------------------------//
// array of RadioButto() objects matching a radiogroup control's position and items

static function DsnRadioButtsCode( oCtrl )

   local aItems := DsnItems( oCtrl )
   local cCode  := "{", n

   for n = 1 to Len( aItems )
      cCode += If( n > 1, ", ", " " ) + "RadioButto( oDlg:nTop + " + ;
               hb_ntos( oCtrl[ "row" ] + 1 + n ) + ", oDlg:nLeft + " + ;
               hb_ntos( oCtrl[ "col" ] + 3 ) + ", " + DsnQuote( aItems[ n ] ) + " )"
   next

return cCode + If( Len( aItems ) > 0, " }", "}" )

//-----------------------------------------------------------------------------------------//

static function DsnQuote( cText )

return '"' + StrTran( hb_defaultValue( cText, "" ), '"', "'" ) + '"'

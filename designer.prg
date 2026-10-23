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

#define CLR_DIALOG    "W+/W"
#define CLR_SAY       "N/W"
#define CLR_GET       "W/B"
#define CLR_BUTTON    "GR+/G"
#define CLR_CHECKBOX  "N/W"
#define CLR_SELECTED  "N/G"
#define CLR_GHOST     "N/BG"

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
   DATA nIdleDraw                     // idle handler: redraw controls
   DATA nOldCursor
   DATA cHint        INIT "F2 add | Enter edit | Del delete | Arrows move | F9 generate | F10 save | Esc exit"

   METHOD New( oIde )
   METHOD Activate()

   METHOD AddControl( cType )
   METHOD DeleteSelected()
   METHOD DlgProperties()
   METHOD DragControl( nIndex, nMRow, nMCol )
   METHOD DrawControls()
   METHOD EditProperties()
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

   local nKey, nIndex

   ::nOldCursor = SetCursor( SC_NONE )
   ::oIde:SuspendStatus()

   ::oWnd = HBWindow():Dialog( ::cDlgCaption, ::nDlgWidth, ::nDlgHeight, ::cDlgColor )
   ::oWnd:bRepaint = { || ::oIde:Repaint() }
   ::oWnd:lDesign  = .T.
   ::oWnd:bPopup   = { || ::PopupMenu() }

   ::nIdleDraw = hb_IdleAdd( { || ::DrawControls() } )

   ::ShowHint( "F2 add | Enter edit | Del delete | Arrows move | F9 generate | F10 save | Esc exit" )

   while ! ::lEnd

      nKey = InKey( 0, INKEY_ALL )

      do case
         case nKey == K_ESC
            if ::lPlacing
               ::lPlacing = .F.
            elseif ! ::lDirty .or. Alert( "Discard unsaved changes?", { "Yes", "No" } ) == 1
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
            else
               ::MoveSelected( -1, 0 )
            endif

         case nKey == K_DOWN
            if ::lPlacing
               ::nGhostRow = Min( ::oWnd:nBottom - ::oWnd:nTop - 2, ::nGhostRow + 1 )
            else
               ::MoveSelected( 1, 0 )
            endif

         case nKey == K_LEFT
            if ::lPlacing
               ::nGhostCol = Max( 0, ::nGhostCol - 1 )
            else
               ::MoveSelected( 0, -1 )
            endif

         case nKey == K_RIGHT
            if ::lPlacing
               ::nGhostCol = Min( ::oWnd:nRight - ::oWnd:nLeft - 2, ::nGhostCol + 1 )
            else
               ::MoveSelected( 0, 1 )
            endif

         case nKey == K_TAB
            if ! Empty( ::aControls )
               ::nSelected = If( ::nSelected >= Len( ::aControls ), 1, ::nSelected + 1 )
            endif

         case nKey == K_SH_TAB
            if ! Empty( ::aControls )
               ::nSelected = If( ::nSelected <= 1, Len( ::aControls ), ::nSelected - 1 )
            endif

         case nKey == K_LBUTTONDOWN
            if ::lPlacing
               if ::HitClient( MRow(), MCol() )
                  ::nGhostRow = MRow() - ::oWnd:nTop - 1
                  ::nGhostCol = MCol() - ::oWnd:nLeft - 1
                  ::AddControl( ::cPlacingType )
               endif
            else
               nIndex = ::HitTest( MRow(), MCol() )
               if nIndex > 0
                  ::nSelected = nIndex
                  ::DragControl( nIndex, MRow(), MCol() )
               else
                  ::nSelected = 0
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
      MENUITEM "Push~Button"               ACTION cType := DSN_BUTTON
      SEPARATOR
      MENUITEM "~Dialog properties..."     ACTION cType := "dialog"
      SEPARATOR
      MENUITEM "~Save JSON    F10"         ACTION cType := "save"
      MENUITEM "~Open JSON    F12"         ACTION cType := "open"
      MENUITEM "~Generate PRG  F9"         ACTION cType := "gen"
   ENDMENU

   // normalize popup geometry (menu builder defaults do not fit 9 items)
   oPopup:nTop    = 21
   oPopup:nLeft   = 30
   oPopup:nRight  = 62
   oPopup:nBottom = oPopup:nTop + Len( oPopup:aItems ) + 1
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
         oCtrl[ "variable" ] = "cVar" + hb_ntos( Len( ::aControls ) + 1 )
         oCtrl[ "width"    ] = 10
      case cType == DSN_CHECKBOX
         oCtrl[ "caption"  ] = "Check"
         oCtrl[ "variable" ] = "lVar" + hb_ntos( Len( ::aControls ) + 1 )
      case cType == DSN_BUTTON
         oCtrl[ "caption"  ] = "&OK"
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

   local oCtrl, oDlg, GetList := {}, lOk := .F., lDummy
   local cCaption, cVariable, nRow, nCol, nWidth
   local aSize, nMaxRow, nMaxCol

   if ::nSelected < 1 .or. ::nSelected > Len( ::aControls )
      return nil
   endif

   oCtrl     = ::aControls[ ::nSelected ]
   aSize     = DsnControlSize( oCtrl )
   nMaxRow   = ::oWnd:nBottom - ::oWnd:nTop - 1 - aSize[ 2 ]
   nMaxCol   = ::oWnd:nRight  - ::oWnd:nLeft - 1 - aSize[ 1 ]
   cCaption  = PadR( hb_HGetDef( oCtrl, "caption", "" ), 30 )
   cVariable = PadR( hb_HGetDef( oCtrl, "variable", "" ), 20 )
   nRow      = oCtrl[ "row" ]
   nCol      = oCtrl[ "col" ]
   nWidth    = hb_HGetDef( oCtrl, "width", 10 )

   ::SuspendUI()

   oDlg = HBWindow():Dialog( "Control properties", 44, 11, CLR_DIALOG )
   oDlg:bRepaint = { || ::Redraw() }

   @ oDlg:nTop + 2, oDlg:nLeft + 11 GET nRow PICTURE "999"
   @ oDlg:nTop + 2, oDlg:nLeft + 25 GET nCol PICTURE "999"
   oDlg:Say( 2, 2, "Row:" )
   oDlg:Say( 2, 20, "Col:" )

   if oCtrl[ "type" ] $ DSN_SAY + "|" + DSN_BUTTON + "|" + DSN_CHECKBOX
      @ oDlg:nTop + 4, oDlg:nLeft + 11 GET cCaption
      oDlg:Say( 4, 2, "Caption:" )
   endif

   if oCtrl[ "type" ] $ DSN_GET + "|" + DSN_CHECKBOX
      @ oDlg:nTop + 5, oDlg:nLeft + 11 GET cVariable
      oDlg:Say( 5, 2, "Variable:" )
   endif

   if oCtrl[ "type" ] == DSN_GET
      @ oDlg:nTop + 6, oDlg:nLeft + 11 GET nWidth PICTURE "999"
      oDlg:Say( 6, 2, "Width:" )
   endif

   @ oDlg:nBottom - 2, oDlg:nLeft + 10 GET lDummy PUSHBUTTON ;
      CAPTION "  &OK  " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nLeft + 24 GET lDummy PUSHBUTTON ;
      CAPTION " &Cancel " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeUI()

   if lOk
      oCtrl[ "row" ] = Max( 0, Min( nMaxRow, nRow ) )
      oCtrl[ "col" ] = Max( 0, Min( nMaxCol, nCol ) )
      if "caption" $ oCtrl
         oCtrl[ "caption" ] = AllTrim( cCaption )
      endif
      if "variable" $ oCtrl
         oCtrl[ "variable" ] = DsnValidVar( cVariable, ;
            If( oCtrl[ "type" ] == DSN_GET, "cVar", "lVar" ) + ;
            hb_ntos( ::nSelected ) )
      endif
      if "width" $ oCtrl
         oCtrl[ "width" ] = Max( 4, Min( 40, nWidth ) )
      endif
      ::lDirty = .T.
      ::Redraw()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD DlgProperties() CLASS HbDesigner

   local oDlg, GetList := {}, lOk := .F., lDummy
   local cCaption := PadR( ::cDlgCaption, 30 )
   local cName    := PadR( ::cDlgName, 20 )
   local nWidth   := ::nDlgWidth
   local nHeight  := ::nDlgHeight

   ::SuspendUI()

   oDlg = HBWindow():Dialog( "Dialog properties", 44, 10, CLR_DIALOG )
   oDlg:bRepaint = { || ::Redraw() }

   @ oDlg:nTop + 2, oDlg:nLeft + 11 GET cCaption
   oDlg:Say( 2, 2, "Caption:" )

   @ oDlg:nTop + 4, oDlg:nLeft + 11 GET cName
   oDlg:Say( 4, 2, "Name:" )

   @ oDlg:nTop + 6, oDlg:nLeft + 11 GET nWidth PICTURE "999"
   oDlg:Say( 6, 2, "Width:" )

   @ oDlg:nTop + 6, oDlg:nLeft + 27 GET nHeight PICTURE "999"
   oDlg:Say( 6, 20, "Height:" )

   @ oDlg:nBottom - 2, oDlg:nLeft + 10 GET lDummy PUSHBUTTON ;
      CAPTION "  &OK  " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nLeft + 24 GET lDummy PUSHBUTTON ;
      CAPTION " &Cancel " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeUI()

   if lOk
      ::cDlgCaption = AllTrim( cCaption )
      ::cDlgName    = DsnValidVar( cName, "MyDialog" )
      ::nDlgWidth   = Max( 20, Min( MaxCol() - 4, nWidth ) )
      ::nDlgHeight  = Max( 6, Min( MaxRow() - 3, nHeight ) )
      with object ::oWnd
         :nRight   = :nLeft + ::nDlgWidth - 1
         :nBottom  = :nTop + ::nDlgHeight - 1
         :cCaption = " " + ::cDlgCaption + " "
      end
      ::lDirty = .T.
      ::Redraw()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD SelectFileName( cTitle, cDefault ) CLASS HbDesigner

   local oDlg, GetList := {}, lOk := .F., lDummy
   local cFile := PadR( cDefault, 35 )

   ::SuspendUI()

   oDlg = HBWindow():Dialog( cTitle, 45, 7, CLR_DIALOG )
   oDlg:bRepaint = { || ::Redraw() }

   @ oDlg:nTop + 2, oDlg:nLeft + 8 GET cFile
   oDlg:Say( 2, 2, "File:" )

   @ oDlg:nBottom - 2, oDlg:nLeft + 14 GET lDummy PUSHBUTTON ;
      CAPTION "  &OK  " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nLeft + 28 GET lDummy PUSHBUTTON ;
      CAPTION " &Cancel " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeUI()

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

   local cFile, cJson, hModel := nil

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

   if ! HB_IsHash( hModel ) .or. ! ( "controls" $ hModel )
      ::ShowHint( "Invalid dialog JSON: " + cFile )
      return nil
   endif

   ::cDlgName    = hb_HGetDef( hModel, "name", "MyDialog" )
   ::cDlgCaption = hb_HGetDef( hModel, "caption", "My Dialog" )
   ::cDlgColor   = hb_HGetDef( hModel, "color", CLR_DIALOG )
   ::nDlgWidth   = hb_HGetDef( hModel, "width", 40 )
   ::nDlgHeight  = hb_HGetDef( hModel, "height", 12 )
   ::aControls   = hModel[ "controls" ]
   ::nSelected   = 0
   ::cFileName   = cFile
   ::lDirty      = .F.

   with object ::oWnd
      :nRight   = :nLeft + ::nDlgWidth - 1
      :nBottom  = :nTop + ::nDlgHeight - 1
      :cCaption = " " + ::cDlgCaption + " "
      :cColor   = ::cDlgColor
   end

   ::Redraw()
   ::ShowHint( "Loaded " + cFile )

return nil

//-----------------------------------------------------------------------------------------//

METHOD GeneratePrg() CLASS HbDesigner

   local hModel := DsnBuildModel( Self )
   local cCode  := DsnGenCode( hModel )
   local cFile  := Lower( ::cDlgName ) + ".prg"

   hb_MemoWrit( cFile, cCode )
   ::ShowHint( "Generated " + cFile )

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
         nWidth = 4 + Len( hb_HGetDef( oCtrl, "caption", "" ) )
      case oCtrl[ "type" ] == DSN_BUTTON
         nWidth  = Len( hb_HGetDef( oCtrl, "caption", "" ) ) + 3
         nHeight = 2   // caption row + shadow row
   endcase

return { nWidth, nHeight }

//-----------------------------------------------------------------------------------------//
// draw one control inside the design window (passive, design time only)
// nRow/nCol in the control hash are client relative (0 based)

procedure DsnDrawControl( oWnd, oCtrl, lSelected, cSelColor )

   local nARow := oWnd:nTop + 1 + oCtrl[ "row" ]
   local nACol := oWnd:nLeft + 1 + oCtrl[ "col" ]
   local nMaxCol := Min( oWnd:nRight - 1, MaxCol() )
   local cCaption := hb_HGetDef( oCtrl, "caption", "" )
   local cColor, cText, nWidth, n

   // design time: captions are shown without the & accelerator marker
   cCaption = StrTran( cCaption, "&", "" )

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
         cText  = SubStr( "[ ] " + cCaption, 1, Max( 0, nMaxCol - nACol + 1 ) )
         hb_DispOutAt( nARow, nACol, cText, cColor )

      case oCtrl[ "type" ] == DSN_BUTTON
         cColor = If( lSelected, cSelColor, CLR_BUTTON )
         cText  = " " + cCaption + " "
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

function DsnGenCode( hModel )

   local cCode := ""
   local oCtrl, n
   local cName := hb_HGetDef( hModel, "name", "MyDialog" )

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

   // variables used by GETs and CHECKBOXes
   for each oCtrl in hModel[ "controls" ]
      do case
         case oCtrl[ "type" ] == DSN_GET
            cCode += "   local " + oCtrl[ "variable" ] + " := Space( " + ;
                     hb_ntos( hb_HGetDef( oCtrl, "width", 10 ) ) + " )" + hb_eol()
         case oCtrl[ "type" ] == DSN_CHECKBOX
            cCode += "   local " + oCtrl[ "variable" ] + " := .F." + hb_eol()
      endcase
   next

   cCode += "   local lDummy" + hb_eol()
   cCode += hb_eol()
   cCode += "   oDlg = HBWindow():Dialog( " + DsnQuote( hb_HGetDef( hModel, "caption", "Dialog" ) ) + ", " + ;
            hb_ntos( hb_HGetDef( hModel, "width", 40 ) ) + ", " + ;
            hb_ntos( hb_HGetDef( hModel, "height", 12 ) ) + ", " + ;
            DsnQuote( hb_HGetDef( hModel, "color", CLR_DIALOG ) ) + " )" + hb_eol()
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
                     " GET " + oCtrl[ "variable" ] + hb_eol()

         case oCtrl[ "type" ] == DSN_CHECKBOX
            cCode += "   @ oDlg:nTop + " + hb_ntos( oCtrl[ "row" ] + 1 ) + ;
                     ", oDlg:nLeft + " + hb_ntos( oCtrl[ "col" ] + 1 ) + ;
                     " GET " + oCtrl[ "variable" ] + ;
                     " CHECKBOX CAPTION " + DsnQuote( oCtrl[ "caption" ] ) + hb_eol()

         case oCtrl[ "type" ] == DSN_BUTTON
            cCode += "   @ oDlg:nTop + " + hb_ntos( oCtrl[ "row" ] + 1 ) + ;
                     ", oDlg:nLeft + " + hb_ntos( oCtrl[ "col" ] + 1 ) + ;
                     " GET lDummy PUSHBUTTON CAPTION " + DsnQuote( oCtrl[ "caption" ] ) + " ;" + hb_eol()
            cCode += "      COLOR 'GR+/G,W+/G,N/G,BG+/G' STATE { || lOk := .T., oDlg:End() }" + hb_eol()
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

static function DsnQuote( cText )

return '"' + StrTran( hb_defaultValue( cText, "" ), '"', "'" ) + '"'

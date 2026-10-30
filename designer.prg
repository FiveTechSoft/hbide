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

#define DSN_SNAP_ROW   2     // F7 snap grid step in rows
#define DSN_SNAP_COL   2     // F7 snap grid step in cols
//
// Private loop key codes, produced by DsnNormKey() from HB_INKEY_EXT input.
// The classic inkey.ch codes collide (K_DOWN == K_CTRL_X == 24,
// K_CTRL_LEFT == K_CTRL_Z, K_CTRL_RIGHT == K_CTRL_B, K_UP == K_CTRL_E,
// K_LEFT == K_CTRL_S, K_CTRL_V == Ins), and a do-case picks the first match,
// so classic input can fire the wrong action (Down ran CutSelected).
// HB_INKEY_EXT gives every key a distinct code; Ctrl+letters normalize to
// DSNK_CTRL_BASE + (letter - "A") and Ctrl+Left/Right to their own codes.
#define DSNK_CTRL_BASE   9100
#define DSNK_CTRL_Z      ( DSNK_CTRL_BASE + 25 )
#define DSNK_CTRL_Y      ( DSNK_CTRL_BASE + 24 )
#define DSNK_CTRL_C      ( DSNK_CTRL_BASE + 2 )
#define DSNK_CTRL_X      ( DSNK_CTRL_BASE + 23 )
#define DSNK_CTRL_V      ( DSNK_CTRL_BASE + 21 )
#define DSNK_CTRLLEFT    9201
#define DSNK_CTRLRIGHT   9202

#define DSN_SAY       "say"
#define DSN_GET       "get"
#define DSN_BUTTON    "button"
#define DSN_CHECKBOX  "checkbox"
#define DSN_RADIO     "radiogroup"
#define DSN_LISTBOX   "listbox"
#define DSN_COMBOBOX  "combobox"

// control palettes for the generated dialog, from hbide's own dialogs
// (white dialog background: input GET from hbide.prg, listbox exact hbide palette)
#define DSN_CLR_GET      "W/B,W+/B,W+/W,GR+/W"
#define DSN_CLR_CHECKBOX "N/W,BG+/W,N/W,GR+/W"
#define DSN_CLR_BUTTON   "GR+/G,W+/G,N/G,BG+/G"
#define DSN_CLR_RADIO    "N/BG,N/BG,N/BG,N+/BG,N/BG,GR+/BG,R+/BG"
#define DSN_CLR_LISTBOX  "N/BG,N+/BG,N/BG,W+/G,N/BG,W+/BG,GR+/BG"
#define DSN_CLR_AREA     "N/BG"   // celeste area: radiogroup interior and listbox background
#define DSN_CLR_AREAKEY  "R+/BG"  // accelerator letter on the celeste area

#define CLR_DIALOG    "W+/W"
#define DSN_CLR_FOCUS "W+/B"   // default focused-control pair (stock palettes keep it)
#define CLR_SAY       "N/W"
#define CLR_GET       "W/B"
#define CLR_BUTTON    "GR+/G"
#define CLR_CHECKBOX  "N/W"
#define CLR_SELECTED  "N/G"
#define CLR_SEL_BTN   "GR+/N"   // editor-only selection look for buttons (never emitted)
#define CLR_GHOST     "N/BG"
#define CLR_CODEVIEW  "W/B"
#define CLR_CODEVIEW_HL "N/BG"

#define CLR_INSP      "W+/B"
#define CLR_INSP_SEL  "N/GR"
#define CLR_INSP_VAL  "N/W"

#define HINT_CANVAS   "F2 add Enter edit F4 insp F5 prg Del Arrows move ^Z/^Y F9 gen F10 save Esc"
#define HINT_CODEVIEW "F5 close | +/- scroll | ,/. pan | read-only: manual code is never touched"
#define HINT_INSP     "F6 canvas | Enter edit | Left/Right adjust | Ctrl+Arrows move panel | F4 hide"

//-----------------------------------------------------------------------------------------//

CLASS HbDesigner

   DATA oIde                          // HbIde instance (Repaint(), MsgInfo())
   DATA oWnd                          // HbWindow used as design canvas
   DATA aControls    INIT {}          // array of hashes, one per control
   DATA nSelected    INIT 0           // 1-based index in aControls, 0 = none
   DATA cDlgName     INIT "MyDialog"
   DATA cDlgCaption  INIT "My Dialog"
   DATA cDlgClrText  INIT "W+"        // dialog text color (foreground)
   DATA cDlgClrBack  INIT "W"         // dialog background color
   DATA cDlgClrFocus INIT DSN_CLR_FOCUS   // focused-control color pair
   // virtual combined colorspec: reads compose text/back, writes split
   ACCESS cDlgColor INLINE ::cDlgClrText + "/" + ::cDlgClrBack
   ASSIGN cDlgColor( c ) INLINE DsnAssignDlgColor( Self, c )
   DATA nDlgWidth    INIT 40
   DATA nDlgHeight   INIT 12
   DATA cFileName    INIT ""          // last JSON file used
   DATA lDirty       INIT .F.
   DATA lEnd         INIT .F.
   DATA lPlacing     INIT .F.         // placing a new control
   DATA lViewClamp   INIT .F.         // design window is smaller than the dialog (viewport clamp)
   DATA nViewRow     INIT 0           // model coords shown at the window's client origin (pan)
   DATA nViewCol     INIT 0
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
   DATA aUndo        INIT {}          // undo history (model snapshots)
   DATA aRedo        INIT {}          // redo history
   DATA hPending                      // pre-burst snapshot (moves, drags, adjusts)
   DATA lPendingUsed INIT .T.         // hPending already consumed or invalid
   DATA lMoveArmed   INIT .T.         // next move/adjust starts a new undo burst
   DATA oClipboard                    // last copied/cut control (detached clone)
   DATA nPasteCount  INIT 0           // consecutive pastes: each drops one cell off
   DATA lSnap       INIT .F.          // F7: snap positions/sizes to the grid
   DATA lCodeView   INIT .F.          // F5: live read-only PRG view visible
   DATA aCodeLines  INIT {}           // last generated code, split into lines
   DATA nCodeTop    INIT 1            // first code line shown in the view
   DATA nCodeLeft   INIT 1            // first code column shown in the view
   DATA nCodeAnchor INIT 0            // generated line of the selected control
   DATA cCodeSig    INIT ""           // model+selection signature of aCodeLines

   METHOD New( oIde )
   METHOD Activate()

   METHOD AddControl( cType )
   METHOD DeleteSelected()
   METHOD PushHistory()
   METHOD PushSnapshot( hSnap )
   METHOD BeginBurst()
   METHOD CommitBurst()
   METHOD ApplySnapshot( hSnap )
   METHOD Undo()
   METHOD Redo()
   METHOD CopySelected()
   METHOD CutSelected()
   METHOD PasteClipboard()
   METHOD ToggleSnap()
   METHOD SnapPos( nRow, nCol )
   METHOD DlgProperties()
   METHOD FitWindow()
   METHOD DragControl( nIndex, nMRow, nMCol )
   METHOD DragResize( nIndex )
   METHOD HandleHit( nMRow, nMCol )
   METHOD ResizeHandlePos()
   METHOD DrawControls()
   METHOD EditProperties()
   METHOD ToggleInspector()
   METHOD InspFields()
   METHOD InspRect()
   METHOD DrawInspector()
   METHOD DrawCodeView()
   METHOD RefreshCodeView()
   METHOD DlgMinSize()
   METHOD InspValue( cKey )
   METHOD InspSetText( cKey, cVal )
   METHOD InspAdjust( nDelta )
   METHOD InspCycle( nDelta )
   METHOD InspEdit()
   METHOD InspPickColor()
   METHOD InspHit( nMRow, nMCol )
   METHOD DragInspector( nMRow, nMCol )
   METHOD InspectorKey( nKey )
   METHOD GeneratePrg()
   METHOD GenerateAndOpen()
   METHOD HitClient( nMRow, nMCol )
   METHOD HitTest( nMRow, nMCol )
   METHOD LoadJson()
   METHOD ApplyModel( hModel )
   METHOD MoveSelected( nDRow, nDCol )
   METHOD PanView( nDRow, nDCol )
   METHOD EnsureSelectedVisible()
   METHOD PopupMenu()
   METHOD Redraw()
   METHOD RegisterIdles()
   METHOD ClampGhost()
   METHOD ResumeUI()
   METHOD SaveJson( lAskName )
   METHOD SelectFileName( cTitle, cDefault )
   METHOD ShowHint( cText )
   METHOD HintUndoRefresh()
   METHOD SuspendUI()

ENDCLASS

//-----------------------------------------------------------------------------------------//

METHOD New( oIde ) CLASS HbDesigner

   ::oIde = oIde

return Self

//-----------------------------------------------------------------------------------------//

METHOD Activate() CLASS HbDesigner

   local nKey, nIndex, nInspHit, nChoice, cEsc

   ::nOldCursor = SetCursor( SC_NONE )
   ::oIde:SuspendStatus()

   ::oWnd = HBWindow():Dialog( ::cDlgCaption, ::nDlgWidth, ::nDlgHeight, ::cDlgColor )
   ::oWnd:bRepaint   = { || ::Redraw() }
   ::oWnd:bAfterDrag = { || ::RegisterIdles(), ::Redraw() }
   ::oWnd:lDesign  = .T.
   ::oWnd:nMaxBottom = MaxRow() - 1   // keep the status bar row clear
   ::oWnd:bPopup   = { || ::PopupMenu() }

   // HBWindow():Dialog() centers with a half-size convention, so the window
   // spans one cell more than the requested size; normalize it to the model
   // size so the canvas, the F3 values and the saved JSON agree
   ::FitWindow()

   ::RegisterIdles()

   ::ShowHint( HINT_CANVAS )
   DsnTrace( "DSN start max=" + Str( MaxRow(), 3 ) + "," + Str( MaxCol(), 4 ) )

   while ! ::lEnd

      nKey = DsnNormKey( InKey( 0, INKEY_ALL + HB_INKEY_EXT ) )

      // a burst of arrow moves/adjusts is a single undo step; any other
      // key (selection change, action, pan) re-arms the burst capture
      if nKey != K_UP .and. nKey != K_DOWN .and. nKey != K_LEFT .and. nKey != K_RIGHT
         ::lMoveArmed = .T.
      endif

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
            cEsc = DsnEscTarget( ::lPlacing, ::lInspector, ::lDirty, ::lCodeView )
            if cEsc == "placing"
               ::lPlacing = .F.
            elseif cEsc == "inspector"
               // close the panel before offering to exit
               ::ToggleInspector()
            elseif cEsc == "codeview"
               // close the live PRG view before offering to exit
               ::lCodeView = .F.
               ::ShowHint( HINT_CANVAS )
               ::Redraw()
            elseif cEsc == "dirty"
               ::SuspendUI()
               nChoice = DsnConfirm( "Discard unsaved changes?", { "&Yes", "&No" } )
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

         case nKey == K_F11
            ::SaveJson( .T. )

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

         case nKey == DSNK_CTRL_Z .or. nKey == K_CTRL_Z
            if ! ::lPlacing
               ::Undo()
            endif

         case nKey == DSNK_CTRL_Y .or. nKey == K_CTRL_Y
            if ! ::lPlacing
               ::Redo()
            endif

         case nKey == DSNK_CTRL_C .or. nKey == K_CTRL_C
            if ! ::lPlacing
               ::CopySelected()
            endif

         case nKey == DSNK_CTRL_X   // EXT only: classic 24 aliases K_DOWN; the arrow case below claims it (move wins over cut without EXT)
            if ! ::lPlacing
               ::CutSelected()
            endif

         case nKey == DSNK_CTRL_V .or. nKey == K_CTRL_V
            if ! ::lPlacing
               ::PasteClipboard()
            endif

         case nKey == K_F7
            ::ToggleSnap()

         case nKey == K_F5
            if ! ::lPlacing
               ::lCodeView = ! ::lCodeView
               if ::lCodeView
                  ::cCodeSig = ""   // force regeneration on the next draw
                  ::ShowHint( HINT_CODEVIEW )
               else
                  ::ShowHint( HINT_CANVAS )
               endif
               ::Redraw()
            endif

         case nKey == K_PGUP .or. ( ::lCodeView .and. nKey == Asc( "-" ) )
            if ::lCodeView
               ::nCodeTop = Max( 1, ::nCodeTop - ( MaxRow() - 3 ) )
               ::DrawCodeView()
            endif

         case ::lCodeView .and. nKey == Asc( "," )
            ::nCodeLeft = Max( 1, ::nCodeLeft - 8 )
            ::Redraw()
         case ::lCodeView .and. nKey == Asc( "." )
            ::nCodeLeft = Min( 240, ::nCodeLeft + 8 )
            ::Redraw()
         case nKey == K_PGDN .or. ( ::lCodeView .and. nKey == Asc( "+" ) )
            if ::lCodeView
               ::nCodeTop = Min( Max( 1, Len( ::aCodeLines ) - ( MaxRow() - 3 ) + 1 ), ;
                                 ::nCodeTop + ( MaxRow() - 3 ) )
               ::DrawCodeView()
            endif

         case nKey == K_UP
            if ::lPlacing
               ::nGhostRow -= If( ::lSnap, DSN_SNAP_ROW, 1 )
               ::ClampGhost()
               ::Redraw()
            else
               ::MoveSelected( -1, 0 )
            endif

         case nKey == K_DOWN
            if ::lPlacing
               ::nGhostRow += If( ::lSnap, DSN_SNAP_ROW, 1 )
               ::ClampGhost()
               ::Redraw()
            else
               ::MoveSelected( 1, 0 )
            endif

         case nKey == K_LEFT
            if ::lPlacing
               ::nGhostCol -= If( ::lSnap, DSN_SNAP_COL, 1 )
               ::ClampGhost()
               ::Redraw()
            else
               ::MoveSelected( 0, -1 )
            endif

         case nKey == K_RIGHT
            if ::lPlacing
               ::nGhostCol += If( ::lSnap, DSN_SNAP_COL, 1 )
               ::ClampGhost()
               ::Redraw()
            else
               ::MoveSelected( 0, 1 )
            endif

         case nKey == K_CTRL_UP
            if ! ::lPlacing
               ::PanView( -4, 0 )
            endif

         case nKey == K_CTRL_DOWN
            if ! ::lPlacing
               ::PanView( 4, 0 )
            endif

         case nKey == DSNK_CTRLLEFT   // classic 26 aliases K_CTRL_Z; the undo case above claims it (non-destructive)
            if ! ::lPlacing
               ::PanView( 0, -4 )
            endif

         case nKey == DSNK_CTRLRIGHT   // classic 2 aliases K_CTRL_B; unreachable without EXT (safe no-op)
            if ! ::lPlacing
               ::PanView( 0, 4 )
            endif

         case nKey == K_TAB
            if ! Empty( ::aControls )
               ::nSelected = If( ::nSelected >= Len( ::aControls ), 1, ::nSelected + 1 )
               ::nInspField = 1
               ::EnsureSelectedVisible()
               ::Redraw()
               ::DrawInspector()
            endif

         case nKey == K_SH_TAB
            if ! Empty( ::aControls )
               ::nSelected = If( ::nSelected <= 1, Len( ::aControls ), ::nSelected - 1 )
               ::nInspField = 1
               ::EnsureSelectedVisible()
               ::Redraw()
               ::DrawInspector()
            endif

         case nKey == K_LBUTTONUP
            DsnTrace( "UP mainloop r=" + Str( MRow(), 4 ) + " c=" + Str( MCol(), 4 ) )

         case nKey == K_LBUTTONDOWN
            if ::lPlacing
               if ::HitClient( MRow(), MCol() )
                  ::nGhostRow = MRow() - ::oWnd:nTop - 1 + ::nViewRow
                  ::nGhostCol = MCol() - ::oWnd:nLeft - 1 + ::nViewCol
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
                  DsnTrace( "PRESS r=" + Str( MRow(), 4 ) + " c=" + Str( MCol(), 4 ) + ;
                     " wnd=" + Str( ::oWnd:nTop, 3 ) + "," + Str( ::oWnd:nLeft, 3 ) + ;
                     " view=" + Str( ::nViewRow, 3 ) + "," + Str( ::nViewCol, 3 ) )
                  nIndex = ::HitTest( MRow(), MCol() )
                  DsnTrace( "HIT idx=" + Str( nIndex, 3 ) + ;
                     If( Len( ::aControls ) > 0, " c1=" + Str( ::aControls[ 1 ][ "row" ], 3 ) + ;
                     "," + Str( ::aControls[ 1 ][ "col" ], 3 ) + " sz=" + ;
                     Str( DsnControlSize( ::aControls[ 1 ] )[ 1 ], 3 ) + "," + ;
                     Str( DsnControlSize( ::aControls[ 1 ] )[ 2 ], 3 ), "" ) )
                  if nIndex > 0
                     ::nSelected = nIndex
                     ::nInspField = 1
                     if ::HandleHit( MRow(), MCol() )
                        ::DragResize( nIndex )
                     else
                        ::DragControl( nIndex, MRow(), MCol() )
                     endif
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
      MENUITEM "Co~mboBox"                 ACTION cType := DSN_COMBOBOX
      SEPARATOR
      MENUITEM "~Dialog properties..."     ACTION cType := "dialog"
      MENUITEM "~Undo        Ctrl+Z"       ACTION cType := "undo"
      MENUITEM "~Redo        Ctrl+Y"       ACTION cType := "redo"
      SEPARATOR
      MENUITEM "~Copy        Ctrl+C"       ACTION cType := "copy"
      MENUITEM "Cu~t         Ctrl+X"       ACTION cType := "cut"
      MENUITEM "~Paste       Ctrl+V"       ACTION cType := "paste"
      MENUITEM "Snap to ~grid  F7"         ACTION cType := "snap"
      SEPARATOR
      MENUITEM "~Save JSON    F10"         ACTION cType := "save"
      MENUITEM "Save JSON ~as...  F11"     ACTION cType := "saveas"
      MENUITEM "~Open JSON    F12"         ACTION cType := "open"
      MENUITEM "~Generate PRG  F9"         ACTION cType := "gen"
      MENUITEM "~Generate and open"        ACTION cType := "genopen"
   ENDMENU

   // normalize popup geometry (menu builder defaults do not fit the items);
   // shift up so the whole popup stays on screen whatever the terminal height
   oPopup:nTop    = Max( 1, Min( 21, MaxRow() - Len( oPopup:aItems ) - 3 ) )
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
      case cType == "undo"
         ::Undo()
      case cType == "redo"
         ::Redo()
      case cType == "copy"
         ::CopySelected()
      case cType == "cut"
         ::CutSelected()
      case cType == "paste"
         ::PasteClipboard()
      case cType == "snap"
         ::ToggleSnap()
      case cType == "save"
         ::SaveJson( .F. )
      case cType == "saveas"
         ::SaveJson( .T. )
      case cType == "open"
         ::LoadJson()
      case cType == "gen"
         ::GeneratePrg()
      case cType == "genopen"
         ::GenerateAndOpen()
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

   local aSize
   local oCtrl := DsnNewControl( cType, ::aControls )

   oCtrl[ "row" ] = ::nGhostRow
   oCtrl[ "col" ] = ::nGhostCol

   aSize = DsnControlSize( oCtrl )
   oCtrl[ "row" ] = Max( 0, Min( ::nDlgHeight - 2 - aSize[ 2 ], oCtrl[ "row" ] ) )
   oCtrl[ "col" ] = Max( 0, Min( ::nDlgWidth  - 2 - aSize[ 1 ], oCtrl[ "col" ] ) )

   ::PushHistory()
   AAdd( ::aControls, oCtrl )
   ::nSelected = Len( ::aControls )
   ::lPlacing  = .F.
   ::lDirty    = .T.

   ::ShowHint( "Enter edit | Del delete | Arrows move | Mouse resizes | F9 gen | F10 save | Esc" )
   ::Redraw()

return nil

//-----------------------------------------------------------------------------------------//

METHOD DeleteSelected() CLASS HbDesigner

   if ::nSelected >= 1 .and. ::nSelected <= Len( ::aControls )
      ::PushHistory()
      hb_ADel( ::aControls, ::nSelected, .T. )
      ::nSelected = Min( ::nSelected, Len( ::aControls ) )
      ::lDirty    = .T.
      ::Redraw()
   endif

return nil

//-----------------------------------------------------------------------------------------//
// undo history: DsnSnapshot() captures the whole model; each mutating
// action pushes the pre-action state. Keyboard move bursts, mouse drags
// and inspector adjusts coalesce into one step (BeginBurst/CommitBurst).

METHOD PushHistory() CLASS HbDesigner

   ::PushSnapshot( DsnSnapshot( Self ) )

return nil

//-----------------------------------------------------------------------------------------//

METHOD PushSnapshot( hSnap ) CLASS HbDesigner

   DsnHistPush( ::aUndo, ::aRedo, hSnap )
   ::hPending     = nil
   ::lPendingUsed = .T.
   ::HintUndoRefresh()

return nil

//-----------------------------------------------------------------------------------------//
// capture the pre-burst state once, when the first move/adjust of a
// burst arrives (lMoveArmed is set by any non-arrow key in the main loop)

METHOD BeginBurst() CLASS HbDesigner

   if ::lMoveArmed
      ::hPending     = DsnSnapshot( Self )
      ::lPendingUsed = .F.
      ::lMoveArmed   = .F.
   endif

return nil

//-----------------------------------------------------------------------------------------//
// push the pre-burst snapshot when the burst actually changed the model;
// kept pending on a no-op (move clamped at an edge) so a later step of
// the same burst still undoes to the true pre-burst state

METHOD CommitBurst() CLASS HbDesigner

   if ! ::lPendingUsed .and. ::hPending != nil
      if DsnSnapEqual( ::hPending, DsnSnapshot( Self ) )
         return nil
      endif
      DsnHistPush( ::aUndo, ::aRedo, ::hPending )
      ::hPending     = nil
      ::lPendingUsed = .T.
      ::HintUndoRefresh()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD ApplySnapshot( hSnap ) CLASS HbDesigner

   ::aControls   = DsnCloneValue( hSnap[ "controls" ] )
   ::cDlgName    = hSnap[ "name" ]
   ::cDlgCaption = hSnap[ "caption" ]
   ::cDlgColor   = hSnap[ "color" ]
   ::cDlgClrFocus = hb_HGetDef( hSnap, "colorfocus", DSN_CLR_FOCUS )
   ::nDlgWidth   = hSnap[ "width" ]
   ::nDlgHeight  = hSnap[ "height" ]
   ::nSelected   = Min( hSnap[ "selected" ], Len( ::aControls ) )
   ::nInspField  = 1
   ::lDirty      = .T.
   with object ::oWnd
      :cCaption = " " + ::cDlgCaption + " "
      :cColor   = ::cDlgColor
   end
   ::FitWindow()
   ::Redraw()
   ::DrawInspector()

return nil

//-----------------------------------------------------------------------------------------//

METHOD Undo() CLASS HbDesigner

   local hSnap := DsnHistUndo( ::aUndo, ::aRedo, DsnSnapshot( Self ) )

   ::hPending     = nil
   ::lPendingUsed = .T.
   if hSnap == nil
      ::ShowHint( "Nothing to undo" )
   else
      ::ApplySnapshot( hSnap )
      ::ShowHint( "Undo (" + hb_ntos( Len( ::aUndo ) ) + " more, ^Y redo)" )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD Redo() CLASS HbDesigner

   local hSnap := DsnHistRedo( ::aRedo, ::aUndo, DsnSnapshot( Self ) )

   ::hPending     = nil
   ::lPendingUsed = .T.
   if hSnap == nil
      ::ShowHint( "Nothing to redo" )
   else
      ::ApplySnapshot( hSnap )
      ::ShowHint( "Redo (" + hb_ntos( Len( ::aRedo ) ) + " more, ^Z undo)" )
   endif

return nil

//-----------------------------------------------------------------------------------------//
// clipboard: copy/cut keep a detached clone; each paste drops a fresh clone
// one cell off the previous one, with a fresh unique variable name

METHOD CopySelected() CLASS HbDesigner

   if ::nSelected >= 1 .and. ::nSelected <= Len( ::aControls )
      ::oClipboard  = DsnCloneValue( ::aControls[ ::nSelected ] )
      ::nPasteCount = 0
      ::ShowHint( "Copied " + ::oClipboard[ "type" ] + " (^V paste)" )
   else
      ::ShowHint( "Select a control first (Tab / click)" )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD CutSelected() CLASS HbDesigner

   if ::nSelected >= 1 .and. ::nSelected <= Len( ::aControls )
      ::oClipboard  = DsnCloneValue( ::aControls[ ::nSelected ] )
      ::nPasteCount = 0
      ::PushHistory()
      hb_ADel( ::aControls, ::nSelected, .T. )
      ::nSelected = Min( ::nSelected, Len( ::aControls ) )
      ::lDirty    = .T.
      ::Redraw()
      ::DrawInspector()
      ::ShowHint( "Cut " + ::oClipboard[ "type" ] + " (^V paste, ^Z undo)" )
   else
      ::ShowHint( "Select a control first (Tab / click)" )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD PasteClipboard() CLASS HbDesigner

   local oCtrl, aSize

   if ::oClipboard == nil
      ::ShowHint( "Clipboard empty: ^C copy, ^X cut first" )
      return nil
   endif

   ::PushHistory()
   oCtrl = DsnCloneValue( ::oClipboard )
   ::nPasteCount++
   oCtrl[ "row" ] = ::oClipboard[ "row" ] + ::nPasteCount
   oCtrl[ "col" ] = ::oClipboard[ "col" ] + ::nPasteCount
   if "variable" $ oCtrl
      oCtrl[ "variable" ] = DsnUniqueVar( ::aControls, ;
         If( oCtrl[ "type" ] == DSN_GET, "cVar", ;
            If( oCtrl[ "type" ] == DSN_CHECKBOX, "lVar", "nVar" ) ) )
   endif
   aSize = DsnControlSize( oCtrl )
   oCtrl[ "row" ] = Max( 0, Min( ::nDlgHeight - 2 - aSize[ 2 ], oCtrl[ "row" ] ) )
   oCtrl[ "col" ] = Max( 0, Min( ::nDlgWidth  - 2 - aSize[ 1 ], oCtrl[ "col" ] ) )
   AAdd( ::aControls, oCtrl )
   ::nSelected = Len( ::aControls )
   ::lDirty    = .T.
   ::EnsureSelectedVisible()
   ::Redraw()
   ::DrawInspector()
   ::ShowHint( "Pasted " + oCtrl[ "type" ] + " (^Z undo)" )

return nil

//-----------------------------------------------------------------------------------------//
// F7: snap mode. Positions and sizes quantize to the grid step when on;
// the grid dots paint on the canvas (see DrawControls). Not a model
// change: no history entry, not saved to the JSON.

METHOD ToggleSnap() CLASS HbDesigner

   ::lSnap = ! ::lSnap
   ::ShowHint( "Snap to grid: " + If( ::lSnap, "ON (" + hb_ntos( DSN_SNAP_COL ) + "x" + hb_ntos( DSN_SNAP_ROW ) + ")", "OFF" ) )
   ::Redraw()

return nil

//-----------------------------------------------------------------------------------------//
// quantize a position to the grid when snap is on; identity when off

METHOD SnapPos( nRow, nCol ) CLASS HbDesigner

   if ::lSnap
      nRow = DsnSnapTo( nRow, DSN_SNAP_ROW )
      nCol = DsnSnapTo( nCol, DSN_SNAP_COL )
   endif

return { nRow, nCol }

//-----------------------------------------------------------------------------------------//

METHOD MoveSelected( nDRow, nDCol ) CLASS HbDesigner

   local oCtrl, aSize, nMaxRow, nMaxCol

   if ::nSelected >= 1 .and. ::nSelected <= Len( ::aControls )
      ::BeginBurst()
      oCtrl   = ::aControls[ ::nSelected ]
      aSize   = DsnControlSize( oCtrl )
      nMaxRow = ::nDlgHeight - 2 - aSize[ 2 ]
      nMaxCol = ::nDlgWidth  - 2 - aSize[ 1 ]
      if ::lSnap
         nDRow *= DSN_SNAP_ROW
         nDCol *= DSN_SNAP_COL
      endif
      oCtrl[ "row" ] = Max( 0, Min( nMaxRow, oCtrl[ "row" ] + nDRow ) )
      oCtrl[ "col" ] = Max( 0, Min( nMaxCol, oCtrl[ "col" ] + nDCol ) )
      if ::lSnap
         oCtrl[ "row" ] = ::SnapPos( oCtrl[ "row" ], oCtrl[ "col" ] )[ 1 ]
         oCtrl[ "col" ] = ::SnapPos( oCtrl[ "row" ], oCtrl[ "col" ] )[ 2 ]
      endif
      ::CommitBurst()
      ::lDirty = .T.
      ::EnsureSelectedVisible()
      ::Redraw()
   endif

return nil

//-----------------------------------------------------------------------------------------//
// pan the canvas over a dialog larger than the window (viewport clamp);
// model coordinates and codegen are never touched

METHOD PanView( nDRow, nDCol ) CLASS HbDesigner

   local nViewH := ::oWnd:nBottom - ::oWnd:nTop - 1
   local nViewW := ::oWnd:nRight  - ::oWnd:nLeft - 1

   ::nViewRow = DsnPanClamp( ::nViewRow + nDRow, ::nDlgHeight, nViewH )
   ::nViewCol = DsnPanClamp( ::nViewCol + nDCol, ::nDlgWidth,  nViewW )
   ::Redraw()

return nil

//-----------------------------------------------------------------------------------------//
// shift the pan origin so the selected control is visible on the canvas

METHOD EnsureSelectedVisible() CLASS HbDesigner

   local oCtrl, aSize, nViewH, nViewW

   if ::lViewClamp .and. ::nSelected >= 1 .and. ::nSelected <= Len( ::aControls )
      oCtrl  = ::aControls[ ::nSelected ]
      aSize  = DsnControlSize( oCtrl )
      nViewH = ::oWnd:nBottom - ::oWnd:nTop - 1
      nViewW = ::oWnd:nRight  - ::oWnd:nLeft - 1
      if oCtrl[ "row" ] < ::nViewRow
         ::nViewRow = oCtrl[ "row" ]
      elseif oCtrl[ "row" ] + aSize[ 2 ] > ::nViewRow + nViewH
         ::nViewRow = oCtrl[ "row" ] + aSize[ 2 ] - nViewH
      endif
      if oCtrl[ "col" ] < ::nViewCol
         ::nViewCol = oCtrl[ "col" ]
      elseif oCtrl[ "col" ] + aSize[ 1 ] > ::nViewCol + nViewW
         ::nViewCol = oCtrl[ "col" ] + aSize[ 1 ] - nViewW
      endif
      ::nViewRow = DsnPanClamp( ::nViewRow, ::nDlgHeight, nViewH )
      ::nViewCol = DsnPanClamp( ::nViewCol, ::nDlgWidth,  nViewW )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD DragControl( nIndex, nMRow, nMCol ) CLASS HbDesigner

   local oCtrl  := ::aControls[ nIndex ]
   local aSize  := DsnControlSize( oCtrl )
   local nOffR  := nMRow - ( ::oWnd:nTop + 1 + oCtrl[ "row" ] - ::nViewRow )
   local nOffC  := nMCol - ( ::oWnd:nLeft + 1 + oCtrl[ "col" ] - ::nViewCol )
   local nNewRow, nNewCol, nMaxRow, nMaxCol
   local nIter  := 0

   nMaxRow = ::nDlgHeight - 2 - aSize[ 2 ]
   nMaxCol = ::nDlgWidth  - 2 - aSize[ 1 ]

   DsnTrace( "DRAG enter idx=" + Str( nIndex, 3 ) + " leftdown=" + If( MLeftDown(), "T", "F" ) )
   ::BeginBurst()
   while MLeftDown()
      nIter++
      nNewRow = Max( 0, Min( nMaxRow, MRow() - ::oWnd:nTop - 1 - nOffR + ::nViewRow ) )
      nNewCol = Max( 0, Min( nMaxCol, MCol() - ::oWnd:nLeft - 1 - nOffC + ::nViewCol ) )
      if ::lSnap
         nNewRow = DsnSnapTo( nNewRow, DSN_SNAP_ROW )
         nNewCol = DsnSnapTo( nNewCol, DSN_SNAP_COL )
      endif
      if nNewRow != oCtrl[ "row" ] .or. nNewCol != oCtrl[ "col" ]
         oCtrl[ "row" ] = nNewRow
         oCtrl[ "col" ] = nNewCol
         ::lDirty = .T.
         ::Redraw()
      endif
   enddo

   ::CommitBurst()
   DsnTrace( "DRAG exit iter=" + Str( nIter, 6 ) + " row=" + Str( oCtrl[ "row" ], 3 ) + " col=" + Str( oCtrl[ "col" ], 3 ) )

return nil

//-----------------------------------------------------------------------------------------//
// screen position of the selected control's resize handle (bottom-right
// cell), or { -1, -1 } when there is no resizable selection

METHOD ResizeHandlePos() CLASS HbDesigner

   local oCtrl, aSize

   if ::nSelected >= 1 .and. ::nSelected <= Len( ::aControls )
      oCtrl = ::aControls[ ::nSelected ]
      if DsnResizable( oCtrl )
         aSize = DsnControlSize( oCtrl )
         return { ::oWnd:nTop + 1 + oCtrl[ "row" ] - ::nViewRow + aSize[ 2 ] - 1, ;
                  ::oWnd:nLeft + 1 + oCtrl[ "col" ] - ::nViewCol + aSize[ 1 ] - 1 }
      endif
   endif

return { -1, -1 }

//-----------------------------------------------------------------------------------------//

METHOD HandleHit( nMRow, nMCol ) CLASS HbDesigner

   local aPos := ::ResizeHandlePos()

return aPos[ 1 ] >= 0 .and. nMRow == aPos[ 1 ] .and. nMCol == aPos[ 2 ]

//-----------------------------------------------------------------------------------------//
// drag the selected control's resize handle: the control grows/shrinks with
// the mouse, clamped by DsnResize to its minimum and to the dialog interior

METHOD DragResize( nIndex ) CLASS HbDesigner

   local oCtrl := ::aControls[ nIndex ]
   local aSize, nTW, nTH
   local nIter := 0

   DsnTrace( "RESIZE enter idx=" + Str( nIndex, 3 ) + " leftdown=" + If( MLeftDown(), "T", "F" ) )
   ::BeginBurst()
   while MLeftDown()
      nIter++
      aSize = DsnControlSize( oCtrl )
      nTW   = MCol() - ::oWnd:nLeft - 1 - oCtrl[ "col" ] + ::nViewCol + 1
      nTH   = MRow() - ::oWnd:nTop - 1 - oCtrl[ "row" ] + ::nViewRow + 1
      if ::lSnap
         nTW = Max( DSN_SNAP_COL, DsnSnapTo( nTW, DSN_SNAP_COL ) )
         nTH = Max( DSN_SNAP_ROW, DsnSnapTo( nTH, DSN_SNAP_ROW ) )
      endif
      if DsnResize( oCtrl, nTW - aSize[ 1 ], nTH - aSize[ 2 ], ;
                    ::nDlgWidth, ::nDlgHeight )
         ::lDirty = .T.
         ::Redraw()
      endif
   enddo

   ::CommitBurst()
   aSize = DsnControlSize( oCtrl )
   DsnTrace( "RESIZE exit iter=" + Str( nIter, 6 ) + " w=" + Str( aSize[ 1 ], 3 ) + " h=" + Str( aSize[ 2 ], 3 ) )

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
      nARow = ::oWnd:nTop + 1 + oCtrl[ "row" ] - ::nViewRow
      nACol = ::oWnd:nLeft + 1 + oCtrl[ "col" ] - ::nViewCol
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
   if ::lInspector
      ::DrawInspector()
   endif
   ::ShowHint()
   DispEnd()

return nil

//-----------------------------------------------------------------------------------------//

METHOD DrawControls() CLASS HbDesigner

   local n, nR, nC, oCtrl, aRect, aSz, nMinW, nMinH

   if ::oWnd == nil .or. ! ::oWnd:lVisible
      return nil
   endif

   // keep the model in sync with window moves/resizes done by mouse,
   // except when the window is a clamped viewport onto a larger dialog
   if ! ::lViewClamp
      ::nDlgWidth  = ::oWnd:nRight - ::oWnd:nLeft + 1
      ::nDlgHeight = ::oWnd:nBottom - ::oWnd:nTop + 1
   endif

   // mouse-resize floor: never shrink the form below its controls' bbox
   nMinW = 6
   nMinH = 3
   for n = 1 to Len( ::aControls )
      aSz = DsnControlSize( ::aControls[ n ] )
      nMinW = Max( nMinW, ::aControls[ n ][ "col" ] + aSz[ 1 ] + 2 )
      nMinH = Max( nMinH, ::aControls[ n ][ "row" ] + aSz[ 2 ] + 2 )
   next
   ::oWnd:nMinW = nMinW
   ::oWnd:nMinH = nMinH

   DispBegin()
   if ::lSnap
      for nR := ::oWnd:nTop + 1 to ::oWnd:nBottom - 1
         if ( nR - ::oWnd:nTop - 1 + ::nViewRow ) % DSN_SNAP_ROW == 0
            for nC := ::oWnd:nLeft + 1 to Min( ::oWnd:nRight - 1, MaxCol() )
               if ( nC - ::oWnd:nLeft - 1 + ::nViewCol ) % DSN_SNAP_COL == 0
                  hb_DispOutAt( nR, nC, hb_UTF8ToStrBox( "." ), "N/W" )
               endif
            next
         endif
      next
   endif
   for n = 1 to Len( ::aControls )
      oCtrl = ::aControls[ n ]
      DsnDrawControl( ::oWnd, oCtrl, n == ::nSelected, NIL, ::nViewRow, ::nViewCol )
   next

   if ::lPlacing
      oCtrl = DsnNewControl( ::cPlacingType, ::aControls )
      oCtrl[ "row" ] = ::nGhostRow
      oCtrl[ "col" ] = ::nGhostCol
      DsnDrawControl( ::oWnd, oCtrl, .T., CLR_GHOST, ::nViewRow, ::nViewCol )
   endif

   // resize handle: bottom-right cell of the selected resizable control
   if ! ::lPlacing
      aRect = ::ResizeHandlePos()
      if aRect[ 1 ] >= 0 .and. ::HitClient( aRect[ 1 ], aRect[ 2 ] )
         hb_DispOutAt( aRect[ 1 ], aRect[ 2 ], hb_UTF8ToStr( "█" ), "N+/W" )
      endif
   endif

   ::DrawInspector()
   ::DrawCodeView()

   DispEnd()

return nil

//-----------------------------------------------------------------------------------------//

METHOD RefreshCodeView() CLASS HbDesigner

   local hModel, cSig, oCtrl

   if ! ::lCodeView
      return nil
   endif

   hModel = DsnBuildModel( Self )
   // regenerate only when the model or the selection changed: the idle
   // redraw calls this on every tick. NOTE: exact == comparison; with
   // SET EXACT off, cSig != "" would always be .F. (xBase padding rule)
   // and the view would never regenerate.
   begin sequence
      cSig = hb_jsonEncode( hModel ) + "|" + hb_ntos( ::nSelected )
      if !( cSig == ::cCodeSig )
         ::cCodeSig    = cSig
         ::aCodeLines  = hb_ATokens( StrTran( DsnGenCode( hModel ), Chr( 13 ), "" ), Chr( 10 ) )
         oCtrl = If( ::nSelected >= 1 .and. ::nSelected <= Len( ::aControls ), ;
                     ::aControls[ ::nSelected ], NIL )
         ::nCodeAnchor = DsnCodeFindLine( ::aCodeLines, oCtrl )
         ::nCodeTop    = DsnCodeViewTop( ::nCodeAnchor, Len( ::aCodeLines ), MaxRow() - 3 )
      endif
   recover
   end

return nil

//-----------------------------------------------------------------------------------------//

METHOD DrawCodeView() CLASS HbDesigner

   local nT := 1, nB := MaxRow() - 1
   local nW := Min( 58, MaxCol() - 3 )
   local nR := MaxCol() - 2, nL := nR - nW + 1
   local nViewH, n, nLine, cTitle

   if ! ::lCodeView .or. ::oWnd == nil
      return nil
   endif

   ::RefreshCodeView()

   nViewH = nB - nT - 1
   ::nCodeTop = Max( 1, Min( ::nCodeTop, Max( 1, Len( ::aCodeLines ) - nViewH + 1 ) ) )

   DispBegin()
   hb_Scroll( nT, nL, nB, nR,,, CLR_CODEVIEW )
   DispBox( nT, nL, nB, nR, 1, CLR_CODEVIEW )
   DrawShadow( nT, nL, nB, nR )
   cTitle = " " + Lower( ::cDlgName ) + ".prg - live view (read-only) "
   hb_DispOutAt( nT, nL + 1, PadR( "", nW - 2 ), "N/BG" )
   hb_DispOutAt( nT, nL + 2, Left( cTitle, nW - 4 ), "N+/BG" )
   for n = 1 to nViewH
      nLine = ::nCodeTop + n - 1
      if nLine >= 1 .and. nLine <= Len( ::aCodeLines )
         hb_DispOutAt( nT + n, nL + 1, ;
            PadR( SubStr( ::aCodeLines[ nLine ], ::nCodeLeft, nW - 2 ), nW - 2 ), ;
            If( nLine == ::nCodeAnchor, CLR_CODEVIEW_HL, CLR_CODEVIEW ) )
      endif
   next
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
// keep an already-visible undo/redo status line truthful after a new push;
// key-help hints (canvas, inspector, ...) are left alone

METHOD HintUndoRefresh() CLASS HbDesigner

   if Left( ::cHint, 5 ) == "Undo " .or. Left( ::cHint, 5 ) == "Redo "
      ::ShowHint( "Undo (" + hb_ntos( Len( ::aUndo ) ) + " more, ^Y redo)" )
   endif

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

// clamp the placing ghost origin so the whole control stays inside the
// dialog interior - the same limits AddControl applies on drop, so the ghost
// never vanishes or teleports when it reaches an edge

METHOD ClampGhost() CLASS HbDesigner

   local aSize := DsnControlSize( DsnNewControl( ::cPlacingType, ::aControls ) )

   ::nGhostRow = Max( 0, Min( ::nDlgHeight - 2 - aSize[ 2 ], ::nGhostRow ) )
   ::nGhostCol = Max( 0, Min( ::nDlgWidth  - 2 - aSize[ 1 ], ::nGhostCol ) )
   if ::lSnap
      ::nGhostRow = DsnSnapTo( ::nGhostRow, DSN_SNAP_ROW )
      ::nGhostCol = DsnSnapTo( ::nGhostCol, DSN_SNAP_COL )
      ::nGhostRow = Max( 0, Min( ::nDlgHeight - 2 - aSize[ 2 ], ::nGhostRow ) )
      ::nGhostCol = Max( 0, Min( ::nDlgWidth  - 2 - aSize[ 1 ], ::nGhostCol ) )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD ResumeUI() CLASS HbDesigner

   ::RegisterIdles()
   ::Redraw()

return nil

//-----------------------------------------------------------------------------------------//
// (re)install the designer idles. The window's own Show() registers a raw
// mouse idle whose HBWindow:MouseEvent otherwise branch repaints the whole
// window frame on EVERY mouse idle, even with no button pressed; that frame
// repaint lands after the redraw idle and visibly eats any control or
// inspector cell overlapping the frame (title row, right column). The
// designer replaces it with a gated idle that only forwards mouse events
// while a button is held (window drag, resize, popup, close), which are the
// only cases MouseEvent acts on.

METHOD RegisterIdles() CLASS HbDesigner

   if ::oWnd != nil .and. ::oWnd:lVisible
      if ::oWnd:nIdle != nil
         hb_IdleDel( ::oWnd:nIdle )
      endif
      ::oWnd:nIdle = hb_IdleAdd( { || If( MLeftDown() .or. MRightDown(), ;
                                           ::oWnd:MouseEvent( MRow(), MCol() ), nil ) } )
   endif

   if ::nIdleDraw == nil
      ::nIdleDraw = hb_IdleAdd( { || ::DrawControls(), ;
         If( ::lInspector, ::DrawInspector(), nil ) } )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD EditProperties() CLASS HbDesigner

   local oCtrl, oDlg, GetList := {}, lOk := .F., lCancel := .F., lDummy
   local cCaption, cVariable, nRow, nCol, nWidth, cAccel, cAction, cItems, nHeight
   local cWhen, cValid, cFocus, cState
   local aSize, nMaxRow, nMaxCol, hBefore, lBrackets

   if ::nSelected < 1 .or. ::nSelected > Len( ::aControls )
      return nil
   endif

   hBefore   = DsnSnapshot( Self )
   oCtrl     = ::aControls[ ::nSelected ]
   aSize     = DsnControlSize( oCtrl )
   nMaxRow   = ::oWnd:nBottom - ::oWnd:nTop - 1 - aSize[ 2 ]
   nMaxCol   = ::oWnd:nRight  - ::oWnd:nLeft - 1 - aSize[ 1 ]
   cCaption  = PadR( hb_HGetDef( oCtrl, "caption", "" ), Max( 60, Len( hb_HGetDef( oCtrl, "caption", "" ) ) ) + 20 )
   cVariable = PadR( hb_HGetDef( oCtrl, "variable", "" ), Max( 20, Len( hb_HGetDef( oCtrl, "variable", "" ) ) ) + 10 )
   nRow      = oCtrl[ "row" ]
   nCol      = oCtrl[ "col" ]
   nWidth    = hb_HGetDef( oCtrl, "width", 10 )
   lBrackets = hb_HGetDef( oCtrl, "style", "shadow" ) == "brackets"
   cAccel    = PadR( hb_HGetDef( oCtrl, "accelerator", "" ), 4 )
   cAction   = PadR( hb_HGetDef( oCtrl, "action", "" ), Max( 60, Len( hb_HGetDef( oCtrl, "action", "" ) ) ) + 20 )
   cItems    = PadR( hb_HGetDef( oCtrl, "items", "" ), Max( 60, Len( hb_HGetDef( oCtrl, "items", "" ) ) ) + 20 )
   nHeight   = hb_HGetDef( oCtrl, "height", 6 )
   cWhen     = PadR( hb_HGetDef( oCtrl, "when", "" ),  Max( 60, Len( hb_HGetDef( oCtrl, "when", "" ) ) ) + 20 )
   cValid    = PadR( hb_HGetDef( oCtrl, "valid", "" ), Max( 60, Len( hb_HGetDef( oCtrl, "valid", "" ) ) ) + 20 )
   cFocus    = PadR( hb_HGetDef( oCtrl, "focus", "" ), Max( 60, Len( hb_HGetDef( oCtrl, "focus", "" ) ) ) + 20 )
   cState    = PadR( hb_HGetDef( oCtrl, "state", "" ), Max( 60, Len( hb_HGetDef( oCtrl, "state", "" ) ) ) + 20 )

   ::SuspendUI()

   oDlg = HBWindow():Dialog( "Control properties", 76, If( oCtrl[ "type" ] == DSN_SAY, 11, 15 ), CLR_DIALOG )
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
      @ oDlg:nTop + 7, oDlg:nLeft + 11 GET lBrackets CHECKBOX ;
         CAPTION "B&rackets look (uncheck for 3D shadow)" STYLE '[X ]' ;
         COLOR "N/W,BG+/W,N/W,GR+/W"
   endif

   if oCtrl[ "type" ] $ DSN_RADIO + "|" + DSN_LISTBOX + "|" + DSN_COMBOBOX
      @ oDlg:nTop + 4, oDlg:nLeft + 11 GET cVariable PICTURE "@S20" COLOR "N/W,W+/B,W+/W,GR+/W"
      oDlg:Say( 4, 2, "Variable:" )
      @ oDlg:nTop + 5, oDlg:nLeft + 11 GET cItems PICTURE "@S40" COLOR "N/W,W+/B,W+/W,GR+/W"
      oDlg:Say( 5, 2, "Items:" )
   endif

   if ( oCtrl[ "type" ] == DSN_LISTBOX .or. oCtrl[ "type" ] == DSN_COMBOBOX )
      @ oDlg:nTop + 6, oDlg:nLeft + 11 GET nWidth PICTURE "999" COLOR "N/W,W+/B,W+/W,GR+/W"
      oDlg:Say( 6, 2, "Width:" )
      @ oDlg:nTop + 7, oDlg:nLeft + 11 GET nHeight PICTURE "999" COLOR "N/W,W+/B,W+/W,GR+/W"
      oDlg:Say( 7, 2, "Height:" )
   endif

   if oCtrl[ "type" ] != DSN_SAY
      @ oDlg:nTop + 8, oDlg:nLeft + 11 GET cWhen PICTURE "@S40" COLOR "N/W,W+/B,W+/W,GR+/W"
      oDlg:Say( 8, 2, "When:" )
      @ oDlg:nTop + 9, oDlg:nLeft + 11 GET cValid PICTURE "@S40" COLOR "N/W,W+/B,W+/W,GR+/W"
      oDlg:Say( 9, 2, "Valid:" )
      if oCtrl[ "type" ] $ DSN_BUTTON + "|" + DSN_CHECKBOX + "|" + DSN_RADIO + "|" + DSN_LISTBOX + "|" + DSN_COMBOBOX
         @ oDlg:nTop + 10, oDlg:nLeft + 11 GET cFocus PICTURE "@S40" COLOR "N/W,W+/B,W+/W,GR+/W"
         oDlg:Say( 10, 2, "Focus:" )
      endif
      if oCtrl[ "type" ] $ DSN_CHECKBOX + "|" + DSN_LISTBOX + "|" + DSN_COMBOBOX
         @ oDlg:nTop + 11, oDlg:nLeft + 11 GET cState PICTURE "@S40" COLOR "N/W,W+/B,W+/W,GR+/W"
         oDlg:Say( 11, 2, "State:" )
      endif
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
      ::PushSnapshot( hBefore )
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
      if ( oCtrl[ "type" ] == DSN_LISTBOX .or. oCtrl[ "type" ] == DSN_COMBOBOX )
         oCtrl[ "height" ] = Max( If( oCtrl[ "type" ] == DSN_COMBOBOX, 4, 3 ), Min( 15, nHeight ) )
      endif
      if oCtrl[ "type" ] == DSN_BUTTON
         oCtrl[ "accelerator" ] = Left( StrTran( AllTrim( cAccel ), "&", "" ), 1 )
         oCtrl[ "action" ]      = AllTrim( cAction )
         oCtrl[ "style" ]       = If( lBrackets, "brackets", "shadow" )
      endif
      if oCtrl[ "type" ] != DSN_SAY
         oCtrl[ "when" ]  = AllTrim( cWhen )
         oCtrl[ "valid" ] = AllTrim( cValid )
         oCtrl[ "focus" ] = AllTrim( cFocus )
         oCtrl[ "state" ] = AllTrim( cState )
      endif
      // Width/height/caption can change the footprint. Clamp against the
      // final size, not just the old size captured before the dialog.
      aSize := DsnControlSize( oCtrl )
      nMaxRow := ::oWnd:nBottom - ::oWnd:nTop - 1 - aSize[ 2 ]
      nMaxCol := ::oWnd:nRight - ::oWnd:nLeft - 1 - aSize[ 1 ]
      oCtrl[ "row" ] := Max( 0, Min( nMaxRow, oCtrl[ "row" ] ) )
      oCtrl[ "col" ] := Max( 0, Min( nMaxCol, oCtrl[ "col" ] ) )
      ::lDirty = .T.
      ::Redraw()
   endif

   if lOk .and. DsnListSBarHidden( oCtrl )
      ::ShowHint( "Listbox height < 6 with overflowing items: scrollbar won't be drawn" )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD DlgProperties() CLASS HbDesigner

   local oDlg, GetList := {}, lOk := .F., lCancel := .F., lDummy
   local cCaption := PadR( ::cDlgCaption, Max( 50, Len( ::cDlgCaption ) ) + 10 )
   local cName    := PadR( ::cDlgName, 20 )
   local nWidth   := ::nDlgWidth
   local nHeight  := ::nDlgHeight
   local cClrBack  := PadR( ::cDlgClrBack, 20 )
   local cClrText  := PadR( ::cDlgClrText, 20 )
   local cClrFocus := PadR( ::cDlgClrFocus, 20 )
   local aMin, hBefore

   hBefore = DsnSnapshot( Self )

   ::SuspendUI()

   oDlg = HBWindow():Dialog( "Dialog properties", 66, 14, CLR_DIALOG )
   oDlg:bRepaint = { || ::Redraw() }

   @ oDlg:nTop + 2, oDlg:nLeft + 11 GET cCaption PICTURE "@S40" COLOR "N/W,W+/B,W+/W,GR+/W"
   oDlg:Say( 2, 2, "Caption:" )

   @ oDlg:nTop + 4, oDlg:nLeft + 11 GET cName COLOR "N/W,W+/B,W+/W,GR+/W"
   oDlg:Say( 4, 2, "Name:" )

   @ oDlg:nTop + 6, oDlg:nLeft + 11 GET nWidth PICTURE "999" COLOR "N/W,W+/B,W+/W,GR+/W"
   oDlg:Say( 6, 2, "Width:" )

   @ oDlg:nTop + 6, oDlg:nLeft + 27 GET nHeight PICTURE "999" COLOR "N/W,W+/B,W+/W,GR+/W"
   oDlg:Say( 6, 20, "Height:" )

   @ oDlg:nTop + 8, oDlg:nLeft + 11 GET cClrBack PICTURE "@S20" COLOR "N/W,W+/B,W+/W,GR+/W"
   oDlg:Say( 8, 2, "Back:" )

   @ oDlg:nTop + 9, oDlg:nLeft + 11 GET cClrText PICTURE "@S20" COLOR "N/W,W+/B,W+/W,GR+/W"
   oDlg:Say( 9, 2, "Text:" )

   @ oDlg:nTop + 10, oDlg:nLeft + 11 GET cClrFocus PICTURE "@S20" COLOR "N/W,W+/B,W+/W,GR+/W"
   oDlg:Say( 10, 2, "Focus:" )

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
      ::PushSnapshot( hBefore )
      aMin = ::DlgMinSize()
      if nWidth < aMin[ 1 ] .or. nHeight < aMin[ 2 ]
         nWidth   = Max( nWidth, aMin[ 1 ] )
         nHeight  = Max( nHeight, aMin[ 2 ] )
         ::ShowHint( "Adjusted to the minimum size: controls inside would be hidden" )
      endif
      ::cDlgCaption = AllTrim( cCaption )
      ::cDlgName    = DsnValidVar( cName, "MyDialog" )
      ::nDlgWidth   = Max( 20, nWidth )
      ::nDlgHeight  = Max( 6, nHeight )
      if ! Empty( AllTrim( cClrBack ) )
         if ! DsnValidColor( AllTrim( cClrBack ) )
            ::ShowHint( "Invalid back color '" + AllTrim( cClrBack ) + "': keeping " + ::cDlgClrBack )
         else
            ::cDlgClrBack = AllTrim( cClrBack )
         endif
      endif
      if ! Empty( AllTrim( cClrText ) )
         if ! DsnValidColor( AllTrim( cClrText ) )
            ::ShowHint( "Invalid text color '" + AllTrim( cClrText ) + "': keeping " + ::cDlgClrText )
         else
            ::cDlgClrText = AllTrim( cClrText )
         endif
      endif
      if ! Empty( AllTrim( cClrFocus ) )
         if ! DsnValidColor( AllTrim( cClrFocus ) )
            ::ShowHint( "Invalid focus color '" + AllTrim( cClrFocus ) + "': keeping " + ::cDlgClrFocus )
         else
            ::cDlgClrFocus = AllTrim( cClrFocus )
         endif
      endif
      with object ::oWnd
         :cCaption = " " + ::cDlgCaption + " "
         :cColor   = ::cDlgColor
      end
      ::FitWindow()
      ::lDirty = .T.
      ::Redraw()
   endif

return nil

//-----------------------------------------------------------------------------------------//
// keep the design window and its shadow fully on screen: when a size
// change (load, F3, inspector resize) would push an edge out, shift the
// window back. The dialog model keeps its true size; when it does not
// fit the screen the window acts as a viewport onto it (lViewClamp) and
// controls beyond the edge are clipped on the canvas, never in the model.

METHOD FitWindow() CLASS HbDesigner

   local aSize := DsnViewSize( ::nDlgWidth, ::nDlgHeight, MaxCol(), MaxRow() )
   // the canvas dialog is always presented centered on the screen;
   // DsnFitRect only steps in when the size does not fit
   local aPos  := DsnFitRect( Int( ( MaxCol() - aSize[ 1 ] ) / 2 ), ;
                              Int( ( MaxRow() - aSize[ 2 ] ) / 2 ), ;
                              aSize[ 1 ], aSize[ 2 ], MaxCol(), MaxRow() )

   ::lViewClamp = aSize[ 1 ] < ::nDlgWidth .or. aSize[ 2 ] < ::nDlgHeight
   ::nViewRow   = DsnPanClamp( ::nViewRow, ::nDlgHeight, aSize[ 2 ] - 2 )
   ::nViewCol   = DsnPanClamp( ::nViewCol, ::nDlgWidth,  aSize[ 1 ] - 2 )

   with object ::oWnd
      :nLeft   = aPos[ 1 ]
      :nTop    = aPos[ 2 ]
      :nRight  = :nLeft + aSize[ 1 ] - 1
      :nBottom = :nTop + aSize[ 2 ] - 1
   end
   DsnTrace( "FIT rect=" + Str( ::oWnd:nTop, 3 ) + "," + Str( ::oWnd:nLeft, 3 ) + ;
      "-" + Str( ::oWnd:nBottom, 3 ) + "," + Str( ::oWnd:nRight, 3 ) + ;
      " max=" + Str( MaxRow(), 3 ) + "," + Str( MaxCol(), 4 ) )

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

   local hModel, cFile := ::cFileName, cFailInfo := ""

   hb_default( @lAskName, .F. )

   if lAskName .or. Empty( ::cFileName )
      cFile = ::SelectFileName( "Save dialog as JSON", ;
         If( Empty( ::cFileName ), Lower( ::cDlgName ) + ".json", ::cFileName ) )
      if Empty( cFile )
         return nil
      endif
   endif

   hModel = DsnBuildModel( Self )

   if DsnSafeMemoWrit( cFile, hb_jsonEncode( hModel, .T. ), @cFailInfo )
      ::cFileName = cFile
      ::lDirty = .F.
      ::ShowHint( "Saved " + ::cFileName )
   else
      ::SuspendUI()
      DsnWriteError( "Could not write " + cFile + ": " + cFailInfo )
      ::ResumeUI()
      ::ShowHint( "Save failed; design kept open. Choose another path and save again" )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD LoadJson() CLASS HbDesigner

   local cFile, cJson, hModel := nil, aMin, nSkipped, hBefore, nDecoded, cRest

   hBefore = DsnSnapshot( Self )

   cFile = ::SelectFileName( "Open a JSON dialog", ::cFileName )
   if Empty( cFile )
      return nil
   endif

   if ! File( cFile )
      ::ShowHint( "File not found: " + cFile )
      return nil
   endif

   cJson = MemoRead( cFile )
   nDecoded := hb_jsonDecode( cJson, @hModel )
   cRest := SubStr( cJson, nDecoded + 1 )
   cRest := StrTran( StrTran( StrTran( StrTran( cRest, " ", "" ), Chr( 9 ), "" ), Chr( 10 ), "" ), Chr( 13 ), "" )

   // Decoder may leave a partially built hash after syntax failure. Never
   // accept it, nor a valid JSON prefix followed by non-whitespace bytes.
   if nDecoded == 0 .or. ! Empty( cRest ) .or. ! DsnValidModel( hModel )
      ::ShowHint( "Invalid dialog JSON: " + cFile )
      return nil
   endif

   nSkipped = ::ApplyModel( hModel )
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
      :cCaption = " " + ::cDlgCaption + " "
      :cColor   = ::cDlgColor
   end
   ::FitWindow()

   ::PushSnapshot( hBefore )

   ::Redraw()
   if nSkipped == 0
      ::ShowHint( "Loaded " + cFile + ;
         If( ::lViewClamp, " (small viewport: Ctrl+Arrows pan, Tab reveals)", "" ) )
   endif

return nil

//-----------------------------------------------------------------------------------------//
// apply a decoded dialog model to the designer: data only, no UI work, so
// JSON round-trips are testable headless. Returns skipped-control count.

METHOD ApplyModel( hModel ) CLASS HbDesigner

   local aMin, nSkipped, cTmp

   ::cDlgName    = DsnValidVar( DsnStr( hb_HGetDef( hModel, "name", "" ), "" ), "MyDialog" )
   ::cDlgCaption = DsnStr( hb_HGetDef( hModel, "caption", "" ), "My Dialog" )
   if Empty( ::cDlgCaption )
      ::cDlgCaption = "My Dialog"
   endif
   ::cDlgColor   = DsnStr( hb_HGetDef( hModel, "color", "" ), CLR_DIALOG )
   if Empty( AllTrim( ::cDlgColor ) )   // absent or empty key: keep the stock dialog color
      ::cDlgColor = CLR_DIALOG
   endif
   // the split properties win over the legacy combined "color" key;
   // each applies only when its key is present and non-empty
   cTmp = DsnStr( hb_HGetDef( hModel, "colortext", "" ), "" )
   if ! Empty( AllTrim( cTmp ) )
      ::cDlgClrText = AllTrim( cTmp )
   endif
   cTmp = DsnStr( hb_HGetDef( hModel, "colorback", "" ), "" )
   if ! Empty( AllTrim( cTmp ) )
      ::cDlgClrBack = AllTrim( cTmp )
   endif
   ::cDlgClrFocus = DSN_CLR_FOCUS
   cTmp = DsnStr( hb_HGetDef( hModel, "colorfocus", "" ), "" )
   if ! Empty( AllTrim( cTmp ) )
      ::cDlgClrFocus = AllTrim( cTmp )
   endif
   ::aControls   = hModel[ "controls" ]
   nSkipped      = Len( ::aControls )
   DsnNormalizeControls( ::aControls )
   nSkipped      -= Len( ::aControls )
   // the model keeps the saved size, grown so no control is left outside;
   // FitWindow() clamps the design window to the screen when needed
   ::nDlgWidth   = Max( 20, Int( DsnNum( hb_HGetDef( hModel, "width", 40 ), 40 ) ) )
   ::nDlgHeight  = Max( 6, Int( DsnNum( hb_HGetDef( hModel, "height", 12 ), 12 ) ) )
   aMin          = ::DlgMinSize()
   ::nDlgWidth   = Max( ::nDlgWidth, aMin[ 1 ] )
   ::nDlgHeight  = Max( ::nDlgHeight, aMin[ 2 ] )
   ::nSelected   = 0
   ::lPlacing    = .F.
   ::nViewRow    = 0
   ::nViewCol    = 0

return nSkipped

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
// { label, key, kind } per field; kind is "num", "text" or "choice"

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
         AAdd( aFields, { "Style",  "style",       "choice" } )
      endif
      if oCtrl[ "type" ] $ DSN_RADIO + "|" + DSN_LISTBOX + "|" + DSN_COMBOBOX
         AAdd( aFields, { "Variable", "variable", "text" } )
         AAdd( aFields, { "Items",    "items",    "text" } )
      endif
      if ( oCtrl[ "type" ] == DSN_LISTBOX .or. oCtrl[ "type" ] == DSN_COMBOBOX )
         AAdd( aFields, { "Width",  "width",  "num" } )
         AAdd( aFields, { "Height", "height", "num" } )
      endif
      if oCtrl[ "type" ] != DSN_SAY
         AAdd( aFields, { "When",  "when",  "text" } )
         AAdd( aFields, { "Valid", "valid", "text" } )
         if oCtrl[ "type" ] $ DSN_BUTTON + "|" + DSN_CHECKBOX + "|" + DSN_RADIO + "|" + DSN_LISTBOX + "|" + DSN_COMBOBOX
            AAdd( aFields, { "Focus", "focus", "text" } )
         endif
         if oCtrl[ "type" ] $ DSN_CHECKBOX + "|" + DSN_LISTBOX + "|" + DSN_COMBOBOX
            AAdd( aFields, { "State", "state", "text" } )
         endif
      endif
   else
      AAdd( aFields, { "Name", "dlgname", "text" } )
      AAdd( aFields, { "Caption", "dlgcaption", "text" } )
      AAdd( aFields, { "Width", "dlgwidth", "num" } )
      AAdd( aFields, { "Height", "dlgheight", "num" } )
      AAdd( aFields, { "Back",  "dlgback",  "color" } )
      AAdd( aFields, { "Text",  "dlgtext",  "color" } )
      AAdd( aFields, { "Focus", "dlgfocus", "color" } )
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
         case cKey == "style"       ; return hb_HGetDef( oCtrl, "style", "shadow" )
         case cKey == "items"       ; return hb_HGetDef( oCtrl, "items", "" )
         case cKey == "when"        ; return hb_HGetDef( oCtrl, "when", "" )
         case cKey == "valid"       ; return hb_HGetDef( oCtrl, "valid", "" )
         case cKey == "focus"       ; return hb_HGetDef( oCtrl, "focus", "" )
         case cKey == "state"       ; return hb_HGetDef( oCtrl, "state", "" )
         case cKey == "height"      ; return hb_ntos( hb_HGetDef( oCtrl, "height", 6 ) )
      endcase
   else
      do case
         case cKey == "dlgname"    ; return ::cDlgName
         case cKey == "dlgcaption" ; return ::cDlgCaption
         case cKey == "dlgwidth"   ; return hb_ntos( ::nDlgWidth )
         case cKey == "dlgheight"  ; return hb_ntos( ::nDlgHeight )
         case cKey == "dlgback"    ; return ::cDlgClrBack
         case cKey == "dlgtext"    ; return ::cDlgClrText
         case cKey == "dlgfocus"   ; return ::cDlgClrFocus
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
   nValWidth = aRect[ 4 ] - aRect[ 2 ] - 12

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
         hb_DispOutAt( aRect[ 1 ] + n, aRect[ 2 ] + 11, cValue, CLR_INSP_VAL )
      endif
   next
   DispEnd()

return nil

//-----------------------------------------------------------------------------------------//

METHOD InspSetText( cKey, cVal ) CLASS HbDesigner

   local oCtrl, aSize

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
         case cKey == "when" .or. cKey == "valid" .or. cKey == "focus" .or. cKey == "state"
            oCtrl[ cKey ] = cVal
      endcase
      // Caption/items can grow without the classic properties dialog.
      aSize := DsnControlSize( oCtrl )
      oCtrl[ "row" ] := Max( 0, Min( ::nDlgHeight - 2 - aSize[ 2 ], oCtrl[ "row" ] ) )
      oCtrl[ "col" ] := Max( 0, Min( ::nDlgWidth - 2 - aSize[ 1 ], oCtrl[ "col" ] ) )
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
   if aFields[ ::nInspField ][ 3 ] == "choice"
      ::InspCycle( nDelta )
      return nil
   endif
   if aFields[ ::nInspField ][ 3 ] != "num"
      return nil
   endif
   cKey = aFields[ ::nInspField ][ 2 ]

   ::BeginBurst()
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
            oCtrl[ "height" ] = Max( If( oCtrl[ "type" ] == DSN_COMBOBOX, 4, 3 ), Min( 15, hb_HGetDef( oCtrl, "height", 6 ) + nDelta ) )
      endcase
   else
      aMin = ::DlgMinSize()
      do case
         case cKey == "dlgwidth"
            nNew = Max( aMin[ 1 ], ::nDlgWidth + nDelta )
            if nNew != ::nDlgWidth + nDelta .and. ::nDlgWidth + nDelta < aMin[ 1 ]
               ::ShowHint( "Minimum width " + hb_ntos( aMin[ 1 ] ) + ": controls inside would be hidden" )
            else
               ::ShowHint( HINT_INSP )
            endif
            ::nDlgWidth = nNew
         case cKey == "dlgheight"
            nNew = Max( aMin[ 2 ], ::nDlgHeight + nDelta )
            if nNew != ::nDlgHeight + nDelta .and. ::nDlgHeight + nDelta < aMin[ 2 ]
               ::ShowHint( "Minimum height " + hb_ntos( aMin[ 2 ] ) + ": controls inside would be hidden" )
            else
               ::ShowHint( HINT_INSP )
            endif
            ::nDlgHeight = nNew
      endcase
      ::FitWindow()
   endif

   ::CommitBurst()
   ::lDirty = .T.
   ::Redraw()

return nil

//-----------------------------------------------------------------------------------------//
// cycle a "choice" inspector field through its values (Left/Right/Enter)

METHOD InspCycle( nDelta ) CLASS HbDesigner

   local aFields, cKey, oCtrl, aValues := {}, nPos

   aFields = ::InspFields()
   if ::nInspField < 1 .or. ::nInspField > Len( aFields )
      return nil
   endif
   if aFields[ ::nInspField ][ 3 ] != "choice"
      return nil
   endif
   if ::nSelected < 1 .or. ::nSelected > Len( ::aControls )
      return nil
   endif
   cKey  = aFields[ ::nInspField ][ 2 ]
   oCtrl = ::aControls[ ::nSelected ]
   do case
      case cKey == "style"
         aValues = { "shadow", "brackets" }
   endcase
   if Empty( aValues )
      return nil
   endif
   nPos = AScan( aValues, hb_HGetDef( oCtrl, cKey, aValues[ 1 ] ) )
   if nPos == 0
      nPos = 1
   endif
   nPos = 1 + Mod( nPos - 1 + nDelta + Len( aValues ), Len( aValues ) )

   ::BeginBurst()
   oCtrl[ cKey ] = aValues[ nPos ]
   ::CommitBurst()
   ::lDirty = .T.
   ::Redraw()

return nil

//-----------------------------------------------------------------------------------------//
// inline edit of a text field inside the inspector

METHOD InspEdit() CLASS HbDesigner

   local aFields, aRect, cKey, cVal, nRow, nCol, nWidth, nKey, lApply := .F.
   local nPos, nOff, hBefore

   aFields = ::InspFields()
   if ::nInspField < 1 .or. ::nInspField > Len( aFields )
      return nil
   endif
   if aFields[ ::nInspField ][ 3 ] == "choice"
      ::InspCycle( 1 )
      return nil
   endif
   if aFields[ ::nInspField ][ 3 ] == "color"
      ::InspPickColor()
      return nil
   endif
   if aFields[ ::nInspField ][ 3 ] != "text"
      return nil
   endif

   cKey   = aFields[ ::nInspField ][ 2 ]
   cVal   = ::InspValue( cKey )
   aRect  = ::InspRect()
   nRow   = aRect[ 1 ] + ::nInspField
   nCol   = aRect[ 2 ] + 11
   nWidth = aRect[ 4 ] - aRect[ 2 ] - 12
   nPos   = Len( cVal ) + 1
   nOff   = 0

   hBefore = DsnSnapshot( Self )

   // the control-redraw idle repaints the inspector on every InKey tick;
   // suspend it while the inline edit owns those cells
   ::SuspendUI()

#ifdef DSN_KEYLOG
   DsnKeyLog( -999 )
#endif
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
      nKey = DsnNormKey( InKey( 0, INKEY_ALL + HB_INKEY_EXT ) )
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
         case nKey == K_CTRL_Y .or. nKey == DSNK_CTRL_Y
            // clear the whole field, as in a Harbour GET
            cVal = ""
            nPos = 1
         case nKey >= 32 .and. nKey <= 255
            if Len( cVal ) < 200
               cVal = Left( cVal, nPos - 1 ) + Chr( nKey ) + SubStr( cVal, nPos )
               nPos++
            endif
      endcase
#ifdef DSN_KEYLOG
      DsnKeyLog2( nKey, cVal, nPos )
#endif
   enddo
   SetCursor( SC_NONE )
   ::ResumeUI()

   if lApply
      ::PushSnapshot( hBefore )
      ::InspSetText( cKey, cVal )
   endif
   ::Redraw()

return nil

//-----------------------------------------------------------------------------------------//
// visual picker for the dialog color fields: writes the same validated
// model properties as the DlgProperties GETs (cDlgClrBack/Text/Focus), so
// JSON persistence (colorback/colortext/colorfocus) and PRG generation
// pick the change up with no further plumbing

METHOD InspPickColor() CLASS HbDesigner

   local aFields, cKey, cOld, cNew, cKind, cCtx, hBefore

   if ::oWnd == NIL
      return nil
   endif
   aFields = ::InspFields()
   if ::nInspField < 1 .or. ::nInspField > Len( aFields )
      return nil
   endif
   if aFields[ ::nInspField ][ 3 ] != "color"
      return nil
   endif
   cKey  = aFields[ ::nInspField ][ 2 ]
   cOld  = ::InspValue( cKey )
   cKind = If( cKey == "dlgfocus", "pair", If( cKey == "dlgback", "bg", "fg" ) )
   cCtx  = If( cKey == "dlgback", ::cDlgClrText, ::cDlgClrBack )

   hBefore = DsnSnapshot( Self )

   ::SuspendUI()
   cNew = DsnColorPick( cOld, aFields[ ::nInspField ][ 1 ] + " color", cKind, cCtx )
   ::ResumeUI()

   if cNew != NIL .and. DsnValidColor( cNew )
      ::PushSnapshot( hBefore )
      do case
         case cKey == "dlgback"  ; ::cDlgClrBack  = cNew
         case cKey == "dlgtext"  ; ::cDlgClrText  = cNew
         case cKey == "dlgfocus" ; ::cDlgClrFocus = cNew
      endcase
      ::oWnd:cColor = ::cDlgColor
      ::lDirty = .T.
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
   local nSkipped := 0, nConflicts := 0, nSBarHidden := 0
   local cCode  := DsnGenCode( hModel, @nSkipped, @nConflicts )
   local cFailInfo := ""
   local oCtrl
   local cFile  := Lower( ::cDlgName ) + ".prg"

   if File( cFile )
      ::SuspendUI()
      if DsnConfirm( "Overwrite " + cFile + "?", { "&Yes", "&No" } ) != 1
         ::ResumeUI()
         return nil
      endif
      ::ResumeUI()
   endif

   nSBarHidden = 0
   for each oCtrl in hModel[ "controls" ]
      if DsnListSBarHidden( oCtrl )
         nSBarHidden++
      endif
   next

   if DsnSafeMemoWrit( cFile, cCode, @cFailInfo )
      ::ShowHint( "Generated " + cFile + ;
         If( nSkipped > 0, " (" + hb_ntos( nSkipped ) + " without items skipped)", "" ) + ;
         If( nConflicts > 0, " (" + hb_ntos( nConflicts ) + " name conflicts resolved)", "" ) + ;
         If( nSBarHidden > 0, " (" + hb_ntos( nSBarHidden ) + ;
            " list/dropdown too short: scrollbar won't be drawn)", "" ) )
      return cFile
   else
      ::SuspendUI()
      DsnWriteError( "Could not write " + cFile + ": " + cFailInfo )
      ::ResumeUI()
      ::ShowHint( "Generate failed; design kept open. Choose another path and try again" )
   endif

return nil

//-----------------------------------------------------------------------------------------//
// "Generate and open" (F2 palette): generate, then ask the IDE to open the
// file in the editor and leave the designer so the IDE can process its
// queue. QueueOpen is an editor-fixes contract method (no __ObjHasMessage
// in this Harbour, so the guard scans the method list): guard so this keeps
// working (generate only, no exit) against an IDE that does not have it.
// A dirty model gets the same discard confirmation as Esc: no silent loss.

METHOD GenerateAndOpen() CLASS HbDesigner

   local cFile := ::GeneratePrg()
   local nChoice

   if cFile != nil
      if AScan( __objGetMethodList( ::oIde ), {|m| m == "QUEUEOPEN"} ) > 0
         if ::lDirty
            ::SuspendUI()
            nChoice = DsnConfirm( "Discard unsaved changes?", { "&Yes", "&No" } )
            ::ResumeUI()
            if nChoice == 1
               ::oIde:QueueOpen( cFile )   // queued only once the exit is accepted
               ::lEnd = .T.
            else
               ::ShowHint( "Generated " + cFile + " (not queued)" )
            endif
         else
            ::oIde:QueueOpen( cFile )
            ::lEnd = .T.
         endif
      else
         ::ShowHint( "Generated " + cFile + " (this IDE cannot open it yet)" )
      endif
   endif

return nil

//-----------------------------------------------------------------------------------------//
// Standalone helpers (no UI): model <-> JSON, code generation.
// Kept UI free so they can be reused and tested outside the IDE.
//-----------------------------------------------------------------------------------------//

//
// DsnNormKey(): normalize InKey() codes from the HB_INKEY_EXT mask.
// gttrm emits 0x41000000 + ( modifiers << 16 ) + keycode for every key,
// which removes the classic alias collisions. Codes with unique classic
// equivalents map back to them (arrows, F-keys, Enter, Esc, Tab, Del, Home,
// Shift-Tab, Ctrl+Up/Down); colliding ones map to the private DSNK_* range
// (Ctrl+letters, Ctrl+Left/Right). Mouse/GT events carry the classic code
// in the low 16 bits. Classic input (terminals without EXT support) passes
// through unchanged; unknown EXT codes pass through as harmless no-ops.
//
#ifdef DSN_KEYLOG
function DsnKeyLog2( nKey, cVal, nPos )
   local hf
   if ! hb_FileExists( "/tmp/dsnkeys.log" )
      FClose( FCreate( "/tmp/dsnkeys.log" ) )
   endif
   hf := FOpen( "/tmp/dsnkeys.log", 2 )
   if hf != -1
      FSeek( hf, 0, 2 )
      FWrite( hf, hb_NToS( nKey ) + "=[" + cVal + "]p" + hb_NToS( nPos ) + " " )
      FClose( hf )
   endif
return nil

function DsnKeyLog( nKey )
   local hf
   if ! hb_FileExists( "/tmp/dsnkeys.log" )
      FClose( FCreate( "/tmp/dsnkeys.log" ) )
   endif
   hf := FOpen( "/tmp/dsnkeys.log", 2 )
   if hf != -1
      FSeek( hf, 0, 2 )
      FWrite( hf, hb_NToS( nKey ) + " " )
      FClose( hf )
   endif
return nil
#endif

function DsnNormKey( nKey )
   local nLow, nMod
   local aFKeys := { K_F1, K_F2, K_F3, K_F4, K_F5, K_F6, K_F7, K_F8, K_F9, K_F10, K_F11, K_F12 }

   if nKey < 0x41000000
      return nKey                          // already classic
   endif
   nKey -= 0x41000000                       // the base has bits in the mod field (0x4100)
   nLow = hb_BitAnd( nKey, 0xFFFF )
   nMod = hb_BitShift( nKey, -16 )
   if nLow >= 1000                          // mouse / GT event: classic code in low16
      return nLow
   endif
   nMod = hb_BitAnd( nMod, 0xFF )          // 0x200 is a text-event marker, not a modifier
   if ( nMod == 0 .or. nMod == 1 ) .and. nLow >= 32 .and. nLow <= 255
      return nLow                          // printable ASCII (shift arrives pre-applied)
   endif
   do case
      case nMod == 2                        // Ctrl
         if nLow >= 65 .and. nLow <= 90
            return DSNK_CTRL_BASE + nLow - 65
         endif
         if nLow == 13
            return K_CTRL_UP
         elseif nLow == 14
            return K_CTRL_DOWN
         elseif nLow == 15
            return DSNK_CTRLLEFT
         elseif nLow == 16
            return DSNK_CTRLRIGHT
         endif
      case nMod == 1                        // Shift
         if nLow == 24
            return K_SH_TAB
         endif
      case nMod == 0
         do case
            case nLow == 13 ; return K_UP
            case nLow == 14 ; return K_DOWN
            case nLow == 15 ; return K_LEFT
            case nLow == 16 ; return K_RIGHT
            case nLow == 8  ; return K_BS
            case nLow == 23 ; return K_BS   // gttrm EXT BackSpace
            case nLow == 17 ; return K_HOME
            case nLow == 18 ; return K_END
            case nLow == 22 ; return K_DEL
            case nLow == 24 ; return K_TAB
            case nLow == 25 ; return K_ESC
            case nLow == 26 ; return K_ENTER
            case nLow >= 1 .and. nLow <= 12
               return aFKeys[ nLow ]
         endcase
   endcase

return nKey + 0x41000000                   // unknown EXT code: harmless no-op in the loop

//-----------------------------------------------------------------------------------------//

function DsnBuildModel( oDesigner )

   local hModel := { "name"     => oDesigner:cDlgName, ;
                     "caption"  => oDesigner:cDlgCaption, ;
                     "width"    => oDesigner:nDlgWidth, ;
                     "height"   => oDesigner:nDlgHeight, ;
                     "color"    => oDesigner:cDlgColor, ;
                     "colortext"  => oDesigner:cDlgClrText, ;
                     "colorback"  => oDesigner:cDlgClrBack, ;
                     "colorfocus" => oDesigner:cDlgClrFocus, ;
                     "controls" => {} }
   local oCtrl

   for each oCtrl in oDesigner:aControls
      AAdd( hModel[ "controls" ], oCtrl )
   next

return hModel

//-----------------------------------------------------------------------------------------//
// size of a control in cells: { nWidth, nHeight }

// default model for a new control of each type; used by AddControl and by the
// placing ghost so the ghost shows the real size the control will have

function DsnNewControl( cType, aControls )

   local oCtrl := { "type" => cType, "row" => 0, "col" => 0 }

   do case
      case cType == DSN_SAY
         oCtrl[ "caption" ] = "Label"
      case cType == DSN_GET
         oCtrl[ "variable" ] = DsnUniqueVar( aControls, "cVar" )
         oCtrl[ "width"    ] = 10
      case cType == DSN_CHECKBOX
         oCtrl[ "caption"  ] = "Check"
         oCtrl[ "variable" ] = DsnUniqueVar( aControls, "lVar" )
      case cType == DSN_BUTTON
         oCtrl[ "caption"     ] = "OK"
         oCtrl[ "accelerator" ] = "O"
         oCtrl[ "action"      ] = "lOk := .T., oDlg:End()"
         oCtrl[ "style"       ] = "shadow"
      case cType == DSN_RADIO
         oCtrl[ "variable" ] = DsnUniqueVar( aControls, "nVar" )
         oCtrl[ "items"    ] = "Option 1,Option 2,Option 3"
      case cType == DSN_LISTBOX .or. cType == DSN_COMBOBOX
         oCtrl[ "variable" ] = DsnUniqueVar( aControls, "nVar" )
         oCtrl[ "items"    ] = "Item 1,Item 2,Item 3"
         oCtrl[ "width"    ] = 20
         oCtrl[ "height"   ] = 6
   endcase

return oCtrl

//-----------------------------------------------------------------------------------------//

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
         if hb_HGetDef( oCtrl, "style", "shadow" ) == "brackets"
            nWidth  = Len( hb_HGetDef( oCtrl, "caption", "" ) ) + 4   // "[ Caption ]"
            nHeight = 1
         else
            nWidth  = Len( hb_HGetDef( oCtrl, "caption", "" ) ) + 4   // inset + face + shadow
            nHeight = 2   // caption row + shadow row
         endif
      case oCtrl[ "type" ] == DSN_RADIO
         nWidth  = 8 + DsnMaxItemLen( oCtrl )
         nHeight = Len( DsnItems( oCtrl ) ) + 2
      case ( oCtrl[ "type" ] == DSN_LISTBOX .or. oCtrl[ "type" ] == DSN_COMBOBOX )
         nWidth  = hb_HGetDef( oCtrl, "width", 20 )
         nHeight = hb_HGetDef( oCtrl, "height", 6 )
   endcase

return { nWidth, nHeight }

//-----------------------------------------------------------------------------------------//
// resize a control by deltas, clamped to its minimum size and to the dialog
// interior; only GET (width) and LISTBOX (width and height) are resizable -
// the rest derive their size from caption/items. Returns .T. when it changed.

function DsnResizable( oCtrl )

return oCtrl[ "type" ] == DSN_GET .or. ( oCtrl[ "type" ] == DSN_LISTBOX .or. oCtrl[ "type" ] == DSN_COMBOBOX )

//-----------------------------------------------------------------------------------------//

function DsnResize( oCtrl, nDWidth, nDHeight, nDlgWidth, nDlgHeight )

   local lChanged := .F.
   local nW, nH

   do case
      case oCtrl[ "type" ] == DSN_GET
         nW = Max( 1, Min( nDlgWidth - 2 - oCtrl[ "col" ], ;
              hb_HGetDef( oCtrl, "width", 10 ) + nDWidth ) )
         if nW != hb_HGetDef( oCtrl, "width", 10 )
            oCtrl[ "width" ] = nW
            lChanged = .T.
         endif

      case ( oCtrl[ "type" ] == DSN_LISTBOX .or. oCtrl[ "type" ] == DSN_COMBOBOX )
         nW = Max( 4, Min( nDlgWidth - 2 - oCtrl[ "col" ], ;
              hb_HGetDef( oCtrl, "width", 20 ) + nDWidth ) )
         nH = Max( If( oCtrl[ "type" ] == DSN_COMBOBOX, 4, 3 ), Min( nDlgHeight - 2 - oCtrl[ "row" ], ;
              hb_HGetDef( oCtrl, "height", 6 ) + nDHeight ) )
         if nW != hb_HGetDef( oCtrl, "width", 20 )
            oCtrl[ "width" ] = nW
            lChanged = .T.
         endif
         if nH != hb_HGetDef( oCtrl, "height", 6 )
            oCtrl[ "height" ] = nH
            lChanged = .T.
         endif
   endcase

return lChanged

//-----------------------------------------------------------------------------------------//
// items of a radiogroup/listbox as an array (CSV in the "items" property)

function DsnItems( oCtrl )

   local aItems := {}, cItem
   local xItems := hb_HGetDef( oCtrl, "items", "" )

   // a model decoded straight from json may carry items as an array
   if HB_ISARRAY( xItems )
      for each cItem in xItems
         if HB_ISSTRING( cItem ) .and. ! Empty( AllTrim( cItem ) )
            AAdd( aItems, AllTrim( cItem ) )
         endif
      next
      return aItems
   endif

   for each cItem in hb_ATokens( xItems, "," )
      cItem = AllTrim( cItem )
      if ! Empty( cItem )
         AAdd( aItems, cItem )
      endif
   next

return aItems

//-----------------------------------------------------------------------------------------//
// .T. when a listbox's items overflow its visible rows (so codegen emits
// SCROLLBAR) but its height is under 6: the stock ScrollBar needs a bar
// length >= 2 (height - 4) to draw, so the bar stays invisible. Used to
// warn without blocking or resizing.

function DsnListSBarHidden( oCtrl )

   local nHeight

   if oCtrl[ "type" ] != DSN_LISTBOX .and. oCtrl[ "type" ] != DSN_COMBOBOX
      return .F.
   endif
   nHeight = hb_HGetDef( oCtrl, "height", 6 ) - If( oCtrl[ "type" ] == DSN_COMBOBOX, 1, 0 )

return nHeight < 6 .and. Len( DsnItems( oCtrl ) ) > nHeight - 2

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

// clips a control's frame rect to the drawable area (window interior and
// screen) and returns { nBottom, nRight } for DispBox, or NIL when fewer
// than two rows or columns remain visible (a box needs both dimensions).
// controls wider or taller than a clamped viewport keep a visible frame
// instead of losing it completely

function DsnFrameClip( nARow, nACol, nWidth, nHeight, nWndBottom, nMaxCol )

   local nB := Min( Min( nARow + nHeight - 1, nWndBottom - 1 ), MaxRow() )
   local nR := Min( nACol + nWidth - 1, nMaxCol )

return iif( nB > nARow .and. nR > nACol, { nB, nR }, NIL )

//-----------------------------------------------------------------------------------------//

procedure DsnDrawControl( oWnd, oCtrl, lSelected, cSelColor, nOffRow, nOffCol )

   local nARow, nACol
   local nMaxCol := Min( oWnd:nRight - 1, MaxCol() )
   local cCaption := hb_HGetDef( oCtrl, "caption", "" )
   local aDlgPair := DsnDlgPair( oWnd:cColor )
   local lDarkDlg := aDlgPair[ 2 ] != "W"
   local cDlgText := aDlgPair[ 1 ] + "/" + aDlgPair[ 2 ]
   local cColor, cText, nWidth, n, aSize, aItems, aClip, nPos
   local cHotKey := If( aDlgPair[ 2 ] != "W", "Y+/" + aDlgPair[ 2 ], DSN_CLR_AREAKEY )

   // design time: & marks accelerators on checkbox/button captions, so it is
   // not drawn there; SAY captions are literal (runtime Say shows & as-is)

   hb_default( @lSelected, .F. )
   hb_default( @cSelColor, CLR_SELECTED )
   hb_default( @nOffRow, 0 )
   hb_default( @nOffCol, 0 )

   nARow = oWnd:nTop + 1 + oCtrl[ "row" ] - nOffRow
   nACol = oWnd:nLeft + 1 + oCtrl[ "col" ] - nOffCol

   if nARow <= oWnd:nTop .or. nARow >= oWnd:nBottom .or. ;
      nARow < 0 .or. nARow > MaxRow() .or. nACol > nMaxCol .or. nACol < 0
      return
   endif

   do case
      case oCtrl[ "type" ] == DSN_SAY
         cColor = If( lSelected, cSelColor, If( lDarkDlg, cDlgText, CLR_SAY ) )
         cText  = SubStr( cCaption, 1, Max( 0, nMaxCol - nACol + 1 ) )
         hb_DispOutAt( nARow, nACol, cText, cColor )

      case oCtrl[ "type" ] == DSN_GET
         cColor = If( lSelected, cSelColor, If( lDarkDlg, "N/W", CLR_GET ) )
         nWidth = hb_HGetDef( oCtrl, "width", 10 )
         hb_DispOutAt( nARow, nACol, ;
            Replicate( hb_UTF8ToStr( "░" ), Min( nWidth, Max( 0, nMaxCol - nACol + 1 ) ) ), cColor )

      case oCtrl[ "type" ] == DSN_CHECKBOX
         cColor = If( lSelected, cSelColor, If( lDarkDlg, cDlgText, CLR_CHECKBOX ) )
         cText  = SubStr( "[ ] " + StrTran( cCaption, "&", "" ), 1, Max( 0, nMaxCol - nACol + 1 ) )
         hb_DispOutAt( nARow, nACol, cText, cColor )

      case oCtrl[ "type" ] == DSN_BUTTON
         cColor = If( lSelected, CLR_SEL_BTN, If( lDarkDlg, "N/W", CLR_BUTTON ) )
         if hb_HGetDef( oCtrl, "style", "shadow" ) == "brackets"
            // bracket look: "[ Caption ]" on one row, no shadow
            cText = "[ " + StrTran( cCaption, "&", "" ) + " ]"
            hb_DispOutAt( nARow, nACol, ;
               SubStr( cText, 1, Max( 0, nMaxCol - nACol + 1 ) ), cColor )
         else
            cText  = " " + StrTran( cCaption, "&", "" ) + " "
            nWidth = Len( cText )
            // the face sits one cell right of the control column: the left
            // inset keeps the dialog color (the invisible half of the
            // classic TV shadow), same layout as the runtime PushButton
            hb_DispOutAt( nARow, nACol + 1, ;
               SubStr( cText, 1, Max( 0, nMaxCol - nACol ) ), cColor )
            // shadow: same slim Turbo Vision look as the runtime PushButton
            if HBBtnShadowUtf8()
               // half blocks on the dialog background: right cell (lower
               // half) and stripe below (upper half), shifted one cell
               if nACol + nWidth + 1 <= nMaxCol
                  hb_DispOutAt( nARow, nACol + nWidth + 1, hb_UTF8ToStr( "▄" ), "N/" + aDlgPair[ 2 ] )
               endif
               if nARow + 1 < oWnd:nBottom .and. nARow + 1 <= MaxRow()
                  n = Min( nWidth, Max( 0, nMaxCol - nACol - 1 ) )
                  if n > 0
                     hb_DispOutAt( nARow + 1, nACol + 2, Replicate( hb_UTF8ToStr( "▀" ), n ), "N/" + aDlgPair[ 2 ] )
                  endif
               endif
            else
               // codepage-safe fallback: solid dark cells
               if nACol + nWidth + 1 <= nMaxCol
                  hb_DispOutAt( nARow, nACol + nWidth + 1, " ", "N/N" )
               endif
               if nARow + 1 < oWnd:nBottom .and. nARow + 1 <= MaxRow()
                  n = Min( nWidth, Max( 0, nMaxCol - nACol - 1 ) )
                  if n > 0
                     hb_DispOutAt( nARow + 1, nACol + 2, Replicate( " ", n ), "N/N" )
                  endif
               endif
            endif
         endif

      case oCtrl[ "type" ] == DSN_RADIO
         cColor = If( lSelected, cSelColor, If( lDarkDlg, cDlgText, DSN_CLR_AREA ) )
         aSize  = DsnControlSize( oCtrl )
         aItems = DsnItems( oCtrl )
         // celeste interior on light dialogs, like the fill the generated
         // code paints behind the runtime radiogroup
         if ! lDarkDlg
            for n = 1 to aSize[ 2 ] - 2
               if nARow + n < oWnd:nBottom .and. nARow + n <= MaxRow()
                  hb_DispOutAt( nARow + n, nACol + 1, ;
                     Space( Max( 0, Min( aSize[ 1 ] - 2, nMaxCol - nACol - 1 ) ) ), DSN_CLR_AREA )
               endif
            next
         endif
         aClip = DsnFrameClip( nARow, nACol, aSize[ 1 ], aSize[ 2 ], oWnd:nBottom, nMaxCol )
         if aClip != NIL
            DispBox( nARow, nACol, aClip[ 1 ], aClip[ 2 ], 1, cColor )
         endif
         for n = 1 to Len( aItems )
            cText = If( n == 1, "(*) ", "( ) " ) + StrTran( aItems[ n ], "&", "" )
            if nARow + n < oWnd:nBottom .and. nARow + n <= MaxRow()
               hb_DispOutAt( nARow + n, nACol + 2, ;
                  SubStr( cText, 1, Max( 0, Min( aSize[ 1 ] - 4, nMaxCol - nACol - 1 ) ) ), cColor )
               // accelerator letter (char after &) in a distinct color, as the
               // runtime radiogroup paints it (designer.md documents this look)
               nPos = At( "&", aItems[ n ] )
               if nPos > 0 .and. nPos < Len( aItems[ n ] ) .and. 4 + nPos <= aSize[ 1 ] - 4
                  hb_DispOutAt( nARow + n, nACol + 2 + 4 + nPos - 1, ;
                     SubStr( aItems[ n ], nPos + 1, 1 ), cHotKey )
               endif
            endif
         next

      case oCtrl[ "type" ] == DSN_COMBOBOX
         cColor = If( lSelected, cSelColor, If( lDarkDlg, "N/W", DSN_CLR_AREA ) )
         aSize = DsnControlSize( oCtrl )
         aItems = DsnItems( oCtrl )
         cText = PadR( If( Empty( aItems ), "", aItems[ 1 ] ), Max( 0, aSize[ 1 ] - 1 ) ) + Chr( 31 )
         hb_DispOutAt( nARow, nACol, Left( cText, Max( 0, nMaxCol - nACol + 1 ) ), cColor )

      case oCtrl[ "type" ] == DSN_LISTBOX
         cColor = If( lSelected, cSelColor, If( lDarkDlg, "N/W", DSN_CLR_AREA ) )
         aSize  = DsnControlSize( oCtrl )
         aItems = DsnItems( oCtrl )
         aClip = DsnFrameClip( nARow, nACol, aSize[ 1 ], aSize[ 2 ], oWnd:nBottom, nMaxCol )
         if aClip != NIL
            DispBox( nARow, nACol, aClip[ 1 ], aClip[ 2 ], 1, cColor )
         endif
         for n = 1 to Min( Len( aItems ), aSize[ 2 ] - 2 )
            cText = PadR( SubStr( aItems[ n ], 1, aSize[ 1 ] - 2 ), aSize[ 1 ] - 2 )
            if nARow + n < oWnd:nBottom .and. nARow + n <= MaxRow()
               hb_DispOutAt( nARow + n, nACol + 1, ;
                  SubStr( cText, 1, Max( 0, nMaxCol - nACol ) ), If( n == 1, If( lDarkDlg, "W+/N", "N+/BG" ), cColor ) )
            endif
         next
         // fill empty interior rows so the box keeps a uniform background,
         // like the runtime listbox (otherwise the dialog bg shows through)
         for n = Len( aItems ) + 1 to aSize[ 2 ] - 2
            if nARow + n < oWnd:nBottom .and. nARow + n <= MaxRow()
               hb_DispOutAt( nARow + n, nACol + 1, ;
                  Space( Max( 0, Min( aSize[ 1 ] - 2, nMaxCol - nACol ) ) ), cColor )
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
   local lNeedFill := .F.      // a radiogroup on a light dialog needs its celeste area fill
   local hDeclared := { => }   // variable name => bound type (C/L/N)
   local hGenVars  := { => }   // control index => variable name used (model untouched)
   local cName := hb_HGetDef( hModel, "name", "MyDialog" )
   local cDlgColor := hb_HGetDef( hModel, "color", CLR_DIALOG )
   local cClrFocus := DsnStr( hb_HGetDef( hModel, "colorfocus", "" ), "" )
   local aDlgPair

   // the split dialog properties win over the combined "color" key
   if ! Empty( DsnStr( hb_HGetDef( hModel, "colortext", "" ), "" ) )
      cDlgColor = AllTrim( hb_HGetDef( hModel, "colortext", "W+" ) ) + "/" + ;
                  AllTrim( hb_HGetDef( hModel, "colorback", "W" ) )
   endif
   if Empty( AllTrim( DsnStr( cDlgColor, "" ) ) )
      cDlgColor = CLR_DIALOG
   endif
   aDlgPair = DsnDlgPair( cDlgColor )   // control palettes derive from it
   if Empty( cClrFocus ) .or. ! DsnValidColor( cClrFocus )
      cClrFocus = DSN_CLR_FOCUS
   endif

   nSkipped   = 0
   nConflicts = 0

   // Harbour identifiers are case-insensitive. Reserve generator-owned locals
   // before resolving user bindings, including item arrays declared later.
   hb_HCaseMatch( hDeclared, .F. )
   hDeclared[ "oDlg" ] := "reserved"
   hDeclared[ "GetList" ] := "reserved"
   hDeclared[ "lOk" ] := "reserved"
   hDeclared[ "lDummy" ] := "reserved"
   for each oCtrl in hModel[ "controls" ]
      if oCtrl[ "type" ] == DSN_RADIO
         hDeclared[ "aButt" + hb_ntos( oCtrl:__enumIndex() ) ] := "reserved"
      elseif oCtrl[ "type" ] == DSN_LISTBOX .or. oCtrl[ "type" ] == DSN_COMBOBOX
         hDeclared[ "aItems" + hb_ntos( oCtrl:__enumIndex() ) ] := "reserved"
      endif
   next

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
      if cType == "" .or. ( oCtrl[ "type" ] $ DSN_RADIO + "|" + DSN_LISTBOX + "|" + DSN_COMBOBOX .and. Empty( DsnItems( oCtrl ) ) )
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
         case ( oCtrl[ "type" ] == DSN_LISTBOX .or. oCtrl[ "type" ] == DSN_COMBOBOX )
            cCode += "   local aItems" + hb_ntos( oCtrl:__enumIndex() ) + hb_eol()
      endcase
   next

   cCode += "   local lDummy" + hb_eol()
   cCode += hb_eol()
   cCode += "   oDlg = HBWindow():Dialog( " + DsnQuote( hb_HGetDef( hModel, "caption", "Dialog" ) ) + ", " + ;
            hb_ntos( hb_HGetDef( hModel, "width", 40 ) ) + ", " + ;
            hb_ntos( hb_HGetDef( hModel, "height", 12 ) ) + ", " + ;
            DsnQuote( cDlgColor ) + " )" + hb_eol()
   cCode += hb_eol()
   if aDlgPair[ 2 ] != "W"
      // hbbutton's BtnDisplay paints its 3D shadow hardcoded "N/W", which
      // shows as a white shadow on a colored dialog: re-register the same
      // display with the shadow on the dialog background instead
      cCode += "   __ClsModMsg( PushButton( 0, 0 ):ClassH, 'DISPLAY', @DsnBtnDisplay() )" + hb_eol()
      cCode += "   __ClsModMsg( PushButton( 0, 0 ):ClassH, 'HITTEST', @DsnBtnHitTest() )" + hb_eol()
      cCode += hb_eol()
   endif

   // item arrays for RADIOGROUP/LISTBOX reference the dialog position
   for each oCtrl in hModel[ "controls" ]
      do case
         case oCtrl[ "type" ] == DSN_RADIO
            if ! Empty( DsnItems( oCtrl ) )
               cCode += "   aButt" + hb_ntos( oCtrl:__enumIndex() ) + " := " + ;
                        DsnRadioButtsCode( oCtrl ) + hb_eol()
               cCode += "   AEval( aButt" + hb_ntos( oCtrl:__enumIndex() ) + ;
                        ", {| o | o:colorSpec := '" + DsnClrRadioFor( cDlgColor ) + "' } )" + hb_eol()
               if aDlgPair[ 2 ] == "W"
                  // celeste interior behind the group: the stock radiogroup
                  // only paints its caption cells, so the area is filled first
                  aSize = DsnControlSize( oCtrl )
                  cCode += "   DsnFillArea( oDlg, oDlg:nTop + " + hb_ntos( oCtrl[ "row" ] + 2 ) + ;
                           ", oDlg:nLeft + " + hb_ntos( oCtrl[ "col" ] + 2 ) + ;
                           ", oDlg:nTop + " + hb_ntos( oCtrl[ "row" ] + aSize[ 2 ] - 1 ) + ;
                           ", oDlg:nLeft + " + hb_ntos( oCtrl[ "col" ] + aSize[ 1 ] - 1 ) + ;
                           ", 'N/BG' )" + hb_eol()
                  lNeedFill = .T.
               endif
            endif
         case ( oCtrl[ "type" ] == DSN_LISTBOX .or. oCtrl[ "type" ] == DSN_COMBOBOX )
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
            if aDlgPair[ 2 ] == "W"
               cCode += "   oDlg:Say( " + hb_ntos( oCtrl[ "row" ] + 1 ) + ", " + ;
                        hb_ntos( oCtrl[ "col" ] + 1 ) + ", " + ;
                        DsnQuote( oCtrl[ "caption" ] ) + " )" + hb_eol()
            else
               // oDlg:Say has no color parameter (it paints GetColors()[ 8 ],
               // a gray background that clashes with a colored dialog)
               cCode += "   hb_DispOutAt( oDlg:nTop + " + hb_ntos( oCtrl[ "row" ] + 1 ) + ;
                        ", oDlg:nLeft + " + hb_ntos( oCtrl[ "col" ] + 1 ) + ", " + ;
                        DsnQuote( oCtrl[ "caption" ] ) + ", '" + aDlgPair[ 1 ] + "/" + ;
                        aDlgPair[ 2 ] + "' )" + hb_eol()
            endif

         case oCtrl[ "type" ] == DSN_GET
            // std.ch rule order is VALID/WHEN/SEND: with events the COLOR
            // clause cannot be used, so emit its exact expansion instead
            cCode += "   @ oDlg:nTop + " + hb_ntos( oCtrl[ "row" ] + 1 ) + ;
                     ", oDlg:nLeft + " + hb_ntos( oCtrl[ "col" ] + 1 ) + ;
                     " GET " + hGenVars[ n ] + DsnEvnWV( oCtrl ) + ;
                     If( Empty( DsnEvnWV( oCtrl ) ), ;
                        " COLOR '" + DsnClrGetFor( cDlgColor, cClrFocus ) + "'", ;
                        " SEND colorDisp( '" + DsnClrGetFor( cDlgColor, cClrFocus ) + "' )" ) + hb_eol()

         case oCtrl[ "type" ] == DSN_CHECKBOX
            cCode += "   @ oDlg:nTop + " + hb_ntos( oCtrl[ "row" ] + 1 ) + ;
                     ", oDlg:nLeft + " + hb_ntos( oCtrl[ "col" ] + 1 ) + ;
                     " GET " + hGenVars[ n ] + ;
                     " CHECKBOX" + DsnEvnWV( oCtrl ) + ;
                     " CAPTION " + DsnQuote( oCtrl[ "caption" ] ) + ;
                     " STYLE '[X ]'" + ;
                     " COLOR '" + DsnClrCheckBoxFor( cDlgColor, cClrFocus ) + "'" + ;
                     DsnEvnFS( oCtrl ) + hb_eol()

         case oCtrl[ "type" ] == DSN_BUTTON
            cCode += "   @ oDlg:nTop + " + hb_ntos( oCtrl[ "row" ] + 1 ) + ;
                     ", oDlg:nLeft + " + hb_ntos( oCtrl[ "col" ] + 1 ) + ;
                     " GET lDummy PUSHBUTTON" + DsnEvnWV( oCtrl ) + " CAPTION " + ;
                     DsnQuote( DsnAccelCaption( hb_HGetDef( oCtrl, "caption", "" ), ;
                        hb_HGetDef( oCtrl, "accelerator", "" ) ) ) + " ;" + hb_eol()
            cCode += "      COLOR '" + DsnClrButtonFor( cDlgColor ) + "'" + ;
                     If( Empty( hb_HGetDef( oCtrl, "focus", "" ) ), "", ;
                        " FOCUS {|| " + AllTrim( oCtrl[ "focus" ] ) + " }" ) + ;
                     " STATE { || " + DsnButtonAction( oCtrl ) + " }" + ;
                     If( hb_HGetDef( oCtrl, "style", "shadow" ) == "brackets", ;
                        " STYLE '[]'", "" ) + hb_eol()

         case ( oCtrl[ "type" ] == DSN_RADIO .or. ( oCtrl[ "type" ] == DSN_LISTBOX .or. oCtrl[ "type" ] == DSN_COMBOBOX ) ) .and. ;
               Empty( DsnItems( oCtrl ) )
            // an item-less radio/listbox cannot run: note it and skip it
            nSkipped++
            cCode += "   // skipped " + oCtrl[ "type" ] + " at row " + ;
                     hb_ntos( oCtrl[ "row" ] + 1 ) + ", col " + ;
                     hb_ntos( oCtrl[ "col" ] + 1 ) + ": no items" + hb_eol()

         case oCtrl[ "type" ] == DSN_RADIO .or. ( oCtrl[ "type" ] == DSN_LISTBOX .or. oCtrl[ "type" ] == DSN_COMBOBOX )
            aSize = DsnControlSize( oCtrl )
            if oCtrl[ "type" ] == DSN_COMBOBOX
               aSize[ 2 ] := Max( 4, Min( hb_HGetDef( oCtrl, "height", 6 ), ;
                  hb_HGetDef( hModel, "height", 12 ) - 2 - oCtrl[ "row" ] ) )
            endif
            if DsnListSBarHidden( oCtrl )
               cCode += "   // warning: " + oCtrl[ "type" ] + " " + hGenVars[ n ] + ;
                        " popup too short: the scrollbar will not be drawn" + hb_eol()
            endif
            cCode += "   @ oDlg:nTop + " + hb_ntos( oCtrl[ "row" ] + 1 ) + ;
                     ", oDlg:nLeft + " + hb_ntos( oCtrl[ "col" ] + 1 ) + ;
                     ", oDlg:nTop + " + hb_ntos( oCtrl[ "row" ] + aSize[ 2 ] ) + ;
                     ", oDlg:nLeft + " + hb_ntos( oCtrl[ "col" ] + aSize[ 1 ] ) + ;
                     " GET " + hGenVars[ n ] + ;
                     If( oCtrl[ "type" ] == DSN_RADIO, ;
                        " RADIOGROUP aButt", " LISTBOX aItems" ) + ;
                     hb_ntos( n ) + If( oCtrl[ "type" ] == DSN_COMBOBOX, " DROPDOWN", "" ) + DsnEvnWV( oCtrl ) + ;
                     If( ( oCtrl[ "type" ] == DSN_LISTBOX .or. oCtrl[ "type" ] == DSN_COMBOBOX ) .and. ;
                        Len( DsnItems( oCtrl ) ) > aSize[ 2 ] - If( oCtrl[ "type" ] == DSN_COMBOBOX, 3, 2 ), " SCROLLBAR", "" ) + ;
                     If( oCtrl[ "type" ] == DSN_RADIO, ;
                        " COLOR '" + If( aDlgPair[ 2 ] == "W", ;
                           If( cClrFocus == DSN_CLR_FOCUS, "N/BG,N/BG,GR+/BG", ;
                              "N/BG,N/BG," + cClrFocus ), ;
                           aDlgPair[ 1 ] + "/" + aDlgPair[ 2 ] + "," + ;
                           aDlgPair[ 1 ] + "/" + aDlgPair[ 2 ] + "," + ;
                           If( cClrFocus == DSN_CLR_FOCUS, "Y+/" + aDlgPair[ 2 ], ;
                              cClrFocus ) ) + "'", ;
                        " COLOR '" + DsnClrListBoxFor( cDlgColor, cClrFocus ) + ;
                           If( oCtrl[ "type" ] == DSN_COMBOBOX, ",N/W", "" ) + "'" ) + ;
                     If( oCtrl[ "type" ] == DSN_RADIO, ;
                        If( Empty( hb_HGetDef( oCtrl, "focus", "" ) ), "", ;
                           " FOCUS {|| " + AllTrim( oCtrl[ "focus" ] ) + " }" ), ;
                        DsnEvnFS( oCtrl ) ) + hb_eol()
      endcase
   next

   if n > 0
      cCode += hb_eol()
   endif

   cCode += "   oDlg:Activate( GetList )" + hb_eol()
   cCode += hb_eol()
   cCode += "return lOk" + hb_eol()

   if aDlgPair[ 2 ] != "W"
      cCode += hb_eol()
      cCode += DsnBtnDisplayCode( aDlgPair[ 2 ] )
   endif
   if lNeedFill
      cCode += hb_eol()
      cCode += DsnFillAreaCode()
   endif

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
      case oCtrl[ "type" ] == DSN_RADIO .or. ( oCtrl[ "type" ] == DSN_LISTBOX .or. oCtrl[ "type" ] == DSN_COMBOBOX )
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

// WHEN/VALID clauses in std.ch rule order (VALID first); empty = no clause,
// so a model without events generates byte-identical code to before.
function DsnEvnWV( oCtrl )

   local cCode := ""

   if ! Empty( hb_HGetDef( oCtrl, "valid", "" ) )
      cCode += " VALID {|| " + AllTrim( oCtrl[ "valid" ] ) + " }"
   endif
   if ! Empty( hb_HGetDef( oCtrl, "when", "" ) )
      cCode += " WHEN {|| " + AllTrim( oCtrl[ "when" ] ) + " }"
   endif

return cCode

// FOCUS/STATE clauses (FOCUS first; radiogroup has no STATE in std.ch).
function DsnEvnFS( oCtrl )

   local cCode := ""

   if ! Empty( hb_HGetDef( oCtrl, "focus", "" ) )
      cCode += " FOCUS {|| " + AllTrim( oCtrl[ "focus" ] ) + " }"
   endif
   if ! Empty( hb_HGetDef( oCtrl, "state", "" ) )
      cCode += " STATE {|| " + AllTrim( oCtrl[ "state" ] ) + " }"
   endif

return cCode

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
                   DSN_BUTTON + "|" + DSN_RADIO + "|" + DSN_LISTBOX + "|" + DSN_COMBOBOX + "|"

   // drop entries that are not usable controls
   for n = Len( aControls ) to 1 step -1
      oCtrl = aControls[ n ]
      cType = If( HB_IsHash( oCtrl ), hb_HGetDef( oCtrl, "type", "" ), "" )
      if ! HB_IsString( cType ) .or. Empty( cType ) .or. ! ( "|" + cType + "|" $ cTypes )
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

      // Optional JSON fields must exist before direct indexed access.
      if "variable" $ oCtrl .and. ! HB_IsString( oCtrl[ "variable" ] )
         oCtrl[ "variable" ] := ""
      endif

      // items accepts a CSV string or a JSON array of strings
      if oCtrl[ "type" ] $ DSN_RADIO + "|" + DSN_LISTBOX + "|" + DSN_COMBOBOX
         if ! "items" $ oCtrl
            oCtrl[ "items" ] := ""
         endif
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
      if ( oCtrl[ "type" ] == DSN_LISTBOX .or. oCtrl[ "type" ] == DSN_COMBOBOX )
         oCtrl[ "width" ]  = Max( 4, Min( 40, Int( DsnNum( hb_HGetDef( oCtrl, "width", 20 ), 20 ) ) ) )
         oCtrl[ "height" ] = Max( If( oCtrl[ "type" ] == DSN_COMBOBOX, 4, 3 ), Min( 15, Int( DsnNum( hb_HGetDef( oCtrl, "height", 6 ), 6 ) ) ) )
      endif

      // every bound control needs a valid, non-empty variable name
      if oCtrl[ "type" ] $ DSN_GET + "|" + DSN_CHECKBOX + "|" + DSN_RADIO + "|" + DSN_LISTBOX + "|" + DSN_COMBOBOX
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

// the 16 foreground colors the visual picker offers, as Harbour color
// tokens verified against hb_ColorToN(). Cyan/magenta/yellow need the
// two-letter forms: C, M and Y are accepted by the validator for legacy
// specs but translate to N/N (invisible) in the GT, so the grid never
// emits them; the parser maps them onto the working forms. Brown is "GR".
// Backgrounds have no bright bit in a color pair (it is the blink bit):
// the background side of the picker offers only the first 8 entries

function DsnColorGrid()

return { "N", "B", "G", "BG", "R", "RB", "GR", "W", ;
         "N+", "B+", "G+", "BG+", "R+", "RB+", "GR+", "W+" }

//-----------------------------------------------------------------------------------------//

// parse one color token into { cBase, lBright, lBlink }, canonicalizing
// aliases onto GT-working letters: "C" -> "BG", "M" -> "RB", "Y" -> "GR+".
// Returns NIL for tokens outside the picker grid (U/I/X, invalid chars)

function DsnColorTokParse( cTok )

   local n, c, cBase := "", lBright := .F., lBlink := .F.

   if Empty( cTok )
      return NIL
   endif

   for n = 1 to Len( cTok )
      c = Upper( SubStr( cTok, n, 1 ) )
      if c == "+"
         lBright := .T.
      elseif c == "*"
         lBlink := .T.
      elseif c $ "WBGRNCMYUIX"
         cBase += c
      else
         return NIL
      endif
   next

   do case
      case cBase == "C" ; cBase := "BG"
      case cBase == "M" ; cBase := "RB"
      case cBase == "Y"
         cBase := "GR"
         lBright := .T.
   endcase

   if AScan( DsnColorGrid(), cBase + If( lBright, "+", "" ) ) == 0
      return NIL
   endif

return { cBase, lBright, lBlink }

//-----------------------------------------------------------------------------------------//

// inverse of DsnColorTokParse: token string, blink preserved

function DsnColorTokCompose( aTok )

return aTok[ 1 ] + If( aTok[ 2 ], "+", "" ) + If( aTok[ 3 ], "*", "" )

//-----------------------------------------------------------------------------------------//

// { fgTok, bgTok } of the first comma item of a color spec; missing sides
// default to the stock white dialog

function DsnColorPair( cSpec )

   local cFirst := AllTrim( hb_defaultValue( cSpec, "" ) )
   local nAt, cFg, cBg

   if Empty( cFirst )
      return { "W+", "W" }
   endif
   nAt = At( ",", cFirst )
   if nAt > 0
      cFirst = Left( cFirst, nAt - 1 )
   endif
   nAt = At( "/", cFirst )
   if nAt > 0
      cFg = Left( cFirst, nAt - 1 )
      cBg = SubStr( cFirst, nAt + 1 )
   else
      cFg = cFirst
      cBg = "W"
   endif

return { If( Empty( cFg ), "W+", cFg ), If( Empty( cBg ), "W", cBg ) }

//-----------------------------------------------------------------------------------------//

// 1-16 position of a token in DsnColorGrid(), blink ignored; 0 if outside

function DsnColorGridIndex( cTok )

   local aTok := DsnColorTokParse( cTok )

   if aTok == NIL
      return 0
   endif

return AScan( DsnColorGrid(), aTok[ 1 ] + If( aTok[ 2 ], "+", "" ) )

//-----------------------------------------------------------------------------------------//

// visual color picker modal for one dialog color property.
// cKind: "fg" (text color), "bg" (dialog background) or "pair" (focus
// fg/bg, Tab switches sides, first Enter moves to the background).
// cCtx is the live counterpart color used for an honest preview (the
// dialog back when picking text, the dialog text when picking back).
// Returns the new spec, or NIL on Esc. A blink modifier in the original
// value is preserved: the grid only edits hue and brightness.
// Background sides are limited to the 8 non-bright colors: the bright
// bit of a background is the blink bit, so bright backgrounds do not
// exist in a color pair and offering them would be decorative.

function DsnColorPick( cCurrent, cTitle, cKind, cCtx )

   local oDlg, aGrid := DsnColorGrid()
   local aTok, aTokBg, nSide := 1, nCur := { 1, 1 }, nKey, n
   local lPair := cKind == "pair"
   local cLight := { "W", "W+", "GR+", "BG", "BG+", "G+", "GR" }
   local cTok, cCellClr, cPreview, cNew := NIL
   local nRow1, nRow2, nPrevRow, nHintRow, nRow, nCol, nLim, nSide2

   cCurrent = AllTrim( hb_defaultValue( cCurrent, "" ) )
   cCtx     = AllTrim( hb_defaultValue( cCtx, "W" ) )
   if lPair
      aTok   = DsnColorTokParse( DsnColorPair( cCurrent )[ 1 ] )
      aTokBg = DsnColorTokParse( DsnColorPair( cCurrent )[ 2 ] )
   else
      aTok = DsnColorTokParse( cCurrent )
   endif
   if aTok != NIL
      nCur[ 1 ] = Max( 1, DsnColorGridIndex( DsnColorTokCompose( aTok ) ) )
   endif
   if lPair .and. aTokBg != NIL
      nCur[ 2 ] = Max( 1, Min( 8, DsnColorGridIndex( DsnColorTokCompose( aTokBg ) ) ) )
   endif
   if cKind == "bg"
      nCur[ 1 ] = Min( 8, nCur[ 1 ] )
   endif

   oDlg = HBWindow():Dialog( " " + cTitle + " ", 54, ;
      If( lPair, 12, If( cKind == "bg", 8, 9 ) ), CLR_DIALOG )
   nRow1    = oDlg:nTop + 2
   nRow2    = If( lPair, oDlg:nTop + 6, 0 )
   nPrevRow = If( lPair, oDlg:nTop + 9, If( cKind == "bg", oDlg:nTop + 4, oDlg:nTop + 5 ) )
   nHintRow = oDlg:nBottom - 1

   do while .T.
      DispBegin()
      if lPair
         oDlg:Say( nRow1 - oDlg:nTop - 1, 2, If( nSide == 1, "> ", "  " ) + "Foreground:" )
         oDlg:Say( nRow2 - oDlg:nTop - 1, 2, If( nSide == 2, "> ", "  " ) + "Background:" )
      else
         oDlg:Say( nRow1 - oDlg:nTop - 1, 2, "> Color:" )
      endif
      for nSide2 = 1 to If( lPair, 2, 1 )
         nLim = If( nSide2 == 1 .and. cKind != "bg", 16, 8 )
         for n = 1 to nLim
            nRow = If( nSide2 == 1, nRow1, nRow2 ) + Int( ( n - 1 ) / 8 )
            nCol = oDlg:nLeft + 3 + ( n - 1 ) % 8 * 6
            cTok = aGrid[ n ]
            cCellClr = If( AScan( cLight, cTok ) > 0, "N", "W+" ) + "/" + cTok
            if n == nCur[ nSide2 ]
               hb_DispOutAt( nRow, nCol, "[" + PadR( cTok, 3 ) + "]", cCellClr )
            else
               hb_DispOutAt( nRow, nCol, " " + PadR( cTok, 3 ) + " ", cCellClr )
            endif
         next
      next
      // honest preview on a black plate: the pick applied the way the
      // property uses it, readable even when it matches the window color
      do case
         case cKind == "fg"
            cPreview = aGrid[ nCur[ 1 ] ] + "/" + cCtx
         case cKind == "bg"
            cPreview = cCtx + "/" + aGrid[ nCur[ 1 ] ]
         otherwise
            cPreview = aGrid[ nCur[ 1 ] ] + "/" + aGrid[ nCur[ 2 ] ]
      endcase
      hb_DispOutAt( nPrevRow, oDlg:nLeft + 2, "Preview:", "N/W" )
      hb_DispOutAt( nPrevRow, oDlg:nLeft + 11, "                ", "N/N" )
      hb_DispOutAt( nPrevRow, oDlg:nLeft + 13, " Sample text ", cPreview )
      hb_DispOutAt( nPrevRow, oDlg:nLeft + 29, PadR( cPreview, 12 ), "N/W" )
      hb_DispOutAt( nHintRow, oDlg:nLeft + 2, ;
         If( lPair, "Arrows move   Tab fg/bg   Enter accept   Esc cancel", ;
                    "Arrows move   Enter accept   Esc cancel" ), "N/W" )
      DispEnd()

      nKey = DsnNormKey( InKey( 0, INKEY_ALL + HB_INKEY_EXT ) )
      nLim = If( nSide == 1 .and. cKind != "bg", 16, 8 )
      do case
         case nKey == K_ESC
            exit
         case nKey == K_ENTER
            if lPair .and. nSide == 1
               nSide = 2
            else
               // grid pick + blink preserved from the original value
               cNew = aGrid[ nCur[ 1 ] ] + If( aTok != NIL .and. aTok[ 3 ], "*", "" )
               if lPair
                  cNew += "/" + aGrid[ nCur[ 2 ] ] + If( aTokBg != NIL .and. aTokBg[ 3 ], "*", "" )
               endif
               exit
            endif
         case nKey == K_LEFT
            nCur[ nSide ] = 1 + Mod( nCur[ nSide ] - 2 + nLim, nLim )
         case nKey == K_RIGHT
            nCur[ nSide ] = 1 + Mod( nCur[ nSide ], nLim )
         case nKey == K_UP
            if nLim == 16
               nCur[ nSide ] -= 8
               if nCur[ nSide ] < 1
                  nCur[ nSide ] += 16
               endif
            endif
         case nKey == K_DOWN
            if nLim == 16
               nCur[ nSide ] += 8
               if nCur[ nSide ] > 16
                  nCur[ nSide ] -= 16
               endif
            endif
         case nKey == K_TAB
            if lPair
               nSide = 3 - nSide
            endif
      endcase
   enddo
   oDlg:Hide()

return cNew

//-----------------------------------------------------------------------------------------//

// first fg/bg pair of a color string: { cFg, cBg }; cBg is the bare
// uppercase letter (modifiers stripped). Defaults to the white dialog.
// ASSIGN target of the virtual cDlgColor: splitting a combined colorspec
// only touches the text/background properties; focus keeps its own value
function DsnAssignDlgColor( oDsn, cColor )

   local aPair := DsnDlgPair( cColor )

   oDsn:cDlgClrText = aPair[ 1 ]
   oDsn:cDlgClrBack = aPair[ 2 ]

return oDsn:cDlgColor

//-----------------------------------------------------------------------------------------//

function DsnDlgPair( cColor )

   local cFirst := AllTrim( hb_defaultValue( cColor, "" ) )
   local nAt, cFg, cBg

   if Empty( cFirst )
      cFirst = CLR_DIALOG
   endif
   nAt = At( ",", cFirst )
   if nAt > 0
      cFirst = AllTrim( Left( cFirst, nAt - 1 ) )
   endif
   nAt = At( "/", cFirst )
   if nAt > 0
      cFg = AllTrim( Left( cFirst, nAt - 1 ) )
      cBg = AllTrim( SubStr( cFirst, nAt + 1 ) )
   else
      cFg = cFirst
      cBg = "N"
   endif
   cBg = Upper( StrTran( StrTran( cBg, "+", "" ), "*", "" ) )
   if Empty( cBg )
      cBg = "N"
   endif
   if Empty( cFg )
      cFg = "W+"
   endif

return { cFg, cBg }

//-----------------------------------------------------------------------------------------//
// runtime palettes derived from the dialog color. The default white
// dialog keeps hbide's own palettes byte-exact (regression); any other
// dialog background gets a readable scheme painted on that background.

// replace the given comma-pair slots of a colorspec with the focus pair
static function DsnClrSetPairs( cSpec, cFocus, aSlots )

   local aItems := hb_aTokens( cSpec, "," )
   local n, cOut := ""

   for each n in aSlots
      if n <= Len( aItems )
         aItems[ n ] = cFocus
      endif
   next
   for each n in aItems
      cOut += If( n:__enumIndex() > 1, ",", "" ) + n
   next

return cOut

//-----------------------------------------------------------------------------------------//

function DsnClrGetFor( cDlgColor, cClrFocus )

   hb_default( @cClrFocus, DSN_CLR_FOCUS )

   if DsnDlgPair( cDlgColor )[ 2 ] == "W"
      if cClrFocus == DSN_CLR_FOCUS
         return DSN_CLR_GET
      endif
      return DsnClrSetPairs( DSN_CLR_GET, cClrFocus, { 2 } )
   endif
   if cClrFocus == DSN_CLR_FOCUS
      return "N/W,B/W,N/W,GR+/W"
   endif

return "N/W," + cClrFocus + ",N/W,GR+/W"

function DsnClrCheckBoxFor( cDlgColor, cClrFocus )

   local aPair := DsnDlgPair( cDlgColor )
   local cText := aPair[ 1 ] + "/" + aPair[ 2 ]

   hb_default( @cClrFocus, DSN_CLR_FOCUS )

   if aPair[ 2 ] == "W"
      if cClrFocus == DSN_CLR_FOCUS
         return DSN_CLR_CHECKBOX
      endif
      return DsnClrSetPairs( DSN_CLR_CHECKBOX, cClrFocus, { 2 } )
   endif
   if cClrFocus == DSN_CLR_FOCUS
      return cText + ",Y+/" + aPair[ 2 ] + "," + cText + ",GR+/" + aPair[ 2 ]
   endif

return cText + "," + cClrFocus + "," + cText + ",GR+/" + aPair[ 2 ]

function DsnClrButtonFor( cDlgColor, cClrFocus )

   hb_default( @cClrFocus, DSN_CLR_FOCUS )

   if DsnDlgPair( cDlgColor )[ 2 ] == "W"
      if cClrFocus == DSN_CLR_FOCUS
         return DSN_CLR_BUTTON
      endif
      return DsnClrSetPairs( DSN_CLR_BUTTON, cClrFocus, { 2 } )
   endif
   if cClrFocus == DSN_CLR_FOCUS
      return "N/W,W+/N,N/W,R/W"
   endif

return "N/W," + cClrFocus + ",N/W,R/W"

function DsnClrRadioFor( cDlgColor, cClrFocus )

   local aPair := DsnDlgPair( cDlgColor )
   local cText := aPair[ 1 ] + "/" + aPair[ 2 ]

   hb_default( @cClrFocus, DSN_CLR_FOCUS )

   if aPair[ 2 ] == "W"
      if cClrFocus == DSN_CLR_FOCUS
         return DSN_CLR_RADIO
      endif
      return DsnClrSetPairs( DSN_CLR_RADIO, cClrFocus, { 4, 7 } )
   endif
   if cClrFocus == DSN_CLR_FOCUS
      return cText + "," + cText + "," + cText + ",Y+/" + aPair[ 2 ] + "," + ;
             cText + ",GR+/" + aPair[ 2 ] + ",Y+/" + aPair[ 2 ]
   endif

return cText + "," + cText + "," + cText + "," + cClrFocus + "," + ;
       cText + ",GR+/" + aPair[ 2 ] + "," + cClrFocus

function DsnClrListBoxFor( cDlgColor, cClrFocus )

   hb_default( @cClrFocus, DSN_CLR_FOCUS )

   if DsnDlgPair( cDlgColor )[ 2 ] == "W"
      if cClrFocus == DSN_CLR_FOCUS
         return DSN_CLR_LISTBOX
      endif
      return DsnClrSetPairs( DSN_CLR_LISTBOX, cClrFocus, { 2 } )
   endif
   if cClrFocus == DSN_CLR_FOCUS
      return "N/W,W+/N,N/W,W+/G,N/W,W+/W,GR+/W"
   endif

return "N/W," + cClrFocus + ",N/W,W+/G,N/W,W+/W,GR+/W"

//-----------------------------------------------------------------------------------------//
// canvas button shadow for a dialog color: the stock white dialog keeps
// the original "N/W"; any other background gets the runtime look, a
// half-block shadow on the dialog background.

function DsnCanvasShadowFor( cDlgColor )

   local aPair := DsnDlgPair( cDlgColor )

   if aPair[ 2 ] == "W"
      return "N/W"
   endif

return "N/" + aPair[ 2 ]

//-----------------------------------------------------------------------------------------//
// top-left that keeps a nWidth x nHeight window and its shadow fully on a
// (0..nMaxCol, 0..nMaxRow) screen: shift left/up only when it overflows.
// Pure function so the fit rules are testable without a window.

// window size for a dialog on a given screen: never larger than the
// screen (with margin for the frame and shadow); the dialog model may
// be bigger, and then the window acts as a viewport onto it

function DsnViewSize( nDlgWidth, nDlgHeight, nMaxCol, nMaxRow )

return { Min( nDlgWidth, nMaxCol - 4 ), Min( nDlgHeight, nMaxRow - 3 ) }

//-----------------------------------------------------------------------------------------//
// Shared verified sibling write; never truncate the existing JSON/PRG in place.
// Full error detail is returned, including retained complete content if any.

function DsnSafeMemoWrit( cFile, cText, cFailInfo )

return HBIDE_AtomicWriteFile( cFile, cText, @cFailInfo )

//-----------------------------------------------------------------------------------------//
// clamp a pan origin so the window never scrolls past the dialog edges

#define DSN_HIST_MAX   100   // undo history depth

//-----------------------------------------------------------------------------------------//
// deep copy of a model value: hashes and arrays are cloned recursively
// so a snapshot never shares structure with the live model

function DsnCloneValue( u )

   local uClone, xKey

   do case
      case ValType( u ) == "H"
         uClone := { => }
         for each xKey in hb_HKeys( u )
            uClone[ xKey ] := DsnCloneValue( u[ xKey ] )
         next
      case ValType( u ) == "A"
         uClone := {}
         for each xKey in u
            AAdd( uClone, DsnCloneValue( xKey ) )
         next
      otherwise
         uClone := u
   endcase

return uClone

//-----------------------------------------------------------------------------------------//
// the whole designer model as a detached copy (undo/redo history entry)

function DsnSnapshot( oDsn )

return { "controls" => DsnCloneValue( oDsn:aControls ), ;
         "selected" => oDsn:nSelected, ;
         "name"     => oDsn:cDlgName, ;
         "caption"  => oDsn:cDlgCaption, ;
         "color"    => oDsn:cDlgColor, ;
         "colortext"  => oDsn:cDlgClrText, ;
         "colorback"  => oDsn:cDlgClrBack, ;
         "colorfocus" => oDsn:cDlgClrFocus, ;
         "width"    => oDsn:nDlgWidth, ;
         "height"   => oDsn:nDlgHeight }

//-----------------------------------------------------------------------------------------//
// model snapshots hold plain data only, so JSON is a deterministic compare

function DsnSnapEqual( hA, hB )

return hb_jsonEncode( hA ) == hb_jsonEncode( hB )

//-----------------------------------------------------------------------------------------//
// push a pre-action snapshot on the undo stack; a new action clears redo

procedure DsnHistPush( aUndo, aRedo, hSnap )

   AAdd( aUndo, hSnap )
   do while Len( aUndo ) > DSN_HIST_MAX
      hb_ADel( aUndo, 1, .T. )
   enddo
   ASize( aRedo, 0 )

return

//-----------------------------------------------------------------------------------------//
// pop the newest undo snapshot; the current state goes on the redo stack.
// Returns nil when there is nothing to undo.

function DsnHistUndo( aUndo, aRedo, hCurrent )

   local hSnap

   if Empty( aUndo )
      return nil
   endif
   hSnap = aUndo[ Len( aUndo ) ]
   ASize( aUndo, Len( aUndo ) - 1 )
   AAdd( aRedo, hCurrent )

return hSnap

//-----------------------------------------------------------------------------------------//
// pop the newest redo snapshot; the current state goes on the undo stack.
// Returns nil when there is nothing to redo.

function DsnHistRedo( aRedo, aUndo, hCurrent )

   local hSnap

   if Empty( aRedo )
      return nil
   endif
   hSnap = aRedo[ Len( aRedo ) ]
   ASize( aRedo, Len( aRedo ) - 1 )
   AAdd( aUndo, hCurrent )

return hSnap

//-----------------------------------------------------------------------------------------//

function DsnSnapTo( n, nStep )

return Int( Round( n / nStep, 0 ) ) * nStep

//-----------------------------------------------------------------------------------------//

function DsnPanClamp( nOff, nModel, nView )

return Max( 0, Min( nOff, Max( 0, nModel - nView ) ) )

//-----------------------------------------------------------------------------------------//

function DsnFitRect( nLeft, nTop, nWidth, nHeight, nMaxCol, nMaxRow )

return { Max( 0, Min( nLeft, nMaxCol - nWidth - 1 ) ), ;
         Max( 0, Min( nTop,  nMaxRow - nHeight - 1 ) ) }

//-----------------------------------------------------------------------------------------//
// text of the DsnBtnDisplay() function emitted into generated dialogs on a
// colored background: the same 3D pushbutton display hbbutton registers
// (BtnDisplay, frozen), with the hardcoded "N/W" shadow repainted as
// "N/<bg>" so the shadow reads dark on the dialog background.

static function DsnFillAreaCode()

   local cCode := ""

   cCode += "// fills a dialog rect with a flat color: the celeste area behind" + hb_eol()
   cCode += "// a radiogroup, whose stock display only paints caption cells" + hb_eol()
   cCode += "function DsnFillArea( oDlg, nTop, nLeft, nBottom, nRight, cColor )" + hb_eol()
   cCode += hb_eol()
   cCode += "   local nRow" + hb_eol()
   cCode += hb_eol()
   cCode += "   (oDlg)" + hb_eol()
   cCode += "   for nRow = nTop to nBottom" + hb_eol()
   cCode += "      hb_DispOutAt( nRow, nLeft, Space( nRight - nLeft + 1 ), cColor )" + hb_eol()
   cCode += "   next" + hb_eol()
   cCode += hb_eol()
   cCode += "return nil" + hb_eol()

return cCode

//-----------------------------------------------------------------------------------------//

static function DsnBtnDisplayCode( cBg )

   local cCode := ""
   local cShadow := "N/" + cBg

   cCode += "// pushbutton display override: same look as hbbutton's BtnDisplay" + hb_eol()
   cCode += "// (3D shadow by default, bracket look on a two-char STYLE)," + hb_eol()
   cCode += "// with the shadow painted on the dialog background" + hb_eol()
   cCode += "function DsnBtnDisplay()" + hb_eol()
   cCode += hb_eol()
   cCode += "   local Self := QSelf()" + hb_eol()
   cCode += hb_eol()
   cCode += "   local cColor" + hb_eol()
   cCode += "   local aPads := DsnBtnPads()" + hb_eol()
   cCode += "   local cCaption := ::cCaption" + hb_eol()
   cCode += "   local nRow := ::nRow" + hb_eol()
   cCode += "   local nCol := ::nCol" + hb_eol()
   cCode += "   local nPos" + hb_eol()
   cCode += hb_eol()
   cCode += "   DispBegin()" + hb_eol()
   cCode += hb_eol()
   cCode += "   do case" + hb_eol()
   cCode += "   case ::lBuffer" + hb_eol()
   cCode += '      cColor := hb_ColorIndex( ::cColorSpec, 2 )' + hb_eol()
   cCode += "   case ::lHasFocus" + hb_eol()
   cCode += '      cColor := hb_ColorIndex( ::cColorSpec, 1 )' + hb_eol()
   cCode += "   otherwise" + hb_eol()
   cCode += '      cColor := hb_ColorIndex( ::cColorSpec, 0 )' + hb_eol()
   cCode += "   endcase" + hb_eol()
   cCode += hb_eol()
   cCode += '   if ( nPos := hb_UAt( "&", cCaption ) ) == 0' + hb_eol()
   cCode += "   elseif nPos == hb_ULen( cCaption )" + hb_eol()
   cCode += "      nPos := 0" + hb_eol()
   cCode += "   else" + hb_eol()
   cCode += '      cCaption := hb_ULeft( cCaption, nPos - 1 ) + hb_USubStr( cCaption, nPos + 1 )' + hb_eol()
   cCode += "   endif" + hb_eol()
   cCode += hb_eol()
   cCode += '   if Len( ::cStyle ) == 2 .and. ::cStyle != "<>"' + hb_eol()
   cCode += hb_eol()
   cCode += '      // bracket look (STYLE "[]" etc.): one row, no shadow' + hb_eol()
   cCode += "      hb_DispOutAt( ::nRow, ::nCol, ;" + hb_eol()
   cCode += '         hb_ULeft( ::cStyle, 1 ) + " " + cCaption + " " + hb_USubStr( ::cStyle, 2, 1 ), cColor )' + hb_eol()
   cCode += "      if nPos != 0" + hb_eol()
   cCode += "         hb_DispOutAt( ::nRow, ::nCol + nPos + 1, ;" + hb_eol()
   cCode += "            hb_USubStr( cCaption, nPos, 1 ), hb_ColorIndex( ::cColorSpec, 3 ) )" + hb_eol()
   cCode += "      endif" + hb_eol()
   cCode += hb_eol()
   cCode += "      DispEnd()" + hb_eol()
   cCode += hb_eol()
   cCode += "      return Self" + hb_eol()
   cCode += "   endif" + hb_eol()
   cCode += hb_eol()
   cCode += "   if ! Empty( aPads )" + hb_eol()
   cCode += hb_eol()
   cCode += "      nCol++" + hb_eol()
   cCode += hb_eol()
   cCode += "      if ::lBuffer" + hb_eol()
   cCode += '         hb_DispOutAt( ::nRow, ::nCol, "  ", "' + cShadow + '" )' + hb_eol()
   cCode += "      endif" + hb_eol()
   cCode += '      hb_DispOutAt( ::nRow, ::nCol + 1 + If( ::lBuffer, 1, 0 ), aPads[ 1 ], cColor )' + hb_eol()
   cCode += '      hb_DispOutAt( ::nRow, ::nCol + hb_ULen( cCaption ) + 2 + If( ::lBuffer, 1, 0 ), aPads[ 2 ], cColor )' + hb_eol()
   cCode += "   endif" + hb_eol()
   cCode += hb_eol()
   cCode += "   if ! Empty( cCaption )" + hb_eol()
   cCode += hb_eol()
   cCode += '      hb_DispOutAt( nRow, nCol + 1 + If( ::lBuffer, 1, 0 ), cCaption, cColor )' + hb_eol()
   cCode += hb_eol()
   cCode += "      if nPos != 0" + hb_eol()
   cCode += '         hb_DispOutAt( nRow, nCol + nPos + If( ::lBuffer, 1, 0 ),;' + hb_eol()
   cCode += '                       hb_USubStr( cCaption, nPos, 1 ), hb_ColorIndex( ::cColorSpec, 3 ) )' + hb_eol()
   cCode += "      endif" + hb_eol()
   cCode += "   endif" + hb_eol()
   cCode += hb_eol()
   cCode += '   // clear the stripe row so state switches leave no stray cells' + hb_eol()
   cCode += '   hb_DispOutAt( ::nRow + 1, ::nCol + 1, Replicate( " ", hb_ULen( cCaption ) + 4 ), "' + cShadow + '" )' + hb_eol()
   cCode += "   if DsnBtnShadowUtf8()" + hb_eol()
   cCode += "      // Turbo Vision half-cell shadow: half blocks on the dialog" + hb_eol()
   cCode += "      // background (right cell lower half, stripe below upper half)" + hb_eol()
   cCode += '      hb_DispOutAt( nRow, ::nCol + hb_ULen( cCaption ) + 3 + If( ::lBuffer, 1, 0 ),;' + hb_eol()
   cCode += '                    hb_UTF8ToStr( "▄" ), "' + cShadow + '" )' + hb_eol()
   cCode += '      hb_DispOutAt( ::nRow + 1, ::nCol + 2 + If( ::lBuffer, 1, 0 ),;' + hb_eol()
   cCode += '                    Replicate( hb_UTF8ToStr( "▀" ), hb_ULen( cCaption ) + 2 ), "' + cShadow + '" )' + hb_eol()
   cCode += "   else" + hb_eol()
   cCode += "      // codepage-safe fallback: solid dark cells (no ACSC mapping" + hb_eol()
   cCode += "      // for the half blocks on non-UTF8 terminals)" + hb_eol()
   cCode += '      hb_DispOutAt( nRow, ::nCol + hb_ULen( cCaption ) + 3 + If( ::lBuffer, 1, 0 ),;' + hb_eol()
   cCode += '                    " ", "N/N" )' + hb_eol()
   cCode += '      hb_DispOutAt( ::nRow + 1, ::nCol + 2 + If( ::lBuffer, 1, 0 ),;' + hb_eol()
   cCode += '                    Replicate( " ", hb_ULen( cCaption ) + 2 ), "N/N" )' + hb_eol()
   cCode += "   endif" + hb_eol()
   cCode += hb_eol()
   cCode += "   DispEnd()" + hb_eol()
   cCode += hb_eol()
   cCode += "return Self" + hb_eol()
   cCode += hb_eol()
   cCode += "function DsnBtnPads()" + hb_eol()
   cCode += hb_eol()
   cCode += 'return { " ", " " }' + hb_eol()
   cCode += hb_eol()
   cCode += "// .T. when the terminal renders the half-block shadow glyphs" + hb_eol()
   cCode += "// (Windows GTs natively; POSIX only in a UTF-8 locale)" + hb_eol()
   cCode += "function DsnBtnShadowUtf8()" + hb_eol()
   cCode += hb_eol()
   cCode += '   local cLoc := "", cName' + hb_eol()
   cCode += hb_eol()
   cCode += '   if "WINDOWS" $ Upper( OS() )' + hb_eol()
   cCode += "      return .T." + hb_eol()
   cCode += "   endif" + hb_eol()
   cCode += '   for each cName in { "LC_ALL", "LC_CTYPE", "LANG" }' + hb_eol()
   cCode += "      cLoc := GetEnv( cName )" + hb_eol()
   cCode += "      if ! Empty( cLoc )" + hb_eol()
   cCode += "         exit" + hb_eol()
   cCode += "      endif" + hb_eol()
   cCode += "   next" + hb_eol()
   cCode += "   cLoc := Upper( cLoc )" + hb_eol()
   cCode += hb_eol()
   cCode += 'return "UTF-8" $ cLoc .or. "UTF8" $ cLoc' + hb_eol()
   cCode += hb_eol()
   cCode += "// pushbutton hit test override: same extent as hbbutton's BtnHitTest," + hb_eol()
   cCode += "// covering the full painted width of the bracket look" + hb_eol()
   cCode += "function DsnBtnHitTest( nMRow, nMCol )" + hb_eol()
   cCode += hb_eol()
   cCode += "   local Self := QSelf()" + hb_eol()
   cCode += "   local nLen := hb_ULen( ::cCaption )" + hb_eol()
   cCode += "   local nAccelPos" + hb_eol()
   cCode += hb_eol()
   cCode += '   if ( nAccelPos := hb_UAt( "&", ::cCaption ) ) > 0 .and. nAccelPos < nLen' + hb_eol()
   cCode += "      nLen--" + hb_eol()
   cCode += "   endif" + hb_eol()
   cCode += '   if Len( ::cStyle ) == 2 .and. ::cStyle != "<>"' + hb_eol()
   cCode += '      nLen += 4   // "[ " + caption + " ]"' + hb_eol()
   cCode += "   else" + hb_eol()
   cCode += "      nLen += 2   // stock extent: pads around the caption" + hb_eol()
   cCode += "   endif" + hb_eol()
   cCode += hb_eol()
   cCode += "   if nMRow >= ::Row .and. nMCol >= ::Col .and. ;" + hb_eol()
   cCode += "      nMRow < ::Row + 1 .and. nMCol < ::Col + nLen" + hb_eol()
   cCode += "      return -2049   // HTCLIENT" + hb_eol()
   cCode += "   endif" + hb_eol()
   cCode += hb_eol()
   cCode += "return 0   // HTNOWHERE" + hb_eol()

return cCode

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

//-----------------------------------------------------------------------------------------//

// Layered Escape target: placement cancel first, then the inspector
// panel, then the dirty-model confirmation, then exit. Pure helper so
// the layering is covered by the test suite.

function DsnEscTarget( lPlacing, lInspector, lDirty, lCodeView )

   hb_default( @lCodeView, .F. )

   if lPlacing
      return "placing"
   endif
   if lInspector
      return "inspector"
   endif
   if lCodeView
      return "codeview"
   endif
   if lDirty
      return "dirty"
   endif

return "exit"

//-----------------------------------------------------------------------------------------//
// 1-based line in the generated code that corresponds to a control: the GET
// line of its variable, else the line carrying its caption. 0 when neither
// shows up (or no control is selected)

function DsnCodeFindLine( aLines, oCtrl )

   local cVar, cCaption, n

   if oCtrl == NIL
      return 0
   endif
   cVar     = hb_HGetDef( oCtrl, "variable", "" )
   cCaption = hb_HGetDef( oCtrl, "caption", "" )
   if ! Empty( cVar )
      for n = 1 to Len( aLines )
         if " GET " + cVar + " " $ aLines[ n ]
            return n
         endif
      next
   endif
   if ! Empty( cCaption )
      for n = 1 to Len( aLines )
         if '"' + cCaption + '"' $ aLines[ n ]
            return n
         endif
      next
   endif

return 0

//-----------------------------------------------------------------------------------------//
// first visible line of the live PRG view: the anchor line near the top,
// clamped so the view stays inside the generated code

function DsnCodeViewTop( nAnchor, nLines, nViewH )

return Max( 1, Min( If( nAnchor > 0, nAnchor - 3, 1 ), Max( 1, nLines - nViewH + 1 ) ) )

//-----------------------------------------------------------------------------------------//
// Clickable Alert() replacement for designer confirmations: same contract
// (returns the 1-based option index, 0 on Esc) over a HbWindow with real
// pushbuttons, so the prompt answers to keyboard (Tab/arrows, Enter, Space,
// Esc) and to the mouse through the window click path. Focus starts on the
// first option, like Alert().

// Bounded scrollable error: recovery paths must never disappear off a status line.
function DsnWriteError( cText )

   local nWidth := Min( 76, MaxCol() - 4 )
   local nHeight := Min( 12, MaxRow() - 4 )
   local nCols := nWidth - 6, nRows := nHeight - 5
   local aLines := {}, nTop := 1, nKey, i
   local oDlg := HBWindow():Dialog( "Write failed", nWidth, nHeight, "W+/B" )

   do while ! Empty( cText )
      AAdd( aLines, Left( cText, nCols ) )
      cText := SubStr( cText, nCols + 1 )
   enddo
   oDlg:Show( .F. )
   do while .T.
      for i := 1 to nRows
         oDlg:Say( i + 1, 3, PadR( If( nTop + i - 1 <= Len( aLines ), ;
            aLines[ Min( Len( aLines ), nTop + i - 1 ) ], "" ), nCols ) )
      next
      oDlg:Say( nHeight - 2, 3, "Up/Down scroll   Enter/Esc close" )
      nKey := DsnNormKey( Inkey( 0, INKEY_ALL + HB_INKEY_EXT ) )
      do case
      case nKey == K_ENTER .or. nKey == K_ESC
         exit
      case nKey == K_DOWN .or. nKey == K_PGDN
         nTop := Min( Max( 1, Len( aLines ) - nRows + 1 ), nTop + 1 )
      case nKey == K_UP .or. nKey == K_PGUP
         nTop := Max( 1, nTop - 1 )
      endcase
   enddo
   oDlg:Hide()

return nil

function DsnConfirm( cText, aOptions )

   local aLay   := DsnConfirmLayout( cText, aOptions, MaxCol() )
   local oDlg   := HBWindow():Dialog( "", aLay[ 1 ], aLay[ 2 ], "W+/B" )
   local aRes   := { 0 }
   local lDummy, i, GetList := {}

   oDlg:SayCenter( cText, -1 )
   for i := 1 to Len( aOptions )
      @ oDlg:nTop + aLay[ 3 ], oDlg:nLeft + aLay[ 4 ][ i ] GET lDummy PUSHBUTTON ;
         CAPTION aOptions[ i ] COLOR 'N/W,W+/N,N/W,R/W'
      // STATE <sb> wraps its argument in a codeblock, so a block-returning
      // factory would be double-wrapped and never run; assign sBlock instead.
      ATail( GetList ):Control:sBlock := DsnConfirmState( oDlg, i, aRes )
   next
   oDlg:Activate( GetList )

return aRes[ 1 ]

// DsnConfirm geometry, pure so the suite can pin it: width fits the text and
// the button row (12 cols per button) with margins and never leaves the
// screen; buttons are centered on row 4 of a 8-row dialog.
function DsnConfirmLayout( cText, aOptions, nMaxCol )

   local nWidth := Min( nMaxCol - 4, Max( Len( cText ) + 8, Len( aOptions ) * 12 + 4 ) )
   local nFirst := Int( ( nWidth - ( Len( aOptions ) * 12 - 2 ) ) / 2 )
   local aCols  := {}
   local i

   for i := 1 to Len( aOptions )
      AAdd( aCols, nFirst + ( i - 1 ) * 12 )
   next

return { nWidth, 8, 4, aCols }

// one codeblock per button with the index captured by value (a closure over
// the loop variable would fire the LAST index for every button)
static function DsnConfirmState( oDlg, nIdx, aRes )
return { || aRes[ 1 ] := nIdx, oDlg:End() }

//-----------------------------------------------------------------------------------------//
// debug trace for mouse/drag diagnosis; active only with DSN_TRACE set

// DsnTrace: optional designer input diagnostics, disabled by default.
// Set env DSN_TRACE=1 to append timestamped lines to /tmp/dsn_trace.log.
// Logs coordinates, control indices and geometry only; never captions,
// control names or other model content.
function DsnTrace( cMsg )

   local h

   if Empty( hb_GetEnv( "DSN_TRACE" ) )
      return nil
   endif
   if ( h := FOpen( "/tmp/dsn_trace.log", 2 ) ) != -1
      FSeek( h, 0, 2 )
   else
      h := FCreate( "/tmp/dsn_trace.log" )
   endif
   if h != -1
      FWrite( h, hb_TToS( hb_DateTime() ) + " " + cMsg + hb_eol() )
      FClose( h )
   endif

return nil

//
// test_designer.prg - non-interactive checks for the designer core functions
// Run: hbmk2 test_designer.prg ../designer.prg ../hbwindow.prg ../hbmenu.prg ../hbbutton.prg -gttrm
//

#include "hbclass.ch"

static s_nPassed := 0, s_nFailed := 0

procedure Main()

   local hModel, cCode, cJson, hBack, aSize
   local oD, oD2, aRect, nMaxRow, nMaxCol, oCtrl, cCellRef, cCellNow
   local oDlg, nCell, cBefore, cAfter, hS0, hS1, aU, aR, hT

   // DsnControlSize
   aSize = DsnControlSize( { "type" => "say", "caption" => "Name:" } )
   Check( "say width", aSize[ 1 ] == 5 .and. aSize[ 2 ] == 1 )
   aSize = DsnControlSize( { "type" => "get", "width" => 12 } )
   Check( "get width", aSize[ 1 ] == 12 )
   aSize = DsnControlSize( { "type" => "checkbox", "caption" => "Active" } )
   Check( "checkbox width", aSize[ 1 ] == 10 )
   aSize = DsnControlSize( { "type" => "button", "caption" => "&OK" } )
   Check( "button height 2", aSize[ 2 ] == 2 .and. aSize[ 1 ] == 6 )

   // DsnValidVar
   Check( "var keeps letters", DsnValidVar( "cName", "x" ) == "cName" )
   Check( "var strips spaces", DsnValidVar( "my var 1", "x" ) == "myvar1" )
   Check( "var rejects digit start", DsnValidVar( "1abc", "cVar1" ) == "cVar1" )
   Check( "var rejects empty", DsnValidVar( "", "cVar1" ) == "cVar1" )

   // model -> JSON -> model round trip
   hModel = { "name"     => "Customer", ;
              "caption"  => "Customer data", ;
              "width"    => 50, ;
              "height"   => 14, ;
              "color"    => "W+/W", ;
              "controls" => { ;
                 { "type" => "say",      "row" => 1, "col" => 2, "caption" => "Name:" }, ;
                 { "type" => "get",      "row" => 1, "col" => 9, "variable" => "cName", "width" => 20 }, ;
                 { "type" => "checkbox", "row" => 3, "col" => 2, "caption" => "Active", "variable" => "lActive" }, ;
                 { "type" => "button",   "row" => 5, "col" => 2, "caption" => "&OK" } } }

   cJson = hb_jsonEncode( hModel, .T. )
   Check( "json not empty", ! Empty( cJson ) )
   hb_MemoWrit( "customer.json", cJson )

   hBack = nil
   hb_jsonDecode( cJson, @hBack )
   Check( "json decode hash", HB_IsHash( hBack ) )
   Check( "json name", hBack[ "name" ] == "Customer" )
   Check( "json controls count", Len( hBack[ "controls" ] ) == 4 )
   Check( "json get variable", hBack[ "controls" ][ 2 ][ "variable" ] == "cName" )
   Check( "json get width numeric", hBack[ "controls" ][ 2 ][ "width" ] == 20 )

   // code generation
   cCode = DsnGenCode( hBack )
   hb_MemoWrit( "customer.prg", cCode )
   Check( "gen has function", "function Dlg_Customer()" $ cCode )
   Check( "gen has dialog", 'HBWindow():Dialog( "Customer data", 50, 14, "W+/W" )' $ cCode )
   Check( "gen has say", 'oDlg:Say( 2, 3, "Name:" )' $ cCode )
   Check( "gen has get", "@ oDlg:nTop + 2, oDlg:nLeft + 10 GET cName" $ cCode )
   Check( "gen has checkbox", "GET lActive CHECKBOX CAPTION" $ cCode )
   Check( "gen declares var", "local cName := Space( 20 )" $ cCode )
   Check( "gen declares lvar", "local lActive := .F." $ cCode )

   // object inspector (model level, no UI)
   oD = HbDesigner():New( nil )
   oD:oWnd = HBWindow():Dialog( "Test", 40, 12, "W+/W" )
   AAdd( oD:aControls, { "type" => "get",    "row" => 1, "col" => 9, "variable" => "cName", "width" => 20 } )
   AAdd( oD:aControls, { "type" => "button", "row" => 5, "col" => 2, "caption"  => "&OK" } )

   // field lists follow the selection
   oD:nSelected = 0
   Check( "insp fields dialog", Len( oD:InspFields() ) == 4 )
   oD:nSelected = 1
   Check( "insp fields get", Len( oD:InspFields() ) == 4 )
   Check( "insp value variable", oD:InspValue( "variable" ) == "cName" )
   oD:nSelected = 2
   Check( "insp fields button", Len( oD:InspFields() ) == 5 )

   // live numeric adjust with clamps
   oD:nSelected = 1
   oD:nInspField = 1   // Row
   oD:InspAdjust( 1 )
   Check( "insp adjust row", oD:aControls[ 1 ][ "row" ] == 2 )
   oD:InspAdjust( -10 )
   Check( "insp adjust clamps zero", oD:aControls[ 1 ][ "row" ] == 0 )
   oD:InspAdjust( 100 )
   nMaxRow = oD:oWnd:nBottom - oD:oWnd:nTop - 2
   Check( "insp adjust clamps canvas", oD:aControls[ 1 ][ "row" ] == nMaxRow )
   oD:nInspField = 4   // Width
   oD:InspAdjust( 100 )
   Check( "insp width max 40", oD:aControls[ 1 ][ "width" ] == 40 )
   oD:InspAdjust( -100 )
   Check( "insp width min 4", oD:aControls[ 1 ][ "width" ] == 4 )

   // move/drop clamps match EditProperties: last usable origin is
   // nDlgHeight-2-aSize (borders take rows/cols 0 and n-1, row 0 maps to 1)
   oD:nSelected = 1   // the get: height 1, width already adjusted to 4 above
   oD:MoveSelected( 100, 100 )
   Check( "move clamps row", oD:aControls[ 1 ][ "row" ] == 12 - 2 - 1 )
   Check( "move clamps col", oD:aControls[ 1 ][ "col" ] == 40 - 2 - 4 )
   oD:MoveSelected( -100, -100 )
   Check( "move clamps zero", oD:aControls[ 1 ][ "row" ] == 0 .and. ;
          oD:aControls[ 1 ][ "col" ] == 0 )

   oD:nGhostRow = 100
   oD:nGhostCol = 100
   oD:AddControl( "listbox" )
   Check( "drop clamps listbox row", oD:aControls[ Len( oD:aControls ) ][ "row" ] == 12 - 2 - 6 )
   Check( "drop clamps listbox col", oD:aControls[ Len( oD:aControls ) ][ "col" ] == 40 - 2 - 20 )
   hb_ADel( oD:aControls, Len( oD:aControls ), .T. )

   // text edits: trim, sanitize, live dialog caption
   oD:nSelected = 2
   oD:InspSetText( "caption", "  Save  " )
   Check( "insp caption trimmed", oD:aControls[ 2 ][ "caption" ] == "Save" )
   oD:nSelected = 1
   oD:InspSetText( "variable", " 1bad var " )
   Check( "insp variable sanitized", oD:aControls[ 1 ][ "variable" ] == "cVar1" )
   oD:nSelected = 0
   oD:InspSetText( "dlgcaption", "Nuevo" )
   Check( "insp dlg caption live", oD:cDlgCaption == "Nuevo" .and. oD:oWnd:cCaption == " Nuevo " )
   oD:nInspField = 3   // dialog Width
   oD:InspAdjust( 5 )
   Check( "insp dlg width live", oD:nDlgWidth == 45 .and. ;
      oD:oWnd:nRight == oD:oWnd:nLeft + 44 )

   // inspector fields per control type
   oD:aControls = {}
   AAdd( oD:aControls, { "type" => "say",      "row" => 1, "col" => 1, "caption"  => "Name" } )
   AAdd( oD:aControls, { "type" => "get",      "row" => 2, "col" => 1, "variable" => "cName", "width" => 10 } )
   AAdd( oD:aControls, { "type" => "checkbox", "row" => 3, "col" => 1, "caption"  => "Active", "variable" => "lOk" } )
   AAdd( oD:aControls, { "type" => "button",   "row" => 4, "col" => 1, "caption"  => "&OK" } )
   oD:nSelected = 1
   Check( "insp fields say",   Len( oD:InspFields() ) == 3 .and. oD:InspFields()[ 3 ][ 1 ] == "Caption" )
   oD:nSelected = 2
   Check( "insp fields get",   Len( oD:InspFields() ) == 4 .and. oD:InspFields()[ 3 ][ 1 ] == "Variable" .and. oD:InspFields()[ 4 ][ 1 ] == "Width" )
   oD:nSelected = 3
   Check( "insp fields check", Len( oD:InspFields() ) == 4 .and. oD:InspFields()[ 3 ][ 1 ] == "Caption" .and. oD:InspFields()[ 4 ][ 1 ] == "Variable" )
   oD:nSelected = 4
   Check( "insp fields btn",   Len( oD:InspFields() ) == 5 .and. oD:InspFields()[ 3 ][ 1 ] == "Caption" .and. ;
          oD:InspFields()[ 4 ][ 1 ] == "Accel" .and. oD:InspFields()[ 5 ][ 1 ] == "Action" )

   // button accelerator and action: model -> generated code
   oD:aControls[ 4 ][ "caption" ]     = "Guardar"
   oD:aControls[ 4 ][ "accelerator" ] = "G"
   oD:aControls[ 4 ][ "action" ]      = "MiAccion()"
   hModel = DsnBuildModel( oD )
   cCode  = DsnGenCode( hModel )
   Check( "gen button accel",  'CAPTION "&Guardar"' $ cCode )
   Check( "gen button action", "STATE { || MiAccion() }" $ cCode )
   Check( "gen accel in caption", DsnAccelCaption( "Guardar", "u" ) == "G&uardar" )
   Check( "gen accel appended",   DsnAccelCaption( "Apply", "Z" ) == "Apply (&Z)" )
   Check( "gen accel default",    DsnButtonAction( { "type" => "button" } ) == "lOk := .T., oDlg:End()" )

   // legacy caption with & normalizes into the accelerator property
   aSize = { { "type" => "button", "row" => 1, "col" => 1, "caption" => "&OK" } }
   DsnNormalizeControls( aSize )
   Check( "normalize legacy button", aSize[ 1 ][ "caption" ] == "OK" .and. aSize[ 1 ][ "accelerator" ] == "O" )

   // long texts are never truncated: model, JSON and generated code keep them whole
   oD:aControls[ 1 ][ "caption" ] = Replicate( "A", 70 )
   hModel = DsnBuildModel( oD )
   cJson  = hb_jsonEncode( hModel, .T. )
   hb_jsonDecode( cJson, @hBack )
   Check( "long caption json",  hBack[ "controls" ][ 1 ][ "caption" ] == Replicate( "A", 70 ) )
   Check( "long caption in prg", Replicate( "A", 70 ) $ DsnGenCode( hModel ) )

   // JSON round-trip preserves accelerator and action
   cJson = hb_jsonEncode( hModel, .T. )
   hb_jsonDecode( cJson, @hBack )
   Check( "json button accel",  hBack[ "controls" ][ 4 ][ "accelerator" ] == "G" )
   Check( "json button action", hBack[ "controls" ][ 4 ][ "action" ] == "MiAccion()" )

   // dialog size guard: shrinking never hides controls (fresh known model)
   oD:aControls = {}
   AAdd( oD:aControls, { "type" => "get",    "row" => 1, "col" => 9, "variable" => "cName", "width" => 20 } )
   AAdd( oD:aControls, { "type" => "button", "row" => 5, "col" => 2, "caption"  => "&OK" } )
   oD:nSelected = 0
   Check( "min size with controls", oD:DlgMinSize()[ 1 ] == 31 .and. oD:DlgMinSize()[ 2 ] == 9 )
   oD:nInspField = 3   // dialog Width
   oD:InspAdjust( -100 )
   Check( "shrink keeps controls", oD:nDlgWidth == 31 )
   Check( "shrink explains", "Minimum" $ oD:cHint )
   oD:nInspField = 4   // dialog Height
   oD:InspAdjust( -100 )
   Check( "shrink keeps controls vert", oD:nDlgHeight == 9 )
   // restore the shared model for the following checks
   oD:aControls = {}
   AAdd( oD:aControls, { "type" => "get",    "row" => 3, "col" => 9, "variable" => "cVar1", "width" => 4, "caption" => "Save" } )
   AAdd( oD:aControls, { "type" => "button", "row" => 5, "col" => 2, "caption"  => "Save" } )

   // panel geometry: never loses its shadow off screen
   oD:lInspector = .T.
   oD:nInspRow = 500
   oD:nInspCol = 500
   aRect = oD:InspRect()
   Check( "insp rect on screen", aRect[ 4 ] <= MaxCol() - 2 .and. aRect[ 3 ] <= MaxRow() - 2 )
   oD:nInspRow = 2
   oD:nInspCol = 20
   aRect = oD:InspRect()
   Check( "insp hit title", oD:InspHit( aRect[ 1 ], aRect[ 2 ] + 2 ) == -1 )
   Check( "insp hit field", oD:InspHit( aRect[ 1 ] + 1, aRect[ 2 ] + 2 ) == 1 )
   Check( "insp hit outside", oD:InspHit( 0, 0 ) == 0 )

   // round trip of inspector-modified properties
   hModel = DsnBuildModel( oD )
   cJson  = hb_jsonEncode( hModel, .T. )
   hBack  = nil
   hb_jsonDecode( cJson, @hBack )
   Check( "insp roundtrip caption", hBack[ "controls" ][ 2 ][ "caption" ] == "Save" )
   Check( "insp roundtrip variable", hBack[ "controls" ][ 1 ][ "variable" ] == "cVar1" )
   Check( "insp roundtrip dlgwidth", hBack[ "width" ] == 31 )

   // radiogroup and listbox controls
   oCtrl = { "type" => "radiogroup", "row" => 1, "col" => 2, "variable" => "nRadio1", "items" => "Red,Green,Blue" }
   aSize = DsnControlSize( oCtrl )
   Check( "radio size", aSize[ 1 ] == 13 .and. aSize[ 2 ] == 5 )
   Check( "radio items", Len( DsnItems( oCtrl ) ) == 3 .and. DsnItems( oCtrl )[ 2 ] == "Green" )

   oCtrl = { "type" => "listbox", "row" => 1, "col" => 2, "variable" => "nList1", "items" => "One,Two", "width" => 16, "height" => 5 }
   aSize = DsnControlSize( oCtrl )
   Check( "listbox size", aSize[ 1 ] == 16 .and. aSize[ 2 ] == 5 )

   hModel = { "name" => "Pick", "caption" => "Pick one", "width" => 40, "height" => 14, "color" => "W+/W", "controls" => { ;
      { "type" => "radiogroup", "row" => 1, "col" => 2, "variable" => "nRadio1", "items" => "Red,Green" }, ;
      { "type" => "listbox", "row" => 8, "col" => 2, "variable" => "nList1", "items" => "One,Two", "width" => 16, "height" => 4 } } }
   cCode = DsnGenCode( hModel )
   Check( "gen radio declares var", "local nRadio1 := 1" $ cCode )
   Check( "gen radio declares butt", "local aButt1" $ cCode .and. "aButt1 := { RadioButto(" $ cCode )
   Check( "gen butt after dialog", At( "aButt1 :=", cCode ) > At( "HBWindow():Dialog", cCode ) )
   Check( "gen radio group clause", "GET nRadio1 RADIOGROUP aButt1" $ cCode )
   Check( "gen listbox declares items", "local aItems2" $ cCode .and. 'aItems2 := { "One", "Two" }' $ cCode )
   Check( "gen listbox clause", "GET nList1 LISTBOX aItems2" $ cCode )
   Check( "gen get color", "GET cName" $ cCode .or. .T. )
   Check( "gen radio item colors", "AEval( aButt1, {| o | o:colorSpec := '" $ cCode )
   Check( "gen listbox color", "LISTBOX aItems2 COLOR '" $ cCode )
   cCode = DsnGenCode( { "caption" => "T", "width" => 40, "height" => 12, "controls" => { ;
      { "type" => "listbox", "row" => 1, "col" => 2, "variable" => "nList2", "items" => "R&D.prg,&One", "width" => 16, "height" => 4 } } } )
   Check( "gen listbox keeps items verbatim", '"R&D.prg"' $ cCode .and. '"&One"' $ cCode )
   // json roundtrip of the new properties
   cJson = hb_jsonEncode( hModel, .T. )
   hBack = nil
   hb_jsonDecode( cJson, @hBack )
   Check( "json radio items", hBack[ "controls" ][ 1 ][ "items" ] == "Red,Green" )
   Check( "json listbox height", hBack[ "controls" ][ 2 ][ "height" ] == 4 )

   // per-option accelerators: & inside an item reaches the RadioButto caption
   hModel[ "controls" ][ 1 ][ "items" ] = "&Red,G&reen,Bl&ue"
   cCode = DsnGenCode( hModel )
   Check( "gen radio accel per item", '"&Red"' $ cCode .and. '"G&reen"' $ cCode .and. '"Bl&ue"' $ cCode )
   Check( "radio items keep amp", DsnItems( hModel[ "controls" ][ 1 ] )[ 1 ] == "&Red" )

   // inspector fields for the new types
   oD2 = HbDesigner():New( nil )
   AAdd( oD2:aControls, { "type" => "radiogroup", "row" => 1, "col" => 1, "variable" => "nRadio1", "items" => "A,B" } )
   oD2:nSelected = 1
   Check( "insp fields radio", Len( oD2:InspFields() ) == 4 )
   Check( "insp value items", oD2:InspValue( "items" ) == "A,B" )
   oD2:aControls[ 1 ] = { "type" => "listbox", "row" => 1, "col" => 1, "variable" => "nList1", "items" => "A,B", "width" => 20, "height" => 6 }
   Check( "insp fields listbox", Len( oD2:InspFields() ) == 6 )
   oD2:InspSetText( "items", "A,B,C,D" )
   Check( "insp set items", oD2:aControls[ 1 ][ "items" ] == "A,B,C,D" )

   // DsnDlgPair parses the first pair, defaults to the white dialog
   Check( "dlgpair blue",  DsnDlgPair( "W+/B, N/W" )[ 1 ] == "W+" .and. DsnDlgPair( "W+/B, N/W" )[ 2 ] == "B" )
   Check( "dlgpair black", DsnDlgPair( "GR+/N" )[ 2 ] == "N" )
   Check( "dlgpair default", DsnDlgPair( "" )[ 2 ] == "W" )

   // colored dialog: control palettes derive from the dialog background
   hModel = { "name" => "Clr", "caption" => "C", "width" => 40, "height" => 12, "color" => "W+/B", "controls" => { ;
      { "type" => "say", "row" => 1, "col" => 2, "caption" => "Lbl" }, ;
      { "type" => "get", "row" => 2, "col" => 2, "variable" => "cV1", "width" => 8 }, ;
      { "type" => "checkbox", "row" => 3, "col" => 2, "caption" => "Ck", "variable" => "lV1" }, ;
      { "type" => "button", "row" => 4, "col" => 2, "caption" => "OK" }, ;
      { "type" => "listbox", "row" => 5, "col" => 2, "variable" => "nL1", "items" => "One,Two", "width" => 12, "height" => 4 } } }
   cCode = DsnGenCode( hModel )
   Check( "clr say inherits", "hb_DispOutAt( oDlg:nTop" $ cCode .and. "'W+/B' )" $ cCode .and. ! ( "oDlg:Say(" $ cCode ) )
   Check( "clr get contrast", "COLOR 'N/W,B/W,N/W,GR+/W'" $ cCode )
   Check( "clr checkbox inherits", "COLOR 'W+/B,Y+/B,W+/B,GR+/B'" $ cCode )
   Check( "clr button contrast", "COLOR 'N/W,W+/N,N/W,R/W'" $ cCode )
   Check( "clr listbox contrast", "COLOR 'N/W,W+/N,N/W,W+/G,N/W,W+/W,GR+/W'" $ cCode )
   Check( "clr button display override", "__ClsModMsg( PushButton( 0, 0 ):ClassH, 'DISPLAY', @DsnBtnDisplay() )" $ cCode ;
          .and. "function DsnBtnDisplay()" $ cCode )
   Check( "clr shadow on dialog bg", ', "N/B" )' $ cCode )

   // default white dialog keeps hbide palettes byte-exact (regression)
   hModel = { "name" => "Def", "caption" => "D", "width" => 40, "height" => 12, "controls" => { ;
      { "type" => "say", "row" => 1, "col" => 2, "caption" => "Lbl" }, ;
      { "type" => "get", "row" => 2, "col" => 2, "variable" => "cV2", "width" => 8 }, ;
      { "type" => "checkbox", "row" => 3, "col" => 2, "caption" => "Ck", "variable" => "lV2" }, ;
      { "type" => "button", "row" => 4, "col" => 2, "caption" => "OK" } } }
   cCode = DsnGenCode( hModel )
   Check( "def say keeps oDlg:Say", "oDlg:Say(" $ cCode )
   Check( "def get palette", "COLOR 'W/B,W+/B,W+/W,GR+/W'" $ cCode )
   Check( "def checkbox palette", "COLOR 'N/W,BG+/W,N/W,GR+/W'" $ cCode )
   Check( "def button palette", "COLOR 'GR+/G,W+/G,N/G,BG+/G'" $ cCode )
   Check( "def no override", ! ( "__ClsModMsg" $ cCode ) .and. ! ( "DsnBtnDisplay" $ cCode ) )

   // canvas button shadow follows the dialog background (runtime equivalence)
   Check( "shadow default white", DsnCanvasShadowFor( "W+/W" ) == "N/W" )
   Check( "shadow blue dialog",  DsnCanvasShadowFor( "W+/B" ) == "N/B" )
   Check( "shadow black dialog", DsnCanvasShadowFor( "GR+/N" ) == "N/N" )

   // DsnFitRect: the design window and its shadow always stay on screen
   Check( "fit keeps fitting window", DsnFitRect( 19, 5, 41, 13, 79, 23 )[ 1 ] == 19 .and. ;
          DsnFitRect( 19, 5, 41, 13, 79, 23 )[ 2 ] == 5 )
   Check( "fit shifts big dialog", DsnFitRect( 19, 5, 62, 22, 79, 23 )[ 1 ] == 16 .and. ;
          DsnFitRect( 19, 5, 62, 22, 79, 23 )[ 2 ] == 0 )
   Check( "fit clamps to zero", DsnFitRect( 30, 10, 76, 22, 79, 23 )[ 1 ] == 2 .and. ;
          DsnFitRect( 30, 10, 76, 22, 79, 23 )[ 2 ] == 0 )
   Check( "fit leaves shadow room", DsnFitRect( 19, 5, 62, 22, 79, 23 )[ 1 ] + 62 + 1 <= 79 .and. ;
          DsnFitRect( 19, 5, 62, 22, 79, 23 )[ 2 ] + 22 + 1 <= 23 )
   Check( "view keeps fitting dialog", DsnViewSize( 40, 12, 79, 23 )[ 1 ] == 40 .and. ;
          DsnViewSize( 40, 12, 79, 23 )[ 2 ] == 12 )
   Check( "view clamps big dialog", DsnViewSize( 62, 22, 65, 21 )[ 1 ] == 61 .and. ;
          DsnViewSize( 62, 22, 65, 21 )[ 2 ] == 18 )
   Check( "view clamps only overflow", DsnViewSize( 62, 12, 65, 21 )[ 1 ] == 61 .and. ;
          DsnViewSize( 62, 12, 65, 21 )[ 2 ] == 12 )
   Check( "pan clamps to dialog edge", DsnPanClamp( 10, 62, 60 ) == 2 )
   Check( "pan keeps zero", DsnPanClamp( 0, 62, 60 ) == 0 .and. DsnPanClamp( -4, 62, 60 ) == 0 )
   Check( "pan no room to scroll", DsnPanClamp( 5, 40, 60 ) == 0 )
   Check( "write ok returns true", DsnSafeMemoWrit( hb_DirTemp() + "/dsn_t.json", "{}" ) .and. ;
          File( hb_DirTemp() + "/dsn_t.json" ) )
   Check( "write bad path returns false", ! DsnSafeMemoWrit( "/no/such/dir/x.json", "{}" ) )



   // --- robustness: unique variables, JSON validation, generation guards ---

   // unique variable names: a duplicate local would not compile (harbour E0003)
   Check( "unique var first", DsnUniqueVar( {}, "cVar" ) == "cVar1" )
   Check( "unique var skips used", DsnUniqueVar( { { "variable" => "cVar1" } }, "cVar" ) == "cVar2" )
   Check( "unique var fills gaps", DsnUniqueVar( { { "variable" => "cVar1" }, { "variable" => "cVar2" } }, "cVar" ) == "cVar3" )

   // the generator declares a shared variable only once
   hModel = { "name" => "Dup", "caption" => "Dup", "width" => 40, "height" => 12, "color" => "W+/W", "controls" => { ;
      { "type" => "get", "row" => 1, "col" => 2, "variable" => "cName", "width" => 10 }, ;
      { "type" => "get", "row" => 2, "col" => 2, "variable" => "cName", "width" => 10 } } }
   cCode = DsnGenCode( hModel )
   Check( "gen declares once", DsnCountOccur( "local cName", cCode ) == 1 )
   Check( "gen uses twice", DsnCountOccur( "GET cName", cCode ) == 2 )

   // an item-less radio/listbox cannot run: skipped with a note, never emitted
   hModel = { "name" => "Empty", "caption" => "Empty", "width" => 40, "height" => 12, "color" => "W+/W", "controls" => { ;
      { "type" => "radiogroup", "row" => 1, "col" => 2, "variable" => "nR", "items" => "" }, ;
      { "type" => "listbox", "row" => 4, "col" => 2, "variable" => "nL", "items" => "", "width" => 16, "height" => 4 } } }
   cCode = DsnGenCode( hModel )
   Check( "gen skips empty radio", ! ( "RADIOGROUP aButt" $ cCode ) .and. "skipped radiogroup" $ cCode )
   Check( "gen skips empty listbox", ! ( "LISTBOX aItems" $ cCode ) .and. "skipped listbox" $ cCode )
   Check( "gen empty declares nothing", ! ( "local nR" $ cCode ) .and. ! ( "local aButt" $ cCode ) )

   // JSON model validation
   Check( "model rejects scalar", ! DsnValidModel( 5 ) )
   Check( "model rejects no controls", ! DsnValidModel( { "name" => "X" } ) )
   Check( "model rejects hash controls", ! DsnValidModel( { "controls" => { "a" => 1 } } ) )
   Check( "model accepts empty array", DsnValidModel( { "controls" => {} } ) )

   // normalization of hand-edited JSON: foreign entries out, types coerced
   aSize = { 5, { "type" => "grid", "row" => 1, "col" => 1 }, ;
      { "type" => "get", "row" => "3", "col" => "2", "width" => "abc" }, ;
      { "type" => "radiogroup", "row" => 1, "col" => 1, "items" => { "A", "B" } }, ;
      { "type" => "checkbox", "row" => 2, "col" => 1, "caption" => 7 } }
   DsnNormalizeControls( aSize )
   Check( "normalize drops foreign", Len( aSize ) == 3 )
   Check( "normalize row numeric", aSize[ 1 ][ "row" ] == 3 .and. HB_IsNumeric( aSize[ 1 ][ "row" ] ) )
   Check( "normalize width default", aSize[ 1 ][ "width" ] == 10 )
   Check( "normalize var created", aSize[ 1 ][ "variable" ] == "cVar1" )
   Check( "normalize items array", aSize[ 2 ][ "items" ] == "A,B" )
   Check( "normalize var radio", aSize[ 2 ][ "variable" ] == "nVar1" )
   Check( "normalize caption string", aSize[ 3 ][ "caption" ] == "" )
   Check( "normalize var check", aSize[ 3 ][ "variable" ] == "lVar1" )

   // same name with different types: separate variables, conflict counted
   hModel = { "name" => "Conf", "caption" => "Conf", "width" => 40, "height" => 12, "color" => "W+/W", "controls" => { ;
      { "type" => "get", "row" => 1, "col" => 2, "variable" => "cName", "width" => 10 }, ;
      { "type" => "checkbox", "row" => 2, "col" => 2, "variable" => "cName", "caption" => "Active" } } }
   cCode = DsnGenCode( hModel, @nMaxRow, @nMaxCol )
   Check( "conflict counted", nMaxCol == 1 )
   Check( "conflict text kept", DsnCountOccur( "local cName := Space( 10 )", cCode ) == 1 )
   Check( "conflict logic renamed", "local cName2 := .F." $ cCode )
   Check( "conflict get renamed", "GET cName2 CHECKBOX" $ cCode )
   Check( "same type still shares", DsnCountOccur( "GET cName ", cCode ) == 1 )
   Check( "model not polluted", ! ( "xgenvar" $ hModel[ "controls" ][ 1 ] ) )

   // checkbox size ignores the & accelerator marker (it is not drawn)
   Check( "checkbox size no amp", DsnControlSize( { "type" => "checkbox", "caption" => "&Active" } )[ 1 ] == 10 )

   oD:oWnd:Hide()

   // inspector must stay above the dialog frame across suspend/resume idle cycles:
   // HBWindow:MouseEvent repaints the window frame on plain mouse idles (its
   // otherwise branch), so the redraw idle must be registered after the mouse
   // idle; ResumeUI used to re-register them in the wrong order
   SetMode( 25, 80 )
   CLS
   oD2 = HbDesigner():New( TStubIde():New() )
   oD2:oWnd = HBWindow():Dialog( oD2:cDlgCaption, oD2:nDlgWidth, oD2:nDlgHeight, oD2:cDlgColor )
   oD2:oWnd:bRepaint = { || oD2:oIde:Repaint() }
   oD2:oWnd:lDesign  = .T.
   oD2:lInspector = .T.
   oD2:nInspRow = oD2:oWnd:nTop              // inspector over the dialog title row
   oD2:nInspCol = oD2:oWnd:nLeft + 10
   oD2:SuspendUI()
   oD2:ResumeUI()
   oD2:DrawControls()                         // reference: inspector painted last
   cCellRef = SaveScreen( oD2:oWnd:nTop, oD2:oWnd:nLeft + 12, ;
                          oD2:oWnd:nTop, oD2:oWnd:nLeft + 12 )
   oD2:oWnd:Refresh()                         // frame painted over inspector
   cCellNow = SaveScreen( oD2:oWnd:nTop, oD2:oWnd:nLeft + 12, ;
                          oD2:oWnd:nTop, oD2:oWnd:nLeft + 12 )
   Check( "idle layering test discriminates", cCellNow != cCellRef )
   oD2:DrawControls()                         // back to inspector-last
   // hb_idleState() runs idle tasks round-robin, one per call: two calls cover
   // both designer idles. With no mouse button held, neither may repaint the
   // dialog frame: HBWindow:MouseEvent's otherwise branch calls Refresh() on
   // every plain mouse idle, which would overpaint controls and the inspector
   hb_idleState()
   hb_idleState()
   cCellNow = SaveScreen( oD2:oWnd:nTop, oD2:oWnd:nLeft + 12, ;
                          oD2:oWnd:nTop, oD2:oWnd:nLeft + 12 )
   Check( "plain mouse idle keeps inspector over dialog frame", cCellNow == cCellRef )
   hb_IdleDel( oD2:oWnd:nIdle )
   hb_IdleDel( oD2:nIdleDraw )
   oD2:oWnd:Hide()

   // HBWindow:Dialog() larger than the screen used to paint corrupted (the
   // centered coordinates go negative and GT rejects the whole frame): it is
   // now moved on-screen and cut to the screen size, keeping the relative
   // control offsets, and reports it through lClamped
   oDlg = HBWindow():Dialog( "Big", 100, 45, "W+/B" )
   Check( "oversized dialog clamped on-screen", ;
      oDlg:nTop == 0 .and. oDlg:nLeft == 0 .and. ;
      oDlg:nBottom == MaxRow() .and. oDlg:nRight == MaxCol() )
   Check( "oversized dialog reports clamp", oDlg:lClamped )
   Check( "oversized dialog keeps requested size", ;
      oDlg:nReqWidth == 100 .and. oDlg:nReqHeight == 45 )
   nCell = Asc( SaveScreen( 0, 0, 0, 0 ) )
   Check( "oversized dialog paints its frame", nCell != 32 .and. nCell != 0 )
   oDlg:Hide()
   Check( "hide restores screen after clamp", Asc( SaveScreen( 0, 0, 0, 0 ) ) == 32 )

   // full-buffer proof: paint a deterministic screen, open an oversized
   // dialog, hide it and require the whole visible area back byte-exact
   CLS
   for nCell = 0 to MaxRow()
      hb_DispOutAt( nCell, 0, Replicate( Chr( 65 + nCell ), MaxCol() + 1 ) )
   next
   cBefore = SaveScreen( 0, 0, MaxRow(), MaxCol() )
   oDlg = HBWindow():Dialog( "Big", 100, 45, "W+/B" )
   oDlg:Hide()
   cAfter = SaveScreen( 0, 0, MaxRow(), MaxCol() )
   Check( "oversized hide restores full screen", cAfter == cBefore )

   oDlg = HBWindow():Dialog( "Small", 40, 10, "W+/B" )
   Check( "fitting dialog keeps its geometry", ;
      oDlg:nTop == Int( ( MaxRow() / 2 ) - 5 ) .and. ;
      oDlg:nBottom == Int( ( MaxRow() / 2 ) + 5 ) .and. ;
      oDlg:nLeft == Int( ( MaxCol() / 2 ) - 20 ) .and. ;
      oDlg:nRight == Int( ( MaxCol() / 2 ) + 20 ) )
   Check( "fitting dialog is not clamped", ! oDlg:lClamped )
   Check( "fitting dialog keeps requested size", ;
      oDlg:nReqWidth == 40 .and. oDlg:nReqHeight == 10 )
   oDlg:Hide()

   // placing ghost clamps to the last origin where the whole control fits,
   // so it never vanishes past an edge while moving it with the arrows
   oD2 = HbDesigner():New( nil )
   oD2:nDlgWidth  = 41
   oD2:nDlgHeight = 14
   oD2:cPlacingType = "listbox"
   oD2:nGhostRow = 12
   oD2:nGhostCol = 39
   oD2:ClampGhost()
   Check( "ghost row clamped to fit height", oD2:nGhostRow == 14 - 2 - 6 )
   Check( "ghost col clamped to fit width", oD2:nGhostCol == 41 - 2 - 20 )
   oD2:nGhostRow = -3
   oD2:nGhostCol = -3
   oD2:ClampGhost()
   Check( "ghost pinned at origin", oD2:nGhostRow == 0 .and. oD2:nGhostCol == 0 )
   oD2:nDlgHeight = 5
   oD2:nGhostRow = 9
   oD2:ClampGhost()
   Check( "oversized ghost pinned at 0", oD2:nGhostRow == 0 )

   // control resize handles: GET width and LISTBOX width/height resize by
   // deltas, clamped to their minimums and to the dialog interior; other
   // types derive their size from caption/items and do not resize
   oCtrl = { "type" => "get", "row" => 2, "col" => 3, "width" => 10 }
   Check( "resize get wider", DsnResize( oCtrl, 5, 0, 56, 18 ) .and. oCtrl[ "width" ] == 15 )
   Check( "resize get min width", DsnResize( oCtrl, -99, 0, 56, 18 ) .and. oCtrl[ "width" ] == 1 )
   Check( "resize get clamped to dialog", DsnResize( oCtrl, 99, 0, 56, 18 ) .and. ;
      oCtrl[ "width" ] == 56 - 2 - 3 )
   Check( "get is resizable", DsnResizable( oCtrl ) )
   oCtrl = { "type" => "listbox", "row" => 4, "col" => 3, "width" => 20, "height" => 6, "items" => "A,B" }
   Check( "resize listbox taller", DsnResize( oCtrl, 0, 3, 56, 18 ) .and. oCtrl[ "height" ] == 9 )
   Check( "resize listbox minimums", DsnResize( oCtrl, -99, -99, 56, 18 ) .and. ;
      oCtrl[ "width" ] == 4 .and. oCtrl[ "height" ] == 3 )
   Check( "resize listbox clamped to dialog", DsnResize( oCtrl, 99, 99, 56, 18 ) .and. ;
      oCtrl[ "width" ] == 56 - 2 - 3 .and. oCtrl[ "height" ] == 18 - 2 - 4 )
   oCtrl = { "type" => "say", "row" => 0, "col" => 0, "caption" => "Name:" }
   Check( "resize say is a no-op", ! DsnResize( oCtrl, 5, 5, 56, 18 ) )
   Check( "say is not resizable", ! DsnResizable( oCtrl ) )

   // codegen follows the resized size: the GET var widens, the LISTBOX
   // bottom/right coordinates move with the new width/height
   hModel = { "name" => "ResizeDemo", "caption" => "Resize", "width" => 56, ;
              "height" => 18, "color" => "W+/B", ;
              "controls" => { ;
                 { "type" => "get", "row" => 2, "col" => 3, "variable" => "cTxt", "width" => 15 }, ;
                 { "type" => "listbox", "row" => 4, "col" => 3, "variable" => "nLb", ;
                   "items" => "A,B", "width" => 22, "height" => 9 } } }
   cCode = DsnGenCode( hModel, @nMaxRow, @nMaxCol )
   Check( "gen uses resized get width", "Space( 15 )" $ cCode )
   Check( "gen uses resized listbox size", ;
      "oDlg:nTop + 13, oDlg:nLeft + 25" $ cCode )

   // frame clipping: a control wider or taller than the drawable area keeps
   // a clipped frame (DispBox edges) instead of losing the box completely;
   // fewer than two visible rows or columns means no drawable box
   Check( "frame clip fully inside", ;
      DsnFrameClip( 5, 5, 14, 5, 30, 79 )[ 1 ] == 9 .and. ;
      DsnFrameClip( 5, 5, 14, 5, 30, 79 )[ 2 ] == 18 )
   Check( "frame clip right edge", ;
      DsnFrameClip( 5, 70, 14, 5, 30, 79 )[ 1 ] == 9 .and. ;
      DsnFrameClip( 5, 70, 14, 5, 30, 79 )[ 2 ] == 79 )
   Check( "frame clip bottom edge", ;
      DsnFrameClip( 5, 5, 14, 30, 20, 79 )[ 1 ] == 19 .and. ;
      DsnFrameClip( 5, 5, 14, 30, 20, 79 )[ 2 ] == 18 )
   Check( "frame clip one column left is nil", DsnFrameClip( 5, 79, 14, 5, 30, 79 ) == NIL )
   Check( "frame clip one row left is nil", DsnFrameClip( 19, 5, 14, 5, 20, 79 ) == NIL )

   // button shadow glyphs follow the active codepage: CP437 keeps the raw
   // half blocks (byte-identical to the old Chr(220)/Chr(223)), the UTF-8
   // opt-in gets the multi-byte encoding so they no longer render as '?'
   Check( "button shadow cp437 bytes", ;
      HbBtnShadowChars()[ 1 ] == Chr( 220 ) .and. HbBtnShadowChars()[ 2 ] == Chr( 223 ) )
   hb_cdpSelect( "UTF8" )
   Check( "button shadow utf8 encoded", ;
      HbBtnShadowChars()[ 1 ] == hb_UTF8ToStr( "▄" ) .and. ;
      Len( HbBtnShadowChars()[ 1 ] ) > 1 )
   hb_cdpSelect( "EN" )

   // caption pads follow the active codepage the same way: CP437 keeps the
   // raw Chr(255) pair, the UTF-8 opt-in gets the two-byte U+00A0 encoding
   Check( "button pads cp437 bytes", ;
      HbBtnPadChars()[ 1 ] == Chr( 255 ) .and. HbBtnPadChars()[ 2 ] == Chr( 255 ) )
   hb_cdpSelect( "UTF8" )
   Check( "button pads utf8 encoded", ;
      HbBtnPadChars()[ 1 ] == Chr( 194 ) + Chr( 160 ) .and. ;
      HbBtnPadChars()[ 2 ] == Chr( 194 ) + Chr( 160 ) )
   hb_cdpSelect( "EN" )

   // generated dialogs emit the same codepage-aware button display: pads
   // and shadow half blocks convert for the active codepage, no raw CP437
   // bytes that render as '?' under the UTF-8 opt-in
   Check( "gen button pads cp-aware", "DsnBtnPads()" $ cCode )
   Check( "gen button shades cp-aware", "DsnBtnShades()" $ cCode )
   Check( "gen no raw cp437 pad bytes", ! "Chr( 255 )" $ cCode )
   Check( "gen no raw cp437 shadow bytes", ! ( "Chr( 220 )" $ cCode ) )

   // undo/redo history: deep copies, equality, stack ops, burst coalescing
   hT = { "h" => { "x" => "y" }, "l" => { 1, 2 } }
   hS1 = DsnCloneValue( hT )
   hT[ "h" ][ "x" ] = "z"
   hT[ "l" ][ 1 ] = 99
   Check( "clone detaches nested hash", hS1[ "h" ][ "x" ] == "y" )
   Check( "clone detaches nested array", hS1[ "l" ][ 1 ] == 1 )

   oD = HbDesigner():New( TStubIde() )
   oD:cDlgName = "Hist"
   AAdd( oD:aControls, { "type" => "say", "row" => 1, "col" => 2, "caption" => "One" } )
   oD:nSelected = 1
   hS0 = DsnSnapshot( oD )
   oD:aControls[ 1 ][ "row" ] = 9
   Check( "snapshot is a deep copy", hS0[ "controls" ][ 1 ][ "row" ] == 1 )
   Check( "snap equal same state", DsnSnapEqual( hS0, hS0 ) )
   Check( "snap detects change", ! DsnSnapEqual( hS0, DsnSnapshot( oD ) ) )

   aU = {}
   aR = { { "mark" => "old" } }
   DsnHistPush( aU, aR, hS0 )
   Check( "push adds to undo", Len( aU ) == 1 )
   Check( "push clears redo", Len( aR ) == 0 )

   aU = {}
   for nCell = 1 to 105
      DsnHistPush( aU, aR, { "mark" => nCell } )
   next
   Check( "history capped at 100", Len( aU ) == 100 )
   Check( "oldest snapshot dropped", aU[ 1 ][ "mark" ] == 6 )

   hS1 = DsnSnapshot( oD )   // row 9 state
   aU = {}
   aR = {}
   DsnHistPush( aU, aR, hS0 )
   hT = DsnHistUndo( aU, aR, hS1 )
   Check( "undo returns previous state", hT[ "controls" ][ 1 ][ "row" ] == 1 )
   Check( "undo pushes current to redo", Len( aR ) == 1 .and. aR[ 1 ][ "controls" ][ 1 ][ "row" ] == 9 )
   Check( "undo empties undo stack", Empty( aU ) )
   Check( "undo on empty is nil", DsnHistUndo( aU, aR, hS0 ) == nil )
   hT = DsnHistRedo( aR, aU, hS0 )
   Check( "redo returns next state", hT[ "controls" ][ 1 ][ "row" ] == 9 )
   Check( "redo pushes current to undo", Len( aU ) == 1 )
   Check( "redo on empty is nil", DsnHistRedo( aR, aU, hS0 ) == nil )

   oD2 = HbDesigner():New( TStubIde() )
   oD2:cDlgName = "Cycle"
   oD2:PushHistory()
   AAdd( oD2:aControls, { "type" => "get", "row" => 2, "col" => 2, "variable" => "cA", "width" => 8 } )
   oD2:PushHistory()
   oD2:aControls[ 1 ][ "row" ] = 5
   Check( "two actions stacked", Len( oD2:aUndo ) == 2 )
   hT = DsnHistUndo( oD2:aUndo, oD2:aRedo, DsnSnapshot( oD2 ) )
   Check( "first undo restores pre-move", hT[ "controls" ][ 1 ][ "row" ] == 2 )
   hT = DsnHistUndo( oD2:aUndo, oD2:aRedo, hT )
   Check( "second undo restores empty model", Empty( hT[ "controls" ] ) )
   Check( "both states on redo stack", Len( oD2:aRedo ) == 2 )
   DsnHistPush( oD2:aUndo, oD2:aRedo, hS0 )
   Check( "new action clears redo", Empty( oD2:aRedo ) )

   // burst coalescing: consecutive moves are one undo step, no-ops push nothing
   oD2 = HbDesigner():New( TStubIde() )
   AAdd( oD2:aControls, { "type" => "say", "row" => 1, "col" => 1, "caption" => "X" } )
   oD2:nSelected = 1
   oD2:BeginBurst()
   oD2:CommitBurst()
   Check( "no-op burst pushes nothing", Empty( oD2:aUndo ) )
   oD2:aControls[ 1 ][ "row" ] = 3
   oD2:CommitBurst()
   Check( "burst pushes pre-burst state", Len( oD2:aUndo ) == 1 .and. oD2:aUndo[ 1 ][ "controls" ][ 1 ][ "row" ] == 1 )
   oD2:aControls[ 1 ][ "row" ] = 4
   oD2:CommitBurst()
   Check( "burst stays one undo step", Len( oD2:aUndo ) == 1 )

   // clipboard: copy/paste/cut
   oD2 = HbDesigner():New( TStubIde() )
   AAdd( oD2:aControls, { "type" => "get", "row" => 2, "col" => 3, "variable" => "cVar1", "width" => 10 } )
   oD2:nSelected = 1
   oD2:CopySelected()
   Check( "copy keeps model", Len( oD2:aControls ) == 1 )
   Check( "copy detaches clone", !( oD2:oClipboard == oD2:aControls[ 1 ] ) )
   oD2:PasteClipboard()
   Check( "paste adds control", Len( oD2:aControls ) == 2 )
   Check( "paste offsets position", oD2:aControls[ 2 ][ "row" ] == 3 .and. oD2:aControls[ 2 ][ "col" ] == 4 )
   Check( "paste fresh variable", oD2:aControls[ 2 ][ "variable" ] != "cVar1" )
   oD2:PasteClipboard()
   Check( "second paste offsets more", oD2:aControls[ 3 ][ "row" ] == 4 .and. oD2:aControls[ 3 ][ "col" ] == 5 )
   Check( "pastes on undo stack", Len( oD2:aUndo ) == 2 )
   hT = DsnHistUndo( oD2:aUndo, oD2:aRedo, DsnSnapshot( oD2 ) )
   Check( "undo removes last paste", Len( hT[ "controls" ] ) == 2 )
   oD2:nSelected = 1
   oD2:CutSelected()
   Check( "cut removes control", Len( oD2:aControls ) == 2 )
   Check( "cut fills clipboard", oD2:oClipboard[ "variable" ] == "cVar1" )
   Check( "cut on undo stack", Len( oD2:aUndo ) == 2 )
   oD2 = HbDesigner():New( TStubIde() )
   oD2:PasteClipboard()
   Check( "paste with empty clipboard is a no-op", Empty( oD2:aControls ) .and. Empty( oD2:aUndo ) )

   // snap to grid (F7)
   oD2 = HbDesigner():New( TStubIde() )
   Check( "snap off by default", ! oD2:lSnap )
   oD2:lSnap = .T.
   Check( "snap 0,0 keeps", oD2:SnapPos( 0, 0 )[ 1 ] == 0 .and. oD2:SnapPos( 0, 0 )[ 2 ] == 0 )
   Check( "snap rounds to grid", oD2:SnapPos( 3, 5 )[ 1 ] == 4 .and. oD2:SnapPos( 3, 5 )[ 2 ] == 6 )
   Check( "snap keeps aligned", oD2:SnapPos( 2, 2 )[ 1 ] == 2 .and. oD2:SnapPos( 2, 2 )[ 2 ] == 2 )
   oD2:lSnap = .F.
   Check( "snap off is identity", oD2:SnapPos( 3, 5 )[ 1 ] == 3 .and. oD2:SnapPos( 3, 5 )[ 2 ] == 5 )
   oD2:ToggleSnap()
   Check( "toggle turns on", oD2:lSnap )
   oD2:ToggleSnap()
   Check( "toggle turns off", ! oD2:lSnap )
   oD2:lSnap = .T.
   oD2:nDlgWidth = 41
   oD2:nDlgHeight = 13
   oD2:cPlacingType = "get"
   oD2:nGhostRow = 3
   oD2:nGhostCol = 5
   oD2:ClampGhost()
   Check( "ghost snapped to grid", oD2:nGhostRow == 4 .and. oD2:nGhostCol == 6 )
   AAdd( oD2:aControls, { "type" => "get", "row" => 4, "col" => 6, "variable" => "cVar1", "width" => 10 } )
   oD2:nSelected = 1
   oD2:MoveSelected( 1, 0 )
   Check( "move snapped to grid", oD2:aControls[ 1 ][ "row" ] == 6 )
   oD2:MoveSelected( -1, 0 )
   Check( "snap move never sticks", oD2:aControls[ 1 ][ "row" ] == 4 )
   Check( "toggle is not a history entry", Len( oD2:aUndo ) == 1 )

   QOut( "" )
   QOut( "PASSED: " + hb_ntos( s_nPassed ) + "  FAILED: " + hb_ntos( s_nFailed ) )
   ErrorLevel( If( s_nFailed == 0, 0, 1 ) )

return


static function DsnCountOccur( cSub, cText )

   local n := 0, nPos := 1

   while ( nPos := hb_At( cSub, cText, nPos ) ) > 0
      n++
      nPos += Len( cSub )
   enddo

return n

procedure Check( cWhat, lOk )

   if lOk
      s_nPassed++
      QOut( "  ok   " + cWhat )
   else
      s_nFailed++
      QOut( "  FAIL " + cWhat )
   endif

return

CLASS TStubIde
   METHOD SuspendStatus() INLINE nil
   METHOD ResumeStatus()  INLINE nil
   METHOD Repaint()       INLINE nil
ENDCLASS

//
// test_designer.prg - non-interactive checks for the designer core functions
// Run: hbmk2 test_designer.prg ../designer.prg ../hbwindow.prg ../hbmenu.prg ../hbbutton.prg -gttrm
//

#include "hbclass.ch"

static s_nPassed := 0, s_nFailed := 0

procedure Main()

   local hModel, cCode, cJson, hBack, aSize

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

   QOut( "" )
   QOut( "PASSED: " + hb_ntos( s_nPassed ) + "  FAILED: " + hb_ntos( s_nFailed ) )
   ErrorLevel( If( s_nFailed == 0, 0, 1 ) )

return

procedure Check( cWhat, lOk )

   if lOk
      s_nPassed++
      QOut( "  ok   " + cWhat )
   else
      s_nFailed++
      QOut( "  FAIL " + cWhat )
   endif

return

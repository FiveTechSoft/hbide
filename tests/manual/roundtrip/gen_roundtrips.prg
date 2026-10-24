// gen_roundtrips.prg - roundtrip harness generator (see README.md)
//
// Builds three small designer models (radiogroup, listbox, get+checkbox),
// generates their dialogs with DsnGenCode(), instruments each one to write
// the final variable values to a /tmp file right after oDlg:Activate(),
// and emits the matching runner programs. Manual key/mouse driving then
// proves that the generated dialogs roundtrip the chosen values.

function Main()

   local hModel, cCode

   hb_jsonDecode( '{ "name": "RadioTest", "caption": "Radio Test", "width": 40, "height": 14, "controls": [' + ;
      '{ "type": "radiogroup", "row": 2, "col": 4, "variable": "nOpt", "items": "First,Second,Third" },' + ;
      '{ "type": "button", "row": 8, "col": 4, "caption": "OK", "accelerator": "O", "action": "lOk := .T., oDlg:End()" } ] }', @hModel )
   cCode = DsnGenCode( hModel )
   cCode = StrTran( cCode, "   oDlg:Activate( GetList )", ;
      '   oDlg:Activate( GetList )' + hb_eol() + ;
      '   hb_MemoWrit( "/tmp/radio_result.txt", "nOpt=" + hb_ntos( nOpt ) )' )
   hb_MemoWrit( "/tmp/radiotest_run.prg", cCode )
   hb_MemoWrit( "/tmp/runradio.prg", ;
      "function Main()" + hb_eol() + ;
      '   SetColor( "N/W" )' + hb_eol() + ;
      "   CLS" + hb_eol() + ;
      "   Dlg_RadioTest()" + hb_eol() + ;
      "return NIL" + hb_eol() )

   hb_jsonDecode( '{ "name": "ListTest", "caption": "List Test", "width": 40, "height": 14, "controls": [' + ;
      '{ "type": "listbox", "row": 2, "col": 4, "variable": "nSel", "items": "Alpha,Beta,Gamma" },' + ;
      '{ "type": "button", "row": 8, "col": 4, "caption": "OK", "accelerator": "O", "action": "lOk := .T., oDlg:End()" } ] }', @hModel )
   cCode = DsnGenCode( hModel )
   cCode = StrTran( cCode, "   oDlg:Activate( GetList )", ;
      '   oDlg:Activate( GetList )' + hb_eol() + ;
      '   hb_MemoWrit( "/tmp/list_result.txt", "nSel=" + hb_ntos( nSel ) )' )
   hb_MemoWrit( "/tmp/listtest_run.prg", cCode )
   hb_MemoWrit( "/tmp/runlist.prg", ;
      "function Main()" + hb_eol() + ;
      '   SetColor( "N/W" )' + hb_eol() + ;
      "   CLS" + hb_eol() + ;
      "   Dlg_ListTest()" + hb_eol() + ;
      "return NIL" + hb_eol() )

   hb_jsonDecode( '{ "name": "MixTest", "caption": "Mix Test", "width": 44, "height": 14, "controls": [' + ;
      '{ "type": "get", "row": 2, "col": 4, "variable": "cName", "width": 15 },' + ;
      '{ "type": "checkbox", "row": 4, "col": 4, "caption": "Enabled", "variable": "lEna" },' + ;
      '{ "type": "button", "row": 8, "col": 4, "caption": "OK", "accelerator": "O", "action": "lOk := .T., oDlg:End()" } ] }', @hModel )
   cCode = DsnGenCode( hModel )
   cCode = StrTran( cCode, "   oDlg:Activate( GetList )", ;
      '   oDlg:Activate( GetList )' + hb_eol() + ;
      '   hb_MemoWrit( "/tmp/mix_result.txt", "cName=[" + cName + "] lEna=" + If( lEna, "T", "F" ) )' )
   hb_MemoWrit( "/tmp/mixtest_run.prg", cCode )
   hb_MemoWrit( "/tmp/runmix.prg", ;
      "function Main()" + hb_eol() + ;
      '   SetColor( "N/W" )' + hb_eol() + ;
      "   CLS" + hb_eol() + ;
      "   Dlg_MixTest()" + hb_eol() + ;
      "return NIL" + hb_eol() )

   ? "wrote /tmp/{radio,list,mix}test_run.prg and /tmp/run{radio,list,mix}.prg"

return NIL

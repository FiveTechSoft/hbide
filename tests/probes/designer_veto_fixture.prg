// Synthetic GET vetoes only; no private expressions are executed.
procedure Main( cOut )
   local hModel, oCtrl, cCode, cMode
   for each cMode in { "when", "valid" }
      oCtrl := DsnNewControl( "get", {} )
      oCtrl[ "row" ] := 2
      oCtrl[ "col" ] := 4
      oCtrl[ cMode ] := "VetoProbe()"
      hModel := { "name" => "Veto", "caption" => cMode, "width" => 50, "height" => 20, ;
         "controls" => { oCtrl, ;
            { "type" => "button", "row" => 15, "col" => 4, "caption" => "OK", ;
              "accelerator" => "O", "action" => "lOk := .T., oDlg:End()" } } }
      cCode := DsnGenCode( hModel )
      cCode := StrTran( cCode, "return lOk", ;
         "hb_MemoWrit( '" + cOut + "/" + cMode + ".value', cVar1 )" + hb_eol() + ;
         "hb_MemoWrit( '" + cOut + "/" + cMode + ".ok', If( lOk, 'T', 'F' ) )" + hb_eol() + ;
         "return lOk" )
      cCode += hb_eol() + "function VetoProbe()" + hb_eol() + ;
         "   local cLog := '" + cOut + "/" + cMode + ".calls'" + hb_eol() + ;
         "   hb_MemoWrit( cLog, hb_MemoRead( cLog ) + 'call' + hb_eol() )" + hb_eol() + ;
         "return File( '" + cOut + "/" + cMode + ".allow' )" + hb_eol() + ;
         "procedure Main()" + hb_eol() + ;
         "   Dlg_Veto()" + hb_eol() + ;
         "return" + hb_eol()
      hb_MemoWrit( cOut + "/" + cMode + ".prg", cCode )
   next
return

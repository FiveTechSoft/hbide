// Generate actual designer artifacts for PTY runtime acceptance.
procedure Main( cOut )
   local hModel, oCtrl, cName, cCode, cResult, cType
   for each cType in { "radiogroup", "listbox", "combobox", "checkbox", "get" }
      cName := "Probe_" + cType
      oCtrl := DsnNewControl( cType, {} )
      oCtrl[ "row" ] := 2
      oCtrl[ "col" ] := 4
      if cType $ "radiogroup|listbox|combobox"
         oCtrl[ "items" ] := "First,Second,Third,Fourth,Fifth,Sixth,Seventh,Eighth"
         oCtrl[ "width" ] := 22
         oCtrl[ "height" ] := 7
         cResult := 'hb_ntos( nVar1 )'
      elseif cType == "checkbox"
         oCtrl[ "caption" ] := "Enabled"
         cResult := 'If( lVar1, "T", "F" )'
      else
         cResult := 'AllTrim( cVar1 )'
      endif
      hModel := { "name" => cName, "caption" => cName, "width" => 50, "height" => 20, ;
         "controls" => { oCtrl, ;
            { "type" => "button", "row" => 15, "col" => 4, "caption" => "OK", ;
              "accelerator" => "O", "action" => "lOk := .T., oDlg:End()" } } }
      // ComboBox starts unfocused to exercise focus transfer on a click.
      if cType == "combobox"
         hb_AIns( hModel[ "controls" ], 1, { "type" => "get", "row" => 0, "col" => 4, ;
            "variable" => "cLead", "width" => 10 }, .T. )
      endif
      cCode := DsnGenCode( hModel )
      cCode := StrTran( cCode, 'return lOk', ;
         'hb_MemoWrit( "' + cOut + '/' + cType + '.value", ' + cResult + ' )' + hb_eol() + 'return lOk' )
      cCode += hb_eol() + 'procedure Main()' + hb_eol() + ;
         'Dlg_' + cName + '()' + hb_eol() + 'return' + hb_eol()
      hb_MemoWrit( cOut + '/' + cType + '.prg', cCode )
   next
return

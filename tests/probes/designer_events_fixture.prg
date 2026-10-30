// Synthetic event expressions only. No private/user handlers are evaluated.
procedure Main( cOut )
   local hModel, oCtrl, cCode, cType, cKey, aEvents
   for each cType in { "get", "checkbox", "button", "radiogroup", "listbox", "combobox" }
      oCtrl := DsnNewControl( cType, {} )
      oCtrl[ "row" ] := 2
      oCtrl[ "col" ] := 4
      if cType $ "radiogroup|listbox|combobox"
         oCtrl[ "items" ] := "First,Second,Third,Fourth"
      endif
      if cType == "button"
         oCtrl[ "caption" ] := "Trigger"
         oCtrl[ "action" ] := "EventProbe( 'action' )"
      endif
      aEvents := { "when", "valid" }
      if cType != "get"
         AAdd( aEvents, "focus" )
      endif
      if cType $ "checkbox|listbox|combobox"
         AAdd( aEvents, "state" )
      endif
      for each cKey in aEvents
         oCtrl[ cKey ] := "EventProbe( '" + cKey + "' )"
      next
      hModel := { "name" => "EventProbe", "caption" => cType, "width" => 50, "height" => 20, ;
         "controls" => { oCtrl, ;
            { "type" => "button", "row" => 15, "col" => 4, "caption" => "OK", ;
              "accelerator" => "O", "action" => "lOk := .T., oDlg:End()" } } }
      cCode := DsnGenCode( hModel )
      cCode := StrTran( cCode, "return lOk", ;
         "hb_MemoWrit( '" + cOut + "/" + cType + ".ok', If( lOk, 'T', 'F' ) )" + hb_eol() + ;
         "return lOk" )
      cCode += hb_eol() + "function EventProbe( cEvent )" + hb_eol() + ;
         "   local cFile := '" + cOut + "/" + cType + ".events'" + hb_eol() + ;
         "   hb_MemoWrit( cFile, hb_MemoRead( cFile ) + cEvent + hb_eol() )" + hb_eol() + ;
         "return .T." + hb_eol() + ;
         "procedure Main()" + hb_eol() + ;
         "   Dlg_EventProbe()" + hb_eol() + ;
         "return" + hb_eol()
      hb_MemoWrit( cOut + "/" + cType + ".prg", cCode )
   next
return

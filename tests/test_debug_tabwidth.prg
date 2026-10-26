// Native code-browser regression, including tabs beyond the old cached width.
PROCEDURE Main()
   LOCAL o, cLine := Replicate( Chr( 9 ), 4 ) + 'x := x + 41'
   LOCAL cFile := hb_DirTemp() + 'hb-tab-' + hb_ntos( hb_MilliSeconds() ) + '.prg'
   LOCAL cSource := 'procedure Main()' + hb_eol() + cLine + hb_eol()
   hb_MemoWrit( cFile, cSource )
   o := HBBrwText():New( 1, 1, 20, 78, cFile, 'W/N,W/B', .F., 4 )
   o:oBrw:GetColumn( 1 ):colorBlock := {|| { 1, 1 } }
   o:nRow := 2
   Assert( At( 'x := x + 41', o:GetLine() ) == 17, 'initial tab 4' )
   o:SetTabWidth( 12 )
   o:oBrw:GetColumn( 1 ):colorBlock := {|| { 1, 1 } }
   o:nRow := 2
   Assert( At( 'x := x + 41', o:GetLine() ) == 49, 'tab 12 keeps text after four tabs' )
   Assert( o:nMaxLineLen >= 59, 'expanded width recalculated' )
   Assert( o:aRows[ 2 ] == cLine .AND. MemoRead( cFile ) == cSource, 'buffer and source unchanged' )
   o:SetTabWidth( 4 )
   o:oBrw:GetColumn( 1 ):colorBlock := {|| { 1, 1 } }
   o:nRow := 2
   Assert( At( 'x := x + 41', o:GetLine() ) == 17, 'restore tab 4' )
   o := HBBrwText():New( 1, 1, 20, 78, cFile, 'W/N,W/B', .F., 12 )
   o:oBrw:GetColumn( 1 ):colorBlock := {|| { 1, 1 } }
   o:nRow := 2
   Assert( At( 'x := x + 41', o:GetLine() ) == 49, 'constructor honors tab width' )
   o:aRows[ 2 ] := Replicate( Chr( 9 ), 100 ) + 'tail'
   o:SetTabWidth( 16 )
   o:oBrw:GetColumn( 1 ):colorBlock := {|| { 1, 1 } }
   o:nRow := 2
   Assert( At( 'tail', o:GetLine() ) == 1601, 'many tabs are not capped by old 256 allowance' )
   FErase( cFile )
   OutStd( 'PASS 7 code-browser tab-width checks' + hb_eol() )
   RETURN

PROCEDURE Assert( lOK, cName )
   IF ! lOK
      OutStd( 'FAIL ' + cName + hb_eol() )
      ErrorLevel( 1 )
      QUIT
   ENDIF
   RETURN

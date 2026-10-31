procedure Main()
 local a, c, nPass:=0,nFail:=0
 for each c in { 'local c := "/*"', "local c := '/*'", 'local c := [/*]', '// /*', '&& /*', '* /*', 'local c := "//" // /*', 'local c := "&&" && /*' }
 a:=HBIDE_ScanProcs('function Main()'+hb_eol()+c+hb_eol()+'return nil'+hb_eol()+'function Target()'+hb_eol()+'return nil')
 Check(Len(a)==2.and.a[2,1]=='Target'.and.a[2,3]==4,'literal or linecomment does not startblock: '+c,@nPass,@nFail)
 next
 a:=HBIDE_ScanProcs('/* function Hidden()'+hb_eol()+'procedure Hidden2() */ function Real()'+hb_eol()+'return nil')
 Check(Len(a)==1.and.a[1,1]=='Real'.and.a[1,3]==2,'realblock and declaration after closing marker',@nPass,@nFail)
 a:=HBIDE_ScanProcs('function Main() // /*'+hb_eol()+'return nil'+hb_eol()+'function Other()')
 Check(Len(a)==2.and.a[2,1]=='Other','trailinglinecomment opener ignored',@nPass,@nFail)
 a:=HBIDE_ScanProcs('#pragma begindump'+hb_eol()+'function Cnoise()'+hb_eol()+'#pragma enddump'+hb_eol()+'function Harbour()')
 Check(Len(a)==1.and.a[1,1]=='Harbour'.and.a[1,3]==4,'C dump excluded',@nPass,@nFail)
 a:=HBIDE_ScanProcs('#pragma begindump'+hb_eol()+'/* C comment'+hb_eol()+'#pragma enddump'+hb_eol()+'function Harbour()')
 Check(Len(a)==1.and.a[1,1]=='Harbour'.and.a[1,3]==4,'dump comment state stays outside Harbour lexer',@nPass,@nFail)
 a:=HBIDE_ScanProcs('CLASS Demo'+hb_eol()+' CLASS VAR shared INIT 1'+hb_eol()+' CLASS METHOD Ping()'+hb_eol()+'ENDCLASS'+hb_eol()+'METHOD FUNCTION New() CLASS Demo'+hb_eol()+'METHOD PROCEDURE Touch() CLASS Demo')
 Check(Len(a)==3,'class members are not class declarations',@nPass,@nFail)
 Check(a[2,1]=='Demo:New'.and.a[2,3]==5,'typed function method name and line',@nPass,@nFail)
 Check(a[3,1]=='Demo:Touch'.and.a[3,3]==6,'typed procedure method name and line',@nPass,@nFail)
 a:=HBIDE_ScanProcs('function Main()'+hb_eol()+'local n := a[1 /* realblock'+hb_eol()+'function Hidden()'+hb_eol()+'*/ ]'+hb_eol()+'return n'+hb_eol()+'function Target()')
 Check(Len(a)==2.and.a[2,1]=='Target'.and.a[2,3]==6,'array index multiline block excludes hidden declaration',@nPass,@nFail)
 ? 'TOTAL',nPass,'PASS',nFail,'FAIL'
 ErrorLevel(iif(nFail==0,0,1))
return
procedure Check(ok,name,nPass,nFail)
 if ok;nPass++;else;nFail++;endif
 ? iif(ok,'PASS:','FAIL:'),name
return
function HBDlgTitleColor()
return 'W+/W'
procedure DrawShadow(t,l,b,r)
 HB_SYMBOL_UNUSED(t)
 HB_SYMBOL_UNUSED(l)
 HB_SYMBOL_UNUSED(b)
 HB_SYMBOL_UNUSED(r)
return

// Original Harbour UI study inspired by FoxPro DOS. Not FoxPro or a language emulator.
#include "inkey.ch"
#include "setcurs.ch"

#ifndef FOXPRO_TEST
PROCEDURE Main()
   LOCAL h := FoxState(), k, nOld := SetCursor( SC_NONE ), cSave := SaveScreen()
   hb_cdpSelect("UTF8")
   // Display side is CP437: GTTRM maps box glyphs to UTF-8 on UTF-8
   // terminals and to ACS line drawing on 8-bit ones, so the frame looks
   // the same whatever the user locale is (verified C and C.UTF-8).
   hb_SetDispCP("EN","UTF8",.T.)
   hb_SetKeyCP("EN","UTF8")
   SetMode( 25, 80 )
   Set( _SET_EVENTMASK, INKEY_ALL + HB_INKEY_EXT )
   DO WHILE ! h[ "quit" ]
      FoxPaint( h )
      k := hb_keyStd( Inkey( 0, INKEY_ALL + HB_INKEY_EXT ) )
      FoxKey( h, k )
   ENDDO
   RestScreen(,,,, cSave )
   SetCursor( nOld )
   RETURN

#endif

FUNCTION FoxState()
   RETURN { "quit" => .F., "view" => "browse", "row" => 1, "top" => 1, "col" => 1, ;
      "menu" => 0, "item" => 1, "input" => "", "history" => { "browse", "Harbour UI study" }, ;
      "data" => { { "A100", "Acme Corp", "Ann Lee" }, { "B200", "Borland Intl", "Philippe Kahn" }, ;
      { "C300", "Fox Software", "David Fulton" }, { "D400", "FiveTech SL", "Antonio L." } }, ;
      "controls" => {}, "cx" => 8, "cy" => 7, "text" => { "* Original Harbour demonstration", "PROCEDURE Main()", "   ? 'Hello Harbour'", "RETURN" }, ;
      "prompt" => "OK", "variable" => "lAccept", "disabled" => .F., "vertical" => .F., ;
      "wins" => { "browse" => {1,0,18,60}, "screen" => {1,0,23,79}, ;
                  "program" => {1,0,21,75}, "command" => {18,51,23,77} }, ;
      "mode" => "", "drag" => NIL, ;
      "notice" => "F10 menus  F4 windows  Ctrl+F7 move  Ctrl+F8 size  Ctrl+H button  Esc close/quit" }

FUNCTION FoxMenus( h )
   LOCAL a := { { "System", { "About this study", "Help" } }, { "File", { "Browse demo data", "New screen", "Program editor", "Exit" } }, ;
      { "Edit", { "Edit current cell" } }, { "Database", { "Demo data only" } }, ;
      { "Record", { "Append", "Change", "Goto first", "Goto last", "Delete" } }, ;
      { "Program", { "Program editor" } }, { "Window", { "Browse", "Screen", "Program", "Command", "Move     Ctrl+F7", "Size     Ctrl+F8" } }, ;
      { "Run", { "About execution limits" } }, { iif( h[ "view" ] == "screen", "Screen", "Browse" ), ;
      { "Push Button   Ctrl+H", "Move cursor: arrows", "Open properties: Enter" } } }
   RETURN a

FUNCTION FoxMin( cView )
   // Minimum {height,width} per window so contents stay usable.
   DO CASE
   CASE cView=="browse";  RETURN {7,40}
   CASE cView=="screen";  RETURN {8,30}
   CASE cView=="program"; RETURN {6,20}
   ENDCASE
   RETURN {4,20} // command

FUNCTION FoxViewRows( h )
   LOCAL w := h["wins","browse"]
   RETURN w[3]-w[1]-4

FUNCTION FoxPaint( h )
   LOCAL a := FoxMenus( h ), x := 0, i, r, n, c, nMenuX := 0, w, items, nBtnW, wb, ws, wp, wc
   LOCAL cTitleAct := iif( Empty(h["mode"]), NIL, "W+/G" )
   DispBegin()
   hb_Scroll( 0, 0, 24, 79,,, "W+/B" )
   hb_DispOutAt( 0, 0, Space(80), "N/W" )
   FOR i := 1 TO Len(a)
      IF i == h[ "menu" ]; nMenuX := x; ENDIF
      hb_DispOutAt( 0, x, " " + a[i,1] + " ", iif(i==h["menu"],"N/BG","N/W") )
      x += Len(a[i,1])+2
   NEXT
   // Independent command window, like the source reference's stacked desktop.
   wc := h["wins","command"]
   FoxFrame( wc[1], wc[2], wc[3], wc[4], "Command", "W+/BG", iif(h["view"]=="command",cTitleAct,NIL) )
   n := wc[3]-wc[1]-2 // history lines that fit above the input row
   r := 0
   FOR i := Max(1,Len(h["history"])-n+1) TO Len(h["history"])
      r++
      hb_DispOutAt( wc[1]+r, wc[2]+1, PadR(Left(h["history",i],wc[4]-wc[2]-2),wc[4]-wc[2]-2), "W+/BG" )
   NEXT
   hb_DispOutAt( wc[3]-1, wc[2]+1, PadR( "> " + Right(h["input"],wc[4]-wc[2]-4),wc[4]-wc[2]-2), iif(h["view"]=="command","W+/B","W+/BG") )
   DO CASE
   CASE h["view"] == "browse"
      wb := h["wins","browse"]
      FoxFrame( wb[1], wb[2], wb[3], wb[4], "CUST", "W+/BG", cTitleAct )
      hb_DispOutAt(wb[1]+1,wb[2]+1,"Cno    Company                    Contact", "W+/BG")
      hb_DispOutAt(wb[1]+2,wb[2]+1,Replicate(hb_UTF8ToStr("─"),Min(59,wb[4]-wb[2]-1)),"W+/BG")
      FOR r := 0 TO FoxViewRows(h)-1
         n := h["top"]+r
         IF n<=Len(h["data"])
            c := PadR(h["data",n,1],6)+" "+PadR(h["data",n,2],25)+" "+PadR(h["data",n,3],26)
            hb_DispOutAt(wb[1]+3+r,wb[2]+1,c,iif(n==h["row"],"W+/B","W+/BG"))
         ENDIF
      NEXT
      FOR r := wb[1]+1 TO wb[3]-2
         hb_DispOutAt(r,wb[2]+7,hb_UTF8ToStr("│"),"W/BG"); hb_DispOutAt(r,wb[2]+33,hb_UTF8ToStr("│"),"W/BG")
      NEXT
      FoxScroll(wb[1]+1,wb[3]-1,wb[4],h["row"],Len(h["data"]))
      hb_DispOutAt(wb[3],wb[2]+3,"Record "+hb_ntos(h["row"])+"/"+hb_ntos(Len(h["data"]))+"  Col "+hb_ntos(h["col"]),"N/W")
   CASE h["view"] == "screen"
      ws := h["wins","screen"]
      FoxFrame(ws[1],ws[2],ws[3],ws[4],"DEMO.SCX (visual study)","W+/B", cTitleAct)
      hb_DispOutAt(ws[1]+1,ws[2]+1,PadR("R: "+hb_ntos(h["cy"])+" C: "+hb_ntos(h["cx"])+" | Move | Ctrl+H Push Button",ws[4]-ws[2]-2),"W+/BG")
      FOR EACH c IN h["controls"]
         nBtnW := Len(c[3])+4
         // Controls fully outside the visible canvas are not painted; the
         // model keeps their coordinates.
         IF c[1]>=ws[1]+2 .AND. c[1]<=ws[3]-2 .AND. c[2]>=ws[2]+1 .AND. c[2]+nBtnW-1<=ws[4]-2
            // shadow first (button face paints over the overlap), same "dark
            // cell" convention as FoxFrame's offset shadow
            IF c[1]+1 <= ws[3]-1
               hb_DispOutAt(c[1]+1,c[2]+1,Space(Min(nBtnW,ws[4]-c[2])),"N/N")
            ENDIF
            IF c[2]+nBtnW <= ws[4]-1
               hb_DispOutAt(c[1],c[2]+nBtnW," ","N/N")
            ENDIF
            hb_DispOutAt(c[1],c[2],"< "+c[3]+" >",iif(c[4],"N/G","W+/G"))
         ENDIF
      NEXT
      IF AScan(h["controls"],{|o|o[1]==h["cy"] .AND. o[2]==h["cx"]})==0
         hb_DispOutAt(h["cy"],h["cx"],"_","GR+/B")
      ENDIF
      // Fixed canvas has no scroll range. No decorative scrollbar.
   CASE h["view"] == "program"
      wp := h["wins","program"]
      FoxFrame(wp[1],wp[2],wp[3],wp[4],"T1.PRG (memory only)","W+/B", cTitleAct)
      FOR i := 1 TO Min(wp[3]-wp[1]-2,Len(h["text"]))
         hb_DispOutAt(wp[1]+i,wp[2]+1,PadR(Left(h["text",i],wp[4]-wp[2]-2),wp[4]-wp[2]-2),iif(i==h["row"],"W+/BG","W+/B"))
      NEXT
      hb_DispOutAt(wp[3],wp[2]+2,"Line "+hb_ntos(h["row"])+" - edits are in memory; no execution", "N/W")
   ENDCASE
   hb_DispOutAt(24,0,PadR(Left(h["notice"],80),80),"N/W")
   IF h["menu"]>0
      items := a[h["menu"],2]; w := 0
      FOR EACH c IN items; w:=Max(w,Len(c)); NEXT
      nMenuX := Min(nMenuX,77-w)
      FoxFrame(1,nMenuX,Len(items)+2,nMenuX+w+3,"","N/W")
      FOR i := 1 TO Len(items)
         hb_DispOutAt(1+i,nMenuX+1,PadR(items[i],w+2),iif(i==h["item"],"N/BG","N/W"))
      NEXT
   ENDIF
   DispEnd()
   RETURN NIL

FUNCTION FoxFrame( t,l,b,r,title,color,cTitleColor )
   IF cTitleColor == NIL; cTitleColor := "GR+/W"; ENDIF
   hb_Scroll(t+1,l+1,Min(24,b+1),Min(79,r+2),,,"N/N")
   hb_Scroll(t,l,b,r,,,color)
   hb_DispOutAt(t,l,Space(r-l+1),"N/W")
   hb_DispOutAt(b,l,Space(r-l+1),"N/W")

   hb_DispOutAt(t,l+Max(2,Int((r-l-Len(title))/2)),title,cTitleColor)



   RETURN NIL

FUNCTION FoxScroll(t,b,x,pos,total)
   LOCAL r, thumb := t+1+Int((b-t-2)*Max(0,pos-1)/Max(1,total-1))
   FOR r:=t TO b; hb_DispOutAt(r,x,hb_UTF8ToStr("░"),"GR+/W"); NEXT
   FoxGlyph(t,x,hb_UTF8ToStr("▲"),"GR+/W"); FoxGlyph(b,x,hb_UTF8ToStr("▼"),"GR+/W")
   FoxGlyph(Min(b-1,thumb),x,hb_UTF8ToStr("◆"),"GR+/W")
   RETURN NIL

FUNCTION FoxModeNotice( h )
   h["notice"] := iif( h["mode"]=="move", "Move window: arrows place it, Enter/Esc finishes", ;
      iif( h["mode"]=="size", "Size window: arrows stretch lower-right corner, Enter/Esc finishes", ;
      "F10 menus  F4 windows  Ctrl+F7 move  Ctrl+F8 size  Ctrl+H button  Esc close/quit" ) )
   RETURN NIL

FUNCTION FoxClampView( h )
   LOCAL w := h["wins",h["view"]], c
   DO CASE
   CASE h["view"]=="screen"
      // Only the placement cursor follows the canvas. Controls keep their
      // stored coordinates: shrinking crops the view, enlarging shows them
      // again at their original position (FoxPro does not rewrite the SCX).
      h["cy"]:=Max(w[1]+2,Min(w[3]-2,h["cy"]))
      h["cx"]:=Max(w[2]+1,Min(Min(w[4]-2,w[2]+60),h["cx"]))
   CASE h["view"]=="browse"
      h["top"]:=Max(1,Min(h["top"],h["row"]))
      IF h["row"]>=h["top"]+FoxViewRows(h);h["top"]:=h["row"]-FoxViewRows(h)+1;ENDIF
   CASE h["view"]=="program"
      h["row"]:=Max(1,Min(Len(h["text"]),h["row"]))
   ENDCASE
   RETURN NIL

FUNCTION FoxKey(h,k)
   LOCAL a:=FoxMenus(h), c, i, n, nMenu:=0, w, m, hh, ww, oldT, oldL, cc
   DO CASE
   CASE k==K_ALT_S; nMenu:=1
   CASE k==K_ALT_F; nMenu:=2
   CASE k==K_ALT_E; nMenu:=3
   CASE k==K_ALT_D; nMenu:=4
   CASE k==K_ALT_R; nMenu:=5
   CASE k==K_ALT_P; nMenu:=6
   CASE k==K_ALT_W; nMenu:=7
   CASE k==K_ALT_U; nMenu:=8
   ENDCASE
   IF nMenu>0; h["menu"]:=nMenu;h["item"]:=1;RETURN NIL; ENDIF
   IF h["menu"]>0
      DO CASE
      CASE k==K_ESC;h["menu"]:=0
      CASE k==K_DOWN;h["item"]:=h["item"]%Len(a[h["menu"],2])+1
      CASE k==K_UP;h["item"]:=iif(h["item"]==1,Len(a[h["menu"],2]),h["item"]-1)
      CASE k==K_RIGHT;h["menu"]:=h["menu"]%Len(a)+1;h["item"]:=1
      CASE k==K_LEFT;h["menu"]:=iif(h["menu"]==1,Len(a),h["menu"]-1);h["item"]:=1
      CASE k==K_ENTER
         n:=h["menu"];i:=h["item"];h["menu"]:=0;FoxAction(h,n,i)
      ENDCASE
      RETURN NIL
   ENDIF
   // Move/size mode owns the keyboard until Enter/Esc.
   IF !Empty(h["mode"])
      w:=h["wins",h["view"]]; m:=FoxMin(h["view"])
      hh:=w[3]-w[1]+1; ww:=w[4]-w[2]+1
      DO CASE
      CASE k==K_ENTER .OR. k==K_ESC; h["mode"]:=""
      CASE h["mode"]=="move"
         oldT:=w[1]; oldL:=w[2]
         DO CASE
         CASE k==K_UP    .AND. w[1]>1;   w[1]--; w[3]--
         CASE k==K_DOWN  .AND. w[3]<23;  w[1]++; w[3]++
         CASE k==K_LEFT  .AND. w[2]>0;   w[2]--; w[4]--
         CASE k==K_RIGHT .AND. w[4]<79;  w[2]++; w[4]++
         ENDCASE
         IF h["view"]=="screen" .AND. (w[1]!=oldT .OR. w[2]!=oldL)
            FOR EACH cc IN h["controls"]
               cc[1]+=w[1]-oldT; cc[2]+=w[2]-oldL
            NEXT
            h["cy"]+=w[1]-oldT; h["cx"]+=w[2]-oldL
         ENDIF
      CASE h["mode"]=="size"
         DO CASE
         CASE k==K_UP    .AND. hh>m[1];  w[3]--
         CASE k==K_DOWN  .AND. w[3]<23;  w[3]++
         CASE k==K_LEFT  .AND. ww>m[2];  w[4]--
         CASE k==K_RIGHT .AND. w[4]<79;  w[4]++
         ENDCASE
         FoxClampView(h)
      ENDCASE
      FoxModeNotice(h)
      RETURN NIL
   ENDIF
   DO CASE
   CASE k==K_F10;h["menu"]:=1;h["item"]:=1
   CASE k==K_ESC
      IF h["view"]=="browse";h["quit"]:=.T.;ELSE;h["view"]:="browse";h["row"]:=1;ENDIF
   CASE k==K_F4
      a:={"browse","screen","program","command"};n:=AScan(a,h["view"]);h["view"]:=a[n%4+1];h["row"]:=1
   CASE k==K_CTRL_F7
      h["mode"]:="move"; FoxModeNotice(h)
   CASE k==K_CTRL_F8
      h["mode"]:="size"; FoxModeNotice(h)
   CASE k==K_CTRL_H .AND. h["view"]=="screen"
      FoxButton(h)
   CASE k==K_LBUTTONDOWN
      w:=h["wins",h["view"]]
      IF MRow()==w[3] .AND. MCol()==w[4]
         h["drag"]:={"size",0,0}
      ELSEIF MRow()==w[1] .AND. MCol()>=w[2] .AND. MCol()<=w[4]
         h["drag"]:={"move",MRow()-w[1],MCol()-w[2]}
      ELSEIF h["view"]=="browse" .AND. MCol()==w[4]
         IF MRow()==w[1]+1;h["row"]:=Max(1,h["row"]-1)
         ELSEIF MRow()==w[3]-1;h["row"]:=Min(Len(h["data"]),h["row"]+1)
         ELSE;h["row"]:=Max(1,Min(Len(h["data"]),1+Int((MRow()-(w[1]+2))*Max(0,Len(h["data"])-1)/Max(1,(w[3]-2)-(w[1]+2)))))
         ENDIF
         h["top"]:=Max(1,Min(h["top"],h["row"]))
         IF h["row"]>=h["top"]+FoxViewRows(h);h["top"]:=h["row"]-FoxViewRows(h)+1;ENDIF
      ENDIF
   CASE k==K_MOUSEMOVE .AND. h["drag"]!=NIL
      w:=h["wins",h["view"]]
      IF h["drag",1]=="move"
         hh:=w[3]-w[1]; ww:=w[4]-w[2]
         oldT:=w[1]; oldL:=w[2]
         w[1]:=Max(1,Min(23-hh,MRow()-h["drag",2])); w[3]:=w[1]+hh
         w[2]:=Max(0,Min(79-ww,MCol()-h["drag",3])); w[4]:=w[2]+ww
         IF h["view"]=="screen" .AND. (w[1]!=oldT .OR. w[2]!=oldL)
            FOR EACH cc IN h["controls"]
               cc[1]+=w[1]-oldT; cc[2]+=w[2]-oldL
            NEXT
            h["cy"]+=w[1]-oldT; h["cx"]+=w[2]-oldL
         ENDIF
      ELSE
         m:=FoxMin(h["view"])
         w[3]:=Max(w[1]+m[1]-1,Min(23,MRow())); w[4]:=Max(w[2]+m[2]-1,Min(79,MCol()))
         FoxClampView(h)
      ENDIF
   CASE k==K_LBUTTONUP
      h["drag"]:=NIL
   CASE h["view"]=="browse"
      DO CASE
      CASE k==K_DOWN;h["row"]:=Min(Len(h["data"]),h["row"]+1)
      CASE k==K_UP;h["row"]:=Max(1,h["row"]-1)
      CASE k==K_PGDN;h["row"]:=Min(Len(h["data"]),h["row"]+FoxViewRows(h))
      CASE k==K_PGUP;h["row"]:=Max(1,h["row"]-FoxViewRows(h))
      CASE k==K_HOME;h["row"]:=1
      CASE k==K_END;h["row"]:=Len(h["data"])
      CASE k==K_MWBACKWARD;h["row"]:=Min(Len(h["data"]),h["row"]+1)
      CASE k==K_MWFORWARD;h["row"]:=Max(1,h["row"]-1)
      CASE k==K_RIGHT;h["col"]:=Min(3,h["col"]+1)
      CASE k==K_LEFT;h["col"]:=Max(1,h["col"]-1)
      CASE k==K_ENTER;FoxEditCell(h)
      ENDCASE
      h["top"]:=Max(1,Min(h["top"],h["row"]))
      IF h["row"]>=h["top"]+FoxViewRows(h);h["top"]:=h["row"]-FoxViewRows(h)+1;ENDIF
   CASE h["view"]=="screen"
      w:=h["wins","screen"]
      DO CASE
      CASE k==K_DOWN;h["cy"]:=Min(w[3]-2,h["cy"]+1)
      CASE k==K_UP;h["cy"]:=Max(w[1]+2,h["cy"]-1)
      CASE k==K_LEFT;h["cx"]:=Max(w[2]+1,h["cx"]-1)
      CASE k==K_RIGHT;h["cx"]:=Min(Min(w[4]-2,w[2]+60),h["cx"]+1)
      CASE k==K_ENTER;FoxButton(h)
      ENDCASE
   CASE h["view"]=="program"
      w:=h["wins","program"]
      n:=h["row"]
      DO CASE
      CASE k==K_UP;h["row"]:=Max(1,n-1)
      CASE k==K_DOWN;h["row"]:=Min(Len(h["text"]),n+1)
      CASE k==K_ENTER .AND. Len(h["text"])<w[3]-w[1]-2;AAdd(h["text"],"");h["row"]:=Len(h["text"])
      CASE k==K_BS;h["text",n]:=Left(h["text",n],Max(0,Len(h["text",n])-1))
      CASE k>=32 .AND. k<=126;h["text",n]+=Chr(k)
      ENDCASE
   CASE h["view"]=="command"
      DO CASE
      CASE k==K_BS;h["input"]:=Left(h["input"],Max(0,Len(h["input"])-1))
      CASE k==K_ENTER
         c:=Lower(AllTrim(h["input"]));AAdd(h["history"],c);h["input"]:=""
         DO CASE
         CASE c=="browse";h["view"]:="browse";h["row"]:=1
         CASE c=="screen";h["view"]:="screen"
         CASE c=="modify command";h["view"]:="program";h["row"]:=1
         OTHERWISE;h["notice"]:="Demo commands: browse, screen, modify command. No code is executed."
         ENDCASE
      CASE k>=32 .AND. k<=126;h["input"]+=Chr(k)
      ENDCASE
   ENDCASE
   RETURN NIL

FUNCTION FoxAction(h,m,i)
   DO CASE
   CASE m==1
      FoxNotice(iif(i==1,"Original Harbour UI study inspired by FoxPro DOS.","F10 menus; arrows/Enter; F4 windows; Ctrl+F7 move; Ctrl+F8 size; Esc returns.")+ ;
         " No FoxPro engine, SCX format or code execution.")
   CASE m==2 .AND. i==4;h["quit"]:=.T.
   CASE m==7 .AND. i==5
      h["mode"]:="move"; FoxModeNotice(h)
   CASE m==7 .AND. i==6
      h["mode"]:="size"; FoxModeNotice(h)
   CASE m==2 .OR. m==7
      IF m==7;h["view"]:={"browse","screen","program","command"}[i]
      ELSE;h["view"]:={"browse","screen","program"}[i];ENDIF
      h["row"]:=1
   CASE m==3;IF h["view"]=="browse";FoxEditCell(h);ELSE;FoxNotice("Cell editing is available in Browse.");ENDIF
   CASE m==4;FoxNotice("In-memory demo records only. No database engine or file is opened.")
   CASE m==5
      h["view"]:="browse"
      DO CASE
      CASE i==1;AAdd(h["data"],{"NEW","New company","Contact"});h["row"]:=Len(h["data"])
      CASE i==2;FoxEditCell(h)
      CASE i==3;h["row"]:=1
      CASE i==4;h["row"]:=Len(h["data"])
      CASE i==5
         IF Len(h["data"])>1;ADel(h["data"],h["row"]);ASize(h["data"],Len(h["data"])-1);h["row"]:=Min(h["row"],Len(h["data"]));ENDIF
      ENDCASE
   CASE m==6;h["view"]:="program";h["row"]:=1
   CASE m==8;FoxNotice("UI demonstration only. Program text is never executed or written to disk.")
   CASE m==9
      IF i==1;h["view"]:="screen";FoxButton(h)
      ELSE;FoxNotice("Screen: arrows move placement cursor; Ctrl+H or Enter adds a button.");ENDIF
   ENDCASE
   h["top"]:=Max(1,Min(h["top"],h["row"]))
   IF h["row"]>=h["top"]+FoxViewRows(h);h["top"]:=h["row"]-FoxViewRows(h)+1;ENDIF
   RETURN NIL

FUNCTION FoxEditCell(h)
   LOCAL c:=FoxInput("Edit cell "+hb_ntos(h["col"]),h["data",h["row"],h["col"]])
   IF c!=NIL;h["data",h["row"],h["col"]]:=c;ENDIF
   RETURN NIL

FUNCTION FoxInput(title,initial)
   LOCAL save:=SaveScreen(),c:=initial,k
   DO WHILE .T.
      FoxFrame(8,10,14,68,title,"W+/RB")
      hb_DispOutAt(10,12,PadR(Right(c,53),53),"W+/BG")
      hb_DispOutAt(12,12,"Enter accepts   Esc cancels   Backspace deletes", "W+/RB")
      k:=hb_keyStd(Inkey(0,INKEY_ALL+HB_INKEY_EXT))
      IF k==K_ESC;c:=NIL;EXIT;ENDIF
      IF k==K_ENTER;EXIT;ENDIF
      IF k==K_BS;c:=Left(c,Max(0,Len(c)-1))
      ELSEIF k>=32 .AND. k<=126;c+=Chr(k);ENDIF
   ENDDO
   RestScreen(,,,,save)
   RETURN c

FUNCTION FoxBox(t,l,b,r,color)
   // Per-cell border writes: a LONG string of multibyte UTF-8 glyphs can
   // split one character across an internal GT write boundary and paint
   // replacement cells mid-border (observed in PTY capture). One cell per
   // call is the safe path in this GT mode.
   LOCAL rr, cc
   hb_Scroll(t,l,b,r,,,color)
   FOR cc:=l TO r
      hb_DispOutAt(t,cc,hb_UTF8ToStr(iif(cc==l,"┌",iif(cc==r,"┐","─"))),color)
      hb_DispOutAt(b,cc,hb_UTF8ToStr(iif(cc==l,"└",iif(cc==r,"┘","─"))),color)
   NEXT
   FOR rr:=t+1 TO b-1
      hb_DispOutAt(rr,l,hb_UTF8ToStr("│"),color)
      hb_DispOutAt(rr,r,hb_UTF8ToStr("│"),color)
   NEXT
   RETURN NIL

FUNCTION FoxButton(h)
   LOCAL save:=SaveScreen(),focus:=1,k,cPrompt:=h["prompt"],cVar:=h["variable"],disabled:=h["disabled"],vertical:=h["vertical"]
   DO WHILE .T.
      hb_Scroll(4,8,21,73,,,"N/N")
      hb_Scroll(3,7,20,71,,,"W+/RB")
      FoxBox(3,7,20,71,"W+/RB")
      hb_DispOutAt(5,9,"Push Button Prompts:","W+/RB")
      hb_DispOutAt(7,10,PadR(Left(cPrompt,20),20),iif(focus==1,"W+/BG","W+/RB"))
      hb_DispOutAt(5,36,"Single button - study subset", "W+/RB")
      FoxBox(6,9,15,32,"W+/RB")
      FoxBox(9,35,11,68,"W+/RB")
      FoxBox(13,35,15,68,"W+/RB")
      hb_DispOutAt(8,36,"Variable:","W+/RB")
      hb_DispOutAt(10,36,PadR(Left(cVar,28),28),iif(focus==2,"W+/BG","W+/RB"))
      hb_DispOutAt(12,36,"Options:","W+/RB")
      hb_DispOutAt(14,36,iif(disabled,"[X] Dimmed preview","[ ] Dimmed preview"),iif(focus==3,"W+/BG","W+/RB"))
      hb_DispOutAt(16,10,"Tab fields; type prompt/variable; Space toggles", "W+/RB")
      hb_DispOutAt(19,25,Space(6),"N/N")
      hb_DispOutAt(18,30," ","N/N")
      hb_DispOutAt(19,41,Space(10),"N/N")
      hb_DispOutAt(18,50," ","N/N")
      hb_DispOutAt(18,24,"< OK >",iif(focus==4,"W+/G","W/G"))
      hb_DispOutAt(18,40,"< Cancel >",iif(focus==5,"W+/G","W/G"))
      k:=hb_keyStd(Inkey(0,INKEY_ALL+HB_INKEY_EXT))
      DO CASE
      CASE k==K_ESC .OR. (k==K_ENTER .AND. focus==5);EXIT
      CASE k==K_TAB;focus:=focus%5+1
      CASE k==K_SH_TAB;focus:=iif(focus==1,5,focus-1)
      CASE k==K_ENTER
         h["prompt"]:=cPrompt;h["variable"]:=cVar;h["disabled"]:=disabled;h["vertical"]:=vertical
         AAdd(h["controls"],{h["cy"],h["cx"],cPrompt,disabled,cVar,vertical});EXIT
      CASE focus==3 .AND. k==K_SPACE;disabled:=!disabled
      CASE focus<=2 .AND. k==K_BS
         IF focus==1;cPrompt:=Left(cPrompt,Max(0,Len(cPrompt)-1));ELSE;cVar:=Left(cVar,Max(0,Len(cVar)-1));ENDIF
      CASE focus<=2 .AND. k>=32 .AND. k<=126
         IF focus==1
            IF Len(cPrompt)<18
               cPrompt+=Chr(k)
            ENDIF
         ELSE
            IF Len(cVar)<28
               cVar+=Chr(k)
            ENDIF
         ENDIF
      ENDCASE
   ENDDO
   RestScreen(,,,,save)
   RETURN NIL

FUNCTION FoxNotice(c)
   LOCAL save:=SaveScreen(),i
   FoxFrame(8,4,15,74,"Study notes","W+/RB")
   FOR i:=1 TO 4;hb_DispOutAt(9+i,6,SubStr(c,(i-1)*66+1,66),"W+/RB");NEXT
   hb_DispOutAt(14,6,"Press any key", "W+/RB");Inkey(0)
   RestScreen(,,,,save)
   RETURN NIL

FUNCTION FoxGlyph(r,c,text,color)
   hb_DispOutAt(r,c,text,color)
   RETURN NIL

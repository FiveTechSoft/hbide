# Resize repaint defect - debug state (2026-10-25, WIP, not for demo)

Branch `mc-clamp-wip` only. Clamp deploy is HELD pending review.

## Finding (verified, reproducible)

With the instrumented v3 build, after a terminal shrink (180x60 -> 140x44,
SIGWINCH, Configuration dialog open):

- `MCDlgResizeRedraw` runs to COMPLETION with no Harbour error: stage
  markers reach `stage dispend`; the clamp shift is correct and
  idempotent (see log below); face refill, shadow, Refresh, says and
  all 23 GETs are repainted in Harbour's virtual screen.
- And yet the process emits ZERO bytes to the terminal after SIGWINCH:
  strace shows no `write(1, ...)` at all post-resize. Later keys
  (Enter, Q) also produce no output. The process stays alive, sleeping
  in `select` (state S, wchan do_select) - i.e. it is not blocked on
  write and not crashed.

## Interpretation - HYPOTHESIS, not proven cause

Harbour paints into its virtual screen and DispEnd completes, but the
bytes never reach the pty. The wedge sits somewhere between the
virtual-screen flush and gttrm's write(1) - attribution to gttrm is a
hypothesis until a minimal reproduction isolates it (an RTL-layer
question, out of mc/ scope for now). The live xterm.js corruption seen
earlier (half-painted dialog, stale remnants) is consistent with the
terminal replaying an older stream while the app went silent.

## clamp.log from the decisive run (instrumented build, pty)

```
redraw MaxRow=43 MaxCol=139 dlg=19,57,40,121 nMaxB=39 nMaxR=137 d=-1,0
stage shift
redraw MaxRow=43 MaxCol=139 dlg=18,57,39,121 nMaxB=39 nMaxR=137 d=0,0
stage shift
stage face
stage refresh
stage says
stage controls
ctl GET
ctl GET
ctl GET
ctl GET
ctl GET
ctl GET
ctl GET
ctl GET
ctl GET
ctl GET
ctl GET
ctl GET
ctl GET
ctl GET
ctl GET
ctl GET
ctl GET
ctl GET
ctl GET
ctl GET
ctl GET
ctl GET
ctl GET
stage dispend
```

## strace excerpt (same run; fd 5 = /tmp/clamp.log, fd 1 = pty)

```
... write(1, dialog repaint during OPEN) ...
--- SIGWINCH ---
write(5, "redraw MaxRow=43 ...")      <- clamp computed, shift executed
write(5, "stage shift" ... "stage dispend", all controls logged)
(no write(1) ever again)
read(0, "\r")   read(0, "Q")          <- keys received, no response
```

## Instrumentation used (diff vs this branch's mc/mc.prg)

Reproduces the instrumented build: apply to mc/mc.prg of this branch,
build with hbmk2, run under a pty, shrink the pty, watch /tmp/clamp.log
and strace -e trace=write,read. Stage markers + BEGIN SEQUENCE/RECOVER
error capture around face/refresh/says/controls; MCClampLog appends to
/tmp/clamp.log.

```diff
--- /tmp/mc_wip_base.prg	2026-10-25 11:42:09.047011251 +0100
+++ mc/mc.prg	2026-10-25 11:35:41.571011251 +0100
@@ -4537,6 +4537,10 @@
       nDCol := Min( 0, nMaxR - oDlg:nRight )
       nDCol := Max( nDCol, -oDlg:nLeft )
    endif
+   MCClampLog( "redraw MaxRow=" + hb_ntos( MaxRow() ) + " MaxCol=" + hb_ntos( MaxCol() ) + ;
+      " dlg=" + hb_ntos( oDlg:nTop ) + "," + hb_ntos( oDlg:nLeft ) + "," + hb_ntos( oDlg:nBottom ) + "," + hb_ntos( oDlg:nRight ) + ;
+      " nMaxB=" + hb_ntos( nMaxB ) + " nMaxR=" + hb_ntos( nMaxR ) + " d=" + hb_ntos( nDRow ) + "," + hb_ntos( nDCol ) )
+   MCClampLog( "stage shift" )
    if nDRow != 0 .or. nDCol != 0
       nOT := oDlg:nTop
       nOL := oDlg:nLeft
@@ -4548,16 +4552,22 @@
       oDlg:nRight  += nDCol
       MCDlgShiftControls( oDlg, nDRow, nDCol )
    endif
+   MCClampLog( "stage face" )
+   BEGIN SEQUENCE
    hb_Scroll( oDlg:nTop, oDlg:nLeft, oDlg:nBottom, oDlg:nRight,,, oDlg:cColor )
    if oDlg:lShadow
       hb_Shadow( oDlg:nTop, oDlg:nLeft, oDlg:nBottom, oDlg:nRight )
    endif
+   MCClampLog( "stage refresh" )
    oDlg:Refresh()
+   MCClampLog( "stage says" )
    for each a in s_aDlgSays
       oDlg:Say( a[ 1 ], a[ 2 ], a[ 3 ] )
    next
+   MCClampLog( "stage controls" )
    if HB_ISARRAY( oDlg:GetList )
       for each o in oDlg:GetList
+         MCClampLog( "ctl " + o:ClassName() )
          if o:Control != NIL
             o:Control:Display()
          else
@@ -4565,6 +4575,12 @@
          endif
       next
    endif
+   MCClampLog( "stage dispend" )
+   RECOVER USING e
+      MCClampLog( "ERROR " + e:ClassName() + " " + e:Description + " " + e:Operation + ;
+                  " sub=" + If( HB_ISSTRING( e:SubSystem ), e:SubSystem, "?" ) + ;
+                  " code=" + hb_ntos( e:GenCode ) + " os=" + hb_ntos( e:OsCode ) )
+   END SEQUENCE
    DispEnd()
    if GetActive() != NIL .and. GetActive():Control != NIL
       GetActive():Control:setFocus()
@@ -4640,6 +4656,22 @@
 
 return nil
 //-----------------------------------------------------------------------------------------//
+
+static function MCClampLog( cLine )
+
+   local nH := FOpen( "/tmp/clamp.log", 1 )  // FO_WRITE
+
+   if nH == -1
+      nH := FCreate( "/tmp/clamp.log" )
+   endif
+   if nH != -1
+      FSeek( nH, 0, 2 )  // FS_END
+      FWrite( nH, cLine + hb_eol() )
+      FClose( nH )
+   endif
+
+return nil
+//-----------------------------------------------------------------------------------------//
 // Like oDlg:Say() but records the line so MCDlgResizeRedraw can replay it.
 function MCDlgSay( oDlg, nRow, nCol, cLine )
 
```

## Open questions for the next session

1. Minimal repro: does a bare Harbour PRG (ScrollRegion + DispBegin/
   DispEnd + SIGWINCH, no mc code) wedge gttrm output the same way?
2. If yes, the defect is in gttrm/RTL (resize flag vs output path);
   report upstream with the repro.
3. The PTY-harness "clean pass" earlier was a misread: pyte also showed
   offset corruption. Never trust harness-only layout claims; verify in
   the real browser path.

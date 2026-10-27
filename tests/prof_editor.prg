// Profiler run of the editor hot paths. Needs a Harbour built with -DHB_USE_PROFILER
// (HB_USER_CFLAGS=-DHB_USE_PROFILER; stock builds define HB_NO_PROFILER).
// hbmk2 prof_editor.prg editor.prg recovery.prg -i<hbide dir>  -> /tmp/hbide-prof-editor.txt
// Ticks are inclusive of callees, not wall-clock.
// Wall-clock micro-benchmark of the editor hot paths (Linux PTY).
#include "hbclass.ch"
#include "inkey.ch"

function HBIDE_MsgAlert( cText )
   HB_SYMBOL_UNUSED( cText )
return 1

static function BuildBuffer( nLines )
   // O(n): build a 100-line block once, then replicate
   local cBlock := "", i
   for i := 1 to 100
      cBlock += "local nValue" + hb_ntos( i ) + " := " + hb_ntos( i ) + " + 1  // filler" + hb_eol()
   next
return Replicate( cBlock, Int( nLines / 100 ) ) + Left( cBlock, 0 )

procedure Main()
   local oProf

   local aSizes := { 100, 1000, 5000, 20000 }
   local nSize, oE, i, t0, nMs, cOut := ""
   oProf := HBProfile():new()
   __SetProfiler( .T. )

   for each nSize in aSizes
      oE := HBSrcEdit():New( BuildBuffer( nSize ), 2, 1, 22, 78, .T. )
      oE:GoTo( 1, 5 )
      t0 := hb_milliseconds()
      for i := 1 to 100
         oE:Edit( Asc( "x" ) )
      next
      nMs := hb_milliseconds() - t0
      cOut += "type " + hb_ntos( nSize ) + " lines: " + hb_ntos( nMs ) + ;
              " ms / 100 chars = " + hb_ntos( nMs / 100 ) + " ms/char" + hb_eol()
      hb_MemoWrit( "/tmp/hbide-bench-editor.txt", cOut )

      t0 := hb_milliseconds()
      for i := 1 to 100
         oE:Edit( K_DOWN )
      next
      nMs := hb_milliseconds() - t0
      cOut += "nav  " + hb_ntos( nSize ) + " lines: " + hb_ntos( nMs ) + " ms / 100 keys" + hb_eol()
      hb_MemoWrit( "/tmp/hbide-bench-editor.txt", cOut )

      // in-view nav: alternate K_DOWN/K_UP inside the visible page (no
      // scrolling, so GoTo triggers no full Display) — isolates the cost
      // of the per-key repaint tail
      oE:GoTo( 10, 5 )
      t0 := hb_milliseconds()
      for i := 1 to 50
         oE:Edit( K_DOWN )
         oE:Edit( K_UP )
      next
      nMs := hb_milliseconds() - t0
      cOut += "nav-in-view " + hb_ntos( nSize ) + " lines: " + hb_ntos( nMs ) + " ms / 100 keys" + hb_eol()
      hb_MemoWrit( "/tmp/hbide-bench-editor.txt", cOut )
   next

   __SetProfiler( .F. )
   oProf:gather()
   hb_MemoWrit( "/tmp/hbide-prof-editor.txt", HBProfileReportToString():new( oProf:timeSort() ):generate( {| o | o:nTicks > 0 }, 40 ) )

return

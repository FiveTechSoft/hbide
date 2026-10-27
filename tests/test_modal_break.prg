// Modal counter cleanup: a Break out of HBWindow:Activate must leave HBIDE_Modal() at 0.
// Build: hbmk2 tests/test_modal_break.prg hbwindow.prg hbgetu.prg hbbutton.prg hbmenu.prg -gttrm; run under a pty (script -qc ./test_modal_break /dev/null)
// Result file: /tmp/hbide-modal-break.txt (expect: recovered;count_after_break=0;count_after_second=0)
#include "inkey.ch"
STATIC s_n := 0
FUNCTION HBIDE_Modal( nDelta )
   IF HB_ISNUMERIC( nDelta )
      s_n := Max( 0, s_n + nDelta )
   ENDIF
RETURN s_n

PROCEDURE Main()
   LOCAL oDlg, GetList := {}, lDummy := .F., cRes := "", bOld
   SetMode( 25, 80 )
   oDlg := HBWindow():Dialog( "T", 30, 7, "W+/W" )
   @ oDlg:nBottom - 2, oDlg:nLeft + 3 GET lDummy PUSHBUTTON CAPTION " OK " STATE { || Break( "boom" ) }
   hb_keyPut( K_RETURN )
   BEGIN SEQUENCE
      oDlg:Activate( GetList )
   RECOVER
      cRes += "recovered;"
   END SEQUENCE
   cRes += "count_after_break=" + hb_ntos( HBIDE_Modal() ) + ";"
   // second modal, normal exit
   GetList := {}
   oDlg := HBWindow():Dialog( "T2", 30, 7, "W+/W" )
   @ oDlg:nBottom - 2, oDlg:nLeft + 3 GET lDummy PUSHBUTTON CAPTION " OK " STATE { || oDlg:End() }
   hb_keyPut( K_RETURN )
   oDlg:Activate( GetList )
   cRes += "count_after_second=" + hb_ntos( HBIDE_Modal() )
   hb_MemoWrit( "/tmp/hbide-modal-break.txt", cRes )
RETURN

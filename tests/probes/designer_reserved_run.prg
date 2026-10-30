#include "inkey.ch"
#include "error.ch"
PROCEDURE Main()
   LOCAL lResult,oError,bOld:=ErrorBlock({|e|Break(e)})
   hb_keyPut(K_ESC)
   BEGIN SEQUENCE
      lResult:=Dlg_Reserved()
      IF !HB_IsLogical(lResult).or.lResult
         ? "FAIL unexpected dialog result"
         ErrorLevel(1)
      ELSE
         ? "PASS reserved dialog Esc returned false"
      ENDIF
   RECOVER USING oError
      ? "FAIL generated dialog",oError:Description,oError:Operation
      ErrorLevel(1)
   END SEQUENCE
   ErrorBlock(bOld)
   RETURN

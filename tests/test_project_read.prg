// Fixtures supplied by a non-root Python harness; unreadable is not empty.
PROCEDURE Main( cDenied, cEmpty )
   LOCAL oP := HBIDEProject():New()
   IF oP:Open( cDenied )
      ? "FAIL unreadable HBP accepted as empty project"
      ErrorLevel( 1 )
      RETURN
   ENDIF
   IF ! Empty( oP:cFile ) .OR. ! Empty( oP:cOriginal ) .OR. Empty( oP:cError )
      ? "FAIL unreadable HBP leaves selected project state"
      ErrorLevel( 1 )
      RETURN
   ENDIF
   IF ! oP:Open( cEmpty ) .OR. ! Empty( oP:cOriginal )
      ? "FAIL valid empty HBP rejected"
      ErrorLevel( 1 )
      RETURN
   ENDIF
   ? "PASS unreadable HBP rejected distinctly from valid empty HBP"
   RETURN

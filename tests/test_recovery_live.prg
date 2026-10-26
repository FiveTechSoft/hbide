#include "fileio.ch"
procedure Main( cMode )
   local a
   if cMode == "hold"
      hb_SetEnv( "HBIDE_RECOVERY_SESSION", "owner" )
      if ! HBIDE_RecoveryWrite( "same", "/tmp/same.prg", "precious-live" )
         ErrorLevel( 2 )
         return
      endif
      hb_MemoWrit( hb_FNameMerge( HBIDE_RecoveryDir(), "ready" ), "yes" )
      hb_idleSleep( 30 )
   else
      a := HBIDE_RecoveryScan()
      hb_MemoWrit( hb_FNameMerge( HBIDE_RecoveryDir(), "scan-result" ), hb_ntos( Len( a ) ) )
   endif
return

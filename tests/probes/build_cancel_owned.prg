// Linux-only exploratory probe, never the production build runner.
#include "fileio.ch"
procedure Main( cChild )
   local hIn, hOut, hErr, hProc, nStatus := -1, cBuffer := Space( 8192 )
   local nRead, cOut := "", cErr := "", nStart := hb_MilliSeconds(), aIdentity, aNow
   local lOwned := .F., lCancelled := .F., nKill := -1, n
   hProc := hb_processOpen( '/usr/bin/setsid /usr/bin/python3 "' + StrTran( cChild, '"', '' ) + '"', @hIn, @hOut, @hErr )
   if hProc == -1
      ErrorLevel( 1 )
      return
   endif
   FClose( hIn )
   do while hb_MilliSeconds() - nStart < 2000
      nRead := hb_PRead( hOut, @cBuffer,, 5 )
      if nRead > 0
         cOut += Left( cBuffer, nRead )
      endif
      nRead := hb_PRead( hErr, @cBuffer,, 5 )
      if nRead > 0
         cErr += Left( cBuffer, nRead )
      endif
      nStatus := hb_processValue( hProc, .F. )
      if nStatus != -1
         exit
      endif
      aIdentity := ProbeIdentity( hProc )
      if aIdentity != NIL .and. aIdentity[ 1 ] == hProc .and. ;
         aIdentity[ 2 ] == hProc .and. aIdentity[ 3 ] == hProc .and. "STARTED" $ cOut
         lOwned := .T.
         exit
      endif
   enddo
   if lOwned .and. hb_processValue( hProc, .F. ) == -1
      aNow := ProbeIdentity( hProc )
      if aNow != NIL .and. aNow[ 4 ] == aIdentity[ 4 ] .and. ;
         aNow[ 2 ] == hProc .and. aNow[ 3 ] == hProc
         nKill := posix_kill( -hProc, "KILL" )
         lCancelled := nKill == 0
      endif
   endif
   // Never wait indefinitely or signal an identity we could not validate.
   nStart := hb_MilliSeconds()
   do while nStatus == -1 .and. hb_MilliSeconds() - nStart < 2000
      nStatus := hb_processValue( hProc, .F. )
      hb_idleSleep( .01 )
   enddo
   FClose( hOut )
   FClose( hErr )
   ? "OWNED", lOwned, "CANCELLED", lCancelled, "KILL", nKill, "EXIT", nStatus
   ? "STDOUT_BYTES", Len( cOut ), "STDERR_BYTES", Len( cErr )
   ? "Cancellation is separate from exit status; no artifact is promoted."
   ErrorLevel( iif( lOwned .and. lCancelled .and. nStatus != -1, 0, 1 ) )
return

// /proc stat: name can contain spaces or ')', use its last closing paren.
// State is tail field1; ppid2, pgrp3, session4, starttime20.
static function ProbeIdentity( nPid )
   local c := hb_MemoRead( "/proc/" + hb_ntos( nPid ) + "/stat" ), nEnd := RAt( ")", c ), a
   if nEnd <= 0
      return NIL
   endif
   a := hb_ATokens( AllTrim( SubStr( c, nEnd + 1 ) ), " " )
   if Len( a ) < 20
      return NIL
   endif
return { Val( c ), Val( a[ 3 ] ), Val( a[ 4 ] ), a[ 20 ] }

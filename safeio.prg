#include "directry.ch"
#include "fileio.ch"

// Reject existing files, links and directories at selection time. This does
// not reserve the path against a concurrent creator. Returns "" on exhaustion.
function HBIDE_UniqueSibling( cBase, cExt )

   local cTmp, nTry := 0

   hb_default( @cExt, "" )
   do while nTry++ < 20
      cTmp := cBase + ".tmp-" + StrZero( hb_randomInt( 999999 ), 6 ) + cExt
      if ! File( cTmp ) .and. ! hb_DirExists( cTmp ) .and. Empty( hb_vfLinkRead( cTmp ) )
         return cTmp
      endif
   enddo

return ""

//-----------------------------------------------------------------------------------------//

// Write cContent to cFile without truncating the user's original in place:
// write a sibling temp file, verify its size, stamp the original's
// permissions on it (hb_vfAttrGet/Set, real native API), then move it over
// the destination. On POSIX the rename replaces atomically, so a crash can
// leave either the old or the new file, never a half-written one. If the
// original's attributes cannot be read or applied, the save ABORTS without
// modifying the destination (fail-closed). After a complete write, a later
// permission/promotion failure keeps that temp and names it in cFailInfo.
// Creation/partial-write failure promises no complete temp; keep the buffer open.
// Symlink policy (fail-closed, documented): renaming would silently replace
// the LINK with a regular file, and writing through the link in place would
// reintroduce the non-atomic truncation this helper removes. Saving to a
// symlinked destination is REFUSED until a safe strategy exists: the
// destination and link stay untouched and the new content goes to a named
// recoverable temp.
function HBIDE_AtomicWriteFile( cFile, cContent, cFailInfo )

   local cTmp, lOk := .F., nAttr := 0, aDir, nHandle, nTry := 0, lWritten

   cFailInfo := ""

   // Reserve with exclusive creation. A name-only check cannot own the path.
   nHandle := F_ERROR
   do while nTry++ < 20
      cTmp := HBIDE_UniqueSibling( cFile )
      if Empty( cTmp )
         exit
      endif
      nHandle := hb_FCreate( cTmp, FC_NORMAL, FO_EXCL )
      if nHandle != F_ERROR
         exit
      endif
   enddo
   if nHandle == F_ERROR
      cFailInfo := "could not write: cannot create an exclusive temp next to " + cFile + "; destination untouched"
      return .F.
   endif
   lWritten := FWrite( nHandle, cContent ) == Len( cContent )
   lWritten := FClose( nHandle ) .and. lWritten
   if ! lWritten
      cFailInfo := "could not write a complete temp; destination untouched. Keep this buffer open and save elsewhere"
      // Do not describe a partial write as recoverable complete content.
      FErase( cTmp )
      return .F.
   endif

   aDir := Directory( cFile )
   if Len( aDir ) > 0 .and. "L" $ aDir[ 1 ][ F_ATTR ]
      cFailInfo := cFile + " is a symlink: saving there is not safe yet. " + ;
                   "Destination untouched; your content is recoverable at " + cTmp
      return .F.
   endif

   do while .T.   // single-exit block; the temp is kept on every failure
      // read the original's permissions BEFORE touching anything
      if File( cFile ) .and. ! hb_vfAttrGet( cFile, @nAttr )
         cFailInfo := "could not read attributes of " + cFile + "; destination untouched"
         exit
      endif
      // stamp the original's permissions on the replacement (aborts above
      // when impossible, so the destination is never silently demoted)
      if File( cFile ) .and. ! hb_vfAttrSet( cTmp, nAttr )
         cFailInfo := "could not preserve the permissions of " + cFile + "; destination untouched"
         exit
      endif
      lOk := HBIDE_ReplaceFile( cTmp, cFile, @cFailInfo )
      exit
   enddo

   if ! lOk .and. File( cTmp )
      cFailInfo += " (new content kept at " + cTmp + ")"
   endif

return lOk

// Move cTmp over cTarget, fail-closed: the original destination is never
// destroyed before the replacement stands in place, and every failure path
// leaves BOTH the original and the new content on disk, named in
// @cRecovery. POSIX rename(2) replaces an existing target atomically. The
// Windows path cannot rename over an existing file, so it parks the
// destination first (never erased), moves the new file in and rolls back on
// failure; if the ROLLBACK also fails, the original survives at its park
// name and the new content at cTmp - cRecovery says exactly where. Not
// atomic on Windows and does not claim to be.
function HBIDE_ReplaceFile( cTmp, cTarget, cRecovery )

   local lOk

   cRecovery := ""
#ifdef __PLATFORM__WINDOWS
return HBIDE_ParkReplace( cTmp, cTarget, @cRecovery )
#else
   lOk := FRename( cTmp, cTarget ) == 0
   if ! lOk
      cRecovery := "rename failed; original untouched at " + cTarget
   endif
return lOk
#endif

//-----------------------------------------------------------------------------------------//

// Park-and-replace with rollback. The Windows replace strategy; factored
// out so fault-injection tests can exercise it on any platform.
function HBIDE_ParkReplace( cTmp, cTarget, cRecovery )

   local cHold

   cRecovery := ""
   if ! File( cTarget )
      if FRename( cTmp, cTarget ) != 0
         cRecovery := "rename failed; new content kept at " + cTmp
         return .F.
      endif
      return .T.
   endif

   cHold := HBIDE_UniqueSibling( cTarget )
   if Empty( cHold )
      cRecovery := "no free park name; original untouched at " + cTarget + ", new content kept at " + cTmp
      return .F.
   endif
   if FRename( cTarget, cHold ) != 0
      cRecovery := "could not park the original; it is untouched at " + cTarget + ", new content kept at " + cTmp
      return .F.
   endif
   if FRename( cTmp, cTarget ) != 0
      if FRename( cHold, cTarget ) != 0
         cRecovery := "replace and rollback BOTH failed: original preserved as " + cHold + ", new content kept at " + cTmp
      else
         cRecovery := "replacement failed; original restored at " + cTarget + "; replacement source: " + cTmp
      endif
      return .F.
   endif
   FErase( cHold )   // replacement complete: drop the park copy

return .T.

//-----------------------------------------------------------------------------------------//


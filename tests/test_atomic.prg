// P0: atomic save + build promotion helpers (editor.prg).
// Verifies: temp+verified write, no in-place truncation, failure leaves the
// original intact and no temp litter, promotion replaces the old binary.
// Linux-only checks (read-only dir via chmod). Run: ./test_atomic

#include "hbclass.ch"

static nPass := 0, nFail := 0

// stubs for editor.prg externals not under test
function HBIDE_MsgAlert( cText )
   hb_defaultValue( cText, "" )
return 1

proc Check( cName, lCond )
   if lCond
      nPass++
      ? "PASS:", cName
   else
      nFail++
      ? "FAIL:", cName
   endif
return

proc Main()

   local cDir := "/tmp/hbide-atomic-" + StrZero( hb_randomInt( 999999 ), 6 )
   local cFile, cOld, cTmp, cTarget, aDir

   MakeDir( cDir )

   // 1. write a NEW file atomically
   cFile := cDir + "/new.prg"
   Check( "atomic write new file ok", HBIDE_AtomicWriteFile( cFile, "line1" + hb_eol() + "line2" ) )
   Check( "new file content exact", MemoRead( cFile ) == "line1" + hb_eol() + "line2" )

   // 2. overwrite an EXISTING file: content replaced, old content gone
   hb_MemoWrit( cFile, "OLD-CONTENT-MUST-GO" )
   Check( "atomic overwrite ok", HBIDE_AtomicWriteFile( cFile, "fresh" ) )
   Check( "overwritten content exact", MemoRead( cFile ) == "fresh" )
   Check( "no temp litter after success", Len( Directory( cDir + "/*.tmp-*" ) ) == 0 )

   // 3. failure: read-only DIRECTORY -> cannot create temp or rename;
   //    original must stay byte-identical, no temp litter
   cOld := cDir + "/ro/protected.prg"
   MakeDir( cDir + "/ro" )
   hb_MemoWrit( cOld, "PRECIOUS" )
   hb_Run( "chmod 0555 " + cDir + "/ro" )
   Check( "write into read-only dir fails", ! HBIDE_AtomicWriteFile( cOld, "replacement" ) )
   Check( "original intact after failure", MemoRead( cOld ) == "PRECIOUS" )
   hb_Run( "chmod 0755 " + cDir + "/ro" )
   Check( "no temp litter after failure", Len( Directory( cDir + "/ro/*.tmp-*" ) ) == 0 )

   // 4. empty content writes fine (edge: 0 bytes, size check must not fail)
   Check( "empty content write ok", HBIDE_AtomicWriteFile( cDir + "/empty.prg", "" ) )
   Check( "empty file is 0 bytes", hb_FSize( cDir + "/empty.prg" ) == 0 )

   // 5. HBIDE_ReplaceFile over an existing target (POSIX atomic replace)
   cTmp := cDir + "/b.buildtmp"
   cTarget := cDir + "/b"
   hb_MemoWrit( cTmp, "NEW-BIN" )
   hb_MemoWrit( cTarget, "OLD-BIN" )
   Check( "promote over existing ok", HBIDE_ReplaceFile( cTmp, cTarget ) )
   Check( "promoted content exact", MemoRead( cTarget ) == "NEW-BIN" )
   Check( "temp consumed by promote", ! File( cTmp ) )

   // 6. promote with missing temp fails and target untouched
   Check( "promote missing temp fails", ! HBIDE_ReplaceFile( cDir + "/absent", cTarget ) )
   Check( "target untouched", MemoRead( cTarget ) == "NEW-BIN" )

   // 7. permissions preserved across the atomic replace (hb_vfAttrGet/Set)
   cFile := cDir + "/mode.prg"
   hb_MemoWrit( cFile, "v1" )
   hb_Run( "chmod 750 " + cFile )
   Check( "atomic write over 750 file ok", HBIDE_AtomicWriteFile( cFile, "v2" ) )
   hb_Run( "stat -c %a " + cFile + " > " + cDir + "/m.txt" )
   Check( "mode 750 preserved", StrTran( MemoRead( cDir + "/m.txt" ), Chr(10) ) == "750" )
   Check( "content replaced", MemoRead( cFile ) == "v2" )

   // 8. read-only (444) file: replace succeeds via rename, mode stays 444
   hb_Run( "chmod 444 " + cFile )
   Check( "atomic write over 444 file ok", HBIDE_AtomicWriteFile( cFile, "v3" ) )
   hb_Run( "stat -c %a " + cFile + " > " + cDir + "/m.txt" )
   Check( "mode 444 preserved", StrTran( MemoRead( cDir + "/m.txt" ), Chr(10) ) == "444" )
   Check( "content replaced again", MemoRead( cFile ) == "v3" )

   // 9. symlink policy: writing through the LINK keeps it a symlink and
   //    updates the TARGET in place (documented non-atomic fallback)
   cOld := cDir + "/real.txt"
   hb_MemoWrit( cOld, "target-v1" )
   hb_Run( "ln -s real.txt " + cDir + "/link.txt" )
   Check( "write through symlink ok", HBIDE_AtomicWriteFile( cDir + "/link.txt", "target-v2" ) )
   Check( "target updated in place", MemoRead( cOld ) == "target-v2" )
   hb_Run( "test -L " + cDir + "/link.txt" )
   aDir := Directory( cDir + "/link.txt" )
   Check( "path is still a symlink", Len( aDir ) > 0 .and. "L" $ aDir[ 1 ][ 5 ] )

   // 10. unique sibling: never returns an existing name, two calls differ
   cTmp := HBIDE_UniqueSibling( cDir + "/u.prg" )
   Check( "unique name free", ! Empty( cTmp ) .and. ! File( cTmp ) )
   Check( "two picks differ", HBIDE_UniqueSibling( cDir + "/u.prg" ) != cTmp )

   hb_Run( "rm -rf " + cDir )

   ?
   ? iif( nFail == 0, "ALL PASS", "FAILURES PRESENT" ), hb_ntos( nPass ) + "/" + hb_ntos( nPass + nFail )

return

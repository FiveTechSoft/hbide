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
   local cFile, cOld, cTmp, cTarget, aDir, cInfo := "", cRecover

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
   cInfo := ""
   Check( "write into read-only dir fails", ! HBIDE_AtomicWriteFile( cOld, "replacement", @cInfo ) )
   Check( "original intact after failure", MemoRead( cOld ) == "PRECIOUS" )
   Check( "failure info explains", ! Empty( cInfo ) )
   hb_Run( "chmod 0755 " + cDir + "/ro" )
   Check( "failed write left no temp (write itself failed)", Len( Directory( cDir + "/ro/*.tmp-*" ) ) == 0 )

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

   // 9. symlink policy (fail-closed): saving TO a symlink is refused -
   //    link and target stay byte-identical, content lands in a named temp
   cOld := cDir + "/real.txt"
   hb_MemoWrit( cOld, "target-v1" )
   hb_Run( "ln -s real.txt " + cDir + "/link.txt" )
   cInfo := ""
   Check( "save to symlink refused", ! HBIDE_AtomicWriteFile( cDir + "/link.txt", "target-v2", @cInfo ) )
   Check( "target untouched", MemoRead( cOld ) == "target-v1" )
   aDir := Directory( cDir + "/link.txt" )
   Check( "path is still a symlink", Len( aDir ) > 0 .and. "L" $ aDir[ 1 ][ 5 ] )
   Check( "refusal explains + names recovery temp", "symlink" $ cInfo .and. "recoverable" $ cInfo )
   Check( "recovery temp exists with new content", Len( Directory( cDir + "/link.txt.tmp-*" ) ) == 1 )
   cRecover := SubStr( cInfo, At( "recoverable at ", cInfo ) + Len( "recoverable at " ) )
   Check( "named symlink recovery bytes exact", hb_MemoRead( cRecover ) == "target-v2" )

   // Dangling symlinks must also be refused, never replaced by a plain file.
   hb_Run( "ln -s absent-target " + cDir + "/dangling.txt" )
   cInfo := ""
   Check( "save to dangling symlink refused", ! HBIDE_AtomicWriteFile( cDir + "/dangling.txt", "NEW", @cInfo ) )
   Check( "dangling link preserved", hb_vfLinkRead( cDir + "/dangling.txt" ) == "absent-target" )

   // Symlink refusal must not promise a recovery file that could not be written.
   hb_Run( "ln -s ../real.txt " + cDir + "/ro/link.txt" )
   hb_Run( "chmod 0555 " + cDir + "/ro" )
   cInfo := ""
   Check( "read-only symlink save refused", ! HBIDE_AtomicWriteFile( cDir + "/ro/link.txt", "NEW", @cInfo ) )
   Check( "failed recovery write not claimed recoverable", !( "recoverable at" $ cInfo ) )
   Check( "failed recovery write explained", "could not write" $ cInfo )
   Check( "read-only link and target untouched", hb_vfLinkRead( cDir + "/ro/link.txt" ) == "../real.txt" .and. MemoRead( cOld ) == "target-v1" )
   hb_Run( "chmod 0755 " + cDir + "/ro" )

   // 10. fault injection: HBIDE_ParkReplace over a target in a READ-ONLY
   //     dir cannot even park -> .F., original intact, temp KEPT, info names it
   cTarget := cDir + "/ro/protected.prg"
   cTmp := cDir + "/new.prg.tmp-000001"
   hb_MemoWrit( cTmp, "NEW-CONTENT" )
   hb_Run( "chmod 0555 " + cDir + "/ro" )
   cInfo := ""
   Check( "park-replace fails closed", ! HBIDE_ParkReplace( cTmp, cTarget, @cInfo ) )
   Check( "park failure keeps original", MemoRead( cTarget ) == "PRECIOUS" )
   Check( "park failure keeps temp", MemoRead( cTmp ) == "NEW-CONTENT" )
   Check( "park failure names both", "untouched" $ cInfo .and. "kept at" $ cInfo )
   hb_Run( "chmod 0755 " + cDir + "/ro" )
   FErase( cTmp )

   // 11. park-replace happy path: replaces and consumes both temps
   cTmp := cDir + "/pr.tmp-000002"
   cTarget := cDir + "/pr.txt"
   hb_MemoWrit( cTmp, "NEW" )
   hb_MemoWrit( cTarget, "OLD" )
   Check( "park-replace over existing ok", HBIDE_ParkReplace( cTmp, cTarget, @cInfo ) )
   Check( "park-replace content", MemoRead( cTarget ) == "NEW" )
   Check( "park-replace consumed temp", ! File( cTmp ) )
   Check( "park copy dropped", Len( Directory( cDir + "/pr.txt.tmp-*" ) ) == 0 )

   // A complete write followed by promotion failure must retain exact new bytes.
   cTarget := cDir + "/directory-target"
   MakeDir( cTarget )
   hb_MemoWrit( cTarget + "/sentinel", "ORIGINAL CHILD" )
   cInfo := ""
   Check( "promotion over directory refused", ! HBIDE_AtomicWriteFile( cTarget, "COMPLETE NEW BYTES", @cInfo ) )
   Check( "directory target child untouched", hb_MemoRead( cTarget + "/sentinel" ) == "ORIGINAL CHILD" )
   aDir := Directory( cTarget + ".tmp-*" )
   Check( "complete temp retained after promotion failure", Len( aDir ) == 1 )
   IF Len( aDir ) == 1
      cRecover := cDir + "/" + aDir[1,1]
      Check( "retained complete bytes exact", hb_MemoRead( cRecover ) == "COMPLETE NEW BYTES" )
      Check( "failure names retained complete temp", cRecover $ cInfo )
   ENDIF

   // Missing replacement after parking: successful rollback must explain state.
   cTarget := cDir + "/rollback-target"
   hb_MemoWrit( cTarget, "ROLLBACK ORIGINAL" )
   cInfo := ""
   Check( "park replace missing source refused", ! HBIDE_ParkReplace( cDir + "/missing-replacement", cTarget, @cInfo ) )
   Check( "successful rollback restores original", hb_MemoRead( cTarget ) == "ROLLBACK ORIGINAL" )
   Check( "successful rollback explains failure", "original restored" $ cInfo )

   // 12. unique sibling: never returns an existing name, two calls differ
   cTmp := HBIDE_UniqueSibling( cDir + "/u.prg" )
   Check( "unique name free", ! Empty( cTmp ) .and. ! File( cTmp ) )
   Check( "two picks differ", HBIDE_UniqueSibling( cDir + "/u.prg" ) != cTmp )

   // Predict first random candidate without changing the production helper.
   hb_randomSeed( 4291 )
   cTmp := HBIDE_UniqueSibling( cDir + "/dangling-temp" )
   hb_Run( 'ln -s absent-target "' + cTmp + '"' )
   hb_randomSeed( 4291 )
   cTarget := HBIDE_UniqueSibling( cDir + "/dangling-temp" )
   Check( "unique sibling skips dangling symlink", cTarget != cTmp )
   Check( "dangling sibling preserved", hb_vfLinkRead( cTmp ) == "absent-target" )
   hb_randomSeed( 5291 )
   cTmp := HBIDE_UniqueSibling( cDir + "/directory-temp" )
   MakeDir( cTmp )
   hb_randomSeed( 5291 )
   Check( "unique sibling skips directory", HBIDE_UniqueSibling( cDir + "/directory-temp" ) != cTmp )

   hb_Run( "rm -rf " + cDir )

   ?
   ? iif( nFail == 0, "ALL PASS", "FAILURES PRESENT" ), hb_ntos( nPass ) + "/" + hb_ntos( nPass + nFail )

return

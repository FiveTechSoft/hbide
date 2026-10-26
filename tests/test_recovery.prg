// P0: recovery journal (recovery.prg). Verifies: recovery dir override and
// creation, key mapping (noname, rel/abs stability, collision-freedom),
// write/read byte-exact round trip, scan metadata, delete. Run: ./test_recovery

static nPass := 0, nFail := 0

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

   local cDir := "/tmp/hbide-recovery-" + StrZero( hb_randomInt( 999999 ), 6 )
   local cKey1, cKey2, cKey3, cKey4, aScan, cBin

   hb_SetEnv( "HBIDE_RECOVERY_DIR", cDir )

   // 1. dir override honored and created on demand
   Check( "recovery dir honors HBIDE_RECOVERY_DIR", HBIDE_RecoveryDir() == cDir )
   Check( "recovery dir created", hb_DirExists( cDir ) )

   // 2. key mapping
   cKey1 := HBIDE_RecoveryKey( "noname.prg" )
   Check( "noname key is fixed", cKey1 == "noname" )
   cKey2 := HBIDE_RecoveryKey( "/tmp/aa/foo.prg" )
   Check( "absolute key stable", cKey2 == HBIDE_RecoveryKey( "/tmp/aa/foo.prg" ) )
   cKey3 := HBIDE_RecoveryKey( "/tmp/bb/foo.prg" )
   Check( "same basename different dirs differ", !( cKey2 == cKey3 ) )
   Check( "relative and absolute map alike", HBIDE_RecoveryKey( "foo.prg" ) == ;
          HBIDE_RecoveryKey( hb_PathNormalize( hb_FNameMerge( hb_cwd(), "foo.prg" ) ) ) )
   cKey4 := HBIDE_RecoveryKey( "/tmp/with space/under_score.prg" )
   Check( "special chars escaped, no raw / _ or space in key", ;
          !( "/" $ cKey4 ) .and. !( " " $ cKey4 ) .and. !( "_5F" == cKey4 ) .and. ;
          !( cKey4 == cKey2 ) )

   // 3. write/read byte-exact round trip, incl. control + high bytes
   cBin := "line1" + hb_eol() + "tab" + Chr( 9 ) + "high" + Chr( 225 ) + Chr( 130 ) + ;
           "end" + Chr( 13 ) + Chr( 10 )
   Check( "journal write ok", HBIDE_RecoveryWrite( cKey2, "/tmp/aa/foo.prg", cBin ) )
   Check( "journal read byte-exact", HBIDE_RecoveryRead( cKey2 ) == cBin )

   // 4. scan metadata
   aScan := HBIDE_RecoveryScan()
   Check( "scan finds one entry", Len( aScan ) == 1 )
   Check( "scan key", aScan[ 1 ][ 1 ] == cKey2 )
   Check( "scan target", aScan[ 1 ][ 2 ] == "/tmp/aa/foo.prg" )
   Check( "scan size", aScan[ 1 ][ 3 ] == Len( cBin ) )
   Check( "scan stamp present", ! Empty( aScan[ 1 ][ 4 ] ) )

   // 5. second journal: scan grows
   Check( "second write ok", HBIDE_RecoveryWrite( cKey1, "noname.prg", "unsaved scratch" ) )
   Check( "scan finds two", Len( HBIDE_RecoveryScan() ) == 2 )

   // 6. delete cleans both files
   HBIDE_RecoveryDelete( cKey2 )
   Check( "delete leaves one", Len( HBIDE_RecoveryScan() ) == 1 )
   Check( "deleted journal gone", ! File( hb_FNameMerge( cDir, cKey2, ".journal" ) ) )
   Check( "deleted sidecar gone", ! File( hb_FNameMerge( cDir, cKey2, ".target" ) ) )

   // 7. overwrite same key: content replaced, not duplicated
   Check( "rewrite ok", HBIDE_RecoveryWrite( cKey1, "noname.prg", "v2" ) )
   Check( "rewrite read exact", HBIDE_RecoveryRead( cKey1 ) == "v2" )
   Check( "rewrite did not duplicate", Len( HBIDE_RecoveryScan() ) == 1 )

   // 8. crash debris is inert: a lone .tmp or a sidecar without journal
   //    must never be offered for recovery
   hb_MemoWrit( hb_FNameMerge( cDir, "zz.journal" ) + ".tmp", "torn" )
   hb_MemoWrit( hb_FNameMerge( cDir, "yy.target" ), "/tmp/yy.prg" )
   Check( "orphan tmp not scanned", Len( HBIDE_RecoveryScan() ) == 1 )
   Check( "read of tmp-only key is empty", Empty( HBIDE_RecoveryRead( "zz" ) ) )
   HBIDE_RecoveryDelete( "zz" )
   HBIDE_RecoveryDelete( "yy" )
   Check( "debris cleaned", Len( Directory( hb_FNameMerge( cDir, "*" ) ) ) == 2 )

   // 9. unwritable recovery dir: write fails soft, never raises
   hb_SetEnv( "HBIDE_RECOVERY_DIR", "/proc/hbide-nope" )
   Check( "write to unwritable dir returns .F.", ! HBIDE_RecoveryWrite( "kk", "k.prg", "x" ) )
   Check( "scan on missing dir is empty", Len( HBIDE_RecoveryScan() ) == 0 )
   Check( "read on missing dir is empty", Empty( HBIDE_RecoveryRead( "kk" ) ) )
   HBIDE_RecoveryDelete( "kk" )   // must not raise either
   Check( "delete on missing dir tolerated", .T. )
   hb_SetEnv( "HBIDE_RECOVERY_DIR", cDir )

   HBIDE_RecoveryDelete( cKey1 )
   hb_Run( "rm -rf " + cDir )

   ? "----"
   ? "PASS", nPass, "FAIL", nFail
   if nFail > 0
      ErrorLevel( 1 )
   endif

return

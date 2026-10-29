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
   local cKey1, cKey2, cKey3, cKey4, aScan, cBin, hEncoding, cBase, cStored
   local cLong1, cLong2, cKeyL1, cKeyL2, cLongDir

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

   // Versioned encoding generation is atomic with text, not a sidecar that
   // could be newer than a journal after a crash between renames.
   hEncoding := { "utf8" => .T., "bom" => .T., "raw" => .F., "cp" => "EN" }
   Check( "encoding journal write", HBIDE_RecoveryWrite( cKey2, "/tmp/aa/foo.prg", cBin, hEncoding ) )
   cBase := cKey2 + "--" + HBIDE_RecoverySession()
   cStored := hb_MemoRead( hb_FNameMerge( cDir, cBase, ".journal" ) )
   Check( "encoding and bytes share envelope", Left( cStored, 10 ) == Chr( 0 ) + "HBIDE-J1" + Chr( 10 ) )
   hEncoding := NIL
   Check( "encoding payload read exact", HBIDE_RecoveryReadBase( cBase, @hEncoding ) == cBin )
   Check( "encoding metadata read exact", HB_ISHASH( hEncoding ) .and. hEncoding[ "utf8" ] .and. ;
      hEncoding[ "bom" ] .and. ! hEncoding[ "raw" ] .and. hEncoding[ "cp" ] == "EN" )
   Check( "legacy API strips envelope", HBIDE_RecoveryRead( cKey2 ) == cBin )
   Check( "rewrite legacy journal", HBIDE_RecoveryWrite( cKey2, "/tmp/aa/foo.prg", cBin ) )
   hEncoding := {=>}
   Check( "legacy data unchanged and no invented encoding", HBIDE_RecoveryReadBase( cBase, @hEncoding ) == cBin .and. hEncoding == NIL )

   // 4. scan metadata
   aScan := HBIDE_RecoveryScan( .T. )
   Check( "scan finds one entry", Len( aScan ) == 1 )
   Check( "scan key", aScan[ 1 ][ 1 ] == cKey2 + "--" + HBIDE_RecoverySession() )
   Check( "scan target", aScan[ 1 ][ 2 ] == "/tmp/aa/foo.prg" )
   Check( "scan size", aScan[ 1 ][ 3 ] == Len( cBin ) )
   Check( "scan stamp present", ! Empty( aScan[ 1 ][ 4 ] ) )

   // 5. second journal: scan grows
   Check( "second write ok", HBIDE_RecoveryWrite( cKey1, "noname.prg", "unsaved scratch" ) )
   Check( "scan finds two", Len( HBIDE_RecoveryScan( .T. ) ) == 2 )

   // 6. delete cleans both files
   HBIDE_RecoveryDelete( cKey2 )
   Check( "delete leaves one", Len( HBIDE_RecoveryScan( .T. ) ) == 1 )
   Check( "deleted journal gone", ! File( hb_FNameMerge( cDir, cKey2, ".journal" ) ) )
   Check( "deleted sidecar gone", ! File( hb_FNameMerge( cDir, cKey2, ".target" ) ) )

   // 7. overwrite same key: content replaced, not duplicated
   Check( "rewrite ok", HBIDE_RecoveryWrite( cKey1, "noname.prg", "v2" ) )
   Check( "rewrite read exact", HBIDE_RecoveryRead( cKey1 ) == "v2" )
   Check( "rewrite did not duplicate", Len( HBIDE_RecoveryScan( .T. ) ) == 1 )

   // 8. crash debris is inert: a lone .tmp or a sidecar without journal
   //    must never be offered for recovery
   hb_MemoWrit( hb_FNameMerge( cDir, "zz--" + HBIDE_RecoverySession() + ".journal" ) + ".tmp", "torn" )
   hb_MemoWrit( hb_FNameMerge( cDir, "yy--" + HBIDE_RecoverySession() + ".target" ), "/tmp/yy.prg" )
   Check( "orphan tmp not scanned", Len( HBIDE_RecoveryScan( .T. ) ) == 1 )
   Check( "read of tmp-only key is empty", Empty( HBIDE_RecoveryRead( "zz" ) ) )
   HBIDE_RecoveryDelete( "zz" )
   HBIDE_RecoveryDelete( "yy" )
   Check( "debris cleaned", Len( Directory( hb_FNameMerge( cDir, "*.journal*" ) ) ) == 1 )

   // 9. unwritable recovery dir: write fails soft, never raises
   hb_SetEnv( "HBIDE_RECOVERY_DIR", "/proc/hbide-nope" )
   Check( "write to unwritable dir returns .F.", ! HBIDE_RecoveryWrite( "kk", "k.prg", "x" ) )
   Check( "scan on missing dir is empty", Len( HBIDE_RecoveryScan( .T. ) ) == 0 )
   Check( "read on missing dir is empty", Empty( HBIDE_RecoveryRead( "kk" ) ) )
   HBIDE_RecoveryDelete( "kk" )   // must not raise either
   Check( "delete on missing dir tolerated", .T. )
   hb_SetEnv( "HBIDE_RECOVERY_DIR", cDir )

   // 9b. support limit: a recovery dir so long that even a bounded key
   // overflows Harbour's full-path limit fails soft (write .F., no raise)
   cLongDir := "/tmp/" + Replicate( "r", 240 )
   hb_SetEnv( "HBIDE_RECOVERY_DIR", cLongDir )
   Check( "overlong recovery dir write fails soft", ! HBIDE_RecoveryWrite( "kk", "k.prg", "x" ) )
   Check( "overlong recovery dir scan empty", Len( HBIDE_RecoveryScan( .T. ) ) == 0 )
   hb_SetEnv( "HBIDE_RECOVERY_DIR", cDir )
   hb_Run( "rm -rf " + cLongDir )

   // 10. instance ownership: two sessions over the same path keep separate
   //     journals; save/discard in one never deletes the other's work
   hb_SetEnv( "HBIDE_RECOVERY_SESSION", "sessA" )
   Check( "session A write", HBIDE_RecoveryWrite( cKey3, "/tmp/bb/foo.prg", "work of A" ) )
   hb_SetEnv( "HBIDE_RECOVERY_SESSION", "sessB" )
   Check( "session B write same path", HBIDE_RecoveryWrite( cKey3, "/tmp/bb/foo.prg", "work of B" ) )
   Check( "both sessions scanned", Len( HBIDE_RecoveryScan( .T. ) ) == 3 )
   HBIDE_RecoveryDelete( cKey3 )   // B saves/discards: only B's journal goes
   Check( "A journal survives B delete", HBIDE_RecoveryReadBase( cKey3 + "--sessA" ) == "work of A" )
   Check( "B journal gone", Empty( HBIDE_RecoveryReadBase( cKey3 + "--sessB" ) ) )
   Check( "scan drops B only", Len( HBIDE_RecoveryScan( .T. ) ) == 2 )
   HBIDE_RecoveryDeleteBase( cKey3 + "--sessA" )
   Check( "base delete cleans A", Len( HBIDE_RecoveryScan( .T. ) ) == 1 )
   hb_SetEnv( "HBIDE_RECOVERY_SESSION", "" )

   // 6. long absolute paths: the escaped key would overflow the filename
   // budget (Harbour path limit via the atomic .tmp write), so it is
   // bounded to prefix + dual-hash of the full path and stays writable.
   cLong1 := "/tmp/" + Replicate( "a", 110 ) + "/" + Replicate( "b", 110 ) + ".prg"
   cLong2 := "/tmp/" + Replicate( "a", 110 ) + "/" + Replicate( "c", 110 ) + ".prg"
   cKeyL1 := HBIDE_RecoveryKey( cLong1 )
   cKeyL2 := HBIDE_RecoveryKey( cLong2 )
   Check( "long key bounded to 120", Len( cKeyL1 ) <= 120 )
   Check( "long key keeps readable prefix", Left( cKeyL1, 15 ) == "_2Ftmp_2Faaaaaa" )
   Check( "long key stable", cKeyL1 == HBIDE_RecoveryKey( cLong1 ) )
   Check( "long keys differ when only tail differs", !( cKeyL1 == cKeyL2 ) )
   cBin := Replicate( "deep content ", 20 ) + hb_eol() + Chr( 0 ) + Chr( 26 ) + "end"
   Check( "long journal write ok", HBIDE_RecoveryWrite( cKeyL1, cLong1, cBin ) )
   Check( "long journal read byte-exact", HBIDE_RecoveryRead( cKeyL1 ) == cBin )
   Check( "long sidecar holds full target", ;
          hb_MemoRead( hb_FNameMerge( cDir, cKeyL1 + "--" + HBIDE_RecoverySession(), ".target" ) ) == cLong1 )
   HBIDE_RecoveryDelete( cKeyL1 )
   Check( "long journal delete", ! File( hb_FNameMerge( cDir, cKeyL1, ".journal" ) ) )

   HBIDE_RecoveryDelete( cKey1 )
   hb_Run( "rm -rf " + cDir )

   ? "----"
   ? "PASS", nPass, "FAIL", nFail
   if nFail > 0
      ErrorLevel( 1 )
   endif

return

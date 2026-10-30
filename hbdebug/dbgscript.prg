// Script lookup follows the bundled debugger manual. Resolving never runs code.
FUNCTION HBIDE_DbgScriptPath( cFileName )
   LOCAL cName, cDir, cCandidate, cDrive
   IF ! HB_ISSTRING( cFileName ) .OR. Empty( cFileName )
      RETURN ""
   ENDIF
   cName := hb_FNameExtSetDef( cFileName, ".cld" )
   IF hb_FileExists( cName )
      RETURN cName
   ENDIF
   // An explicit directory is an exact request, never a PATH basename search.
   hb_FNameSplit( cName, , , , @cDrive )
   IF ! Empty( hb_FNameDir( cName ) ) .OR. ! Empty( cDrive )
      RETURN ""
   ENDIF
   FOR EACH cDir IN hb_ATokens( GetEnv( "PATH" ), hb_osPathListSeparator() )
      IF Empty( cDir )
         LOOP // cwd was already checked; do not turn an empty component into root.
      ENDIF
      cCandidate := hb_DirSepAdd( cDir ) + cName
      IF hb_FileExists( cCandidate )
         RETURN cCandidate
      ENDIF
   NEXT
   RETURN ""

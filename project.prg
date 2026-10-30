// Harbour project model and build diagnostics. hbmk2 remains the build authority.
#include "hbclass.ch"

CREATE CLASS HBIDEProject
   VAR cFile INIT ""
   VAR cRoot INIT ""
   VAR cOriginal INIT ""
   VAR aMembers INIT {}
   VAR aUnresolved INIT {}
   VAR hInfo INIT {=>}
   VAR hBuild INIT {=>}
   VAR cError INIT ""
   METHOD Open( cFile )
   METHOD Info( cHbmk2 )
   METHOD Build( cHbmk2, lRebuild )
ENDCLASS

METHOD Open( cFile ) CLASS HBIDEProject
   LOCAL cLine, cToken, aTokens, nLine := 0, cExt, cMember
   ::cError := ""
   ::cFile := ""; ::cRoot := ""; ::cOriginal := ""
   ::aMembers := {}; ::aUnresolved := {}; ::hInfo := {=>}; ::hBuild := {=>}
   IF Lower( hb_FNameExt( cFile ) ) != ".hbp" .OR. ! hb_FileExists( cFile )
      ::cError := "Select an existing .hbp project"
      RETURN .F.
   ENDIF
   ::cFile := hb_PathNormalize( hb_FNameMerge( hb_cwd(), cFile ) )
   // hb_FNameMerge does not resolve absolute names on all hosts.
   IF HBIDEProjectAbsolute( cFile )
      ::cFile := hb_PathNormalize( cFile )
   ENDIF
   ::cRoot := hb_FNameDir( ::cFile )
   ::cOriginal := hb_MemoRead( ::cFile )
   ::aMembers := {}; ::aUnresolved := {}; ::hInfo := {=>}; ::hBuild := {=>}
   FOR EACH cLine IN hb_ATokens( StrTran( ::cOriginal, Chr(13), "" ), Chr(10) )
      nLine++
      IF Empty( AllTrim( cLine ) ) .OR. Left( LTrim( cLine ), 1 ) == "#"
         LOOP
      ENDIF
      aTokens := HBIDEProjectTokens( cLine )
      IF aTokens == NIL
         AAdd( ::aUnresolved, { nLine, cLine, "Unbalanced quotes" } )
         LOOP
      ENDIF
      FOR EACH cToken IN aTokens
         IF "{" $ cToken .OR. "}" $ cToken .OR. "*" $ cToken .OR. "?" $ cToken .OR. Left( cToken, 1 ) == "@"
            AAdd( ::aUnresolved, { nLine, cToken, "Resolved by hbmk2, not by the source list" } )
            LOOP
         ENDIF
         cExt := Lower( hb_FNameExt( cToken ) )
         IF Left( cToken, 1 ) != "-" .AND. AScan( { ".prg", ".ch", ".c", ".cpp", ".h", ".hbp", ".hbm", ".hbc" }, cExt ) > 0
            IF ! Empty( cExt )
               cMember := HBIDEProjectPath( ::cRoot, cToken )
               IF AScan( ::aMembers, {| m | m[ "path" ] == cMember } ) == 0
                  AAdd( ::aMembers, { "path" => cMember, "token" => cToken, ;
                     "line" => nLine, "exists" => hb_FileExists( cMember ), ;
                     "kind" => iif( cExt == ".hbp", "subproject", iif( cExt == ".hbm" .OR. cExt == ".hbc", "configuration", "source" ) ) } )
               ENDIF
            ENDIF
         ENDIF
      NEXT
   NEXT
   RETURN .T.

METHOD Info( cHbmk2 ) CLASS HBIDEProject
   LOCAL hResult := HBIDEProjectProcess( Self, cHbmk2, { "--hbinfo", "-run-" } )
   LOCAL cLine, hDecoded
   ::hInfo := {=>}
   IF hResult[ "exit" ] == 0
      FOR EACH cLine IN hb_ATokens( hResult[ "output" ], Chr(10) )
         hDecoded := NIL
         hb_jsonDecode( AllTrim( cLine ), @hDecoded )
         IF HB_ISHASH( hDecoded ) .AND. hb_HHasKey( hDecoded, "targettype" )
            ::hInfo := hDecoded
         ENDIF
      NEXT
   ENDIF
   IF Empty( ::hInfo )
      ::cError := "hbmk2 project information unavailable: " + hResult[ "output" ]
      RETURN .F.
   ENDIF
   ::cError := ""
   RETURN .T.

METHOD Build( cHbmk2, lRebuild ) CLASS HBIDEProject
   LOCAL aFlags := { "-run-", "-q" }
   // Do not run the product here, including when the project contains -run.
   // The caller can offer Run only after this result's exit code is zero.
   IF hb_defaultValue( lRebuild, .F. )
      AAdd( aFlags, "-rebuild" )
   ENDIF
   ::hBuild := HBIDEProjectProcess( Self, cHbmk2, aFlags )
   ::hBuild[ "ok" ] := ::hBuild[ "exit" ] == 0
   ::hBuild[ "diagnostics" ] := HBIDEProjectDiagnostics( ::hBuild[ "output" ], ::cRoot )
   ::cError := iif( ::hBuild[ "ok" ], "", "Build failed (exit " + hb_ntos( ::hBuild[ "exit" ] ) + ")" )
   RETURN ::hBuild[ "ok" ]

FUNCTION HBIDEProjectProcess( oProject, cHbmk2, aFlags )
   LOCAL cOld := hb_cwd(), cOut := "", cErr := "", nExit := -1, cCommand, cFlag
   LOCAL oError
   IF Empty( oProject:cFile )
      RETURN { "exit" => -1, "output" => "No project open", "command" => "" }
   ENDIF
   cCommand := HBIDEProjectQuote( cHbmk2 ) + " " + HBIDEProjectQuote( hb_FNameNameExt( oProject:cFile ) )
   FOR EACH cFlag IN aFlags
      cCommand += " " + HBIDEProjectQuote( cFlag )
   NEXT
   hb_cwd( oProject:cRoot )
   IF hb_cwd() != oProject:cRoot
      RETURN { "exit" => -1, "output" => "Cannot enter project directory", "command" => cCommand }
   ENDIF
   BEGIN SEQUENCE WITH {| e | Break( e ) }
      // hb_processRun invokes the executable directly, not a command shell.
      nExit := hb_processRun( cCommand,, @cOut, @cErr )
   RECOVER USING oError
      cErr += iif( HB_ISOBJECT( oError ), oError:Description, "Process failed" )
   END SEQUENCE
   hb_cwd( cOld )
   RETURN { "exit" => nExit, "output" => StrTran( StrTran( cOut + Chr(10) + cErr, Chr(13) + Chr(10), Chr(10) ), Chr(13), Chr(10) ), ;
      "command" => cCommand }

FUNCTION HBIDEProjectAbsolute( cFile )
   RETURN Left( cFile, 1 ) == "/" .OR. Left( cFile, 1 ) == "\" .OR. SubStr( cFile, 2, 1 ) == ":"

FUNCTION HBIDEProjectPath( cRoot, cFile )
   RETURN hb_PathNormalize( iif( HBIDEProjectAbsolute( cFile ), cFile, cRoot + cFile ) )

FUNCTION HBIDEProjectQuote( cArg )
   // Quote for Harbour's process argv parser, not for a shell.
   IF '"' $ cArg .OR. Chr(10) $ cArg .OR. Chr(13) $ cArg
      Break( "Invalid process argument" )
   ENDIF
#ifdef __PLATFORM__UNIX
   cArg := StrTran( cArg, "\", "\\" )
#endif
   RETURN '"' + cArg + '"'

FUNCTION HBIDEProjectTokens( cLine )
   LOCAL a := {}, c := "", lQuote := .F., lStarted := .F., i, ch
   FOR i := 1 TO Len( cLine )
      ch := SubStr( cLine, i, 1 )
      DO CASE
      CASE ch == '"'
         lQuote := ! lQuote
         lStarted := .T.
      CASE ( ch == " " .OR. ch == Chr(9) ) .AND. ! lQuote
         IF lStarted
            AAdd( a, c ); c := ""; lStarted := .F.
         ENDIF
      OTHERWISE
         c += ch
         lStarted := .T.
      ENDCASE
   NEXT
   IF lQuote
      RETURN NIL
   ENDIF
   IF lStarted
      AAdd( a, c )
   ENDIF
   RETURN a

FUNCTION HBIDEProjectDiagnostics( cOutput, cRoot )
   LOCAL a := {}, cLine, nOpen, nClose, cFile, cRow, cCol, cText, nColon, aPart, n
   LOCAL cLevel, h
   cOutput := StrTran( StrTran( cOutput, Chr(13) + Chr(10), Chr(10) ), Chr(13), Chr(10) )
   FOR EACH cLine IN hb_ATokens( cOutput, Chr(10) )
      cFile := ""; cRow := ""; cCol := ""; cText := ""
      // Harbour: path/name.prg(123) Error E0020 ...
      nClose := At( ")", cLine ); nOpen := RAt( "(", Left( cLine, nClose ) )
      IF nOpen > 1 .AND. nClose > nOpen
         cRow := SubStr( cLine, nOpen + 1, nClose - nOpen - 1 )
         IF HBIDEProjectDigits( cRow )
            cFile := AllTrim( Left( cLine, nOpen - 1 ) )
            cText := AllTrim( SubStr( cLine, nClose + 1 ) )
         ENDIF
      ENDIF
      IF Empty( cFile )
         // GCC/Clang: filename:line:column: error/warning. Drive colon is not a separator.
         aPart := hb_ATokens( cLine, ":" )
         FOR n := 2 TO Len( aPart ) - 1
            IF HBIDEProjectDigits( AllTrim( aPart[ n ] ) )
               cFile := aPart[ 1 ]
               FOR nColon := 2 TO n - 1
                  cFile += ":" + aPart[ nColon ]
               NEXT
               cRow := aPart[ n ]; nColon := n + 1
               IF HBIDEProjectDigits( AllTrim( aPart[ nColon ] ) )
                  cCol := aPart[ nColon ]; nColon++
               ENDIF
               cText := ""
               FOR nOpen := nColon TO Len( aPart )
                  cText += iif( Empty( cText ), "", ":" ) + aPart[ nOpen ]
               NEXT
               EXIT
            ENDIF
         NEXT
      ENDIF
      cLevel := iif( "ERROR" $ Upper( cText ), "error", iif( "WARNING" $ Upper( cText ), "warning", "" ) )
      IF ! Empty( cFile ) .AND. ! Empty( cLevel ) .AND. Val( cRow ) > 0
         h := { "path" => HBIDEProjectPath( cRoot, cFile ), "line" => Val( cRow ), ;
            "column" => Max( 1, Val( cCol ) ), "level" => cLevel, "text" => AllTrim( cText ), "raw" => cLine }
         AAdd( a, h )
      ENDIF
   NEXT
   RETURN a

FUNCTION HBIDEProjectDigits( c )
   LOCAL i
   IF Empty( c )
      RETURN .F.
   ENDIF
   FOR i := 1 TO Len( c )
      IF ! SubStr( c, i, 1 ) $ "0123456789"
         RETURN .F.
      ENDIF
   NEXT
   RETURN .T.

// Standard headers for the embedded compiler: honor explicit installation,
// then locate the Harbour installation of hbmk2 already selected by PATH.
FUNCTION HBIDECompilerInclude()
   LOCAL aRoots := {}, cRoot, cBin, n, cPath
   FOR EACH cRoot IN { GetEnv( "HB_INC_INSTALL" ), GetEnv( "HB_INCLUDE" ) }
      IF ! Empty( cRoot )
         AAdd( aRoots, cRoot )
      ENDIF
   NEXT
   FOR EACH cPath IN hb_ATokens( GetEnv( "PATH" ), hb_osPathListSeparator() )
      IF File( hb_DirSepAdd( cPath ) + "hbmk2" ) .OR. File( hb_DirSepAdd( cPath ) + "hbmk2.exe" )
         cBin := hb_DirSepAdd( cPath )
         FOR n := 1 TO 4
            AAdd( aRoots, hb_DirSepAdd( cBin ) + "include" )
            cBin := hb_PathNormalize( hb_DirSepAdd( cBin ) + ".." + hb_ps() )
         NEXT
         EXIT
      ENDIF
   NEXT
   FOR EACH cRoot IN aRoots
      cRoot := hb_DirSepAdd( cRoot )
      IF File( cRoot + "inkey.ch" ) .AND. File( cRoot + "hbclass.ch" ) .AND. File( cRoot + "std.ch" )
         RETURN cRoot
      ENDIF
   NEXT
RETURN ""

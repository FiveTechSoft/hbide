/*
 * mcvfs.prg - VFS routing and providers for the MC demo.
 *
 * See VFS.md for the architecture. Local paths never pass through this file
 * beyond MCVfsKind(); everything else is a VFS path:
 *
 *   /abs/path/archive.tar#utar/inner/path     extfs (archive-in-path)
 *   sftp://[user@]host[:port]/abs/path        SFTP (curl/libssh)
 *   sh://[user@]host[:port]/abs/path          shell link (ssh exec, FISH-style)
 *   ftp://host/path                           anonymous FTP (curl)
 *
 * All providers are read-only for now: browsing, viewing and copying OUT.
 * Writing, deleting and moving is refused with a message. Links are shown
 * but never followed anywhere (local policy, same as extfs).
 */

static s_cVfsErr := ""

//-----------------------------------------------------------------------------------------//

function MCVfsSetError( cMsg )

   s_cVfsErr := cMsg

return nil

//-----------------------------------------------------------------------------------------//

function MCVfsTakeError()

   local c := s_cVfsErr

   s_cVfsErr := ""

return c

//-----------------------------------------------------------------------------------------//

static function MCFirstLine( cText )

   local a := hb_ATokens( StrTran( hb_defaultValue( cText, "" ), Chr( 13 ), "" ), Chr( 10 ) )

return If( Len( a ) > 0, AllTrim( a[ 1 ] ), "" )

//-----------------------------------------------------------------------------------------//

function MCVfsKind( cPath )

   // scheme prefixes first: a "#utar/" inside a remote path is remote text,
   // never an archive marker
   if Left( cPath, 7 ) == "sftp://"
      return "sftp"
   endif
   if Left( cPath, 5 ) == "sh://"
      return "sh"
   endif
   if Left( cPath, 6 ) == "ftp://"
      return "ftp"
   endif
   if At( "#utar/", cPath ) > 0
      return "utar"
   endif
   if At( "#uzip/", cPath ) > 0
      return "uzip"
   endif

return "local"

//-----------------------------------------------------------------------------------------//

function MCVfsSplit( cPath )

   // -> { cScheme, cContainer, cInner } or nil for local paths.
   // extfs:  cContainer = local archive path, cInner = relative member path
   // remote: cContainer = [user@]host[:port], cInner = absolute remote path
   local cScheme := MCVfsKind( cPath ), n, cRest, cInner

   if cScheme == "local"
      return nil
   endif
   if cScheme == "utar" .or. cScheme == "uzip"
      n := At( "#" + cScheme + "/", cPath )
      cInner := SubStr( cPath, n + 6 )
      if Right( cInner, 1 ) == "/"
         cInner := Left( cInner, Len( cInner ) - 1 )
      endif
      return { cScheme, Left( cPath, n - 1 ), cInner }
   endif
   cRest := SubStr( cPath, Len( cScheme ) + 4 )   // after "://"
   n := At( "/", cRest )
   if n == 0
      return { cScheme, cRest, "/" }
   endif
   cInner := SubStr( cRest, n )
   if Len( cInner ) > 1 .and. Right( cInner, 1 ) == "/"
      cInner := Left( cInner, Len( cInner ) - 1 )
   endif

return { cScheme, Left( cRest, n - 1 ), cInner }

//-----------------------------------------------------------------------------------------//

static function MCVfsSplitHost( cHost )

   // [user@]host[:port] -> { cUser, cName, cPort }
   local cUser := "", cName := cHost, cPort := "", n

   if ( n := At( "@", cName ) ) > 0
      cUser := Left( cName, n - 1 )
      cName := SubStr( cName, n + 1 )
   endif
   if ( n := RAt( ":", cName ) ) > 0
      cPort := SubStr( cName, n + 1 )
      cName := Left( cName, n - 1 )
   endif

return { cUser, cName, cPort }

//-----------------------------------------------------------------------------------------//

function MCVfsParent( cPath )

   // parent directory of a VFS path: one level up inside the container, or
   // the container's own directory (extfs) / local root (remote) when
   // leaving it
   local a := MCVfsSplit( cPath ), cDir

   if a == nil
      return hb_FNameDir( cPath )
   endif
   if a[ 1 ] == "utar" .or. a[ 1 ] == "uzip"
      if Empty( a[ 3 ] )
         return hb_FNameDir( a[ 2 ] )
      endif
      return a[ 2 ] + "#" + a[ 1 ] + "/" + hb_FNameDir( a[ 3 ] )
   endif
   if a[ 3 ] == "/"
      return "/"
   endif
   cDir := hb_FNameDir( a[ 3 ] )   // "/tmp/" or "/"
   if cDir == "/"
      return a[ 1 ] + "://" + a[ 2 ] + "/"
   endif

return a[ 1 ] + "://" + a[ 2 ] + Left( cDir, Len( cDir ) - 1 )

//-----------------------------------------------------------------------------------------//

function MCVfsChild( cPath, cName )

   // join that never normalizes: scheme:// prefixes and #fragments survive
   if Right( cPath, 1 ) == "/"
      return cPath + cName
   endif

return cPath + "/" + cName

//-----------------------------------------------------------------------------------------//

function MCVfsArchiveScheme( cFile )

   // -> "utar" | "uzip" | "" by extension: which archives Enter should open
   local cL := Lower( cFile )

   if Right( cL, 4 ) == ".zip"
      return "uzip"
   endif
   if Right( cL, 4 ) == ".tar" .or. Right( cL, 7 ) == ".tar.gz" .or. ;
      Right( cL, 4 ) == ".tgz" .or. Right( cL, 8 ) == ".tar.bz2" .or. ;
      Right( cL, 5 ) == ".tbz2" .or. Right( cL, 7 ) == ".tar.xz"
      return "utar"
   endif

return ""

//-----------------------------------------------------------------------------------------//

function MCVfsList( cPath )

   // -> array of { name, size, date, time, attr, isDir } for the immediate
   // children of cPath, or nil on listing failure (caller keeps its state)
   local a := MCVfsSplit( cPath )

   if a == nil
      return nil
   endif
   do case
   case a[ 1 ] == "utar"
      return MCVfsTarList( a[ 2 ], a[ 3 ] )
   case a[ 1 ] == "uzip"
      return MCVfsZipList( a[ 2 ], a[ 3 ] )
   case a[ 1 ] == "sh"
      return MCVfsShList( a[ 2 ], a[ 3 ] )
   endcase

return MCVfsCurlList( a[ 1 ], a[ 2 ], a[ 3 ] )

//-----------------------------------------------------------------------------------------//

static function MCVfsTarList( cArchive, cInner )

   local cOut := "", aRet := {}, cLine, aT, cName, cRest, lDir
   local cPrefix := If( Empty( cInner ), "", cInner + "/" ), nPos

   if hb_ProcessRun( MCShWrap( "tar tvf " + ShellQuote( cArchive ) + " 2>/dev/null" ),, @cOut ) != 0
      return nil
   endif
   for each cLine in hb_ATokens( cOut, Chr( 10 ) )
      cLine := StrTran( cLine, Chr( 13 ), "" )
      aT := hb_ATokens( cLine )
      // -rw-r--r-- owner/group size yyyy-mm-dd hh:mm name [with spaces]
      if Len( aT ) < 6 .or. ! ( Left( aT[ 1 ], 1 ) $ "-dl" )
         loop
      endif
      nPos := At( aT[ 5 ], cLine ) + Len( aT[ 5 ] )
      cName := AllTrim( SubStr( cLine, nPos ) )
      if Left( cName, 2 ) == "./"
         cName := SubStr( cName, 3 )   // GNU tar stores "./name" for "tar cf arch ."
      endif
      if Left( aT[ 1 ], 1 ) == "l" .and. " -> " $ cName
         cName := Left( cName, At( " -> ", cName ) - 1 )   // shown, never followed
      endif
      if ! Empty( cPrefix ) .and. Left( cName, Len( cPrefix ) ) != cPrefix
         loop
      endif
      cRest := SubStr( cName, Len( cPrefix ) + 1 )
      lDir := Left( aT[ 1 ], 1 ) == "d"
      if Right( cRest, 1 ) == "/"
         lDir := .T.
         cRest := Left( cRest, Len( cRest ) - 1 )
      endif
      if Empty( cRest ) .or. "/" $ cRest
         loop   // the directory itself or a deeper level
      endif
      AAdd( aRet, { cRest, Val( aT[ 3 ] ), hb_SToD( StrTran( aT[ 4 ], "-", "" ) ), ;
                    aT[ 5 ], aT[ 1 ], lDir } )
   next

return aRet

//-----------------------------------------------------------------------------------------//

static function MCVfsZipList( cArchive, cInner )

   local cOut := "", aRet := {}, cLine, aT, cName, cRest, lDir
   local cPrefix := If( Empty( cInner ), "", cInner + "/" ), nPos

   if hb_ProcessRun( MCShWrap( "unzip -l " + ShellQuote( cArchive ) + " 2>/dev/null" ),, @cOut ) != 0
      return nil
   endif
   for each cLine in hb_ATokens( cOut, Chr( 10 ) )
      cLine := StrTran( cLine, Chr( 13 ), "" )
      aT := hb_ATokens( cLine )
      // size yyyy-mm-dd hh:mm name [with spaces]
      if Len( aT ) < 4 .or. ! IsDigit( Left( aT[ 1 ], 1 ) ) .or. At( "-", aT[ 2 ] ) == 0
         loop
      endif
      nPos := At( aT[ 3 ], cLine ) + Len( aT[ 3 ] )
      cName := AllTrim( SubStr( cLine, nPos ) )
      if ! Empty( cPrefix ) .and. Left( cName, Len( cPrefix ) ) != cPrefix
         loop
      endif
      cRest := SubStr( cName, Len( cPrefix ) + 1 )
      lDir := .F.
      if Right( cRest, 1 ) == "/"
         lDir := .T.
         cRest := Left( cRest, Len( cRest ) - 1 )
      endif
      if Empty( cRest ) .or. "/" $ cRest
         loop
      endif
      AAdd( aRet, { cRest, Val( aT[ 1 ] ), hb_SToD( StrTran( aT[ 2 ], "-", "" ) ), ;
                    aT[ 3 ], If( lDir, "D", "" ), lDir } )
   next

return aRet

//-----------------------------------------------------------------------------------------//

static function MCVfsShList( cHost, cDir )

   // shell link (FISH-style): listing through an ssh exec channel.
   // BatchMode: never prompts; a host that asks for a password fails fast
   // and the reason surfaces in the panel message.
   local cRemote := "ls -lA --time-style=long-iso -- " + ShellQuote( cDir )
   local cOut := "", cErr := "", aRet := {}, cLine, aT, cName
   local nPos, nPos2

   if hb_ProcessRun( MCShWrap( MCSSHBase( cHost ) + " " + ShellQuote( cRemote ) ),, @cOut, @cErr ) != 0
      MCVfsSetError( "ssh: " + MCFirstLine( cErr ) )
      return nil
   endif
   for each cLine in hb_ATokens( cOut, Chr( 10 ) )
      cLine := StrTran( cLine, Chr( 13 ), "" )
      aT := hb_ATokens( cLine )
      // -rw-r--r-- links owner group size yyyy-mm-dd hh:mm name [with spaces]
      if Len( aT ) < 8 .or. ! ( Left( aT[ 1 ], 1 ) $ "-dl" )
         loop
      endif
      nPos := At( aT[ 6 ], cLine )
      nPos2 := hb_At( aT[ 7 ], cLine, nPos + Len( aT[ 6 ] ) )
      if nPos == 0 .or. nPos2 == 0
         loop
      endif
      cName := AllTrim( SubStr( cLine, nPos2 + Len( aT[ 7 ] ) ) )
      if Left( aT[ 1 ], 1 ) == "l" .and. " -> " $ cName
         cName := Left( cName, At( " -> ", cName ) - 1 )   // shown, never followed
      endif
      if cName == "." .or. cName == ".."
         loop
      endif
      AAdd( aRet, { cName, Val( aT[ 5 ] ), hb_SToD( StrTran( aT[ 6 ], "-", "" ) ), ;
                    aT[ 7 ], aT[ 1 ], Left( aT[ 1 ], 1 ) == "d" } )
   next

return aRet

//-----------------------------------------------------------------------------------------//

static function MCVfsCurlList( cScheme, cHost, cDir )

   // sftp/ftp listing through curl. Credentials are never passed on the
   // command line: sftp rides the user's default ssh keys and known_hosts;
   // ftp is anonymous. stdin is closed so an unexpected password prompt
   // can never block the UI.
   local cUrl := cScheme + "://" + cHost + cDir
   local cOut := "", cErr := "", aRet := {}, cLine, aT, cName
   local nPos, cMM, cYear, cTime

   if Right( cUrl, 1 ) != "/"
      cUrl += "/"
   endif
   if hb_ProcessRun( MCShWrap( "timeout 60 curl -sS --max-time 55 " + ShellQuote( cUrl ) + ;
                               " < /dev/null" ),, @cOut, @cErr ) != 0
      MCVfsSetError( "curl: " + MCFirstLine( cErr ) )
      return nil
   endif
   for each cLine in hb_ATokens( cOut, Chr( 10 ) )
      cLine := StrTran( cLine, Chr( 13 ), "" )
      aT := hb_ATokens( cLine )
      // -rw-r--r-- links owner group size Mon DD [YYYY|HH:MM] name [with spaces]
      if Len( aT ) < 9 .or. ! ( Left( aT[ 1 ], 1 ) $ "-dl" )
         loop
      endif
      cMM := MCMonthNum( aT[ 6 ] )
      if Empty( cMM )
         loop
      endif
      nPos := hb_At( aT[ 8 ], cLine, At( aT[ 6 ], cLine ) )
      if nPos == 0
         loop
      endif
      cName := AllTrim( SubStr( cLine, nPos + Len( aT[ 8 ] ) ) )
      if Left( aT[ 1 ], 1 ) == "l" .and. " -> " $ cName
         cName := Left( cName, At( " -> ", cName ) - 1 )   // shown, never followed
      endif
      if cName == "." .or. cName == ".."
         loop
      endif
      if ":" $ aT[ 8 ]
         cYear := hb_ntos( Year( Date() ) )   // server omits the year for recent files
         cTime := aT[ 8 ]
      else
         cYear := aT[ 8 ]
         cTime := ""
      endif
      AAdd( aRet, { cName, Val( aT[ 5 ] ), hb_SToD( cYear + cMM + PadL( aT[ 7 ], 2, "0" ) ), ;
                    cTime, aT[ 1 ], Left( aT[ 1 ], 1 ) == "d" } )
   next

return aRet

//-----------------------------------------------------------------------------------------//

static function MCMonthNum( cMon )

   local n := AScan( { "Jan", "Feb", "Mar", "Apr", "May", "Jun", ;
                       "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }, { | c | c == cMon } )

return If( n == 0, "", PadL( hb_ntos( n ), 2, "0" ) )

//-----------------------------------------------------------------------------------------//

static function MCSSHBase( cHost )

   // common ssh command prefix for the shell link; auth (keys, known_hosts,
   // host aliases) comes from the user's ssh configuration, never from
   // command-line credentials
   local a := MCVfsSplitHost( cHost )
   local cCmd := "timeout 40 ssh -o BatchMode=yes -o ConnectTimeout=10"

   if ! Empty( a[ 3 ] )
      cCmd += " -p " + a[ 3 ]
   endif
   cCmd += " " + ShellQuote( If( Empty( a[ 1 ] ), a[ 2 ], a[ 1 ] + "@" + a[ 2 ] ) )

return cCmd

//-----------------------------------------------------------------------------------------//

static function MCVfsFetchFile( cScheme, cHost, cRemote, cDst )

   // one remote file -> local path; on failure the partial local file is
   // removed and the reason is available via MCVfsTakeError()
   local cCmd, cOut := "", cErr := ""

   if cScheme == "sh"
      cCmd := MCSSHBase( cHost ) + " " + ShellQuote( "cat -- " + ShellQuote( cRemote ) ) + ;
              " > " + ShellQuote( cDst )
   else
      cCmd := "timeout 120 curl -sS --max-time 110 " + ;
              ShellQuote( cScheme + "://" + cHost + cRemote ) + " -o " + ShellQuote( cDst ) + ;
              " < /dev/null"
   endif
   if hb_ProcessRun( MCShWrap( cCmd ),, @cOut, @cErr ) != 0
      FErase( cDst )
      MCVfsSetError( If( cScheme == "sh", "ssh: ", "curl: " ) + MCFirstLine( cErr ) )
      return .F.
   endif

return .T.

//-----------------------------------------------------------------------------------------//

static function MCVfsFetchTree( cScheme, cHost, cRemoteDir, cLocalDir )

   // recursive remote -> local materialization using only List + Fetch
   // (protocol-true: no shell assumptions for sftp/ftp). Any link inside
   // refuses the whole tree, fail-closed, same policy as extfs.
   local aList := MCVfsList( cScheme + "://" + cHost + cRemoteDir ), aE, cChild

   if aList == nil
      return .F.   // MCVfsTakeError() carries the reason
   endif
   for each aE in aList
      if Left( aE[ 5 ], 1 ) == "l"
         MCVfsSetError( "remote directory contains a link (" + aE[ 1 ] + ; 
                        "); links are not followed, copy cancelled" )
         return .F.
      endif
      cChild := hb_FNameMerge( cLocalDir, aE[ 1 ] )
      if aE[ 6 ]
         if hb_DirCreate( cChild ) != 0
            MCVfsSetError( "cannot create local directory: " + cChild )
            return .F.
         endif
         if ! MCVfsFetchTree( cScheme, cHost, MCVfsChild( cRemoteDir, aE[ 1 ] ), cChild )
            return .F.
         endif
      else
         if ! MCVfsFetchFile( cScheme, cHost, MCVfsChild( cRemoteDir, aE[ 1 ] ), cChild )
            return .F.
         endif
      endif
   next

return .T.

//-----------------------------------------------------------------------------------------//

function MCVfsStat( cPath )

   // -> one entry { name, size, date, time, attr, isDir } or nil
   local cParent, cBase, aList, aE

   if MCVfsKind( cPath ) == "local" .or. Right( cPath, 1 ) == "/"
      return nil   // a VFS container root is not an entry
   endif
   cParent := MCVfsParent( cPath )
   cBase   := hb_FNameNameExt( cPath )
   if Empty( cBase )
      return nil
   endif
   aList := MCVfsList( cParent )
   if aList != nil
      for each aE in aList
         if aE[ 1 ] == cBase
            return aE
         endif
      next
   endif

return nil

//-----------------------------------------------------------------------------------------//

function MCVfsTmpDir()

   // per-session scratch for extracted members; removed by MCVfsCleanup()
   static s_cDir := ""

   local nH, cName := ""

   if Empty( s_cDir )
      nH := hb_FTempCreate( "/tmp", "hbmcvfs",, @cName )
      if nH < 0
         return "/tmp"
      endif
      FClose( nH )
      FErase( cName )
      if hb_DirCreate( cName ) == 0
         s_cDir := cName
      else
         s_cDir := "/tmp"
      endif
   endif

return s_cDir

//-----------------------------------------------------------------------------------------//

function MCVfsCleanup()

   local cDir := MCVfsTmpDir()

   // NOTE: exact compare; with SET EXACT off "x" != "/tmp" would be a
   // prefix comparison and never true for dirs under /tmp.
   if !( cDir == "/tmp" )
      DeleteTree( cDir, .T. )
   endif

return nil

//-----------------------------------------------------------------------------------------//

function MCVfsExtract( cPath, cDstDir, lDir )

   // materializes the member named by cPath into a fresh wrap dir inside
   // cDstDir, keeping its name; -> { cExtractedPath, cWrapDir } or nil.
   // The caller deletes cWrapDir when done.
   local a := MCVfsSplit( cPath ), cWrap, cCmd, cOut := ""
   local nH, cName := "", cDst

   if a == nil .or. ( ( a[ 1 ] == "utar" .or. a[ 1 ] == "uzip" ) .and. Empty( a[ 3 ] ) )
      return nil
   endif
   nH := hb_FTempCreate( cDstDir, "hbx",, @cName )
   if nH < 0
      return nil
   endif
   FClose( nH )
   FErase( cName )
   if hb_DirCreate( cName ) != 0
      return nil
   endif
   cWrap := cName
   if a[ 1 ] == "sh" .or. a[ 1 ] == "sftp" .or. a[ 1 ] == "ftp"
      return MCVfsExtractRemote( a, cPath, cWrap, lDir )
   endif
   if a[ 1 ] == "utar"
      cCmd := "tar xf " + ShellQuote( a[ 2 ] ) + " -C " + ShellQuote( cWrap ) + ;
              " -- " + ShellQuote( a[ 3 ] + If( lDir, "/", "" ) ) + ;
              " 2>/dev/null || tar xf " + ShellQuote( a[ 2 ] ) + " -C " + ShellQuote( cWrap ) + ;
              " -- " + ShellQuote( "./" + a[ 3 ] + If( lDir, "/", "" ) ) + " 2>/dev/null"
   else
      cCmd := "cd " + ShellQuote( cWrap ) + " && unzip -o -q " + ShellQuote( a[ 2 ] ) + ;
              " " + ShellQuote( a[ 3 ] + If( lDir, "/*", "" ) ) + " 2>/dev/null"
   endif
   if hb_ProcessRun( MCShWrap( cCmd ),, @cOut ) != 0
      DeleteTree( cWrap, .T. )
      return nil
   endif
   cDst := hb_FNameMerge( cWrap, a[ 3 ] )
   if ! hb_FileExists( cDst ) .and. ! hb_DirExists( cDst )
      DeleteTree( cWrap, .T. )
      return nil
   endif

return { cDst, cWrap }

//-----------------------------------------------------------------------------------------//

static function MCVfsExtractRemote( a, cPath, cWrap, lDir )

   local cDst, aE

   if lDir
      cDst := hb_FNameMerge( cWrap, hb_FNameNameExt( a[ 3 ] ) )
      if Empty( hb_FNameNameExt( a[ 3 ] ) )
         cDst := cWrap   // remote root: fill the wrap itself
      elseif hb_DirCreate( cDst ) != 0
         MCVfsSetError( "cannot create local directory: " + cDst )
         DeleteTree( cWrap, .T. )
         return nil
      endif
      if ! MCVfsFetchTree( a[ 1 ], a[ 2 ], a[ 3 ], cDst )
         DeleteTree( cWrap, .T. )
         return nil
      endif
      return { cDst, cWrap }
   endif
   aE := MCVfsStat( cPath )
   if aE != nil .and. Left( aE[ 5 ], 1 ) == "l"
      MCVfsSetError( "remote entry is a link; links are not followed" )
      DeleteTree( cWrap, .T. )
      return nil
   endif
   cDst := hb_FNameMerge( cWrap, hb_FNameNameExt( a[ 3 ] ) )
   if ! MCVfsFetchFile( a[ 1 ], a[ 2 ], a[ 3 ], cDst )
      DeleteTree( cWrap, .T. )
      return nil
   endif

return { cDst, cWrap }

//-----------------------------------------------------------------------------------------//

function MCVfsViewFile( cPath )

   // view a VFS member through a materialized read-only copy
   local aX := MCVfsExtract( cPath, MCVfsTmpDir(), .F. ), cErr

   if aX == nil
      cErr := MCVfsTakeError()
      MCMsgBox( "VFS", "Cannot read:" + Chr( 10 ) + cPath + ;
                If( Empty( cErr ), "", Chr( 10 ) + "Reason: " + cErr ) )
      return nil
   endif
   if ! Empty( hb_FLinkRead( aX[ 1 ] ) )
      // a link member could point outside the archive; never follow it
      DeleteTree( aX[ 2 ], .T. )
      MCMsgBox( "VFS", "Archive member is a link and is not followed:" + Chr( 10 ) + cPath )
      return nil
   endif
   MCViewerText( cPath + "  (read-only, materialized copy)", MemoRead( aX[ 1 ] ) )
   DeleteTree( aX[ 2 ], .T. )

return nil

//-----------------------------------------------------------------------------------------//

function MCVfsCopy( cSrc, cDst, lConfirm, lAll, oApp )

   // cross-scheme copy: VFS -> local streams through a materialized temp
   // and reuses the verified local copy with its failure rollback; writing
   // into any VFS is refused (read-only providers)
   local aE, aX, lOk, cErr

   if MCVfsKind( cDst ) != "local"
      MCMsgBox( "Copy", "The " + MCVfsKind( cDst ) + " provider is read-only in this demo:" + Chr( 10 ) + ;
                "no writing, deleting or moving into it. Nothing changed." )
      return .F.
   endif
   aE := MCVfsStat( cSrc )
   if aE == nil
      MCMsgBox( "Copy", "Cannot read VFS member:" + Chr( 10 ) + cSrc )
      return .F.
   endif
   aX := MCVfsExtract( cSrc, MCVfsTmpDir(), aE[ 6 ] )
   if aX == nil
      cErr := MCVfsTakeError()
      MCMsgBox( "Copy", "Cannot read:" + Chr( 10 ) + cSrc + ;
                If( Empty( cErr ), "", Chr( 10 ) + "Reason: " + cErr ) )
      return .F.
   endif
   lOk := CopyItem( aX[ 1 ], cDst, lConfirm, @lAll, oApp )
   DeleteTree( aX[ 2 ], .T. )

return lOk

//-----------------------------------------------------------------------------------------//

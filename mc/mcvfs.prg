/*
 * mcvfs.prg - VFS routing and the extfs (archive) provider for the MC demo.
 *
 * See VFS.md for the architecture. Local paths never pass through this file
 * beyond MCVfsKind(); everything else is a VFS path of the form
 * /abs/path/archive.tar#utar/inner/path (or #uzip/). extfs is read-only for
 * now: browsing, viewing and copying OUT of archives; writing, deleting and
 * moving to or from archives is refused with a message.
 */

//-----------------------------------------------------------------------------------------//

function MCVfsKind( cPath )

   if At( "#utar/", cPath ) > 0
      return "utar"
   endif
   if At( "#uzip/", cPath ) > 0
      return "uzip"
   endif

return "local"

//-----------------------------------------------------------------------------------------//

function MCVfsSplit( cPath )

   // -> { cScheme, cArchive, cInner } ; cInner has no leading or trailing "/"
   local n := At( "#utar/", cPath ), cScheme := "utar", cInner

   if n == 0
      n := At( "#uzip/", cPath )
      cScheme := "uzip"
   endif
   if n == 0
      return nil
   endif
   cInner := SubStr( cPath, n + 6 )
   if Right( cInner, 1 ) == "/"
      cInner := Left( cInner, Len( cInner ) - 1 )
   endif

return { cScheme, Left( cPath, n - 1 ), cInner }

//-----------------------------------------------------------------------------------------//

function MCVfsParent( cPath )

   // parent directory of a VFS path: one level up inside the archive, or the
   // archive's own directory when leaving it
   local a := MCVfsSplit( cPath )

   if a == nil
      return hb_FNameDir( cPath )
   endif
   if Empty( a[ 3 ] )
      return hb_FNameDir( a[ 2 ] )
   endif

return a[ 2 ] + "#" + a[ 1 ] + "/" + hb_FNameDir( a[ 3 ] )

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
   if a[ 1 ] == "utar"
      return MCVfsTarList( a[ 2 ], a[ 3 ] )
   endif

return MCVfsZipList( a[ 2 ], a[ 3 ] )

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

function MCVfsStat( cPath )

   // -> one entry { name, size, date, time, attr, isDir } or nil
   local a := MCVfsSplit( cPath ), cBase, cParent, aE, aList

   if a == nil .or. Empty( a[ 3 ] )
      return nil
   endif
   cBase   := hb_FNameNameExt( a[ 3 ] )
   cParent := a[ 2 ] + "#" + a[ 1 ] + "/" + hb_FNameDir( a[ 3 ] )
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

   if cDir != "/tmp"
      DeleteTree( cDir )
   endif

return nil

//-----------------------------------------------------------------------------------------//

function MCVfsExtract( cPath, cDstDir, lDir )

   // extracts the member named by cPath into a fresh wrap dir inside cDstDir,
   // keeping its inner path; -> { cExtractedPath, cWrapDir } or nil.
   // The caller deletes cWrapDir when done.
   local a := MCVfsSplit( cPath ), cWrap, cCmd, cOut := ""
   local nH, cName := "", cDst

   if a == nil .or. Empty( a[ 3 ] )
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
   if a[ 1 ] == "utar"
      cCmd := "tar xf " + ShellQuote( a[ 2 ] ) + " -C " + ShellQuote( cWrap ) + ;
              " -- " + ShellQuote( a[ 3 ] + If( lDir, "/", "" ) ) + ;
              " 2>/dev/null || tar xf " + ShellQuote( a[ 2 ] ) + " -C " + ShellQuote( cWrap ) + ;
              " -- " + ShellQuote( "./" + a[ 3 ] + If( lDir, "/", "" ) ) + " 2>/dev/null"
   else
      cCmd := "cd " + ShellQuote( cWrap ) + " && unzip -o -q " + ShellQuote( a[ 2 ] ) + ;
              " " + ShellQuote( a[ 3 ] + If( lDir, "/*", "" ) )
   endif
   if hb_ProcessRun( MCShWrap( cCmd ),, @cOut ) != 0
      DeleteTree( cWrap )
      return nil
   endif
   cDst := hb_FNameMerge( cWrap, a[ 3 ] )
   if ! hb_FileExists( cDst ) .and. ! hb_DirExists( cDst )
      DeleteTree( cWrap )
      return nil
   endif

return { cDst, cWrap }

//-----------------------------------------------------------------------------------------//

function MCVfsViewFile( cPath )

   // view an archive member through an extracted read-only copy
   local aX := MCVfsExtract( cPath, MCVfsTmpDir(), .F. )

   if aX == nil
      MCMsgBox( "VFS", "Cannot extract:" + Chr( 10 ) + cPath )
      return nil
   endif
   if ! Empty( hb_FLinkRead( aX[ 1 ] ) )
      // a link member could point outside the archive; never follow it
      DeleteTree( aX[ 2 ] )
      MCMsgBox( "VFS", "Archive member is a link and is not followed:" + Chr( 10 ) + cPath )
      return nil
   endif
   MCViewerText( cPath + "  (read-only, extracted copy)", MemoRead( aX[ 1 ] ) )
   DeleteTree( aX[ 2 ] )

return nil

//-----------------------------------------------------------------------------------------//

function MCVfsCopy( cSrc, cDst, lConfirm, lAll, oApp )

   // cross-scheme copy: extfs -> local streams through an extracted temp and
   // reuses the verified local copy with its failure rollback; writing into
   // archives is refused
   local aE, aX, lOk

   if MCVfsKind( cDst ) != "local"
      MCMsgBox( "Copy", "Writing into archives is not supported yet (read-only VFS)." + Chr( 10 ) + ;
                "Nothing changed." )
      return .F.
   endif
   aE := MCVfsStat( cSrc )
   if aE == nil
      MCMsgBox( "Copy", "Cannot read archive member:" + Chr( 10 ) + cSrc )
      return .F.
   endif
   aX := MCVfsExtract( cSrc, MCVfsTmpDir(), aE[ 6 ] )
   if aX == nil
      MCMsgBox( "Copy", "Cannot extract:" + Chr( 10 ) + cSrc )
      return .F.
   endif
   lOk := CopyItem( aX[ 1 ], cDst, lConfirm, @lAll, oApp )
   DeleteTree( aX[ 2 ] )

return lOk

//-----------------------------------------------------------------------------------------//

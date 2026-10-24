//-----------------------------------------------------------------------------------------//
// mcarcwrite.prg - write support for the uzip/utar extfs providers.
//
// Strategy: never edit an archive in place. ZIP additions go through a
// staging tree merged by Info-ZIP; TAR (a pure stream) is extracted into a
// staging tree, changed there, and repacked. The original archive is
// backed up next to itself (.hbbak) and restored on any failure, so an
// interrupted or failed write never leaves a half-written archive.
// Only local -> archive is routed here; remote/archive sources stay
// refused. Links inside staging are never followed (CopyItem semantics).
//
// License: same as hbide (GPLv3)
//-----------------------------------------------------------------------------------------//

static function MCTarCompFlag( cArchive )

   local c := Lower( cArchive )

   if Right( c, 7 ) == ".tar.gz" .or. Right( c, 4 ) == ".tgz"
      return "z"
   endif
   if Right( c, 8 ) == ".tar.bz2" .or. Right( c, 5 ) == ".tbz2"
      return "j"
   endif
   if Right( c, 7 ) == ".tar.xz" .or. Right( c, 4 ) == ".txz"
      return "J"
   endif

return ""

//-----------------------------------------------------------------------------------------//

static function MCStageDir( cParent )

   // fresh empty staging dir inside cParent, like MCVfsExtract's wrap
   local cName := "", nH := hb_FTempCreate( cParent, "hbs",, @cName )

   if nH < 0
      return nil
   endif
   FClose( nH )
   FErase( cName )
   if hb_DirCreate( cName ) != 0
      return nil
   endif

return cName

//-----------------------------------------------------------------------------------------//

// Repack the staging tree over the archive with backup/rollback.
static function MCTarRepack( cArchive, cTree )

   local cBak := cArchive + ".hbbak", cOut := ""
   local cFlag := MCTarCompFlag( cArchive ), lOk

   if hb_FileExists( cBak )
      // A leftover backup means a previous repack failed and nobody has
      // inspected it yet. Never overwrite it silently: it may be the only
      // copy of that earlier original.
      MCVfsSetError( "backup from a previous failed repack exists:" + Chr( 10 ) + cBak + ;
                     Chr( 10 ) + "Inspect or remove it first. Nothing changed." )
      return .F.
   endif
   if hb_FileExists( cArchive )
      if hb_ProcessRun( MCShWrap( "cp -p " + ShellQuote( cArchive ) + " " + ShellQuote( cBak ) + " 2>/dev/null" ) ) != 0
         MCVfsSetError( "cannot create backup copy" )
         return .F.
      endif
   endif
   lOk := hb_ProcessRun( MCShWrap( "cd " + ShellQuote( cTree ) + " && tar -c" + cFlag + ;
          " -f " + ShellQuote( cArchive + ".hbtmp" ) + " . 2>/dev/null && tar -t" + cFlag + ;
          " -f " + ShellQuote( cArchive + ".hbtmp" ) + " >/dev/null 2>&1" ) ) == 0
   if lOk
      lOk := hb_ProcessRun( MCShWrap( "mv " + ShellQuote( cArchive + ".hbtmp" ) + " " + ShellQuote( cArchive ) + " 2>/dev/null" ) ) == 0
   endif
   FErase( cArchive + ".hbtmp" )
   if lOk
      FErase( cBak )
   else
      // The archive itself is never opened for writing (we write .hbtmp
      // and rename over it), so on failure the original is still
      // byte-identical. Keep the backup for inspection; if the archive
      // somehow vanished, try to put the backup back in place.
      if hb_FileExists( cBak )
         if ! hb_FileExists( cArchive )
            hb_ProcessRun( MCShWrap( "mv " + ShellQuote( cBak ) + " " + ShellQuote( cArchive ) + " 2>/dev/null" ) )
            MCVfsSetError( "repack failed; original restored from backup" )
         else
            MCVfsSetError( "repack failed; original archive untouched, backup kept at " + cBak )
         endif
      else
         MCVfsSetError( "repack failed before backup; original archive untouched" )
      endif
   endif

return lOk

//-----------------------------------------------------------------------------------------//

// Extract the archive into cTree (tolerate a not-yet-existing archive).
static function MCTarUnpack( cArchive, cTree )

   local cFlag := MCTarCompFlag( cArchive )

   if ! hb_FileExists( cArchive )
      return .T.
   endif
   if hb_ProcessRun( MCShWrap( "tar -x" + cFlag + " -f " + ShellQuote( cArchive ) + ;
      " -C " + ShellQuote( cTree ) + " 2>/dev/null" ) ) != 0
      MCVfsSetError( "cannot extract archive for rewrite" )
      return .F.
   endif

return .T.

//-----------------------------------------------------------------------------------------//

// Add one local item into an archive member directory.
// cDstUrl = <archive>#uzip|utar/<inner dir>/<name>; cSrc = local path.
function MCVfsArchiveAdd( cDstUrl, cSrc )

   local a := MCVfsSplit( cDstUrl ), lDir := hb_DirExists( cSrc )
   local cWrap, cTree, cInnerDir, cName, cTop, cCmd, cOut := "", lOk := .F.
   local lDstIsDir := Right( cDstUrl, 1 ) == "/"

   if a == nil .or. ! ( a[ 1 ] == "uzip" .or. a[ 1 ] == "utar" )
      return .F.
   endif
   // A trailing slash names a member directory (the F5 dialog offers the
   // panel URL with one): the item keeps its own name inside it. Without
   // it the url is the full member path (rename-while-copy).
   cName := If( lDstIsDir, hb_FNameNameExt( cSrc ), hb_FNameNameExt( cDstUrl ) )
   cInnerDir := If( lDstIsDir, a[ 3 ], hb_FNameDir( a[ 3 ] ) )
   if cInnerDir == "/"
      cInnerDir := ""
   endif
   cWrap := MCStageDir( MCVfsTmpDir() )
   if cWrap == nil
      MCVfsSetError( "cannot create staging directory" )
      return .F.
   endif
   cTree := hb_FNameMerge( cWrap, "tree" )
   hb_DirCreate( cTree )
   if a[ 1 ] == "utar" .and. ! MCTarUnpack( a[ 2 ], cTree )
      DeleteTree( cWrap, .T. )
      return .F.
   endif
   // place the item at its member path inside the staging tree
   if ! Empty( cInnerDir ) .and. ;
      hb_ProcessRun( MCShWrap( "mkdir -p " + ShellQuote( hb_FNameMerge( cTree, cInnerDir ) ) + " 2>/dev/null" ) ) != 0 .and. ;
      ! hb_DirExists( hb_FNameMerge( cTree, cInnerDir ) )
      MCVfsSetError( "cannot stage inner directory" )
      DeleteTree( cWrap, .T. )
      return .F.
   endif
   if ! CopyItem( cSrc, hb_FNameMerge( cTree, If( Empty( cInnerDir ), cName, cInnerDir + "/" + cName ) ), .F., nil, nil )
      MCVfsSetError( "cannot stage item" )
      DeleteTree( cWrap, .T. )
      return .F.
   endif
   if a[ 1 ] == "utar"
      lOk := MCTarRepack( a[ 2 ], cTree )
   else
      // zip merges a subtree into the existing archive
      cTop := If( Empty( cInnerDir ), cName, SubStr( cInnerDir, 1, At( "/", cInnerDir + "/" ) - 1 ) )
      cCmd := "cd " + ShellQuote( cTree ) + " && zip -q -r " + ShellQuote( a[ 2 ] ) + ;
              " -- " + ShellQuote( cTop ) + " 2>/dev/null"
      lOk := hb_ProcessRun( MCShWrap( cCmd ),, @cOut ) == 0
      if ! lOk
         MCVfsSetError( "zip update failed" )
      endif
   endif
   DeleteTree( cWrap, .T. )

return lOk

//-----------------------------------------------------------------------------------------//

// Delete members (files or dir subtrees) of the archive shown at cPanelUrl.
function MCVfsArchiveDelete( cPanelUrl, aNames )

   local a := MCVfsSplit( cPanelUrl ), cWrap, cTree, cName, cInner, cCmd, lOk := .T.
   local cOut := ""

   if a == nil .or. ! ( a[ 1 ] == "uzip" .or. a[ 1 ] == "utar" )
      return .F.
   endif
   if a[ 1 ] == "uzip"
      cInner := If( Empty( a[ 3 ] ), "", a[ 3 ] + "/" )
      for each cName in aNames
         // delete both the entry and, for directories, its subtree
         cCmd := "zip -q -d " + ShellQuote( a[ 2 ] ) + " -- " + ;
                 ShellQuote( cInner + cName ) + " " + ShellQuote( cInner + cName + "/" ) + ;
                 " " + ShellQuote( cInner + cName + "/*" ) + " 2>/dev/null"
         if hb_ProcessRun( MCShWrap( cCmd ),, @cOut ) != 0
            lOk := .F.
         endif
      next
      return lOk
   endif
   // tar: rewrite without the members
   cWrap := MCStageDir( MCVfsTmpDir() )
   if cWrap == nil
      MCVfsSetError( "cannot create staging directory" )
      return .F.
   endif
   cTree := hb_FNameMerge( cWrap, "tree" )
   hb_DirCreate( cTree )
   if ! MCTarUnpack( a[ 2 ], cTree )
      DeleteTree( cWrap, .T. )
      return .F.
   endif
   cInner := If( Empty( a[ 3 ] ), "", a[ 3 ] + "/" )
   for each cName in aNames
      if ! DeleteTree( hb_FNameMerge( cTree, cInner + cName ), .T. )
         FErase( hb_FNameMerge( cTree, cInner + cName ) )
      endif
   next
   lOk := MCTarRepack( a[ 2 ], cTree )
   DeleteTree( cWrap, .T. )

return lOk

//-----------------------------------------------------------------------------------------//

// Create a directory member inside the archive shown at cPanelUrl.
function MCVfsArchiveMkdir( cPanelUrl, cName )

   local a := MCVfsSplit( cPanelUrl ), cWrap, cTree, cInner, cTop, cCmd, lOk := .F.
   local cOut := ""

   if a == nil .or. ! ( a[ 1 ] == "uzip" .or. a[ 1 ] == "utar" )
      return .F.
   endif
   cWrap := MCStageDir( MCVfsTmpDir() )
   if cWrap == nil
      MCVfsSetError( "cannot create staging directory" )
      return .F.
   endif
   cTree := hb_FNameMerge( cWrap, "tree" )
   hb_DirCreate( cTree )
   if a[ 1 ] == "utar" .and. ! MCTarUnpack( a[ 2 ], cTree )
      DeleteTree( cWrap, .T. )
      return .F.
   endif
   cInner := If( Empty( a[ 3 ] ), "", a[ 3 ] + "/" )
   if hb_ProcessRun( MCShWrap( "mkdir -p " + ShellQuote( hb_FNameMerge( cTree, cInner + cName ) ) + " 2>/dev/null" ) ) != 0
      MCVfsSetError( "cannot stage directory" )
      DeleteTree( cWrap, .T. )
      return .F.
   endif
   if a[ 1 ] == "utar"
      lOk := MCTarRepack( a[ 2 ], cTree )
   else
      cTop := If( Empty( a[ 3 ] ), cName, SubStr( a[ 3 ], 1, At( "/", a[ 3 ] + "/" ) - 1 ) )
      cCmd := "cd " + ShellQuote( cTree ) + " && zip -q -r " + ShellQuote( a[ 2 ] ) + ;
              " -- " + ShellQuote( cTop ) + " 2>/dev/null"
      lOk := hb_ProcessRun( MCShWrap( cCmd ),, @cOut ) == 0
      if ! lOk
         MCVfsSetError( "zip update failed" )
      endif
   endif
   DeleteTree( cWrap, .T. )

return lOk

//-----------------------------------------------------------------------------------------//

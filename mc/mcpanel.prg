/*
 * mcpanel.prg - MCPanel: one file panel of the Commander
 */

#include "hbclass.ch"
#include "inkey.ch"
#include "mc.ch"

REQUEST HB_CODEPAGE_ES850, HB_CODEPAGE_CS852, HB_CODEPAGE_RU866, HB_CODEPAGE_RU1251
REQUEST HB_CODEPAGE_ESWIN, HB_CODEPAGE_ESISO, HB_CODEPAGE_CSISO

/* Panel display charsets (real mc: Alt-e recodes panel display into the
 * system codepage; "No translation" cancels). id "" means no translation.
 * Display-only: file operations always use the raw filesystem bytes. */

function MCCpList()

return { { "No translation", "" }, ;
         { "UTF-8",          "UTF8"  }, ;
         { "CP437",          "EN"    }, ;
         { "CP850",          "ES850" }, ;
         { "CP852",          "CS852" }, ;
         { "CP866",          "RU866" }, ;
         { "CP1251",         "RU1251" }, ;
         { "CP1252",         "ESWIN" }, ;
         { "ISO-8859-1",     "ESISO" }, ;
         { "ISO-8859-2",     "CSISO" } }

function MCCpValid( cId )

return AScan( MCCpList(), { | a | a[ 2 ] == cId } ) > 0

function MCCpDecode( cText, cId )

   local cOut

   if Empty( cId ) .or. cId == "UTF8"
      return cText
   endif
   begin sequence with { | e | break( e ) }
      cOut := hb_StrToUTF8( cText, cId )
   recover
      cOut := cText          // unknown/broken id: show raw bytes, never crash
   end sequence

return cOut
#include "directry.ch"
#include "fileio.ch"

//-----------------------------------------------------------------------------------------//

CLASS MCPanel

   DATA   cPath
   DATA   aFiles      INIT {}
   DATA   hStat       INIT { => }   // name => { nAtime, nCtime, nInode, cAtimeStr, cCtimeStr }, filled lazily
   DATA   hLinks      INIT { => }   // name => symlink target, filled by Rescan (local fs only)
   DATA   nDirMTime   INIT 0      // dir mtime at last scan (fast dir reload check)
   DATA   nCurrent    INIT 1
   DATA   nOffset     INIT 0
   DATA   nTop        INIT 1
   DATA   nLeft       INIT 0
   DATA   nBottom     INIT 37
   DATA   nRight      INIT 59
   DATA   lActive     INIT .F.
   DATA   cSort       INIT "name"
   DATA   lReverse    INIT .F.
   DATA   lCaseSens   INIT .F.
   DATA   cFilter     INIT "*"
   DATA   cCp         INIT ""        // display charset id (MCCpList); "" = no translation
   DATA   lBrief      INIT .F.
   DATA   cListMode   INIT "full"     // full | brief | long | user
   DATA   cUserFmt    INIT "half name | size"
   DATA   lUserMiniStatus INIT .F.
   DATA   hLong       INIT { => }   // name => { cPerms, cNlink, cOwner, cGroup }, lazy, local only
   DATA   cMode       INIT "listing"   // listing | quickview | info | tree | panelize
   DATA   aTree       INIT {}
   DATA   oApp
   DATA   aDirSizes   INIT { => }
   DATA   lSizesComputed INIT .F.

   METHOD New( cPath )
   METHOD SetPos( nT, nL, nB, nR )
   METHOD Export()
   METHOD Import( a )
   METHOD Rescan()
   METHOD ReloadIfChanged()
   METHOD DirMTime()
   METHOD GoDir( cPath )
   METHOD SortFiles()
   METHOD FillStat()
   METHOD FillLong()
   METHOD EntryLong( aEntry, nWidth )
   METHOD EntryUser( aEntry, nWidth )
   METHOD Display()
   METHOD DisplayListing()
   METHOD DisplayQuickView()
   METHOD DisplayInfo()
   METHOD DisplayTree()
   METHOD EntryLine( aEntry, nWidth )
   METHOD EntryColor( aEntry, lOnBar )
   METHOD TitleText()
   METHOD MiniStatus()
   METHOD VisibleRows() INLINE ::nBottom - ::nTop - 3
   METHOD RowToIndex( nRow, nCol )
   METHOD BriefLayout()          // -> { nColW, nCols } for multi-column brief
   METHOD PageSize()             // visible entries: rows, or cols*rows in brief
   METHOD FixScroll()
   METHOD Scroll( nDelta )
   METHOD Move( nKey )
   METHOD Current()
   METHOD MarkCurrent()
   METHOD MarkedEntries()
   METHOD EnterKey()
   METHOD LynxEnter()
   METHOD LynxUp()
   METHOD QuickSearch()
   METHOD ComputeDirSizes()
   METHOD DirSize( cPath, nLevel )
   METHOD SelectName( cName )

ENDCLASS

//-----------------------------------------------------------------------------------------//

METHOD New( cPath ) CLASS MCPanel

   ::cPath := hb_PathNormalize( cPath )

return Self

//-----------------------------------------------------------------------------------------//

METHOD SetPos( nT, nL, nB, nR ) CLASS MCPanel

   ::nTop    := nT
   ::nLeft   := nL
   ::nBottom := nB
   ::nRight  := nR
   ::FixScroll()

return nil

//-----------------------------------------------------------------------------------------//

METHOD Export() CLASS MCPanel

return { ::cPath, ::aFiles, ::nCurrent, ::nOffset, ::cSort, ::lReverse, ;
         ::lCaseSens, ::cFilter, ::lBrief, ::cMode, ::aDirSizes, ::lSizesComputed, ;
         ::hLinks, ::cListMode, ::cUserFmt, ::lUserMiniStatus }

//-----------------------------------------------------------------------------------------//

METHOD Import( a ) CLASS MCPanel

   ::cPath     := a[ 1 ]
   ::aFiles    := a[ 2 ]
   ::nCurrent  := a[ 3 ]
   ::nOffset   := a[ 4 ]
   ::cSort     := a[ 5 ]
   ::lReverse  := a[ 6 ]
   ::lCaseSens := a[ 7 ]
   ::cFilter   := a[ 8 ]
   ::lBrief    := a[ 9 ]
   ::cMode     := a[ 10 ]
   ::aDirSizes := a[ 11 ]
   ::lSizesComputed := a[ 12 ]
   ::hLinks := If( Len( a ) >= 13, a[ 13 ], { => } )
   ::cListMode := If( Len( a ) >= 14, a[ 14 ], If( ::lBrief, "brief", "full" ) )
   ::cUserFmt := If( Len( a ) >= 15, a[ 15 ], "half name | size" )
   ::lUserMiniStatus := If( Len( a ) >= 16, a[ 16 ], .F. )
   ::FixScroll()

return nil

//-----------------------------------------------------------------------------------------//

METHOD GoDir( cPath ) CLASS MCPanel

   local cErr

   if MCVfsKind( cPath ) != "local"
      if MCVfsList( cPath ) == nil
         cErr := MCVfsTakeError()
         MCMsgBox( "VFS", "Cannot list:" + Chr( 10 ) + cPath + ;
                   If( Empty( cErr ), "", Chr( 10 ) + "Reason: " + cErr ) + Chr( 10 ) + ;
                   "Staying in the current directory." )
         return nil
      endif
      ::cPath := cPath   // VFS paths are absolute by construction; normalize would mangle "scheme://"
   else
      if ! ::oApp:lCdFollowsLinks
         ::cPath := MCRealPath( cPath )
      else
         ::cPath := hb_PathNormalize( cPath )
      endif
   endif
   ::cMode     := "listing"
   ::nCurrent  := 1
   ::nOffset   := 0
   ::aDirSizes := { => }
   ::Rescan()

return nil

//-----------------------------------------------------------------------------------------//

METHOD DirMTime() CLASS MCPanel

   local cOut := ""

   if hb_ProcessRun( MCShWrap( "stat -c %Y -- " + ShellQuote( ::cPath ) ),, @cOut ) == 0
      return Val( AllTrim( cOut ) )
   endif

return 0

//-----------------------------------------------------------------------------------------//

METHOD ReloadIfChanged() CLASS MCPanel

   // mc "fast dir reload" OFF: entering this panel re-reads the dir when
   // its mtime changed since the last scan; ON: only C-r rescans
   if ::cMode == "panelize" .or. ::cMode == "tree"
      return nil
   endif
   if MCVfsKind( ::cPath ) != "local"
      return nil
   endif
   if ::DirMTime() != ::nDirMTime
      ::Rescan()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD Rescan() CLASS MCPanel

   local aDir, aEntry, cFull
   local lShowHidden := ::oApp:lShowHidden
   local aNames, cCmd, cOut := "", aModes, n, cName, cMode

   ::hStat  := { => }
   ::hLinks := { => }
   ::hLong  := { => }

   if ::cMode == "panelize"
      return nil   // panelize content is managed by the panelize action
   endif

   if MCVfsKind( ::cPath ) != "local"
      ::aFiles := {}
      ::lSizesComputed := .F.
      AAdd( ::aFiles, { "/..", 0, CToD( "" ), "", "D", .T., .F. } )
      aDir := MCVfsList( ::cPath )
      if aDir == nil
         ::SortFiles()
         ::FixScroll()
         return nil
      endif
      for each aEntry in aDir
         if ! lShowHidden .and. Left( aEntry[ 1 ], 1 ) == "."
            loop
         endif
         if aEntry[ 6 ] .or. FilterMatch( aEntry[ 1 ], ::cFilter, ::lCaseSens, ::oApp:lShellPatterns )
            AAdd( ::aFiles, { aEntry[ 1 ], aEntry[ 2 ], aEntry[ 3 ], aEntry[ 4 ], ;
                              aEntry[ 5 ], aEntry[ 6 ], .F. } )
         endif
      next
      ::SortFiles()
      ::FixScroll()
      return nil
   endif

   ::aFiles := {}
   ::lSizesComputed := .F.
   AAdd( ::aFiles, { "/..", 0, CToD( "" ), "", "D", .T., .F. } )

   aDir := Directory( hb_DirSepAdd( ::cPath ) + "*", "DHS" )
   for each aEntry in aDir
      if aEntry[ F_NAME ] == "." .or. aEntry[ F_NAME ] == ".."
         loop
      endif
      if ! lShowHidden .and. Left( aEntry[ F_NAME ], 1 ) == "."
         loop
      endif
      if ! ::oApp:lShowBackup .and. Right( aEntry[ F_NAME ], 1 ) == "~"
         loop
      endif
      cFull := hb_FNameMerge( ::cPath, aEntry[ F_NAME ] )
      if "L" $ aEntry[ F_ATTR ]
         ::hLinks[ aEntry[ F_NAME ] ] := MCLinkTarget( cFull )
      endif
      if hb_DirExists( cFull )
         AAdd( ::aFiles, { aEntry[ F_NAME ], 0, aEntry[ F_DATE ], aEntry[ F_TIME ], ;
                           aEntry[ F_ATTR ], .T., .F. } )
      else
         if FilterMatch( aEntry[ F_NAME ], ::cFilter, ::lCaseSens, ::oApp:lShellPatterns )
            AAdd( ::aFiles, { aEntry[ F_NAME ], aEntry[ F_SIZE ], aEntry[ F_DATE ], ;
                              aEntry[ F_TIME ], aEntry[ F_ATTR ], .F., .F. } )
         endif
      endif
   next

   // file type highlight: one stat pass marks executables (local fs only);
   // order of stat output lines follows the argument order
   if ::oApp:lFileTypes
      aNames := {}
      for each aEntry in ::aFiles
         if ! aEntry[ P_DIR ]
            AAdd( aNames, aEntry[ P_NAME ] )
         endif
      next
      if ! Empty( aNames )
         cCmd := "for f in"
         for each cName in aNames
            cCmd += " " + ShellQuote( hb_FNameMerge( ::cPath, cName ) )
         next
         // -L: exec if the TARGET is executable (a symlink itself is 777);
         // the loop prints 'x' for unresolvable names so lines stay aligned
         cCmd += '; do stat -c %a -L -- "$f" 2>/dev/null || echo x; done'
         if Len( cCmd ) < 8000 .and. hb_ProcessRun( MCShWrap( cCmd ),, @cOut ) == 0
            aModes := hb_ATokens( cOut, hb_eol() )
            n := 0
            for each aEntry in ::aFiles
               if ! aEntry[ P_DIR ]
                  n++
                  if n <= Len( aModes )
                     cMode := AllTrim( aModes[ n ] )
                     if "1" $ cMode .or. "3" $ cMode .or. "5" $ cMode .or. "7" $ cMode
                        AAdd( aEntry, .T. )   // P_EXEC
                     endif
                  endif
               endif
            next
         endif
      endif
   endif

   if ::oApp:lComputeTotals
      ::ComputeDirSizes()
   endif
   ::SortFiles()
   ::FixScroll()
   ::nDirMTime := ::DirMTime()

return nil

//-----------------------------------------------------------------------------------------//

METHOD FillStat() CLASS MCPanel

   // atime/ctime/inode are not in Harbour's Directory(): fetch them on
   // demand with ONE batched stat call (local panels only; VFS providers
   // do not carry these fields and compare equal, falling back to name).
   local aNames := {}, a, cOut := "", cCmd := "", aLines, aT, n, nMax
   local lRetry := .F.

   for each a in ::aFiles
      if a[ P_NAME ] != "/.." .and. ! hb_HHasKey( ::hStat, a[ P_NAME ] )
         AAdd( aNames, a[ P_NAME ] )
      endif
   next
   if Empty( aNames )
      return nil
   endif
   // stat output lines follow the argument order, so names never appear
   // in the output and no quoting inside a name can break the mapping
   for each a in aNames
      cCmd += " " + ShellQuote( a )
   next
   if hb_ProcessRun( MCShWrap( "cd " + ShellQuote( ::cPath ) + ;
          " && stat -c '%i|%X|%Z|%x|%z' --" + cCmd + " 2>/dev/null" ),, @cOut ) != 0
      return nil
   endif
   aLines := hb_ATokens( cOut, Chr( 10 ) )
   nMax := Min( Len( aLines ), Len( aNames ) )
   for n := 1 to nMax
      aT := hb_ATokens( aLines[ n ], "|" )
      if Len( aT ) == 5
         ::hStat[ aNames[ n ] ] := { Val( aT[ 2 ] ), Val( aT[ 3 ] ), Val( aT[ 1 ] ), ;
                                     AllTrim( aT[ 4 ] ), AllTrim( aT[ 5 ] ) }
      endif
   next
   // a partial result means the tree changed mid-stat; retry once fresh
   if Len( aLines ) < Len( aNames ) .and. ! lRetry
      ::hStat := { => }
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD SortFiles() CLASS MCPanel

   local aRest, lMix := ::oApp:lMixDirs, n

   if Len( ::aFiles ) <= 2
      return nil
   endif

   // keep "/.." first
   aRest := {}
   for n := 2 to Len( ::aFiles )
      AAdd( aRest, ::aFiles[ n ] )
   next

   if ( ::cSort == "atime" .or. ::cSort == "ctime" .or. ::cSort == "inode" ) .and. ;
      MCVfsKind( ::cPath ) == "local"
      ::FillStat()
   endif

   if ::cSort != "unsorted"
      ASort( aRest,,, { | a, b | PanelCompare( a, b, ::cSort, ::lCaseSens, lMix, ::hStat ) } )
      if ::lReverse
         aRest := ARev( aRest )
      endif
   elseif ! lMix
      ASort( aRest,,, { | a, b | a[ P_DIR ] .and. ! b[ P_DIR ] } )
   endif

   ::aFiles := { ::aFiles[ 1 ] }
   AEval( aRest, { | a | AAdd( ::aFiles, a ) } )

return nil

//-----------------------------------------------------------------------------------------//

static function ARev( a )

   local n, aOut := {}

   for n := Len( a ) to 1 step -1
      AAdd( aOut, a[ n ] )
   next

return aOut

//-----------------------------------------------------------------------------------------//

static function PanelCompare( a, b, cSort, lCaseSens, lMix, hStat )

   local n := .F., cA, cB, nA, nB

   if ! lMix .and. a[ P_DIR ] != b[ P_DIR ]
      return a[ P_DIR ]   // directories first
   endif

   do case
      case cSort == "name"
         cA := a[ P_NAME ] ; cB := b[ P_NAME ]
         if ! lCaseSens
            cA := Lower( cA ) ; cB := Lower( cB )
         endif
         n := cA < cB
      case cSort == "ext"
         cA := Lower( hb_FNameExt( a[ P_NAME ] ) ) ; cB := Lower( hb_FNameExt( b[ P_NAME ] ) )
         if cA == cB
            n := Lower( a[ P_NAME ] ) < Lower( b[ P_NAME ] )
         else
            n := cA < cB
         endif
      case cSort == "size"
         if a[ P_SIZE ] == b[ P_SIZE ]
            n := Lower( a[ P_NAME ] ) < Lower( b[ P_NAME ] )
         else
            n := a[ P_SIZE ] < b[ P_SIZE ]
         endif
      case cSort == "mtime"
         if a[ P_DATE ] == b[ P_DATE ]
            n := a[ P_TIME ] <= b[ P_TIME ]
         else
            n := a[ P_DATE ] < b[ P_DATE ]
         endif
      case cSort == "atime" .or. cSort == "ctime" .or. cSort == "inode"
         // { atime, ctime, inode }; missing (VFS or unstated) compares as 0
         nA := If( hStat != nil .and. hb_HHasKey( hStat, a[ P_NAME ] ), ;
                   hStat[ a[ P_NAME ] ][ If( cSort == "atime", 1, If( cSort == "ctime", 2, 3 ) ) ], 0 )
         nB := If( hStat != nil .and. hb_HHasKey( hStat, b[ P_NAME ] ), ;
                   hStat[ b[ P_NAME ] ][ If( cSort == "atime", 1, If( cSort == "ctime", 2, 3 ) ) ], 0 )
         if nA == nB
            n := Lower( a[ P_NAME ] ) < Lower( b[ P_NAME ] )
         else
            n := nA < nB
         endif
   endcase

return n

//-----------------------------------------------------------------------------------------//

METHOD TitleText() CLASS MCPanel

   local nW := ::nRight - ::nLeft - 5, cPath := ::cPath

   if ::cMode == "panelize"
      return " Panelized "
   endif
   if hb_ULen( cPath ) > nW
      cPath := "~" + hb_UTF8SubStr( cPath, hb_ULen( cPath ) - nW + 1 )
   endif

return " " + cPath + " "

//-----------------------------------------------------------------------------------------//

METHOD MiniStatus() CLASS MCPanel

   local aEntry := ::Current(), cInfo := ""

   if aEntry == nil
      return ""
   endif
   if ::cListMode == "user" .and. ::lUserMiniStatus
      if ::cListMode == "user" .and. MCUFmtNeedsLong( ::cUserFmt )
         ::FillLong()
      endif
      cInfo := AllTrim( ::EntryUser( aEntry, Max( 60, ::nRight - ::nLeft - 1 ) ) )
   elseif aEntry[ P_DIR ]
      cInfo := If( aEntry[ P_NAME ] == "/..", "UP--DIR", "SUB-DIR" )
   else
      cInfo := If( aEntry[ P_SIZE ] < 0, "size unknown", AllTrim( Str( aEntry[ P_SIZE ], 14 ) ) + " bytes" )
      if ! Empty( aEntry[ P_DATE ] )
         cInfo += "  " + DToC( aEntry[ P_DATE ] ) + " " + aEntry[ P_TIME ]
      endif
   endif
   if Len( ::MarkedEntries() ) > 0
      cInfo += "  [" + hb_ntos( Len( ::MarkedEntries() ) ) + " marked]"
   endif
   if ::oApp:lShowFreeSpace .and. MCVfsKind( ::cPath ) == "local"
      cInfo += "  Free: " + MCSizeShort( hb_DiskSpace( ::cPath, HB_DISK_AVAIL ) )
   endif

return cInfo

//-----------------------------------------------------------------------------------------//

METHOD RowToIndex( nRow, nCol ) CLASS MCPanel

   local nRel := nRow - ::nTop - 2   // frame + header
   local aLay, nC

   if nRel < 0 .or. nRel >= ::VisibleRows()
      return 0
   endif

   if ::lBrief .and. nCol != nil
      aLay := ::BriefLayout()
      nC := Int( ( nCol - ::nLeft - 1 ) / aLay[ 1 ] )
      if nC < 0 .or. nC >= aLay[ 2 ]
         return 0
      endif
      nRel += nC * ::VisibleRows()
   endif

   nRel += ::nOffset + 1
   if nRel > Len( ::aFiles )
      return 0
   endif

return nRel

//-----------------------------------------------------------------------------------------//

METHOD BriefLayout() CLASS MCPanel

   local nW := Max( 8, ::nRight - ::nLeft - 1 ), nMax := 0, aEntry

   for each aEntry in ::aFiles
      nMax := Max( nMax, hb_ULen( MCCpDecode( aEntry[ P_NAME ], ::cCp ) ) + ;
                   If( aEntry[ P_DIR ] .and. aEntry[ P_NAME ] != "/..", 1, 0 ) )
   next
   nMax := Min( Max( nMax + 3, 10 ), nW )   // leading space + 2-cell gap

return { nMax, Max( 1, Int( nW / nMax ) ) }

//-----------------------------------------------------------------------------------------//

METHOD PageSize() CLASS MCPanel

return If( ::lBrief, ::BriefLayout()[ 2 ] * ::VisibleRows(), ::VisibleRows() )

//-----------------------------------------------------------------------------------------//

METHOD FixScroll() CLASS MCPanel

   local nRows, nCols

   if ::nCurrent < 1
      ::nCurrent := 1
   endif
   if ::nCurrent > Len( ::aFiles )
      ::nCurrent := Len( ::aFiles )
   endif
   if ::lBrief
      // brief is column-major: keep the offset aligned to column starts so
      // columns always begin at the panel top (mc-style columnwise scroll)
      nRows := ::VisibleRows()
      nCols := ::BriefLayout()[ 2 ]
      if ::nCurrent <= ::nOffset
         ::nOffset := Int( ( ::nCurrent - 1 ) / nRows ) * nRows
      endif
      if ::nCurrent > ::nOffset + nRows * nCols
         ::nOffset := ( Int( ( ::nCurrent - 1 ) / nRows ) - nCols + 1 ) * nRows
      endif
   else
      if ::nCurrent <= ::nOffset
         ::nOffset := ::nCurrent - 1
      endif
      if ::nCurrent > ::nOffset + ::VisibleRows()
         ::nOffset := ::nCurrent - ::VisibleRows()
      endif
   endif
   if ::nOffset < 0
      ::nOffset := 0
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD Scroll( nDelta ) CLASS MCPanel

   ::nCurrent := Min( Max( ::nCurrent + nDelta, 1 ), Max( Len( ::aFiles ), 1 ) )
   ::FixScroll()

return nil

//-----------------------------------------------------------------------------------------//

METHOD Move( nKey ) CLASS MCPanel

   do case
      case nKey == K_UP
         ::nCurrent--
         if ! ::lBrief .and. ::nCurrent >= 1
            if ::oApp:lScrollPages .and. ::nCurrent < ::nOffset + 1
               // hit the top edge: scroll half a page (mc move_up)
               ::nOffset := Max( ::nOffset - Int( ::VisibleRows() / 2 ), 0 )
            elseif ::oApp:lScrollCenter .and. ;
                   ::nCurrent - 1 - ::nOffset < Int( ::VisibleRows() / 2 ) .and. ::nOffset > 0
               ::nOffset--
            endif
         endif
      case nKey == K_DOWN
         ::nCurrent++
         if ! ::lBrief .and. ::nCurrent <= Len( ::aFiles )
            if ::oApp:lScrollPages .and. ::nCurrent - 1 - ::nOffset == ::VisibleRows()
               // hit the bottom edge: scroll half a page (mc move_down)
               ::nOffset := Min( ::nOffset + Int( ::VisibleRows() / 2 ), ;
                                 Max( Len( ::aFiles ) - ::VisibleRows(), 0 ) )
            elseif ::oApp:lScrollCenter .and. ;
                   ::nCurrent - 1 - ::nOffset > Int( ::VisibleRows() / 2 )
               ::nOffset := Min( ::nOffset + 1, Max( Len( ::aFiles ) - ::VisibleRows(), 0 ) )
            endif
         endif
      case nKey == K_LEFT  ; If( ::lBrief, ::nCurrent -= ::VisibleRows(), )
      case nKey == K_RIGHT ; If( ::lBrief, ::nCurrent += ::VisibleRows(), )
      case nKey == K_PGUP  ; ::nCurrent -= ::PageSize()
      case nKey == K_PGDN  ; ::nCurrent += ::PageSize()
      case nKey == K_HOME  ; ::nCurrent := 1
      case nKey == K_END   ; ::nCurrent := Len( ::aFiles )
   endcase
   ::nCurrent := Min( Max( ::nCurrent, 1 ), Max( Len( ::aFiles ), 1 ) )
   ::FixScroll()
   ::oApp:OtherPanelRef()

return nil

//-----------------------------------------------------------------------------------------//

METHOD Current() CLASS MCPanel

   if Len( ::aFiles ) == 0 .or. ::nCurrent < 1 .or. ::nCurrent > Len( ::aFiles )
      return nil
   endif

return ::aFiles[ ::nCurrent ]

//-----------------------------------------------------------------------------------------//

METHOD MarkCurrent() CLASS MCPanel

   local aEntry := ::Current()

   if aEntry != nil .and. aEntry[ P_NAME ] != "/.."
      aEntry[ P_MARKED ] := ! aEntry[ P_MARKED ]
      if ::oApp:lMarkDown
         ::nCurrent++
      endif
      ::FixScroll()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD MarkedEntries() CLASS MCPanel

   local aOut := {}, aEntry

   for each aEntry in ::aFiles
      if aEntry[ P_MARKED ] .and. aEntry[ P_NAME ] != "/.."
         AAdd( aOut, aEntry )
      endif
   next

return aOut

//-----------------------------------------------------------------------------------------//

METHOD LynxEnter() CLASS MCPanel

   // Lynx-like motion: Right enters the dir under the cursor
   local aEntry := ::Current()

   if ::cMode == "panelize" .or. ::cMode == "tree"
      return .F.
   endif
   if aEntry != nil .and. aEntry[ P_DIR ] .and. aEntry[ P_NAME ] != "/.."
      ::GoDir( MCEntryPath( Self, aEntry ) )
      return .T.
   endif

return .F.

//-----------------------------------------------------------------------------------------//

METHOD LynxUp() CLASS MCPanel

   // Lynx-like motion: Left goes to the parent dir (same rules as "/..")
   local cUp

   if ::cMode == "panelize" .or. ::cMode == "tree"
      return .F.
   endif
   if MCVfsKind( ::cPath ) != "local"
      ::GoDir( MCVfsParent( ::cPath ) )
   else
      cUp := iif( Right( ::cPath, 1 ) == "/", hb_StrShrink( ::cPath, 1 ), ::cPath )
      ::GoDir( iif( Empty( cUp ), "/", hb_FNameDir( cUp ) ) )
   endif

return .T.

//-----------------------------------------------------------------------------------------//

METHOD EnterKey() CLASS MCPanel

   local aEntry := ::Current(), cFull, cCmd, cUp

   if aEntry == nil
      return nil
   endif

   if ::cMode == "panelize"
      cFull := aEntry[ P_NAME ]
      if hb_DirExists( cFull )
         ::GoDir( cFull )
      elseif hb_FileExists( cFull )
         ::GoDir( hb_FNameDir( cFull ) )
         ::SelectName( hb_FNameNameExt( cFull ) )
      endif
      return nil
   endif

   if ::cMode == "tree"
      if ::nCurrent >= 1 .and. ::nCurrent <= Len( ::aTree )
         ::GoDir( ::aTree[ ::nCurrent ][ 3 ] )
      endif
      return nil
   endif

   if aEntry[ P_DIR ]
      if aEntry[ P_NAME ] == "/.."
         if MCVfsKind( ::cPath ) != "local"
            ::GoDir( MCVfsParent( ::cPath ) )
         else
            // hb_FNameDir() of a slash-terminated path returns the path
            // itself; chop the trailing slash or ".." never goes up
            cUp := iif( Right( ::cPath, 1 ) == "/", hb_StrShrink( ::cPath, 1 ), ::cPath )
            ::GoDir( iif( Empty( cUp ), "/", hb_FNameDir( cUp ) ) )
         endif
      else
         ::GoDir( MCEntryPath( Self, aEntry ) )
      endif
      return nil
   endif

   // regular file: archives open as directories, extension binding, else view
   cFull := hb_FNameMerge( ::cPath, aEntry[ P_NAME ] )
   if MCVfsKind( ::cPath ) == "local" .and. ! Empty( MCVfsArchiveScheme( cFull ) )
      ::GoDir( cFull + "#" + MCVfsArchiveScheme( cFull ) + "/" )
      return nil
   endif
   if MCVfsKind( cFull ) != "local"
      MCVfsViewFile( cFull )
      return nil
   endif
   cCmd := ExtBinding( Lower( hb_FNameExt( cFull ) ) )
   if ! Empty( cCmd )
      cCmd := StrTran( cCmd, "%f", ShellQuote( cFull ) )
      ::oApp:cCmdLine := cCmd
      ::oApp:RunCommand()
   elseif hb_ProcessRun( MCShWrap( "test -x " + ShellQuote( cFull ) + " && test ! -d " + ShellQuote( cFull ) ) ) == 0
      // executable regular file: mc runs it, asking first when
      // "confirm execute" is on
      if ! ::oApp:lConfirmExecute .or. ;
         ::oApp:DlgConfirm( "Execute", "Execute " + aEntry[ P_NAME ] + "?", "&Execute" )
         ::oApp:cCmdLine := ShellQuote( cFull )
         ::oApp:RunCommand()
      endif
   else
      MCViewer( cFull )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD SelectName( cName ) CLASS MCPanel

   local n

   for n := 1 to Len( ::aFiles )
      if ::aFiles[ n ][ P_NAME ] == cName
         ::nCurrent := n
         exit
      endif
   next
   ::FixScroll()

return nil

//-----------------------------------------------------------------------------------------//

METHOD QuickSearch() CLASS MCPanel

   local cSearch := "", nKey, n, cName

   while .T.
      hb_DispOutAt( ::nBottom - 1, ::nLeft + 1, hb_UPadR( "Quick search: " + cSearch, ::nRight - ::nLeft - 1 ), "W+/BG" )
      nKey := InKey( 0 )
      if nKey == K_ESC .or. nKey == K_ENTER
         exit
      elseif nKey == K_BS
         cSearch := Left( cSearch, Len( cSearch ) - 1 )
      elseif nKey >= 32 .and. nKey < 256
         cSearch += Chr( nKey )
      else
         loop
      endif
      for n := 1 to Len( ::aFiles )
         cName := ::aFiles[ n ][ P_NAME ]
         if ! Empty( cSearch ) .and. Lower( Left( cName, Len( cSearch ) ) ) == Lower( cSearch )
            ::nCurrent := n
            ::FixScroll()
            ::Display()
            exit
         endif
      next
   end
   ::Display()

return nil

//-----------------------------------------------------------------------------------------//

METHOD ComputeDirSizes() CLASS MCPanel

   local aEntry

   for each aEntry in ::aFiles
      if aEntry[ P_DIR ] .and. aEntry[ P_NAME ] != "/.."
         aEntry[ P_SIZE ] := ::DirSize( MCEntryPath( Self, aEntry ), 0 )
      endif
   next

   ::lSizesComputed := .T.

return nil

//-----------------------------------------------------------------------------------------//

METHOD DirSize( cPath, nLevel ) CLASS MCPanel

   local aDir, aEntry, nSize := 0, cFull

   if nLevel > 12   // recursion guard
      return 0
   endif

   aDir := Directory( hb_DirSepAdd( cPath ) + "*", "DHS" )
   for each aEntry in aDir
      if aEntry[ F_NAME ] == "." .or. aEntry[ F_NAME ] == ".."
         loop
      endif
      cFull := hb_FNameMerge( cPath, aEntry[ F_NAME ] )
      if hb_DirExists( cFull )
         nSize += ::DirSize( cFull, nLevel + 1 )
      else
         nSize += aEntry[ F_SIZE ]
      endif
   next

return nSize

//-----------------------------------------------------------------------------------------//

METHOD Display() CLASS MCPanel

   local oApp := ::oApp, cFrame := oApp:aPalette[ CLR_FRAME ]
   local nRows := ::VisibleRows()

   do case
      case ::cMode == "quickview" ; ::DisplayQuickView()
      case ::cMode == "info"      ; ::DisplayInfo()
      case ::cMode == "tree"      ; ::DisplayTree()
      otherwise                   ; ::DisplayListing()
   endcase

   // frame + title
   hb_DispBox( ::nTop, ::nLeft, ::nBottom, ::nRight, hb_UTF8ToStrBox( "┌─┐│┘─└│" ), cFrame )
   hb_DispOutAt( ::nTop, ::nLeft + Max( 1, Int( ( ::nRight - ::nLeft - hb_ULen( ::TitleText() ) ) / 2 ) ), ;
                 ::TitleText(), If( ::lActive, oApp:aPalette[ CLR_TITLE ], cFrame ) )
   // scroll hints
   if ::nOffset > 0 .and. ::cMode == "listing"
      hb_DispOutAt( ::nTop, ::nLeft + 1, hb_UTF8ToStr( "↑" ), cFrame )
   endif
   if ::cMode == "listing" .and. ::nOffset + ::PageSize() < Len( ::aFiles )
      hb_DispOutAt( ::nTop, ::nRight - 1, hb_UTF8ToStr( "↓" ), cFrame )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD DisplayListing() CLASS MCPanel

   local oApp := ::oApp, nW := ::nRight - ::nLeft - 1
   local nRows := ::VisibleRows(), n, nIdx, aEntry, cLine, cColor
   local cHdr, aLay, nColW, nCols, nC, nX, nCellW, cName

   if ::cListMode == "long" .or. ( ::cListMode == "user" .and. MCUFmtNeedsLong( ::cUserFmt ) )
      ::FillLong()
   endif
   if ::cListMode == "user" .and. MCUFmtNeedsStat( ::cUserFmt )
      ::FillStat()
   endif
   // header
   if ::lBrief
      cHdr := " Name"
   elseif ::cListMode == "long"
      cHdr := " " + PadR( "Perms", 10 ) + " " + PadL( "Ln", 3 ) + " " + PadR( "Owner", 8 ) + ;
              " " + PadR( "Group", 8 ) + " " + PadL( "Size", 8 ) + " " + PadR( "MTime", 12 ) + " Name"
   elseif ::cListMode == "user"
      cHdr := ""
   else
      cHdr := " Name" + Space( Max( 1, nW - 27 ) ) + "Size      MTime"
   endif
   hb_DispOutAt( ::nTop + 1, ::nLeft + 1, hb_UPadR( cHdr, nW ), oApp:aPalette[ CLR_HEADER ] )

   if ::lBrief
      // column-major multi-column layout (mc brief style);
      // clear the whole body first so narrower grids erase old full-mode lines
      hb_Scroll( ::nTop + 2, ::nLeft + 1, ::nBottom - 1, ::nRight - 1, 0, 0, oApp:aPalette[ CLR_PANEL ], " " )
      aLay := ::BriefLayout()
      nColW := aLay[ 1 ]
      nCols := aLay[ 2 ]
      for nC := 0 to nCols - 1
         nX := ::nLeft + 1 + nC * nColW
         nCellW := Min( nColW, ::nRight - nX )
         if nCellW < 2
            exit
         endif
         for n := 1 to nRows
            nIdx := ::nOffset + nC * nRows + n
            if nIdx <= Len( ::aFiles )
               aEntry := ::aFiles[ nIdx ]
               cName := MCCpDecode( aEntry[ P_NAME ], ::cCp )
               if aEntry[ P_DIR ] .and. aEntry[ P_NAME ] != "/.."
                  cName += "/"
               endif
               if hb_HHasKey( ::hLinks, aEntry[ P_NAME ] )
                  cName += " -> " + MCCpDecode( ::hLinks[ aEntry[ P_NAME ] ], ::cCp )
               endif
               cLine := hb_UPadR( hb_UTF8SubStr( " " + cName, 1, nCellW - 1 ), nCellW )   // trailing blank cell before the next column
               cColor := ::EntryColor( aEntry, nIdx == ::nCurrent .and. ::lActive )
               hb_DispOutAt( ::nTop + 1 + n, nX, cLine, cColor )
            else
               hb_DispOutAt( ::nTop + 1 + n, nX, Space( nCellW ), oApp:aPalette[ CLR_PANEL ] )
            endif
         next
      next
   else
      for n := 1 to nRows
         nIdx := ::nOffset + n
         if nIdx <= Len( ::aFiles )
            aEntry := ::aFiles[ nIdx ]
            cLine := ::EntryLine( aEntry, nW )
            cColor := ::EntryColor( aEntry, nIdx == ::nCurrent .and. ::lActive )
            hb_DispOutAt( ::nTop + 1 + n, ::nLeft + 1, cLine, cColor )
         else
            hb_DispOutAt( ::nTop + 1 + n, ::nLeft + 1, Space( nW ), oApp:aPalette[ CLR_PANEL ] )
         endif
      next
   endif

   // mini status
   if oApp:lMiniStatus
      hb_DispOutAt( ::nBottom - 1, ::nLeft + 1, hb_UPadR( ::MiniStatus(), nW ), oApp:aPalette[ CLR_MINI ] )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD EntryLine( aEntry, nWidth ) CLASS MCPanel

   local cName := MCCpDecode( aEntry[ P_NAME ], ::cCp ), cSize, cTime, cLine

   if aEntry[ P_DIR ] .and. aEntry[ P_NAME ] != "/.."
      cName += "/"
   endif
   if hb_HHasKey( ::hLinks, aEntry[ P_NAME ] )
      cName += " -> " + MCCpDecode( ::hLinks[ aEntry[ P_NAME ] ], ::cCp )
   endif
   if ::lBrief
      return hb_UPadR( " " + cName, nWidth )
   endif
   if ::cListMode == "long"
      return ::EntryLong( aEntry, nWidth )
   endif
   if ::cListMode == "user"
      return ::EntryUser( aEntry, nWidth )
   endif
   if aEntry[ P_DIR ]
      cSize := If( aEntry[ P_NAME ] == "/..", "UP--DIR ", ;
              If( ::lSizesComputed, MCSizeColumn( aEntry[ P_SIZE ], ::oApp:lSIUnits ), "SUB-DIR " ) )
   else
      cSize := If( aEntry[ P_SIZE ] < 0, PadL( "?", 8 ), MCSizeColumn( aEntry[ P_SIZE ], ::oApp:lSIUnits ) )
   endif
   cTime := If( Empty( aEntry[ P_DATE ] ), Space( 16 ), ;
                DToC( aEntry[ P_DATE ] ) + " " + Left( aEntry[ P_TIME ], 5 ) )

   cLine := " " + hb_UPadR( hb_UTF8SubStr( cName, 1, nWidth - 28 ), nWidth - 27 ) + ;   // one blank cell always separates Name from Size
            cSize + " " + cTime

return hb_UPadR( cLine, nWidth )   // cell-based: UTF-8 names pad to cells, not bytes

//-----------------------------------------------------------------------------------------//

METHOD EntryColor( aEntry, lOnBar ) CLASS MCPanel

   local aPal := ::oApp:aPalette

   if lOnBar
      return If( aEntry[ P_MARKED ], aPal[ CLR_BAR_MARK ], aPal[ CLR_BAR ] )
   endif
   if aEntry[ P_MARKED ]
      return aPal[ CLR_MARKED ]
   endif
   if aEntry[ P_DIR ]
      return aPal[ CLR_DIR ]
   endif
   if ::oApp:lFileTypes .and. Len( aEntry ) >= 8 .and. aEntry[ 8 ]
      return aPal[ CLR_EXEC ]
   endif

return aPal[ CLR_PANEL ]

//-----------------------------------------------------------------------------------------//

METHOD DisplayQuickView() CLASS MCPanel

   local oOther := If( Self == ::oApp:oPanel1, ::oApp:oPanel2, ::oApp:oPanel1 ), aEntry := oOther:Current()
   local nW := ::nRight - ::nLeft - 1, nRows := ::VisibleRows()
   local aLines := {}, cFull, n, aX

   hb_Scroll( ::nTop + 1, ::nLeft + 1, ::nBottom - 1, ::nRight - 1, 0, 0, ::oApp:aPalette[ CLR_PANEL ], " " )
   if aEntry != nil
      if aEntry[ P_DIR ]
         cFull := If( aEntry[ P_NAME ] == "/..", ;
                      If( MCVfsKind( oOther:cPath ) == "local", hb_FNameDir( oOther:cPath ), MCVfsParent( oOther:cPath ) ), ;
                      MCEntryPath( oOther, aEntry ) )
         aLines := { "Directory: " + cFull, "" }
         if MCVfsKind( cFull ) != "local"
            aX := MCVfsList( cFull )
            if aX != nil
               AEval( aX, { | a | AAdd( aLines, a[ 1 ] + If( a[ 6 ], "/", "" ) ) } )
            endif
         else
            AEval( Directory( hb_DirSepAdd( cFull ) + "*", "DHS" ), ;
                   { | a | AAdd( aLines, a[ F_NAME ] + If( hb_DirExists( hb_FNameMerge( cFull, a[ F_NAME ] ) ), "/", "" ) ) } )
         endif
      else
         cFull := MCEntryPath( oOther, aEntry )
         if MCVfsKind( cFull ) != "local"
            aX := MCVfsExtract( cFull, MCVfsTmpDir(), .F. )
            if aX == nil
               aLines := { "(cannot read this member)" }
            else
               aLines := hb_aTokens( StrTran( Left( MemoRead( aX[ 1 ] ), 60000 ), Chr( 13 ) ), Chr( 10 ) )
               DeleteTree( aX[ 2 ], .T. )
            endif
         else
            aLines := hb_aTokens( StrTran( Left( MemoRead( cFull ), 60000 ), Chr( 13 ) ), Chr( 10 ) )
         endif
      endif
   endif
   for n := 1 to Min( nRows, Len( aLines ) )
      hb_DispOutAt( ::nTop + 1 + n, ::nLeft + 1, hb_UPadR( hb_UTF8SubStr( aLines[ n ], 1, nW ), nW ), ::oApp:aPalette[ CLR_PANEL ] )
   next

return nil

//-----------------------------------------------------------------------------------------//

METHOD DisplayInfo() CLASS MCPanel

   local oOther := If( Self == ::oApp:oPanel1, ::oApp:oPanel2, ::oApp:oPanel1 ), aEntry := oOther:Current()
   local nW := ::nRight - ::nLeft - 1
   local aLines := {}, cFull, cOut := ""

   hb_Scroll( ::nTop + 1, ::nLeft + 1, ::nBottom - 1, ::nRight - 1, 0, 0, ::oApp:aPalette[ CLR_PANEL ], " " )
   if aEntry != nil
      cFull := hb_FNameMerge( oOther:cPath, aEntry[ P_NAME ] )
      AAdd( aLines, "Name:     " + aEntry[ P_NAME ] )
      AAdd( aLines, "Location: " + oOther:cPath )
      if aEntry[ P_DIR ]
         AAdd( aLines, "Type:     directory" )
      else
         AAdd( aLines, "Type:     regular file" )
         AAdd( aLines, "Size:     " + If( aEntry[ P_SIZE ] < 0, "unknown", hb_ntos( aEntry[ P_SIZE ] ) + " bytes" ) )
      endif
      AAdd( aLines, "Modified: " + If( Empty( aEntry[ P_DATE ] ), "-", DToC( aEntry[ P_DATE ] ) + " " + aEntry[ P_TIME ] ) )
      AAdd( aLines, "Attrs:    " + aEntry[ P_ATTR ] )
      hb_ProcessRun( MCShWrap( "stat -c 'Mode:     %A (%a)" + Chr( 10 ) + "Links:    %h' " + ShellQuote( cFull ) ),, @cOut )
      AEval( hb_aTokens( StrTran( cOut, Chr( 13 ) ), Chr( 10 ) ), { | c | AAdd( aLines, c ) } )
      cOut := ""
      hb_ProcessRun( MCShWrap( "readlink " + ShellQuote( cFull ) ),, @cOut )
      if ! Empty( cOut )
         AAdd( aLines, "Symlink:  " + AllTrim( cOut ) )
      endif
      AAdd( aLines, "" )
      cOut := ""
      hb_ProcessRun( MCShWrap( [df -k ] + ShellQuote( oOther:cPath ) + [ | tail -1 | awk '{print "Disk free: " $4 " KB of " $2 " KB"}'] ),, @cOut )
      AAdd( aLines, AllTrim( cOut ) )
   endif
   AEval( aLines, { | c, n | If( ::nTop + 1 + n < ::nBottom, ;
       hb_DispOutAt( ::nTop + 1 + n, ::nLeft + 1, hb_UPadR( hb_UTF8SubStr( c, 1, nW ), nW ), ::oApp:aPalette[ CLR_PANEL ] ), ) } )

return nil

//-----------------------------------------------------------------------------------------//

METHOD DisplayTree() CLASS MCPanel

   local nW := ::nRight - ::nLeft - 1, nRows := ::VisibleRows(), n, nIdx, cLine

   if Empty( ::aTree )
      TreeScan( ::cPath, 0, ::aTree )
   endif

   hb_Scroll( ::nTop + 1, ::nLeft + 1, ::nBottom - 1, ::nRight - 1, 0, 0, ::oApp:aPalette[ CLR_PANEL ], " " )
   hb_DispOutAt( ::nTop + 1, ::nLeft + 1, PadR( " Directory tree (Enter: chdir)", nW ), ::oApp:aPalette[ CLR_HEADER ] )
   for n := 1 to Min( nRows, Len( ::aTree ) )
      nIdx := ::nOffset + n
      if nIdx <= Len( ::aTree )
         cLine := Space( ::aTree[ nIdx ][ 2 ] * 2 ) + ::aTree[ nIdx ][ 1 ]
         hb_DispOutAt( ::nTop + 1 + n, ::nLeft + 1, hb_UPadR( hb_UTF8SubStr( cLine, 1, nW ), nW ), ;
                       If( nIdx == ::nCurrent .and. ::lActive, ::oApp:aPalette[ CLR_BAR ], ::oApp:aPalette[ CLR_DIR ] ) )
      endif
   next

return nil

//-----------------------------------------------------------------------------------------//

function TreeScan( cPath, nLevel, aTree )

   local aDir, cFull

   if nLevel > 6 .or. Len( aTree ) > 800
      return nil
   endif

   AAdd( aTree, { hb_FNameName( hb_DirSepDel( cPath ) ), nLevel, cPath } )
   for each aDir in Directory( hb_DirSepAdd( cPath ) + "*", "D" )
      if aDir[ 1 ] == "." .or. aDir[ 1 ] == ".." .or. Left( aDir[ 1 ], 1 ) == "."
         loop
      endif
      cFull := hb_FNameMerge( cPath, aDir[ 1 ] )
      if hb_DirExists( cFull )
         TreeScan( cFull, nLevel + 1, aTree )
      endif
   next

return nil

//-----------------------------------------------------------------------------------------//

function FilterMatch( cName, cFilter, lCaseSens, lShellPatterns )

   local aMasks := hb_aTokens( hb_defaultValue( cFilter, "*" ), "; " ), cMask

   hb_defaultValue( @lShellPatterns, .T. )
   if Empty( cFilter ) .or. cFilter == "*"
      return .T.   // match-all mask in either mode
   endif
   if ! lShellPatterns
      // mc shell-patterns off: the mask is a plain substring, not a glob
      return If( lCaseSens, cFilter $ cName, Lower( cFilter ) $ Lower( cName ) )
   endif
   for each cMask in aMasks
      if Empty( cMask )
         loop
      endif
      if ! lCaseSens
         if hb_FileMatch( Lower( cName ), Lower( cMask ) )
            return .T.
         endif
      else
         if hb_FileMatch( cName, cMask )
            return .T.
         endif
      endif
   next

return .F.

//-----------------------------------------------------------------------------------------//

// resolve a symlink's target via the same shell pattern the symlink
// actions use (Harbour has no native readlink)
function MCLinkTarget( cFull )

   local cTarget := ""

   hb_ProcessRun( MCShWrap( "readlink " + ShellQuote( cFull ) ),, @cTarget )

return AllTrim( StrTran( StrTran( cTarget, Chr( 13 ) ), Chr( 10 ) ) )

//-----------------------------------------------------------------------------------------//

// short human size for the mini-status free-space readout
function MCSizeShort( nBytes )

   if nBytes >= 1073741824
      return AllTrim( Str( Round( nBytes / 1073741824, 1 ), 8, 1 ) ) + "G"
   endif
   if nBytes >= 1048576
      return AllTrim( Str( Round( nBytes / 1048576, 1 ), 8, 1 ) ) + "M"
   endif

return AllTrim( Str( Round( nBytes / 1024, 0 ), 10, 0 ) ) + "K"

//-----------------------------------------------------------------------------------------//

// size column: raw bytes while they fit 8 chars, then K/M/G with a
// 1024 divisor (default) or 1000 ("Use SI size units")
function MCSizeColumn( nBytes, lSI )

   local cRaw := AllTrim( Str( nBytes, 20 ) ), nDiv

   if Len( cRaw ) <= 8
      return PadL( cRaw, 8 )
   endif

   nDiv := If( lSI, 1000, 1024 )

   if nBytes >= nDiv * nDiv * nDiv
      return PadL( AllTrim( Str( nBytes / ( nDiv * nDiv * nDiv ), 10, 1 ) ) + "G", 8 )
   endif
   if nBytes >= nDiv * nDiv
      return PadL( AllTrim( Str( nBytes / ( nDiv * nDiv ), 10, 1 ) ) + "M", 8 )
   endif

return PadL( AllTrim( Str( nBytes / nDiv, 10, 1 ) ) + "K", 8 )

//-----------------------------------------------------------------------------------------//

// physical path resolution for "Cd follows links" OFF (mc's cd_symlinks=0):
// resolves the symlink chain to the real directory
function MCRealPath( cPath )

   local cOut := "", nRet

   nRet := hb_ProcessRun( MCShWrap( "cd " + ShellQuote( cPath ) + " && pwd -P" ),, @cOut )
   if nRet == 0
      cOut := StrTran( StrTran( cOut, Chr( 13 ), "" ), Chr( 10 ), "" )
      if ! Empty( cOut )
         return hb_PathNormalize( cOut )
      endif
   endif

return hb_PathNormalize( cPath )

//-----------------------------------------------------------------------------------------//

function MCShWrap( cScript )
// hb_ProcessRun() execs without a shell; pipes, redirections, && need sh -c.
return "/bin/sh -c " + ShellQuote( cScript )

function ShellQuote( cPath )

return "'" + StrTran( cPath, "'", "'\''" ) + "'"

//-----------------------------------------------------------------------------------------//

function ExtBinding( cExt )

   local cFile := hb_DirSepAdd( hb_GetEnv( "HOME" ) ) + ".hbmc.ext"
   local cLine

   if hb_FileExists( cFile )
      for each cLine in hb_aTokens( StrTran( MemoRead( cFile ), Chr( 13 ) ), Chr( 10 ) )
         cLine := AllTrim( cLine )
         if ! Empty( cLine ) .and. Left( cLine, 1 ) != "#" .and. At( "=", cLine ) > 0
            if Lower( AllTrim( Left( cLine, At( "=", cLine ) - 1 ) ) ) == StrTran( cExt, ".", "" )
               return AllTrim( SubStr( cLine, At( "=", cLine ) + 1 ) )
            endif
         endif
      next
   endif

return ""

//-----------------------------------------------------------------------------------------//

function MCErrorMsg( oError )

   local cMsg := "Error " + oError:SubSystem() + "/" + hb_ntos( oError:SubCode() ) + ;
                 ": " + oError:Description, n := 1

   while ! Empty( ProcName( n ) )
      cMsg += Chr( 10 ) + "  " + ProcName( n ) + "(" + hb_ntos( ProcLine( n ) ) + ")"
      n++
      if n > 6
         exit
      endif
   end

return cMsg

//-----------------------------------------------------------------------------------------//

METHOD FillLong() CLASS MCPanel

   // perms/nlink/owner/group for the long and user listing formats: ONE
   // batched stat call (local panels only; VFS providers do not carry
   // these fields, so their cells stay blank). Output lines follow the
   // argument order, so names never appear and quoting is safe.
   local aNames := {}, a, cOut := "", cCmd := "", aLines, aT, n, nMax

   if MCVfsKind( ::cPath ) != "local"
      return nil
   endif
   for each a in ::aFiles
      if a[ P_NAME ] != "/.." .and. ! hb_HHasKey( ::hLong, a[ P_NAME ] )
         AAdd( aNames, a[ P_NAME ] )
      endif
   next
   if Empty( aNames )
      return nil
   endif
   for each a in aNames
      cCmd += " " + ShellQuote( a )
   next
   if hb_ProcessRun( MCShWrap( "cd " + ShellQuote( ::cPath ) + ;
          " && stat -c '%A|%h|%U|%G' --" + cCmd + " 2>/dev/null" ),, @cOut ) != 0
      return nil
   endif
   aLines := hb_ATokens( cOut, Chr( 10 ) )
   nMax := Min( Len( aLines ), Len( aNames ) )
   for n := 1 to nMax
      aT := hb_ATokens( aLines[ n ], "|" )
      if Len( aT ) == 4
         ::hLong[ aNames[ n ] ] := { AllTrim( aT[ 1 ] ), AllTrim( aT[ 2 ] ), ;
                                     AllTrim( aT[ 3 ] ), AllTrim( aT[ 4 ] ) }
      endif
   next

return nil

//-----------------------------------------------------------------------------------------//

METHOD EntryLong( aEntry, nWidth ) CLASS MCPanel

   // ls -l style: perms nlink owner group size mtime name
   local cName := MCCpDecode( aEntry[ P_NAME ], ::cCp ), aL, cSize, cTime
   local cPerms := Space( 10 ), cNlink := Space( 3 ), cOwner := Space( 8 ), cGroup := Space( 8 )

   if aEntry[ P_DIR ] .and. aEntry[ P_NAME ] != "/.."
      cName += "/"
   endif
   if hb_HHasKey( ::hLinks, aEntry[ P_NAME ] )
      cName += " -> " + MCCpDecode( ::hLinks[ aEntry[ P_NAME ] ], ::cCp )
   endif
   if hb_HHasKey( ::hLong, aEntry[ P_NAME ] )
      aL := ::hLong[ aEntry[ P_NAME ] ]
      cPerms := PadR( aL[ 1 ], 10 )
      cNlink := PadL( aL[ 2 ], 3 )
      cOwner := PadR( hb_UTF8SubStr( aL[ 3 ], 1, 8 ), 8 )
      cGroup := PadR( hb_UTF8SubStr( aL[ 4 ], 1, 8 ), 8 )
   endif
   if aEntry[ P_DIR ]
      cSize := If( aEntry[ P_NAME ] == "/..", "UP--DIR ", ;
              If( ::lSizesComputed, MCSizeColumn( aEntry[ P_SIZE ], ::oApp:lSIUnits ), "SUB-DIR " ) )
   else
      cSize := If( aEntry[ P_SIZE ] < 0, PadL( "?", 8 ), MCSizeColumn( aEntry[ P_SIZE ], ::oApp:lSIUnits ) )
   endif
   cTime := MCShortDate( aEntry[ P_DATE ], aEntry[ P_TIME ] )

return hb_UPadR( " " + cPerms + " " + cNlink + " " + cOwner + " " + cGroup + ;
                 " " + cSize + " " + cTime + " " + ;
                 hb_UTF8SubStr( cName, 1, Max( 1, nWidth - 56 ) ), nWidth )

//-----------------------------------------------------------------------------------------//

METHOD EntryUser( aEntry, nWidth ) CLASS MCPanel

   // user-defined listing format, subset of mc's: columns separated by
   // "|", each column a list of fields: name ext size bsize mtime atime
   // ctime perm nlink owner group type mark space; "half" gives the
   // column half of the panel width, the rest share what remains.
   // Unknown words are ignored.
   local aCols := hb_ATokens( ::cUserFmt, "|" ), nCols := Len( aCols )
   local aHalf := {}, aWords, cWord, n, nHalfW, nRest, nRestCols, nColW
   local cLine := "", aL, cName, cPart, nFixed, aFields, lHasName

   for n := 1 to nCols
      aWords := hb_ATokens( aCols[ n ] )
      AAdd( aHalf, AScan( aWords, { | w | Lower( w ) == "half" } ) > 0 )
   next
   nHalfW   := Int( nWidth / 2 )
   nRestCols := 0
   for n := 1 to nCols
      if ! aHalf[ n ]
         nRestCols++
      endif
   next
   nRest := nWidth - ( nCols - nRestCols ) * nHalfW

   for n := 1 to nCols
      nColW := If( aHalf[ n ], nHalfW, Int( nRest / Max( 1, nRestCols ) ) )
      if n == nCols .and. ! aHalf[ n ]
         nColW := nWidth - hb_ULen( cLine )   // last column takes the remainder
      endif
      aWords := hb_ATokens( aCols[ n ] )
      aFields := {}
      for each cWord in aWords
         if Lower( cWord ) != "half"
            AAdd( aFields, Lower( cWord ) )
         endif
      next
      // fixed-width fields first; name/ext share what remains
      nFixed := 0
      lHasName := .F.
      for each cWord in aFields
         do case
            case cWord == "name" .or. cWord == "ext"
               lHasName := .T.
            case cWord == "size" .or. cWord == "bsize" ; nFixed += 8 + 1
            case cWord == "mtime" .or. cWord == "atime" .or. cWord == "ctime" ; nFixed += 12 + 1
            case cWord == "perm" ; nFixed += 10 + 1
            case cWord == "nlink" ; nFixed += 3 + 1
            case cWord == "owner" .or. cWord == "group" ; nFixed += 8 + 1
            case cWord == "type" .or. cWord == "mark" .or. cWord == "space" ; nFixed += 1 + 1
         endcase
      next

      cPart := ""
      for each cWord in aFields
         if ! Empty( cPart )
            cPart += " "
         endif
         do case
            case cWord == "name" .or. cWord == "ext"
               cName := If( cWord == "ext", hb_FNameExt( aEntry[ P_NAME ] ), ;
                            MCCpDecode( aEntry[ P_NAME ], ::cCp ) + ;
                            If( aEntry[ P_DIR ] .and. aEntry[ P_NAME ] != "/..", "/", "" ) )
               if cWord == "name" .and. hb_HHasKey( ::hLinks, aEntry[ P_NAME ] )
                  cName += " -> " + MCCpDecode( ::hLinks[ aEntry[ P_NAME ] ], ::cCp )
               endif
               cPart += hb_UPadR( hb_UTF8SubStr( cName, 1, Max( 0, nColW - nFixed - 1 ) ), ;
                                  Max( 0, nColW - nFixed - 1 ) )
            case cWord == "size" .or. cWord == "bsize"
               if aEntry[ P_DIR ]
                  cPart += If( aEntry[ P_NAME ] == "/..", "UP--DIR ", ;
                          If( ::lSizesComputed, MCSizeColumn( aEntry[ P_SIZE ], ::oApp:lSIUnits ), "SUB-DIR " ) )
               else
                  cPart += If( aEntry[ P_SIZE ] < 0, PadL( "?", 8 ), MCSizeColumn( aEntry[ P_SIZE ], ::oApp:lSIUnits ) )
               endif
            case cWord == "mtime"
               cPart += MCShortDate( aEntry[ P_DATE ], aEntry[ P_TIME ] )
            case cWord == "atime" .or. cWord == "ctime"
               if hb_HHasKey( ::hStat, aEntry[ P_NAME ] )
                  cPart += MCShortDate( hb_SToD( StrTran( Left( ::hStat[ aEntry[ P_NAME ], If( cWord == "atime", 4, 5 ) ], 10 ), "-", "" ) ), ;
                                        SubStr( ::hStat[ aEntry[ P_NAME ], If( cWord == "atime", 4, 5 ) ], 12, 5 ) )
               else
                  cPart += Space( 12 )
               endif
            case cWord == "perm"
               cPart += If( hb_HHasKey( ::hLong, aEntry[ P_NAME ] ), PadR( ::hLong[ aEntry[ P_NAME ], 1 ], 10 ), Space( 10 ) )
            case cWord == "nlink"
               cPart += If( hb_HHasKey( ::hLong, aEntry[ P_NAME ] ), PadL( ::hLong[ aEntry[ P_NAME ], 2 ], 3 ), Space( 3 ) )
            case cWord == "owner"
               cPart += If( hb_HHasKey( ::hLong, aEntry[ P_NAME ] ), PadR( ::hLong[ aEntry[ P_NAME ], 3 ], 8 ), Space( 8 ) )
            case cWord == "group"
               cPart += If( hb_HHasKey( ::hLong, aEntry[ P_NAME ] ), PadR( ::hLong[ aEntry[ P_NAME ], 4 ], 8 ), Space( 8 ) )
            case cWord == "type"
               if hb_HHasKey( ::hLong, aEntry[ P_NAME ] )
                  cPart += Left( ::hLong[ aEntry[ P_NAME ], 1 ], 1 )
               else
                  cPart += If( aEntry[ P_DIR ], "d", "-" )
               endif
            case cWord == "mark"
               cPart += If( aEntry[ P_MARKED ], "*", " " )
            case cWord == "space"
               cPart += " "
         endcase
      next
      cLine += hb_UPadR( hb_UTF8SubStr( cPart, 1, Max( 0, nColW - 1 ) ), nColW )
   next

return hb_UPadR( cLine, nWidth )

//-----------------------------------------------------------------------------------------//

function MCShortDate( dDate, cTime )

   // mc-style 12-char timestamp: "Oct 24 19:20"
   local aMon := { "Jan", "Feb", "Mar", "Apr", "May", "Jun", ;
                   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

   if Empty( dDate )
      return Space( 12 )
   endif

return aMon[ Month( dDate ) ] + " " + PadL( hb_ntos( Day( dDate ) ), 2 ) + " " + PadR( Left( cTime, 5 ), 5 )

function MCUFmtNeedsLong( cFmt )

   // does the user format reference stat-backed fields (perm/nlink/owner/group/type)?
   local cWord

   for each cWord in hb_ATokens( StrTran( Lower( cFmt ), "|", " " ) )
      if cWord == "perm" .or. cWord == "nlink" .or. cWord == "owner" .or. ;
         cWord == "group" .or. cWord == "type"
         return .T.
      endif
   next

return .F.

function MCUFmtNeedsStat( cFmt )

   local cWord

   for each cWord in hb_ATokens( StrTran( Lower( cFmt ), "|", " " ) )
      if cWord == "atime" .or. cWord == "ctime"
         return .T.
      endif
   next

return .F.

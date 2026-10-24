/*
 * mcpanel.prg - MCPanel: one file panel of the Commander
 */

#include "hbclass.ch"
#include "inkey.ch"
#include "mc.ch"
#include "directry.ch"

//-----------------------------------------------------------------------------------------//

CLASS MCPanel

   DATA   cPath
   DATA   aFiles      INIT {}
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
   DATA   lBrief      INIT .F.
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
   METHOD GoDir( cPath )
   METHOD SortFiles()
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
   METHOD RowToIndex( nRow )
   METHOD FixScroll()
   METHOD Scroll( nDelta )
   METHOD Move( nKey )
   METHOD Current()
   METHOD MarkCurrent()
   METHOD MarkedEntries()
   METHOD EnterKey()
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
         ::lCaseSens, ::cFilter, ::lBrief, ::cMode, ::aDirSizes, ::lSizesComputed }

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
      ::cPath := hb_PathNormalize( cPath )
   endif
   ::cMode     := "listing"
   ::nCurrent  := 1
   ::nOffset   := 0
   ::aDirSizes := { => }
   ::Rescan()

return nil

//-----------------------------------------------------------------------------------------//

METHOD Rescan() CLASS MCPanel

   local aDir, aEntry, cFull
   local lShowHidden := ::oApp:lShowHidden

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
         if aEntry[ 6 ] .or. FilterMatch( aEntry[ 1 ], ::cFilter, ::lCaseSens )
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
      cFull := hb_FNameMerge( ::cPath, aEntry[ F_NAME ] )
      if hb_DirExists( cFull )
         AAdd( ::aFiles, { aEntry[ F_NAME ], 0, aEntry[ F_DATE ], aEntry[ F_TIME ], ;
                           aEntry[ F_ATTR ], .T., .F. } )
      else
         if FilterMatch( aEntry[ F_NAME ], ::cFilter, ::lCaseSens )
            AAdd( ::aFiles, { aEntry[ F_NAME ], aEntry[ F_SIZE ], aEntry[ F_DATE ], ;
                              aEntry[ F_TIME ], aEntry[ F_ATTR ], .F., .F. } )
         endif
      endif
   next

   ::SortFiles()
   ::FixScroll()

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

   if ::cSort != "unsorted"
      ASort( aRest,,, { | a, b | PanelCompare( a, b, ::cSort, ::lCaseSens, lMix ) } )
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

static function PanelCompare( a, b, cSort, lCaseSens, lMix )

   local n := .F., cA, cB

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
   if aEntry[ P_DIR ]
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

return cInfo

//-----------------------------------------------------------------------------------------//

METHOD RowToIndex( nRow ) CLASS MCPanel

   local nRel := nRow - ::nTop - 2   // frame + header

   if nRel < 0 .or. nRel >= ::VisibleRows()
      return 0
   endif

   nRel += ::nOffset + 1
   if nRel > Len( ::aFiles )
      return 0
   endif

return nRel

//-----------------------------------------------------------------------------------------//

METHOD FixScroll() CLASS MCPanel

   if ::nCurrent < 1
      ::nCurrent := 1
   endif
   if ::nCurrent > Len( ::aFiles )
      ::nCurrent := Len( ::aFiles )
   endif
   if ::nCurrent <= ::nOffset
      ::nOffset := ::nCurrent - 1
   endif
   if ::nCurrent > ::nOffset + ::VisibleRows()
      ::nOffset := ::nCurrent - ::VisibleRows()
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
      case nKey == K_UP    ; ::nCurrent--
      case nKey == K_DOWN  ; ::nCurrent++
      case nKey == K_PGUP  ; ::nCurrent -= ::VisibleRows()
      case nKey == K_PGDN  ; ::nCurrent += ::VisibleRows()
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
      ::nCurrent++
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

METHOD EnterKey() CLASS MCPanel

   local aEntry := ::Current(), cFull, cCmd

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
            ::GoDir( hb_FNameDir( ::cPath ) )
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
   if ::cMode == "listing" .and. ::nOffset + nRows < Len( ::aFiles )
      hb_DispOutAt( ::nTop, ::nRight - 1, hb_UTF8ToStr( "↓" ), cFrame )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD DisplayListing() CLASS MCPanel

   local oApp := ::oApp, nW := ::nRight - ::nLeft - 1
   local nRows := ::VisibleRows(), n, nIdx, aEntry, cLine, cColor
   local cHdr

   // header
   if ::lBrief
      cHdr := " Name"
   else
      cHdr := " Name" + Space( Max( 1, nW - 27 ) ) + "Size      MTime"
   endif
   hb_DispOutAt( ::nTop + 1, ::nLeft + 1, hb_UPadR( cHdr, nW ), oApp:aPalette[ CLR_HEADER ] )

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

   // mini status
   if oApp:lMiniStatus
      hb_DispOutAt( ::nBottom - 1, ::nLeft + 1, hb_UPadR( ::MiniStatus(), nW ), oApp:aPalette[ CLR_MINI ] )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD EntryLine( aEntry, nWidth ) CLASS MCPanel

   local cName := aEntry[ P_NAME ], cSize, cTime, cLine

   if aEntry[ P_DIR ] .and. aEntry[ P_NAME ] != "/.."
      cName += "/"
   endif
   if ::lBrief
      return hb_UPadR( " " + cName, nWidth )
   endif
   if aEntry[ P_DIR ]
      cSize := If( aEntry[ P_NAME ] == "/..", "UP--DIR ", ;
              If( ::lSizesComputed, Str( aEntry[ P_SIZE ], 8 ), "SUB-DIR " ) )
   else
      cSize := If( aEntry[ P_SIZE ] < 0, PadL( "?", 8 ), Str( aEntry[ P_SIZE ], 8 ) )
   endif
   cTime := If( Empty( aEntry[ P_DATE ] ), Space( 16 ), ;
                DToC( aEntry[ P_DATE ] ) + " " + Left( aEntry[ P_TIME ], 5 ) )

   cLine := " " + hb_UPadR( hb_UTF8SubStr( cName, 1, nWidth - 27 ), nWidth - 27 ) + ;
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

function FilterMatch( cName, cFilter, lCaseSens )

   local aMasks := hb_aTokens( hb_defaultValue( cFilter, "*" ), "; " ), cMask

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

/*
 * mc.prg - Midnight Commander style dual-panel file manager
 * Built with the hbide GUI classes (hbwindow/hbmenu/hbbutton) over Harbour GT.
 * Turbo Vision look. Pure Harbour; external commands only for chmod/ln/chown.
 */

#include "hbclass.ch"
#include "../hbmenu.ch"
#include "inkey.ch"
#include "setcurs.ch"
#include "hbgtinfo.ch"
#include "box.ch"
#include "mc.ch"
#include "directry.ch"
#include "fileio.ch"

#xcommand DEFAULT <uVar1> := <uVal1> ;
   [, <uVarN> := <uValN> ] => ;
      If( <uVar1> == nil, <uVar1> := <uVal1>, ) ;;
    [ If( <uVarN> == nil, <uVarN> := <uValN>, ); ]

#define HB_INKEY_GTEVENT   1024


//-----------------------------------------------------------------------------------------//

function Main( cStartDir )

   local oApp

   Set( _SET_ESCAPE, .F. )  // Esc must not cancel the program at InKey()
   Set( _SET_CANCEL, .F. )  // Alt+C is quick cd, not Harbour's cancel key

   // File names are raw filesystem bytes; on Linux that is UTF-8. Running
   // the whole app on the UTF-8 codepage makes the display layer pass
   // those bytes through untranslated (non-lossy) instead of mangling
   // them through an 8-bit CP. ASCII UI text is unaffected.
   hb_cdpSelect( "UTF8" )

   oApp := MCApp():New( hb_defaultValue( cStartDir, hb_cwd() ) )

   oApp:Activate()

return nil

//-----------------------------------------------------------------------------------------//

CLASS MCApp

   DATA   oPanel1
   DATA   oPanel2
   DATA   nActive      INIT 1
   DATA   oMenu
   DATA   lEnd         INIT .F.
   DATA   cBackScreen
   DATA   cCmdLine     INIT ""
   DATA   oCmdLine
   DATA   cCp1        INIT ""        // panel display charsets from cfg
   DATA   cCp2        INIT ""
   DATA   aKeyBind    INIT {}        // { { triggerCode, canonical K_Fn }, x 10 }: learnable F1..F10
   DATA   cListMode1  INIT "full"    // per-panel listing formats from cfg
   DATA   cListMode2  INIT "full"
   DATA   cUserFmt1   INIT "half name | size"
   DATA   cUserFmt2   INIT "half name | size"
   DATA   lUserMini1  INIT .F.
   DATA   lUserMini2  INIT .F.
   DATA   cLastOutput  INIT ""
   DATA   aHistory     INIT {}
   DATA   aHotlist     INIT {}
   DATA   nPrefixKey   INIT 0

   // configuration (persisted)
   DATA   lShowHidden     INIT .F.
   DATA   lConfirmDelete  INIT .T.
   DATA   lConfirmOverwrite INIT .T.
   DATA   lConfirmExecute INIT .T.
   DATA   lConfirmExit    INIT .T.
   DATA   lMiniStatus     INIT .T.
   DATA   lMixDirs        INIT .F.
   DATA   lComputeTotals  INIT .F.
   DATA   lShowFreeSpace  INIT .T.
   DATA   lAutoSaveSetup  INIT .T.
   DATA   lShellPatterns  INIT .T.
   DATA   lShowBackup     INIT .T.
   DATA   lMarkDown       INIT .T.
   DATA   lLynxMotion     INIT .F.
   DATA   lMkdirAutoname  INIT .F.
   DATA   lFileTypes      INIT .T.
   DATA   lFastReload     INIT .F.
   DATA   lVerboseOp      INIT .T.
   DATA   lInternalView   INIT .T.
   DATA   lInternalEdit   INIT .T.
   DATA   lCdFollowsLinks INIT .T.
   DATA   lSafeDelete    INIT .F.  // mc default: both safe_* are FALSE (mc setup.c)
   DATA   lSafeOverwrite INIT .F.
   DATA   nPauseAfterRun INIT 1   // mc default: pause_on_dumb_terminals (mc execute.c:60)
   DATA   lClassicProgressbar INIT .T.  // mc default TRUE (mc filegui.c:160)
   DATA   lSinglePress  INIT .T.  // mc default TRUE (mc lib/tty/key.c:94)
   DATA   nEscTimeout   INIT 1000000  // us; mc default G_USEC_PER_SEC (key.c:96)
   DATA   lAskNewFile   INIT .F.  // mc default FALSE (mc setup.c:108)
   DATA   lAutoMenus    INIT .F.  // mc default FALSE (mc setup.c:99)
   DATA   lDropMenus    INIT .F.  // mc default FALSE (mc setup.c:101)
   DATA   lBarLit       INIT .F.  // menu bar highlighted without dropdown (drop_menus=FALSE)
   DATA   nBarItem      INIT 0
   DATA   lShowAllAmbig INIT .F.  // mc default FALSE (mc lib/global.c:76)
   DATA   lRotatingDash INIT .T.  // mc default TRUE (mc layout.c:86)
   DATA   lPreallocate  INIT .F.  // mc: vfs preallocate_space, default FALSE
   DATA   lCowClone     INIT .T.  // mc: vfs file_cloning, default TRUE (lib/global.c:110)
   DATA   lSIUnits        INIT .F.
   DATA   cExternalView   INIT "less"
   DATA   cExternalEdit   INIT "vi"
   DATA   lScrollPages    INIT .T.
   DATA   lScrollCenter   INIT .F.
   DATA   lMousePages     INIT .T.
   DATA   lEqualSplit     INIT .T.
   DATA   lHorizontal     INIT .F.
   DATA   nScrRows        INIT 0
   DATA   nScrCols        INIT 0
   DATA   lMenubar        INIT .T.
   DATA   lCmdlineBar     INIT .T.
   DATA   lKeybar         INIT .T.
   DATA   nTheme          INIT 1
   DATA   aThemes
   DATA   aPalette

   METHOD New( cStartDir )
   METHOD Activate()
   METHOD Layout()
   METHOD Repaint()
   METHOD CheckResize()
   METHOD ShowMenuBar()
   METHOD ShowCmdLine()
   METHOD ShowKeyBar()
   METHOD ActivePanel() INLINE If( ::nActive == 1, ::oPanel1, ::oPanel2 )
   METHOD OtherPanel()  INLINE If( ::nActive == 1, ::oPanel2, ::oPanel1 )
   METHOD SwitchPanel()
   METHOD SwapPanels()
   METHOD Rescan()
   METHOD PanelsOnOff()
   METHOD RunCommand()
   METHOD ShowOutput( cOutput )
   METHOD CmdInsertName()
   METHOD QuickCd()
   METHOD QuickSearch()
   METHOD DirSizes()
   METHOD CompareDirs()
   METHOD BuildMenu()
   METHOD AltKey( nKey )
   METHOD MouseClick( nRow, nCol, lDbl )
   METHOD GrabScreen()
   METHOD SetTheme( nTheme )
   METHOD LoadCfg()
   METHOD SaveCfg( lQuiet )
   METHOD CfgFile()    INLINE hb_DirSepAdd( hb_GetEnv( "HOME" ) ) + ".hbmc.ini"

   // menu action entry points (implemented in mcmenu.prg)
   METHOD PanelListing( nPanel )
   METHOD PanelQuickView( nPanel )
   METHOD PanelInfo( nPanel )
   METHOD PanelTree( nPanel )
   METHOD Panelize( nPanel )
   METHOD PanelCharset()
   METHOD ListingFormat( nPanel )
   METHOD SortOrder( nPanel )
   METHOD FilterDlg( nPanel )
   METHOD VfsLink( nPanel, cScheme )
   METHOD FileView()
   METHOD FileViewName()
   METHOD FileFilteredView()
   METHOD FileEdit()
   METHOD FileEditNew()
   METHOD RunExternal( cCmd, cFull )
   METHOD FileCopy()
   METHOD FileChmod()
   METHOD FileLink()
   METHOD FileSymlink()
   METHOD FileEditSymlink()
   METHOD FileChown()
   METHOD FileMove()
   METHOD FileMkdir()
   METHOD FileDelete()
   METHOD SelectGroup( lSelect )
   METHOD InvertSelection()
   METHOD UserMenu()
   METHOD DirectoryTreeDlg()
   METHOD FindFile()
   METHOD CmdHistory()
   METHOD Hotlist()
   METHOD EditExtFile()
   METHOD EditMenuFile()
   METHOD OptionsConfig()
   METHOD OptionsLayout()
   METHOD OptionsPanel()
   METHOD OptionsConfirm()
   METHOD OptionsAppearance()
   METHOD LearnKeys()
   METHOD TranslateKey( nKey )
   METHOD HelpDialog()
   METHOD About()
   METHOD Quit()
   METHOD DlgInput( cTitle, cLabel, cDefault, nLen )
   METHOD DlgCopy( nCount, cDefault, cAction, cVerb )
   METHOD FileCopyBg( oSrc, aMarked, cDest )
   METHOD FileMoveBg( oSrc, aMarked, cDest )
   METHOD BgJobs()
   METHOD DlgConfirm( cTitle, cMsg, cOk, lSafeDefault )
   METHOD DlgList( cTitle, aItems, nDef )
   METHOD OtherPanelRef()
   METHOD MenuBarLight()
   METHOD MenuBarUnlight()
   METHOD MenuBarMove( nDelta )

ENDCLASS

//-----------------------------------------------------------------------------------------//

METHOD New( cStartDir ) CLASS MCApp

   local n

   SET SCOREBOARD OFF
   SET DATE FORMAT TO "yyyy-mm-dd"

   ::GrabScreen()
   Set( _SET_EVENTMASK, hb_bitOr( INKEY_KEYBOARD, HB_INKEY_GTEVENT, INKEY_ALL ) )
   SetMode( 40, 120 )

   // MC classic, TV cyan, mono
   ::aThemes := { ;
      { "W/B",   "W+/B",  "GR+/B",  "N/BG",  "GR+/BG", "W/B",  "GR+/B",  "GR+/B", "W/B",   "G+/B"  }, ;
      { "N/BG",  "W+/BG", "GR+/BG", "W+/B",  "GR+/B",  "N/BG", "N+/BG",  "N+/BG","N/BG",  "G+/BG" }, ;
      { "N/W",   "W+/W",  "N/W",    "W/N",   "W+/N",   "N/W",  "W+/W",   "W+/W", "N/W",   "N/W"   } }

   __ClsModMsg( PushButton( 0, 0 ):ClassH, "DISPLAY", @BtnDisplay() )
   __ClsModMsg( CheckBox( 0, 0 ):ClassH, "DISPLAY", @ChkDisplay() )
   __ClsModMsg( PushButton( 0, 0 ):ClassH, "HITTEST", @BtnHitTest() )
   __ClsModMsg( RadioButto( 0, 0 ):ClassH, "DISPLAY", @RadDisplay() )

   ::aKeyBind := {}
   for n := 1 to 10
      AAdd( ::aKeyBind, { MCKeyDefaults()[ n ], MCKeyDefaults()[ n ] } )
   next

   ::LoadCfg()
   ::oCmdLine := MCCommandLine():New( self )
   ::SetTheme( ::nTheme )

   ::oPanel1 := MCPanel():New( cStartDir )
   ::oPanel2 := MCPanel():New( cStartDir )
   ::oPanel1:oApp := Self
   ::oPanel2:oApp := Self
   ::oPanel1:cCp := ::cCp1
   ::oPanel2:cCp := ::cCp2
   ::oPanel1:cListMode := ::cListMode1
   ::oPanel2:cListMode := ::cListMode2
   ::oPanel1:lBrief := ( ::cListMode1 == "brief" )
   ::oPanel2:lBrief := ( ::cListMode2 == "brief" )
   ::oPanel1:cUserFmt := ::cUserFmt1
   ::oPanel2:cUserFmt := ::cUserFmt2
   ::oPanel1:lUserMiniStatus := ::lUserMini1
   ::oPanel2:lUserMiniStatus := ::lUserMini2

   ::oMenu := ::BuildMenu()
   SetCursor( SC_NONE )

   __MCApp( Self )

   ErrorBlock( { | oError | MCMsgBox( "Error", MCErrorMsg( oError ) ) } )

return Self

//-----------------------------------------------------------------------------------------//

// Module-level handle to the running app, for plain functions (MCMsgBox is
// also the ErrorBlock handler, where Self is not available).
function __MCApp( oApp )

   static s_oApp

   if PCount() > 0
      s_oApp := oApp
   endif

return s_oApp

//-----------------------------------------------------------------------------------------//

METHOD SetTheme( nTheme ) CLASS MCApp

   ::nTheme := nTheme
   ::aPalette := ::aThemes[ ::nTheme ]

return nil

//-----------------------------------------------------------------------------------------//

METHOD Layout() CLASS MCApp

   local nTop    := If( ::lMenubar, 1, 0 )
   local nBottom := MaxRow() - If( ::lKeybar, 1, 0 ) - If( ::lCmdlineBar, 2, 0 )
   local nMidCol := Int( MaxCol() / 2 )
   local nMidRow := Int( ( nBottom - nTop + 1 ) / 2 ) + nTop - 1

   if ::lHorizontal
      ::oPanel1:SetPos( nTop, 0, nMidRow, MaxCol() )
      ::oPanel2:SetPos( nMidRow + 1, 0, nBottom, MaxCol() )
   else
      if ::lEqualSplit
         ::oPanel1:SetPos( nTop, 0, nBottom, nMidCol + 1 )
         ::oPanel2:SetPos( nTop, nMidCol + 1, nBottom, MaxCol() )
      else
         ::oPanel1:SetPos( nTop, 0, nBottom, Int( MaxCol() * 2 / 3 ) )
         ::oPanel2:SetPos( nTop, Int( MaxCol() * 2 / 3 ) + 1, nBottom, MaxCol() )
      endif
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD GrabScreen() CLASS MCApp

   ::cBackScreen := SaveScreen( 0, 0, MaxRow(), MaxCol() )

return nil

//-----------------------------------------------------------------------------------------//

// Terminal resize (SIGWINCH): the GT updates MaxRow()/MaxCol() and repaints
// its shadow buffer as-is, which leaves the old layout's pixels outside the
// new geometry (double chrome). mc redraws cleanly on WINCH; do the same:
// wipe the whole screen and relayout+repaint inside a single DispBegin so
// the clear is never visible.
METHOD CheckResize() CLASS MCApp

   if MaxRow() != ::nScrRows .or. MaxCol() != ::nScrCols
      ::nScrRows := MaxRow()
      ::nScrCols := MaxCol()
      DispBegin()
      hb_Scroll( 0, 0, ::nScrRows, ::nScrCols, 0, 0, "W/N", " " )
      SetPos( 0, 0 )
      ::Layout()
      ::Repaint()
      DispEnd()
      return .T.
   endif

return .F.

//-----------------------------------------------------------------------------------------//

METHOD Repaint() CLASS MCApp

   DispBegin()
   if ::lMenubar
      ::ShowMenuBar()
   endif
   ::oPanel1:lActive := ( ::nActive == 1 )
   ::oPanel2:lActive := ( ::nActive == 2 )
   ::oPanel1:Display()
   ::oPanel2:Display()
   if ::lCmdlineBar
      ::ShowCmdLine()
   endif
   if ::lKeybar
      ::ShowKeyBar()
   endif
   DispEnd()

return nil

//-----------------------------------------------------------------------------------------//

METHOD ShowMenuBar() CLASS MCApp

   ::oMenu:LoadColors()
   ::oMenu:Display()

return nil

//-----------------------------------------------------------------------------------------//

METHOD ShowCmdLine() CLASS MCApp

   ::oCmdLine:Show()

return nil

//-----------------------------------------------------------------------------------------//

METHOD ShowKeyBar() CLASS MCApp

   local aKeys := { "Help", "Menu", "View", "Edit", "Copy", "RenMov", "Mkdir", "Delete", "PullDn", "Quit" }
   local n, cLabel, nCol := 0

   hb_DispOutAt( MaxRow(), 0, Space( MaxCol() + 1 ), "N/N" )
   for n := 1 to 10
      cLabel := If( n < 10, " " + hb_ntos( n ) + PadR( aKeys[ n ], 9 ), "10" + PadR( aKeys[ n ], 8 ) )
      hb_DispOutAt( MaxRow(), nCol, Left( cLabel, 2 ), "BG+/N" )
      hb_DispOutAt( MaxRow(), nCol + 2, SubStr( cLabel, 3 ), "W/N" )
      nCol += 12
   next

return nil

//-----------------------------------------------------------------------------------------//

METHOD SwitchPanel() CLASS MCApp

   ::nActive := If( ::nActive == 1, 2, 1 )
   if ! ::lFastReload
      ::ActivePanel():ReloadIfChanged()
   endif
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD SwapPanels() CLASS MCApp

   local a1 := ::oPanel1:Export(), a2 := ::oPanel2:Export()

   ::oPanel1:Import( a2 )
   ::oPanel2:Import( a1 )
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD Rescan() CLASS MCApp

   ::oPanel1:Rescan()
   ::oPanel2:Rescan()
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD PanelsOnOff() CLASS MCApp

   local nKey, aLines, nFirst, n

   DispBegin()
   hb_Scroll( 0, 0, MaxRow(), MaxCol(), 0, 0, "W/N", " " )
   if ! Empty( ::cLastOutput )
      // split into lines like ShowOutput: hb_DispOutAt renders hb_eol() as
      // a glyph box otherwise
      aLines := hb_aTokens( StrTran( ::cLastOutput, Chr( 13 ) ), Chr( 10 ) )
      nFirst := Max( 1, Len( aLines ) - MaxRow() + 1 )
      for n := nFirst to Len( aLines )
         hb_DispOutAt( n - nFirst, 0, PadR( aLines[ n ], MaxCol() + 1 ), "W/N" )
      next
   endif
   hb_DispOutAt( MaxRow(), 0, " Press any key to return to the panels ", "N/W" )
   DispEnd()
   nKey := InKey( 0, INKEY_ALL + HB_INKEY_GTEVENT )
   if nKey >= K_ALT_Q .and. nKey <= K_ALT_M  // allow menu shortcut while hidden
      ::Repaint()
      ::oMenu:ProcessKey( nKey )
   else
      ::Repaint()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD CmdInsertName() CLASS MCApp

   local aEntry := ::ActivePanel():Current()

   if aEntry != nil
      ::oCmdLine:Append( ShellQuote( MCEntryPath( ::ActivePanel(), aEntry ) ) + " " )
      ::cCmdLine := ::oCmdLine:cText
      ::ShowCmdLine()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD RunCommand() CLASS MCApp

   local cCmd := AllTrim( ::cCmdLine ), cOut := "", cErr := "", nRet
   local cFull

   if Empty( cCmd )
      return nil
   endif

   AAdd( ::aHistory, cCmd )
   if Len( ::aHistory ) > 30
      ADel( ::aHistory, 1 )
      ASize( ::aHistory, 30 )
   endif

   if Left( cCmd, 3 ) == "cd " .or. cCmd == "cd"
      cFull := MCAbsPath( ::ActivePanel():cPath, SubStr( cCmd + " ", 4 ) )
      if MCVfsKind( cFull ) != "local"
         ::ActivePanel():GoDir( cFull )   // VFS destinations are validated by listing them
      elseif hb_DirExists( cFull )
         ::ActivePanel():GoDir( cFull )
      else
         MCMsgBox( "cd", "Directory does not exist:" + Chr( 10 ) + cFull )
      endif
   else
      if ::lConfirmExecute
         ::cLastOutput := "$ " + cCmd + hb_eol()
      else
         ::cLastOutput := ""
      endif
      nRet := hb_ProcessRun( MCShWrap( "cd " + ShellQuote( ::ActivePanel():cPath ) + " && " + cCmd ),, @cOut, @cErr )
      ::cLastOutput := "$ " + cCmd + hb_eol() + cOut + cErr + ;
         If( nRet != 0, hb_eol() + "(exit code " + hb_ntos( nRet ) + ")", "" )
      // mc execute.c:331: pause only when the option says so
      if MCPauseShown( ::nPauseAfterRun )
         ::ShowOutput( ::cLastOutput )
      endif
      ::Rescan()
   endif
   ::oCmdLine:SetText( "" )
   ::cCmdLine := ""
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD ShowOutput( cOutput ) CLASS MCApp

   local aLines := hb_aTokens( StrTran( cOutput, Chr( 13 ) ), Chr( 10 ) )
   local nMax := MaxRow() - 1, nFirst := Max( 1, Len( aLines ) - nMax + 1 ), n, nRow := 0

   hb_Scroll( 0, 0, MaxRow(), MaxCol(), 0, 0, "W/N", " " )
   for n := nFirst to Len( aLines )
      hb_DispOutAt( nRow++, 0, PadR( aLines[ n ], MaxCol() + 1 ), "W/N" )
      if nRow > nMax
         exit
      endif
   next
   hb_DispOutAt( MaxRow(), 0, " Press any key to return to the panels ", "N/W" )
   InKey( 0, INKEY_ALL + HB_INKEY_GTEVENT )

return nil

//-----------------------------------------------------------------------------------------//

METHOD QuickCd() CLASS MCApp

   local cPath := ::DlgInput( "Quick cd", "Path:", "", 50 )

   if cPath != nil
      cPath := MCAbsPath( ::ActivePanel():cPath, cPath )
      if hb_DirExists( cPath )
         ::ActivePanel():GoDir( cPath )
      else
         MCMsgBox( "Quick cd", "Directory does not exist:" + Chr( 10 ) + cPath )
      endif
      ::Repaint()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD QuickSearch() CLASS MCApp

   ::ActivePanel():QuickSearch()
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD DirSizes() CLASS MCApp

   ::ActivePanel():ComputeDirSizes()
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD Quit() CLASS MCApp

   if MCJobsActive()
      if ! ::DlgConfirm( "Quit", "Background jobs are still running." + Chr( 10 ) + ;
                         "Cancel them and quit?", "&Quit" )
         return nil
      endif
      MCJobsCancelAll()
   endif
   if ! ::lConfirmExit .or. ::DlgConfirm( "Quit", "Do you really want to quit the Commander?", "&Quit" )
      MCJobsCleanup()
      MCVfsCleanup()
      if ::lAutoSaveSetup
         ::SaveCfg( .T. )
      endif
      ::lEnd := .T.
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD Activate() CLASS MCApp

   local nKey, nKeyRaw, nFlags, lCtrl, nKey2, nAlt, lDone, cK

   ::Layout()
   ::Rescan()
   ::Repaint()
   ::nScrRows := MaxRow()
   ::nScrCols := MaxCol()

   // mc auto_menu (setup.c:99 default FALSE): invoke the user menu at
   // startup (mc filemanager.c:1460 MSG_IDLE -> CK_UserMenu)
   if ::lAutoMenus
      ::UserMenu()
      ::Repaint()
   endif

   while ! ::lEnd
      nKeyRaw := InKey( If( MCJobsNeedTick(), 0.2, 0 ), HB_INKEY_ALL + HB_INKEY_EXT )
      if nKeyRaw == 0
         // Idle tick: advance the background copy queue one chunk.
         MCJobsStep()
         if MCJobsTakeFinished()
            ::Rescan()
            ::Repaint()
         endif
         ::CheckResize()
         loop
      endif
      // Resize arrives as HB_INKEY_NEW_EVENT( HB_K_RESIZE ) (gttrm) or plain
      // K_RESIZE (gtcrs); either way it only needs a relayout, and any other
      // key that rode along still gets processed below.
      ::CheckResize()
      nFlags  := hb_keyMod( nKeyRaw )
      nKey    := ::TranslateKey( hb_keyStd( nKeyRaw ) )
      lCtrl   := hb_bitAnd( nFlags, HB_KF_CTRL ) != 0
      lDone := .T.

      // Ctrl+X prefix commands
      if ::nPrefixKey != 0
         ::nPrefixKey := 0
         cK := ""
         if lCtrl .and. nKey >= 1 .and. nKey <= 26
            cK := Chr( nKey + 64 )
         elseif nKey >= 32 .and. nKey < 256
            cK := Upper( Chr( nKey ) )
         endif
         do case
            case cK == "D" ; ::CompareDirs()
            case cK == "C" ; ::FileChmod()
            case cK == "O" ; ::FileChown()
            case cK == "L" ; ::FileLink()
            case cK == "S" ; ::FileSymlink()
            case cK == "I" ; ::PanelInfo( 3 - ::nActive )
            case cK == "Q" ; ::PanelQuickView( 3 - ::nActive )
            case cK == "T" ; ::PanelTree( ::nActive )
            case cK == "P" ; ::Panelize( ::nActive )
         endcase
         ::Repaint()
         loop
      endif

      if ::lBarLit
         if nKey == K_ESC
            ::MenuBarUnlight()
            loop
         elseif nKey == K_LEFT
            ::MenuBarMove( -1 )
            loop
         elseif nKey == K_RIGHT
            ::MenuBarMove( 1 )
            loop
         elseif nKey == K_ENTER .or. nKey == K_DOWN
            ::lBarLit := .F.
            ::oMenu:ShowPopup( ::nBarItem )
            ::nBarItem := 0
            loop
         else
            ::MenuBarUnlight()   // any other key: bar off, key processed normally
         endif
      endif

      if ::oMenu:IsOpen()
         ::oMenu:ProcessKey( nKey )
         if ! ::oMenu:IsOpen()
            ::Repaint()
         endif
         loop
      endif

      if ::lCmdlineBar .and. ::oCmdLine:HandleKey( nKey, lCtrl )
         ::cCmdLine := ::oCmdLine:cText
         ::Repaint()
         loop
      endif

      do case
         case nKey >= K_ALT_Q .and. nKey <= K_ALT_M .or. ;
              nKey >= K_ALT_A .and. nKey <= K_ALT_Z
            ::AltKey( nKey )

         case nKey == K_F1  ; ::HelpDialog()
         case nKey == K_F2  ; ::UserMenu()
         case nKey == K_F3  ; ::FileView()
         case nKey == K_F4  ; ::FileEdit()
         case nKey == K_SH_F4 ; ::FileEditNew()
         case nKey == K_F5  ; ::FileCopy()
         case nKey == K_F6  ; ::FileMove()
         case nKey == K_F7  ; ::FileMkdir()
         case nKey == K_F8  ; ::FileDelete()
         case nKey == K_F9
            SetCursor( SC_NONE )
            // mc drop_menus (setup.c:101, default FALSE): F9 lights the menu
            // bar without dropping the menu; ON drops it immediately
            if ::lDropMenus
               ::oMenu:ProcessKey( K_ALT_L )
            else
               ::MenuBarLight()
            endif
         case nKey == K_F10 ; ::Quit()

         case nKey == K_TAB .and. nFlags == 0 ; ::SwitchPanel()
         case nKey == K_CTRL_U .and. lCtrl ; ::SwapPanels()
         case nKey == K_CTRL_O .and. lCtrl ; ::PanelsOnOff()
         case nKey == K_CTRL_R .and. lCtrl ; ::Rescan()
         case nKey == K_CTRL_S .and. lCtrl ; ::QuickSearch()
         case nKey == K_CTRL_X .and. lCtrl ; ::nPrefixKey := nKey
         case nKey == K_CTRL_ENTER ; ::CmdInsertName()

         case nKey == K_LBUTTONDOWN
            ::MouseClick( MRow(), MCol(), .F. )
         case nKey == K_LDBLCLK
            ::MouseClick( MRow(), MCol(), .T. )
         case nKey == K_MWFORWARD
            ::ActivePanel():Scroll( -If( ::lMousePages, ::ActivePanel():VisibleRows(), 3 ) )
            ::Repaint()
         case nKey == K_MWBACKWARD
            ::ActivePanel():Scroll( If( ::lMousePages, ::ActivePanel():VisibleRows(), 3 ) )
            ::Repaint()

         case ( nKey == K_UP .or. nKey == K_DOWN .or. nKey == K_LEFT .or. nKey == K_RIGHT .or. ;
                nKey == K_PGUP .or. nKey == K_PGDN .or. nKey == K_HOME .or. nKey == K_END ) .and. nFlags == 0
            if ::lLynxMotion .and. nKey == K_RIGHT .and. ::ActivePanel():LynxEnter()
               // entered the dir under the cursor
            elseif ::lLynxMotion .and. nKey == K_LEFT .and. ::ActivePanel():LynxUp()
               // went to the parent dir
            else
               ::ActivePanel():Move( nKey )
            endif
            ::Repaint()

         case nKey == K_INS .and. nFlags == 0
            ::ActivePanel():MarkCurrent()
            ::Repaint()

         case nKey == K_ENTER
            if Empty( ::cCmdLine )
               ::ActivePanel():EnterKey()
               ::Repaint()
            else
               ::RunCommand()
            endif

         case nKey == K_ESC
            nKey2 := InKey( 0.04 )
            if ( nAlt := MCA_ESCAlt( nKey2 ) ) != 0
               ::AltKey( nAlt )
            else
               ::oCmdLine:SetText( "" )
               ::cCmdLine := ""
               ::Repaint()
            endif

         case nKey == 43 .and. Empty( ::cCmdLine ) ; ::SelectGroup( .T. )    // '+'
         case nKey == 45 .and. Empty( ::cCmdLine ) ; ::SelectGroup( .F. )    // '-'
         case nKey == 42 .and. Empty( ::cCmdLine ) ; ::InvertSelection()     // '*'

         otherwise
            lDone := .F.
      endcase
   end

return nil

//-----------------------------------------------------------------------------------------//

METHOD AltKey( nKey ) CLASS MCApp

   do case
      case nKey == K_ALT_C ; ::QuickCd()
      case nKey == K_ALT_H ; ::CmdHistory()
      case nKey == K_ALT_O ; ( ::OtherPanel():GoDir( ::ActivePanel():cPath ), ::Repaint() )
      case nKey == K_ALT_E ; ::PanelCharset()
      otherwise
         SetCursor( SC_NONE )
         ::oMenu:ProcessKey( nKey )
         if ! ::oMenu:IsOpen()
            ::Repaint()
         endif
   endcase

return nil

//-----------------------------------------------------------------------------------------//

METHOD MouseClick( nRow, nCol, lDbl ) CLASS MCApp

   local oPanel, nIdx, nP

   if nRow == 0 .and. ::lMenubar
      SetCursor( SC_NONE )
      ::oMenu:ProcessKey( K_LBUTTONDOWN )
      if ! ::oMenu:IsOpen()
         ::Repaint()
      endif
      return nil
   endif

   if ::lKeybar .and. nRow == MaxRow()
      do case
         case nCol < 12  ; ::HelpDialog()
         case nCol < 24  ; ::UserMenu()
         case nCol < 36  ; ::FileView()
         case nCol < 48  ; ::FileEdit()
         case nCol < 60  ; ::FileCopy()
         case nCol < 72  ; ::FileMove()
         case nCol < 84  ; ::FileMkdir()
         case nCol < 96  ; ::FileDelete()
         case nCol < 108 ; ( SetCursor( SC_NONE ), ::oMenu:ProcessKey( K_ALT_L ) )
         otherwise       ; ::Quit()
      endcase
      ::Repaint()
      return nil
   endif

   for nP := 1 to 2
      oPanel := If( nP == 1, ::oPanel1, ::oPanel2 )
      if nRow >= oPanel:nTop .and. nRow <= oPanel:nBottom .and. ;
         nCol >= oPanel:nLeft .and. nCol <= oPanel:nRight
         if nP != ::nActive
            ::nActive := nP
         endif
         nIdx := oPanel:RowToIndex( nRow, nCol )
         if nIdx > 0
            oPanel:nCurrent := nIdx
            oPanel:FixScroll()
         endif
         if lDbl
            oPanel:EnterKey()
         endif
         exit
      endif
   next
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD CompareDirs() CLASS MCApp

   local oA := ::ActivePanel(), oB := ::OtherPanel()
   local aEntry, nFound, nMarked := 0

   if oA:cMode != "listing" .or. oB:cMode != "listing"
      MCMsgBox( "Compare directories", "Both panels must be in file listing mode." )
      return nil
   endif

   for each aEntry in oA:aFiles
      if aEntry[ P_NAME ] == "/.."
         loop
      endif
      nFound := AScan( oB:aFiles, { | a | a[ P_NAME ] == aEntry[ P_NAME ] } )
      if nFound == 0 .or. ;
         oB:aFiles[ nFound ][ P_SIZE ] != aEntry[ P_SIZE ] .or. ;
         oB:aFiles[ nFound ][ P_DATE ] != aEntry[ P_DATE ]
         aEntry[ P_MARKED ] := .T.
         nMarked++
      else
         aEntry[ P_MARKED ] := .F.
      endif
   next
   ::Repaint()
   MCMsgBox( "Compare directories", hb_ntos( nMarked ) + " file(s) marked in the active panel:" + Chr( 10 ) + ;
      "missing in the other panel, or different size/date." )

return nil

/*
 * mcdialogs.prg - shared dialogs for the Commander, built with hbide GUI idioms
 */


//-----------------------------------------------------------------------------------------//

// ESC prefix maps to Alt+key (MC meta prefix): ESC,f == Alt+F
// Full path of a panel entry: panelize rows already store absolute paths,
// listing rows are names relative to the panel cwd. hb_FNameMerge() would
// duplicate the base for absolute panelize names.
function MCEntryPath( oPanel, aEntry )

   if oPanel:cMode == "panelize"
      return aEntry[ P_NAME ]
   endif
   if MCVfsKind( oPanel:cPath ) != "local"
      return MCVfsChild( oPanel:cPath, aEntry[ P_NAME ] )
   endif

return hb_FNameMerge( oPanel:cPath, aEntry[ P_NAME ] )

//-----------------------------------------------------------------------------------------//

static function MCA_ESCAlt( nKey )

   local nAlt := 0
   local aMap := { 286, 304, 302, 288, 274, 289, 290, 291, 279, 292, 293, 294, 306, ;
                   305, 280, 281, 272, 275, 287, 276, 278, 303, 273, 301, 277, 300 }

   if nKey >= 97 .and. nKey <= 122      // a-z
      nAlt := aMap[ nKey - 96 ]
   endif

return nAlt

//-----------------------------------------------------------------------------------------//

// Resolve a user-typed path: absolute stays, relative merges into cBase
static function MCAbsPath( cBase, cPath )

   cPath := AllTrim( hb_defaultValue( cPath, "" ) )
   if MCVfsKind( cPath ) != "local"
      return cPath   // VFS URLs are absolute by construction
   endif
   if Left( cPath, 1 ) == "/"
      return hb_PathNormalize( cPath )
   endif
   if MCVfsKind( cBase ) != "local"
      return MCVfsChild( cBase, cPath )
   endif

return hb_PathNormalize( hb_FNameMerge( cBase, cPath ) )

//-----------------------------------------------------------------------------------------//

function MCMsgBox( cTitle, cText )

   local oDlg, GetList := {}, lOk := .F.
   local aLines := {}, cLine, nRow := 2
   local nW := 0, nMaxW := Min( 92, MaxCol() - 8 )

   // wrap long lines to the visible area, cell-based (UTF-8 safe)
   for each cLine in hb_aTokens( hb_defaultValue( cText, "" ), Chr( 10 ) )
      while hb_ULen( cLine ) > nMaxW
         AAdd( aLines, hb_UTF8SubStr( cLine, 1, nMaxW ) )
         cLine := hb_UTF8SubStr( cLine, nMaxW + 1 )
      enddo
      AAdd( aLines, cLine )
   next

   AEval( aLines, { | c | nW := Max( nW, hb_ULen( c ) ) } )
   nW := Min( Max( nW + 8, 30 ), nMaxW + 4 )

   oDlg = HBWindow():Dialog( cTitle, nW, Len( aLines ) + 5, "W+/W" )
   for each cLine in aLines
      oDlg:Say( nRow++, 2, cLine )
   next

   @ oDlg:nBottom - 2, oDlg:nLeft + Int( ( nW ) / 2 ) - 3 GET lOk PUSHBUTTON ;
      CAPTION " &OK " COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" GUISEND cargo := .T. ;
      STATE { || oDlg:End() }

   // Esc = Cancel inside dialogs: enable the READ exit key just for the
   // dialog (app keeps _SET_ESCAPE OFF so Esc never kills the main loop);
   // an Esc-terminated READ leaves lOk .F., so previous config is preserved
   MCDlgEscArm( oDlg, If( __MCApp() != NIL, __MCApp():lSinglePress, .T. ) )
   SetKey( K_ENTER, { || MCDlgEnter( GetList ) } )
   oDlg:Activate( GetList )
   SetKey( K_ENTER, NIL )
   SetKey( K_ESC, NIL )
   Set( _SET_ESCAPE, .F. )

return nil

//-----------------------------------------------------------------------------------------//

METHOD DlgInput( cTitle, cLabel, cDefault, nLen ) CLASS MCApp

   local oDlg, GetList := {}, lDummy, lOk := .F., nBack
   local cValue := PadR( hb_defaultValue( cDefault, "" ), hb_defaultValue( nLen, 40 ) )

   DEFAULT nLen := 40

   oDlg = HBWindow():Dialog( cTitle, Max( nLen + 8, Len( cLabel ) + 8 ), 8, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }

   oDlg:Say( 2, 3, cLabel )
   @ oDlg:nTop + 3, oDlg:nLeft + 3 GET cValue COLOR "W/B,W+/B,W+/W,GR+/W"

   // Cursor after the prefilled text (mc behavior): GET:setFocus() forces
   // pos := 1, so a pre-READ :pos assignment cannot survive; queue an End
   // key instead - the first GET consumes it and lands the cursor at the
   // end of the value. The variable stays PadR'd because the dialog renders
   // the GET with the variable's width, so End lands past the padding: walk
   // the cursor back over the trailing blanks with queued Left keys.
   hb_keyPut( K_END )
   for nBack := 1 to nLen - Len( RTrim( cDefault ) )
      hb_keyPut( K_LEFT )
   next

   @ oDlg:nBottom - 2, oDlg:nLeft + 4 GET lDummy PUSHBUTTON CAPTION "  &OK  " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" GUISEND cargo := .T. ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nRight - 12 GET lDummy PUSHBUTTON CAPTION " &Cancel " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" ;
      STATE { || oDlg:End() }

   // Esc = Cancel inside dialogs: enable the READ exit key just for the
   // dialog (app keeps _SET_ESCAPE OFF so Esc never kills the main loop);
   // an Esc-terminated READ leaves lOk .F., so previous config is preserved
   MCDlgEscArm( oDlg, ::lSinglePress )
   SetKey( K_ENTER, { || MCDlgEnter( GetList ) } )
   oDlg:Activate( GetList )
   SetKey( K_ENTER, NIL )
   SetKey( K_ESC, NIL )
   Set( _SET_ESCAPE, .F. )
   ::Repaint()

   if lOk
      return AllTrim( cValue )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD DlgConfirm( cTitle, cMsg, cOk, lSafeDefault ) CLASS MCApp

   local oDlg, GetList := {}, lDummy, lOk := .F.
   local aLines := hb_aTokens( hb_defaultValue( cMsg, "" ), Chr( 10 ) ), cLine, nRow := 2, nW := 0
   local nColCancel, nColAction

   DEFAULT cOk := "&Yes"
   DEFAULT lSafeDefault := .T.

   AEval( aLines, { | c | nW := Max( nW, hb_ULen( c ) ) } )
   nW := Min( Max( nW + 8, 34 ), 100 )

   oDlg = HBWindow():Dialog( cTitle, nW, Len( aLines ) + 5, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   for each cLine in aLines
      oDlg:Say( nRow++, 2, cLine )
   next

   // lSafeDefault = mc's safe_delete/safe_overwrite semantics: .T. puts the
   // initial focus on Cancel (any stray key fires the safe button); .F. puts
   // it on the action button, like mc preselecting "&Yes". Creation order
   // sets the initial focus; physical layout never changes (Cancel left).
   nColCancel := oDlg:nLeft + Int( ( nW - ( 12 + 4 + Len( AllTrim( cOk ) ) + 4 ) ) / 2 )
   nColAction := nColCancel + 12 + 4
   if lSafeDefault
      @ oDlg:nBottom - 2, nColCancel GET lDummy PUSHBUTTON ;
         CAPTION " &Cancel " COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" GUISEND cargo := .T. ;
         STATE { || oDlg:End() }
      @ oDlg:nBottom - 2, nColAction GET lDummy PUSHBUTTON ;
         CAPTION " " + cOk + " " COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" ;
         STATE { || lOk := .T., oDlg:End() }
   else
      @ oDlg:nBottom - 2, nColAction GET lDummy PUSHBUTTON ;
         CAPTION " " + cOk + " " COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" GUISEND cargo := .T. ;
         STATE { || lOk := .T., oDlg:End() }
      @ oDlg:nBottom - 2, nColCancel GET lDummy PUSHBUTTON ;
         CAPTION " &Cancel " COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" ;
         STATE { || oDlg:End() }
   endif

   // Esc = Cancel inside dialogs: enable the READ exit key just for the
   // dialog (app keeps _SET_ESCAPE OFF so Esc never kills the main loop);
   // an Esc-terminated READ leaves lOk .F., so previous config is preserved
   MCDlgEscArm( oDlg, ::lSinglePress )
   SetKey( K_ENTER, { || MCDlgEnter( GetList ) } )
   oDlg:Activate( GetList )
   SetKey( K_ENTER, NIL )
   SetKey( K_ESC, NIL )
   Set( _SET_ESCAPE, .F. )
   ::Repaint()

return lOk

//-----------------------------------------------------------------------------------------//

METHOD DlgList( cTitle, aItems, nDef ) CLASS MCApp

   local oDlg, GetList := {}, lDummy, lOk := .F.
   local nPick, oLbx, nW := 0, cItem  // numeric GET var: listbox Select() positions by index and the position round-trips through the var

   hb_default( @nDef, 1 )
   nPick := nDef

   if Empty( aItems )
      return 0
   endif
   AEval( aItems, { | c | nW := Max( nW, hb_ULen( c ) ) } )
   nW := Min( Max( nW + 8, 40 ), 100 )

   oDlg = HBWindow():Dialog( cTitle, nW, Min( Len( aItems ) + 6, 24 ), "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }

   @ oDlg:nTop + 1, oDlg:nLeft + 2, oDlg:nBottom - 3, oDlg:nRight - 2 GET nPick LISTBOX aItems ;
      COLOR "N/BG,GR+/BG,N/BG,W+/G,W+/W,W+/W,GR+/W"
   oLbx := ATail( GetList ):Control
   oLbx:Display()
   if nDef > 1
      oLbx:HitTest( 0, 0 )  // noop keep focus
   endif

   @ oDlg:nBottom - 2, oDlg:nLeft + 4 GET lDummy PUSHBUTTON CAPTION "  &OK  " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" GUISEND cargo := .T. ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nRight - 12 GET lDummy PUSHBUTTON CAPTION " &Cancel " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" ;
      STATE { || oDlg:End() }

   // Esc = Cancel inside dialogs: enable the READ exit key just for the
   // dialog (app keeps _SET_ESCAPE OFF so Esc never kills the main loop);
   // an Esc-terminated READ leaves lOk .F., so previous config is preserved
   MCDlgEscArm( oDlg, ::lSinglePress )
   SetKey( K_ENTER, { || MCDlgEnter( GetList ) } )
   oDlg:Activate( GetList )
   SetKey( K_ENTER, NIL )
   SetKey( K_ESC, NIL )
   Set( _SET_ESCAPE, .F. )
   ::Repaint()

   if lOk
      return oLbx:value  // current listbox position; the GET var round-trip via buffer is unreliable
   endif

return 0

//-----------------------------------------------------------------------------------------//

METHOD PanelCharset() CLASS MCApp

   // real mc: Alt-e changes the charset of the panel, recoding display
   // into the system codepage; "No translation" cancels the recoding
   local aCp := MCCpList(), aLabels := {}, nCur := 1, n
   local oP := ::ActivePanel()

   for n := 1 to Len( aCp )
      AAdd( aLabels, aCp[ n ][ 1 ] )
      if aCp[ n ][ 2 ] == oP:cCp
         nCur := n
      endif
   next
   n := ::DlgList( "Panel charset (display only)", aLabels, nCur )
   if n > 0
      oP:cCp := aCp[ n ][ 2 ]
   endif
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD OtherPanelRef() CLASS MCApp

   local oOther := ::OtherPanel()

   if oOther:cMode == "quickview" .or. oOther:cMode == "info"
      DispBegin()
      oOther:Display()
      DispEnd()
   endif

return nil

/*
 * mcmenu.prg - menu bar and option dialogs of the Commander
 * Menu structure mirrors GNU Midnight Commander (local build, no VFS items).
 */


//-----------------------------------------------------------------------------------------//

METHOD BuildMenu() CLASS MCApp

   local oMenu

   MENU oMenu
      MENUITEM " ~Left "
      MENU
         MENUITEM "File listin~g"        ACTION ::PanelListing( 1 )
         MENUITEM "~Quick view     C-x q" ACTION ::PanelQuickView( 1 )
         MENUITEM "~Info           C-x i" ACTION ::PanelInfo( 1 )
         MENUITEM "~Tree           C-x t" ACTION ::PanelTree( 1 )
         MENUITEM "Paneli~ze       C-x p" ACTION ::Panelize( 1 )
         SEPARATOR
         MENUITEM "~Listing format..."    ACTION ::ListingFormat( 1 )
         MENUITEM "~Sort order..."        ACTION ::SortOrder( 1 )
         MENUITEM "~Filter..."            ACTION ::FilterDlg( 1 )
         SEPARATOR
         MENUITEM "~Rescan         C-r"   ACTION ::Rescan()
         SEPARATOR
         MENUITEM "F~TP link..."          ACTION ::VfsLink( 1, "ftp" )
         MENUITEM "S~hell link..."        ACTION ::VfsLink( 1, "sh" )
         MENUITEM "SFT~P link..."         ACTION ::VfsLink( 1, "sftp" )
      ENDMENU

      MENUITEM " ~File "
      MENU
         MENUITEM "~View             F3"  ACTION ::FileView()
         MENUITEM "Vie~w file..."         ACTION ::FileViewName()
         MENUITEM "~Filtered view"        ACTION ::FileFilteredView()
         MENUITEM "~Edit             F4"  ACTION ::FileEdit()
         MENUITEM "~Copy             F5"  ACTION ::FileCopy()
         MENUITEM "C~hmod          C-x c" ACTION ::FileChmod()
         MENUITEM "~Link           C-x l" ACTION ::FileLink()
         MENUITEM "~Symlink        C-x s" ACTION ::FileSymlink()
         MENUITEM "Edit s~ymlink"         ACTION ::FileEditSymlink()
         MENUITEM "Ch~own          C-x o" ACTION ::FileChown()
         MENUITEM "~Rename/Move      F6"  ACTION ::FileMove()
         MENUITEM "~Mkdir            F7"  ACTION ::FileMkdir()
         MENUITEM "~Delete           F8"  ACTION ::FileDelete()
         MENUITEM "Quick c~d       M-c"   ACTION ::QuickCd()
         SEPARATOR
         MENUITEM "Select ~group     +"   ACTION ::SelectGroup( .T. )
         MENUITEM "U~nselect group   -"   ACTION ::SelectGroup( .F. )
         MENUITEM "~Invert selection *"   ACTION ::InvertSelection()
         SEPARATOR
         MENUITEM "E~xit            F10"  ACTION ::Quit()
      ENDMENU

      MENUITEM " ~Command "
      MENU
         MENUITEM "~User menu        F2"  ACTION ::UserMenu()
         MENUITEM "~Directory tree"       ACTION ::DirectoryTreeDlg()
         MENUITEM "~Find file"            ACTION ::FindFile()
         MENUITEM "S~wap panels      C-u" ACTION ::SwapPanels()
         MENUITEM "Switch ~panels on/off C-o" ACTION ::PanelsOnOff()
         MENUITEM "~Compare directories C-x d" ACTION ::CompareDirs()
         MENUITEM "Show directory s~izes" ACTION ::DirSizes()
         MENUITEM "Command ~history  M-h" ACTION ::CmdHistory()
         MENUITEM "Di~rectory hotlist"    ACTION ::Hotlist()
         MENUITEM "~Background jobs"      ACTION ::BgJobs()
         SEPARATOR
         MENUITEM "Edit ~extension file"  ACTION ::EditExtFile()
         MENUITEM "Edit ~menu file"       ACTION ::EditMenuFile()
      ENDMENU

      MENUITEM " ~Options "
      MENU
         MENUITEM "~Configuration..."     ACTION ::OptionsConfig()
         MENUITEM "~Layout..."            ACTION ::OptionsLayout()
         MENUITEM "~Panel options..."     ACTION ::OptionsPanel()
         MENUITEM "C~onfirmation..."      ACTION ::OptionsConfirm()
         MENUITEM "~Appearance..."        ACTION ::OptionsAppearance()
         MENUITEM "~Learn keys..."        ACTION ::LearnKeys()
         SEPARATOR
         MENUITEM "~Save setup"           ACTION ::SaveCfg()
      ENDMENU

      MENUITEM " ~Right "
      MENU
         MENUITEM "File listin~g"        ACTION ::PanelListing( 2 )
         MENUITEM "~Quick view     C-x q" ACTION ::PanelQuickView( 2 )
         MENUITEM "~Info           C-x i" ACTION ::PanelInfo( 2 )
         MENUITEM "~Tree           C-x t" ACTION ::PanelTree( 2 )
         MENUITEM "Paneli~ze       C-x p" ACTION ::Panelize( 2 )
         SEPARATOR
         MENUITEM "~Listing format..."    ACTION ::ListingFormat( 2 )
         MENUITEM "~Sort order..."        ACTION ::SortOrder( 2 )
         MENUITEM "~Filter..."            ACTION ::FilterDlg( 2 )
         SEPARATOR
         MENUITEM "~Rescan         C-r"   ACTION ::Rescan()
         SEPARATOR
         MENUITEM "F~TP link..."          ACTION ::VfsLink( 2, "ftp" )
         MENUITEM "S~hell link..."        ACTION ::VfsLink( 2, "sh" )
         MENUITEM "SFT~P link..."         ACTION ::VfsLink( 2, "sftp" )
      ENDMENU
   ENDMENU

   oMenu:LoadColors()

return oMenu

//-----------------------------------------------------------------------------------------//

METHOD PanelListing( nPanel ) CLASS MCApp

   local oPanel := If( nPanel == 1, ::oPanel1, ::oPanel2 )

   oPanel:cMode := "listing"
   oPanel:Rescan()
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD PanelQuickView( nPanel ) CLASS MCApp

   local oPanel := If( nPanel == 1, ::oPanel1, ::oPanel2 )

   oPanel:cMode := If( oPanel:cMode == "quickview", "listing", "quickview" )
   if oPanel:cMode == "listing"
      oPanel:Rescan()
   endif
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD PanelInfo( nPanel ) CLASS MCApp

   local oPanel := If( nPanel == 1, ::oPanel1, ::oPanel2 )

   oPanel:cMode := If( oPanel:cMode == "info", "listing", "info" )
   if oPanel:cMode == "listing"
      oPanel:Rescan()
   endif
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD PanelTree( nPanel ) CLASS MCApp

   local oPanel := If( nPanel == 1, ::oPanel1, ::oPanel2 )

   if oPanel:cMode == "tree"
      oPanel:cMode := "listing"
      oPanel:Rescan()
   else
      oPanel:cMode := "tree"
      oPanel:aTree := {}
      oPanel:nCurrent := 1
      oPanel:nOffset := 0
   endif
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD Panelize( nPanel ) CLASS MCApp

   local oPanel := If( nPanel == 1, ::oPanel1, ::oPanel2 )
   local cCmd := ::DlgInput( "External panelize", "Command (e.g. find . -type f -name '*.prg'):", "", 45 )
   local cOut := "", cLine, aStat

   if cCmd == nil
      return nil
   endif
   hb_ProcessRun( MCShWrap( "cd " + ShellQuote( oPanel:cPath ) + " && " + cCmd ),, @cOut )
   oPanel:aFiles := {}
   AAdd( oPanel:aFiles, { "/..", 0, CToD( "" ), "", "D", .T., .F. } )
   for each cLine in hb_aTokens( StrTran( cOut, Chr( 13 ) ), Chr( 10 ) )
      cLine := AllTrim( cLine )
      if ! Empty( cLine )
         // The command's output lines are paths as printed, interpreted
         // relative to the panel's current directory (MC semantics).
         cLine := MCAbsPath( oPanel:cPath, cLine )
         aStat := Directory( cLine, "DHS" )
         if ! Empty( aStat )
            AAdd( oPanel:aFiles, { cLine, If( hb_DirExists( cLine ), 0, aStat[ 1, F_SIZE ] ), ;
                                   aStat[ 1, F_DATE ], aStat[ 1, F_TIME ], ;
                                   aStat[ 1, F_ATTR ], hb_DirExists( cLine ), .F. } )
         else
            // Path does not exist from the panel cwd: keep the row but show
            // the metadata as unknown instead of faking zeros.
            AAdd( oPanel:aFiles, { cLine, -1, CToD( "" ), "", "", .F., .F. } )
         endif
      endif
   next
   oPanel:cMode := "panelize"
   oPanel:nCurrent := 1
   oPanel:nOffset := 0
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD ListingFormat( nPanel ) CLASS MCApp

   local oPanel := If( nPanel == 1, ::oPanel1, ::oPanel2 )
   local oDlg, GetList := {}, lDummy, lOk := .F.
   local nFmt := AScan( { "full", "brief", "long", "user" }, oPanel:cListMode ), aFmt[ 4 ], n
   local cUF := PadR( oPanel:cUserFmt, 28 ), lUMS := oPanel:lUserMiniStatus
   local cRadStyle := "(" + Chr( 7 ) + " )"
   local cRadClr := "N/W,N/BG,N/W,N/W,N/W,R/W,N/BG"

   if nFmt == 0
      nFmt := 1
   endif

   oDlg = HBWindow():Dialog( "Listing format", 46, 13, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }

   // same layout pattern as OptionsAppearance: equal-width captions with a
   // leading space (capCol = col + 3 paints the gap after ")"), numeric GET
   // var so the underlying GET buffer is a single hidden digit, and the
   // default single-line group frame on its own rows around the items
   aFmt[ 1 ] := RadioButto( oDlg:nTop + 2, oDlg:nLeft + 4, " " + PadR( "&Full file list", 16 ) )
   aFmt[ 2 ] := RadioButto( oDlg:nTop + 3, oDlg:nLeft + 4, " " + PadR( "&Brief file list", 16 ) )
   aFmt[ 3 ] := RadioButto( oDlg:nTop + 4, oDlg:nLeft + 4, " " + PadR( "&Long file list", 16 ) )
   aFmt[ 4 ] := RadioButto( oDlg:nTop + 5, oDlg:nLeft + 4, " " + PadR( "&User defined", 16 ) )
   AEval( aFmt, { | o | o:capCol := oDlg:nLeft + 8, o:colorSpec := cRadClr, o:cargo := { "GR+/BG", 0, 0 } } )
   oDlg:cargo := aFmt

   @ oDlg:nTop + 1, oDlg:nLeft + 3, oDlg:nTop + 6, oDlg:nLeft + 25 GET nFmt ;
      RADIOGROUP aFmt STYLE cRadStyle COLOR "N/W,N/BG,GR+/BG"

   oDlg:Say( 8, 3, "Format:" )
   @ oDlg:nTop + 8, oDlg:nLeft + 12 GET cUF COLOR "N/BG,W+/BG,N/BG,GR+/BG"

   @ oDlg:nTop + 9, oDlg:nLeft + 3 GET lUMS ;
      CHECKBOX CAPTION "user &mini status" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ oDlg:nBottom - 2, oDlg:nLeft + 4 GET lDummy PUSHBUTTON CAPTION "  &OK  " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" GUISEND cargo := .T. STATE { || lOk := .T., oDlg:End() }
   @ oDlg:nBottom - 2, oDlg:nRight - 12 GET lDummy PUSHBUTTON CAPTION " &Cancel " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" STATE { || oDlg:End() }

   // Esc = Cancel inside dialogs: enable the READ exit key just for the
   // dialog (app keeps _SET_ESCAPE OFF so Esc never kills the main loop);
   // an Esc-terminated READ leaves lOk .F., so previous config is preserved
   MCDlgEscArm( oDlg, ::lSinglePress )
   SetKey( K_ENTER, { || MCDlgEnter( GetList ) } )
   oDlg:Activate( GetList )
   SetKey( K_ENTER, NIL )
   SetKey( K_ESC, NIL )
   Set( _SET_ESCAPE, .F. )
   ::Repaint()

   if lOk
      // numeric GET buffer round-trip is unreliable; read the items
      n := AScan( aFmt, { | o | o:buffer } )
      if n == 0
         n := Min( Max( 1, Int( nFmt ) ), 4 )
      endif
      oPanel:cListMode := { "full", "brief", "long", "user" }[ n ]
      oPanel:lBrief := ( n == 2 )
      if ! Empty( AllTrim( cUF ) )
         oPanel:cUserFmt := AllTrim( cUF )
      endif
      oPanel:lUserMiniStatus := lUMS
      ::Repaint()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD SortOrder( nPanel ) CLASS MCApp

   local oPanel := If( nPanel == 1, ::oPanel1, ::oPanel2 )
   local oDlg, GetList := {}, lDummy, lOk := .F.
   local aNames := { "&Name", "&Extension", "&Size", "&Modify time", "&Access time", "&Change time", "&Inode", "&Unsorted" }
   local aKeys  := { "name", "ext", "size", "mtime", "atime", "ctime", "inode", "unsorted" }
   local nSort := Max( 1, AScan( aKeys, oPanel:cSort ) ), aRad[ 8 ], n
   local lRev := oPanel:lReverse, lCase := oPanel:lCaseSens
   local cRadStyle := "(" + Chr( 7 ) + " )"
   local cRadClr := "N/W,N/BG,N/W,N/W,N/W,R/W,N/BG"
   local cFrame  := hb_UTF8ToStrBox( "┌─┐│┘─└│" )
   local nT, nL

   oDlg = HBWindow():Dialog( "Sort order", 38, 18, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   nT := oDlg:nTop
   nL := oDlg:nLeft

   // Group: Sort
   hb_DispBox( nT + 1, nL + 2, nT + 10, nL + 35, cFrame, "N/W" )
   hb_Scroll( nT + 2, nL + 3, nT + 9, nL + 34,,, "N/W" )
   hb_DispOutAt( nT + 1, nL + 4, " Sort ", "N/W" )

   for n := 1 to 8
      aRad[ n ] := RadioButto( nT + 1 + n, nL + 5, aNames[ n ] )
   next
   AEval( aRad, { | o | o:colorSpec := cRadClr, o:cargo := { "GR+/BG", 0, 0 } } )
   oDlg:cargo := aRad

   // numeric GET var: the GET buffer is a single digit that lands on the
   // group frame corner (the box rect coincides with the manual frame), not
   // a caption string bleeding over the cyan fill
   @ nT + 1, nL + 2, nT + 10, nL + 35 GET nSort ;
      RADIOGROUP aRad STYLE cRadStyle COLOR "N/W,N/BG,GR+/BG"
   // focused state would otherwise repaint a DOUBLE-line default frame over
   // the single-line manual one
   ATail( GetList ):Control:hotBox := cFrame
   // Redraw group frame (radiogroup Display already drew its own frame)
   hb_DispBox( nT + 1, nL + 2, nT + 10, nL + 35, cFrame, "N/W" )
   hb_Scroll( nT + 2, nL + 3, nT + 9, nL + 34,,, "N/W" )
   hb_DispOutAt( nT + 1, nL + 4, " Sort ", "N/W" )
   ATail( GetList ):Control:Display()

   // Group: Options
   hb_DispBox( nT + 11, nL + 2, nT + 14, nL + 35, cFrame, "N/W" )
   hb_Scroll( nT + 12, nL + 3, nT + 13, nL + 34,,, "N/W" )
   hb_DispOutAt( nT + 11, nL + 4, " Options ", "N/W" )

   @ nT + 12, nL + 5 GET lRev ;
      CHECKBOX CAPTION "&Reverse" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ nT + 13, nL + 5 GET lCase ;
      CHECKBOX CAPTION "&Case sensitive" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ oDlg:nBottom - 2, nL + 4 GET lDummy PUSHBUTTON CAPTION "  &OK  " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" GUISEND cargo := .T. STATE { || lOk := .T., oDlg:End() }
   @ oDlg:nBottom - 2, oDlg:nRight - 12 GET lDummy PUSHBUTTON CAPTION " &Cancel " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" STATE { || oDlg:End() }

   // Esc = Cancel inside dialogs: enable the READ exit key just for the
   // dialog (app keeps _SET_ESCAPE OFF so Esc never kills the main loop);
   // an Esc-terminated READ leaves lOk .F., so previous config is preserved
   MCDlgEscArm( oDlg, ::lSinglePress )
   SetKey( K_ENTER, { || MCDlgEnter( GetList ) } )
   oDlg:Activate( GetList )
   SetKey( K_ENTER, NIL )
   SetKey( K_ESC, NIL )
   Set( _SET_ESCAPE, .F. )
   ::Repaint()

   if lOk
      // the numeric GET buffer round-trip is unreliable; read the
      // radiogroup items directly (lBuffer on the selected button)
      n := AScan( aRad, { | o | o:buffer } )
      if n == 0
         n := Min( Max( 1, Int( nSort ) ), 8 )
      endif
      oPanel:cSort := aKeys[ n ]
      oPanel:lReverse := lRev
      oPanel:lCaseSens := lCase
      oPanel:SortFiles()
      ::Repaint()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD FilterDlg( nPanel ) CLASS MCApp

   local oPanel := If( nPanel == 1, ::oPanel1, ::oPanel2 )
   local cFilter := ::DlgInput( "Filter", "File mask (e.g. *.prg or * for all):", oPanel:cFilter, 40 )

   if cFilter != nil
      oPanel:cFilter := If( Empty( cFilter ), "*", cFilter )
      oPanel:Rescan()
      ::Repaint()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD VfsLink( nPanel, cScheme ) CLASS MCApp

   // Left/Right menu "FTP link...", "Shell link...", "SFTP link...": open a
   // remote VFS directory in that panel. All providers are read-only.
   local oPanel := If( nPanel == 1, ::oPanel1, ::oPanel2 )
   local cTitle := If( cScheme == "ftp", "FTP link", If( cScheme == "sh", "Shell link", "SFTP link" ) )
   local cUrl := ::DlgInput( cTitle, cScheme + "://[user@]host[:port]/path:", cScheme + "://", 55 )

   if cUrl == nil .or. Empty( AllTrim( cUrl ) ) .or. AllTrim( cUrl ) == cScheme + "://"
      return nil
   endif
   oPanel:GoDir( AllTrim( cUrl ) )
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD OptionsConfig() CLASS MCApp

   // Layout mirrors mc's real configure_box (mc src/filemanager/boxes.c:560+):
   // left column = File operations + Esc key mode + Pause after run groups,
   // right column = Other options group
   local oDlg, GetList := {}, lDummy, lOk := .F., nEsc := 0, oTmo
   local lVerb := ::lVerboseOp, lTotals := ::lComputeTotals
   local lCP := ::lClassicProgressbar, lMkA := ::lMkdirAutoname
   local lPre := ::lPreallocate, lCow := ::lCowClone
   local lSPress := ::lSinglePress, cTimeout := hb_ntos( ::nEscTimeout )
   local lIE := ::lInternalEdit, lIV := ::lInternalView
   local lAsk := ::lAskNewFile, lAM := ::lAutoMenus, lDM := ::lDropMenus
   local lPat := ::lShellPatterns, lSA := ::lShowAllAmbig
   local lRD := ::lRotatingDash, lCdL := ::lCdFollowsLinks
   local lSD := ::lSafeDelete, lSOv := ::lSafeOverwrite
   local lSave := ::lAutoSaveSetup
   local nPauseRun := ::nPauseAfterRun + 1, aPar[ 3 ], nT, nL, nLC, nRC, n
   local cFrame := hb_UTF8ToStrBox( "┌─┐│┘─└│" )

   oDlg = HBWindow():Dialog( "Configuration", 64, 21, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   nT := oDlg:nTop
   nL := oDlg:nLeft
   nLC := nL + 2
   nRC := nL + 33

   // ---- left column: File operations
   hb_DispBox( nT + 1, nLC, nT + 8, nLC + 29, cFrame, "N/W" )
   hb_Scroll( nT + 2, nLC + 1, nT + 7, nLC + 28,,, "N/W" )
   hb_DispOutAt( nT + 1, nLC + 2, " File operations ", "N/W" )

   @ nT + 2, nLC + 2 GET lVerb ;
      CHECKBOX CAPTION "&Verbose operation" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ nT + 3, nLC + 2 GET lTotals ;
      CHECKBOX CAPTION "Compute &totals" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ nT + 4, nLC + 2 GET lCP ;
      CHECKBOX CAPTION "Classic pro&gressbar" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ nT + 5, nLC + 2 GET lMkA ;
      CHECKBOX CAPTION "Mkdi&r autoname" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ nT + 6, nLC + 2 GET lPre ;
      CHECKBOX CAPTION "&Preallocate space" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ nT + 7, nLC + 2 GET lCow ;
      CHECKBOX CAPTION "Use COW file cloning" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   // ---- left column: Esc key mode
   hb_DispBox( nT + 9, nLC, nT + 12, nLC + 29, cFrame, "N/W" )
   hb_Scroll( nT + 10, nLC + 1, nT + 11, nLC + 28,,, "N/W" )
   hb_DispOutAt( nT + 9, nLC + 2, " Esc key mode ", "N/W" )

   @ nT + 10, nLC + 2 GET lSPress ;
      CHECKBOX CAPTION "S&ingle press" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   hb_DispOutAt( nT + 11, nLC + 4, "Timeout:", "N/W" )
   @ nT + 11, nLC + 14 GET cTimeout PICTURE "9999999999"
   oTmo := ATail( GetList )

   // ---- left column: Pause after run (mc: Never / On dumb terminals / Always)
   hb_DispBox( nT + 13, nLC, nT + 17, nLC + 29, cFrame, "N/W" )
   hb_Scroll( nT + 14, nLC + 1, nT + 16, nLC + 28,,, "N/W" )
   hb_DispOutAt( nT + 13, nLC + 2, " Pause after run ", "N/W" )
   aPar[ 1 ] := RadioButto( nT + 14, nLC + 3, " " + PadR( "&Never", 21 ) )
   aPar[ 2 ] := RadioButto( nT + 15, nLC + 3, " " + PadR( "On d&umb terminals", 21 ) )
   aPar[ 3 ] := RadioButto( nT + 16, nLC + 3, " " + PadR( "Al&ways", 21 ) )
   AEval( aPar, { | o | o:capCol := nLC + 7, o:colorSpec := "N/W,N/BG,N/W,N/W,N/W,R/W,N/BG", o:cargo := { "GR+/BG", 0, 0 } } )
   oDlg:cargo := aPar
   @ nT + 13, nLC, nT + 17, nLC + 29 GET nPauseRun ;
      RADIOGROUP aPar STYLE "(" + Chr( 7 ) + " )" COLOR "N/W,N/BG,GR+/BG"
   // focused state would otherwise repaint a DOUBLE-line default frame over
   // the single-line manual one
   ATail( GetList ):Control:hotBox := cFrame
   hb_DispBox( nT + 13, nLC, nT + 17, nLC + 29, cFrame, "N/W" )
   hb_Scroll( nT + 14, nLC + 1, nT + 16, nLC + 28,,, "N/W" )
   hb_DispOutAt( nT + 13, nLC + 2, " Pause after run ", "N/W" )
   ATail( GetList ):Control:Display()

   // ---- right column: Other options
   hb_DispBox( nT + 1, nRC, nT + 15, nRC + 29, cFrame, "N/W" )
   hb_Scroll( nT + 2, nRC + 1, nT + 14, nRC + 28,,, "N/W" )
   hb_DispOutAt( nT + 1, nRC + 2, " Other options ", "N/W" )

   @ nT + 2, nRC + 2 GET lIE ;
      CHECKBOX CAPTION "Use internal edi&t" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ nT + 3, nRC + 2 GET lIV ;
      CHECKBOX CAPTION "Use internal vie&w" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ nT + 4, nRC + 2 GET lAsk ;
      CHECKBOX CAPTION "A&sk new file name" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ nT + 5, nRC + 2 GET lAM ;
      CHECKBOX CAPTION "Auto m&enus" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ nT + 6, nRC + 2 GET lDM ;
      CHECKBOX CAPTION "&Drop down menus" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ nT + 7, nRC + 2 GET lPat ;
      CHECKBOX CAPTION "S&hell patterns" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ nT + 8, nRC + 2 GET lSA ;
      CHECKBOX CAPTION "Co&mplete: show all" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ nT + 9, nRC + 2 GET lRD ;
      CHECKBOX CAPTION "Rotating d&ash" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ nT + 10, nRC + 2 GET lCdL ;
      CHECKBOX CAPTION "Cd follows lin&ks" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ nT + 11, nRC + 2 GET lSD ;
      CHECKBOX CAPTION "Sa&fe delete" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ nT + 12, nRC + 2 GET lSOv ;
      CHECKBOX CAPTION "Safe overwrite" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ nT + 13, nRC + 2 GET lSave ;
      CHECKBOX CAPTION "A&uto save setup" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ oDlg:nBottom - 2, oDlg:nLeft + 4 GET lDummy PUSHBUTTON CAPTION "  &OK  " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" GUISEND cargo := .T. STATE { || lOk := .T., oDlg:End() }
   @ oDlg:nBottom - 2, oDlg:nRight - 12 GET lDummy PUSHBUTTON CAPTION " &Cancel " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" STATE { || oDlg:End() }

   // Esc = Cancel inside dialogs. mc old_esc_mode (lib/tty/key.c:94, default
   // TRUE = "Single press" on): a lone Esc cancels. With the option OFF the
   // Esc key is only a prefix and the dialog closes on Esc Esc.
   MCDlgEscArm( oDlg, lSPress )
   SetKey( K_ENTER, { || MCDlgEnter( GetList ) } )
   oDlg:Activate( GetList )
   SetKey( K_ENTER, NIL )
   SetKey( K_ESC, NIL )
   Set( _SET_ESCAPE, .F. )
   ::Repaint()

   if lOk
      ::lVerboseOp := lVerb
      ::lComputeTotals := lTotals
      ::lClassicProgressbar := lCP
      ::lMkdirAutoname := lMkA
      ::lPreallocate := lPre
      ::lCowClone := lCow
      ::lSinglePress := lSPress
      ::nEscTimeout := Int( Val( AllTrim( cTimeout ) ) )
      ::lInternalEdit := lIE
      ::lInternalView := lIV
      ::lAskNewFile := lAsk
      ::lAutoMenus := lAM
      ::lDropMenus := lDM
      ::lShellPatterns := lPat
      ::lShowAllAmbig := lSA
      ::lRotatingDash := lRD
      ::lCdFollowsLinks := lCdL
      ::lSafeDelete := lSD
      ::lSafeOverwrite := lSOv
      ::lAutoSaveSetup := lSave
      // numeric GET buffer round-trip is unreliable; read the items
      n := AScan( aPar, { | o | o:buffer } )
      if n == 0
         n := Min( Max( 1, Int( nPauseRun ) ), 3 )
      endif
      ::nPauseAfterRun := n - 1
      ::Rescan()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD OptionsLayout() CLASS MCApp

   local oDlg, GetList := {}, lDummy, lOk := .F.
   local lEq := ::lEqualSplit, lHor := ::lHorizontal, lMb := ::lMenubar
   local lCl := ::lCmdlineBar, lKb := ::lKeybar, lFree := ::lShowFreeSpace

   oDlg = HBWindow():Dialog( "Layout", 44, 12, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }

   @ oDlg:nTop + 2, oDlg:nLeft + 3 GET lEq ;
      CHECKBOX CAPTION "&Equal split" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ oDlg:nTop + 3, oDlg:nLeft + 3 GET lHor ;
      CHECKBOX CAPTION "&Horizontal split" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ oDlg:nTop + 4, oDlg:nLeft + 3 GET lMb ;
      CHECKBOX CAPTION "&Menubar visible" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ oDlg:nTop + 5, oDlg:nLeft + 3 GET lCl ;
      CHECKBOX CAPTION "&Command prompt" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ oDlg:nTop + 6, oDlg:nLeft + 3 GET lKb ;
      CHECKBOX CAPTION "&Keybar visible" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

      @ oDlg:nTop + 7, oDlg:nLeft + 3 GET lFree ;
      CHECKBOX CAPTION "Show &free space" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

@ oDlg:nBottom - 2, oDlg:nLeft + 4 GET lDummy PUSHBUTTON CAPTION "  &OK  " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" GUISEND cargo := .T. STATE { || lOk := .T., oDlg:End() }
   @ oDlg:nBottom - 2, oDlg:nRight - 12 GET lDummy PUSHBUTTON CAPTION " &Cancel " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" STATE { || oDlg:End() }

   // Esc = Cancel inside dialogs: enable the READ exit key just for the
   // dialog (app keeps _SET_ESCAPE OFF so Esc never kills the main loop);
   // an Esc-terminated READ leaves lOk .F., so previous config is preserved
   MCDlgEscArm( oDlg, ::lSinglePress )
   SetKey( K_ENTER, { || MCDlgEnter( GetList ) } )
   oDlg:Activate( GetList )
   SetKey( K_ENTER, NIL )
   SetKey( K_ESC, NIL )
   Set( _SET_ESCAPE, .F. )
   ::Repaint()

   if lOk
      ::lEqualSplit := lEq
      ::lHorizontal := lHor
      ::lMenubar := lMb
      ::lCmdlineBar := lCl
      ::lKeybar := lKb
      ::lShowFreeSpace := lFree
      ::Layout()
      ::Repaint()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD OptionsPanel() CLASS MCApp

   local oDlg, GetList := {}, lDummy, lOk := .F.
   local lMix := ::lMixDirs, lBak := ::lShowBackup, lMd := ::lMarkDown
   local lHidden := ::lShowHidden, lLynx := ::lLynxMotion
   local lFT := ::lFileTypes
   local lFR := ::lFastReload
   local lSP := ::lScrollPages, lSC := ::lScrollCenter, lMP := ::lMousePages
   local lSI := ::lSIUnits, lMini := ::lMiniStatus

   oDlg = HBWindow():Dialog( "Panel options", 44, 18, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }

   @ oDlg:nTop + 2, oDlg:nLeft + 3 GET lMix ;
      CHECKBOX CAPTION "&Mix all files (no dirs first)" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ oDlg:nTop + 3, oDlg:nLeft + 3 GET lBak ;
      CHECKBOX CAPTION "Show &backup files" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ oDlg:nTop + 4, oDlg:nLeft + 3 GET lMd ;
      CHECKBOX CAPTION "Mar&k moves down" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ oDlg:nTop + 5, oDlg:nLeft + 3 GET lHidden ;
      CHECKBOX CAPTION "Show &hidden files" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ oDlg:nTop + 6, oDlg:nLeft + 3 GET lLynx ;
      CHECKBOX CAPTION "L&ynx-like motion" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ oDlg:nTop + 7, oDlg:nLeft + 3 GET lFT ;
      CHECKBOX CAPTION "File &types highlight" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ oDlg:nTop + 8, oDlg:nLeft + 3 GET lFR ;
      CHECKBOX CAPTION "&Fast dir reload" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ oDlg:nTop + 9, oDlg:nLeft + 3 GET lSP ;
      CHECKBOX CAPTION "Pa&ge scrolling" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ oDlg:nTop + 10, oDlg:nLeft + 3 GET lSC ;
      CHECKBOX CAPTION "Center &scrolling" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ oDlg:nTop + 11, oDlg:nLeft + 3 GET lMP ;
      CHECKBOX CAPTION "&Mouse page scrolling" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ oDlg:nTop + 12, oDlg:nLeft + 3 GET lSI ;
      CHECKBOX CAPTION "Use SI si&ze units" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

      @ oDlg:nTop + 13, oDlg:nLeft + 3 GET lMini ;
      CHECKBOX CAPTION "Show mi&ni-status" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

@ oDlg:nBottom - 2, oDlg:nLeft + 4 GET lDummy PUSHBUTTON CAPTION "  &OK  " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" GUISEND cargo := .T. STATE { || lOk := .T., oDlg:End() }
   @ oDlg:nBottom - 2, oDlg:nRight - 12 GET lDummy PUSHBUTTON CAPTION " &Cancel " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" STATE { || oDlg:End() }

   // Esc = Cancel inside dialogs: enable the READ exit key just for the
   // dialog (app keeps _SET_ESCAPE OFF so Esc never kills the main loop);
   // an Esc-terminated READ leaves lOk .F., so previous config is preserved
   MCDlgEscArm( oDlg, ::lSinglePress )
   SetKey( K_ENTER, { || MCDlgEnter( GetList ) } )
   oDlg:Activate( GetList )
   SetKey( K_ENTER, NIL )
   SetKey( K_ESC, NIL )
   Set( _SET_ESCAPE, .F. )
   ::Repaint()

   if lOk
      ::lMixDirs := lMix
      ::lShowBackup := lBak
      ::lMarkDown := lMd
      ::lShowHidden := lHidden
      ::lLynxMotion := lLynx
      ::lFileTypes := lFT
      ::lFastReload := lFR
      ::lScrollPages := lSP
      ::lScrollCenter := lSC
      ::lMousePages := lMP
      ::lSIUnits := lSI
      ::lMiniStatus := lMini
      ::Rescan()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD OptionsConfirm() CLASS MCApp

   local oDlg, GetList := {}, lDummy, lOk := .F.
   local lDel := ::lConfirmDelete, lOvr := ::lConfirmOverwrite
   local lExe := ::lConfirmExecute, lExit := ::lConfirmExit

   oDlg = HBWindow():Dialog( "Confirmation", 44, 11, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }

   @ oDlg:nTop + 2, oDlg:nLeft + 3 GET lDel ;
      CHECKBOX CAPTION "&Delete" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ oDlg:nTop + 3, oDlg:nLeft + 3 GET lOvr ;
      CHECKBOX CAPTION "&Overwrite" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ oDlg:nTop + 4, oDlg:nLeft + 3 GET lExe ;
      CHECKBOX CAPTION "E&xecute" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()
   @ oDlg:nTop + 5, oDlg:nLeft + 3 GET lExit ;
      CHECKBOX CAPTION "E&xit" STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
   ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ oDlg:nBottom - 2, oDlg:nLeft + 4 GET lDummy PUSHBUTTON CAPTION "  &OK  " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" GUISEND cargo := .T. STATE { || lOk := .T., oDlg:End() }
   @ oDlg:nBottom - 2, oDlg:nRight - 12 GET lDummy PUSHBUTTON CAPTION " &Cancel " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" STATE { || oDlg:End() }

   // Esc = Cancel inside dialogs: enable the READ exit key just for the
   // dialog (app keeps _SET_ESCAPE OFF so Esc never kills the main loop);
   // an Esc-terminated READ leaves lOk .F., so previous config is preserved
   MCDlgEscArm( oDlg, ::lSinglePress )
   SetKey( K_ENTER, { || MCDlgEnter( GetList ) } )
   oDlg:Activate( GetList )
   SetKey( K_ENTER, NIL )
   SetKey( K_ESC, NIL )
   Set( _SET_ESCAPE, .F. )
   ::Repaint()

   if lOk
      ::lConfirmDelete    := lDel
      ::lConfirmOverwrite := lOvr
      ::lConfirmExecute   := lExe
      ::lConfirmExit      := lExit
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD OptionsAppearance() CLASS MCApp

   local oDlg, GetList := {}, lDummy, lOk := .F.
   local aNames := { "&Midnight Commander classic", "&Turbo Vision cyan", "Monochro&me" }
   // numeric GET var: the underlying GET paints its buffer text at the
   // group's top-left cell; a 1-char index is wiped by the frame, a long
   // caption string would bleed through the cells the items do not paint
   local nThemeSel := ::nTheme, aRad[ 3 ], n
   local cRadStyle := "(" + Chr( 7 ) + " )"
   local cRadClr := "N/W,N/BG,N/W,N/W,N/W,R/W,N/BG"

   oDlg = HBWindow():Dialog( "Appearance", 40, 10, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }

   for n := 1 to 3
      // captions share one width (27 = longest name with "&") so no
      // trailing cells show through; leading space + capCol = col + 3
      // paints the gap cell between ")" and the label in the row color
      aRad[ n ] := RadioButto( oDlg:nTop + 1 + n, oDlg:nLeft + 4, " " + PadR( aNames[ n ], 27 ) )
      aRad[ n ]:capCol := oDlg:nLeft + 8
   next
   AEval( aRad, { | o | o:colorSpec := cRadClr, o:cargo := { "GR+/BG", 0, 0 } } )
   oDlg:cargo := aRad

   // keep the default single-line group frame (authentic mc look) but give
   // it its own rows/cols around the items: one blank row above/below and
   // margin columns, in the dialog background color so it reads as chrome
   @ oDlg:nTop + 1, oDlg:nLeft + 3, oDlg:nTop + 5, oDlg:nLeft + 36 GET nThemeSel ;
      RADIOGROUP aRad STYLE cRadStyle COLOR "N/W,N/BG,GR+/BG"

   @ oDlg:nBottom - 2, oDlg:nLeft + 4 GET lDummy PUSHBUTTON CAPTION "  &OK  " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" GUISEND cargo := .T. STATE { || lOk := .T., oDlg:End() }
   @ oDlg:nBottom - 2, oDlg:nRight - 12 GET lDummy PUSHBUTTON CAPTION " &Cancel " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" STATE { || oDlg:End() }

   // Esc = Cancel inside dialogs: enable the READ exit key just for the
   // dialog (app keeps _SET_ESCAPE OFF so Esc never kills the main loop);
   // an Esc-terminated READ leaves lOk .F., so previous config is preserved
   // SET DELIMITERS OFF too: the GET's bracket delimiters would paint at
   // the group's edges
   MCDlgEscArm( oDlg, ::lSinglePress )
   Set( _SET_DELIMITERS, .F. )
   SetKey( K_ENTER, { || MCDlgEnter( GetList ) } )
   oDlg:Activate( GetList )
   SetKey( K_ENTER, NIL )
   SetKey( K_ESC, NIL )
   Set( _SET_DELIMITERS, .T. )
   Set( _SET_ESCAPE, .F. )
   ::Repaint()

   if lOk
      n := AScan( aRad, { | o | o:buffer } )
      if n == 0
         n := Min( Max( 1, Int( nThemeSel ) ), 3 )
      endif
      ::SetTheme( n )
      ::Repaint()
   endif

return nil

/*
 * mcops.prg - file operations and Command-menu actions of the Commander
 */


//-----------------------------------------------------------------------------------------//

METHOD FileView() CLASS MCApp

   local aEntry := ::ActivePanel():Current(), cFull

   if aEntry != nil .and. ! aEntry[ P_DIR ]
      cFull := MCEntryPath( ::ActivePanel(), aEntry )
      if MCVfsKind( cFull ) == "local"
         if ! ::lInternalView
            ::RunExternal( ::cExternalView, cFull )
         elseif ! Empty( ::ActivePanel():cCp )
            MCViewerText( MCCpDecode( cFull, ::ActivePanel():cCp ) + "  [" + ::ActivePanel():cCp + "]", ;
                          MCCpDecode( MemoRead( cFull ), ::ActivePanel():cCp ) )
         else
            MCViewer( cFull )
         endif
      else
         MCVfsViewFile( cFull )
      endif
   elseif aEntry != nil
      MCMsgBox( "View", "Cannot view a directory." )
   endif
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD FileViewName() CLASS MCApp

   local cFile := ::DlgInput( "View file", "File name:", hb_FNameMerge( ::ActivePanel():cPath, "" ), 50 )

   if cFile != nil
      cFile := MCAbsPath( ::ActivePanel():cPath, cFile )
      if hb_FileExists( cFile )
         MCViewer( cFile )
      else
         MCMsgBox( "View file", "File not found:" + Chr( 10 ) + cFile )
      endif
   endif
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD FileFilteredView() CLASS MCApp

   local aEntry := ::ActivePanel():Current()
   local cCmd, cOut := "", cFull

   if aEntry == nil .or. aEntry[ P_DIR ]
      MCMsgBox( "Filtered view", "Select a regular file first." )
      return nil
   endif

   cFull := MCEntryPath( ::ActivePanel(), aEntry )
   cCmd := ::DlgInput( "Filtered view", "Command (%f = file, e.g. cat -n %f):", "", 45 )
   if cCmd == nil
      return nil
   endif
   cCmd := StrTran( cCmd, "%f", ShellQuote( cFull ) )
   hb_ProcessRun( MCShWrap( "cd " + ShellQuote( ::ActivePanel():cPath ) + " && " + cCmd + " 2>&1" ),, @cOut )
   MCViewerText( aEntry[ P_NAME ] + " filtered through: " + cCmd, cOut )
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD FileEdit() CLASS MCApp

   local aEntry := ::ActivePanel():Current()

   if aEntry != nil .and. ! aEntry[ P_DIR ]
      if MCVfsKind( MCEntryPath( ::ActivePanel(), aEntry ) ) != "local"
         MCMsgBox( "Edit", "Editing VFS entries is not supported yet (read-only VFS)." )
      elseif ! ::lInternalEdit
         ::RunExternal( ::cExternalEdit, MCEntryPath( ::ActivePanel(), aEntry ) )
      else
         MCEditFile( MCEntryPath( ::ActivePanel(), aEntry ) )
      endif
   elseif aEntry != nil
      MCMsgBox( "Edit", "Cannot edit a directory." )
   endif
   ::ActivePanel():Rescan()
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

// Use internal view/edit OFF: hand the file to the configured external
// program in the same terminal (mc exec + refresh). less/vi set their own
// termios and restore on exit, so the app's raw mode survives the handoff.
// mc edit_cmd_new (src/filemanager/cmd.c:710): Shift-F4 edits a NEW file.
// editor_ask_filename_before_edit (setup.c:108, default FALSE) asks the
// file name first; Cancel returns to the panels, empty opens an unnamed
// edit (the demo editor needs a path: it opens "noname" in the panel).
METHOD FileEditNew() CLASS MCApp

   local oPanel := ::ActivePanel(), cName := "", cFull

   if ::lAskNewFile
      cName := ::DlgInput( "Edit file", "Enter file name:", "", 60 )
      if cName == nil
         return nil
      endif
      cName := AllTrim( cName )
   endif
   if Empty( cName )
      cName := "noname"
   endif
   cFull := MCAbsPath( oPanel:cPath, cName )
   if MCVfsKind( cFull ) != "local"
      MCMsgBox( "Edit", "Editing VFS entries is not supported yet (read-only VFS)." )
      return nil
   endif
   if ! ::lInternalEdit
      ::RunExternal( ::cExternalEdit, cFull )
   else
      MCEditFile( cFull )
   endif
   oPanel:Rescan()
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD RunExternal( cCmd, cFull ) CLASS MCApp

   DispEnd()
   hb_ProcessRun( cCmd + " " + ShellQuote( cFull ) )
   DispBegin()
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD FileCopy() CLASS MCApp

   local oSrc := ::ActivePanel(), oDst := ::OtherPanel()
   local aMarked := oSrc:MarkedEntries(), aTargets, aEntry
   local cDest, cAction := "ok", lAll := .F., nCopied := 0, nSkipped := 0

   if oDst:cMode != "listing"
      MCMsgBox( "Copy", "The other panel must be in file listing mode." )
      return nil
   endif
   if Empty( aMarked )
      aEntry := oSrc:Current()
      if aEntry == nil .or. aEntry[ P_NAME ] == "/.."
         MCMsgBox( "Copy", "Nothing to copy." )
         return nil
      endif
      aMarked := { aEntry }
   endif

   aTargets := AEval( aMarked, { | a | a[ P_NAME ] },,, .T. )
   cDest := hb_DirSepAdd( oDst:cPath )
   do while .T.
      cDest := ::DlgCopy( Len( aMarked ), cDest, @cAction )
      if cDest == nil
         return nil
      endif
      cDest := MCAbsPath( oDst:cPath, cDest )
      if cAction != "bg"
         exit
      endif
      if ::FileCopyBg( oSrc, aMarked, cDest )
         return nil
      endif
      // Refused (nothing to copy left the user informed): reopen the dialog
      // so OK can run the same copy in the foreground.
   enddo
   if Len( aMarked ) > 1 .and. ! hb_DirExists( cDest )
      hb_DirCreate( cDest )
   endif

   for each aEntry in aMarked
      if ::lVerboseOp
         MCVerboseLog( "copy " + MCEntryPath( oSrc, aEntry ) + " -> " + ;
                       DestFor( cDest, aEntry, Len( aMarked ) ) )
      endif
      if CopyItem( MCEntryPath( oSrc, aEntry ), ;
                   DestFor( cDest, aEntry, Len( aMarked ) ), ;
                   ::lConfirmOverwrite, @lAll, Self )
         nCopied++
      else
         nSkipped++
      endif
   next

   ::Rescan()
   MCMsgBox( "Copy", hb_ntos( nCopied ) + " item(s) copied" + ;
             If( nSkipped > 0, ", " + hb_ntos( nSkipped ) + " skipped", "" ) + ;
             If( ::lVerboseOp, ":" + Chr( 10 ) + MCListNames( aMarked, 5 ), "." ) )

return nil

//-----------------------------------------------------------------------------------------//

static function DestFor( cDest, aEntry, nCount )

   if nCount == 1 .and. ! hb_DirExists( cDest )
      return cDest   // rename-while-copy single file
   endif

return hb_FNameMerge( cDest, hb_FNameNameExt( aEntry[ P_NAME ] ) )

//-----------------------------------------------------------------------------------------//

// Copy destination dialog with the same layout as GNU mc: destination input
// plus [ OK ] [ Background ] [ Cancel ]. Returns the typed destination, or
// nil on Cancel/Esc; cAction comes back "ok" or "bg".
METHOD DlgCopy( nCount, cDefault, cAction, cVerb ) CLASS MCApp

   local oDlg, GetList := {}, lDummy, lOk := .F., lBg := .F.
   local cValue := PadR( hb_defaultValue( cDefault, "" ), 55 )

   DEFAULT cVerb := "Copy"
   oDlg = HBWindow():Dialog( cVerb, 66, 8, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   oDlg:Say( 2, 3, cVerb + " " + hb_ntos( nCount ) + " item(s) to:" )
   @ oDlg:nTop + 3, oDlg:nLeft + 3 GET cValue COLOR "W/B,W+/B,W+/W,GR+/W"

   @ oDlg:nBottom - 2, oDlg:nLeft + 5 GET lDummy PUSHBUTTON CAPTION "  &OK  " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" GUISEND cargo := .T. STATE { || lOk := .T., oDlg:End() }
   @ oDlg:nBottom - 2, oDlg:nLeft + 21 GET lDummy PUSHBUTTON CAPTION " &Background " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" STATE { || lBg := .T., oDlg:End() }
   @ oDlg:nBottom - 2, oDlg:nRight - 12 GET lDummy PUSHBUTTON CAPTION " &Cancel " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" STATE { || oDlg:End() }

   // Esc = Cancel inside dialogs: enable the READ exit key just for the
   // dialog (app keeps _SET_ESCAPE OFF so Esc never kills the main loop);
   // an Esc-terminated READ leaves lOk .F., so previous config is preserved
   MCDlgEscArm( oDlg, ::lSinglePress )
   SetKey( K_ENTER, { || MCDlgEnter( GetList ) } )
   oDlg:Activate( GetList )
   SetKey( K_ENTER, NIL )
   SetKey( K_ESC, NIL )
   Set( _SET_ESCAPE, .F. )
   ::Repaint()

   if lOk .or. lBg
      cAction := If( lBg, "bg", "ok" )
      return AllTrim( cValue )
   endif

return nil

//-----------------------------------------------------------------------------------------//

// Queue a copy in the background. The tree is flattened up front so the
// jobs dialog can show real progress; symlinks and unsafe source/destination
// pairs are skipped with the same rules as the foreground copy. One up-front
// overwrite decision covers the whole queue, like the foreground "all" flow.
METHOD FileCopyBg( oSrc, aMarked, cDest ) CLASS MCApp

   local aFiles := {}, aSkipped := {}, aEntry, aItem, aExist := {}, aNew

   if MCVfsKind( oSrc:cPath ) != "local" .or. MCVfsKind( cDest ) != "local"
      MCMsgBox( "Copy", "Background copy is only available for local files." + Chr( 10 ) + ;
                "Use OK to run this copy in the foreground." )
      return .F.
   endif

   for each aEntry in aMarked
      MCGather( MCEntryPath( oSrc, aEntry ), DestFor( cDest, aEntry, Len( aMarked ) ), aFiles, aSkipped )
   next

   if ::lConfirmOverwrite
      for each aItem in aFiles
         if aItem[ 1 ] == "file" .and. hb_FileExists( aItem[ 3 ] )
            AAdd( aExist, aItem )
         endif
      next
      if ! Empty( aExist ) .and. ! ::DlgConfirm( "Overwrite", ;
            hb_ntos( Len( aExist ) ) + " destination file(s) exist." + Chr( 10 ) + ;
            "Overwrite them?", "&Overwrite", ::lSafeOverwrite )
         for each aItem in aExist
            AAdd( aSkipped, aItem[ 3 ] )
         next
         aNew := {}
         for each aItem in aFiles
            if AScan( aExist, { | e | e == aItem } ) == 0
               AAdd( aNew, aItem )
            endif
         next
         aFiles := aNew
      endif
   endif

   if Empty( aFiles )
      MCMsgBox( "Copy", "Nothing to copy." )
      return .F.
   endif
   if ! Empty( aSkipped )
      MCMsgBox( "Copy", hb_ntos( Len( aSkipped ) ) + " item(s) skipped (unsafe, unsupported or kept)." )
   endif
   MCJobsAdd( aFiles, hb_ntos( Len( aMarked ) ) + " item(s) -> " + cDest,, ::lPreallocate, ::lCowClone )

return .T.

//-----------------------------------------------------------------------------------------//

// Background move: same queue with the move flag. The queue is
// non-interactive, so entries whose destination exists are still skipped
// up front (foreground MoveItem asks and overwrites instead); VFS refused,
// symlinks skipped by MCGather.
METHOD FileMoveBg( oSrc, aMarked, cDest ) CLASS MCApp

   local aFiles := {}, aSkipped := {}, aEntry, aItem, aExist := {}, aNew

   if MCVfsKind( oSrc:cPath ) != "local" .or. MCVfsKind( cDest ) != "local"
      MCMsgBox( "Rename/Move", "Background move is only available for local files." + Chr( 10 ) + ;
                "Use OK to run this move in the foreground." )
      return .F.
   endif

   for each aEntry in aMarked
      MCGather( MCEntryPath( oSrc, aEntry ), DestFor( cDest, aEntry, Len( aMarked ) ), aFiles, aSkipped )
   next

   // Move never overwrites: drop entries whose destination already exists.
   for each aItem in aFiles
      if aItem[ 1 ] == "file" .and. ;
         ( hb_FileExists( aItem[ 3 ] ) .or. ! Empty( hb_FLinkRead( aItem[ 3 ] ) ) )
         AAdd( aExist, aItem )
      endif
   next
   if ! Empty( aExist )
      for each aItem in aExist
         AAdd( aSkipped, aItem[ 3 ] )
      next
      aNew := {}
      for each aItem in aFiles
         if AScan( aExist, { | e | e == aItem } ) == 0
            AAdd( aNew, aItem )
         endif
      next
      aFiles := aNew
   endif

   if Empty( aFiles )
      MCMsgBox( "Rename/Move", "Nothing to move." )
      return .F.
   endif
   if ! Empty( aSkipped )
      MCMsgBox( "Rename/Move", hb_ntos( Len( aSkipped ) ) + ;
                " item(s) skipped (unsafe, unsupported or destination exists)." )
   endif
   MCJobsAdd( aFiles, "move " + hb_ntos( Len( aMarked ) ) + " item(s) -> " + cDest, .T., ::lPreallocate, ::lCowClone )

return .T.

//-----------------------------------------------------------------------------------------//

// Recursive flatten for the background queue; never prompts.
static function MCGather( cSrc, cDst, aFiles, aSkipped )

   local cFrom := MCRealPath( cSrc ), cTo := MCRealPath( cDst ), aChild, cStat, aStat

   if Empty( cFrom ) .or. Empty( cTo ) .or. cFrom == cTo .or. ;
      ( hb_DirExists( cSrc ) .and. Left( cTo, Len( hb_DirSepAdd( cFrom ) ) ) == hb_DirSepAdd( cFrom ) ) .or. ;
      MCSameFile( cSrc, cDst )
      AAdd( aSkipped, cSrc )
      return nil
   endif
   if ! Empty( hb_FLinkRead( cSrc ) ) .or. ! Empty( hb_FLinkRead( cDst ) )
      AAdd( aSkipped, cSrc )
      return nil
   endif
   if hb_DirExists( cSrc )
      AAdd( aFiles, { "mkdir", cSrc, cDst, 0 } )
      for each aChild in Directory( hb_DirSepAdd( cSrc ) + "*", "DHS" )
         if !( aChild[ F_NAME ] == "." ) .and. !( aChild[ F_NAME ] == ".." )
            MCGather( hb_FNameMerge( cSrc, aChild[ F_NAME ] ), ;
                      hb_FNameMerge( cDst, aChild[ F_NAME ] ), aFiles, aSkipped )
         endif
      next
      // Snapshot perms/mtime NOW: a move empties the source dirs before the
      // dirmeta step runs, which would mutate the mtimes --reference reads.
      cStat := ""
      hb_ProcessRun( MCShWrap( "stat -c '%Y %a' -- " + ShellQuote( cSrc ) + " 2>/dev/null" ),, @cStat )
      aStat := hb_ATokens( StrTran( cStat, hb_eol(), " " ) )
      if Len( aStat ) >= 2
         AAdd( aFiles, { "dirmeta", cSrc, cDst, 0, Val( aStat[ 1 ] ), aStat[ 2 ] } )
      else
         AAdd( aFiles, { "dirmeta", cSrc, cDst, 0 } )
      endif
      return nil
   endif
   AAdd( aFiles, { "file", cSrc, cDst, hb_FSize( cSrc ) } )

return nil

//-----------------------------------------------------------------------------------------//

// Command > Background jobs: live list of the copy queue. Hand-rolled loop
// (no READ) so progress keeps moving while the dialog is open: each idle
// tick advances the queue one chunk and redraws.
METHOD BgJobs() CLASS MCApp

   local oDlg, nSel := 1, lEnd := .F., nKey, n, j, aJobs
   local nT, nL, nPct, nFill, cState, cLine, cKey
   // mc filegui.c:915/931: with classic progressbar OFF and the RIGHT panel
   // active, the gauge grows right-to-left
   local lRTL := ! ::lClassicProgressbar .and. ::ActivePanel() == ::oPanel2

   oDlg = HBWindow():Dialog( "Background jobs", 64, 15, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   nT := oDlg:nTop
   nL := oDlg:nLeft
   oDlg:Say( oDlg:nBottom - oDlg:nTop - 1, 3, "C: cancel  Enter: full errors  Esc: close" )

   while ! lEnd
      MCJobsStep()

      cErr := ""
      aJobs := MCJobsList()
      nSel := Min( nSel, Max( Len( aJobs ), 1 ) )
      hb_Scroll( nT + 1, nL + 1, nT + 9, nL + 62,,, "N/W" )
      if Empty( aJobs )
         hb_DispOutAt( nT + 5, nL + 24, "No background jobs", "N/W" )
      else
         for n := 1 to Min( Len( aJobs ), 9 )
            j := aJobs[ n ]
            cState := j[ "state" ]
            if j[ "total" ] > 0
               nPct := Int( j[ "done" ] * 100 / j[ "total" ] )
            else
               nPct := If( cState == "done", 100, 0 )
            endif
            nFill := Int( nPct / 10 )
            cLine := hb_UPadR( hb_UTF8SubStr( j[ "desc" ], 1, 25 ), 25 ) + " " + ;
                     hb_UPadR( cState, 9 ) + " [" + ;
                     If( lRTL, Replicate( "-", 10 - nFill ) + Replicate( "#", nFill ), ;
                               Replicate( "#", nFill ) + Replicate( "-", 10 - nFill ) ) + "] " + ;
                     hb_UPadR( hb_ntos( nPct ) + "%", 4 ) + ;
                     If( ! Empty( j[ "err" ] ), " !", "" )
            hb_DispOutAt( nT + 1 + n, nL + 2, cLine, If( n == nSel, "W+/G", "N/W" ) )
         next
         // Per-entry problems for the selected job, in full (3 lines): an
         // "error" job here is never a "done" one.
         j := aJobs[ Min( nSel, Len( aJobs ) ) ]
         // First 180 chars inline; a "..." tail marks that Enter shows all.
         cErr := j[ "err" ]
         if hb_UTF8Len( cErr ) > 180
            cErr := hb_UTF8SubStr( cErr, 1, 177 ) + "..."
         endif
         for n := 0 to 2
            hb_DispOutAt( nT + 10 + n, nL + 2, hb_UPadR( hb_UTF8SubStr( cErr, n * 60 + 1, 60 ), 60 ), ;
               If( Empty( cErr ), "N/W", "W+/R" ) )
         next
      endif

      // hb_keyStd(): with HB_INKEY_EXT, printable keys arrive as extended
      // codes (99 becomes 11240735); normalize like the main loop does.
      nKey := hb_keyStd( InKey( 0.2, HB_INKEY_ALL + HB_INKEY_EXT ) )
      do case
         case nKey == 0
            loop
         case nKey == K_ESC
            lEnd := .T.
         case nKey == K_ENTER
            if ! Empty( aJobs )
               j := aJobs[ Min( nSel, Len( aJobs ) ) ]
               if ! Empty( j[ "err" ] )
                  // Suspend the dialog's idle mouse task: hbwindow's idle
                  // Refresh() would otherwise repaint the dialog frame over
                  // the full-screen viewer. Re-registered on return.
                  if oDlg:nIdle != nil
                     hb_IdleDel( oDlg:nIdle )
                     oDlg:nIdle := nil
                  endif
                  MCViewerText( "Problems in: " + j[ "desc" ], MCJobsErrText( j ) )
                  oDlg:nIdle := hb_IdleAdd( { || oDlg:MouseEvent( MRow(), MCol() ) } )
               endif
            endif
         case nKey == K_UP
            nSel := Max( 1, nSel - 1 )
         case nKey == K_DOWN
            nSel := Min( Max( Len( aJobs ), 1 ), nSel + 1 )
         case nKey == K_LBUTTONDOWN
            if MRow() == nT .and. MCol() == nL + 2
               lEnd := .T.   // window close button
            endif
         otherwise
            cKey := If( nKey >= 32 .and. nKey < 256, Upper( Chr( nKey ) ), "" )
            if cKey == "C" .and. ! Empty( aJobs )
               MCJobsCancel( nSel )
            endif
      endcase
   enddo

   oDlg:Hide()
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

function CopyItem( cSrc, cDst, lConfirm, lAll, oApp )

   local lOk := .T., lCreated := .F., aChild
   local cFrom, cTo

   if MCVfsKind( cSrc ) != "local" .or. MCVfsKind( cDst ) != "local"
      return MCVfsCopy( cSrc, cDst, lConfirm, @lAll, oApp )
   endif
   cFrom := MCRealPath( cSrc )
   cTo := MCRealPath( cDst )

   // Never truncate the source or recursively copy a directory into itself.
   if Empty( cFrom ) .or. Empty( cTo ) .or. cFrom == cTo .or. ;
      ( hb_DirExists( cSrc ) .and. Left( cTo, Len( hb_DirSepAdd( cFrom ) ) ) == hb_DirSepAdd( cFrom ) ) .or. ;
      MCSameFile( cSrc, cDst )
      MCMsgBox( "Copy", "Unsafe source/destination combination. Copy cancelled." )
      return .F.
   endif
   // Do not follow source or destination links, including links to directories.
   if ! Empty( hb_FLinkRead( cSrc ) ) .or. ! Empty( hb_FLinkRead( cDst ) )
      MCMsgBox( "Copy", "Copying symbolic links is not supported yet. Nothing changed." )
      return .F.
   endif
   if hb_DirExists( cSrc )
      if ! hb_DirExists( cDst )
         if hb_DirCreate( cDst ) != 0
            MCMsgBox( "Copy", "Cannot create directory:" + Chr( 10 ) + cDst )
            return .F.
         endif
         lCreated := .T.
      endif
      for each aChild in Directory( hb_DirSepAdd( cSrc ) + "*", "DHS" )
         if !( aChild[ F_NAME ] == "." ) .and. !( aChild[ F_NAME ] == ".." )   // exact: != is a prefix compare with SET EXACT off
            if ! CopyItem( hb_FNameMerge( cSrc, aChild[ F_NAME ] ), ;
                           hb_FNameMerge( cDst, aChild[ F_NAME ] ), lConfirm, @lAll, oApp )
               lOk := .F.
            endif
         endif
      next
      if ! lOk
         // Roll back a directory this operation itself created, so a failed
         // copy does not leave a partial tree at the destination. The cleanup
         // runs before the metadata below is applied, while the new tree is
         // still writable; a pre-existing destination is never touched.
         if lCreated .and. ! DeleteTree( cDst, .T. )
            MCMsgBox( "Copy", "The failed copy could not be fully removed:" + Chr( 10 ) + cDst )
         endif
      elseif lCreated
         // Keep the source directory's permissions and mtime. Applied after
         // the children are in place so a read-only source dir cannot block
         // its own copy.
         hb_ProcessRun( MCShWrap( "chmod --reference=" + ShellQuote( cSrc ) + " " + ShellQuote( cDst ) ),, )
         hb_ProcessRun( MCShWrap( "touch --reference=" + ShellQuote( cSrc ) + " " + ShellQuote( cDst ) ),, )
      endif
      return lOk
   endif
   if hb_FileExists( cDst ) .and. lConfirm .and. ! lAll
      if ! oApp:DlgConfirm( "Overwrite", "File exists:" + Chr( 10 ) + cDst + Chr( 10 ) + "Overwrite?", "&Overwrite", oApp:lSafeOverwrite )
         return .F.
      endif
   endif
return FCopyText( cSrc, cDst, oApp:lPreallocate, oApp:lCowClone, oApp )

static function MCRealPath( cPath )
   local cOut := ""
   if hb_ProcessRun( MCShWrap( "readlink -m -- " + ShellQuote( cPath ) ),, @cOut ) != 0
      return ""
   endif
return AllTrim( StrTran( cOut, Chr( 10 ), "" ) )

static function MCSameFile( cA, cB )
   local cOne := "", cTwo := ""
   hb_ProcessRun( MCShWrap( "stat -Lc '%d:%i' -- " + ShellQuote( cA ) + " 2>/dev/null" ),, @cOne )
   hb_ProcessRun( MCShWrap( "stat -Lc '%d:%i' -- " + ShellQuote( cB ) + " 2>/dev/null" ),, @cTwo )
return ! Empty( cOne ) .and. cOne == cTwo

//-----------------------------------------------------------------------------------------//

function FCopyText( cSrc, cDst, lPrealloc, lCowClone, oApp )

   local nSrc, nDst, cBuf := Space( 65536 ), nRead, lOk, cTmp := ""
   local cBak := "", nBak, lRestored, nSize, nAl := 0, nPick := 0

   lPrealloc := hb_defaultValue( lPrealloc, .F. )
   lCowClone := hb_defaultValue( lCowClone, .F. )

   // mc file_cloning (lib/global.c:110, default TRUE): whole-file COW clone
   // first, only when the destination does not exist (mc file.c:2606); any
   // failure falls back to the normal copy, like mc.
   if lCowClone .and. ! hb_FileExists( cDst )
      if MC_CloneFile( cSrc, cDst ) == 0
         return .T.
      endif
   endif

   if hb_DirExists( cDst )
      MCMsgBox( "Copy", "Destination is a directory:" + Chr( 10 ) + cDst )
      return .F.
   endif

   nSrc := FOpen( cSrc, 0 )
   if nSrc < 0
      MCMsgBox( "Copy", "Cannot open:" + Chr( 10 ) + cSrc )
      return .F.
   endif
   // Write to a temp file in the destination directory first: an existing
   // destination is only replaced after a complete, successful copy, so a
   // failed overwrite never destroys the previous file.
   nDst := hb_FTempCreate( hb_DirSepAdd( hb_FNameDir( cDst ) ), "hbmc",, @cTmp )
   if nDst < 0
      FClose( nSrc )
      MCMsgBox( "Copy", "Cannot create:" + Chr( 10 ) + cDst )
      return .F.
   endif
   // mc preallocate_space (lib/global.c:109, default FALSE; file.c:2701):
   // reserve the destination space up front; on failure copy anyway, like
   // mc's fallback after the error prompt.
   if lPrealloc
      nSize := FSeek( nSrc, 0, FS_END )
      FSeek( nSrc, 0, FS_SET )
      // mc file.c:2701-2713: on preallocate failure mc asks the user;
      // retry re-attempts the reservation, copy-anyway continues without
      // it (mc's "try copy anyway"), abort skips this file.
      while nSize > 0 .and. ( nAl := MC_FAllocate( nDst, 0, nSize ) ) != 0
         nPick := oApp:DlgList( "Cannot preallocate space (errno " + hb_ntos( nAl ) + ")", ;
                                { "&Retry", "&Copy anyway", "&Abort file" }, 2 )
         if nPick == 1
            loop
         elseif nPick == 2
            exit
         else
            FClose( nSrc )
            FClose( nDst )
            FErase( cTmp )
            return .F.
         endif
      enddo
   endif
   while ( nRead := FRead( nSrc, @cBuf, 65536 ) ) > 0
      if FWrite( nDst, Left( cBuf, nRead ) ) != nRead
         exit
      endif
   end
   lOk := ( nRead == 0 .and. FError() == 0 )   // FRead() returns 0 both at EOF and on error; FError() tells them apart
   FClose( nSrc )
   FClose( nDst )
   if ! lOk
      FErase( cTmp )
      MCMsgBox( "Copy", "Copy failed:" + Chr( 10 ) + cSrc + Chr( 10 ) + ;
                "The previous destination was left unchanged." )
      return .F.
   endif
   // hb_FTempCreate() uses 0600; give the copy the source file's permissions
   hb_ProcessRun( MCShWrap( "chmod --reference=" + ShellQuote( cSrc ) + " " + ShellQuote( cTmp ) ),, )
   if FRename( cTmp, cDst ) != 0
      // rename(2) replaces an existing destination atomically on POSIX, but
      // not everywhere (Windows rename() refuses an existing target). Never
      // erase the previous destination to retry: move it aside, retry, and
      // restore it if the retry fails, so a failed overwrite cannot lose it.
      if File( cDst )
         nBak := hb_FTempCreate( hb_DirSepAdd( hb_FNameDir( cDst ) ), "hbmc",, @cBak )
         if nBak < 0
            FErase( cTmp )
            MCMsgBox( "Copy", "Cannot replace destination:" + Chr( 10 ) + cDst + Chr( 10 ) + ;
                      "The previous destination was left unchanged." )
            return .F.
         endif
         FClose( nBak )
         FErase( cBak )  // keep the unique name, free the slot
         if FRename( cDst, cBak ) != 0
            FErase( cTmp )
            MCMsgBox( "Copy", "Cannot replace destination:" + Chr( 10 ) + cDst + Chr( 10 ) + ;
                      "The previous destination was left unchanged." )
            return .F.
         endif
         if FRename( cTmp, cDst ) != 0
            lRestored := ( FRename( cBak, cDst ) == 0 )
            FErase( cTmp )
            if lRestored
               MCMsgBox( "Copy", "Cannot replace destination:" + Chr( 10 ) + cDst + Chr( 10 ) + ;
                         "The previous destination was left unchanged." )
            else
               MCMsgBox( "Copy", "Cannot replace destination:" + Chr( 10 ) + cDst + Chr( 10 ) + ;
                         "Its previous content was preserved as:" + Chr( 10 ) + cBak )
            endif
            return .F.
         endif
         FErase( cBak )  // replace succeeded: drop the moved-aside original
      else
         FErase( cTmp )
         MCMsgBox( "Copy", "Cannot create:" + Chr( 10 ) + cDst )
         return .F.
      endif
   endif
   // Keep the source file's modification time on the destination.
   hb_ProcessRun( MCShWrap( "touch --reference=" + ShellQuote( cSrc ) + " " + ShellQuote( cDst ) ),, )
return .T.


//-----------------------------------------------------------------------------------------//

METHOD FileMove() CLASS MCApp

   local oSrc := ::ActivePanel(), oDst := ::OtherPanel()
   local aMarked := oSrc:MarkedEntries(), aEntry
   local cDest, cAction := "ok", nMoved := 0, nFailed := 0

   if Empty( aMarked )
      aEntry := oSrc:Current()
      if aEntry == nil .or. aEntry[ P_NAME ] == "/.."
         MCMsgBox( "Rename/Move", "Nothing to move." )
         return nil
      endif
      aMarked := { aEntry }
   endif

   cDest := If( Len( aMarked ) == 1, ;
                hb_FNameMerge( oDst:cPath, aMarked[ 1 ][ P_NAME ] ), ;
                hb_DirSepAdd( oDst:cPath ) )
   do while .T.
      cDest := ::DlgCopy( Len( aMarked ), cDest, @cAction, "Move" )
      if cDest == nil
         return nil
      endif
      cDest := MCAbsPath( oDst:cPath, cDest )
      if cAction != "bg"
         exit
      endif
      if ::FileMoveBg( oSrc, aMarked, cDest )
         return nil
      endif
      // Refused: reopen the dialog so OK can run the move in the foreground.
   enddo

   for each aEntry in aMarked
      if ::lVerboseOp
         MCVerboseLog( "move " + MCEntryPath( oSrc, aEntry ) + " -> " + ;
                       DestFor( cDest, aEntry, Len( aMarked ) ) )
      endif
      if MoveItem( MCEntryPath( oSrc, aEntry ), ;
                   DestFor( cDest, aEntry, Len( aMarked ) ), Self )
         nMoved++
      else
         nFailed++
      endif
   next

   ::Rescan()
   if nFailed > 0
      MCMsgBox( "Rename/Move", hb_ntos( nMoved ) + " moved, " + hb_ntos( nFailed ) + " failed." )
   endif

return nil

//-----------------------------------------------------------------------------------------//

static function MoveItem( cSrc, cDst, oApp )
   local lAll := .F., cTarget
   if MCVfsKind( cSrc ) != "local" .or. MCVfsKind( cDst ) != "local"
      MCMsgBox( "Rename/Move", "Moving to or from a VFS is not supported yet (read-only VFS)." + Chr( 10 ) + ;
                "Use Copy instead. Nothing changed." )
      return .F.
   endif
   if MCSameFile( cSrc, cDst )
      MCMsgBox( "Rename/Move", "Source and destination are the same file." )
      return .F.
   endif
   if hb_DirExists( cDst ) .and. Empty( hb_FLinkRead( cDst ) )
      // A real directory is never replaced; a symlink (even to a dir) is.
      MCMsgBox( "Rename/Move", "Destination is a directory:" + Chr( 10 ) + cDst )
      return .F.
   endif
   if hb_FileExists( cDst ) .or. ! Empty( hb_FLinkRead( cDst ) )
      // mc overwrite semantics: confirm when confirmations are on, then
      // replace - rename(2) swaps a file or symlink destination atomically.
      if oApp:lConfirmOverwrite .and. ;
         ! oApp:DlgConfirm( "Overwrite", "File exists:" + Chr( 10 ) + cDst + Chr( 10 ) + "Overwrite?", "&Overwrite", oApp:lSafeOverwrite )
         return .F.
      endif
      lAll := .T.  // confirmation granted (or off): CopyItem must not re-ask
   endif
   if FRename( cSrc, cDst ) == 0
      return .T.
   endif
   // Cross-filesystem fallback: copy first and remove the source only after
   // a complete copy, so a partial failure never deletes data.
   if ! Empty( hb_FLinkRead( cSrc ) )
      // Recreate the symlink at the destination, then remove the original.
      // A relative target only names the same file next to the SOURCE;
      // resolve it to an absolute path so the moved link keeps its meaning.
      cTarget := hb_FLinkRead( cSrc )
      if Left( cTarget, 1 ) != "/"
         cTarget := hb_PathNormalize( hb_DirSepAdd( hb_FNameDir( cSrc ) ) + cTarget )
      endif
      // linkat(2) cannot replace an existing destination; the overwrite
      // was already confirmed above, so remove it before relinking.
      if hb_FileExists( cDst ) .or. ! Empty( hb_FLinkRead( cDst ) )
         if FErase( cDst ) != 0
            MCMsgBox( "Rename/Move", "Cannot replace:" + Chr( 10 ) + cDst )
            return .F.
         endif
      endif
      if hb_FLinkSym( cTarget, cDst ) == 0
         return FErase( cSrc ) == 0
      endif
      MCMsgBox( "Rename/Move", "Cannot create link:" + Chr( 10 ) + cDst )
      return .F.
   endif
   if ! CopyItem( cSrc, cDst, .T., @lAll, oApp )
      return .F.   // copy failed: source untouched; CopyItem removes a partial
                   // destination it created itself
   endif
   if hb_DirExists( cSrc )
      return DeleteTree( cSrc )
   endif
return FErase( cSrc ) == 0

//-----------------------------------------------------------------------------------------//

function DeleteTree( cPath, lPrep )

   local aDir, lOk := .T.

   if ! Empty( hb_FLinkRead( cPath ) )
      return FErase( cPath ) == 0
   endif
   if lPrep == NIL
      lPrep := .F.
   endif
   if lPrep
      // only for trees the app itself created (extract wraps, rollback
      // targets, session temp): trees from archives or read-only sources
      // can carry dirs without owner rwx, which would make the recursion
      // below silently stop. chmod -R does not traverse symlinks (verified:
      // a link in the tree pointing outside is not followed) and cPath
      // itself is never a symlink here (handled above). User-owned trees
      // (F8 delete) never get their permissions touched.
      hb_ProcessRun( MCShWrap( "chmod -R u+rwX -- " + ShellQuote( cPath ) + " 2>/dev/null" ),, )
   endif
   for each aDir in Directory( hb_DirSepAdd( cPath ) + "*", "DHS" )
      if aDir[ F_NAME ] == "." .or. aDir[ F_NAME ] == ".."
         loop
      endif
      if ! Empty( hb_FLinkRead( hb_FNameMerge( cPath, aDir[ F_NAME ] ) ) )
         if FErase( hb_FNameMerge( cPath, aDir[ F_NAME ] ) ) != 0
            lOk := .F.
         endif
      elseif hb_DirExists( hb_FNameMerge( cPath, aDir[ F_NAME ] ) )
         if ! DeleteTree( hb_FNameMerge( cPath, aDir[ F_NAME ] ), .F. )
            lOk := .F.
         endif
      else
         if FErase( hb_FNameMerge( cPath, aDir[ F_NAME ] ) ) != 0
            lOk := .F.
         endif
      endif
   next

return lOk .and. hb_DirDelete( cPath ) == 0

//-----------------------------------------------------------------------------------------//

METHOD FileMkdir() CLASS MCApp

   local cName, cErr
   local cKind := MCVfsKind( ::ActivePanel():cPath )

   // refuse up front on providers that cannot take a new member
   if cKind != "local" .and. cKind != "uzip" .and. cKind != "utar"
      MCMsgBox( "Make Directory", "Mkdir is not supported on this provider (read-only VFS)." )
      return nil
   endif
   cName := ::DlgInput( "Make Directory", "New directory:", ;
      If( ::lMkdirAutoname .and. ::ActivePanel():Current() != nil, ;
          ::ActivePanel():Current()[ P_NAME ], "" ), 45 )

   if cName != nil .and. ! Empty( cName )
      cKind := MCVfsKind( ::ActivePanel():cPath )
      if cKind == "uzip" .or. cKind == "utar"
         if MCVfsArchiveMkdir( ::ActivePanel():cPath, cName )
            ::Rescan()
         else
            cErr := MCVfsTakeError()
            MCMsgBox( "Make Directory", "Cannot create member directory." + ;
                      If( Empty( cErr ), "", Chr( 10 ) + "Reason: " + cErr ) )
         endif
         return nil
      endif
      if cKind != "local"
         MCMsgBox( "Make Directory", "Mkdir is not supported on this provider (read-only VFS)." )
         return nil
      endif
      cName := MCAbsPath( ::ActivePanel():cPath, cName )
      if hb_DirCreate( cName ) != 0
         MCMsgBox( "Make Directory", "Cannot create:" + Chr( 10 ) + cName )
      endif
      ::Rescan()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD FileDelete() CLASS MCApp

   local oSrc := ::ActivePanel(), aMarked := oSrc:MarkedEntries(), aEntry
   local nDeleted := 0, nFailed := 0, cFull, aNames, cErr

   if MCVfsKind( oSrc:cPath ) == "uzip" .or. MCVfsKind( oSrc:cPath ) == "utar"
      if Empty( aMarked )
         aEntry := oSrc:Current()
         if aEntry == nil .or. aEntry[ P_NAME ] == "/.."
            MCMsgBox( "Delete", "Nothing to delete." )
            return nil
         endif
         aMarked := { aEntry }
      endif
      if ::lConfirmDelete
         if ! ::DlgConfirm( "Delete", "Delete " + hb_ntos( Len( aMarked ) ) + " member(s) from the archive?" + Chr( 10 ) + ;
                            aMarked[ 1 ][ P_NAME ] + If( Len( aMarked ) > 1, " ...", "" ), "&Delete", ::lSafeDelete )
            return nil
         endif
      endif
      aNames := {}
      for each aEntry in aMarked
         AAdd( aNames, aEntry[ P_NAME ] )
      next
      if MCVfsArchiveDelete( oSrc:cPath, aNames )
         ::Rescan()
      else
         cErr := MCVfsTakeError()
         MCMsgBox( "Delete", "Cannot update the archive." + ;
                   If( Empty( cErr ), "", Chr( 10 ) + "Reason: " + cErr ) )
      endif
      return nil
   endif
   if MCVfsKind( oSrc:cPath ) != "local"
      MCMsgBox( "Delete", "Deleting VFS entries is not supported yet (read-only VFS)." )
      return nil
   endif

   if Empty( aMarked )
      aEntry := oSrc:Current()
      if aEntry == nil .or. aEntry[ P_NAME ] == "/.."
         MCMsgBox( "Delete", "Nothing to delete." )
         return nil
      endif
      aMarked := { aEntry }
   endif

   if ::lConfirmDelete
      if ! ::DlgConfirm( "Delete", "Delete " + hb_ntos( Len( aMarked ) ) + " item(s)?" + Chr( 10 ) + ;
                         aMarked[ 1 ][ P_NAME ] + If( Len( aMarked ) > 1, " ...", "" ), "&Delete", ::lSafeDelete )
         return nil
      endif
   endif

   for each aEntry in aMarked
      cFull := MCEntryPath( oSrc, aEntry )
      if aEntry[ P_DIR ]
         if DeleteTree( cFull )
            nDeleted++
         else
            nFailed++
         endif
      else
         if FErase( cFull ) == 0
            nDeleted++
         else
            nFailed++
         endif
      endif
   next

   ::Rescan()
   if nFailed > 0
      MCMsgBox( "Delete", hb_ntos( nDeleted ) + " deleted, " + hb_ntos( nFailed ) + " failed." )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD SelectGroup( lSelect ) CLASS MCApp

   local oPanel := ::ActivePanel()
   local cMask := ::DlgInput( If( lSelect, "Select group", "Unselect group" ), ;
                              "File mask:", "*", 30 )
   local aEntry, n := 0

   if cMask == nil
      return nil
   endif
   for each aEntry in oPanel:aFiles
      if ! aEntry[ P_DIR ] .and. FilterMatch( aEntry[ P_NAME ], cMask, oPanel:lCaseSens, ::lShellPatterns )
         aEntry[ P_MARKED ] := lSelect
         n++
      endif
   next
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD InvertSelection() CLASS MCApp

   local aEntry

   for each aEntry in ::ActivePanel():aFiles
      if aEntry[ P_NAME ] != "/.."
         aEntry[ P_MARKED ] := ! aEntry[ P_MARKED ]
      endif
   next
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD FileChmod() CLASS MCApp

   local aEntry := ::ActivePanel():Current()
   local cFull, cMode := "", cOut := "", nRet, oDlg, GetList := {}, lDummy, lOk := .F.
   local aChk[ 9 ], aLabels := { "owner read", "owner write", "owner exec", ;
                                 "group read", "group write", "group exec", ;
                                 "other read", "other write", "other exec" }
   local n, nMode := 0, cCur := ""

   if aEntry == nil .or. aEntry[ P_NAME ] == "/.."
      return nil
   endif
   cFull := MCEntryPath( ::ActivePanel(), aEntry )
   hb_ProcessRun( MCShWrap( "stat -c %a " + ShellQuote( cFull ) ),, @cCur )
   nMode := Val( AllTrim( cCur ) )   // octal digits as decimal number, e.g. 644

   // expand octal digits into bit flags
   aChk[ 1 ] := hb_bitAnd( OctalDigit( nMode, 100 ), 4 ) != 0
   aChk[ 2 ] := hb_bitAnd( OctalDigit( nMode, 100 ), 2 ) != 0
   aChk[ 3 ] := hb_bitAnd( OctalDigit( nMode, 100 ), 1 ) != 0
   aChk[ 4 ] := hb_bitAnd( OctalDigit( nMode, 10 ), 4 ) != 0
   aChk[ 5 ] := hb_bitAnd( OctalDigit( nMode, 10 ), 2 ) != 0
   aChk[ 6 ] := hb_bitAnd( OctalDigit( nMode, 10 ), 1 ) != 0
   aChk[ 7 ] := hb_bitAnd( OctalDigit( nMode, 1 ), 4 ) != 0
   aChk[ 8 ] := hb_bitAnd( OctalDigit( nMode, 1 ), 2 ) != 0
   aChk[ 9 ] := hb_bitAnd( OctalDigit( nMode, 1 ), 1 ) != 0

   oDlg = HBWindow():Dialog( "Chmod " + aEntry[ P_NAME ], 46, 13, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }

   for n := 1 to 9
      @ oDlg:nTop + 1 + n, oDlg:nLeft + 4 GET aChk[ n ] ;
         CHECKBOX CAPTION aLabels[ n ] STYLE "[X ]" COLOR "N/W,N/BG,N/W,R/W"
      ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
      ATail( GetList ):Control:Display()
   next

   @ oDlg:nBottom - 2, oDlg:nLeft + 4 GET lDummy PUSHBUTTON CAPTION "  &Set  " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" GUISEND cargo := .T. STATE { || lOk := .T., oDlg:End() }
   @ oDlg:nBottom - 2, oDlg:nRight - 12 GET lDummy PUSHBUTTON CAPTION " &Cancel " ;
      COLOR "N/W,N/BG,N/BG,R/W" STYLE "[]" STATE { || oDlg:End() }

   // Esc = Cancel inside dialogs: enable the READ exit key just for the
   // dialog (app keeps _SET_ESCAPE OFF so Esc never kills the main loop);
   // an Esc-terminated READ leaves lOk .F., so previous config is preserved
   MCDlgEscArm( oDlg, ::lSinglePress )
   SetKey( K_ENTER, { || MCDlgEnter( GetList ) } )
   oDlg:Activate( GetList )
   SetKey( K_ENTER, NIL )
   SetKey( K_ESC, NIL )
   Set( _SET_ESCAPE, .F. )
   ::Repaint()

   if lOk
      cMode := hb_ntos( If( aChk[1],4,0 ) + If( aChk[2],2,0 ) + If( aChk[3],1,0 ) ) + ;
               hb_ntos( If( aChk[4],4,0 ) + If( aChk[5],2,0 ) + If( aChk[6],1,0 ) ) + ;
               hb_ntos( If( aChk[7],4,0 ) + If( aChk[8],2,0 ) + If( aChk[9],1,0 ) )
      nRet := hb_ProcessRun( MCShWrap( "chmod " + cMode + " " + ShellQuote( cFull ) + " 2>&1" ),, @cOut )
      if nRet != 0
         MCMsgBox( "Chmod", cOut )
      endif
      ::Rescan()
   endif

return nil

//-----------------------------------------------------------------------------------------//

static function OctalDigit( nMode, nPlace )

return Int( nMode / nPlace ) % 10

//-----------------------------------------------------------------------------------------//

METHOD FileLink() CLASS MCApp

   local aEntry := ::ActivePanel():Current()
   local cLink, cFull, cOut := "", nRet

   if aEntry == nil .or. aEntry[ P_NAME ] == "/.."
      return nil
   endif
   cFull := MCEntryPath( ::ActivePanel(), aEntry )
   cLink := ::DlgInput( "Link", "Hard link " + aEntry[ P_NAME ] + " to:", ;
                        hb_FNameMerge( ::OtherPanel():cPath, aEntry[ P_NAME ] ), 55 )
   if cLink != nil
      nRet := hb_ProcessRun( MCShWrap( "ln " + ShellQuote( cFull ) + " " + ;
                             ShellQuote( MCAbsPath( ::ActivePanel():cPath, cLink ) ) + " 2>&1" ),, @cOut )
      if nRet != 0
         MCMsgBox( "Link", cOut )
      endif
      ::Rescan()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD FileSymlink() CLASS MCApp

   local aEntry := ::ActivePanel():Current()
   local cLink, cFull, cOut := "", nRet

   if aEntry == nil .or. aEntry[ P_NAME ] == "/.."
      return nil
   endif
   cFull := MCEntryPath( ::ActivePanel(), aEntry )
   cLink := ::DlgInput( "Symlink", "Symbolic link name:", ;
                        hb_FNameMerge( ::OtherPanel():cPath, aEntry[ P_NAME ] ), 55 )
   if cLink != nil
      nRet := hb_ProcessRun( MCShWrap( "ln -s " + ShellQuote( cFull ) + " " + ;
                             ShellQuote( MCAbsPath( ::ActivePanel():cPath, cLink ) ) + " 2>&1" ),, @cOut )
      if nRet != 0
         MCMsgBox( "Symlink", cOut )
      endif
      ::Rescan()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD FileEditSymlink() CLASS MCApp

   local aEntry := ::ActivePanel():Current()
   local cFull, cTarget := "", cNew, cOut := "", nRet

   if aEntry == nil .or. aEntry[ P_NAME ] == "/.."
      return nil
   endif
   cFull := MCEntryPath( ::ActivePanel(), aEntry )
   hb_ProcessRun( MCShWrap( "readlink " + ShellQuote( cFull ) ),, @cTarget )
   cTarget := AllTrim( cTarget )
   if Empty( cTarget )
      MCMsgBox( "Edit symlink", "Not a symbolic link:" + Chr( 10 ) + cFull )
      return nil
   endif
   cNew := ::DlgInput( "Edit symlink", "New target for " + aEntry[ P_NAME ] + ":", cTarget, 55 )
   if cNew != nil .and. cNew != cTarget
      nRet := hb_ProcessRun( MCShWrap( "ln -sfn " + ShellQuote( cNew ) + " " + ShellQuote( cFull ) + " 2>&1" ),, @cOut )
      if nRet != 0
         MCMsgBox( "Edit symlink", cOut )
      endif
      ::Rescan()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD FileChown() CLASS MCApp

   local aEntry := ::ActivePanel():Current()
   local cOwner, cFull, cOut := "", nRet

   if aEntry == nil .or. aEntry[ P_NAME ] == "/.."
      return nil
   endif
   cFull := MCEntryPath( ::ActivePanel(), aEntry )
   cOwner := ::DlgInput( "Chown", "New owner[:group] for " + aEntry[ P_NAME ] + ":", hb_GetEnv( "USER" ), 40 )
   if cOwner != nil .and. ! Empty( cOwner )
      nRet := hb_ProcessRun( MCShWrap( "chown " + ShellQuote( cOwner ) + " " + ShellQuote( cFull ) + " 2>&1" ),, @cOut )
      if nRet != 0
         MCMsgBox( "Chown", cOut )
      endif
      ::Rescan()
   endif

return nil

/*
 * mctools.prg - Command menu actions, help, about, and configuration
 */


//-----------------------------------------------------------------------------------------//

// mc drop_menus=FALSE bar state: F9 lights the bar; Left/Right move the
// highlight without dropping any menu; Enter/Down drops the current one
// (mc menubar_activate with drop_menus off, filemanager.c:336/351).
METHOD MenuBarLight() CLASS MCApp

   ::lBarLit := .T.
   ::nBarItem := 1
   ::oMenu:aItems[ 1 ]:Display( ::oMenu:cClrHilite, ::oMenu:cClrHotFocus )

return nil

//-----------------------------------------------------------------------------------------//

METHOD MenuBarUnlight() CLASS MCApp

   if ::lBarLit
      ::lBarLit := .F.
      if ::nBarItem >= 1 .and. ::nBarItem <= Len( ::oMenu:aItems )
         ::oMenu:aItems[ ::nBarItem ]:Display( ::oMenu:cClrPopup, ::oMenu:cClrHotKey )
      endif
      ::nBarItem := 0
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD MenuBarMove( nDelta ) CLASS MCApp

   local n := ::nBarItem, nMax := Len( ::oMenu:aItems )

   if n < 1
      return nil
   endif
   ::oMenu:aItems[ n ]:Display( ::oMenu:cClrPopup, ::oMenu:cClrHotKey )
   n += nDelta
   if n < 1
      n := nMax
   elseif n > nMax
      n := 1
   endif
   do while hb_LeftEq( ::oMenu:aItems[ n ]:cPrompt, "-" )
      n += nDelta
      if n < 1
         n := nMax
      elseif n > nMax
         n := 1
      endif
   enddo
   ::nBarItem := n
   ::oMenu:aItems[ n ]:Display( ::oMenu:cClrHilite, ::oMenu:cClrHotFocus )

return nil

//-----------------------------------------------------------------------------------------//

METHOD UserMenu() CLASS MCApp

   local aItems := {}, aCmds := {}, cLine, cFile, n, cOut := "", cCmd, nRet
   local cLocal := hb_FNameMerge( ::ActivePanel():cPath, ".mc.menu" )
   local cHome := hb_DirSepAdd( hb_GetEnv( "HOME" ) ) + ".mc.menu"

   // format per line: key|label|command   (%f = current file)
   cFile := If( hb_FileExists( cLocal ), cLocal, If( hb_FileExists( cHome ), cHome, "" ) )
   if ! Empty( cFile )
      for each cLine in hb_aTokens( StrTran( MemoRead( cFile ), Chr( 13 ) ), Chr( 10 ) )
         cLine := AllTrim( cLine )
         if Empty( cLine ) .or. Left( cLine, 1 ) == "#"
            loop
         endif
         if hb_TokenCount( cLine, "|" ) >= 3
            AAdd( aItems, hb_TokenGet( cLine, 1, "|" ) + "  " + hb_TokenGet( cLine, 2, "|" ) )
            AAdd( aCmds, hb_TokenGet( cLine, 3, "|" ) )
         endif
      next
   else
      aItems := { "c  Compile current file with hbmk2", "g  git status", "l  ls -la" }
      aCmds  := { "hbmk2 %f 2>&1", "git status 2>&1", "ls -la" }
   endif

   n := ::DlgList( "User menu" + If( Empty( cFile ), " (built-in defaults)", "" ), aItems )
   if n > 0
      cCmd := aCmds[ n ]
      if At( "%f", cCmd ) > 0
         if ::ActivePanel():Current() == nil
            return nil
         endif
         cCmd := StrTran( cCmd, "%f", ShellQuote( hb_FNameMerge( ::ActivePanel():cPath, ;
                         ::ActivePanel():Current()[ P_NAME ] ) ) )
      endif
      nRet := hb_ProcessRun( MCShWrap( "cd " + ShellQuote( ::ActivePanel():cPath ) + " && " + cCmd + " 2>&1" ),, @cOut )
      ::cLastOutput := "$ " + cCmd + hb_eol() + cOut + ;
         If( nRet != 0, hb_eol() + "(exit code " + hb_ntos( nRet ) + ")", "" )
      ::ShowOutput( ::cLastOutput )
      ::Rescan()
   endif
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD DirectoryTreeDlg() CLASS MCApp

   local aTree := {}, aItems := {}, aEntry, n

   TreeScan( ::ActivePanel():cPath, 0, aTree )
   for each aEntry in aTree
      AAdd( aItems, Space( aEntry[ 2 ] * 2 ) + aEntry[ 1 ] )
   next

   n := ::DlgList( "Directory tree", aItems )
   if n > 0
      ::ActivePanel():GoDir( aTree[ n ][ 3 ] )
   endif
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD FindFile() CLASS MCApp

   local cMask := ::DlgInput( "Find file", "File mask:", "*", 30 )
   local cContent, aFound := {}, aItems := {}, cStart, n

   if cMask == nil
      return nil
   endif
   cContent := ::DlgInput( "Find file", "Containing text (empty = any):", "", 40 )
   if cContent == nil
      return nil
   endif
   cStart := ::ActivePanel():cPath

   FindScan( cStart, cMask, cContent, aFound, 0 )
   if Empty( aFound )
      MCMsgBox( "Find file", "No files found." )
      return nil
   endif
   AEval( aFound, { | c | AAdd( aItems, hb_UTF8SubStr( c, Max( 1, hb_ULen( c ) - 95 ) ) ) } )
   n := ::DlgList( "Find results (" + hb_ntos( Len( aFound ) ) + ")", aItems )
   if n > 0
      ::ActivePanel():GoDir( hb_FNameDir( aFound[ n ] ) )
      ::ActivePanel():SelectName( hb_FNameNameExt( aFound[ n ] ) )
   endif
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

static function FindScan( cPath, cMask, cContent, aFound, nLevel )

   local aDir, cFull

   if nLevel > 10 .or. Len( aFound ) > 500
      return nil
   endif
   for each aDir in Directory( hb_DirSepAdd( cPath ) + "*", "DHS" )
      if aDir[ 1 ] == "." .or. aDir[ 1 ] == ".." .or. Left( aDir[ 1 ], 1 ) == "."
         loop
      endif
      cFull := hb_FNameMerge( cPath, aDir[ 1 ] )
      if hb_DirExists( cFull )
         FindScan( cFull, cMask, cContent, aFound, nLevel + 1 )
      elseif hb_FileMatch( Lower( aDir[ 1 ] ), Lower( cMask ) )
         if Empty( cContent ) .or. Lower( cContent ) $ Lower( Left( MemoRead( cFull ), 200000 ) )
            AAdd( aFound, cFull )
         endif
      endif
   next

return nil

//-----------------------------------------------------------------------------------------//

METHOD CmdHistory() CLASS MCApp

   local n

   if Empty( ::aHistory )
      MCMsgBox( "Command history", "The command history is empty." )
      return nil
   endif
   n := ::DlgList( "Command history", AReverse2( AClone( ::aHistory ) ) )
   if n > 0
      ::oCmdLine:SetText( AReverse2( AClone( ::aHistory ) )[ n ] )
      ::cCmdLine := ::oCmdLine:cText
   endif
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

static function AReverse2( a )

   local n, aOut := {}

   for n := Len( a ) to 1 step -1
      AAdd( aOut, a[ n ] )
   next

return aOut

//-----------------------------------------------------------------------------------------//

METHOD Hotlist() CLASS MCApp

   local aItems := {}, aEntry, n

   for n := 1 to 10
      if ! Empty( ::aKeyBind ) .and. ::aKeyBind[ n ][ 1 ] != MCKeyDefaults()[ n ]
         cTxt += "learnkey" + hb_ntos( n ) + "=" + hb_ntos( ::aKeyBind[ n ][ 1 ] ) + hb_eol()
      endif
   next
   for each aEntry in ::aHotlist
      AAdd( aItems, aEntry[ 1 ] + "  (" + aEntry[ 2 ] + ")" )
   next
   AAdd( aItems, "+ Add current directory" )
   AAdd( aItems, "- Remove selected" )

   n := ::DlgList( "Directory hotlist", aItems )
   if n > 0 .and. n <= Len( ::aHotlist )
      ::ActivePanel():GoDir( ::aHotlist[ n ][ 2 ] )
   elseif n == Len( ::aHotlist ) + 1
      AAdd( ::aHotlist, { hb_FNameName( hb_DirSepDel( ::ActivePanel():cPath ) ), ::ActivePanel():cPath } )
      ::SaveCfg( .T. )
   elseif n == Len( ::aHotlist ) + 2 .and. ! Empty( ::aHotlist )
      // remove: ask which one
      aItems := {}
      AEval( ::aHotlist, { | a | AAdd( aItems, a[ 1 ] + "  (" + a[ 2 ] + ")" ) } )
      n := ::DlgList( "Remove from hotlist", aItems )
      if n > 0 .and. n <= Len( ::aHotlist )
         ADel( ::aHotlist, n )
         ASize( ::aHotlist, Len( ::aHotlist ) - 1 )
         ::SaveCfg( .T. )
      endif
   endif
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD EditExtFile() CLASS MCApp

   local cFile := hb_DirSepAdd( hb_GetEnv( "HOME" ) ) + ".hbmc.ext"

   if ! hb_FileExists( cFile )
      hb_MemoWrit( cFile, "# extension bindings: ext=command  (%f = file)" + hb_eol() + ;
                   "# prg=hbmk2 %f" + hb_eol() )
   endif
   MCEditFile( cFile )
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD EditMenuFile() CLASS MCApp

   local cFile := hb_DirSepAdd( hb_GetEnv( "HOME" ) ) + ".mc.menu"

   if ! hb_FileExists( cFile )
      hb_MemoWrit( cFile, "# user menu: key|label|command  (%f = current file)" + hb_eol() + ;
                   "c|Compile current file with hbmk2|hbmk2 %f 2>&1" + hb_eol() + ;
                   "g|git status|git status 2>&1" + hb_eol() + ;
                   "l|ls -la|ls -la" + hb_eol() )
   endif
   MCEditFile( cFile )
   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD HelpDialog() CLASS MCApp

   MCViewerText( "Harbour Commander - Help", ;
      "Harbour Commander - a Midnight Commander style file manager" + hb_eol() + ;
      "built with the hbide GUI classes (Turbo Vision look)." + hb_eol() + hb_eol() + ;
      "PANELS" + hb_eol() + ;
      "  Tab            switch active panel" + hb_eol() + ;
      "  Arrows/PgUp/PgDn/Home/End   move selection" + hb_eol() + ;
      "  Enter          enter directory / open file (extension binding or view)" + hb_eol() + ;
      "  Ins            mark/unmark file" + hb_eol() + ;
      "  + - *          select / unselect group / invert selection" + hb_eol() + ;
      "  C-s            quick search" + hb_eol() + ;
      "  C-r            rescan both panels" + hb_eol() + ;
      "  C-u            swap panels" + hb_eol() + ;
      "  C-o            panels on/off (shows last command output)" + hb_eol() + ;
      "  C-x d          compare directories" + hb_eol() + ;
      "  C-x i/q/t/p    info / quick view / tree / panelize" + hb_eol() + ;
      "  C-x c/o/l/s    chmod / chown / link / symlink" + hb_eol() + ;
      "  M-c            quick cd     M-h  command history" + hb_eol() + ;
      "  M-o            other panel chdirs to this directory" + hb_eol() + hb_eol() + ;
      "FUNCTION KEYS" + hb_eol() + ;
      "  F1 Help  F2 User menu  F3 View  F4 Edit  F5 Copy" + hb_eol() + ;
      "  F6 Rename/Move  F7 Mkdir  F8 Delete  F9 PullDn  F10 Quit" + hb_eol() + hb_eol() + ;
      "COMMAND LINE" + hb_eol() + ;
      "  Type to enter a command, Enter runs it, C-Enter inserts the" + hb_eol() + ;
      "  current file name, Esc clears. 'cd dir' changes the panel." + hb_eol() + hb_eol() + ;
      "VIEWER" + hb_eol() + ;
      "  F3/Esc/q quit  F4 hex mode  F2 wrap  F5 goto line  F7 search" + hb_eol() + hb_eol() + ;
      "EDITOR" + hb_eol() + ;
      "  F2 save  F10/Esc quit (asks to save when modified)" + hb_eol() + hb_eol() + ;
      "FILES" + hb_eol() + ;
      "  ~/.hbmc.ini   saved configuration, hotlist and history" + hb_eol() + ;
      "  ~/.hbmc.ext   extension bindings for Enter on a file" + hb_eol() + ;
      "  ~/.mc.menu or ./.mc.menu   user menu (F2)" + hb_eol() )

   ::Repaint()

return nil

//-----------------------------------------------------------------------------------------//

METHOD About() CLASS MCApp

   MCMsgBox( "About", ;
      "Harbour Commander 1.0" + Chr( 10 ) + ;
      "A Midnight Commander style file manager" + Chr( 10 ) + ;
      "written in Harbour with the hbide GUI classes." + Chr( 10 ) + Chr( 10 ) + ;
      "FiveTechSoft / hbide demo" )

return nil

//-----------------------------------------------------------------------------------------//

METHOD TranslateKey( nKey ) CLASS MCApp

   // learned F-key bindings: map the incoming code to the canonical
   // K_Fn the dispatch below understands (mc "Learn keys")
   local a

   for each a in ::aKeyBind
      if nKey == a[ 1 ]
         return a[ 2 ]
      endif
   next

return nKey

//-----------------------------------------------------------------------------------------//

METHOD LearnKeys() CLASS MCApp

   local aDef := MCKeyDefaults()
   local aNames := { "Help", "Menu", "View", "Edit", "Copy", ;
                     "RenMov", "Mkdir", "Delete", "PullDn", "Quit" }
   local aItems := {}, n, nPick, oDlg, nKey

   for n := 1 to 10
      AAdd( aItems, PadR( "F" + hb_ntos( n ) + " " + aNames[ n ], 14 ) + ;
            If( ::aKeyBind[ n ][ 1 ] == aDef[ n ], "(default)", ;
                "(key code " + hb_ntos( ::aKeyBind[ n ][ 1 ] ) + ")" ) )
   next

   nPick := ::DlgList( "Learn keys", aItems, 1 )
   if nPick == 0
      return nil
   endif

   // raw capture window: no READ, a single Inkey; Esc cancels
   oDlg := HBWindow():Dialog( "Learn keys", 52, 8, "W+/W" )
   oDlg:Say( 2, 3, "Press the new key for F" + hb_ntos( nPick ) + " " + aNames[ nPick ] )
   oDlg:Say( 3, 3, "(Esc cancels; the old binding is replaced)" )
   nKey := Inkey( 0 )
   oDlg:Hide()
   ::Repaint()

   if nKey != K_ESC
      ::aKeyBind[ nPick ][ 1 ] := nKey
      MCMsgBox( "Learn keys", "F" + hb_ntos( nPick ) + " " + aNames[ nPick ] + ;
                " now answers to key code " + hb_ntos( nKey ) )
   endif

return nil

//-----------------------------------------------------------------------------------------//

// mc execute.c:331-333: pause if Always, or (On dumb terminals AND not an
// xterm-ish terminal AND not on the Linux console)
function MCPauseShown( nOpt )

   local cTerm := Lower( GetEnv( "TERM" ) )

   if nOpt == 2
      return .T.
   endif
   if nOpt == 1
      return !( "xterm" $ cTerm ) .and. cTerm != "linux"
   endif

return .F.

//-----------------------------------------------------------------------------------------//

function MCKeyDefaults()

return { K_F1, K_F2, K_F3, K_F4, K_F5, K_F6, K_F7, K_F8, K_F9, K_F10 }

//-----------------------------------------------------------------------------------------//

METHOD LoadCfg() CLASS MCApp

   local cFile := ::CfgFile(), cLine, cKey, cVal, n

   if ! hb_FileExists( cFile )
      return nil
   endif
   for each cLine in hb_aTokens( StrTran( MemoRead( cFile ), Chr( 13 ) ), Chr( 10 ) )
      cLine := AllTrim( cLine )
      if Empty( cLine ) .or. Left( cLine, 1 ) == "#"
         loop
      endif
      if Left( cLine, 8 ) == "hotlist|"
         AAdd( ::aHotlist, { hb_TokenGet( cLine, 2, "|" ), hb_TokenGet( cLine, 3, "|" ) } )
         loop
      endif
      if Left( cLine, 8 ) == "history|"
         AAdd( ::aHistory, SubStr( cLine, 9 ) )
         loop
      endif
      cKey := Lower( hb_TokenGet( cLine, 1, "=" ) )
      cVal := hb_TokenGet( cLine, 2, "=" )
      do case
         case cKey == "showhidden"     ; ::lShowHidden := ( cVal == "1" )
         case cKey == "confirmdelete"  ; ::lConfirmDelete := ( cVal == "1" )
         case cKey == "confirmoverwrite" ; ::lConfirmOverwrite := ( cVal == "1" )
         case cKey == "confirmexecute" ; ::lConfirmExecute := ( cVal == "1" )
         case cKey == "confirmexit"    ; ::lConfirmExit := ( cVal == "1" )
         case cKey == "ministatus"     ; ::lMiniStatus := ( cVal == "1" )
         case cKey == "mixdirs"        ; ::lMixDirs := ( cVal == "1" )
         case cKey == "computetotals"  ; ::lComputeTotals := ( cVal == "1" )
         case cKey == "showfreespace"  ; ::lShowFreeSpace := ( cVal == "1" )
         case cKey == "autosavesetup"  ; ::lAutoSaveSetup := ( cVal == "1" )
         case cKey == "shellpatterns"  ; ::lShellPatterns := ( cVal == "1" )
         case cKey == "showbackup"     ; ::lShowBackup := ( cVal == "1" )
         case cKey == "markdown"       ; ::lMarkDown := ( cVal == "1" )
         case cKey == "lynxmotion"     ; ::lLynxMotion := ( cVal == "1" )
         case cKey == "mkdirautoname"  ; ::lMkdirAutoname := ( cVal == "1" )
         case cKey == "filetypes"      ; ::lFileTypes := ( cVal == "1" )
         case cKey == "fastreload"     ; ::lFastReload := ( cVal == "1" )
         case cKey == "verbose"        ; ::lVerboseOp := ( cVal == "1" )
         case cKey == "internalview"   ; ::lInternalView := ( cVal == "1" )
         case cKey == "internaledit"   ; ::lInternalEdit := ( cVal == "1" )
         case cKey == "externalview"   ; ::cExternalView := cVal
         case cKey == "externaledit"   ; ::cExternalEdit := cVal
         case cKey == "scrollpages"    ; ::lScrollPages := ( cVal == "1" )
         case cKey == "scrollcenter"   ; ::lScrollCenter := ( cVal == "1" )
         case cKey == "mousepages"     ; ::lMousePages := ( cVal == "1" )
         case cKey == "cdsymlinks"     ; ::lCdFollowsLinks := ( cVal == "1" )
         case cKey == "pauseafterrun"  ; ::nPauseAfterRun := Min( Max( 0, Val( cVal ) ), 2 )
         case cKey == "classicprogressbar" ; ::lClassicProgressbar := ( cVal == "1" )
         case cKey == "singlepress"    ; ::lSinglePress := ( cVal == "1" )
         case cKey == "esctimeout"     ; ::nEscTimeout := Int( Val( cVal ) )
         case cKey == "asknewfile"     ; ::lAskNewFile := ( cVal == "1" )
         case cKey == "automenus"      ; ::lAutoMenus := ( cVal == "1" )
         case cKey == "dropdownmenus"  ; ::lDropMenus := ( cVal == "1" )
         case cKey == "showallambig"   ; ::lShowAllAmbig := ( cVal == "1" )
         case cKey == "rotatingdash"   ; ::lRotatingDash := ( cVal == "1" )
         case cKey == "preallocate"    ; ::lPreallocate := ( cVal == "1" )
         case cKey == "cowcloning"     ; ::lCowClone := ( cVal == "1" )
         case cKey == "safedelete"     ; ::lSafeDelete := ( cVal == "1" )
         case cKey == "safeoverwrite"  ; ::lSafeOverwrite := ( cVal == "1" )
         case cKey == "siunits"        ; ::lSIUnits := ( cVal == "1" )
         case cKey == "equalsplit"     ; ::lEqualSplit := ( cVal == "1" )
         case cKey == "horizontal"     ; ::lHorizontal := ( cVal == "1" )
         case cKey == "menubar"        ; ::lMenubar := ( cVal == "1" )
         case cKey == "cmdlinebar"     ; ::lCmdlineBar := ( cVal == "1" )
         case cKey == "keybar"         ; ::lKeybar := ( cVal == "1" )
         case cKey == "theme"          ; ::nTheme := Max( 1, Min( 3, Val( cVal ) ) )
         case cKey == "cpleft"        ; ::cCp1 := If( MCCpValid( cVal ), cVal, "" )
         case cKey == "cpright"       ; ::cCp2 := If( MCCpValid( cVal ), cVal, "" )
         case cKey == "listmode1"     ; if AScan( { "full", "brief", "long", "user" }, cVal ) > 0 ; ::cListMode1 := cVal ; endif
         case cKey == "listmode2"     ; if AScan( { "full", "brief", "long", "user" }, cVal ) > 0 ; ::cListMode2 := cVal ; endif
         case cKey == "userfmt1"      ; if ! Empty( cVal ) ; ::cUserFmt1 := cVal ; endif
         case cKey == "userfmt2"      ; if ! Empty( cVal ) ; ::cUserFmt2 := cVal ; endif
         case cKey == "usermini1"     ; ::lUserMini1 := ( cVal == "1" )
         case cKey == "usermini2"     ; ::lUserMini2 := ( cVal == "1" )
         case Left( cKey, 8 ) == "learnkey"
            n := Val( SubStr( cKey, 9 ) )
            if n >= 1 .and. n <= 10 .and. Val( cVal ) != 0
               ::aKeyBind[ n ][ 1 ] := Val( cVal )
            endif
      endcase
   next

return nil

//-----------------------------------------------------------------------------------------//

METHOD SaveCfg( lQuiet ) CLASS MCApp

   local cTxt := "# Harbour Commander configuration" + hb_eol(), aEntry, c, n

   cTxt += "showhidden=" + If( ::lShowHidden, "1", "0" ) + hb_eol()
   cTxt += "confirmdelete=" + If( ::lConfirmDelete, "1", "0" ) + hb_eol()
   cTxt += "confirmoverwrite=" + If( ::lConfirmOverwrite, "1", "0" ) + hb_eol()
   cTxt += "confirmexecute=" + If( ::lConfirmExecute, "1", "0" ) + hb_eol()
   cTxt += "confirmexit=" + If( ::lConfirmExit, "1", "0" ) + hb_eol()
   cTxt += "ministatus=" + If( ::lMiniStatus, "1", "0" ) + hb_eol()
   cTxt += "mixdirs=" + If( ::lMixDirs, "1", "0" ) + hb_eol()
   cTxt += "computetotals=" + If( ::lComputeTotals, "1", "0" ) + hb_eol()
   cTxt += "showfreespace=" + If( ::lShowFreeSpace, "1", "0" ) + hb_eol()
   cTxt += "autosavesetup=" + If( ::lAutoSaveSetup, "1", "0" ) + hb_eol()
   cTxt += "shellpatterns=" + If( ::lShellPatterns, "1", "0" ) + hb_eol()
   cTxt += "showbackup=" + If( ::lShowBackup, "1", "0" ) + hb_eol()
   cTxt += "markdown=" + If( ::lMarkDown, "1", "0" ) + hb_eol()
   cTxt += "lynxmotion=" + If( ::lLynxMotion, "1", "0" ) + hb_eol()
   cTxt += "mkdirautoname=" + If( ::lMkdirAutoname, "1", "0" ) + hb_eol()
   cTxt += "filetypes=" + If( ::lFileTypes, "1", "0" ) + hb_eol()
   cTxt += "fastreload=" + If( ::lFastReload, "1", "0" ) + hb_eol()
   cTxt += "verbose=" + If( ::lVerboseOp, "1", "0" ) + hb_eol()
   cTxt += "internalview=" + If( ::lInternalView, "1", "0" ) + hb_eol()
   cTxt += "internaledit=" + If( ::lInternalEdit, "1", "0" ) + hb_eol()
   cTxt += "externalview=" + ::cExternalView + hb_eol()
   cTxt += "externaledit=" + ::cExternalEdit + hb_eol()
   cTxt += "scrollpages=" + If( ::lScrollPages, "1", "0" ) + hb_eol()
   cTxt += "scrollcenter=" + If( ::lScrollCenter, "1", "0" ) + hb_eol()
   cTxt += "mousepages=" + If( ::lMousePages, "1", "0" ) + hb_eol()
   cTxt += "cdsymlinks=" + If( ::lCdFollowsLinks, "1", "0" ) + hb_eol()
   cTxt += "pauseafterrun=" + hb_ntos( ::nPauseAfterRun ) + hb_eol()
   cTxt += "classicprogressbar=" + If( ::lClassicProgressbar, "1", "0" ) + hb_eol()
   cTxt += "singlepress=" + If( ::lSinglePress, "1", "0" ) + hb_eol()
   cTxt += "esctimeout=" + hb_ntos( ::nEscTimeout ) + hb_eol()
   cTxt += "asknewfile=" + If( ::lAskNewFile, "1", "0" ) + hb_eol()
   cTxt += "automenus=" + If( ::lAutoMenus, "1", "0" ) + hb_eol()
   cTxt += "dropdownmenus=" + If( ::lDropMenus, "1", "0" ) + hb_eol()
   cTxt += "showallambig=" + If( ::lShowAllAmbig, "1", "0" ) + hb_eol()
   cTxt += "rotatingdash=" + If( ::lRotatingDash, "1", "0" ) + hb_eol()
   cTxt += "preallocate=" + If( ::lPreallocate, "1", "0" ) + hb_eol()
   cTxt += "cowcloning=" + If( ::lCowClone, "1", "0" ) + hb_eol()
   cTxt += "safedelete=" + If( ::lSafeDelete, "1", "0" ) + hb_eol()
   cTxt += "safeoverwrite=" + If( ::lSafeOverwrite, "1", "0" ) + hb_eol()
   cTxt += "siunits=" + If( ::lSIUnits, "1", "0" ) + hb_eol()
   cTxt += "equalsplit=" + If( ::lEqualSplit, "1", "0" ) + hb_eol()
   cTxt += "horizontal=" + If( ::lHorizontal, "1", "0" ) + hb_eol()
   cTxt += "menubar=" + If( ::lMenubar, "1", "0" ) + hb_eol()
   cTxt += "cmdlinebar=" + If( ::lCmdlineBar, "1", "0" ) + hb_eol()
   cTxt += "keybar=" + If( ::lKeybar, "1", "0" ) + hb_eol()
   cTxt += "theme=" + hb_ntos( ::nTheme ) + hb_eol()
   cTxt += "cpleft=" + ::oPanel1:cCp + hb_eol()
   cTxt += "cpright=" + ::oPanel2:cCp + hb_eol()
   cTxt += "listmode1=" + ::oPanel1:cListMode + hb_eol()
   cTxt += "listmode2=" + ::oPanel2:cListMode + hb_eol()
   cTxt += "userfmt1=" + ::oPanel1:cUserFmt + hb_eol()
   cTxt += "userfmt2=" + ::oPanel2:cUserFmt + hb_eol()
   cTxt += "usermini1=" + If( ::oPanel1:lUserMiniStatus, "1", "0" ) + hb_eol()
   cTxt += "usermini2=" + If( ::oPanel2:lUserMiniStatus, "1", "0" ) + hb_eol()
   for n := 1 to 10
      if ! Empty( ::aKeyBind ) .and. ::aKeyBind[ n ][ 1 ] != MCKeyDefaults()[ n ]
         cTxt += "learnkey" + hb_ntos( n ) + "=" + hb_ntos( ::aKeyBind[ n ][ 1 ] ) + hb_eol()
      endif
   next
   for each aEntry in ::aHotlist
      cTxt += "hotlist|" + aEntry[ 1 ] + "|" + aEntry[ 2 ] + hb_eol()
   next
   for each c in ::aHistory
      cTxt += "history|" + c + hb_eol()
   next

   if ! hb_defaultValue( lQuiet, .F. )
      if hb_MemoWrit( ::CfgFile(), cTxt )
         MCMsgBox( "Save setup", "Configuration saved to:" + Chr( 10 ) + ::CfgFile() )
      else
         MCMsgBox( "Save setup", "Could not write:" + Chr( 10 ) + ::CfgFile() )
      endif
   else
      hb_MemoWrit( ::CfgFile(), cTxt )
   endif
   ::Repaint()

return nil


//-----------------------------------------------------------------------------------------//

// Enter inside dialogs: focused pushbutton fires (reader parity); any other
// control fires the dialog default button (cargo .T., shown as [< >]) -
// Midnight Commander semantics.
// Esc = Cancel inside dialogs, honoring the Esc key mode option
// (mc old_esc_mode, lib/tty/key.c:94 default TRUE = "Single press" ON):
// ON -> a lone Esc cancels (READ exit key); OFF -> Esc is only a prefix
// and the dialog closes on Esc Esc. The app keeps _SET_ESCAPE OFF in the
// main loop; each dialog arms this just for its own READ.
function MCDlgEscArm( oDlg, lSingle )

   static nEscCount := 0

   nEscCount := 0
   Set( _SET_ESCAPE, lSingle )
   if lSingle
      SetKey( K_ESC, NIL )
   else
      SetKey( K_ESC, { || ( ++nEscCount >= 2 .and. ( oDlg:End(), .T. ) ) } )
   endif

return nil

//-----------------------------------------------------------------------------------------//

function MCDlgEnter( aGets )

   local oGet := GetActive(), o

   if oGet != NIL .and. oGet:Control != NIL .and. ;
      oGet:Control:IsKindOf( "PUSHBUTTON" )
      oGet:Control:Select()
   else
      for each o in aGets
         if o:Control != NIL .and. o:Control:IsKindOf( "PUSHBUTTON" ) .and. ;
            o:Control:cargo == .T.
            if HB_ISEVALITEM( o:Control:sBlock )
               Eval( o:Control:sBlock )
            endif
            exit
         endif
      next
   endif

return NIL

//-----------------------------------------------------------------------------------------//

// Verbose operation instrumentation: one line per processed file, the same
// detail mc's operation dialog shows live for long operations (instant on
// the demo fixtures, so the log is the inspectable artifact).
static function MCVerboseLog( cLine )

   local nH := FOpen( "/tmp/hbmc-verbose.log", 1 )   // FO_WRITE

   if nH == -1
      nH := FCreate( "/tmp/hbmc-verbose.log" )
   endif
   if nH != -1
      FSeek( nH, 0, 2 )   // FS_END
      FWrite( nH, cLine + hb_eol() )
      FClose( nH )
   endif

return nil

//-----------------------------------------------------------------------------------------//

static function MCListNames( aMarked, nMax )

   local cOut := "", n := 0, aEntry

   for each aEntry in aMarked
      if aEntry[ P_NAME ] == "/.."
         loop
      endif
      n++
      if n > nMax
         return cOut + ", ..."
      endif
      cOut += If( n == 1, "", ", " ) + aEntry[ P_NAME ]
   next

return cOut

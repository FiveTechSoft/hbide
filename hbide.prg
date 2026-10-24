REQUEST __DBGENTRY   // link the Harbour source debugger (libhbdebug)

#include "hbclass.ch"
#include "hbhrb.ch"
#include "hbmenu.ch"
#include "inkey.ch"
#include "getexit.ch"
#include "setcurs.ch"
#include 'hbgtinfo.ch'

#xcommand DEFAULT <uVar1> := <uVal1> ;
               [, <uVarN> := <uValN> ] => ;
                  If( <uVar1> == nil, <uVar1> := <uVal1>, ) ;;
                [ If( <uVarN> == nil, <uVarN> := <uValN>, ); ]

#define HB_INKEY_GTEVENT   1024

//-----------------------------------------------------------------------------------------//

function Main()

   local oHbIde := HBIde():New()

   oHbIde:Activate()
   
return nil

//-----------------------------------------------------------------------------------------//

CLASS HbIde

   DATA   cBackScreen
   DATA   oMenu
   DATA   oWndCode
   DATA   oEditor
   DATA   nOldCursor
   DATA   lEnd
   DATA   nIdleStatus
   DATA   nLastDiskCheck
   DATA   cCompiler    INIT "GCC"
   DATA   lWarnings    INIT .T.
   DATA   lDebugInfo   INIT .F.
   DATA   lStrict      INIT .T.
   DATA   lIncremental INIT .F.
   DATA   lOptimize    INIT .F.
   DATA   lAutoRun     INIT .T.
   DATA   cPendingOpen INIT ""   // file the designer asks hbide to open on exit

   METHOD New()
   METHOD About()   
   METHOD BuildMenu()
   METHOD Designer()   
   METHOD QueueOpen( cFile )
   METHOD ClearPendingOpen()
   METHOD OpenInEditor( cFileName )
   METHOD Hide() INLINE RestScreen( 0, 0, MaxRow(), MaxCol(), ::cBackScreen )   
   METHOD MsgInfo( cText ) 
   METHOD Show()
   METHOD ShowStatus()
   METHOD Start()
   METHOD Script()
   METHOD Debug()
   METHOD Activate()
   METHOD End()   
   METHOD SaveScreen() INLINE ::cBackScreen := SaveScreen( 0, 0, MaxRow(), MaxCol() )  
   METHOD NewFile()
   METHOD SaveAs()
   METHOD DoSave()
   METHOD BuildFlags()
   METHOD OpenFile()
   METHOD GotoLine()
   METHOD ReplaceDialog()
   METHOD FindDialog()
   METHOD CheckUnsaved()
   METHOD CheckDiskChange()
   METHOD ReloadFromDisk()
   METHOD ConfirmOverwrite()
   METHOD SaveFile()
   METHOD Repaint()
   METHOD SuspendStatus()
   METHOD ResumeStatus()
   METHOD CompilerFlags()
   METHOD DisplayOpts()
   METHOD ApplyDisplay( nRows, nCols )
   METHOD HelpContents()
   METHOD HelpIndex()
   METHOD HelpView( cTitle, cText, lNested )
   METHOD HelpTopic( cTitle )
   METHOD HelpPick( aTopics, cCaption )

ENDCLASS

//-----------------------------------------------------------------------------------------//

METHOD New() CLASS HBIde

   local cLocale

   SET SCOREBOARD OFF
   Set( _SET_INSERT, .T. )   // editor works in insert mode by default (D4)
   
   ::SaveScreen()
   Set( _SET_EVENTMASK, hb_bitOr( INKEY_KEYBOARD, HB_INKEY_GTEVENT, INKEY_ALL ) )
   SetMode( 40, 120 )

   // Pin CP437 by default: the UI glyphs (button shades, check marks, box
   // chars) are CP437 and dialog widgets paint them as raw bytes; a Latin
   // or UTF-8 display codepage renders those text-path glyphs wrong.
   // Term/box CP stay "EN" so box borders keep the CP437 mapping.
   // Experimental opt-in: HBIDE_UTF8=1 selects the UTF8 host CP, which
   // renders accented/euro file content correctly through the gttrm Unicode
   // buffer (needs a real UTF-8 terminal). Known limits in that mode,
   // documented in docs: CP437 widget shade glyphs and GET echo show "?",
   // and legacy CP437/Latin1 sources display "?" (bytes stay byte-exact).
   cLocale := GetEnv( "HBIDE_UTF8" )
   if ! Empty( cLocale ) .and. !( Upper( cLocale ) == "0" ) .and. !( Upper( cLocale ) == "NO" )
      hb_cdpSelect( "UTF8" )
   else
      hb_cdpSelect( "EN" )
   endif
   hb_SetDispCP( "EN" )

   // xterm defaults to 8-bit meta (eightBitInput): Alt+o arrives as raw byte
   // 0xEF and leaks into the editor instead of opening menus. Ask xterm for
   // ESC-prefix meta (its metaSendsEscape mode) so Alt+letter works without
   // the user having to configure the terminal. Restored on exit.
   if "xterm" $ Lower( GetEnv( "TERM" ) )
      XTermMetaEsc( .T. )
   endif

   ::oMenu       = ::BuildMenu()
   ::oWndCode    = HBWindow():New( 1, 0, MaxRow() - 1, MaxCol(), "noname.prg", "W/B" )
   ::oEditor     = BuildEditor()
   ::nOldCursor  = SetCursor( SC_NONE )

   Hb_GtInfo( HB_GTI_FONTNAME , "Lucida Console" )
   Hb_GtInfo( HB_GTI_FONTWIDTH, 14  )
   Hb_GtInfo( HB_GTI_FONTSIZE , 25 ) 

   __ClsModMsg( PushButton( 0, 0 ):ClassH, "DISPLAY", @BtnDisplay() )
   __ClsModMsg( CheckBox( 0, 0 ):ClassH, "DISPLAY", @ChkDisplay() )
   __ClsModMsg( RadioButto( 0, 0 ):ClassH, "DISPLAY", @RadDisplay() )
   __ClsModMsg( CheckBox( 0, 0 ):ClassH, "HITTEST", @ChkHitTest() )
   __ClsModMsg( RadioButto( 0, 0 ):ClassH, "HITTEST", @RadHitTest() )

   ::nIdleStatus = hb_IdleAdd( { || ::ShowStatus() } )
   ::nLastDiskCheck = 0

   ErrorBlock( { | oError | ::MsgInfo( CallStack( oError ), "Error" ) } )

return Self

//-----------------------------------------------------------------------------------------//

function CallStack( oError, cSep, nLevel )

   local cErrorLog := ErrorMessage( oError )
   local c, n

   DEFAULT cSep := Chr( 10 ), nLevel := 1

   if ValType( oError:Args ) == "A"
      cErrorLog += cSep + "   Args:" + cSep
      for n = 1 to Len( oError:Args )
         cErrorLog += "     [" + Str( n, 4 ) + "] = " + ValType( oError:Args[ n ] ) + ;
                      "   " + hb_ValToStr( oError:Args[ n ] ) + ;
                      If( ValType( oError:Args[ n ] ) == "A", " length: " + ;
                      AllTrim( Str( Len( oError:Args[ n ] ) ) ), "" ) + cSep
      next
   endif

   while ! Empty( c := ProcName( nLevel ) )
      cErrorLog += cSep + c + "( " + hb_ntos( ProcLine( nLevel ) ) + " )"
      nLevel++
   end

return cErrorLog

//-----------------------------------------------------------------------------------------//

#define NTRIM(n)    ( LTrim( Str( n ) ) )
#include "error.ch"

static func ErrorMessage( e )

   // start error message
    local cMessage := if( empty( e:OsCode ), ;
                          if( e:severity > ES_WARNING, "Error ", "Warning " ),;
                          "(DOS Error " + NTRIM(e:osCode) + ") " )

   // add subsystem name if available
    cMessage += if( ValType( e:SubSystem ) == "C",;
                    e:SubSystem()                ,;
                    "???" )

   // add subsystem's error code if available
    cMessage += if( ValType( e:SubCode ) == "N",;
                    "/" + NTRIM( e:SubCode )   ,;
                    "/???" )
   // add error description if available
  if ( ValType( e:Description ) == "C" )
        cMessage += "  " + e:Description
   end

   // add either filename or operation
    cMessage += if( ! Empty( e:FileName ),;
                    ": " + e:FileName   ,;
                    if( !Empty( e:Operation ),;
                        ": " + e:Operation   ,;
                        "" ) )
return cMessage

//-----------------------------------------------------------------------------------------//

METHOD Designer() CLASS HBIde

   local oDesigner := HbDesigner():New( Self )
   local cPending

   oDesigner:Activate()
   // The designer queues a generated .prg with QueueOpen(); opening it while
   // the designer UI is active would mix two window stacks, so it opens here,
   // once the designer session has fully ended.
   if ! Empty( ::cPendingOpen )
      cPending := ::cPendingOpen
      ::cPendingOpen := ""
      ::OpenInEditor( cPending )
   endif

return nil

//-----------------------------------------------------------------------------------------//

// Contract for the dialog designer: queue a generated .prg to be opened in
// the source editor when the designer session ends. No UI here.
METHOD QueueOpen( cFile ) CLASS HBIde

   ::cPendingOpen := cFile

return nil

// Cancels a queued open (e.g. the designer queued and its dirty-model exit
// was then refused): clears the slot so no stale file opens on a later
// designer exit. No UI.
METHOD ClearPendingOpen() CLASS HBIde

   ::cPendingOpen := ""

return nil

//-----------------------------------------------------------------------------------------//

// Picker-free open of an existing file in the code editor. Same core steps
// as OpenFile()'s confirmed path. Returns .T. when the file was opened.
METHOD OpenInEditor( cFileName ) CLASS HBIde

   if ! File( cFileName )
      Alert( "File not found: " + cFileName )
      return .F.
   endif
   if ! ::CheckUnsaved()   // must not drop unsaved work
      return .F.
   endif
   if ! ::oWndCode:lVisible
      ::oWndCode:Show( .F. )
   endif
   ::oEditor:LoadFile( cFileName )
   ::oEditor:Display()
   ::oEditor:Goto( 1, 5 )
   ::oWndCode:cCaption = cFileName
   ::oWndCode:Refresh()

return .T.

//-----------------------------------------------------------------------------------------//

METHOD About() CLASS HBIde

   local oDlg, GetList := {}, lOk := .F.

   oDlg = HBWindow():Dialog( "HbIde 1.0", 35, 15, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   oDlg:SayCenter( "Harbour IDE", -4 )
   oDlg:SayCenter( "Version 1.0", -2 )
   oDlg:SayCenter( "Copyright (c) 1999-2023 by" )
   oDlg:SayCenter( "The Harbour Project", 2 )

   @ oDlg:nBottom - 2, oDlg:nLeft + Int( ( oDlg:nRight - oDlg:nLeft ) / 2 ) - 3 GET lOk ;
      PUSHBUTTON CAPTION " &OK " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()
   
return nil

//-----------------------------------------------------------------------------------------//

METHOD GotoLine() CLASS HBIde 

   local oDlg, GetList := {}, lDummy, lOk := .F.
   local nLine := 1, oGetName

   oDlg = HBWindow():Dialog( "Goto line", 30, 7, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   // Controls positioned relative to the dialog frame (D2)
   @ oDlg:nTop + 2, oDlg:nLeft + 13 GET nLine CAPTION "number:" COLOR "W/B,W+/B,W+/W,GR+/W" ;
      VALID { || If( LastKey() == K_ENTER, ( lOk := .T., GetActive():exitState := GE_ESCAPE ), ), .T. }

   @ oDlg:nBottom - 2, oDlg:nLeft + 5 GET lDummy PUSHBUTTON CAPTION " &OK " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nLeft + 15 GET lDummy PUSHBUTTON CAPTION "&Cancel" COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()

   if lOk
      ::oEditor:GotoLine( nLine )
      ::oEditor:Display()
      ::oEditor:ShowCursor()
   endif   
   
return nil

//-----------------------------------------------------------------------------------------//

METHOD MsgInfo( cText, cTitle ) CLASS HBIde

   local oDlg, GetList := {}, lOk := .F.
   local aLines := hb_aTokens( cText, Chr( 10 ) ), cLine, nRow := 2

   DEFAULT cTitle := "Information"

   oDlg = HBWindow():Dialog( cTitle, 55, Len( aLines ) + 5, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   for each cLine in aLines
      oDlg:Say( nRow++, 2, cLine )
   next   

   @ oDlg:nBottom - 2, oDlg:nLeft + ( oDlg:nRight - oDlg:nLeft ) / 2 - 2 GET lOk PUSHBUTTON ;
      CAPTION " &OK " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()
   
return nil

//-----------------------------------------------------------------------------------------//

METHOD Show() CLASS HBIde

   local n

   ::oMenu:Display()
   for n = 1 to MaxRow()
      @ n, 0 SAY Replicate( " ", MaxCol() + 1 ) COLOR "BG/B"
   next
   ::oWndCode:Show()
   hb_IdleDel( ::oWndCode:nIdle )
   ::oWndCode:nIdle = nil
   ::oEditor:Display()
   ::ShowStatus()

return nil

//-----------------------------------------------------------------------------------------//

METHOD Repaint() CLASS HBIde

   local n

   DispBegin()
   ::oMenu:Display()
   for n = 1 to MaxRow()
      @ n, 0 SAY Replicate( " ", MaxCol() + 1 ) COLOR "BG/B"
   next
   if ::oWndCode:lVisible
      ::oWndCode:Refresh()
   endif
   ::oEditor:Display()
   ::ShowStatus()
   DispEnd()

return nil

//-----------------------------------------------------------------------------------------//

METHOD ShowStatus() CLASS HBIde

   local aColors := ;
      { "W+/BG", "N/BG", "R/BG", "N+/BG", "W+/B", "GR+/B", "W/B", "N/W", "R/W", "N/BG", "R/BG" }

   DispBegin()
   hb_DispOutAt( MaxRow(), 0, Space( MaxCol() + 1 ), aColors[ 8 ] )
   hb_DispOutAt( MaxRow(), 2, iif( Set( _SET_INSERT ), "INS", "OVR" ), aColors[ 8 ] )
   if ::oEditor:HasMark()
      hb_DispOutAt( MaxRow(), 7, "MARK", aColors[ 9 ] )
   endif
   hb_DispOutAt( MaxRow(), MaxCol() - 17,;
                 "row: " + AllTrim( Str( ::oEditor:RowPos() ) ) + ", " + ;
                 "col: " + AllTrim( Str( Max( ::oEditor:ColPos() - 4, 1 ) ) ) + " ",;
                 aColors[ 8 ] )
   DispEnd()

return nil

//-----------------------------------------------------------------------------------------//

METHOD SuspendStatus() CLASS HBIde

   if ::nIdleStatus != nil
      hb_IdleDel( ::nIdleStatus )
      ::nIdleStatus = nil
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD ResumeStatus() CLASS HBIde

   if ::nIdleStatus == nil
      ::nIdleStatus = hb_IdleAdd( { || ::ShowStatus() } )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD Activate() CLASS HBIde

   local nKey, nKeyStd

   ::lEnd = .F.
   ::Show()
   ::oEditor:Goto( 1, 5 )

   while ! ::lEnd
      // HB_INKEY_EXT: gttrm keeps extended codes for keys that the classic
      // set collapses (Ctrl+Left == K_CTRL_Z, Shift+arrows == plain arrows).
      // nKeyStd feeds every pre-existing path; the editor also gets the raw
      // code so it can bind the newly distinct combinations.
      nKey = InKey( 1, INKEY_ALL + HB_INKEY_GTEVENT + HB_INKEY_EXT )   // 1s: lets the disk-change poll run idle
      nKeyStd = hb_keyStd( nKey )

      if nKeyStd == K_ESC .and. ! ::oMenu:IsOpen()
         if ::oEditor:Changed()
            if ::CheckUnsaved()
               ::lEnd = .T.
            else
               ::Repaint()
            endif
         else
            ::lEnd = .T.
         endif
      endif

      if nKeyStd >= K_ALT_Q .and. nKeyStd <= K_ALT_M
         SetCursor( SC_NONE )
         ::oMenu:ProcessKey( nKeyStd )
      endif

      // Handle F5 for Find
      if nKeyStd == K_F5 .and. ! ::oMenu:IsOpen()
         ::FindDialog()
         loop
      endif

      // Handle F2 for Save
      if nKeyStd == K_F2 .and. ! ::oMenu:IsOpen()
         ::SaveFile()
         loop
      endif




      // Handle F3 for Find Next
      if nKeyStd == K_F3 .and. ! ::oMenu:IsOpen()
         ::oEditor:FindNext()
         ::oEditor:ShowCursor()
         ::ShowStatus()
         loop
      endif

      if nKeyStd == K_LBUTTONDOWN
         if MRow() == 0 .or. ::oMenu:IsOpen()
            SetCursor( SC_NONE )
            ::oMenu:ProcessKey( nKeyStd )
            if ! ::oMenu:IsOpen()
               if ::oWndCode:lVisible
                  ::oEditor:ShowCursor()
               endif
            endif
         else
            if MRow() == 1 .and. MCol() == 2
               ::oWndCode:Hide()
               SetCursor( SC_NONE )
            else
               if ::oWndCode:lVisible
                  ::oEditor:Edit( nKey )
                  ::ShowStatus()
                  ::oEditor:ShowCursor()
               endif
            endif
         endif
      elseif nKeyStd == K_MWFORWARD .or. nKeyStd == K_MWBACKWARD
         if ::oMenu:IsOpen()
            ::oMenu:ProcessKey( nKeyStd )
         else
            if ::oWndCode:lVisible
               ::oEditor:Edit( nKey )
               ::ShowStatus()
               ::oEditor:ShowCursor()
            endif
         endif
      else
         if ::oMenu:IsOpen()
            ::oMenu:ProcessKey( nKeyStd )
            if ! ::oMenu:IsOpen()
               if ::oWndCode:lVisible
                  ::oEditor:ShowCursor()
               endif
            endif
         else
            if ::oWndCode:lVisible
               ::oEditor:ShowCursor()
               ::oEditor:Edit( nKey )
               ::ShowStatus()
            endif
         endif
      endif

      if Seconds() - ::nLastDiskCheck >= 2 .or. Seconds() < ::nLastDiskCheck
         ::nLastDiskCheck := Seconds()
         ::CheckDiskChange()
      endif
   end

   ::Hide()

   if "xterm" $ Lower( GetEnv( "TERM" ) )
      XTermMetaEsc( .F. )   // restore xterm meta modes
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD BuildMenu() CLASS HBIde

   local oMenu

   MENU oMenu
      MENUITEM " ~File "
      MENU
         MENUITEM "~New"              ACTION ::NewFile()
         MENUITEM "~Open..."          ACTION ::OpenFile()
         MENUITEM "~Save           F2 " ACTION ::SaveFile()
         MENUITEM "Save ~As... "      ACTION ::SaveAs()
         SEPARATOR
         MENUITEM "E~xit"             ACTION ::End()
      ENDMENU

      MENUITEM " ~Edit "
      MENU
         MENUITEM "U~ndo           Ctrl+Z"   ACTION ( ::oEditor:Undo(), ::oEditor:ShowCursor() )
         MENUITEM "R~edo           Ctrl+U"   ACTION ( ::oEditor:Redo(), ::oEditor:ShowCursor() )
         SEPARATOR
         MENUITEM "~Copy "                  ACTION iif( ::oEditor:HasMark(), ::oEditor:CopySelection(), ::oEditor:CopyLine() )
         MENUITEM "Cu~t "                   ACTION iif( ::oEditor:HasMark(), ::oEditor:CutSelection(), ::oEditor:DeleteLine() )
         MENUITEM "~Paste "                 ACTION ( ::oEditor:PasteLine(), ::oEditor:ShowCursor() )
         SEPARATOR
         MENUITEM "~Delete Line  Ctrl+Y"    ACTION ( ::oEditor:DeleteLine(), ::oEditor:ShowCursor() )
         MENUITEM "D~uplicate Line "        ACTION ( ::oEditor:DuplicateLine(), ::oEditor:ShowCursor() )
         SEPARATOR
         MENUITEM "~Find...         F5 "    ACTION ::FindDialog()
         MENUITEM "~Repeat Last Find F3"    ACTION ( ::oEditor:FindNext(), ::oEditor:ShowCursor() )
         MENUITEM "Repl~ace... "              ACTION ::ReplaceDialog()
         SEPARATOR
         MENUITEM "~Goto Line..."           ACTION ::GotoLine()
      ENDMENU

      MENUITEM " ~Run "
      MENU
         MENUITEM "~Start "            ACTION ::Start()
         MENUITEM "S~cript "           ACTION ::Script()
         MENUITEM "~Debug "          ACTION ::Debug()
      ENDMENU

      MENUITEM " ~Options "
      MENU
         MENUITEM "~Compiler Flags... " ACTION ::CompilerFlags()
         MENUITEM "~Display... "        ACTION ::DisplayOpts()
         SEPARATOR
         MENUITEM "De~signer..."       ACTION ::Designer() 
      ENDMENU 

      MENUITEM " ~Help "
      MENU
         MENUITEM "~Index "        ACTION ::HelpIndex()
         MENUITEM "~Contents "     ACTION ::HelpContents()
         SEPARATOR
         MENUITEM "A~bout... "      ACTION ::About()
      ENDMENU  
   ENDMENU

return oMenu

//-----------------------------------------------------------------------------------------//

METHOD Start() CLASS HbIde

   local cFile := AllTrim( ::oEditor:cFile ), cExe, cOut, nDot, cBase

   if ! ::ConfirmOverwrite()
      return nil
   endif

   ::oEditor:SaveFile()

   if Empty( cFile ) .or. cFile == "noname.prg" .and. ! File( cFile )
      Alert( "Nothing to run: save the file first" )
      return nil
   endif

   // files are opened as bare names in the current dir
   nDot = RAt( ".", cFile )
   cBase = iif( nDot > 1, Left( cFile, nDot - 1 ), cFile )

   // hbmk2 must be on PATH (Windows build not verified here)
   do case
      case Left( OS(), 7 ) == "Windows"
         cExe = cBase + ".exe"
      otherwise
         cExe = "./" + cBase
   endcase

   hb_Run( "hbmk2" + ::BuildFlags() + " " + cFile + " > info.txt 2>&1" )
   cOut = MemoRead( "info.txt" )
   Alert( iif( Empty( cOut ), "Build OK: " + cExe, cOut ) )

   if File( cExe )
      if ::lAutoRun
         hb_Run( cExe )
      else
         Alert( "Built (auto-run off): " + cExe )
      endif
   else
      Alert( "Build failed or hbmk2 not on PATH; executable not found: " + cExe )
   endif

   ::Repaint()
   SetCursor( SC_NORMAL )

return nil

//-----------------------------------------------------------------------------------------//

METHOD OpenFile() CLASS HbIde 

   local oDlg := HbWindow():Dialog( "Open a file", 46, 18, "W+/W" )
   local GetList := {}, oGetName, oListBox
   local cFileName := Space( 250 ), cPickFileName := ""
   local lDummy, lOk := .F., lTooLong := .F., nTooLong := 0, cTooLong := "", cLastLB := ""
   local aPrgs := Directory( "*.prg" )
   local nT, nL, nR, nB

   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   AEval( aPrgs, { | aPrg, n | aPrgs[ n ] := aPrg[ 1 ] } )
   if Len( aPrgs ) == 0
      AAdd( aPrgs, "" )
   endif
   // seed the sync marker with the listbox's initial selection so merely
   // tabbing into the list never overwrites a manually typed filename;
   // only an actual selection change (navigation) syncs the GET.
   cLastLB := aPrgs[ 1 ]

   // Controls positioned relative to the dialog frame (D2)
   nT = oDlg:nTop
   nL = oDlg:nLeft
   nR = oDlg:nRight
   nB = oDlg:nBottom

   @ nT + 3, nL + 3 GET cFileName PICTURE "@S37" COLOR "W/B,W+/B,W+/W,GR+/W" ;
      VALID { || If( LastKey() == K_ENTER, If( Empty( AllTrim( cFileName ) ) .and. oListBox != nil .and. ;
                     Len( oListBox:buffer ) > 250, ;
                  ( lTooLong := .T., nTooLong := Len( oListBox:buffer ), ;
                    cTooLong := Left( oListBox:buffer, 40 ), GetActive():exitState := GE_ESCAPE ), ;
                  ( lOk := .T., GetActive():exitState := GE_ESCAPE ) ), ), .T. }

   with object oGetName := ATail( GetList )  
      :CapRow = nT + 2   
      :CapCol = nL + 3   
      :Caption = "File to ope&n"
      :Display()
   end   

   @ nT + 5, nL + 3, nB - 3, nR - 3 GET cPickFileName LISTBOX aPrgs ;
      COLOR "N/BG,GR+/BG,N/BG,W+/G,W+/W,W+/W,GR+/W" ;
      VALID { || If( LastKey() == K_ENTER, If( Empty( AllTrim( cFileName ) ) .and. oListBox != nil .and. ;
                     Len( oListBox:buffer ) > 250, ;
                  ( lTooLong := .T., nTooLong := Len( oListBox:buffer ), ;
                    cTooLong := Left( oListBox:buffer, 40 ), GetActive():exitState := GE_ESCAPE ), ;
                  ( lOk := .T., GetActive():exitState := GE_ESCAPE ) ), ), .T. } ;
      STATE { || If( oListBox != nil .and. oListBox:buffer != cLastLB, ;
               ( cLastLB := oListBox:buffer, ;
                 If( Len( cLastLB ) > 250, ;
                     ( oGetName:VarPut( Space( 250 ) ), oGetName:Display() ), ;
                     ( oGetName:VarPut( cLastLB ), oGetName:Assign(), oGetName:Display() ) ) ), ) }

   with object oListBox := ATail( GetList ):Control  
      :CapRow = nT + 4   
      :CapCol = nL + 4   
      :Caption = "&Files"   
      :Display()
   end   

   // names over the GET's 250-char buffer are never truncated into it:
   // the listbox leaves the GET empty instead, and OK rejects explicitly.
   // The alert fires after the dialog closes: in-dialog alerts get
   // overdrawn by the dialog's own repaint cycle.
   @ nB - 2, nR - 19 GET lDummy PUSHBUTTON CAPTION "  &OK  " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || If( Empty( AllTrim( oGetName:VarGet() ) ) .and. ;
                     oListBox != nil .and. Len( oListBox:buffer ) > 250, ;
                  ( lTooLong := .T., nTooLong := Len( oListBox:buffer ), ;
                    cTooLong := Left( oListBox:buffer, 40 ), oDlg:End() ), ;
                  ( oDlg:End(), lOk := .T. ) ) }

   @ nB - 2, nR - 10 GET lDummy PUSHBUTTON CAPTION "&Cancel" COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()

   if lTooLong
      Alert( "Path too long (" + hb_ntos( nTooLong ) + ;
             " chars, max 250): " + cTooLong + "..." )
      return nil
   endif

   cFileName = AllTrim( cFileName )   // the GET is Space( 250 ): trim padding (D6)

   if lOk .and. ! Empty( cFileName )
      if ! File( cFileName )
         Alert( "File not found: " + cFileName )
      elseif ! ::CheckUnsaved()   // opening another file must not drop unsaved work
         // cancelled: keep editing the current buffer
      else
         if ! ::oWndCode:lVisible
            ::oWndCode:Show( .F. )
         endif
         ::oEditor:LoadFile( cFileName )
         ::oEditor:Display()
         ::oEditor:Goto( 1, 5 )
         ::oWndCode:cCaption = cFileName
         ::oWndCode:Refresh()
      endif
   endif 

return nil   

//-----------------------------------------------------------------------------------------//

METHOD End() CLASS HbIde

   if ::CheckUnsaved()
      ::lEnd := .T.
   else
      ::Repaint()
   endif

return nil

//-----------------------------------------------------------------------------------------//

// Returns .T. when it is safe to drop the current buffer:
// no changes, or user saved (and the save persisted), or user discarded.
METHOD CheckUnsaved() CLASS HbIde

   local lGo := .T.

   if ::oEditor:Changed()
      switch Alert( "Unsaved changes", { "&Save", "&Discard", "&Cancel" } )
      case 1
         ::SaveFile()
         lGo := ! ::oEditor:Changed()   // a failed save keeps the buffer dirty
         exit
      case 2
         lGo := .T.
         exit
      otherwise
         lGo := .F.
      end
   endif

return lGo

//-----------------------------------------------------------------------------------------//

// External-change watch (tvedit DiskStamp/CheckDiskChanges model, adapted to
// the single-buffer HBIde). The stamp is date+time+size+MD5 of the bytes
// (<= 8 MB), so a same-size edit inside the filesystem timestamp resolution
// is detected too; larger files keep the plain stamp.
METHOD CheckDiskChange() CLASS HbIde

   local cStamp

   if ::oMenu:IsOpen() .or. Empty( ::oEditor:cFile )
      return nil
   endif

   cStamp := ::oEditor:DiskStamp( ::oEditor:cFile )
   if Empty( cStamp )
      // external deletion: there is nothing to reload, so never touch the
      // buffer. Notify once and keep it; the save guard asks before recreating
      if ! Empty( ::oEditor:cSeenStamp )
         ::oEditor:cSeenStamp := ""
         Alert( "File deleted on disk; buffer kept: " + ::oEditor:cFile )
         ::Repaint()
         ::oEditor:ShowCursor()
      endif
      return nil
   endif

   if cStamp == ::oEditor:cSeenStamp
      return nil
   endif

   // mark as seen first: "Keep mine" must not re-ask for this same change;
   // the next own save warns before overwriting the external version
   ::oEditor:cSeenStamp := cStamp

   if ! ::oEditor:Changed()
      Alert( "File changed on disk; reloaded: " + ::oEditor:cFile )
      ::ReloadFromDisk()
   else
      if Alert( "File changed on disk and you have unsaved changes", ;
                { "&Reload", "&Keep mine" } ) == 1
         ::ReloadFromDisk()
      endif
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD ReloadFromDisk() CLASS HbIde

   // keep the cursor where the user was: reload used to jump to the top.
   // Clamp to the new text: the file may have shrunk on disk.
   local nRow := ::oEditor:RowPos()
   local nCol := ::oEditor:ColPos()

   ::oEditor:LoadFile( ::oEditor:cFile )
   nRow := Min( nRow, ::oEditor:LineCount() )
   nCol := Min( nCol, ::oEditor:LineLen( nRow ) + 5 )   // gutter-based coords (K_END lands on len+5)
   ::oEditor:Goto( nRow, nCol )
   ::Repaint()
   ::oEditor:ShowCursor()

return nil

//-----------------------------------------------------------------------------------------//

METHOD ConfirmOverwrite() CLASS HbIde

   if ::oEditor:FileVanished()
      if Alert( "File was deleted on disk. Recreate it?", ;
                { "&Recreate", "&Cancel" } ) != 1
         return .F.
      endif
   elseif ::oEditor:DiskChangedSinceLoad()
      if Alert( "File changed on disk since it was loaded/saved. Overwrite it?", ;
                { "&Overwrite", "&Cancel" } ) != 1
         return .F.
      endif
   endif

return .T.

//-----------------------------------------------------------------------------------------//

METHOD SaveFile() CLASS HbIde

   // untitled buffer: Save behaves as Save As (standard IDE contract)
   if Empty( ::oEditor:cFile ) .or. ::oEditor:cFile == "noname.prg"
      ::SaveAs()
      return nil
   endif

   ::DoSave()

return nil

//-----------------------------------------------------------------------------------------//

METHOD NewFile() CLASS HbIde

   if ! ::CheckUnsaved()
      ::Repaint()
      return nil
   endif

   ::oEditor:LoadText( "" )
   ::oEditor:cFile := "noname.prg"
   ::oEditor:cSeenStamp := ""
   ::oEditor:cLoadStamp := ""
   if ! ::oWndCode:lVisible
      ::oWndCode:Show( .F. )
   endif
   ::oWndCode:cCaption := ::oEditor:cFile
   ::Repaint()
   ::oEditor:Goto( 1, 5 )
   ::oEditor:ShowCursor()

return nil

//-----------------------------------------------------------------------------------------//

METHOD SaveAs() CLASS HbIde

   local oDlg := HbWindow():Dialog( "Save as", 50, 9, "W+/W" )
   local GetList := {}, oGetName, lDummy, lOk := .F.
   local cFileName := Space( 250 )
   local cName

   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   @ oDlg:nTop + 3, oDlg:nLeft + 3 GET cFileName PICTURE "@S30" COLOR "W/B,W+/B,W+/W,GR+/W" ;
      VALID { || If( LastKey() == K_ENTER, ( lOk := .T., GetActive():exitState := GE_ESCAPE ), ), .T. }

   with object oGetName := ATail( GetList )
      :CapRow = oDlg:nTop + 2
      :CapCol = oDlg:nLeft + 3
      :Caption = "File &name"
      :Display()
   end

   @ oDlg:nBottom - 2, oDlg:nRight - 19 GET lDummy PUSHBUTTON CAPTION "  &OK  " ;
      COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nRight - 10 GET lDummy PUSHBUTTON CAPTION "&Cancel" ;
      COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()

   cName := AllTrim( cFileName )
   if ! lOk .or. Empty( cName )
      return nil
   endif

   if cName != ::oEditor:cFile
      if File( cName )
         if Alert( "File exists: " + cName, { "&Overwrite", "&Cancel" } ) != 1
            ::Repaint()
            return nil
         endif
      endif
      ::oEditor:cFile := cName
      // seed the stamps with the current disk state of the target so the
      // save guard below does not re-ask for the change we just confirmed;
      // the .bak flow in DoSave still preserves the previous disk version
      ::oEditor:cSeenStamp := ::oEditor:cLoadStamp := ::oEditor:DiskStamp( cName )
   endif

   ::DoSave()

return nil

//-----------------------------------------------------------------------------------------//

METHOD DoSave() CLASS HbIde

   local cTmp

   if ! ::ConfirmOverwrite()
      return nil
   endif

   // tvedit-style safety net: keep the previous disk version as .bak.
   // The copy runs BEFORE writing, so a failed write leaves both intact.
   if ! Empty( ::oEditor:cFile ) .and. File( ::oEditor:cFile )
      // unique temp name: never delete preexisting content assuming it is ours
      cTmp := ::oEditor:cFile + ".bak." + StrZero( hb_randomInt( 999999 ), 6 ) + ".tmp"
      if File( cTmp )
         Alert( "Could not create the .bak copy (temp name in use); the previous .bak is preserved. Saving anyway" )
      elseif hb_FCopy( ::oEditor:cFile, cTmp ) != 0
         FErase( cTmp )   // drop the partial copy we just made
         Alert( "Could not create the .bak copy; the previous .bak is preserved. Saving anyway" )
      elseif FRename( cTmp, ::oEditor:cFile + ".bak" ) != 0
         // rename over an existing file fails on some platforms; erase and retry once
         FErase( ::oEditor:cFile + ".bak" )
         if FRename( cTmp, ::oEditor:cFile + ".bak" ) != 0
            Alert( "Could not update the .bak copy; the new backup is kept as " + cTmp + ". Saving anyway" )
         endif
      endif
   endif

   ::oEditor:SaveFile()
   ::oWndCode:cCaption = ::oEditor:cFile
   ::oWndCode:Refresh()
   ::oEditor:Display()
   ::oEditor:ShowCursor()

return nil

//-----------------------------------------------------------------------------------------//

METHOD CompilerFlags() CLASS HbIde

   local oDlg, GetList := {}, lDummy, lOk := .F.
   local lWarnings := ::lWarnings, lDebug := ::lDebugInfo, lStrict := ::lStrict
   local lIncremental := ::lIncremental, lOptimize := ::lOptimize, lAutoRun := ::lAutoRun
   local cCompiler := ::cCompiler, aCompilers[ 4 ], bPaint
   local cChkStyle := "[X ]", cRadStyle := "(" + Chr( 7 ) + " )"
   local cRadClr := "N/BG,N/BG,N/BG,W+/BG,N/BG,W+/BG,GR+/BG"
   local nT, nL, nR, nB

   // Turbo Vision gray dialog colors
   // Normal:       N/W    (black on gray)
   // Accelerator:  GR+/W  (yellow on gray)
   // Focused:      N/G    (black on green)
   // Button:       N/BG   (black on cyan)
   // Button focus: W+/G   (bright white on green)
   // Btn accel:    GR+/BG (yellow on cyan)
   // Group title:  W+/W   (bright white on gray)

   oDlg = HBWindow():Dialog( "Compiler Options", 56, 16, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   nT = oDlg:nTop
   nL = oDlg:nLeft
   nR = oDlg:nRight
   nB = oDlg:nBottom
   bPaint := { || HBIDE_PaintFlagsGroups( oDlg ) }

   // Groups: Compiler, Options, Build
   Eval( bPaint )

   aCompilers[ 1 ] = RadioButto( nT + 2, nL + 4, "&GCC" )
   aCompilers[ 2 ] = RadioButto( nT + 3, nL + 4, "&MSVC" )
   aCompilers[ 3 ] = RadioButto( nT + 4, nL + 4, "&Borland C" )
   aCompilers[ 4 ] = RadioButto( nT + 5, nL + 4, "C&lang" )

    AEval( aCompilers, { | o | o:colorSpec := cRadClr, o:cargo := { "GR+/BG", 0, 0 } } )

    oDlg:cargo := aCompilers

   @ nT + 2, nL + 3, nT + 6, nL + 23 GET cCompiler ;
      RADIOGROUP aCompilers STYLE cRadStyle

   ATail( GetList ):Control:coldBox := ""
   ATail( GetList ):Control:hotBox := ""
   // Redraw group frames (radiogroup Display already drew its own frame)
   Eval( bPaint )
   ATail( GetList ):Control:Display()

   @ nT + 2, nL + 28 GET lWarnings ;
      CHECKBOX CAPTION "&Warnings" STYLE cChkStyle ;
      COLOR "N/BG,W+/BG,N/BG,W+/BG"
    ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ nT + 3, nL + 28 GET lDebug ;
      CHECKBOX CAPTION "&Debug info" STYLE cChkStyle ;
      COLOR "N/BG,W+/BG,N/BG,W+/BG"
    ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ nT + 4, nL + 28 GET lStrict ;
      CHECKBOX CAPTION "S&trict types" STYLE cChkStyle ;
      COLOR "N/BG,W+/BG,N/BG,W+/BG"
    ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ nT + 5, nL + 28 GET lIncremental ;
      CHECKBOX CAPTION "&Incremental" STYLE cChkStyle ;
      COLOR "N/BG,W+/BG,N/BG,W+/BG"
    ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()


   @ nT + 9, nL + 4 GET lOptimize ;
      CHECKBOX CAPTION "O&ptimize code" STYLE cChkStyle ;
      COLOR "N/BG,W+/BG,N/BG,W+/BG"
    ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   @ nT + 10, nL + 4 GET lAutoRun ;
      CHECKBOX CAPTION "&Run after build" STYLE cChkStyle ;
      COLOR "N/BG,W+/BG,N/BG,W+/BG"
    ATail( GetList ):Control:cargo := { "GR+/BG", 0, 0 }
   ATail( GetList ):Control:Display()

   // Buttons
   @ nB - 2, nL + 10 GET lDummy PUSHBUTTON ;
      CAPTION "  &OK  " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ nB - 2, nL + 24 GET lDummy PUSHBUTTON ;
      CAPTION " &Cancel " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   @ nB - 2, nL + 38 GET lDummy PUSHBUTTON ;
      CAPTION "  &Help  " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || HBIDE_DialogHelp( oDlg, GetList, { || ::HelpTopic( "Options menu" ) }, bPaint ) }

   oDlg:Activate( GetList )
   ::ResumeStatus()

   if lOk
      ::cCompiler    := cCompiler
      ::lWarnings    := lWarnings
      ::lDebugInfo   := lDebug
      ::lStrict      := lStrict
      ::lIncremental := lIncremental
      ::lOptimize    := lOptimize
      ::lAutoRun     := lAutoRun
   endif

return nil

//-----------------------------------------------------------------------------------------//

// hbmk2 flag string from the Compiler Options dialog selections.
// Mappings: compiler -> -comp= (long form "-compiler=" is legacy and crashes hbmk2 3.2.1dev r2026-10-24 in LegacyWarning/ParamToString), Warnings -> -w3 (off: -w0),
// Debug info -> -b, Strict types -> -es2 (warnings are fatal),
// Incremental -> -inc, Optimize code -> -O2.
METHOD BuildFlags() CLASS HbIde

   local cFlags := ""
   local aIds := { "GCC" => "gcc", "MSVC" => "msvc", "Borland C" => "bcc", "Clang" => "clang" }

   if hb_HHasKey( aIds, ::cCompiler )
      cFlags += " -comp=" + aIds[ ::cCompiler ]
   endif
   cFlags += iif( ::lWarnings, " -w3", " -w0" )
   if ::lDebugInfo
      cFlags += " -b"
   endif
   if ::lStrict
      cFlags += " -es2"
   endif
   if ::lIncremental
      cFlags += " -inc"
   endif
   if ::lOptimize
      cFlags += " -O2"
   endif

return cFlags

//-----------------------------------------------------------------------------------------//

// Single-line free-form input used by Find/Replace: unlike a fixed-width
// GET (Space(N) buffer), the string grows/shrinks with the keys typed, so
// trailing blanks are real data, not field padding. Enter confirms the
// dialog, Tab/Down advances to the next control, Esc cancels. Returns
// { cText, lConfirm, lNext }.
static function HBIDE_DlgInput( nRow, nCol, nWidth, cInit )

   local cText := hb_defaultValue( cInit, "" )
   local nPos := Len( cText ) + 1, nOfs := 0, nKey, cKey
   local lInsert := .T., nOldCursor := SetCursor( SC_NORMAL )

   do while .T.
      if nPos < nOfs + 1
         nOfs := nPos - 1
      elseif nPos > nOfs + nWidth
         nOfs := nPos - nWidth
      endif
      hb_DispOutAt( nRow, nCol, PadR( SubStr( cText, nOfs + 1, nWidth ), nWidth ), "W/B" )
      SetPos( nRow, nCol + nPos - nOfs - 1 )

      nKey := Inkey( 0, hb_bitOr( INKEY_KEYBOARD, HB_INKEY_GTEVENT, INKEY_ALL ) )
      do case
      case nKey == K_ESC
         SetCursor( nOldCursor )
         return { "", .F., .F. }
      case nKey == K_ENTER
         SetCursor( nOldCursor )
         return { cText, .T., .F. }
      case nKey == K_TAB .or. nKey == K_DOWN
         SetCursor( nOldCursor )
         return { cText, .F., .T. }
      case nKey == K_LEFT
         nPos := Max( nPos - 1, 1 )
      case nKey == K_RIGHT
         nPos := Min( nPos + 1, Len( cText ) + 1 )
      case nKey == K_HOME
         nPos := 1
      case nKey == K_END
         nPos := Len( cText ) + 1
      case nKey == K_INS
         lInsert := ! lInsert
      case nKey == K_BS
         if nPos > 1
            cText := Stuff( cText, --nPos, 1, "" )
         endif
      case nKey == K_DEL
         if nPos <= Len( cText )
            cText := Stuff( cText, nPos, 1, "" )
         endif
      otherwise
         cKey := hb_keyChar( nKey )
         if Len( cKey ) > 0   // not Empty(): a typed SPACE is real data here
            cText := Stuff( cText, nPos, If( lInsert, 0, 1 ), cKey )
            nPos += Len( cKey )
         endif
      endcase
   enddo

return { "", .F., .F. }

//-----------------------------------------------------------------------------------------//

METHOD ReplaceDialog() CLASS HbIde

   local oDlg, GetList := {}, lDummy, lOk := .F., nCount
   local cFind := "", cReplace := "", aIn   // free-form fields: trailing blanks are real data

   oDlg = HBWindow():Dialog( "Replace", 40, 9, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   @ oDlg:nTop + 2, oDlg:nLeft + 5 SAY "Search for:" COLOR "N/W"
   @ oDlg:nTop + 4, oDlg:nLeft + 5 SAY "Replace with:" COLOR "N/W"

   @ oDlg:nBottom - 2, oDlg:nLeft + 11 GET lDummy PUSHBUTTON CAPTION " &OK " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nLeft + 22 GET lDummy PUSHBUTTON CAPTION "&Cancel" COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   aIn := HBIDE_DlgInput( oDlg:nTop + 3, oDlg:nLeft + 5, 28, cFind )
   if aIn[ 2 ]   // Enter: confirm with both fields as typed so far
      cFind := aIn[ 1 ]
      lOk := .T.
      oDlg:Hide()
   elseif aIn[ 3 ]   // Tab: next field
      cFind := aIn[ 1 ]
      aIn := HBIDE_DlgInput( oDlg:nTop + 5, oDlg:nLeft + 5, 28, cReplace )
      if aIn[ 2 ]
         cReplace := aIn[ 1 ]
         lOk := .T.
         oDlg:Hide()
      elseif aIn[ 3 ]
         cReplace := aIn[ 1 ]
         oDlg:Activate( GetList )   // OK/Cancel buttons
      else
         oDlg:Hide()
      endif
   else
      oDlg:Hide()
   endif
   ::ResumeStatus()

   if lOk .and. Len( cFind ) > 0
      nCount := ::oEditor:ReplaceAll( cFind, cReplace )
      ::oEditor:ShowCursor()
      Alert( hb_ntos( nCount ) + " replacement(s)" )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD FindDialog() CLASS HbIde

   local oDlg, GetList := {}, lDummy, lOk := .F.
   local cText := "", aIn   // free-form field: trailing blanks are real data

   oDlg = HBWindow():Dialog( "Find", 40, 7, "W+/W" )
   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   @ oDlg:nTop + 2, oDlg:nLeft + 5 SAY "Search for:" COLOR "N/W"

   @ oDlg:nBottom - 2, oDlg:nLeft + 11 GET lDummy PUSHBUTTON CAPTION " &OK " COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nLeft + 22 GET lDummy PUSHBUTTON CAPTION "&Cancel" COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   aIn := HBIDE_DlgInput( oDlg:nTop + 3, oDlg:nLeft + 5, 28, cText )
   if aIn[ 2 ]   // Enter: confirm
      cText := aIn[ 1 ]
      lOk := .T.
      oDlg:Hide()
   elseif aIn[ 3 ]   // Tab: OK/Cancel buttons
      cText := aIn[ 1 ]
      oDlg:Activate( GetList )
   else
      oDlg:Hide()
   endif
   ::ResumeStatus()

   if lOk .and. Len( cText ) > 0
      ::oEditor:FindText( cText )
      ::oEditor:ShowCursor()
      ::ShowStatus()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD Script() CLASS HbIde
   
   local oHrb, bOldError

   oHrb = hb_CompileFromBuf( StrTran( ::oEditor:GetText(), "Main", "__Main" ),;
                              .T., "-n", "-q2", "-Ic:/harbour/include" ) 
   ::Show()

   if ! Empty( oHrb )
      BEGIN SEQUENCE
         bOldError = ErrorBlock( { | o | DoBreak( o ) } )
         hb_HrbRun( oHrb )
      END SEQUENCE
      ErrorBlock( bOldError )
   endif

return nil      

//-----------------------------------------------------------------------------------------//


//-----------------------------------------------------------------------------------------//

METHOD Debug() CLASS HbIde

   local oHrb, bOldError, cTmpPrg, cTmpHrb
   static nDbgSeq := 0

   // compile the buffer with debug info (-b). The VM debug-request flag
   // is per stack and hb_HrbRun() runs on the HRB stack, so an init
   // procedure inside the compiled buffer asks for the break: the Harbour
   // source debugger (libhbdebug, linked via REQUEST __DBGENTRY) stops at
   // the first line with debug info and takes over until the run ends.
   // The buffer goes to a real temp file and is compiled with
   // hb_compilebuf() so the module has a real name and the debugger
   // finds the source in the current dir.
   // unique module/file names per session: after an Alt+X abort the HRB
   // module stays registered (the unwind skips hb_hrbUnLoad()) and the
   // next hb_hrbLoad() would recycle its symbol table with static
   // initialization deactivated - init procedures (and so the debug
   // break request) would never run again.
   cTmpPrg := "__hbide_dbg__.prg"
   // collision-free even for restarts within the same millisecond
   nDbgSeq++
   cTmpHrb := "__hbide_dbg__" + LTrim( Str( nDbgSeq ) ) + "_" + ;
              StrTran( Str( hb_MilliSeconds(), 15, 3 ), " ", "0" ) + ".hrb"
   hb_MemoWrit( cTmpPrg, StrTran( ::oEditor:GetText(), "Main", "__Main" ) + hb_eol() + ;
                         "init procedure __hbide_debug__()" + hb_eol() + ;
                         "   __dbgInvokeDebug( .T. )" + hb_eol() + ;
                         "return" + hb_eol() )
   // hb_compilebuf() collects every parameter into argv, so the first one
   // is consumed as the program name; without -q2 the compiler prints its
   // banner to stdout raw, outside the gttrm screen buffer (this was the
   // "menubar garbage" after Script/Debug runs)
   oHrb = hb_compilebuf( "hbide", cTmpPrg, "-n", "-b", "-q2" )
   ::Show()

   if ! Empty( oHrb )
      // clear stale debugger state from a previous aborted session
      // (Break() unwinds past dbgentry.c's bInside restore)
      __hbide_dbgReset()
      // HB_HRB_BIND_FORCELOCAL: a Break() out of the debugger (Alt+X)
      // unwinds past hb_HrbRun()'s internal hb_hrbUnLoad() and leaks the
      // module. With default binding the leaked public symbols poison the
      // next session (init procedures skipped -> no debug request, and
      // stale pCode could run). FORCELOCAL keeps the module's functions
      // static to itself, so every session binds cleanly.
      // run from a uniquely named .hrb file: symbol table recycling is
      // keyed by the load filename ("pcode.hrb" for in-memory bodies)
      hb_MemoWrit( cTmpHrb, oHrb )
      BEGIN SEQUENCE
         bOldError = ErrorBlock( { | o | DoBreak( o ) } )
         hb_HrbRun( HB_HRB_BIND_FORCELOCAL, cTmpHrb )
      END SEQUENCE
      ErrorBlock( bOldError )
      FErase( cTmpPrg )
      FErase( cTmpHrb )
      ::Repaint()
      SetCursor( SC_NORMAL )
   endif

return nil

function DoBreak( oError )

   Alert( oError:Description )

return nil

//-----------------------------------------------------------------------------------------//
// Custom CheckBox Display: 5 colors
// 0: mark unfocused, 1: mark focused, 2: brackets+caption unfocused,
// 3: caption focused, 4: accelerator (always yellow)

function ChkDisplay()

   local Self := QSelf()
   local cColor, cAccel, cStyle := ::cStyle, cCaption, nPos
   local nDR := 0, nDC := 0

   if HB_IsArray( ::cargo )
      nDR := ::cargo[ 2 ]
      nDC := ::cargo[ 3 ]
   endif

   DispBegin()

   hb_DispOutAt( ::row + nDR, ::col + nDC + 1, ;
      iif( ::lBuffer, SubStr( cStyle, 2, 1 ), SubStr( cStyle, 3, 1 ) ), ;
      hb_ColorIndex( ::cColorSpec, iif( ::lHasFocus, 1, 0 ) ) )

   cColor := hb_ColorIndex( ::cColorSpec, iif( ::lHasFocus, 3, 2 ) )
   hb_DispOutAt( ::row + nDR, ::col + nDC, Left( cStyle, 1 ), cColor )
   hb_DispOutAt( ::row + nDR, ::col + nDC + 2, Right( cStyle, 1 ), cColor )

   if ! Empty( cCaption := ::cCaption )
      if ( nPos := At( "&", cCaption ) ) == 0
      elseif nPos == Len( cCaption )
         nPos := 0
      else
         cCaption := Stuff( cCaption, nPos, 1, "" )
      endif

      hb_DispOutAt( ::nCapRow + nDR, ::nCapCol + nDC, cCaption, cColor )

      if nPos != 0
         cAccel := iif( HB_IsArray( ::cargo ), ::cargo[ 1 ], hb_ColorIndex( ::cColorSpec, 3 ) )
         hb_DispOutAt( ::nCapRow + nDR, ::nCapCol + nDC + nPos - 1, ;
            SubStr( cCaption, nPos, 1 ), cAccel )
      endif
   endif

   DispEnd()

return Self

//-----------------------------------------------------------------------------------------//
// Patched CheckBox hitTest: applies cargo delta to match visual position

function ChkHitTest( nMRow, nMCol )

   local Self := QSelf()
   local nDR := 0, nDC := 0, nLen, nPos

   if HB_IsArray( ::cargo )
      nDR := ::cargo[ 2 ]
      nDC := ::cargo[ 3 ]
   endif

   nLen := Len( ::cCaption )
   if ( nPos := At( "&", ::cCaption ) ) > 0 .and. nPos < nLen
      nLen--
   endif

   if nMRow == ::nRow + nDR .and. ;
      nMCol >= ::nCol + nDC .and. ;
      nMCol < ::nCol + nDC + 3
      return 1  // HTCLIENT
   endif

   if ! Empty( ::cCaption ) .and. ;
      nMRow == ::nCapRow + nDR .and. ;
      nMCol >= ::nCapCol + nDC .and. ;
      nMCol < ::nCapCol + nDC + nLen
      return 2  // HTCAPTION
   endif

   return 0  // HTNOWHERE

//-----------------------------------------------------------------------------------------//
// Patched RadioButton hitTest: applies cargo delta to match visual position

function RadHitTest( nMRow, nMCol )

   local Self := QSelf()
   local nLen, nPos
   local nDR := 0, nDC := 0

   if HB_IsArray( ::cargo )
      nDR := ::cargo[ 2 ]
      nDC := ::cargo[ 3 ]
   endif

   nLen := Len( ::cCaption )
   if ( nPos := At( "&", ::cCaption ) ) > 0 .and. nPos < nLen
      nLen--
   endif

   if nMRow == ::Row + nDR .and. ;
      nMCol >= ::Col + nDC .and. ;
      nMCol < ::Col + nDC + 3
      return 1  // HTCLIENT
   endif

   if ! Empty( ::cCaption ) .and. ;
      nMRow == ::CapRow + nDR .and. ;
      nMCol >= ::CapCol + nDC .and. ;
      nMCol < ::CapCol + nDC + nLen
      return 1  // HTCLIENT
   endif

   return 0  // HTNOWHERE

//-----------------------------------------------------------------------------------------//
// Custom RadioButton Display: 7 colors
// 0: unused, 1: bullet unselected, 2: unused, 3: bullet selected,
// 4: caption unfocused, 5: caption focused, 6: accelerator (always yellow)

function RadDisplay()

   local Self := QSelf()
   local cColor, cAccel, cStyle := ::cStyle, cCaption, nPos
   local nDR := 0, nDC := 0

   if HB_IsArray( ::cargo )
      nDR := ::cargo[ 2 ]
      nDC := ::cargo[ 3 ]
   endif

   DispBegin()

   cColor := iif( ::lBuffer, ;
      hb_ColorIndex( ::cColorSpec, 3 ), ;
      hb_ColorIndex( ::cColorSpec, 1 ) )
   hb_DispOutAt( ::row + nDR, ::col + nDC, Left( cStyle, 1 ) + ;
      iif( ::lBuffer, SubStr( cStyle, 2, 1 ), SubStr( cStyle, 3, 1 ) ) + ;
      Right( cStyle, 1 ), cColor )

   if ! Empty( cCaption := ::cCaption )
      if ( nPos := At( "&", cCaption ) ) == 0
      elseif nPos == Len( cCaption )
         nPos := 0
      else
         cCaption := Stuff( cCaption, nPos, 1, "" )
      endif

      hb_DispOutAt( ::CapRow + nDR, ::CapCol + nDC, cCaption, ;
         hb_ColorIndex( ::cColorSpec, iif( ::lBuffer, 5, 4 ) ) )

      if nPos != 0
         if ::lBuffer .and. HB_IsArray( ::cargo )
            cAccel := ::cargo[ 1 ]
         else
            cAccel := hb_ColorIndex( ::cColorSpec, iif( ::lBuffer, 5, 4 ) )
         endif
         hb_DispOutAt( ::CapRow + nDR, ::CapCol + nDC + nPos - 1, ;
            SubStr( cCaption, nPos, 1 ), cAccel )
      endif
   endif

   DispEnd()

return Self

//-----------------------------------------------------------------------------------------//

//-----------------------------------------------------------------------------------------//

// Topic picker shared by Help>Contents (all topics) and Help>Index (filtered).
// Returns the 1-based topic index within aTopics, 0 when cancelled.
METHOD HelpPick( aTopics, cCaption ) CLASS HbIde

   local oDlg := HbWindow():Dialog( cCaption, 50, 14, "W+/W" )
   local GetList := {}, lDummy, lOk := .F., cPick := ""
   local aTitles := {}, oListBox

   AEval( aTopics, { | t | AAdd( aTitles, t[ 2 ] ) } )

   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   @ oDlg:nTop + 2, oDlg:nLeft + 3, oDlg:nBottom - 4, oDlg:nRight - 3 GET cPick ;
      LISTBOX aTitles COLOR "N/BG,GR+/BG,N/BG,W+/G,W+/W,W+/W,GR+/W" ;
      VALID { || If( LastKey() == K_ENTER, ( lOk := .T., GetActive():exitState := GE_ESCAPE ), ), .T. }

   oListBox := ATail( GetList ):Control

   @ oDlg:nBottom - 2, oDlg:nRight - 19 GET lDummy PUSHBUTTON CAPTION "  &OK  " ;
      COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nRight - 10 GET lDummy PUSHBUTTON CAPTION "&Cancel" ;
      COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()

   if ! lOk
      return 0
   endif

return AScan( aTopics, { | t | t[ 2 ] == oListBox:buffer } )

//-----------------------------------------------------------------------------------------//

METHOD HelpContents() CLASS HbIde

   local aTopics := HBIDEHelpTopics(), nPick

   while ( nPick := ::HelpPick( aTopics, "Help - Contents" ) ) > 0
      ::HelpView( aTopics[ nPick, 2 ], aTopics[ nPick, 3 ] )
   end

return nil

//-----------------------------------------------------------------------------------------//

METHOD HelpIndex() CLASS HbIde

   local oDlg := HbWindow():Dialog( "Help - Index", 50, 8, "W+/W" )
   local GetList := {}, lDummy, lOk := .F., oGetName
   local cFilter := Space( 30 ), cKey, aTopics, aMatch := {}, nPick

   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   @ oDlg:nTop + 3, oDlg:nLeft + 3 GET cFilter COLOR "W/B,W+/B,W+/W,GR+/W" ;
      VALID { || If( LastKey() == K_ENTER, ( lOk := .T., GetActive():exitState := GE_ESCAPE ), ), .T. }

   with object oGetName := ATail( GetList )
      :CapRow = oDlg:nTop + 2
      :CapCol = oDlg:nLeft + 3
      :Caption = "&Keyword"
      :Display()
   end

   @ oDlg:nBottom - 2, oDlg:nRight - 19 GET lDummy PUSHBUTTON CAPTION "  &OK  " ;
      COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ oDlg:nBottom - 2, oDlg:nRight - 10 GET lDummy PUSHBUTTON CAPTION "&Cancel" ;
      COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()

   if ! lOk
      return nil
   endif

   cKey := Lower( AllTrim( cFilter ) )
   aTopics := HBIDEHelpTopics()
   if Empty( cKey )
      aMatch := aTopics
   else
      AEval( aTopics, { | t | iif( cKey $ Lower( t[ 1 ] + " " + t[ 2 ] ), ;
         AAdd( aMatch, t ), ) } )
   endif

   if Len( aMatch ) == 0
      Alert( "No help topic matches: " + cKey )
   elseif Len( aMatch ) == 1
      ::HelpView( aMatch[ 1, 2 ], aMatch[ 1, 3 ] )
   else
      while ( nPick := ::HelpPick( aMatch, "Help - Index" ) ) > 0
         ::HelpView( aMatch[ nPick, 2 ], aMatch[ nPick, 3 ] )
      end
   endif

return nil

//-----------------------------------------------------------------------------------------//



// Paints the three labeled group frames of the Compiler Flags dialog.
// Used for the initial paint and to restore them after a nested dialog.
static function HBIDE_PaintFlagsGroups( oDlg )

   local nT := oDlg:nTop, nL := oDlg:nLeft
   local nR := oDlg:nRight

   hb_DispBox( nT + 1, nL + 2, nT + 7, nL + 24, ;
               hb_UTF8ToStr( "┌─┐│┘─└│" ), "N/W" )
   hb_Scroll( nT + 2, nL + 3, nT + 6, nL + 23,,, "N/BG" )
   hb_DispOutAt( nT + 1, nL + 4, " Compiler ", "N/W" )

   hb_DispBox( nT + 1, nL + 26, nT + 7, nR - 2, ;
               hb_UTF8ToStr( "┌─┐│┘─└│" ), "N/W" )
   hb_Scroll( nT + 2, nL + 27, nT + 6, nR - 3,,, "N/BG" )
   hb_DispOutAt( nT + 1, nL + 28, " Options ", "N/W" )

   hb_DispBox( nT + 8, nL + 2, nT + 12, nR - 2, ;
               hb_UTF8ToStr( "┌─┐│┘─└│" ), "N/W" )
   hb_Scroll( nT + 9, nL + 3, nT + 11, nR - 3,,, "N/BG" )
   hb_DispOutAt( nT + 8, nL + 4, " Build ", "N/W" )

return nil

// Runs a help action over a modal GET dialog without visual overlap:
// Hide() drops the dialog idle repaint task and clears its area, the help
// draws on the clean IDE background, then the dialog and its GETs redraw.
static function HBIDE_DialogHelp( oDlg, GetList, bHelp, bPaint )

   local oCtrl

   oDlg:Hide()
   Eval( bHelp )
   oDlg:Show( .T. )
   if bPaint != nil
      Eval( bPaint )
   endif
   for each oCtrl in GetList
      if oCtrl:Control != nil
         oCtrl:Control:Display()
      endif
   next

return nil

//-----------------------------------------------------------------------------------------//

METHOD HelpTopic( cTitle ) CLASS HbIde

   local aTopics := HBIDEHelpTopics()
   local n := AScan( aTopics, { | t | t[ 2 ] == cTitle } )

   if n > 0
      ::HelpView( aTopics[ n, 2 ], aTopics[ n, 3 ], .T. )
   else
      Alert( "Help not available" )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD HelpView( cTitle, cText, lNested ) CLASS HbIde

   local cScr := SaveScreen( 0, 0, MaxRow(), MaxCol() )
   local nT := 3, nL := 15, nB := MaxRow() - 4, nR := MaxCol() - 15

   ::SuspendStatus()
   DispBegin()
   hb_DispBox( nT - 1, nL - 1, nB + 1, nR + 1, ;
               hb_UTF8ToStr( "┌─┐│┘─└│" ), "W+/W" )
   hb_Scroll( nT, nL, nB, nR,,, "W/B" )
   hb_DispOutAt( nT - 1, nL + 2, " " + cTitle + " ", "W+/W" )
   hb_DispOutAt( nB + 2, nL, "Esc: back", "W+/BG" )
   DispEnd()

   MemoEdit( cText, nT, nL, nB, nR, .F. )

   RestScreen( 0, 0, MaxRow(), MaxCol(), cScr )
   ::ResumeStatus()
   if ! hb_defaultValue( lNested, .F. )
      ::Repaint()
      ::oEditor:ShowCursor()
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD DisplayOpts() CLASS HbIde

   local oDlg := HbWindow():Dialog( "Display", 30, 9, "W+/W" )
   local GetList := {}, lDummy, lOk := .F.
   local aSizes := { "40 x 120", "30 x 100", "25 x 80" }
   local cRadStyle := "(" + Chr( 7 ) + " )"
   local aRadios := {}, n, cSize := aSizes[ 1 ]
   local nT, nL, nB, nR

   // preselect the current mode when it is one of the presets
   for n = 1 to Len( aSizes )
      if Val( Left( aSizes[ n ], 2 ) ) == MaxRow() + 1
         cSize := aSizes[ n ]
      endif
   next

   oDlg:bRepaint = { || ::Repaint() }
   ::SuspendStatus()

   nT := oDlg:nTop
   nL := oDlg:nLeft
   nB := oDlg:nBottom
   nR := oDlg:nRight

   for n = 1 to Len( aSizes )
      AAdd( aRadios, RadioButto( nT + 1 + n, nL + 4, aSizes[ n ] ) )
      ATail( aRadios ):colorSpec := "N/W,N/W,N/W,W+/W,N/W,W+/W,GR+/W"
   next

   @ nT + 2, nL + 3, nT + 4, nR - 3 GET cSize ;
      RADIOGROUP aRadios STYLE cRadStyle

   ATail( GetList ):Control:coldBox := ""
   ATail( GetList ):Control:hotBox := ""
   hb_Scroll( nT + 1, nL + 2, nB - 3, nR - 2,,, "N/W" )
   ATail( GetList ):Control:Display()

   @ nB - 2, nR - 19 GET lDummy PUSHBUTTON CAPTION "  &OK  " ;
      COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || lOk := .T., oDlg:End() }

   @ nB - 2, nR - 10 GET lDummy PUSHBUTTON CAPTION "&Cancel" ;
      COLOR "GR+/G,W+/G,N/G,BG+/G" ;
      STATE { || oDlg:End() }

   oDlg:Activate( GetList )
   ::ResumeStatus()

   if lOk
      ::ApplyDisplay( Val( Left( cSize, 2 ) ), Val( SubStr( cSize, 6 ) ) )
   endif

return nil

//-----------------------------------------------------------------------------------------//

METHOD ApplyDisplay( nRows, nCols ) CLASS HbIde

   local nOldRows := MaxRow() + 1, nOldCols := MaxCol() + 1

   if nRows == nOldRows .and. nCols == nOldCols
      return nil
   endif

   ::oWndCode:Hide()
   if ! SetMode( nRows, nCols ) .or. MaxRow() + 1 != nRows .or. MaxCol() + 1 != nCols
      SetMode( nOldRows, nOldCols )
      Alert( "Terminal does not support " + hb_ntos( nRows ) + "x" + hb_ntos( nCols ) )
      ::oWndCode:Show( .F. )
      ::Repaint()
      ::oEditor:ShowCursor()
      return nil
   endif

   ::SaveScreen()
   ::oWndCode := HBWindow():New( 1, 0, MaxRow() - 1, MaxCol(), ;
                                 ::oWndCode:cCaption, "W/B" )
   ::oWndCode:Show( .F. )
   ::oEditor:Resize( 2, 1, MaxRow() - 2, MaxCol() - 1 )
   ::Repaint()
   ::oEditor:ShowCursor()

return nil

//-----------------------------------------------------------------------------------------//

// Ask xterm for ESC-prefix meta (eightBitInput off + metaSendsEscape on) or
// restore its defaults. QQOut cannot be used: gttrm draws OutStd into the
// screen buffer instead of forwarding it to the terminal, so the escape
// never reaches xterm. Writing to /dev/tty bypasses the GT.
function XTermMetaEsc( lOn )

   local nH := FOpen( "/dev/tty", 1 )   // FO_WRITE

   if nH != -1
      if lOn
         FWrite( nH, Chr( 27 ) + "[?1034l" + Chr( 27 ) + "[?1036h" )
      else
         FWrite( nH, Chr( 27 ) + "[?1036l" + Chr( 27 ) + "[?1034h" )
      endif
      FClose( nH )
   endif

return nil

//-----------------------------------------------------------------------------------------//
